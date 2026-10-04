import Foundation
import XCTest
@testable import Avela

final class HabitScheduleEvaluatorTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 1
        return calendar
    }()

    // 2024-06-17 is a Monday, 2024-06-19 is a Wednesday, both mid-morning America/New_York.
    private let monday = Date(timeIntervalSince1970: 1_718_632_800)
    private let wednesday = Date(timeIntervalSince1970: 1_718_805_600)

    func testDailyScheduleIsDueEveryDay() {
        XCTAssertTrue(HabitScheduleEvaluator.isDue(.daily, on: monday, calendar: calendar))
        XCTAssertTrue(HabitScheduleEvaluator.isDue(.daily, on: wednesday, calendar: calendar))
    }

    func testWeekdaysScheduleIsDueOnlyOnSelectedDays() {
        let schedule = HabitSchedule.weekdays([.monday, .wednesday, .friday])
        XCTAssertTrue(HabitScheduleEvaluator.isDue(schedule, on: monday, calendar: calendar))
        XCTAssertTrue(HabitScheduleEvaluator.isDue(schedule, on: wednesday, calendar: calendar))

        let tuesday = monday.addingTimeInterval(24 * 60 * 60)
        XCTAssertFalse(HabitScheduleEvaluator.isDue(schedule, on: tuesday, calendar: calendar))
    }

    func testTimesPerWeekScheduleIsDueEveryDay() {
        let schedule = HabitSchedule.timesPerWeek(3)
        XCTAssertTrue(HabitScheduleEvaluator.isDue(schedule, on: monday, calendar: calendar))
        XCTAssertTrue(HabitScheduleEvaluator.isDue(schedule, on: wednesday, calendar: calendar))
    }

    func testWeeklyProgressCountsOnlyCompletionsInTheContainingWeek() {
        let habitID = UUID()
        let otherHabitID = UUID()
        let mondayCompletion = Completion(
            id: UUID(), habitID: habitID, occurredAt: monday, localDateKey: "2024-06-17", source: .app, note: nil
        )
        let wednesdayCompletion = Completion(
            id: UUID(), habitID: habitID, occurredAt: wednesday, localDateKey: "2024-06-19", source: .app, note: nil
        )
        let nextWeekCompletion = Completion(
            id: UUID(),
            habitID: habitID,
            occurredAt: monday.addingTimeInterval(9 * 24 * 60 * 60),
            localDateKey: "2024-06-26",
            source: .app,
            note: nil
        )
        let otherHabitCompletion = Completion(
            id: UUID(), habitID: otherHabitID, occurredAt: monday, localDateKey: "2024-06-17", source: .app, note: nil
        )

        let progress = HabitScheduleEvaluator.weeklyProgress(
            habitID: habitID,
            target: 3,
            completions: [mondayCompletion, wednesdayCompletion, nextWeekCompletion, otherHabitCompletion],
            on: wednesday,
            calendar: calendar
        )

        XCTAssertEqual(progress.completedCount, 2)
        XCTAssertEqual(progress.target, 3)
        XCTAssertFalse(progress.isSatisfied)
    }

    func testWeeklyProgressRemainsVisibleBeyondTarget() {
        let habitID = UUID()
        let completions = (0..<4).map { offset in
            Completion(
                id: UUID(),
                habitID: habitID,
                occurredAt: monday.addingTimeInterval(Double(offset) * 24 * 60 * 60),
                localDateKey: "day-\(offset)",
                source: .app,
                note: nil
            )
        }

        let progress = HabitScheduleEvaluator.weeklyProgress(
            habitID: habitID, target: 3, completions: completions, on: wednesday, calendar: calendar
        )

        XCTAssertEqual(progress.completedCount, 4)
        XCTAssertTrue(progress.isSatisfied)
    }

    func testActiveConfigurationResolvesMostRecentSnapshotNotAfterDate() {
        let habitID = UUID()
        let original = HabitConfigurationSnapshot(
            id: UUID(), habitID: habitID, polarity: .positive, schedule: .daily,
            effectiveLocalDateKey: "2024-01-01", revision: 0, createdAt: monday
        )
        let edited = HabitConfigurationSnapshot(
            id: UUID(), habitID: habitID, polarity: .positive, schedule: .timesPerWeek(3),
            effectiveLocalDateKey: "2024-06-01", revision: 1, createdAt: monday
        )

        let beforeEdit = HabitScheduleEvaluator.activeConfiguration(
            from: [original, edited], on: Date(timeIntervalSince1970: 1_709_251_200), calendar: calendar
        ) // 2024-02-29
        XCTAssertEqual(beforeEdit, original)

        let afterEdit = HabitScheduleEvaluator.activeConfiguration(from: [original, edited], on: monday, calendar: calendar)
        XCTAssertEqual(afterEdit, edited)
    }

    func testActiveConfigurationWithMultipleEditsOnSameLocalDayPicksTheHighestRevision() {
        let habitID = UUID()
        // Two edits both effective "2024-06-17" (the same local day as `monday`),
        // with different `createdAt` values but distinguished authoritatively by
        // `revision`. The later edit (higher revision) must win regardless of the
        // order the snapshots are passed in, since SwiftData fetch order is not
        // guaranteed to match insertion order.
        let firstEditOfTheDay = HabitConfigurationSnapshot(
            id: UUID(), habitID: habitID, polarity: .positive, schedule: .daily,
            effectiveLocalDateKey: "2024-06-17", revision: 0, createdAt: monday
        )
        let secondEditOfTheDay = HabitConfigurationSnapshot(
            id: UUID(), habitID: habitID, polarity: .positive, schedule: .timesPerWeek(5),
            effectiveLocalDateKey: "2024-06-17", revision: 1, createdAt: monday.addingTimeInterval(3600)
        )

        let inCreationOrder = HabitScheduleEvaluator.activeConfiguration(
            from: [firstEditOfTheDay, secondEditOfTheDay], on: monday, calendar: calendar
        )
        XCTAssertEqual(inCreationOrder, secondEditOfTheDay)

        let inReverseOrder = HabitScheduleEvaluator.activeConfiguration(
            from: [secondEditOfTheDay, firstEditOfTheDay], on: monday, calendar: calendar
        )
        XCTAssertEqual(inReverseOrder, secondEditOfTheDay)
    }

    func testActiveConfigurationWithIdenticalCreatedAtUsesRevisionToBreakTies() {
        let habitID = UUID()
        // Same local day AND the exact same `createdAt` instant — e.g. two edits
        // made from a single captured `Date()`, or two snapshots built with the
        // same injected timestamp. `createdAt` alone cannot disambiguate these;
        // only `revision` can, and the result must not depend on input order.
        let firstEditOfTheDay = HabitConfigurationSnapshot(
            id: UUID(), habitID: habitID, polarity: .positive, schedule: .daily,
            effectiveLocalDateKey: "2024-06-17", revision: 0, createdAt: monday
        )
        let secondEditOfTheDay = HabitConfigurationSnapshot(
            id: UUID(), habitID: habitID, polarity: .positive, schedule: .timesPerWeek(5),
            effectiveLocalDateKey: "2024-06-17", revision: 1, createdAt: monday
        )
        XCTAssertEqual(firstEditOfTheDay.createdAt, secondEditOfTheDay.createdAt, "the point of this test is a createdAt collision")

        let inCreationOrder = HabitScheduleEvaluator.activeConfiguration(
            from: [firstEditOfTheDay, secondEditOfTheDay], on: monday, calendar: calendar
        )
        XCTAssertEqual(inCreationOrder, secondEditOfTheDay)

        let inReverseOrder = HabitScheduleEvaluator.activeConfiguration(
            from: [secondEditOfTheDay, firstEditOfTheDay], on: monday, calendar: calendar
        )
        XCTAssertEqual(inReverseOrder, secondEditOfTheDay)
    }

    func testActiveConfigurationFallsBackToEarliestSnapshotWhenDatePrecedesAll() {
        let habitID = UUID()
        let onlySnapshot = HabitConfigurationSnapshot(
            id: UUID(), habitID: habitID, polarity: .positive, schedule: .daily,
            effectiveLocalDateKey: "2024-06-17", revision: 0, createdAt: monday
        )
        let earlier = Date(timeIntervalSince1970: 1_577_836_800) // 2020-01-01

        let resolved = HabitScheduleEvaluator.activeConfiguration(from: [onlySnapshot], on: earlier, calendar: calendar)
        XCTAssertEqual(resolved, onlySnapshot)
    }
    func testHistoricalConfigurationSurvivesUserCalendarIdentifierSwitches() {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = calendar.timeZone
        let habitID = UUID()
        let original = HabitConfigurationSnapshot(id: UUID(), habitID: habitID, polarity: .positive,
            schedule: .daily, effectiveLocalDateKey: LocalDay.key(for: monday, calendar: buddhist),
            revision: 0, createdAt: monday)
        let edited = HabitConfigurationSnapshot(id: UUID(), habitID: habitID, polarity: .positive,
            schedule: .timesPerWeek(3), effectiveLocalDateKey: LocalDay.key(for: wednesday, calendar: calendar),
            revision: 1, createdAt: wednesday)
        for identifier in [Calendar.Identifier.gregorian, .buddhist, .japanese, .islamicUmmAlQura] {
            var current = Calendar(identifier: identifier)
            current.timeZone = calendar.timeZone
            XCTAssertEqual(HabitScheduleEvaluator.activeConfiguration(from: [edited, original], on: monday, calendar: current)?.id,
                           original.id, "Original date must keep its historical configuration")
            XCTAssertEqual(HabitScheduleEvaluator.activeConfiguration(from: [edited, original], on: wednesday, calendar: current)?.id,
                           edited.id, "Later edit must remain latest after switching calendars")
        }
    }

}
