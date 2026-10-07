import Foundation
import SwiftData
import XCTest
@testable import Avela

@MainActor
final class HabitLifetimeTests: XCTestCase {
    private let habitID = UUID()
    private let anchor = Date(timeIntervalSince1970: 1_759_680_000)

    private func completion(_ key: String, habit: UUID? = nil, time: Date? = nil, id: UUID = UUID()) -> Completion {
        Completion(id: id, habitID: habit ?? habitID, occurredAt: time ?? anchor,
            localDateKey: key, source: .app, note: nil)
    }
    private func entry(_ kind: HabitActivityKind, unit: HabitQuantityUnit? = nil, amount: Int = 1,
                       key: String = "2025-10-05", id: UUID = UUID(), habit: UUID? = nil, time: Date? = nil) -> HabitActivityEntry {
        HabitActivityEntry(id: id, habitID: habit ?? habitID, configurationID: UUID(), dayKey: key,
            loggedAt: time ?? anchor, kind: kind, amount: amount, unit: unit, description: "Recorded")
    }
    private func summarize(_ completions: [Completion] = [], entries: [HabitActivityEntry] = []) -> HabitLifetimeCalculator.Summary {
        HabitLifetimeCalculator.summarize(habitID: habitID, completions: completions, entries: entries, asOf: anchor)
    }

    func testDistinctStoredDaysSurviveGapsAndDuplicateCompletions() {
        let result = summarize([completion("2025-01-01"), completion("2025-01-01"), completion("2025-10-05")])
        XCTAssertEqual(result.checkInDays, 2)
        XCTAssertEqual(result.nextMilestone, 10)
    }
    func testForeignAndFutureRecordsNeverInflateTotals() {
        let result = summarize([completion("2025-10-05", habit: UUID()), completion("2025-10-06", time: anchor.addingTimeInterval(1))],
            entries: [entry(.quantity, unit: .pages, amount: 10, habit: UUID()), entry(.smallerAction, time: anchor.addingTimeInterval(1))])
        XCTAssertEqual(result.checkInDays, 0)
        XCTAssertEqual(result.smallerActionDays, 0)
        XCTAssertTrue(result.quantities.isEmpty)
    }
    func testStoredDayKeysAreNotRederivedFromMatchingInstantsAfterTravel() {
        XCTAssertEqual(summarize([completion("2025-10-04"), completion("2025-10-05")]).checkInDays, 2)
    }
    func testMilestoneBoundaryAndUndoAreRecomputed() {
        let values = (1...25).map { completion("2025-09-\(String(format: "%02d", $0))") }
        XCTAssertEqual(summarize(values).achievedMilestones, [10, 25])
        XCTAssertEqual(summarize(Array(values.dropLast())).achievedMilestones, [10])
        XCTAssertEqual(summarize(Array(values.dropLast())).nextMilestone, 25)
    }
    func testAboveFinalMilestoneRemainsAnUncappedCount() {
        let values = (0..<1_001).map { offset in
            completion(LocalDay.key(for: anchor.addingTimeInterval(Double(-offset) * 86_400), calendar: Calendar(identifier: .gregorian)))
        }
        let result = summarize(values)
        XCTAssertEqual(result.checkInDays, 1_001)
        XCTAssertEqual(result.achievedMilestones, [10, 25, 50, 100, 250, 500, 1_000])
        XCTAssertNil(result.nextMilestone)
    }
    func testHistoricalCapturedUnitsNeverPoolAndDuplicateIDsDoNotDoubleCount() {
        let pages = entry(.quantity, unit: .pages, amount: 20)
        let result = summarize(entries: [pages, pages, entry(.quantity, unit: .pages, amount: 5), entry(.quantity, unit: .minutes, amount: 10)])
        XCTAssertEqual(result.quantities, [.init(unit: .pages, amount: 25), .init(unit: .minutes, amount: 10)])
        XCTAssertEqual(result.checkInDays, 0)
    }
    func testSmallerActionsRemainSeparateAndCountDistinctDays() {
        let result = summarize(entries: [entry(.smallerAction), entry(.smallerAction), entry(.smallerAction, key: "2025-10-04")])
        XCTAssertEqual(result.smallerActionDays, 2)
        XCTAssertEqual(result.checkInDays, 0)
        XCTAssertTrue(result.achievedMilestones.isEmpty)
    }
    func testCorrectedQuantityTotalUsesSurvivingEntriesOnly() {
        let first = entry(.quantity, unit: .pages, amount: 20)
        let second = entry(.quantity, unit: .pages, amount: 5)
        XCTAssertEqual(summarize(entries: [first, second]).quantities.first?.amount, 25)
        XCTAssertEqual(summarize(entries: [second]).quantities.first?.amount, 5)
    }
    func testViewModelIsReadOnlyAndArchivedWeeklyHabitCountsLoggedDaysNotWeeks() throws {
        let container = try AppPersistence.makeContainer(inMemory: true)
        let repository = SwiftDataHabitRepository(modelContext: container.mainContext)
        let habit = try repository.createHabit(.init(name: "Read", iconName: "book", category: .learning,
            polarity: .positive, schedule: .timesPerWeek(3)), at: anchor.addingTimeInterval(-86_400))
        let first = try repository.recordCompletion(habitID: habit.id, at: anchor.addingTimeInterval(-86_400), source: .app, note: nil)
        _ = try repository.recordCompletion(habitID: habit.id, at: anchor, source: .app, note: nil)
        try repository.archiveHabit(id: habit.id, at: anchor)
        let model = HabitLifetimeViewModel(habitID: habit.id, habits: repository, activity: nil)
        model.load(asOf: anchor)
        XCTAssertEqual(model.summary?.checkInDays, 2)
        XCTAssertEqual(model.habitName, "Read")
        XCTAssertFalse(model.hasQuantityHistory)
        let interval = DateInterval(start: habit.createdAt, end: anchor.addingTimeInterval(1))
        XCTAssertEqual(try repository.completions(for: habit.id, in: interval).count, 2)
        try repository.undoCompletion(id: first.id)
        model.load(asOf: anchor)
        XCTAssertEqual(model.summary?.checkInDays, 1)
    }
    func testLifetimeIncludesInitialStoredDayAfterTravelAndUnitChanges() throws {
        var hawaii = Calendar(identifier: .gregorian)
        hawaii.timeZone = TimeZone(identifier: "Pacific/Honolulu")!
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let container = try AppPersistence.makeContainer(inMemory: true)
        let habits = SwiftDataHabitRepository(modelContext: container.mainContext, calendar: hawaii)
        let activity = SwiftDataHabitActivityRepository(context: container.mainContext, habits: habits, calendar: hawaii)
        let first = hawaii.date(from: DateComponents(year: 2025, month: 9, day: 30, hour: 23))!
        let second = hawaii.date(byAdding: .day, value: 1, to: first)!
        let habit = try habits.createHabit(.init(name: "Read", iconName: "book", category: .learning, polarity: .positive, schedule: .daily), at: first)
        try activity.configure(habitID: habit.id, target: .init(amount: 20, unit: .pages), smallerAction: "", at: first)
        let firstConfig = try XCTUnwrap(activity.configuration(for: habit.id, on: first))
        try activity.log(habitID: habit.id, kind: .quantity, amount: 20, expectedConfigurationID: firstConfig.id, on: first, now: first)
        try activity.configure(habitID: habit.id, target: .init(amount: 10, unit: .minutes), smallerAction: "", at: second)
        let secondConfig = try XCTUnwrap(activity.configuration(for: habit.id, on: second))
        try activity.log(habitID: habit.id, kind: .quantity, amount: 10, expectedConfigurationID: secondConfig.id, on: second, now: second)
        let traveledHabits = SwiftDataHabitRepository(modelContext: container.mainContext, calendar: tokyo)
        let traveledActivity = SwiftDataHabitActivityRepository(context: container.mainContext, habits: traveledHabits, calendar: tokyo)
        let model = HabitLifetimeViewModel(habitID: habit.id, habits: traveledHabits, activity: traveledActivity)
        model.load(asOf: second)
        XCTAssertEqual(model.summary?.checkInDays, 2)
        XCTAssertEqual(model.summary?.quantities, [.init(unit: .pages, amount: 20), .init(unit: .minutes, amount: 10)])
        XCTAssertNil(model.errorMessage)
    }

    func testHistoricalEntryRangeUsesStoredDaysForBackdatedLogsAndExcludesExactEndDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let container = try AppPersistence.makeContainer(inMemory: true)
        let habits = SwiftDataHabitRepository(modelContext: container.mainContext, calendar: calendar)
        let activity = SwiftDataHabitActivityRepository(context: container.mainContext, habits: habits, calendar: calendar)
        let start = calendar.date(from: DateComponents(year: 2025, month: 10, day: 1))!
        let rangeStart = calendar.date(byAdding: .day, value: 1, to: start)!
        let rangeEnd = calendar.date(byAdding: .day, value: 2, to: start)!
        let loggedLater = calendar.date(byAdding: .day, value: 5, to: start)!
        let habit = try habits.createHabit(.init(name: "Read", iconName: "book", category: .learning, polarity: .positive, schedule: .daily), at: start)
        try activity.configure(habitID: habit.id, target: .init(amount: 20, unit: .pages), smallerAction: "", at: start)
        let config = try XCTUnwrap(activity.configuration(for: habit.id, on: start))
        for (date, amount) in [(start, 1), (rangeStart, 2), (rangeEnd, 3)] {
            try activity.log(habitID: habit.id, kind: .quantity, amount: amount, expectedConfigurationID: config.id, on: date, now: loggedLater)
        }
        let rows = try activity.entries(for: habit.id, in: DateInterval(start: rangeStart, end: rangeEnd))
        XCTAssertEqual(rows.map(\.dayKey), ["2025-10-02"])
        XCTAssertEqual(rows.map(\.amount), [2])
        XCTAssertEqual(rows.first?.loggedAt, loggedLater)
        XCTAssertGreaterThan(loggedLater, rangeEnd)
        XCTAssertEqual(try activity.entries(for: UUID(), in: DateInterval(start: rangeStart, end: rangeEnd)), [])
        XCTAssertEqual(try activity.entries(for: habit.id, in: DateInterval(start: rangeStart, end: rangeStart)), [])
    }

    func testHistoricalEntryRangeIncludesIntersectingCivilDaysForPartialBoundaries() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let container = try AppPersistence.makeContainer(inMemory: true)
        let habits = SwiftDataHabitRepository(modelContext: container.mainContext, calendar: calendar)
        let activity = SwiftDataHabitActivityRepository(context: container.mainContext, habits: habits, calendar: calendar)
        let firstDay = calendar.date(from: DateComponents(year: 2025, month: 10, day: 2))!
        let secondDay = calendar.date(byAdding: .day, value: 1, to: firstDay)!
        let habit = try habits.createHabit(.init(name: "Read", iconName: "book", category: .learning, polarity: .positive, schedule: .daily), at: firstDay)
        try activity.configure(habitID: habit.id, target: .init(amount: 20, unit: .pages), smallerAction: "", at: firstDay)
        let config = try XCTUnwrap(activity.configuration(for: habit.id, on: firstDay))
        try activity.log(habitID: habit.id, kind: .quantity, amount: 2, expectedConfigurationID: config.id, on: firstDay, now: secondDay)
        try activity.log(habitID: habit.id, kind: .quantity, amount: 3, expectedConfigurationID: config.id, on: secondDay, now: secondDay)
        // A civil-day query includes both intersecting days, even though their
        // recorded dates are midnight and the supplied start is noon.
        let interval = DateInterval(start: firstDay.addingTimeInterval(43_200), end: secondDay.addingTimeInterval(43_200))
        XCTAssertEqual(try activity.entries(for: habit.id, in: interval).map(\.dayKey), ["2025-10-02", "2025-10-03"])
    }

    func testMissingHabitShowsErrorRatherThanFabricatedZero() throws {
        let container = try AppPersistence.makeContainer(inMemory: true)
        let repository = SwiftDataHabitRepository(modelContext: container.mainContext)
        let model = HabitLifetimeViewModel(habitID: UUID(), habits: repository, activity: nil)
        model.load(asOf: anchor)
        XCTAssertNil(model.summary)
        XCTAssertNotNil(model.errorMessage)
    }
}
