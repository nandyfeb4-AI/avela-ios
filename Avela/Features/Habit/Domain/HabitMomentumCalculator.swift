import Foundation

/// Momentum is an explainable collection of recorded facts, not a weighted
/// score or a prediction. Smaller effort never becomes a full success.
enum HabitMomentumCalculator {
    struct Summary: Equatable {
        let recentSuccessful: Int
        let recentResolved: Int
        let recoverySuccessful: Int
        let isRecovering: Bool
        let recoveryUnit: String
        let lifetime: HabitLifetimeCalculator.Summary
        var recentPercentage: Int? {
            recentResolved > 0 ? Int((Double(recentSuccessful) / Double(recentResolved) * 100).rounded()) : nil
        }
    }

    static func summarize(habit: Habit, snapshots: [HabitConfigurationSnapshot],
                          completions: [Completion], skips: [Skip],
                          archivePeriods: [HabitArchivePeriod], entries: [HabitActivityEntry],
                          asOf date: Date, calendar: Calendar) -> Summary {
        let today = calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .day, value: -13, to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? date
        let recent = HabitProgressCalculator.consistency(
            for: habit, snapshots: snapshots, completions: completions, skips: skips,
            archivePeriods: archivePeriods, in: DateInterval(start: start, end: end),
            asOf: date, calendar: calendar)
        let recovery = HabitProgressCalculator.recoveryProgress(
            for: habit, snapshots: snapshots, completions: completions, skips: skips,
            archivePeriods: archivePeriods, asOf: date, calendar: calendar)
        let periods = HabitProgressCalculator.periods(
            for: habit, snapshots: snapshots, completions: completions, skips: skips,
            archivePeriods: archivePeriods, asOf: date, calendar: calendar)
        let suffix = periods.dropFirst(periods.lastIndex(where: { $0.outcome == .miss }).map { $0 + 1 } ?? 0)
        let units = Set(suffix.filter { $0.outcome == .success }.map { $0.unit == .days ? "days" : "weeks" })
        let activeUnit = HabitProgressCalculator.streak(
            for: habit, snapshots: snapshots, completions: completions, skips: skips,
            archivePeriods: archivePeriods, asOf: date, calendar: calendar).unit
        let unit = units.count > 1 ? "commitments" : (units.first ?? (activeUnit == .days ? "days" : "weeks"))
        return Summary(recentSuccessful: recent.successfulUnits, recentResolved: recent.scheduledUnits,
                       recoverySuccessful: recovery.consecutiveSuccessesSinceMiss,
                       isRecovering: recovery.isRecovering, recoveryUnit: unit,
                       lifetime: HabitLifetimeCalculator.summarize(habitID: habit.id, completions: completions,
                                                                  entries: entries, asOf: date))
    }
}
