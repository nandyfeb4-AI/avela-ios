import Foundation
import SwiftData
import XCTest
@testable import Avela

@MainActor
final class IntentionSessionViewModelTests: XCTestCase {
    private var container: ModelContainer?
    private let now = Date(timeIntervalSince1970: 1_718_632_800)

    private final class Links: IntentionSessionLinkRepository {
        var stored: [IntentionSessionLink] = []
        var shouldFail = false
        func links(for habitID: UUID) throws -> [IntentionSessionLink] { stored.filter { $0.habitID == habitID } }
        func save(_ link: IntentionSessionLink) throws {
            if shouldFail { throw IntentionSessionLinkError.conflictingIntention }
            stored.append(link)
        }
    }

    private func fixture() throws -> (SwiftDataHabitRepository, SwiftDataAttentionRepository, Habit, AttentionGoal) {
        let value = try AppPersistence.makeContainer(inMemory: true)
        container = value
        let habits = SwiftDataHabitRepository(modelContext: value.mainContext)
        let attention = SwiftDataAttentionRepository(modelContext: value.mainContext)
        let habit = try habits.createHabit(HabitDraft(name: "Read", iconName: "book.fill", category: .learning,
                                                     polarity: .positive, schedule: .daily), at: now)
        let goal = try attention.createGoal(AttentionGoalDraft(name: "Reading space", appOrCategoryLabel: nil,
                                                               type: .phoneFreeSession, targetValue: 15, unit: .minutes), at: now)
        return (habits, attention, habit, goal)
    }

    func testLoadingCapturesNoSessionOrHabitSuccess() throws {
        let (habits, attention, habit, goal) = try fixture()
        let links = Links()
        let model = IntentionSessionViewModel(habitID: habit.id, habits: habits, attention: attention, links: links)
        model.load(asOf: now)
        XCTAssertEqual(model.selectedGoalID, goal.id)
        XCTAssertEqual(model.selectedTargetMinutes, 15)
        XCTAssertTrue(try attention.sessions(for: goal.id).isEmpty)
        XCTAssertTrue(links.stored.isEmpty)
        XCTAssertTrue(try habits.completions(for: habit.id, in: DateInterval(start: now, duration: 86400)).isEmpty)
    }

    func testExplicitStartLinksSessionWithoutCompletingHabitOrInferringOutcome() throws {
        let (habits, attention, habit, goal) = try fixture()
        let links = Links()
        let model = IntentionSessionViewModel(habitID: habit.id, habits: habits, attention: attention, links: links)
        model.load(asOf: now)
        model.start(asOf: now)
        let session = try XCTUnwrap(attention.sessions(for: goal.id).first)
        XCTAssertEqual(links.stored.first?.sessionID, session.id)
        XCTAssertEqual(links.stored.first?.habitID, habit.id)
        model.load(asOf: now.addingTimeInterval(3600))
        XCTAssertNil(model.history.first?.session.outcome)
        XCTAssertEqual(model.history.first?.outcomeLabel, "Awaiting your check-in")
        XCTAssertTrue(try habits.completions(for: habit.id, in: DateInterval(start: now, duration: 86400)).isEmpty)
    }

    func testArchivedHabitCannotStartFromStaleReview() throws {
        let (habits, attention, habit, goal) = try fixture()
        let links = Links()
        let model = IntentionSessionViewModel(habitID: habit.id, habits: habits, attention: attention, links: links)
        model.load(asOf: now)
        try habits.archiveHabit(id: habit.id, at: now)
        model.start(asOf: now)
        XCTAssertTrue(try attention.sessions(for: goal.id).isEmpty)
        XCTAssertTrue(links.stored.isEmpty)
        XCTAssertFalse(model.habitAvailable)
    }

    func testLinkFailureDisclosesStartedSessionAndKeepsReviewDestination() throws {
        let (habits, attention, habit, goal) = try fixture()
        let links = Links()
        links.shouldFail = true
        let model = IntentionSessionViewModel(habitID: habit.id, habits: habits, attention: attention, links: links)
        model.load(asOf: now)
        model.start(asOf: now)
        XCTAssertEqual(try attention.sessions(for: goal.id).count, 1)
        XCTAssertEqual(model.startedSessionGoalID, goal.id)
        XCTAssertTrue(model.errorMessage?.contains("session started") == true)
        XCTAssertTrue(links.stored.isEmpty)
        model.start(asOf: now)
        XCTAssertEqual(try attention.sessions(for: goal.id).count, 1)
    }

    func testOnlyPhoneFreeGoalsCanBeSelectedAndStarted() throws {
        let (habits, attention, habit, goal) = try fixture()
        let budget = try attention.createGoal(AttentionGoalDraft(name: "News", appOrCategoryLabel: nil,
                                                                 type: .maxDurationPerDay, targetValue: 30, unit: .minutes), at: now)
        let model = IntentionSessionViewModel(habitID: habit.id, habits: habits, attention: attention, links: Links())
        model.load(asOf: now)
        XCTAssertEqual(model.goals.map(\.id), [goal.id])
        model.selectedGoalID = budget.id
        model.start(asOf: now)
        XCTAssertTrue(try attention.sessions(for: budget.id).isEmpty)
        XCTAssertNotNil(model.errorMessage)
    }

    func testManualSessionResultRemainsDistinctFromHabitCompletion() throws {
        let (habits, attention, habit, goal) = try fixture()
        let links = Links()
        let model = IntentionSessionViewModel(habitID: habit.id, habits: habits, attention: attention, links: links)
        model.load(asOf: now)
        model.start(asOf: now)
        let session = try XCTUnwrap(attention.sessions(for: goal.id).first)
        try attention.finishSession(id: session.id, outcome: .kept, at: session.expectedEnd)
        let reloaded = IntentionSessionViewModel(habitID: habit.id, habits: habits, attention: attention, links: links)
        reloaded.load(asOf: session.expectedEnd)
        XCTAssertEqual(reloaded.history.first?.outcomeLabel, "Kept · reported manually")
        XCTAssertTrue(try habits.completions(for: habit.id, in: DateInterval(start: now, duration: 86400)).isEmpty)
    }

    func testPersistedAssociationIsImmutableAndRetrySafe() throws {
        let value = try ModelContainer(for: IntentionSessionLinkRecord.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        container = value
        let repository = SwiftDataIntentionSessionLinkRepository(modelContext: value.mainContext)
        let habitID = UUID(), sessionID = UUID()
        let link = IntentionSessionLink(id: UUID(), habitID: habitID, sessionID: sessionID, createdAt: now)
        try repository.save(link)
        try repository.save(link)
        XCTAssertEqual(try repository.links(for: habitID), [link])
        XCTAssertThrowsError(try repository.save(IntentionSessionLink(id: UUID(), habitID: UUID(), sessionID: sessionID, createdAt: now)))
        XCTAssertThrowsError(try repository.save(IntentionSessionLink(id: link.id, habitID: habitID, sessionID: UUID(), createdAt: now)))
        XCTAssertEqual(try repository.links(for: habitID), [link])
    }
}
