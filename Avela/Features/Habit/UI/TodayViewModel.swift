import Foundation
import OSLog
import Observation

/// Display-ready projection of a `Habit` for the Today screen. Pure data — no
/// SwiftData, no business logic. `TodayViewModel` computes it by composing
/// `HabitRepository` reads with `HabitScheduleEvaluator`; the view only renders it.
struct TodayHabitRow: Identifiable, Equatable {
    let id: UUID
    let name: String
    let iconName: String
    let polarity: HabitPolarity
    let scheduleDescription: String
    let isCompletedToday: Bool
    let todaysCompletionID: UUID?
    let weeklyProgress: WeeklyProgressDisplay?
    /// Short recovery framing ("Rebuilding · 2 of 3 good days") shown instead
    /// of the plain schedule context while `RecoveryProgress.isRecovering` is
    /// true — the same rule `HabitDetailViewModel` already uses, surfaced on
    /// Today too, since UX.md's priority order puts "what needs recovery?"
    /// ahead of "what is my attention state?" and Today previously answered
    /// it nowhere. `nil` whenever recovery framing should not be shown.
    let recoveryContext: String?
    var isSkippedToday: Bool = false
}

struct WeeklyProgressDisplay: Equatable {
    let completed: Int
    let target: Int
}

/// Feature state for the Today screen. Owns no persistence of its own: every
/// read and write goes through the injected `HabitRepository` protocol, and
/// all scheduling/progress math is delegated to `HabitScheduleEvaluator` — this
/// type only composes those calls and shapes the result for the view.
@MainActor
@Observable
final class TodayViewModel {
    private(set) var rows: [TodayHabitRow] = []
    var isShowingCreateHabit = false
    var errorMessage: String?
    var isShowingPremium = false
    var creationAllowed: (Int) -> Bool = { _ in true }

    func requestCreation() {
        do {
            let count = try repository.fetchHabits(includeArchived: false).count
            if creationAllowed(count) { isShowingCreateHabit = true }
            else { isShowingPremium = true }
        } catch { handle(error) }
    }

    private let repository: HabitRepository
    private let calendar: Calendar
    private static let logger = Logger(subsystem: "com.example.Avela", category: "TodayViewModel")
    private static let friendlyErrorMessage = "Something went wrong. Please try again."

    init(repository: HabitRepository, calendar: Calendar = .autoupdatingCurrent) {
        self.repository = repository
        self.calendar = calendar
    }

    func load(asOf date: Date = Date()) {
        do {
            let habits = try repository.fetchHabits(includeArchived: false)
            rows = try habits
                .filter { HabitScheduleEvaluator.isDue($0.schedule, on: date, calendar: calendar) }
                .map { try row(for: $0, asOf: date) }
        } catch {
            handle(error)
        }
    }

    func createHabit(_ draft: HabitDraft, asOf date: Date = Date()) {
        do {
            guard creationAllowed(try repository.fetchHabits(includeArchived: false).count) else {
                isShowingCreateHabit = false
                isShowingPremium = true
                return
            }
            _ = try repository.createHabit(draft, at: date)
            isShowingCreateHabit = false
            load(asOf: date)
        } catch {
            handle(error)
        }
    }

    func toggleCompletion(for row: TodayHabitRow, asOf date: Date = Date()) {
        do {
            if let completionID = row.todaysCompletionID {
                try repository.undoCompletion(id: completionID)
            } else {
                let start = calendar.startOfDay(for: date)
                let end = calendar.date(byAdding: .day, value: 1, to: start)!
                for skip in try repository.skips(for: row.id, in: DateInterval(start: start, end: end)) {
                    try repository.undoSkip(id: skip.id)
                }
                _ = try repository.recordCompletion(habitID: row.id, at: date, source: .app, note: nil)
            }
            load(asOf: date)
        } catch {
            handle(error)
        }
    }

    private func row(for habit: Habit, asOf date: Date) throws -> TodayHabitRow {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
        let todaysCompletion = try repository.completions(for: habit.id, in: DateInterval(start: dayStart, end: dayEnd)).first

        var weeklyProgress: WeeklyProgressDisplay?
        if case .timesPerWeek(let target) = habit.schedule {
            let weekInterval = LocalDay.weekInterval(containing: date, calendar: calendar)
            let weekCompletions = try repository.completions(for: habit.id, in: weekInterval)
            let progress = HabitScheduleEvaluator.weeklyProgress(
                habitID: habit.id, target: target, completions: weekCompletions, on: date, calendar: calendar
            )
            weeklyProgress = WeeklyProgressDisplay(completed: progress.completedCount, target: progress.target)
        }

        return TodayHabitRow(
            id: habit.id,
            name: habit.name,
            iconName: habit.iconName,
            polarity: habit.polarity,
            scheduleDescription: HabitScheduleFormatter.description(for: habit.schedule),
            isCompletedToday: todaysCompletion != nil,
            todaysCompletionID: todaysCompletion?.id,
            weeklyProgress: weeklyProgress,
            recoveryContext: try recoveryContext(for: habit, asOf: date),
            isSkippedToday: try !repository.skips(for: habit.id, in: DateInterval(start: dayStart, end: dayEnd)).isEmpty
        )
    }

    private func recoveryContext(for habit: Habit, asOf date: Date) throws -> String? {
        let historyStart = min(habit.createdAt, date)
        let historyEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        let historyInterval = DateInterval(start: historyStart, end: historyEnd)
        let snapshots = try repository.configurationHistory(for: habit.id)
        let completions = try repository.completions(for: habit.id, in: historyInterval)
        let skips = try repository.skips(for: habit.id, in: historyInterval)
        let archivePeriods = try repository.archivePeriods(for: habit.id)

        let recovery = HabitProgressCalculator.recoveryProgress(
            for: habit, snapshots: snapshots, completions: completions, skips: skips,
            archivePeriods: archivePeriods, asOf: date, calendar: calendar
        )
        guard recovery.isRecovering else { return nil }
        let streak = HabitProgressCalculator.streak(
            for: habit, snapshots: snapshots, completions: completions, skips: skips,
            archivePeriods: archivePeriods, asOf: date, calendar: calendar
        )
        // Always plural ("of 3 good days"), even when the count itself is 1:
        // the plural agrees with the "3"-day/week set being measured against,
        // not with the count, the same way "1 of 3 apples" reads correctly.
        let plural = streak.unit == .days ? "days" : "weeks"
        let threshold = HabitProgressCalculator.recoveryCompletionThreshold
        return "Rebuilding · \(recovery.consecutiveSuccessesSinceMiss) of \(threshold) good \(plural)"
    }

    private func handle(_ error: Error) {
        Self.logger.error("Today view model operation failed: \(String(describing: error), privacy: .private)")
        errorMessage = Self.friendlyErrorMessage
    }
}
