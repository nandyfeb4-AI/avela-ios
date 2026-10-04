import Foundation

/// Shared presentation formatting for `HabitSchedule`, used by both
/// `TodayViewModel` and `HabitDetailViewModel`. Purely textual — no scheduling
/// logic lives here; it only describes a schedule that `HabitScheduleEvaluator`
/// already resolved.
enum HabitScheduleFormatter {
    static func description(for schedule: HabitSchedule) -> String {
        switch schedule {
        case .daily:
            return "Daily"
        case .weekdays(let days):
            let symbols = Calendar(identifier: .gregorian).shortWeekdaySymbols
            return Weekday.allCases
                .filter { days.contains($0) }
                .map { symbols[$0.rawValue - 1] }
                .joined(separator: ", ")
        case .timesPerWeek(let count):
            return "\(count)x / week"
        }
    }
}
