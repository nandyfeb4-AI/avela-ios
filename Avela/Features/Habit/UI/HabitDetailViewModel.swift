import Foundation
import OSLog
import Observation

/// Display-ready projection of a habit's detail screen. Pure data — the view
/// only renders these fields; `HabitDetailViewModel` is the only place that
/// composes `HabitRepository` reads with `HabitProgressCalculator`.
struct HabitDetailDisplay: Equatable {
    let name: String
    let iconName: String
    let categoryLabel: String
    let polarityLabel: String
    let scheduleLabel: String
    let isCompletedToday: Bool
    /// Polarity-aware wording for `isCompletedToday` — "Completed"/"Not
    /// completed yet" for `positive` habits, "Logged"/"Not logged yet" for
    /// `avoidance` ones, since an avoidance habit's resolution isn't
    /// accurately described as being "completed." See `HabitPolarityFormatter`.
    let todayStatusLabel: String
    let weeklyProgress: WeeklyProgressDisplay?
    let currentStreakLabel: String
    let bestStreakLabel: String
    /// `nil` whenever recovery framing should not be shown: no miss ever
    /// happened, or the 3-success recovery threshold has already been reached.
    let recoveryMessage: String?
    let consistencyRangeLabel: String
    let consistencyLabel: String
    let isArchived: Bool
    let isSkippedToday: Bool
    let canSkipToday: Bool
}

/// Feature state for the habit detail screen. Read-only with respect to
/// completion (opening detail must never log or undo a completion); editing
/// and archiving go through the same `HabitRepository` operations Today uses.
/// All streak/recovery/consistency math is delegated to
/// `HabitProgressCalculator` — this type only fetches the facts it needs and
/// shapes the result for display.
@MainActor
@Observable
final class HabitDetailViewModel {
    private(set) var display: HabitDetailDisplay?
    private(set) var draft: HabitDraft?
    var isShowingEditForm = false
    var isShowingArchiveConfirmation = false
    var errorMessage: String?
    /// Set once archiving succeeds, so the view can dismiss itself back to Today.
    private(set) var didArchive = false

    let habitID: UUID
    private let repository: HabitRepository
    private let calendar: Calendar
    private static let logger = Logger(subsystem: "com.example.Avela", category: "HabitDetailViewModel")
    private static let friendlyErrorMessage = "Something went wrong. Please try again."
    private static let consistencyWindowInDays = 14

    init(habitID: UUID, repository: HabitRepository, calendar: Calendar = .autoupdatingCurrent) {
        self.habitID = habitID
        self.repository = repository
        self.calendar = calendar
    }

    func load(asOf date: Date = Date()) {
        do {
            guard let habit = try repository.fetchHabit(id: habitID) else {
                errorMessage = Self.friendlyErrorMessage
                return
            }
            draft = HabitDraft(
                name: habit.name, iconName: habit.iconName, category: habit.category,
                polarity: habit.polarity, schedule: habit.schedule
            )

            let historyStart = min(habit.createdAt, date)
            let historyEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
            let historyInterval = DateInterval(start: historyStart, end: historyEnd)
            let snapshots = try repository.configurationHistory(for: habitID)
            let completions = try repository.completions(for: habitID, in: historyInterval)
            let skips = try repository.skips(for: habitID, in: historyInterval)
            let archivePeriods = try repository.archivePeriods(for: habitID)

            let streak = HabitProgressCalculator.streak(
                for: habit, snapshots: snapshots, completions: completions, skips: skips,
                archivePeriods: archivePeriods, asOf: date, calendar: calendar
            )
            let recovery = HabitProgressCalculator.recoveryProgress(
                for: habit, snapshots: snapshots, completions: completions, skips: skips,
                archivePeriods: archivePeriods, asOf: date, calendar: calendar
            )
            // -13, not -14: the window includes today, so 14 total days are
            // [today - 13, today] inclusive, i.e. [today - 13, tomorrow) half-open.
            let windowStart = calendar.date(
                byAdding: .day, value: -(Self.consistencyWindowInDays - 1), to: calendar.startOfDay(for: date)
            ) ?? historyStart
            let consistencyRange = DateInterval(start: windowStart, end: historyEnd)
            let consistency = HabitProgressCalculator.consistency(
                for: habit, snapshots: snapshots, completions: completions, skips: skips,
                archivePeriods: archivePeriods, in: consistencyRange, asOf: date, calendar: calendar
            )

            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
            let isCompletedToday = completions.contains { $0.occurredAt >= dayStart && $0.occurredAt < dayEnd }

            var weeklyProgress: WeeklyProgressDisplay?
            if case .timesPerWeek(let target) = habit.schedule {
                let weekInterval = LocalDay.weekInterval(containing: date, calendar: calendar)
                let weekCompletions = try repository.completions(for: habitID, in: weekInterval)
                let progress = HabitScheduleEvaluator.weeklyProgress(
                    habitID: habitID, target: target, completions: weekCompletions, on: date, calendar: calendar
                )
                weeklyProgress = WeeklyProgressDisplay(completed: progress.completedCount, target: progress.target)
            }

            display = HabitDetailDisplay(
                name: habit.name,
                iconName: habit.iconName,
                categoryLabel: habit.category.rawValue.capitalized,
                polarityLabel: habit.polarity == .positive ? "Build Up" : "Cut Down",
                scheduleLabel: HabitScheduleFormatter.description(for: habit.schedule),
                isCompletedToday: isCompletedToday,
                todayStatusLabel: HabitPolarityFormatter.statusLabel(isCompleted: isCompletedToday, polarity: habit.polarity),
                weeklyProgress: weeklyProgress,
                currentStreakLabel: Self.streakLabel(streak.currentStreak, unit: streak.unit, zeroText: "No current streak yet"),
                bestStreakLabel: Self.streakLabel(streak.bestStreak, unit: streak.unit, zeroText: "No streak yet"),
                recoveryMessage: Self.recoveryMessage(recovery, unit: streak.unit),
                consistencyRangeLabel: "Last \(Self.consistencyWindowInDays) Days",
                consistencyLabel: Self.consistencyLabel(consistency, unit: streak.unit),
                isArchived: habit.isArchived,
                isSkippedToday: skips.contains { $0.localDateKey == LocalDay.key(for: date, calendar: calendar) },
                canSkipToday: !habit.isArchived && !isCompletedToday && HabitScheduleEvaluator.isDue(habit.schedule, on: date, calendar: calendar)

            )
        } catch {
            handle(error)
        }
    }

    func saveEdits(_ updatedDraft: HabitDraft, asOf date: Date = Date()) {
        do {
            _ = try repository.updateHabit(id: habitID, with: updatedDraft, at: date)
            isShowingEditForm = false
            load(asOf: date)
        } catch {
            handle(error)
        }
    }

    func toggleSkip(asOf date: Date = Date()) {
        do {
            guard let habit = try repository.fetchHabit(id: habitID), !habit.isArchived else { return }
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            let interval = DateInterval(start: start, end: end)
            let skips = try repository.skips(for: habitID, in: interval)
            if !skips.isEmpty {
                for skip in skips { try repository.undoSkip(id: skip.id) }
            } else {
                guard HabitScheduleEvaluator.isDue(habit.schedule, on: date, calendar: calendar),
                      try repository.completions(for: habitID, in: interval).isEmpty else { return }
                try repository.recordSkip(habitID: habitID, on: date, reason: .planned)
            }
            load(asOf: date)
        } catch { handle(error) }
    }

    func archive(asOf date: Date = Date()) {
        do {
            try repository.archiveHabit(id: habitID, at: date)
            isShowingArchiveConfirmation = false
            didArchive = true
        } catch {
            handle(error)
        }
    }

    private func handle(_ error: Error) {
        Self.logger.error("Habit detail view model operation failed: \(String(describing: error), privacy: .private)")
        errorMessage = Self.friendlyErrorMessage
    }

    private static func streakLabel(_ count: Int, unit: HabitProgressCalculator.StreakUnit, zeroText: String) -> String {
        guard count > 0 else { return zeroText }
        let noun = unit == .days ? "day" : "week"
        return "\(count)-\(noun) streak"
    }

    private static func recoveryMessage(
        _ recovery: HabitProgressCalculator.RecoveryProgress, unit: HabitProgressCalculator.StreakUnit
    ) -> String? {
        guard recovery.isRecovering else { return nil }
        guard recovery.consecutiveSuccessesSinceMiss > 0 else {
            return "You're rebuilding momentum."
        }
        let noun = unit == .days ? "day" : "week"
        let plural = recovery.consecutiveSuccessesSinceMiss == 1 ? noun : "\(noun)s"
        return "\(recovery.consecutiveSuccessesSinceMiss) good \(plural) since your miss."
    }

    private static func consistencyLabel(
        _ consistency: HabitProgressCalculator.ConsistencyResult, unit: HabitProgressCalculator.StreakUnit
    ) -> String {
        guard consistency.scheduledUnits > 0 else { return "Not enough data yet" }
        let noun = unit == .days ? "day" : "week"
        let plural = consistency.scheduledUnits == 1 ? noun : "\(noun)s"
        let percent = Int((consistency.percentage * 100).rounded())
        return "\(consistency.successfulUnits) of \(consistency.scheduledUnits) \(plural) (\(percent)%)"
    }
}
