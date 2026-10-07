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
    /// Spoken context remains available on the habit control; the visual
    /// treatment lives in a dedicated, typed recovery card.
    let recoveryContext: String?
    var recovery: TodayRecoveryDisplay? = nil
    var isSkippedToday: Bool = false
    var quantityProgress: String? = nil
    var requiresQuantityLogging: Bool = false
}

/// Presentation composed from the same historical periods used by streaks.
/// Mixed day/week runs are called commitments, never relabeled as days or weeks.
struct TodayRecoveryDisplay: Equatable {
    let completed: Int
    let target: Int
    let unit: String
    let canMakeEasier: Bool
    let smallerAction: String?
    var suggestion: HabitRecoverySuggestion? = nil
    var progressLabel: String { "\(completed) of \(target) good \(unit)" }
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
    private(set) var activeHabitCount = 0
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

    var activityRepository: HabitActivityRepository?
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
            activeHabitCount = habits.count
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

    /// Undo targets the exact logged fact, never a toggle of a refreshed row.
    /// A confirmation kept open across midnight must not log or undo another day.
    func undoTodayCompletion(id: UUID, habitID: UUID, asOf date: Date = Date()) {
        do {
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            let active = try repository.fetchHabits(includeArchived: false).contains { $0.id == habitID }
            let records = try repository.completions(for: habitID, in: DateInterval(start: start, end: end))
            if active && records.contains(where: { $0.id == id }) {
                try repository.undoCompletion(id: id)
            }
            load(asOf: date)
        } catch { handle(error) }
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

        let activityConfig = try activityRepository?.configuration(for: habit.id, on: date)
        let quantity = activityConfig?.target
        let total = try activityRepository?.entries(for: habit.id, on: date).filter { $0.kind == .quantity && $0.unit == quantity?.unit }.reduce(0) { $0 + $1.amount } ?? 0
        let recovery = try recoveryDisplay(for: habit, smallerAction: activityConfig?.smallerAction, asOf: date)
        return TodayHabitRow(
            id: habit.id,
            name: habit.name,
            iconName: habit.iconName,
            polarity: habit.polarity,
            scheduleDescription: HabitScheduleFormatter.description(for: habit.schedule),
            isCompletedToday: todaysCompletion != nil,
            todaysCompletionID: todaysCompletion?.id,
            weeklyProgress: weeklyProgress,
            recoveryContext: recovery?.progressLabel,
            recovery: recovery,
            isSkippedToday: try !repository.skips(for: habit.id, in: DateInterval(start: dayStart, end: dayEnd)).isEmpty,
            quantityProgress: quantity.map { "\(total) of \($0.amount) \($0.unit.rawValue)" },
            requiresQuantityLogging: quantity != nil
        )
    }

    private func recoveryDisplay(for habit: Habit, smallerAction: String?, asOf date: Date) throws -> TodayRecoveryDisplay? {
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
        let periods = HabitProgressCalculator.periods(
            for: habit, snapshots: snapshots, completions: completions, skips: skips,
            archivePeriods: archivePeriods, asOf: date, calendar: calendar
        )
        let lastMiss = periods.lastIndex { $0.outcome == .miss }
        let successes = periods.dropFirst(lastMiss.map { $0 + 1 } ?? 0).filter { $0.outcome == .success }
        let mixedUnits = successes.contains { $0.unit != streak.unit }
        let unit = mixedUnits ? "commitments" : (streak.unit == .days ? "days" : "weeks")
        let proposal = HabitAdjustmentCalculator.proposal(
            for: habit, snapshots: snapshots, completions: completions, skips: skips,
            archivePeriods: archivePeriods, asOf: date, calendar: calendar
        )
        let action = smallerAction?.trimmingCharacters(in: .whitespacesAndNewlines)
        let suggestion = HabitRecoverySuggestionCalculator.suggestion(
            for: habit, snapshots: snapshots, completions: completions, skips: skips,
            archivePeriods: archivePeriods, smallerAction: smallerAction, asOf: date, calendar: calendar)
        let alreadyLogged = try activityRepository?.entries(for: habit.id, on: date).contains { $0.kind == .smallerAction } ?? false
        return TodayRecoveryDisplay(
            completed: recovery.consecutiveSuccessesSinceMiss,
            target: HabitProgressCalculator.recoveryCompletionThreshold,
            unit: unit, canMakeEasier: proposal != nil,
            smallerAction: habit.polarity == .positive && action?.isEmpty == false ? action : nil,
            suggestion: alreadyLogged ? nil : suggestion
        )
    }

    private func handle(_ error: Error) {
        Self.logger.error("Today view model operation failed: \(String(describing: error), privacy: .private)")
        errorMessage = Self.friendlyErrorMessage
    }
}
