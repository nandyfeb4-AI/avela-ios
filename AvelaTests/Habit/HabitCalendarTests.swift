import Foundation
import SwiftData
import XCTest
@testable import Avela

final class HabitCalendarCalculatorTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 2
        return calendar
    }
    private func day(_ offset: Int) -> Date { Date(timeIntervalSince1970: 1_718_632_800 + Double(offset) * 86_400) }
    private func habit(_ schedule: HabitSchedule = .daily) -> Habit {
        Habit(id: UUID(), name: "Read", iconName: "book", category: .learning, polarity: .positive,
              schedule: schedule, createdAt: day(0), updatedAt: day(0), archivedAt: nil, sortOrder: 0)
    }
    private func snapshot(_ habit: Habit, schedule: HabitSchedule? = nil, offset: Int = 0, revision: Int = 0) -> HabitConfigurationSnapshot {
        HabitConfigurationSnapshot(id: UUID(), habitID: habit.id, polarity: .positive, schedule: schedule ?? habit.schedule,
            effectiveLocalDateKey: LocalDay.key(for: day(offset), calendar: calendar), revision: revision, createdAt: day(offset))
    }
    private func completion(_ habit: Habit, _ offset: Int, key: String? = nil) -> Completion {
        Completion(id: UUID(), habitID: habit.id, occurredAt: day(offset), localDateKey: key ?? LocalDay.key(for: day(offset), calendar: calendar), source: .app, note: nil)
    }
    private func month(_ habit: Habit, completions: [Completion] = [], skips: [Skip] = [], snapshots: [HabitConfigurationSnapshot]? = nil,
                       pauses: [HabitArchivePeriod] = [], offset: Int = 5) -> HabitCalendarCalculator.Month {
        HabitCalendarCalculator.month(containing: day(0), habit: habit, snapshots: snapshots ?? [snapshot(habit)],
            completions: completions, skips: skips, archivePeriods: pauses, asOf: day(offset), calendar: calendar)
    }
    private func state(_ result: HabitCalendarCalculator.Month, _ offset: Int) throws -> HabitCalendarCalculator.DayState {
        try XCTUnwrap(result.days.first { $0.key == LocalDay.key(for: day(offset), calendar: calendar) }).state
    }

    func testDailyFactsExcusedSkipPendingAndFutureMatchStreakRules() throws {
        let h = habit()
        let skip = Skip(id: UUID(), habitID: h.id, localDateKey: "2024-06-18", reason: .planned, createdAt: day(1))
        let result = month(h, completions: [completion(h, 0), completion(h, 2)], skips: [skip], offset: 3)
        XCTAssertEqual(try state(result, 0), .success)
        XCTAssertEqual(try state(result, 1), .skipped)
        XCTAssertEqual(try state(result, 2), .success)
        XCTAssertEqual(try state(result, 3), .pending)
        XCTAssertEqual(try state(result, 4), .future)
        XCTAssertEqual(try state(result, -1), .notStarted)
        XCTAssertEqual(result.streak.currentStreak, 2)
    }

    func testMissAndUndoUseSameFactsAsNumericStreak() throws {
        let h = habit()
        let completed = month(h, completions: [completion(h, 0), completion(h, 1)], offset: 2)
        XCTAssertEqual(completed.streak.currentStreak, 2)
        let undone = month(h, completions: [completion(h, 0)], offset: 2)
        XCTAssertEqual(try state(undone, 1), .missed)
        XCTAssertEqual(undone.streak.currentStreak, 0)
    }

    func testClosedArchiveGapIsNeutralAndBoundaryRemainsPending() throws {
        let h = habit()
        let pause = HabitArchivePeriod(id: UUID(), habitID: h.id, archivedAt: day(1), reactivatedAt: day(4))
        let result = month(h, completions: [completion(h, 0), completion(h, 4)], pauses: [pause])
        XCTAssertEqual(try state(result, 1), .pending)
        XCTAssertEqual(try state(result, 2), .paused)
        XCTAssertEqual(try state(result, 3), .paused)
        XCTAssertEqual(try state(result, 4), .success)
        XCTAssertEqual(result.streak.currentStreak, 2)
    }

    func testNextDayReactivationKeepsArchiveDayPendingWithoutAFullDormantDay() throws {
        let h = habit()
        let pause = HabitArchivePeriod(id: UUID(), habitID: h.id, archivedAt: day(1), reactivatedAt: day(2))
        let result = month(h, completions: [completion(h, 0), completion(h, 2)], pauses: [pause], offset: 3)
        XCTAssertEqual(try state(result, 1), .pending)
        XCTAssertEqual(try state(result, 2), .success)
        XCTAssertEqual(result.streak.currentStreak, 2)
        XCTAssertFalse(result.days.contains { $0.key == "2024-06-18" && $0.state == .missed })
    }

    func testWeeklyNextDayReactivationSplitsPeriodWithoutManufacturingMiss() {
        let h = habit(.timesPerWeek(3))
        let pause = HabitArchivePeriod(id: UUID(), habitID: h.id, archivedAt: day(1), reactivatedAt: day(2))
        let result = month(h, completions: [completion(h, 0)], pauses: [pause], offset: 3)
        XCTAssertEqual(result.weeklyPeriods.map(\.outcome), [.pending, .pending])
        XCTAssertEqual(result.weeklyPeriods.first?.periodEnd, calendar.startOfDay(for: day(2)))
        XCTAssertEqual(result.weeklyPeriods.last?.periodStart, calendar.startOfDay(for: day(2)))
    }

    func testOpenArchiveStopsDailyMisses() throws {
        var h = habit()
        h.archivedAt = day(1)
        let result = month(h, completions: [completion(h, 0)])
        XCTAssertEqual(try state(result, 1), .pending)
        XCTAssertEqual(try state(result, 2), .paused)
        XCTAssertEqual(result.streak.currentStreak, 1)
    }

    func testFlexibleWeeklyShowsPeriodOutcomeAndNoDailyMisses() throws {
        let h = habit(.timesPerWeek(3))
        let result = month(h, completions: [completion(h, 0), completion(h, 0), completion(h, 2)], offset: 7)
        XCTAssertEqual(try state(result, 1), .weekly)
        XCTAssertEqual(try state(result, 0), .logged)
        XCTAssertEqual(result.weeklyPeriods.count, 2)
        XCTAssertEqual(result.weeklyPeriods[0].completedCount, 2, "Duplicate check-ins are not extra commitment days")
        XCTAssertEqual(result.weeklyPeriods[0].outcome, .miss)
        XCTAssertEqual(result.weeklyPeriods[1].outcome, .pending)
        XCTAssertFalse(result.days.contains { $0.state == .missed })
        XCTAssertEqual(result.streak.unit, .weeks)
    }

    func testWeeklySuccessCountsOneStreakUnitAndPauseSplitsEvaluatedRanges() throws {
        let h = habit(.timesPerWeek(2))
        let pause = HabitArchivePeriod(id: UUID(), habitID: h.id, archivedAt: day(2), reactivatedAt: day(5))
        let result = month(h, completions: [completion(h, 0), completion(h, 1)], pauses: [pause], offset: 6)
        XCTAssertEqual(result.weeklyPeriods.map(\.outcome), [.success, .pending])
        XCTAssertEqual(result.weeklyPeriods[0].periodEnd, calendar.startOfDay(for: day(3)))
        XCTAssertEqual(result.weeklyPeriods[1].periodStart, calendar.startOfDay(for: day(5)))
        XCTAssertEqual(result.streak.currentStreak, 1)
        XCTAssertEqual(try state(result, 3), .paused)
    }

    func testLastDayOfWeekStaysPendingUntilFollowingMidnight() {
        let h = habit(.timesPerWeek(2))
        let lastDay = month(h, completions: [completion(h, 0)], offset: 6)
        XCTAssertEqual(lastDay.weeklyPeriods.first?.outcome, .pending)
        let firstDayNextWeek = month(h, completions: [completion(h, 0)], offset: 7)
        XCTAssertEqual(firstDayNextWeek.weeklyPeriods.first?.outcome, .miss)
        XCTAssertEqual(firstDayNextWeek.weeklyPeriods.last?.outcome, .pending)
    }

    func testHistoricalScheduleChangesKeepOldDailyCommitmentsAndNewWeeklyUnits() throws {
        let h = habit(.timesPerWeek(2))
        let snapshots = [snapshot(h, schedule: .daily), snapshot(h, schedule: .timesPerWeek(2), offset: 2, revision: 1)]
        let result = month(h, completions: [completion(h, 0), completion(h, 2), completion(h, 3)], snapshots: snapshots)
        XCTAssertEqual(try state(result, 0), .success)
        XCTAssertEqual(try state(result, 1), .missed)
        XCTAssertEqual(try state(result, 4), .weekly)
        XCTAssertEqual(result.weeklyPeriods.first?.periodStart, calendar.startOfDay(for: day(2)))
        XCTAssertEqual(result.weeklyPeriods.first?.outcome, .success)
    }

    func testWeekdayOffDaysAreNeutralAndGridHonorsMondayStart() throws {
        let h = habit(.weekdays([.monday, .wednesday]))
        let result = month(h, completions: [completion(h, 0)], offset: 3)
        XCTAssertEqual(result.leadingBlankCount, 5, "June 1 2024 is Saturday")
        XCTAssertEqual(result.days.count, 30)
        XCTAssertEqual(try state(result, 1), .notScheduled)
        XCTAssertEqual(try state(result, 2), .missed)
        XCTAssertEqual(try state(result, 3), .notScheduled)
    }

    func testStoredKeyWinsOverTimestampAfterTravelAndOtherHabitsAreExcluded() throws {
        let h = habit()
        let result = month(h, completions: [completion(h, 1, key: "2024-06-17"), completion(habit(), 2)], offset: 3)
        XCTAssertEqual(try state(result, 0), .success)
        XCTAssertEqual(try state(result, 1), .missed)
        XCTAssertEqual(try state(result, 2), .missed)
    }

    func testCalendarUsesCivilDatesEvenWithBuddhistUserCalendar() {
        let h = habit()
        var userCalendar = Calendar(identifier: .buddhist)
        userCalendar.timeZone = calendar.timeZone
        userCalendar.firstWeekday = 2
        let result = HabitCalendarCalculator.month(containing: day(0), habit: h, snapshots: [snapshot(h)],
            completions: [completion(h, 0)], skips: [], archivePeriods: [], asOf: day(2), calendar: userCalendar)
        XCTAssertEqual(result.days.first?.key, "2024-06-01")
        XCTAssertEqual(result.days.count, 30)
    }

    func testDSTMonthHasEveryCivilDayAndPeriodEndUsesCalendarArithmetic() {
        let start = calendar.date(from: DateComponents(year: 2024, month: 3, day: 9, hour: 10))!
        var h = habit(); h = Habit(id: h.id, name: h.name, iconName: h.iconName, category: h.category, polarity: h.polarity,
            schedule: .daily, createdAt: start, updatedAt: start, archivedAt: nil, sortOrder: 0)
        let snap = HabitConfigurationSnapshot(id: UUID(), habitID: h.id, polarity: .positive, schedule: .daily,
            effectiveLocalDateKey: "2024-03-09", revision: 0, createdAt: start)
        let end = calendar.date(byAdding: .day, value: 3, to: start)!
        let periods = HabitProgressCalculator.periods(for: h, snapshots: [snap], completions: [], skips: [], archivePeriods: [], asOf: end, calendar: calendar)
        let transition = periods.first { $0.localDateKey == "2024-03-10" }!
        XCTAssertEqual(transition.periodEnd.timeIntervalSince(transition.periodStart), 23 * 3600)
        let result = HabitCalendarCalculator.month(containing: start, habit: h, snapshots: [snap], completions: [], skips: [], archivePeriods: [], asOf: end, calendar: calendar)
        XCTAssertEqual(result.days.count, 31)
        XCTAssertEqual(Set(result.days.map(\.key)).count, 31)
    }
}

@MainActor
final class HabitCalendarViewModelTests: XCTestCase {
    private var container: ModelContainer?

    func testMonthNavigationDoesNotMutateFactsAndStopsAtCreationAndCurrentMonth() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 2
        let start = calendar.date(from: DateComponents(year: 2024, month: 12, day: 20, hour: 10))!
        let now = calendar.date(from: DateComponents(year: 2025, month: 2, day: 5, hour: 10))!
        let store = try AppPersistence.makeContainer(inMemory: true); container = store
        let repo = SwiftDataHabitRepository(modelContext: store.mainContext, calendar: calendar)
        let h = try repo.createHabit(HabitDraft(name: "Read", iconName: "book", category: .learning, polarity: .positive, schedule: .daily), at: start)
        let record = try repo.recordCompletion(habitID: h.id, at: start, source: .app, note: nil)
        let vm = HabitCalendarViewModel(habitID: h.id, repository: repo, calendar: calendar)
        vm.load(asOf: now)
        XCTAssertEqual(vm.monthTitle, "February 2025")
        XCTAssertFalse(vm.canGoForward)
        XCTAssertTrue(vm.canGoBack)
        XCTAssertEqual(vm.weekdayLabels.first, "Mon")
        vm.moveMonth(by: -1, asOf: now)
        XCTAssertEqual(vm.monthTitle, "January 2025")
        vm.moveMonth(by: -1, asOf: now)
        XCTAssertEqual(vm.monthTitle, "December 2024")
        XCTAssertFalse(vm.canGoBack)
        vm.moveMonth(by: -1, asOf: now)
        XCTAssertEqual(vm.monthTitle, "December 2024")
        XCTAssertEqual(vm.month?.days.first { $0.key == "2024-12-20" }?.state, .success)
        vm.showCurrentMonth(asOf: now)
        XCTAssertEqual(vm.monthTitle, "February 2025")
        XCTAssertEqual(try repo.completions(for: h.id, in: DateInterval(start: .distantPast, end: .distantFuture)).map(\.id), [record.id])
        XCTAssertTrue(try repo.skips(for: h.id, in: DateInterval(start: .distantPast, end: .distantFuture)).isEmpty)
        XCTAssertEqual(try repo.configurationHistory(for: h.id).count, 1)
    }

    func testTravelDoesNotHideStoredFactsInPreviousOrFollowingMonth() throws {
        var loggedCalendar = Calendar(identifier: .gregorian)
        loggedCalendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let loggedAt = loggedCalendar.date(from: DateComponents(year: 2025, month: 1, day: 31, hour: 23, minute: 30))!
        let store = try AppPersistence.makeContainer(inMemory: true); container = store
        let repo = SwiftDataHabitRepository(modelContext: store.mainContext, calendar: loggedCalendar)
        let h = try repo.createHabit(HabitDraft(name: "Travel", iconName: "airplane", category: .other, polarity: .positive, schedule: .daily), at: loggedAt)
        try repo.recordCompletion(habitID: h.id, at: loggedAt, source: .app, note: nil)
        var travelCalendar = loggedCalendar
        travelCalendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let vm = HabitCalendarViewModel(habitID: h.id, repository: repo, calendar: travelCalendar)
        vm.load(asOf: loggedAt)
        XCTAssertTrue(vm.canGoBack, "January fact must remain accessible even though creation instant is February in Tokyo")
        vm.moveMonth(by: -1, asOf: loggedAt)
        XCTAssertEqual(vm.month?.days.first { $0.key == "2025-01-31" }?.state, .logged)
        // Record March 1 in Tokyo, then view the same instant from LA where
        // it is still February. Only the actual future civil-month fact opens it.
        let marchInstant = travelCalendar.date(from: DateComponents(year: 2025, month: 3, day: 1, hour: 1))!
        let travelRepo = SwiftDataHabitRepository(modelContext: store.mainContext, calendar: travelCalendar)
        try travelRepo.recordCompletion(habitID: h.id, at: marchInstant, source: .app, note: nil)
        let backHome = HabitCalendarViewModel(habitID: h.id, repository: repo, calendar: loggedCalendar)
        backHome.load(asOf: marchInstant)
        XCTAssertTrue(backHome.canGoForward)
        backHome.moveMonth(by: 1, asOf: marchInstant)
        XCTAssertEqual(backHome.month?.days.first { $0.key == "2025-03-01" }?.state, .logged)
        XCTAssertFalse(backHome.canGoForward)
        XCTAssertFalse(backHome.month!.days.contains { $0.state == .missed })
    }

    func testMissingHabitProducesRecoverableErrorRatherThanSpinner() throws {
        let store = try AppPersistence.makeContainer(inMemory: true); container = store
        let vm = HabitCalendarViewModel(habitID: UUID(), repository: SwiftDataHabitRepository(modelContext: store.mainContext))
        vm.load()
        XCTAssertNil(vm.month)
        XCTAssertNotNil(vm.errorMessage)
    }
}
