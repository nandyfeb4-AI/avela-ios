import Foundation
import SwiftData
import XCTest
@testable import Avela

@MainActor
final class HomeCalendarModelTests: XCTestCase {
    private var retainedContainer: ModelContainer?

    private func calendar(zone: String = "America/New_York", firstWeekday: Int = 2) -> Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: zone)!
        value.locale = Locale(identifier: "en_US_POSIX")
        value.firstWeekday = firstWeekday
        return value
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0,
                      in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func repository(calendar: Calendar) throws -> SwiftDataHabitRepository {
        let store = try AppPersistence.makeContainer(inMemory: true)
        retainedContainer = store
        return SwiftDataHabitRepository(modelContext: store.mainContext, calendar: calendar)
    }

    private func create(_ name: String, at date: Date, in repo: SwiftDataHabitRepository,
                        schedule: HabitSchedule = .daily) throws -> Habit {
        try repo.createHabit(HabitDraft(name: name, iconName: "book", category: .learning,
                                        polarity: .positive, schedule: schedule), at: date)
    }

    private func state(_ model: HomeCalendarModel, key: String, habitID: UUID) throws -> HabitCalendarCalculator.DayState {
        let day = try XCTUnwrap(model.month.first { $0.key == key })
        return try XCTUnwrap(day.rows.first { $0.habit.id == habitID }).state
    }

    func testWeekUsesCivilDaysAcrossDaylightSavingAndHonorsWeekStart() throws {
        let cal = calendar(firstWeekday: 1)
        let repo = try repository(calendar: cal)
        _ = try create("Read", at: date(2027, 3, 1, in: cal), in: repo)
        let now = date(2027, 3, 18, in: cal)
        let model = HomeCalendarModel(repository: repo, calendar: cal)
        model.load(asOf: now)

        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.week.map(\.key), (14...20).map { "2027-03-\($0)" })
        XCTAssertEqual(model.week.filter(\.isToday).map(\.key), ["2027-03-18"])
        XCTAssertEqual(model.week[1].date.timeIntervalSince(model.week[0].date), 23 * 3600)
        XCTAssertEqual(model.month.count, 31)
        XCTAssertEqual(Set(model.month.map(\.key)).count, 31)
        XCTAssertTrue(model.week.allSatisfy { cal.component(.hour, from: $0.date) == 0 })
        XCTAssertEqual(model.week.filter(\.isFuture).map(\.key), ["2027-03-19", "2027-03-20"])
    }

    func testHistoricalMonthSelectionNeverChangesTheCurrentWeekOrTrackingFacts() throws {
        let cal = calendar(zone: "UTC")
        let repo = try repository(calendar: cal)
        let start = date(2024, 12, 20, in: cal)
        let habit = try create("Read", at: start, in: repo)
        let completion = try repo.recordCompletion(habitID: habit.id, at: start, source: .app, note: nil)
        let skip = try repo.recordSkip(habitID: habit.id, on: date(2024, 12, 21, in: cal), reason: .planned)
        let now = date(2025, 2, 5, in: cal)
        let model = HomeCalendarModel(repository: repo, calendar: cal)
        model.load(asOf: now)
        let week = model.week.map(\.key)

        model.showMonth(containing: start, asOf: now)
        XCTAssertEqual(model.monthTitle, "December 2024")
        XCTAssertEqual(model.week.map(\.key), week)
        XCTAssertEqual(model.week.filter(\.isToday).map(\.key), ["2025-02-05"])
        XCTAssertFalse(model.canGoBack)
        XCTAssertTrue(model.canGoForward)
        model.moveMonth(by: -1, asOf: now)
        XCTAssertEqual(model.monthTitle, "December 2024")
        model.moveMonth(by: 1, asOf: now)
        XCTAssertEqual(model.monthTitle, "January 2025")
        model.showCurrentMonth(asOf: now)
        XCTAssertEqual(model.monthTitle, "February 2025")
        XCTAssertFalse(model.canGoForward)
        XCTAssertEqual(model.week.map(\.key), week)

        let all = DateInterval(start: .distantPast, end: .distantFuture)
        XCTAssertEqual(try repo.completions(in: all).map(\.id), [completion.id])
        XCTAssertEqual(try repo.skips(in: all).map(\.id), [skip.id])
        XCTAssertEqual(try repo.configurationHistory(for: habit.id).count, 1)
        XCTAssertTrue(try repo.archivePeriods(for: habit.id).isEmpty)
    }

    func testSelectingAnOrdinaryDateUsesItsMonthStartForAlignmentAndNavigation() throws {
        let cal = calendar(zone: "UTC")
        let repo = try repository(calendar: cal)
        _ = try create("Read", at: date(2024, 12, 20, in: cal), in: repo)
        let model = HomeCalendarModel(repository: repo, calendar: cal)
        let now = date(2025, 2, 5, in: cal)
        model.showMonth(containing: date(2024, 12, 20, hour: 18, in: cal), asOf: now)
        XCTAssertEqual(model.monthTitle, "December 2024")
        XCTAssertEqual(model.month.first?.key, "2024-12-01")
        XCTAssertEqual(model.leadingBlanks, 6, "December starts on Sunday in this Monday-first calendar")
        XCTAssertFalse(model.canGoBack, "A date later in the earliest month is not another browsable month")
        model.moveMonth(by: 1, asOf: now)
        XCTAssertEqual(model.monthTitle, "January 2025")
        XCTAssertEqual(model.leadingBlanks, 2)
        model.moveMonth(by: -1, asOf: now)
        XCTAssertEqual(model.monthTitle, "December 2024")
        XCTAssertFalse(model.canGoBack)
    }

    func testDailySkipsAndPausesStayNeutralAndFlexibleWeeksDoNotBecomeDailyMisses() throws {
        let cal = calendar(zone: "UTC")
        let repo = try repository(calendar: cal)
        let start = date(2024, 6, 17, in: cal)
        let daily = try create("Read", at: start, in: repo)
        let weekly = try create("Walk", at: start, in: repo, schedule: .timesPerWeek(3))
        _ = try repo.recordCompletion(habitID: daily.id, at: start, source: .app, note: nil)
        _ = try repo.recordCompletion(habitID: weekly.id, at: date(2024, 6, 18, in: cal), source: .app, note: nil)
        try repo.archiveHabit(id: daily.id, at: date(2024, 6, 18, in: cal))
        try repo.reactivateHabit(id: daily.id, at: date(2024, 6, 21, in: cal))
        _ = try repo.recordSkip(habitID: daily.id, on: date(2024, 6, 22, in: cal), reason: .planned)
        let model = HomeCalendarModel(repository: repo, calendar: cal)
        model.load(asOf: date(2024, 6, 24, in: cal))

        XCTAssertEqual(try state(model, key: "2024-06-17", habitID: daily.id), .success)
        XCTAssertEqual(try state(model, key: "2024-06-18", habitID: daily.id), .pending)
        XCTAssertEqual(try state(model, key: "2024-06-19", habitID: daily.id), .paused)
        XCTAssertEqual(try state(model, key: "2024-06-20", habitID: daily.id), .paused)
        XCTAssertEqual(try state(model, key: "2024-06-22", habitID: daily.id), .skipped)
        XCTAssertEqual(try state(model, key: "2024-06-24", habitID: daily.id), .pending)
        XCTAssertEqual(try state(model, key: "2024-06-25", habitID: daily.id), .future)
        XCTAssertEqual(try state(model, key: "2024-06-18", habitID: weekly.id), .logged)
        XCTAssertEqual(try state(model, key: "2024-06-19", habitID: weekly.id), .weekly)
        XCTAssertFalse(model.month.flatMap(\.rows).contains { $0.habit.id == weekly.id && $0.state == .missed })
        XCTAssertEqual(model.month.first { $0.key == "2024-06-22" }?.loggedCount, 0,
                       "An excused skip is not a recorded habit success")
    }

    func testArchivedHabitsRetainTheirRecordedDaysAndAreExplicitlyArchived() throws {
        let cal = calendar(zone: "UTC")
        let repo = try repository(calendar: cal)
        let start = date(2025, 1, 3, in: cal)
        let habit = try create("Old reading", at: start, in: repo)
        let completion = try repo.recordCompletion(habitID: habit.id, at: start, source: .app, note: nil)
        try repo.archiveHabit(id: habit.id, at: date(2025, 1, 5, in: cal))
        let model = HomeCalendarModel(repository: repo, calendar: cal)
        model.showMonth(containing: start, asOf: date(2025, 2, 5, in: cal))

        XCTAssertTrue(try repo.fetchHabits(includeArchived: false).isEmpty)
        let recorded = try XCTUnwrap(model.month.first { $0.key == "2025-01-03" })
        XCTAssertEqual(recorded.loggedCount, 1)
        XCTAssertTrue(try XCTUnwrap(recorded.rows.first).habit.isArchived)
        XCTAssertEqual(try state(model, key: "2025-01-06", habitID: habit.id), .paused)
        XCTAssertEqual(try repo.completions(in: DateInterval(start: .distantPast, end: .distantFuture)).map(\.id), [completion.id])
    }

    func testActivityCountUsesDistinctHabitsWithoutCallingOffScheduleRecordsAdherence() throws {
        let cal = calendar(zone: "UTC")
        let repo = try repository(calendar: cal)
        let start = date(2025, 1, 6, in: cal)
        let daily = try create("Read", at: start, in: repo)
        let weekly = try create("Walk", at: start, in: repo, schedule: .timesPerWeek(3))
        _ = try repo.recordCompletion(habitID: daily.id, at: start, source: .app, note: nil)
        _ = try repo.recordCompletion(habitID: weekly.id, at: start, source: .app, note: nil)
        let model = HomeCalendarModel(repository: repo, calendar: cal)
        model.load(asOf: start)
        let recorded = try XCTUnwrap(model.month.first { $0.key == "2025-01-06" })
        XCTAssertEqual(recorded.loggedCount, 2)
        XCTAssertEqual(Set(recorded.rows.filter { $0.state == .success || $0.state == .logged }.map(\.id)).count, 2)
        XCTAssertEqual(try state(model, key: "2025-01-06", habitID: weekly.id), .logged)
        XCTAssertEqual(model.month.first { $0.key == "2025-01-05" }?.rows.count, 0)
    }

    func testPartialQuantityAndSmallerActionCountOnceWithoutCreatingHabitSuccess() throws {
        let cal = calendar(zone: "UTC")
        let repo = try repository(calendar: cal)
        let now = date(2025, 1, 6, in: cal)
        let habit = try create("Read", at: now, in: repo)
        let activity = SwiftDataHabitActivityRepository(context: try XCTUnwrap(retainedContainer).mainContext,
                                                       habits: repo, calendar: cal)
        try activity.configure(habitID: habit.id, target: .init(amount: 10, unit: .pages),
                               smallerAction: "One paragraph", at: now)
        let config = try XCTUnwrap(activity.configuration(for: habit.id, on: now))
        try activity.log(habitID: habit.id, kind: .quantity, amount: 3,
                         expectedConfigurationID: config.id, on: now, now: now)
        try activity.log(habitID: habit.id, kind: .smallerAction, amount: 0,
                         expectedConfigurationID: config.id, on: now, now: now)
        let model = HomeCalendarModel(repository: repo, activities: activity, calendar: cal)
        model.load(asOf: now)
        let day = try XCTUnwrap(model.week.first { $0.key == "2025-01-06" })
        XCTAssertEqual(day.loggedCount, 1, "Two activity kinds from one habit remain one recorded habit")
        let row = try XCTUnwrap(day.rows.first { $0.id == habit.id })
        XCTAssertTrue(row.hasRecordedActivity)
        XCTAssertEqual(row.state, .pending, "Recorded effort is separate from a successful commitment")
        XCTAssertTrue(try repo.completions(for: habit.id, in: XCTUnwrap(cal.dateInterval(of: .day, for: now))).isEmpty)
        XCTAssertEqual(try activity.entries(for: habit.id, on: now).count, 2)
    }

    func testTravelKeepsStoredFactsAccessibleAcrossBothMonthBoundaries() throws {
        let loggedCalendar = calendar(zone: "America/Los_Angeles")
        let repo = try repository(calendar: loggedCalendar)
        let loggedAt = date(2025, 1, 31, hour: 23, minute: 30, in: loggedCalendar)
        let habit = try create("Travel", at: loggedAt, in: repo)
        _ = try repo.recordCompletion(habitID: habit.id, at: loggedAt, source: .app, note: nil)
        let travelCalendar = calendar(zone: "Asia/Tokyo")
        let abroad = HomeCalendarModel(repository: repo, calendar: travelCalendar)
        abroad.load(asOf: loggedAt)
        XCTAssertTrue(abroad.canGoBack)
        abroad.moveMonth(by: -1, asOf: loggedAt)
        XCTAssertEqual(abroad.monthTitle, "January 2025")
        XCTAssertEqual(try state(abroad, key: "2025-01-31", habitID: habit.id), .logged)
        XCTAssertEqual(abroad.month.first { $0.key == "2025-01-31" }?.loggedCount, 1)

        let marchInstant = date(2025, 3, 1, hour: 1, in: travelCalendar)
        let travelRepo = SwiftDataHabitRepository(modelContext: try XCTUnwrap(retainedContainer).mainContext,
                                                 calendar: travelCalendar)
        _ = try travelRepo.recordCompletion(habitID: habit.id, at: marchInstant, source: .app, note: nil)
        let home = HomeCalendarModel(repository: repo, calendar: loggedCalendar)
        home.load(asOf: marchInstant)
        XCTAssertTrue(home.canGoForward)
        home.moveMonth(by: 1, asOf: marchInstant)
        XCTAssertEqual(home.monthTitle, "March 2025")
        XCTAssertEqual(try state(home, key: "2025-03-01", habitID: habit.id), .logged)
        XCTAssertFalse(home.canGoForward)
        XCTAssertFalse(home.month.flatMap(\.rows).contains { $0.state == .missed })
    }

    func testEmptyLibraryStillHasARealCurrentWeekAndCannotBrowseInventedHistory() throws {
        let cal = calendar(zone: "UTC")
        let repo = try repository(calendar: cal)
        let model = HomeCalendarModel(repository: repo, calendar: cal)
        let now = date(2025, 2, 5, in: cal)
        model.load(asOf: now)
        XCTAssertEqual(model.week.count, 7)
        XCTAssertEqual(model.month.count, 28)
        XCTAssertTrue(model.week.allSatisfy { $0.rows.isEmpty && $0.loggedCount == 0 })
        XCTAssertFalse(model.canGoBack)
        XCTAssertFalse(model.canGoForward)
        model.showMonth(containing: date(2020, 1, 1, in: cal), asOf: now)
        XCTAssertEqual(model.monthTitle, "February 2025")
        XCTAssertNil(model.errorMessage)
    }
}
