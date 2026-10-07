import Foundation
import Observation

extension Notification.Name {
    static let avelaHealthDidLog = Notification.Name("avelaHealthDidLog")
}

enum HealthHabitMetric: String, CaseIterable, Codable, Sendable {
    case steps
    case exerciseMinutes
    var label: String { self == .steps ? "Steps" : "Exercise minutes" }
    var defaultTarget: Double { self == .steps ? 5000 : 30 }
    var maximumTarget: Double { self == .steps ? 200000 : 1440 }
}

struct HealthHabitConnection: Identifiable, Equatable, Sendable {
    let id: UUID
    let habitID: UUID
    let metric: HealthHabitMetric
    let target: Double
    let connectedAt: Date
}

@MainActor protocol HealthHabitConnectionRepository {
    func connections() throws -> [HealthHabitConnection]
    func save(habitID: UUID, metric: HealthHabitMetric, target: Double, at date: Date) throws
    func disconnect(habitID: UUID) throws
}

@MainActor protocol HealthHabitProvider {
    var isAvailable: Bool { get }
    func requestReadAccess(for metric: HealthHabitMetric) async throws
    /// nil means no accessible samples, never a measured zero or denied flag.
    func total(for metric: HealthHabitMetric, in interval: DateInterval) async throws -> Double?
}

enum HealthHabitError: LocalizedError {
    case unavailable, invalidTarget, invalidHabit
    var errorDescription: String? {
        switch self {
        case .unavailable: return "Apple Health isn't available on this device. Manual logging still works."
        case .invalidTarget: return "Enter a positive target within the displayed limit."
        case .invalidHabit: return "Connect an active Build Up habit to Apple Health."
        }
    }
}

@MainActor @Observable
final class HealthHabitService {
    private let habits: HabitRepository
    private let connections: HealthHabitConnectionRepository
    private let provider: HealthHabitProvider
    private let calendar: Calendar
    private let currentDate: () -> Date
    private(set) var isRefreshing = false
    private(set) var refreshError: String?
    private(set) var messages: [UUID: String] = [:]
    var isAvailable: Bool { provider.isAvailable }

    init(habits: HabitRepository, connections: HealthHabitConnectionRepository,
         provider: HealthHabitProvider, calendar: Calendar = .autoupdatingCurrent,
         currentDate: @escaping () -> Date = Date.init) {
        self.habits = habits; self.connections = connections
        self.provider = provider; self.calendar = calendar; self.currentDate = currentDate
    }

    func connection(for habitID: UUID) throws -> HealthHabitConnection? {
        try connections.connections().first { $0.habitID == habitID }
    }

    func connect(habitID: UUID, metric: HealthHabitMetric, target: Double, at date: Date = Date()) async throws {
        guard provider.isAvailable else { throw HealthHabitError.unavailable }
        guard target.isFinite, target > 0, target <= metric.maximumTarget else { throw HealthHabitError.invalidTarget }
        try validateHabit(habitID)
        // The successful request only means Apple's permission flow completed,
        // not that read access was granted. Query results remain optional.
        try await provider.requestReadAccess(for: metric)
        try validateHabit(habitID)
        try connections.save(habitID: habitID, metric: metric, target: target, at: date)
        messages[habitID] = "Connected. Refresh to check today's available Health data."
    }

    func disconnect(habitID: UUID) throws {
        try connections.disconnect(habitID: habitID)
        messages[habitID] = "Disconnected. Existing completions are kept."
    }

    var permitsConnection: (UUID) -> Bool = { _ in true }

    private func validateHabit(_ id: UUID) throws {
        guard permitsConnection(id) else { throw HealthHabitError.invalidHabit }
        guard let habit = try habits.fetchHabit(id: id), habit.archivedAt == nil,
              habit.polarity == .positive else { throw HealthHabitError.invalidHabit }
    }

    func refresh(at date: Date = Date()) async {
        guard !isRefreshing, provider.isAvailable else { return }
        isRefreshing = true
        refreshError = nil
        defer { isRefreshing = false }
        do {
            let saved = try connections.connections()
            for connection in saved {
                guard !Task.isCancelled else { return }
                do { try await refresh(connection, at: date) }
                catch { messages[connection.habitID] = "Couldn't refresh Apple Health. Manual logging still works." }
            }
        } catch {
            refreshError = "Your Health connections couldn't be loaded. Manual logging still works."
        }
    }

    private func refresh(_ connection: HealthHabitConnection, at date: Date) async throws {
        guard connection.target.isFinite, connection.target > 0,
              connection.target <= connection.metric.maximumTarget else { throw HealthHabitError.invalidTarget }
        try validateHabit(connection.habitID)
        guard connection.connectedAt <= date,
              let day = calendar.dateInterval(of: .day, for: date) else { return }
        let value = try await provider.total(for: connection.metric, in: DateInterval(start: day.start, end: date))
        guard !Task.isCancelled,
              LocalDay.key(for: date, calendar: calendar) == LocalDay.key(for: currentDate(), calendar: calendar),
              try self.connection(for: connection.habitID)?.id == connection.id else { return }
        try validateHabit(connection.habitID)
        guard let value, value.isFinite, value >= 0 else {
            messages[connection.habitID] = "No accessible Health data yet. This may mean no samples or limited read access."
            return
        }
        messages[connection.habitID] = "\(value.formatted(.number.precision(.fractionLength(0...1)))) of \(connection.target.formatted()) \(connection.metric.label.lowercased()) from Apple Health today."
        guard value >= connection.target,
              let configuration = try habits.activeConfiguration(for: connection.habitID, on: date),
              HabitScheduleEvaluator.isDue(configuration.schedule, on: date, calendar: calendar),
              (try habits.completions(for: connection.habitID, in: day)).isEmpty,
              (try habits.skips(for: connection.habitID, in: day)).isEmpty else { return }
        // A user skip is authoritative; imports don't replace it. Each local
        // day counts once, including flexible weekly commitments.
        try habits.recordCompletion(habitID: connection.habitID, at: date, source: .healthKit, note: nil)
        NotificationCenter.default.post(name: .avelaHealthDidLog, object: nil)
        messages[connection.habitID] = "Today's target reached in Apple Health. Habit success logged."
    }
}
