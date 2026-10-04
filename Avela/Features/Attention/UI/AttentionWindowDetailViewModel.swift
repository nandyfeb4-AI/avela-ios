import Foundation
import Observation
import OSLog

struct AttentionWindowSummary {
    let targetLabel: String
    let statusLabel: String
    let state: AttentionProgressCalculator.ThresholdState?

    static func windowDay(for date: Date, configuration: AttentionGoalConfigurationSnapshot, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        if let start = configuration.windowStartMinute, let end = configuration.windowEndMinute,
           end < start,
           let current = AttentionWindowCalculator.interval(on: day, startMinute: start, endMinute: end, calendar: calendar),
           date < current.start {
            return calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return day
    }

    /// An overnight window belongs to the day it started. Edits on the
    /// following day cannot relabel or extend that historical commitment.
    @MainActor
    static func resolvedWindow(goal: AttentionGoal, configuration: AttentionGoalConfigurationSnapshot,
                               repository: AttentionRepository, date: Date, calendar: Calendar) throws -> DateInterval? {
        let selectedDay = max(windowDay(for: date, configuration: configuration, calendar: calendar),
                              calendar.startOfDay(for: goal.createdAt))
        guard let historical = try repository.activeConfiguration(for: goal.id, on: selectedDay),
              let start = historical.windowStartMinute, let end = historical.windowEndMinute else { return nil }
        return AttentionWindowCalculator.interval(on: selectedDay, startMinute: start, endMinute: end, calendar: calendar)
    }

    @MainActor
    static func make(goal: AttentionGoal, configuration: AttentionGoalConfigurationSnapshot,
                     repository: AttentionRepository, date: Date, calendar: Calendar) throws -> AttentionWindowSummary {
        if goal.type == .phoneFreeSession {
            let active = try repository.sessions(for: goal.id).last(where: \.isActive)
            let label = "\((active?.targetMinutes ?? configuration.targetValue).formatted()) min phone-free session"
            guard let active else { return AttentionWindowSummary(targetLabel: label, statusLabel: "Start a session when you're ready", state: nil) }
            return AttentionWindowSummary(targetLabel: label,
                statusLabel: date >= active.expectedEnd ? "Time elapsed · confirm your result" : "Session active · self-reported", state: nil)
        }
        guard let interval = try resolvedWindow(goal: goal, configuration: configuration,
                                                repository: repository, date: date, calendar: calendar) else {
            return AttentionWindowSummary(targetLabel: "Protected window", statusLabel: "Not reported yet", state: nil)
        }
        let day = calendar.startOfDay(for: interval.start)
        guard let next = calendar.date(byAdding: .day, value: 1, to: day) else {
            return AttentionWindowSummary(targetLabel: "Protected window", statusLabel: "Not reported yet", state: nil)
        }
        // A report only attests to its captured bounds. A same-day edit
        // creates a different commitment and must not inherit the old result.
        let report = try repository.checkIns(for: goal.id, in: DateInterval(start: day, end: next)).last {
            $0.windowStart == interval.start && $0.windowEnd == interval.end
        }
        let overnight = !calendar.isDate(interval.start, inSameDayAs: interval.end)
        let label = "\(interval.start.formatted(date: .omitted, time: .shortened))–\(interval.end.formatted(date: .omitted, time: .shortened))\(overnight ? " overnight" : "")"
        return AttentionWindowSummary(targetLabel: label,
            statusLabel: report.map { $0.outcome == .kept ? "Kept · reported manually" : "Interrupted · reported manually" } ?? "Not reported yet · manual check-in",
            state: nil)
    }
}

@MainActor
@Observable
final class AttentionWindowDetailViewModel {
    let goalID: UUID
    private let repository: AttentionRepository
    private let calendar: Calendar
    private(set) var presentationDate = Date()
    private(set) var name = ""
    private(set) var goalType: AttentionGoalType = .noUseBeforeTime
    private(set) var summary: AttentionWindowSummary?
    private(set) var draft: AttentionGoalDraft?
    private(set) var window: DateInterval?
    private(set) var activeSession: AttentionSession?
    private(set) var sessionHistory: [AttentionSession] = []
    var isEditing = false
    var errorMessage: String?

    init(goalID: UUID, repository: AttentionRepository, calendar: Calendar = .autoupdatingCurrent) {
        self.goalID = goalID
        self.repository = repository
        self.calendar = calendar
    }

    func load(asOf date: Date = Date()) {
        presentationDate = date
        do {
            guard let goal = try repository.fetchGoal(id: goalID),
                  let configuration = try repository.activeConfiguration(for: goalID, on: date) else {
                throw AttentionRepositoryError.goalNotFound(goalID)
            }
            name = goal.name
            goalType = goal.type
            draft = AttentionGoalDraft(name: goal.name, appOrCategoryLabel: goal.appOrCategoryLabel,
                type: goal.type, targetValue: configuration.targetValue, unit: configuration.unit,
                windowStartMinute: configuration.windowStartMinute, windowEndMinute: configuration.windowEndMinute)
            summary = try AttentionWindowSummary.make(goal: goal, configuration: configuration,
                repository: repository, date: date, calendar: calendar)
            if goal.type == .phoneFreeSession {
                sessionHistory = try repository.sessions(for: goalID)
                activeSession = sessionHistory.last(where: \.isActive)
            } else {
                window = try AttentionWindowSummary.resolvedWindow(goal: goal, configuration: configuration,
                    repository: repository, date: date, calendar: calendar)
            }
            errorMessage = nil
        } catch { handle(error) }
    }

    /// Only transition boundaries need a presentation refresh. This deadline
    /// does not complete a session or report an outcome.
    var refreshDeadline: Date { nextRefreshDate(asOf: presentationDate) }

    func nextRefreshDate(asOf date: Date) -> Date {
        let day = calendar.startOfDay(for: date)
        let midnight = calendar.date(byAdding: .day, value: 1, to: day) ?? date.addingTimeInterval(86400)
        var candidates = [midnight]
        if let activeSession { candidates.append(activeSession.expectedEnd) }
        if let window { candidates.append(contentsOf: [window.start, window.end]) }
        return candidates.filter { $0 > date }.min() ?? date.addingTimeInterval(86400)
    }

    func canReportKept(at date: Date) -> Bool {
        if let activeSession { return date >= activeSession.expectedEnd }
        return window.map { date >= $0.end } ?? false
    }

    func canReportInterrupted(at date: Date) -> Bool {
        if let activeSession { return date >= activeSession.startedAt }
        return window.map { date >= $0.start } ?? false
    }

    func startSession(asOf date: Date = Date()) {
        do { _ = try repository.startSession(goalID: goalID, at: date); load(asOf: date) }
        catch { handle(error) }
    }

    func report(_ outcome: AttentionCheckInOutcome, asOf date: Date = Date()) {
        do {
            if goalType == .phoneFreeSession {
                guard let activeSession else { throw AttentionRepositoryError.invalidCheckIn }
                _ = try repository.finishSession(id: activeSession.id, outcome: outcome, at: date)
            } else {
                guard let window else { throw AttentionRepositoryError.invalidCheckIn }
                _ = try repository.recordCheckIn(goalID: goalID, on: window.start, outcome: outcome, at: date)
            }
            load(asOf: date)
        } catch { handle(error) }
    }

    func saveEdits(_ draft: AttentionGoalDraft, asOf date: Date = Date()) {
        do { _ = try repository.updateGoal(id: goalID, with: draft, at: date); isEditing = false; load(asOf: date) }
        catch { handle(error) }
    }

    private func handle(_ error: Error) {
        Logger(subsystem: "com.example.Avela", category: "AttentionWindow")
            .error("Window operation failed: \(String(describing: error), privacy: .private)")
        errorMessage = "Something went wrong. Please try again."
    }
}
