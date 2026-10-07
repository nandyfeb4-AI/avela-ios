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

    func testWeeklyConnectionCountsRecordedStartsNotOutcomesOrHabitSuccess() throws {
        let (habits, attention, habit, _) = try fixture()
        let links = Links()
        let week = LocalDay.weekInterval(containing: now, calendar: .autoupdatingCurrent)
        let before = week.start.addingTimeInterval(-60)
        let goal = try attention.createGoal(.init(name: "Focus", appOrCategoryLabel: nil, type: .focusSession, targetValue: 10, unit: .minutes), at: before)
        let old = try attention.startSession(goalID: goal.id, at: before)
        _ = try attention.finishSession(id: old.id, outcome: .interrupted, at: before.addingTimeInterval(10))
        try links.save(.init(id: UUID(), habitID: habit.id, sessionID: old.id, createdAt: before))
        let current = try attention.startSession(goalID: goal.id, at: now)
        try links.save(.init(id: UUID(), habitID: habit.id, sessionID: current.id, createdAt: now))
        let model = IntentionSessionViewModel(habitID: habit.id, habits: habits, attention: attention, links: links)
        model.load(asOf: now)
        XCTAssertEqual(model.currentWeekSessionCount, 1)
        XCTAssertEqual(model.history.count, 2)
        XCTAssertNil(model.history.first?.session.outcome)
        XCTAssertTrue(try habits.completions(for: habit.id, in: DateInterval(start: .distantPast, end: .distantFuture)).isEmpty)
    }

    func testPrivateReasonAppearsBeforeSessionAndHidePreservesItWithoutStartingAnything() throws {
        let (habits, attention, habit, goal) = try fixture()
        _ = try habits.updateHabit(id: habit.id, with: .init(name: habit.name, iconName: habit.iconName,
            category: habit.category, polarity: habit.polarity, schedule: habit.schedule,
            whyItMatters: "Make time to learn."), at: now)
        let links = Links()
        let model = IntentionSessionViewModel(habitID: habit.id, habits: habits, attention: attention, links: links)
        model.load(asOf: now)
        XCTAssertEqual(model.whyMemory, "Make time to learn.")
        model.hideWhyMemory(asOf: now)
        XCTAssertNil(model.whyMemory)
        XCTAssertEqual(try habits.fetchHabit(id: habit.id)?.whyItMatters, "Make time to learn.")
        XCTAssertTrue(try attention.sessions(for: goal.id).isEmpty)
        XCTAssertTrue(links.stored.isEmpty)
        let reopened = IntentionSessionViewModel(habitID: habit.id, habits: habits, attention: attention, links: links)
        reopened.load(asOf: now)
        XCTAssertNil(reopened.whyMemory)
        XCTAssertEqual(try habits.configurationHistory(for: habit.id).count, 1)
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
    func testCreateFocusGoalDoesNotStartUntilExplicitActionOrCompleteHabit() throws {
        let (habits, attention, habit, _) = try fixture()
        let links = Links()
        let model = IntentionSessionViewModel(habitID: habit.id, habits: habits, attention: attention, links: links)
        model.creationAllowed = { _ in true }
        model.load(asOf: now)
        model.createSessionGoal(.init(name: "Focus for reading", appOrCategoryLabel: nil, type: .focusSession, targetValue: 20, unit: .minutes), asOf: now)
        let id = try XCTUnwrap(model.selectedGoalID)
        XCTAssertEqual(model.selectedSessionType, .focusSession)
        XCTAssertTrue(try attention.sessions(for: id).isEmpty)
        XCTAssertTrue(links.stored.isEmpty)
        XCTAssertTrue(model.start(asOf: now))
        let session = try XCTUnwrap(attention.sessions(for: id).first)
        XCTAssertEqual(model.startedSessionID, session.id)
        XCTAssertEqual(links.stored.first?.habitID, habit.id)
        XCTAssertThrowsError(try attention.finishSession(id: session.id, outcome: .kept, at: now))
        try attention.finishSession(id: session.id, outcome: .kept, at: session.expectedEnd)
        model.load(asOf: session.expectedEnd)
        XCTAssertEqual(model.history.first?.outcomeLabel, "Focused · reported manually")
        XCTAssertTrue(try habits.completions(for: habit.id, in: DateInterval(start: now, duration: 86400)).isEmpty)
    }

    func testInlineCreationRechecksPlanAndRejectsNonSessionGoal() throws {
        let (habits, attention, habit, _) = try fixture()
        let model = IntentionSessionViewModel(habitID: habit.id, habits: habits, attention: attention, links: Links())
        model.load(asOf: now)
        model.creationAllowed = { _ in false }
        model.createSessionGoal(.init(name: "Focus", appOrCategoryLabel: nil, type: .focusSession, targetValue: 20, unit: .minutes), asOf: now)
        XCTAssertEqual(try attention.fetchGoals().count, 1)
        XCTAssertTrue(model.errorMessage?.contains("limit") == true)
        model.creationAllowed = { _ in true }
        model.createSessionGoal(.init(name: "Budget", appOrCategoryLabel: nil, type: .maxDurationPerDay, targetValue: 20, unit: .minutes), asOf: now)
        XCTAssertEqual(try attention.fetchGoals().count, 1)
    }

    func testFocusGoalAndSessionKeepTheirMeaningAfterReload() throws {
        let (habits, attention, habit, _) = try fixture()
        let store = try XCTUnwrap(container)
        let links = SwiftDataIntentionSessionLinkRepository(modelContext: store.mainContext)
        let model = IntentionSessionViewModel(habitID: habit.id, habits: habits, attention: attention, links: links)
        model.creationAllowed = { _ in true }
        model.load(asOf: now)
        model.createSessionGoal(.init(name: "Focus", appOrCategoryLabel: nil, type: .focusSession, targetValue: 20, unit: .minutes), asOf: now)
        let goalID = try XCTUnwrap(model.selectedGoalID)
        XCTAssertTrue(model.start(asOf: now))
        let attentionReloaded = SwiftDataAttentionRepository(modelContext: store.mainContext)
        let reloaded = IntentionSessionViewModel(habitID: habit.id, habits: habits, attention: attentionReloaded, links: links)
        reloaded.load(asOf: now)
        XCTAssertEqual(try attentionReloaded.fetchGoal(id: goalID)?.type, .focusSession)
        XCTAssertEqual(reloaded.startedSessionGoalID, goalID)
        XCTAssertEqual(reloaded.startedSessionID, model.startedSessionID)
        XCTAssertEqual(reloaded.history.count, 1)
    }

    func testFailedNewIntentionDoesNotReplaceItsReviewPathWithOlderActiveSession() throws {
        let (habits, attention, habit, oldGoal) = try fixture()
        let links = Links()
        let model = IntentionSessionViewModel(habitID: habit.id, habits: habits, attention: attention, links: links)
        model.creationAllowed = { _ in true }
        model.load(asOf: now)
        XCTAssertTrue(model.start(asOf: now))
        model.createSessionGoal(.init(name: "New focus", appOrCategoryLabel: nil, type: .focusSession, targetValue: 20, unit: .minutes), asOf: now)
        let newGoalID = try XCTUnwrap(model.selectedGoalID)
        links.shouldFail = true
        XCTAssertTrue(model.start(asOf: now))
        let session = try XCTUnwrap(attention.sessions(for: newGoalID).first)
        XCTAssertEqual(model.startedSessionID, session.id)
        XCTAssertEqual(model.startedSessionGoalID, newGoalID)
        XCTAssertEqual(model.history.first?.session.attentionGoalID, oldGoal.id)
        XCTAssertNotNil(model.errorMessage)
    }

}
