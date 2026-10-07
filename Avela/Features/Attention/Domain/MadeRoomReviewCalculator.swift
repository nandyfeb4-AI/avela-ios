import Foundation

/// A factual review of explicit intentions. Timer duration is elapsed time,
/// not measured phone avoidance; independent habit check-ins imply no causation.
enum MadeRoomReviewCalculator {
    struct HabitResult: Identifiable, Equatable, Sendable {
        var id: UUID { habitID }
        let habitID: UUID
        let habitName: String
        let isArchived: Bool
        let sessionCount: Int
        let keptSessions: Int
        let interruptedSessions: Int
        let unreportedSessions: Int
        let timerSeconds: TimeInterval
        let successfulCheckInDays: Int
    }

    struct Review: Equatable, Sendable {
        let interval: DateInterval
        let habits: [HabitResult]
        let omittedLinkCount: Int
        let omittedTimerCount: Int
        var sessionCount: Int { habits.reduce(0) { $0 + $1.sessionCount } }
        var keptSessions: Int { habits.reduce(0) { $0 + $1.keptSessions } }
        var interruptedSessions: Int { habits.reduce(0) { $0 + $1.interruptedSessions } }
        var unreportedSessions: Int { habits.reduce(0) { $0 + $1.unreportedSessions } }
        var timerSeconds: TimeInterval { habits.reduce(0) { $0 + $1.timerSeconds } }
    }

    static func calculate(habits: [Habit], links: [IntentionSessionLink], sessions: [AttentionSession],
                          completions: [Completion], interval: DateInterval, calendar: Calendar) -> Review {
        let habitIDs = Set(habits.map(\.id))
        let sessionsByID = Dictionary(grouping: sessions, by: \.id)
        let linksBySession = Dictionary(grouping: links, by: \.sessionID)
        var assigned: [UUID: [AttentionSession]] = [:]
        var omitted = 0
        var omittedTimers = 0
        for (sessionID, candidates) in linksBySession {
            let owners = Set(candidates.map(\.habitID))
            // A contradictory stored link is not attributed to an arbitrary habit.
            guard owners.count == 1, let owner = owners.first, habitIDs.contains(owner),
                  let copies = sessionsByID[sessionID], let session = copies.first,
                  copies.allSatisfy({ $0 == session }) else {
                omitted += 1
                continue
            }
            guard session.startedAt >= interval.start, session.startedAt < interval.end else { continue }
            assigned[owner, default: []].append(session)
        }
        let firstKey = LocalDay.key(for: interval.start, calendar: calendar)
        let endKey = LocalDay.key(for: interval.end, calendar: calendar)
        let rows = habits.compactMap { habit -> HabitResult? in
            guard let own = assigned[habit.id], !own.isEmpty else { return nil }
            let ended = own.filter { $0.endedAt != nil }
            let kept = ended.filter { $0.outcome == .kept }.count
            let interrupted = ended.filter { $0.outcome == .interrupted }.count
            let seconds = ended.reduce(0.0) { total, session in
                guard let end = session.endedAt else { return total }
                let duration = end.timeIntervalSince(session.startedAt)
                // Implausible/corrupt durations are omitted rather than invented.
                guard duration.isFinite, duration >= 0, duration <= 7 * 24 * 3600 else {
                    omittedTimers += 1
                    return total
                }
                return total + duration
            }
            let keys = Set(completions.filter {
                $0.habitID == habit.id && $0.localDateKey >= firstKey && $0.localDateKey < endKey
            }.map(\.localDateKey))
            return HabitResult(habitID: habit.id, habitName: habit.name, isArchived: habit.isArchived,
                               sessionCount: own.count, keptSessions: kept, interruptedSessions: interrupted,
                               unreportedSessions: own.count - kept - interrupted, timerSeconds: seconds,
                               successfulCheckInDays: keys.count)
        }
        return Review(interval: interval, habits: rows, omittedLinkCount: omitted, omittedTimerCount: omittedTimers)
    }
}
