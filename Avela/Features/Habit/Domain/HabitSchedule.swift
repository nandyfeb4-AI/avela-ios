import Foundation

/// Mirrors `Calendar`'s `.weekday` component numbering (Sunday = 1 ... Saturday = 7)
/// so conversion to and from `Calendar` output needs no lookup table.
enum Weekday: Int, CaseIterable, Codable, Hashable, Sendable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    init?(calendarWeekday: Int) {
        self.init(rawValue: calendarWeekday)
    }
}

/// Supported V1 schedule kinds. `custom intervals` are explicitly deferred per
/// DATA_MODEL.md and are not represented here.
enum HabitSchedule: Equatable, Hashable, Sendable {
    case daily
    case weekdays(Set<Weekday>)
    case timesPerWeek(Int)
}
