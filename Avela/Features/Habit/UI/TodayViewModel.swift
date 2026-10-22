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
    var quantityTarget: HabitQuantityTarget? = nil
    var activityConfigurationID: UUID? = nil
    var quickAmount: Int? = nil
    /// Captures the displayed civil day; identical-looking rows cannot move a
    /// stale action across midnight.
    var trackingDayKey: String? = nil
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
    private let quickLogPresets: HabitQuickLogPresets
    private static let logger = Logger(subsystem: "com.example.Avela", category: "TodayViewModel")
    private static let friendlyErrorMessage = "Something went wrong. Please try again."

    init(repository: HabitRepository, calendar: Calendar = .autoupdatingCurrent, presets: HabitQuickLogPresets? = nil) {
        self.repository = repository
        self.calendar = calendar
        quickLogPresets = presets ?? HabitQuickLogPresets()
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
        errorMessage = nil
        do {
            let dayKey = LocalDay.key(for: date, calendar: calendar)
            guard row.trackingDayKey == dayKey,
                  let habit = try repository.fetchHabit(id: row.id), !habit.isArchived,
                  habit.createdAt <= date,
                  let schedule = try repository.activeConfiguration(for: row.id, on: date)?.schedule,
                  HabitScheduleEvaluator.isDue(schedule, on: date, calendar: calendar) else {
                load(asOf: date)
                errorMessage = "This check-in has changed. Review today's habits and try again."
                return
            }
            // Amount-generated success belongs to its recorded entries. A
            // stale simple-check-in control cannot erase that derived fact
            // while leaving the target-reaching quantity unchanged.
            let currentActivity = try activityRepository?.configuration(for: row.id, on: date)
            guard !row.requiresQuantityLogging && currentActivity?.target == nil else {
                load(asOf: date)
                errorMessage = "Open this habit's progress to review its recorded amounts."
                return
            }
            let interval = try currentDayInterval(date)
            let completions = try repository.completions(for: row.id, in: interval)
            if let completionID = row.todaysCompletionID {
                guard completions.contains(where: { $0.id == completionID && $0.localDateKey == dayKey }) else {
                    load(asOf: date)
                    errorMessage = "This check-in has changed. Your current progress is unchanged."
                    return
                }
                try repository.undoCompletion(id: completionID)
            } else {
                // Multiple activations of the same displayed Log control must
                // not add duplicate facts or replace an independently saved log.
                guard completions.isEmpty else { load(asOf: date); return }
                let skips = try repository.skips(for: row.id, in: interval)
                guard row.isSkippedToday || skips.isEmpty else {
                    load(asOf: date)
                    errorMessage = "This day was skipped after the screen loaded. Review it before logging."
                    return
                }
                try repository.validateCompletion(habitID: row.id, at: date)
                for skip in skips {
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
    @discardableResult
    func undoTodayCompletion(id: UUID, habitID: UUID, asOf date: Date = Date()) -> Bool {
        errorMessage = nil
        do {
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            let active = try repository.fetchHabits(includeArchived: false).contains { $0.id == habitID }
            let records = try repository.completions(for: habitID, in: DateInterval(start: start, end: end))
            let dayKey = LocalDay.key(for: date, calendar: calendar)
            guard active && records.contains(where: { $0.id == id && $0.localDateKey == dayKey }) else {
                load(asOf: date)
                errorMessage = "That check-in is no longer available to undo here. Open the habit to review its progress."
                return false
            }
            try repository.undoCompletion(id: id)
            load(asOf: date)
            return true
        } catch { handle(error); return false }
    }

    /// A quantity shortcut uses the same canonical writer as the full logger.
    /// The returned ID identifies only this new entry for a deliberate Undo.
    @discardableResult
    func logQuickAmount(for row: TodayHabitRow, asOf date: Date = Date()) -> HabitActivityEntry? {
        errorMessage = nil
        var didSave = false
        do {
            guard let activityRepository,
                  row.trackingDayKey == LocalDay.key(for: date, calendar: calendar),
                  let habit = try repository.fetchHabit(id: row.id), !habit.isArchived,
                  habit.createdAt <= date, habit.polarity == .positive,
                  let schedule = try repository.activeConfiguration(for: row.id, on: date)?.schedule,
                  HabitScheduleEvaluator.isDue(schedule, on: date, calendar: calendar),
                  let config = try activityRepository.configuration(for: row.id, on: date),
                  config.id == row.activityConfigurationID,
                  let target = config.target, target == row.quantityTarget,
                  let amount = row.quickAmount, (1...10_000).contains(amount) else {
                throw HabitActivityError.staleConfiguration
            }
            let interval = try currentDayInterval(date)
            guard try repository.skips(for: row.id, in: interval).isEmpty else {
                throw HabitActivityError.unavailableDay
            }
            let existingIDs = Set(try activityRepository.entries(for: row.id, on: date).map(\.id))
            try activityRepository.log(habitID: row.id, kind: .quantity, amount: amount,
                expectedConfigurationID: config.id, on: date, now: date)
            didSave = true
            let added = try activityRepository.entries(for: row.id, on: date).filter {
                !existingIDs.contains($0.id) && $0.kind == .quantity
                    && $0.configurationID == config.id && $0.amount == amount && $0.unit == target.unit
            }
            load(asOf: date)
            guard added.count == 1 else {
                errorMessage = "Progress saved. Open the habit to review your entries."
                return nil
            }
            return added[0]
        } catch {
            if didSave {
                // Never present an export/read failure as a failed write that
                // invites a second additive log of the same intended amount.
                load(asOf: date)
                errorMessage = "Progress saved. Open the habit to review your entries."
            } else { handle(error) }
            return nil
        }
    }

    @discardableResult
    func undoQuickAmount(entryID: UUID, habitID: UUID, asOf date: Date = Date()) -> Bool {
        errorMessage = nil
        do {
            guard let activityRepository,
                  let habit = try repository.fetchHabit(id: habitID), !habit.isArchived,
                  let entry = try activityRepository.entries(for: habitID, on: date).first(where: { $0.id == entryID }),
                  entry.habitID == habitID, entry.kind == .quantity,
                  entry.dayKey == LocalDay.key(for: date, calendar: calendar), entry.loggedAt <= date else {
                load(asOf: date)
                errorMessage = "That amount is no longer available to undo here. Open the habit to review its entries."
                return false
            }
            try activityRepository.removeEntry(id: entry.id, now: date)
            load(asOf: date)
            return true
        } catch { handle(error); return false }
    }

    private func currentDayInterval(_ date: Date) throws -> DateInterval {
        guard let interval = calendar.dateInterval(of: .day, for: date) else { throw HabitActivityError.unavailableDay }
        return interval
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
            quantityProgress: quantity.map { "\(total) of \($0.amount) \($0.unit.name(for: $0.amount))" },
            requiresQuantityLogging: quantity != nil,
            quantityTarget: quantity,
            activityConfigurationID: activityConfig?.id,
            quickAmount: quantity.flatMap { quickLogPresets.amounts(for: habit.id, unit: $0.unit).first },
            trackingDayKey: LocalDay.key(for: date, calendar: calendar)
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
