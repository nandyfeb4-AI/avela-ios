import Foundation
import SwiftData
import XCTest
@testable import Avela

@MainActor
final class HabitMomentumTests: XCTestCase {
    private var container: ModelContainer!
    private var habits: SwiftDataHabitRepository!
    private var activities: SwiftDataHabitActivityRepository!
    private var calendar: Calendar!
    private let start = Date(timeIntervalSince1970: 1_718_496_000)
    override func setUpWithError() throws {
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1
        container = try AppPersistence.makeContainer(inMemory: true)
        habits = SwiftDataHabitRepository(modelContext: container.mainContext, calendar: calendar)
        activities = SwiftDataHabitActivityRepository(context: container.mainContext, habits: habits, calendar: calendar)
    }
    private func day(_ n: Int) -> Date { calendar.date(byAdding: .day, value: n, to: start)!.addingTimeInterval(3600) }
    private func create(_ schedule: HabitSchedule = .daily) throws -> Habit {
        try habits.createHabit(HabitDraft(name: "Read", iconName: "book", category: .learning, polarity: .positive, schedule: schedule), at: day(0))
    }
    private func summary(_ habit: Habit, on n: Int) throws -> HabitMomentumCalculator.Summary {
        let model = HabitMomentumViewModel(habitID: habit.id, habits: habits, activity: activities, calendar: calendar)
        model.load(asOf: day(n))
        XCTAssertNil(model.errorMessage)
        return try XCTUnwrap(model.summary)
    }
    func testOpenPeriodIsUnknownRatherThanMeasuredZero() throws {
        let habit = try create()
        let result = try summary(habit, on: 0)
        XCTAssertNil(result.recentPercentage)
        XCTAssertEqual(result.recentResolved, 0)
        XCTAssertFalse(result.isRecovering)
    }
    func testSkipsAndPausedWindowsDoNotBecomeMisses() throws {
        let habit = try create()
        try habits.recordSkip(habitID: habit.id, on: day(0), reason: .planned)
        try habits.archiveHabit(id: habit.id, at: day(1))
        let paused = try summary(habit, on: 10)
        XCTAssertNil(paused.recentPercentage)
        XCTAssertFalse(paused.isRecovering)
        try habits.reactivateHabit(id: habit.id, at: day(10))
        XCTAssertNil(try summary(habit, on: 10).recentPercentage)
    }
    func testRecoveryEndsAtThirdSuccessAndUndoRecomputesIt() throws {
        let habit = try create()
        let first = try habits.recordCompletion(habitID: habit.id, at: day(2), source: .app, note: nil)
        _ = first
        try habits.recordCompletion(habitID: habit.id, at: day(3), source: .app, note: nil)
        XCTAssertEqual(try summary(habit, on: 3).recoverySuccessful, 2)
        XCTAssertTrue(try summary(habit, on: 3).isRecovering)
        let third = try habits.recordCompletion(habitID: habit.id, at: day(4), source: .app, note: nil)
        XCTAssertFalse(try summary(habit, on: 4).isRecovering)
        try habits.undoCompletion(id: third.id)
        XCTAssertTrue(try summary(habit, on: 4).isRecovering)
        XCTAssertEqual(try summary(habit, on: 4).lifetime.checkInDays, 2)
    }
    func testWeeklyTargetIsOneResolvedCommitmentNotSevenDays() throws {
        let habit = try create(.timesPerWeek(2))
        try habits.recordCompletion(habitID: habit.id, at: day(0), source: .app, note: nil)
        try habits.recordCompletion(habitID: habit.id, at: day(1), source: .app, note: nil)
        let result = try summary(habit, on: 7)
        XCTAssertEqual(result.recentResolved, 1)
        XCTAssertEqual(result.recentPercentage, 100)
        XCTAssertEqual(result.lifetime.checkInDays, 2)
    }
    func testSmallerEffortNeverBecomesFullSuccess() throws {
        let habit = try create()
        try activities.configure(habitID: habit.id, target: nil, smallerAction: "One page", at: day(0))
        let config = try XCTUnwrap(activities.configuration(for: habit.id, on: day(2)))
        try activities.log(habitID: habit.id, kind: .smallerAction, amount: 1, expectedConfigurationID: config.id, on: day(2), now: day(2))
        let result = try summary(habit, on: 2)
        XCTAssertEqual(result.recentSuccessful, 0)
        XCTAssertEqual(result.lifetime.smallerActionDays, 1)
        XCTAssertEqual(result.lifetime.checkInDays, 0)
        XCTAssertEqual(result.recoverySuccessful, 0)
    }
    func testOldSuccessRemainsLifetimeEffortOutsideRecentWindow() throws {
        let habit = try create()
        try habits.recordCompletion(habitID: habit.id, at: day(0), source: .app, note: nil)
        let result = try summary(habit, on: 20)
        XCTAssertEqual(result.recentSuccessful, 0)
        XCTAssertEqual(result.recentResolved, 13)
        XCTAssertEqual(result.lifetime.checkInDays, 1)
    }
    func testMissingHabitClearsPreviouslyLoadedFacts() throws {
        let model = HabitMomentumViewModel(habitID: UUID(), habits: habits, activity: activities, calendar: calendar)
        model.load(asOf: day(0))
        XCTAssertNil(model.summary)
        XCTAssertNotNil(model.errorMessage)
    }
}
