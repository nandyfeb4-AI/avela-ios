import Foundation
import SwiftData
import XCTest
@testable import Avela

@MainActor
final class HabitRecoverySuggestionTests: XCTestCase {
    private var container: ModelContainer!
    private var habits: SwiftDataHabitRepository!
    private var activities: SwiftDataHabitActivityRepository!
    private var calendar: Calendar!
    private let start = Date(timeIntervalSince1970: 1_718_496_000) // 2024-06-16 UTC, Sunday

    override func setUpWithError() throws {
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1
        container = try AppPersistence.makeContainer(inMemory: true)
        habits = SwiftDataHabitRepository(modelContext: container.mainContext, calendar: calendar)
        activities = SwiftDataHabitActivityRepository(context: container.mainContext, habits: habits, calendar: calendar)
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: start)!.addingTimeInterval(3600)
    }

    private func create(_ schedule: HabitSchedule = .daily, polarity: HabitPolarity = .positive) throws -> Habit {
        try habits.createHabit(HabitDraft(name: "Read", iconName: "book", category: .learning,
            polarity: polarity, schedule: schedule), at: day(0))
    }

    private func model(_ habit: Habit, on offset: Int) -> HabitRecoveryChoiceViewModel {
        let model = HabitRecoveryChoiceViewModel(habitID: habit.id, habits: habits, activities: activities, calendar: calendar)
        model.load(asOf: day(offset))
        return model
    }

    func testTwoResolvedMissesOfferConfiguredSmallerActionWithoutWriting() throws {
        let habit = try create()
        try activities.configure(habitID: habit.id, target: nil, smallerAction: "Read one page", at: day(0))
        XCTAssertNil(model(habit, on: 1).suggestion)
        let state = model(habit, on: 2)
        XCTAssertEqual(state.suggestion?.recentMisses, 2)
        XCTAssertEqual(state.suggestion?.smallerAction, "Read one page")
        XCTAssertTrue(state.canOpenSmallerAction(asOf: day(2)))
        XCTAssertEqual(try habits.configurationHistory(for: habit.id).count, 1)
        XCTAssertTrue(try habits.archivePeriods(for: habit.id).isEmpty)
        XCTAssertTrue(try activities.entries(for: habit.id, on: day(2)).isEmpty)
        XCTAssertTrue(try habits.completions(for: habit.id, in: DateInterval(start: start, end: day(3))).isEmpty)
    }

    func testSkipAndOpenPeriodDoNotBecomeMisses() throws {
        let habit = try create()
        try habits.recordSkip(habitID: habit.id, on: day(0), reason: .planned)
        XCTAssertNil(model(habit, on: 2).suggestion)
        XCTAssertEqual(model(habit, on: 3).suggestion?.recentMisses, 2)
        try habits.recordSkip(habitID: habit.id, on: day(3), reason: .planned)
        XCTAssertNil(model(habit, on: 3).suggestion)
    }

    func testCurrentSuccessAndThreeRecoverySuccessesSuppressSuggestion() throws {
        let habit = try create()
        try habits.recordCompletion(habitID: habit.id, at: day(2), source: .app, note: nil)
        XCTAssertNil(model(habit, on: 2).suggestion)
        XCTAssertNotNil(model(habit, on: 3).suggestion)
        for n in 3...4 { try habits.recordCompletion(habitID: habit.id, at: day(n), source: .app, note: nil) }
        XCTAssertNil(model(habit, on: 5).suggestion)
    }

    func testWeeklyOncePerWeekQualifiesAfterTwoClosedWeeks() throws {
        let habit = try create(.timesPerWeek(1))
        XCTAssertNil(model(habit, on: 7).suggestion)
        let result = try XCTUnwrap(model(habit, on: 14).suggestion)
        XCTAssertEqual(result.recentMisses, 2)
        XCTAssertEqual(result.windowDays, 28)
        XCTAssertEqual(result.unit, .weeks)
        XCTAssertTrue(result.reason.contains("weekly commitments"))
    }

    func testUnscheduledWeekdayDoesNotSuggestAndMissesUseCurrentConfigurationOnly() throws {
        let habit = try create(.weekdays([.monday, .tuesday]))
        XCTAssertNil(model(habit, on: 3).suggestion) // Wednesday not scheduled
        XCTAssertNotNil(model(habit, on: 8).suggestion)
        _ = try habits.updateHabit(id: habit.id, with: HabitDraft(name: habit.name, iconName: habit.iconName,
            category: habit.category, polarity: .positive, schedule: .daily), at: day(8))
        XCTAssertNil(model(habit, on: 9).suggestion) // only one current-configuration miss
    }

    func testAvoidanceAndArchiveAreExcludedAndPauseCreatesNoMisses() throws {
        XCTAssertNil(model(try create(.daily, polarity: .avoidance), on: 5).suggestion)
        let habit = try create()
        try habits.archiveHabit(id: habit.id, at: day(1))
        XCTAssertNil(model(habit, on: 5).suggestion)
        try habits.reactivateHabit(id: habit.id, at: day(20))
        XCTAssertNil(model(habit, on: 21).suggestion)
        XCTAssertEqual(model(habit, on: 23).suggestion?.recentMisses, 3)
    }

    func testPauseIsExplicitPreservesHistoryAndDoesNotResumeAutomatically() throws {
        let habit = try create()
        let state = model(habit, on: 3)
        XCTAssertFalse(try XCTUnwrap(habits.fetchHabit(id: habit.id)).isArchived, "Opening alone does nothing")
        XCTAssertTrue(state.pause(asOf: day(3)))
        XCTAssertFalse(state.pause(asOf: day(3)), "Repeated confirmation cannot duplicate a pause")
        let paused = try XCTUnwrap(habits.fetchHabit(id: habit.id))
        XCTAssertTrue(paused.isArchived)
        XCTAssertEqual(try habits.archivePeriods(for: habit.id).count, 1)
        XCTAssertEqual(try habits.configurationHistory(for: habit.id).count, 1)
        XCTAssertNil(model(habit, on: 30).suggestion)
        XCTAssertTrue(try XCTUnwrap(habits.fetchHabit(id: habit.id)).isArchived)
        try habits.reactivateHabit(id: habit.id, at: day(30))
        let all = HabitProgressCalculator.periods(for: try XCTUnwrap(habits.fetchHabit(id: habit.id)),
            snapshots: try habits.configurationHistory(for: habit.id), completions: [], skips: [],
            archivePeriods: try habits.archivePeriods(for: habit.id), asOf: day(30), calendar: calendar)
        XCTAssertEqual(all.filter { $0.outcome == .miss }.count, 3)
    }

    func testMidnightOrChangedActionRejectsStaleReview() throws {
        let habit = try create()
        try activities.configure(habitID: habit.id, target: nil, smallerAction: "Read one page", at: day(0))
        let state = model(habit, on: 3)
        XCTAssertFalse(state.pause(asOf: day(4)))
        XCTAssertFalse(try XCTUnwrap(habits.fetchHabit(id: habit.id)).isArchived)
        state.load(asOf: day(4))
        try activities.configure(habitID: habit.id, target: nil, smallerAction: "Open the book", at: day(4))
        XCTAssertFalse(state.canOpenSmallerAction(asOf: day(4)))
        XCTAssertFalse(try XCTUnwrap(habits.fetchHabit(id: habit.id)).isArchived)
    }

    func testSmallerEffortAlreadyLoggedSuppressesRepetitionWithoutGrantingSuccess() throws {
        let habit = try create()
        try activities.configure(habitID: habit.id, target: nil, smallerAction: "Read one page", at: day(0))
        let state = model(habit, on: 3)
        let config = try XCTUnwrap(activities.configuration(for: habit.id, on: day(3)))
        try activities.log(habitID: habit.id, kind: .smallerAction, amount: 1,
            expectedConfigurationID: config.id, on: day(3), now: day(3))
        XCTAssertFalse(state.canOpenSmallerAction(asOf: day(3)))
        XCTAssertNil(model(habit, on: 3).suggestion)
        XCTAssertTrue(try habits.completions(for: habit.id, in: DateInterval(start: start, end: day(4))).isEmpty)
    }
}
