import Foundation

enum HabitQuantityUnit: String, CaseIterable, Codable, Sendable {
    case count, pages, glasses, minutes
    var label: String { rawValue.capitalized }
    func name(for amount: Int) -> String {
        guard amount == 1 else { return rawValue }
        switch self {
        case .count: return "count"
        case .pages: return "page"
        case .glasses: return "glass"
        case .minutes: return "minute"
        }
    }
}

struct HabitQuantityTarget: Equatable, Codable, Sendable {
    var amount: Int
    var unit: HabitQuantityUnit
    var label: String { "\(amount) \(unit.name(for: amount)) per scheduled day" }
}

struct HabitActivityConfiguration: Equatable, Sendable {
    let id: UUID
    let habitID: UUID
    let effectiveDayKey: String
    let revision: Int
    let target: HabitQuantityTarget?
    let smallerAction: String
}

enum HabitActivityKind: String, Codable, Sendable { case quantity, smallerAction }

struct HabitActivityEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let habitID: UUID
    let configurationID: UUID
    let dayKey: String
    let loggedAt: Date
    let kind: HabitActivityKind
    let amount: Int
    let unit: HabitQuantityUnit?
    let description: String
}

struct HabitTimerState: Equatable, Sendable {
    let habitID: UUID
    let dayKey: String
    var startedAt: Date?
    var elapsedSeconds: Int
    func seconds(at date: Date) -> Int {
        let extra = startedAt.map { max(0, min(86_400, Int(date.timeIntervalSince($0)))) } ?? 0
        return min(86_400, elapsedSeconds + extra)
    }
}

enum HabitActivityError: Error, Equatable {
    case invalidTarget, invalidAmount, unavailableDay, staleConfiguration, staleCorrection, noSmallerAction
}

enum HabitDayCorrection: String, CaseIterable { case success, skip, clear }

struct HabitCorrectionPreview: Equatable {
    let habitID: UUID
    let dayKey: String
    let completionIDs: Set<UUID>
    let skipIDs: Set<UUID>
    let activityConfigurationID: UUID?
    let scheduleConfigurationID: UUID?
}

@MainActor
protocol HabitActivityRepository {
    func configuration(for habitID: UUID, on date: Date) throws -> HabitActivityConfiguration?
    func configure(habitID: UUID, target: HabitQuantityTarget?, smallerAction: String, at date: Date) throws
    func entries(for habitID: UUID, on date: Date) throws -> [HabitActivityEntry]
    /// Stored civil days intersecting a half-open interval. Backdated entries
    /// belong to their recorded day, never the later time they were entered.
    func entries(for habitID: UUID, in range: DateInterval) throws -> [HabitActivityEntry]
    func log(habitID: UUID, kind: HabitActivityKind, amount: Int, expectedConfigurationID: UUID, on date: Date, now: Date) throws
    func removeEntry(id: UUID, now: Date) throws
    func correctionPreview(habitID: UUID, on date: Date) throws -> HabitCorrectionPreview
    func correct(_ preview: HabitCorrectionPreview, to outcome: HabitDayCorrection, on date: Date, now: Date) throws
    func timer(for habitID: UUID, on date: Date) throws -> HabitTimerState?
    func saveTimer(_ state: HabitTimerState, now: Date) throws
    func resetTimer(for habitID: UUID) throws
    func logTimer(habitID: UUID, now: Date) throws
}

extension HabitActivityConfiguration {
    static func active(from values: [Self], dayKey: String) -> Self? {
        values.filter { $0.effectiveDayKey <= dayKey }.max {
            ($0.effectiveDayKey, $0.revision) < ($1.effectiveDayKey, $1.revision)
        }
    }
}
