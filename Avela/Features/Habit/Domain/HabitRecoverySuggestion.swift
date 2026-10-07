import Foundation

/// An explainable option derived only from recorded commitments. It neither
/// diagnoses overload nor changes a target, creates effort, or logs success.
struct HabitRecoverySuggestion: Equatable, Sendable {
    let recentMisses: Int
    let windowDays: Int
    let unit: HabitProgressCalculator.StreakUnit
    let smallerAction: String?
    let configurationRevision: Int

    var reason: String {
        let commitments = unit == .weeks ? "weekly commitments" : "scheduled days"
        return "\(recentMisses) \(commitments) have no success check-in in the last \(windowDays) days."
    }
}

enum HabitRecoverySuggestionCalculator {
    static func suggestion(
        for habit: Habit, snapshots: [HabitConfigurationSnapshot], completions: [Completion],
        skips: [Skip], archivePeriods: [HabitArchivePeriod], smallerAction: String?,
        asOf date: Date, calendar: Calendar
    ) -> HabitRecoverySuggestion? {
        guard !habit.isArchived, habit.polarity == .positive,
              let current = HabitScheduleEvaluator.activeConfiguration(from: snapshots, on: date, calendar: calendar),
              current.schedule == habit.schedule, current.polarity == .positive,
              HabitProgressCalculator.recoveryProgress(for: habit, snapshots: snapshots,
                completions: completions, skips: skips, archivePeriods: archivePeriods,
                asOf: date, calendar: calendar).isRecovering else { return nil }
        let weekly: Bool
        if case .timesPerWeek = habit.schedule { weekly = true } else { weekly = false }
        let windowDays = weekly ? 28 : 14
        let today = calendar.startOfDay(for: date)
        guard let start = calendar.date(byAdding: .day, value: -windowDays, to: today) else { return nil }
        let periods = HabitProgressCalculator.periods(for: habit, snapshots: snapshots,
            completions: completions, skips: skips, archivePeriods: archivePeriods,
            asOf: date, calendar: calendar)
        // A recorded success or excused check-in in the current period already
        // answers today's invitation. A non-scheduled day needs no invitation.
        guard let currentPeriod = periods.last,
              currentPeriod.periodStart <= date, date < currentPeriod.periodEnd,
              currentPeriod.outcome == .pending else { return nil }
        let misses = periods.filter { period in
            guard period.outcome == .miss, period.periodStart >= start,
                  period.periodEnd <= today,
                  let configuration = HabitScheduleEvaluator.activeConfiguration(from: snapshots, onKey: period.localDateKey)
            else { return false }
            // Only the current configuration supplies evidence. An old schedule
            // returning later does not inherit the old configuration's misses.
            return configuration.revision == current.revision
                && configuration.schedule == current.schedule && configuration.polarity == current.polarity
        }.count
        guard misses >= 2 else { return nil }
        let action = smallerAction?.trimmingCharacters(in: .whitespacesAndNewlines)
        return HabitRecoverySuggestion(recentMisses: misses, windowDays: windowDays,
            unit: weekly ? .weeks : .days, smallerAction: action?.isEmpty == false ? action : nil,
            configurationRevision: current.revision)
    }
}
