import Foundation
import SwiftData
import XCTest
@testable import Avela

@MainActor
final class MadeRoomReviewViewModelTests: XCTestCase {
    private var container: ModelContainer?
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/Denver")!
        value.firstWeekday = 2
        return value
    }
    private var start: Date { calendar.date(from: DateComponents(year: 2024, month: 3, day: 4))! }
    private var interval: DateInterval { LocalDay.weekInterval(containing: start, calendar: calendar) }

    private final class Links: IntentionSessionLinkRepository {
        var rows: [IntentionSessionLink] = []
        var fails = false
        func links(for habitID: UUID) throws -> [IntentionSessionLink] {
            if fails { throw IntentionSessionLinkError.conflictingIntention }
            return rows.filter { $0.habitID == habitID }
        }
        func save(_ link: IntentionSessionLink) throws { rows.append(link) }
    }

    private func repositories() throws -> (SwiftDataHabitRepository, SwiftDataAttentionRepository, Habit, AttentionGoal, Links) {
        let container = try AppPersistence.makeContainer(inMemory: true)
        self.container = container
        let habits = SwiftDataHabitRepository(modelContext: container.mainContext, calendar: calendar)
        let attention = SwiftDataAttentionRepository(modelContext: container.mainContext, calendar: calendar)
        let habit = try habits.createHabit(HabitDraft(name: "Read", iconName: "book", category: .learning,
                                                     polarity: .positive, schedule: .daily), at: start)
        let goal = try attention.createGoal(AttentionGoalDraft(name: "Reading space", appOrCategoryLabel: nil,
                                                               type: .phoneFreeSession, targetValue: 15, unit: .minutes), at: start)
        return (habits, attention, habit, goal, Links())
    }

    func testPopulatedArchivedReviewIsReadOnlyAndSessionNeverGeneratesHabitSuccess() throws {
        let (habits, attention, habit, goal, links) = try repositories()
        let session = try attention.startSession(goalID: goal.id, at: start.addingTimeInterval(3600))
        try attention.finishSession(id: session.id, outcome: .kept, at: session.expectedEnd)
        try links.save(IntentionSessionLink(id: UUID(), habitID: habit.id, sessionID: session.id, createdAt: session.startedAt))
        try habits.archiveHabit(id: habit.id, at: interval.end)
        let model = MadeRoomReviewViewModel(habits: habits, attention: attention, links: links, interval: interval, calendar: calendar)
        model.load()
        model.load()
        XCTAssertEqual(model.review?.keptSessions, 1)
        XCTAssertEqual(model.review?.timerSeconds, 900)
        XCTAssertEqual(model.review?.habits.first?.successfulCheckInDays, 0)
        XCTAssertTrue(model.review?.habits.first?.isArchived == true)
        XCTAssertEqual(try attention.sessions(for: goal.id).count, 1)
        XCTAssertTrue(try habits.completions(in: interval).isEmpty)
        XCTAssertNil(model.errorMessage)
    }

    func testFailedReloadClearsStaleFactsAndMissingLinkedSessionsRemainPartial() throws {
        let (habits, attention, habit, _, links) = try repositories()
        try links.save(IntentionSessionLink(id: UUID(), habitID: habit.id, sessionID: UUID(), createdAt: start))
        let model = MadeRoomReviewViewModel(habits: habits, attention: attention, links: links, interval: interval, calendar: calendar)
        model.load()
        XCTAssertEqual(model.review?.omittedLinkCount, 1)
        XCTAssertTrue(model.review?.habits.isEmpty == true)
        links.fails = true
        model.load()
        XCTAssertNil(model.review)
        XCTAssertNotNil(model.errorMessage)
        links.fails = false
        model.load()
        XCTAssertNil(model.errorMessage)
    }

    func testInsightsPassesSelectedCompletedWeekAndKeepsOpenedReviewStable() throws {
        let (habits, attention, _, _, links) = try repositories()
        let now = calendar.date(byAdding: .day, value: 10, to: start)!
        let model = InsightsViewModel(repository: habits, attentionRepository: attention, intentionLinks: links, calendar: calendar)
        model.load(asOf: now)
        let initial = try XCTUnwrap(model.madeRoomModel())
        XCTAssertEqual(initial.interval, interval)
        model.goToPreviousWeek(asOf: now)
        let earlier = try XCTUnwrap(model.madeRoomModel())
        XCTAssertEqual(earlier.interval, model.insights?.weekInterval)
        XCTAssertLessThan(earlier.interval.start, interval.start)
        XCTAssertEqual(initial.interval, interval, "Changing the parent week doesn't silently rewrite an opened review")
    }
}
