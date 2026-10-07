import Foundation
import XCTest
@testable import Avela

final class MadeRoomReviewCalculatorTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/Denver")!
        value.firstWeekday = 2
        return value
    }
    private var start: Date { calendar.date(from: DateComponents(year: 2024, month: 3, day: 4))! }
    private var interval: DateInterval { LocalDay.weekInterval(containing: start, calendar: calendar) }
    private func makeHabit(archived: Bool = false) -> Habit {
        Habit(id: UUID(), name: "Read", iconName: "book", category: .learning, polarity: .positive,
              schedule: .daily, createdAt: start, updatedAt: start,
              archivedAt: archived ? interval.end : nil, sortOrder: 0)
    }
    private func makeSession(at date: Date? = nil, duration: Double? = 900,
                         outcome: AttentionCheckInOutcome? = .kept) -> AttentionSession {
        let date = date ?? start
        return AttentionSession(id: UUID(), attentionGoalID: UUID(), startedAt: date,
                                expectedEnd: date.addingTimeInterval(900), targetMinutes: 15,
                                endedAt: duration.map { date.addingTimeInterval($0) }, outcome: outcome)
    }
    private func makeLink(_ session: AttentionSession, to habit: Habit) -> IntentionSessionLink {
        IntentionSessionLink(id: UUID(), habitID: habit.id, sessionID: session.id, createdAt: session.startedAt)
    }
    private func calculate(_ habits: [Habit], _ links: [IntentionSessionLink], _ sessions: [AttentionSession],
                           completions: [Completion] = []) -> MadeRoomReviewCalculator.Review {
        MadeRoomReviewCalculator.calculate(habits: habits, links: links, sessions: sessions,
                                           completions: completions, interval: interval, calendar: calendar)
    }

    func testHalfOpenWeekUsesSessionStartEvenWhenSessionEndsInNextWeek() {
        let habit = makeHabit()
        let before = makeSession(at: start.addingTimeInterval(-1))
        let first = makeSession()
        let last = makeSession(at: interval.end.addingTimeInterval(-60), duration: 120)
        let next = makeSession(at: interval.end)
        let sessions = [before, first, last, next]
        let result = calculate([habit], sessions.map { makeLink($0, to: habit) }, sessions)
        XCTAssertEqual(result.sessionCount, 2)
        XCTAssertEqual(result.timerSeconds, 1020)
        XCTAssertEqual(interval.duration, 7 * 86400 - 3600, "A spring-forward week has seven civil days, not 168 elapsed hours")
    }

    func testDuplicateLinksAndSessionCopiesNeverInflateTotals() {
        let habit = makeHabit()
        let session = makeSession()
        let link = makeLink(session, to: habit)
        let result = calculate([habit], [link, link], [session, session])
        XCTAssertEqual(result.sessionCount, 1)
        XCTAssertEqual(result.keptSessions, 1)
        XCTAssertEqual(result.timerSeconds, 900)
    }

    func testContradictoryOwnersAndMissingSessionsAreOmittedWithoutArbitraryAttribution() {
        let first = makeHabit(), second = makeHabit()
        let session = makeSession(), missing = makeSession()
        let result = calculate([first, second], [makeLink(session, to: first), makeLink(session, to: second), makeLink(missing, to: first)], [session])
        XCTAssertTrue(result.habits.isEmpty)
        XCTAssertEqual(result.omittedLinkCount, 2)
    }

    func testActiveAndEndedUnreportedSessionsStayNeutralAndActiveTimerIsExcluded() {
        let habit = makeHabit()
        let active = makeSession(duration: nil, outcome: nil)
        let ended = makeSession(duration: 1200, outcome: nil)
        let interrupted = makeSession(duration: 300, outcome: .interrupted)
        let result = calculate([habit], [active, ended, interrupted].map { makeLink($0, to: habit) }, [active, ended, interrupted])
        XCTAssertEqual(result.keptSessions, 0)
        XCTAssertEqual(result.interruptedSessions, 1)
        XCTAssertEqual(result.unreportedSessions, 2)
        XCTAssertEqual(result.timerSeconds, 1500)
        XCTAssertEqual(result.habits.first?.successfulCheckInDays, 0, "Elapsed/kept sessions never imply habit completion")
    }

    func testArchivedHabitAndStoredCivilKeysArePreservedWithIndependentDeduplicatedCheckIns() {
        let habit = makeHabit(archived: true)
        let session = makeSession()
        let entries = [
            Completion(id: UUID(), habitID: habit.id, occurredAt: start.addingTimeInterval(-60), localDateKey: "2024-03-04", source: .app, note: nil),
            Completion(id: UUID(), habitID: habit.id, occurredAt: start, localDateKey: "2024-03-04", source: .quantity, note: nil),
            Completion(id: UUID(), habitID: habit.id, occurredAt: interval.end, localDateKey: "2024-03-11", source: .app, note: nil)
        ]
        let result = calculate([habit], [makeLink(session, to: habit)], [session], completions: entries)
        XCTAssertTrue(result.habits.first?.isArchived == true)
        XCTAssertEqual(result.habits.first?.successfulCheckInDays, 1)
        XCTAssertEqual(result.sessionCount, 1)
    }

    func testUnlinkedSessionsAndUnrelatedHabitCheckInsAreNotAttributed() {
        let habit = makeHabit(), unrelated = makeHabit()
        let linked = makeSession(), unlinked = makeSession()
        let completion = Completion(id: UUID(), habitID: unrelated.id, occurredAt: start, localDateKey: "2024-03-04", source: .app, note: nil)
        let result = calculate([habit, unrelated], [makeLink(linked, to: habit)], [linked, unlinked], completions: [completion])
        XCTAssertEqual(result.sessionCount, 1)
        XCTAssertEqual(result.habits.count, 1)
        XCTAssertEqual(result.habits.first?.successfulCheckInDays, 0)
    }

    func testInvalidTimerDurationCannotProduceNegativeOrImplausibleMinutes() {
        let habit = makeHabit()
        let invalid = makeSession(duration: -30), excessive = makeSession(duration: 8 * 86400)
        let result = calculate([habit], [invalid, excessive].map { makeLink($0, to: habit) }, [invalid, excessive])
        XCTAssertEqual(result.timerSeconds, 0)
        XCTAssertEqual(result.omittedTimerCount, 2)
        XCTAssertEqual(result.keptSessions, 2, "A self-reported outcome and a usable timer are distinct facts")
    }
}
