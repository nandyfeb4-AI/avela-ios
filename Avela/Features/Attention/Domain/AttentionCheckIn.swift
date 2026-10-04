import Foundation

/// Explicit self-report, never inferred from elapsed time or missing usage.
enum AttentionCheckInOutcome: String, Codable, Sendable {
    case kept
    case interrupted
}

struct AttentionCheckIn: Identifiable, Equatable, Sendable {
    let id: UUID
    let attentionGoalID: UUID
    let localDateKey: String
    let windowStart: Date
    let windowEnd: Date
    let outcome: AttentionCheckInOutcome
    let recordedAt: Date
    let revision: Int
}

struct AttentionSession: Identifiable, Equatable, Sendable {
    let id: UUID
    let attentionGoalID: UUID
    let startedAt: Date
    let expectedEnd: Date
    let targetMinutes: Double
    let endedAt: Date?
    let outcome: AttentionCheckInOutcome?
    var isActive: Bool { endedAt == nil }
}

/// Uses calendar arithmetic for wall-clock windows and absolute elapsed time
/// for sessions. Missing spring-forward times move to the next valid time;
/// repeated fall-back times select the first occurrence.
enum AttentionWindowCalculator {
    static func interval(on date: Date, startMinute: Int, endMinute: Int, calendar: Calendar) -> DateInterval? {
        guard (0..<1440).contains(startMinute), (0..<1440).contains(endMinute), startMinute != endMinute else { return nil }
        let day = calendar.startOfDay(for: date)
        guard let start = time(on: day, minute: startMinute, calendar: calendar),
              let endDay = endMinute < startMinute ? calendar.date(byAdding: .day, value: 1, to: day) : day,
              let end = time(on: endDay, minute: endMinute, calendar: calendar), end > start else { return nil }
        return DateInterval(start: start, end: end)
    }

    private static func time(on day: Date, minute: Int, calendar: Calendar) -> Date? {
        calendar.nextDate(after: day.addingTimeInterval(-1),
            matching: DateComponents(hour: minute / 60, minute: minute % 60, second: 0),
            matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)
    }
}
