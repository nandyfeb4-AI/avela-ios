import Foundation

struct HabitAdjustmentProposal: Equatable, Sendable {
    let currentSchedule: HabitSchedule
    let suggestedFrequency: Int
    let maximumFrequency: Int
    let recentMisses: Int
    let windowDays: Int
}

/// An optional frequency suggestion, never a completion inference or a coaching service.
enum HabitAdjustmentCalculator {
    static func proposal(
        for habit: Habit, snapshots: [HabitConfigurationSnapshot], completions: [Completion],
        skips: [Skip], archivePeriods: [HabitArchivePeriod], asOf date: Date, calendar: Calendar
    ) -> HabitAdjustmentProposal? {
        guard !habit.isArchived, habit.polarity == .positive else { return nil }
        let frequency: Int
        let windowDays: Int
        switch habit.schedule {
        case .daily: frequency = 7; windowDays = 14
        case .weekdays(let days): frequency = days.count; windowDays = 14
        case .timesPerWeek(let target): frequency = target; windowDays = 28
        }
        guard frequency > 1, frequency <= 7,
              HabitProgressCalculator.recoveryProgress(
                for: habit, snapshots: snapshots, completions: completions, skips: skips,
                archivePeriods: archivePeriods, asOf: date, calendar: calendar
              ).isRecovering,
              let start = calendar.date(byAdding: .day, value: -windowDays, to: calendar.startOfDay(for: date))
        else { return nil }
        let periods = HabitProgressCalculator.periods(
            for: habit, snapshots: snapshots, completions: completions, skips: skips,
            archivePeriods: archivePeriods, asOf: date, calendar: calendar
        )
        let misses = periods.filter { period in
            guard period.outcome == .miss, period.periodStart >= start, period.periodEnd <= date,
                  let configuration = HabitScheduleEvaluator.activeConfiguration(from: snapshots, onKey: period.localDateKey)
            else { return false }
            return configuration.schedule == habit.schedule && configuration.polarity == .positive
        }.count
        guard misses >= 2 else { return nil }
        return HabitAdjustmentProposal(currentSchedule: habit.schedule,
            suggestedFrequency: habit.schedule == .daily ? 3 : frequency - 1,
            maximumFrequency: frequency - 1, recentMisses: misses, windowDays: windowDays)
    }
}
