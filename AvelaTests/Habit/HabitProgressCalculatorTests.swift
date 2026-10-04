import Foundation
import XCTest
@testable import Avela

final class HabitProgressCalculatorTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 1
        return calendar
    }()

    /// Monday 2024-06-17, 10:00 America/New_York. `day(n)` walks forward/back by
    /// `n` calendar days from there. June 2024 has no DST transition, so plain
    /// 86400s arithmetic lands on the same wall-clock hour each day.
    private let anchor = Date(timeIntervalSince1970: 1_718_632_800)
    private func day(_ n: Int) -> Date { anchor.addingTimeInterval(Double(n) * 86_400) }
    private func key(_ date: Date) -> String { LocalDay.key(for: date, calendar: calendar) }

    /// Midnight of `day(n)`. Every emitted unit's `periodStart` is midnight-
    /// aligned, so `DateInterval` range boundaries in tests must be too —
    /// `day(n)` itself (10:00) would exclude that day's own unit from a range
    /// starting at it.
    private func midnight(_ n: Int) -> Date { calendar.startOfDay(for: day(n)) }

    private func makeHabit(
        schedule: HabitSchedule,
        createdAt: Date,
        archivedAt: Date? = nil
    ) -> Habit {
        Habit(
            id: UUID(), name: "Test", iconName: "star", category: .other, polarity: .positive,
            schedule: schedule, createdAt: createdAt, updatedAt: createdAt, archivedAt: archivedAt, sortOrder: 0
        )
    }

    private func snapshot(
        habitID: UUID, schedule: HabitSchedule, effectiveFrom date: Date, revision: Int
    ) -> HabitConfigurationSnapshot {
        HabitConfigurationSnapshot(
            id: UUID(), habitID: habitID, polarity: .positive, schedule: schedule,
            effectiveLocalDateKey: key(date), revision: revision, createdAt: date
        )
    }

    private func completion(_ habitID: UUID, on date: Date) -> Completion {
        Completion(id: UUID(), habitID: habitID, occurredAt: date, localDateKey: key(date), source: .app, note: nil)
    }

    private func skip(_ habitID: UUID, on date: Date, reason: SkipReason = .planned) -> Skip {
        Skip(id: UUID(), habitID: habitID, localDateKey: key(date), reason: reason, createdAt: date)
    }

    private func archivePeriod(_ habitID: UUID, archivedAt: Date, reactivatedAt: Date?) -> HabitArchivePeriod {
        HabitArchivePeriod(id: UUID(), habitID: habitID, archivedAt: archivedAt, reactivatedAt: reactivatedAt)
    }

    // MARK: - Daily schedule

    func testDailyStreakBuildsAndBreaksOnMiss() {
        let habit = makeHabit(schedule: .daily, createdAt: day(0))
        let snapshots = [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(0), revision: 0)]
        // Mon, Tue, Wed completed; Thu missed; Fri completed.
        let completions = [day(0), day(1), day(2), day(4)].map { completion(habit.id, on: $0) }

        let streak = HabitProgressCalculator.streak(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: [], asOf: day(4), calendar: calendar
        )
        XCTAssertEqual(streak.currentStreak, 1)
        XCTAssertEqual(streak.bestStreak, 3)
        XCTAssertEqual(streak.unit, .days)

        let recovery = HabitProgressCalculator.recoveryProgress(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: [], asOf: day(4), calendar: calendar
        )
        XCTAssertEqual(recovery.lastMissedLocalDateKey, key(day(3)))
        XCTAssertEqual(recovery.consecutiveSuccessesSinceMiss, 1)
        XCTAssertTrue(recovery.isRecovering)
    }

    func testIncompleteCurrentDayCarriesYesterdaysStreakForward() {
        let habit = makeHabit(schedule: .daily, createdAt: day(0))
        let snapshots = [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(0), revision: 0)]
        // Mon-Thu completed; Friday (evaluation day) not completed yet.
        let completions = [day(0), day(1), day(2), day(3)].map { completion(habit.id, on: $0) }

        let streak = HabitProgressCalculator.streak(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: [], asOf: day(4), calendar: calendar
        )
        XCTAssertEqual(streak.currentStreak, 4, "today being unfinished must not erase yesterday's streak")
        XCTAssertEqual(streak.bestStreak, 4)
    }

    func testIncompleteCurrentDayDoesNotResurrectAStreakBrokenYesterday() {
        let habit = makeHabit(schedule: .daily, createdAt: day(0))
        let snapshots = [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(0), revision: 0)]
        // Mon-Wed completed, Thu missed, Friday (evaluation day) not completed yet.
        let completions = [day(0), day(1), day(2)].map { completion(habit.id, on: $0) }

        let streak = HabitProgressCalculator.streak(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: [], asOf: day(4), calendar: calendar
        )
        XCTAssertEqual(streak.currentStreak, 0)
        XCTAssertEqual(streak.bestStreak, 3)

        let recovery = HabitProgressCalculator.recoveryProgress(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: [], asOf: day(4), calendar: calendar
        )
        XCTAssertEqual(recovery.lastMissedLocalDateKey, key(day(3)))
        XCTAssertEqual(recovery.consecutiveSuccessesSinceMiss, 0)
    }

    func testDuplicateSameDayCompletionsDoNotInflateDailyStreak() {
        let habit = makeHabit(schedule: .daily, createdAt: day(0))
        let snapshots = [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(0), revision: 0)]
        // Three completions logged on the same day.
        let completions = [day(0), day(0), day(0)].map { completion(habit.id, on: $0) }

        let streak = HabitProgressCalculator.streak(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: [], asOf: day(0), calendar: calendar
        )
        XCTAssertEqual(streak.currentStreak, 1)
        XCTAssertEqual(streak.bestStreak, 1)
    }

    func testStreakTreatsNearMidnightCompletionsAsSeparateDays() {
        let habit = makeHabit(schedule: .daily, createdAt: day(0))
        let snapshots = [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(0), revision: 0)]
        let justBeforeMidnight = Date(timeIntervalSince1970: 1_718_683_140) // Mon 23:59 EDT
        let justAfterMidnight = Date(timeIntervalSince1970: 1_718_683_260) // Tue 00:01 EDT
        let completions = [completion(habit.id, on: justBeforeMidnight), completion(habit.id, on: justAfterMidnight)]

        let streak = HabitProgressCalculator.streak(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: [], asOf: justAfterMidnight, calendar: calendar
        )
        XCTAssertEqual(streak.currentStreak, 2, "a completion at 23:59 and one at 00:01 the next day are two distinct days")
    }

    // MARK: - Skips

    func testSkipExcusesADayWithoutBreakingStreakOrCountingAsSuccess() {
        let habit = makeHabit(schedule: .daily, createdAt: day(0))
        let snapshots = [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(0), revision: 0)]
        let completions = [day(0), day(2)].map { completion(habit.id, on: $0) } // Mon, Wed
        let skips = [skip(habit.id, on: day(1))] // Tue excused

        let streak = HabitProgressCalculator.streak(
            for: habit, snapshots: snapshots, completions: completions, skips: skips, archivePeriods: [], asOf: day(2), calendar: calendar
        )
        XCTAssertEqual(streak.currentStreak, 2, "an excused day must not break the streak")
        XCTAssertEqual(streak.bestStreak, 2)

        let consistency = HabitProgressCalculator.consistency(
            for: habit, snapshots: snapshots, completions: completions, skips: skips, archivePeriods: [],
            in: DateInterval(start: midnight(0), end: midnight(3)), asOf: day(2), calendar: calendar
        )
        XCTAssertEqual(consistency.successfulUnits, 2)
        XCTAssertEqual(consistency.scheduledUnits, 2, "the skipped day must be excluded from the denominator, not counted against it")
        XCTAssertEqual(consistency.percentage, 1.0)
    }

    // MARK: - Weekdays schedule

    func testWeekdayScheduleStreakIgnoresNonScheduledDays() {
        let habit = makeHabit(schedule: .weekdays([.monday, .wednesday, .friday]), createdAt: day(0))
        let snapshots = [snapshot(habitID: habit.id, schedule: .weekdays([.monday, .wednesday, .friday]), effectiveFrom: day(0), revision: 0)]
        // Mon(0), Wed(2), Fri(4), next Mon(7) — all scheduled days completed.
        let completions = [day(0), day(2), day(4), day(7)].map { completion(habit.id, on: $0) }

        let streak = HabitProgressCalculator.streak(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: [], asOf: day(7), calendar: calendar
        )
        XCTAssertEqual(streak.currentStreak, 4, "Tue/Thu/weekend must not count as misses for a Mon/Wed/Fri schedule")
        XCTAssertEqual(streak.bestStreak, 4)
    }

    // MARK: - Flexible weekly schedule

    func testFlexibleWeeklyUsesSuccessfulWeeksNotDailyStreaks() {
        let habit = makeHabit(schedule: .timesPerWeek(3), createdAt: day(-1)) // created Sunday, week-aligned
        let snapshots = [snapshot(habitID: habit.id, schedule: .timesPerWeek(3), effectiveFrom: day(-1), revision: 0)]
        // Week 1 (Sun -1 ... Sat 5): Mon/Wed/Fri completed -> target met.
        // Week 2 (Sun 6 ... Sat 12): only 2 distinct days -> miss (evaluated at natural week end).
        // Week 3 (Sun 13 ... Sat 19): 3 distinct days by midweek -> success while week still open.
        let completions = [day(0), day(2), day(4), day(7), day(8), day(13), day(14), day(15)]
            .map { completion(habit.id, on: $0) }

        let streakAfterWeek1 = HabitProgressCalculator.streak(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: [], asOf: day(4), calendar: calendar
        )
        XCTAssertEqual(streakAfterWeek1.currentStreak, 1, "a week already at target is a success even mid-week")
        XCTAssertEqual(streakAfterWeek1.unit, .weeks)

        let streakAfterWeek2 = HabitProgressCalculator.streak(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: [], asOf: day(12), calendar: calendar
        )
        XCTAssertEqual(streakAfterWeek2.currentStreak, 0, "week 2 fell short of target by its natural end")
        XCTAssertEqual(streakAfterWeek2.bestStreak, 1)

        let streakAfterWeek3 = HabitProgressCalculator.streak(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: [], asOf: day(15), calendar: calendar
        )
        XCTAssertEqual(streakAfterWeek3.currentStreak, 1)

        let recovery = HabitProgressCalculator.recoveryProgress(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: [], asOf: day(15), calendar: calendar
        )
        XCTAssertEqual(recovery.lastMissedLocalDateKey, key(day(6)), "the miss is recorded as the missed week's start day")
        XCTAssertEqual(recovery.consecutiveSuccessesSinceMiss, 1)
    }

    func testDuplicateSameDayCompletionsDoNotInflateWeeklyTarget() {
        let habit = makeHabit(schedule: .timesPerWeek(3), createdAt: day(-1))
        let snapshots = [snapshot(habitID: habit.id, schedule: .timesPerWeek(3), effectiveFrom: day(-1), revision: 0)]
        // Monday logged twice, Wednesday once: 2 distinct days, not 3.
        let completions = [day(0), day(0), day(2)].map { completion(habit.id, on: $0) }

        let streak = HabitProgressCalculator.streak(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: [], asOf: day(5), calendar: calendar // Saturday: natural week end
        )
        XCTAssertEqual(streak.currentStreak, 0, "two completions on one day must not count as two distinct days toward the target")
    }

    // MARK: - Historical configuration / schedule edits

    func testHistoricalScheduleEditMidWeekSplitsPartialPeriodsCorrectly() {
        let habit = makeHabit(schedule: .timesPerWeek(2), createdAt: day(0))
        let snapshots = [
            snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(0), revision: 0),
            snapshot(habitID: habit.id, schedule: .timesPerWeek(2), effectiveFrom: day(2), revision: 1), // Wed
        ]
        // Mon, Tue completed under the old daily schedule.
        // Only Thu completed under the new weekly schedule (1 distinct day < target 2).
        let completions = [day(0), day(1), day(3)].map { completion(habit.id, on: $0) }

        // Evaluate at Saturday (day 5), the natural end of the week containing the edit.
        let streak = HabitProgressCalculator.streak(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: [], asOf: day(5), calendar: calendar
        )
        XCTAssertEqual(streak.currentStreak, 0, "the partial week after the edit fell short of its own target")
        XCTAssertEqual(streak.bestStreak, 2, "the two daily successes before the edit must be preserved")
        XCTAssertEqual(streak.unit, .weeks, "unit reflects the schedule active as of the evaluation date")
    }

    // MARK: - Archiving

    func testArchivedHabitFreezesMetricsAtTheArchiveDate() {
        let archivedAt = day(2) // Wednesday
        let habit = makeHabit(schedule: .daily, createdAt: day(0), archivedAt: archivedAt)
        let snapshots = [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(0), revision: 0)]
        let completions = [day(0), day(1), day(2)].map { completion(habit.id, on: $0) }

        // Evaluate two weeks after archiving, with no further activity recorded.
        let streak = HabitProgressCalculator.streak(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: [], asOf: day(16), calendar: calendar
        )
        XCTAssertEqual(streak.currentStreak, 3, "the gap after archiving must not be read back as missed days")
        XCTAssertEqual(streak.bestStreak, 3)
    }

    // MARK: - Consistency over an explicit range

    func testConsistencyOverExplicitRangeOnlyCountsThatWindow() {
        let habit = makeHabit(schedule: .daily, createdAt: day(0))
        let snapshots = [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(0), revision: 0)]
        // Week 1 (days 0-6): every day completed.
        // Week 2 (days 7-13): every day missed.
        let completions = (0...6).map { completion(habit.id, on: day($0)) }

        // Evaluated one day past both windows so neither window's last day is
        // the still-open "pending" day; every unit inside [day(0), day(14)) is
        // therefore fully determined (success or miss), not excluded.
        let week1Consistency = HabitProgressCalculator.consistency(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: [],
            in: DateInterval(start: midnight(0), end: midnight(7)), asOf: day(14), calendar: calendar
        )
        XCTAssertEqual(week1Consistency.successfulUnits, 7)
        XCTAssertEqual(week1Consistency.scheduledUnits, 7)
        XCTAssertEqual(week1Consistency.percentage, 1.0)

        let week2Consistency = HabitProgressCalculator.consistency(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: [],
            in: DateInterval(start: midnight(7), end: midnight(14)), asOf: day(14), calendar: calendar
        )
        XCTAssertEqual(week2Consistency.successfulUnits, 0)
        XCTAssertEqual(week2Consistency.scheduledUnits, 7)
        XCTAssertEqual(week2Consistency.percentage, 0.0)
    }

    func testConsistencyRangeIsHalfOpenAtItsEndBoundary() {
        // DateInterval itself is a *closed* interval, so this guards against
        // regressing to `range.contains(_:)`, which would incorrectly include
        // the day exactly at `range.end` (the first day of the *next* period).
        let habit = makeHabit(schedule: .daily, createdAt: day(0))
        let snapshots = [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(0), revision: 0)]
        let completions: [Completion] = [] // every day missed
        let range = DateInterval(start: midnight(0), end: midnight(3)) // Mon-Wed only

        let consistency = HabitProgressCalculator.consistency(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: [],
            in: range, asOf: day(5), calendar: calendar
        )
        XCTAssertEqual(consistency.scheduledUnits, 3, "day 3 starts exactly at range.end and must be excluded")
    }

    func testConsistencyIsZeroNotNaNWhenNothingIsScheduledInRange() {
        let habit = makeHabit(schedule: .weekdays([.monday]), createdAt: day(0))
        let snapshots = [snapshot(habitID: habit.id, schedule: .weekdays([.monday]), effectiveFrom: day(0), revision: 0)]

        // A range containing only non-scheduled days (Tue-Thu of week 1).
        let consistency = HabitProgressCalculator.consistency(
            for: habit, snapshots: snapshots, completions: [], skips: [], archivePeriods: [],
            in: DateInterval(start: day(1), end: day(4)), asOf: day(3), calendar: calendar
        )
        XCTAssertEqual(consistency.scheduledUnits, 0)
        XCTAssertEqual(consistency.percentage, 0)
    }

    /// Insights reviews a *completed* past week using the habit's full,
    /// present-day fact set (every completion and every configuration
    /// snapshot, not just what existed at the time) — `consistency(in:asOf:)`
    /// has no way to "forget" data recorded after the reviewed week. This
    /// confirms that doesn't matter: a later completion can't retroactively
    /// help a past week, and a later schedule edit can't retroactively change
    /// which schedule was in effect during it, because `in: range` filters
    /// units by the period's own `periodStart` and the per-day schedule
    /// resolution (`HabitScheduleEvaluator.activeConfiguration`) is always
    /// looked up for that day specifically, never the latest snapshot.
    func testConsistencyForACompletedWeekIsUnaffectedByLaterCompletionsOrConfigurationChanges() {
        let habit = makeHabit(schedule: .daily, createdAt: day(0))
        let week1Range = DateInterval(start: midnight(0), end: midnight(7))

        // Week 1 (days 0-6, daily): completed Mon/Tue/Wed, missed Thu-Sun.
        let week1Completions = [day(0), day(1), day(2)].map { completion(habit.id, on: $0) }
        let week1Snapshots = [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(0), revision: 0)]

        let isolatedWeek1 = HabitProgressCalculator.consistency(
            for: habit, snapshots: week1Snapshots, completions: week1Completions, skips: [], archivePeriods: [],
            in: week1Range, asOf: day(13), calendar: calendar
        )
        XCTAssertEqual(isolatedWeek1.successfulUnits, 3)
        XCTAssertEqual(isolatedWeek1.scheduledUnits, 7)

        // Add a schedule change well after week 1 (daily -> 2x/week from day
        // 10) and completions well after week 1 (days 20-21, as if logged
        // weeks later). Neither should be able to change what already
        // happened in week 1.
        let laterSnapshots = week1Snapshots + [
            snapshot(habitID: habit.id, schedule: .timesPerWeek(2), effectiveFrom: day(10), revision: 1)
        ]
        let laterCompletions = week1Completions + [day(20), day(21)].map { completion(habit.id, on: $0) }

        let week1WithLaterDataPresent = HabitProgressCalculator.consistency(
            for: habit, snapshots: laterSnapshots, completions: laterCompletions, skips: [], archivePeriods: [],
            in: week1Range, asOf: day(30), calendar: calendar
        )
        XCTAssertEqual(
            week1WithLaterDataPresent, isolatedWeek1,
            "a completed week's consistency must not change when later completions are recorded or the habit's schedule is later edited"
        )
    }

    // MARK: - Recovery with a perfect history

    func testRecoveryProgressHasNoMissWhenHistoryIsPerfect() {
        let habit = makeHabit(schedule: .daily, createdAt: day(0))
        let snapshots = [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(0), revision: 0)]
        let completions = (0...3).map { completion(habit.id, on: day($0)) }

        let recovery = HabitProgressCalculator.recoveryProgress(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: [], asOf: day(3), calendar: calendar
        )
        XCTAssertNil(recovery.lastMissedLocalDateKey)
        XCTAssertFalse(recovery.isRecovering)
        XCTAssertEqual(recovery.consecutiveSuccessesSinceMiss, 4)
    }

    // MARK: - Daylight saving

    func testDailyStreakAcrossDaylightSavingSpringForwardCountsCalendarDaysNotElapsedHours() {
        let saturday = Date(timeIntervalSince1970: 1_709_996_400) // 2024-03-09 10:00 EST
        let sunday = saturday.addingTimeInterval(23 * 60 * 60) // clocks spring forward during this day
        let monday = Date(timeIntervalSince1970: 1_710_165_600) // 2024-03-11 10:00 EDT
        let habit = makeHabit(schedule: .daily, createdAt: saturday)
        let snapshots = [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: saturday, revision: 0)]
        let completions = [saturday, sunday, monday].map { completion(habit.id, on: $0) }

        let streak = HabitProgressCalculator.streak(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: [], asOf: monday, calendar: calendar
        )
        XCTAssertEqual(streak.currentStreak, 3, "the 23-hour spring-forward day must still count as exactly one day")
        XCTAssertEqual(streak.bestStreak, 3)
    }

    // MARK: - Time zone injection

    func testInjectedCalendarDeterminesWhichDayIsCurrentAndPending() {
        // Only Monday is completed; Tuesday never gets a completion.
        let habit = makeHabit(schedule: .daily, createdAt: day(0))
        let snapshots = [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(0), revision: 0)]
        let completions = [day(0)].map { completion(habit.id, on: $0) }

        // 2024-06-18 23:30 America/New_York is already 2024-06-19 (Wednesday) in
        // Asia/Tokyo, so Tuesday is Tokyo's *past*, not its still-open "today."
        let instant = Date(timeIntervalSince1970: 1_718_767_800)
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        tokyo.locale = Locale(identifier: "en_US_POSIX")
        tokyo.firstWeekday = 1

        let newYorkStreak = HabitProgressCalculator.streak(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: [], asOf: instant, calendar: calendar
        )
        XCTAssertEqual(newYorkStreak.currentStreak, 1, "in New York it is still Tuesday, an unfinished day that doesn't erase Monday's streak")

        let tokyoStreak = HabitProgressCalculator.streak(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: [], asOf: instant, calendar: tokyo
        )
        XCTAssertEqual(tokyoStreak.currentStreak, 0, "in Tokyo Tuesday has already fully elapsed without a completion, so it is a genuine miss")
    }

    // MARK: - Archiving and pauses

    func testSinglePauseIsInvisibleToTheStreakAndArchiveDayIsPending() {
        let habit = makeHabit(schedule: .daily, createdAt: day(0))
        let snapshots = [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(0), revision: 0)]
        // Mon completed; archived Tue (no completion that day); reactivated Fri, also completed.
        let completions = [day(0), day(4)].map { completion(habit.id, on: $0) }
        let periods = [archivePeriod(habit.id, archivedAt: day(1), reactivatedAt: day(4))]

        let streak = HabitProgressCalculator.streak(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: periods, asOf: day(4), calendar: calendar
        )
        XCTAssertEqual(streak.currentStreak, 2, "the dormant Wed/Thu must not break the Mon-Fri streak")
        XCTAssertEqual(streak.bestStreak, 2)
    }

    func testArchiveDayItselfResolvesAsPendingNotAMissOnceReactivated() {
        // The archive day (Tue) is never completed. Once the pause ends and the
        // walk continues past it, Tue must still read as pending (unresolved at
        // the moment of archiving), never as a miss manufactured after the fact.
        let habit = makeHabit(schedule: .daily, createdAt: day(0))
        let snapshots = [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(0), revision: 0)]
        let completions = [day(0), day(4)].map { completion(habit.id, on: $0) }
        let periods = [archivePeriod(habit.id, archivedAt: day(1), reactivatedAt: day(4))]

        let recovery = HabitProgressCalculator.recoveryProgress(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: periods, asOf: day(4), calendar: calendar
        )
        XCTAssertNil(recovery.lastMissedLocalDateKey, "a pending archive day is not a miss")
        XCTAssertEqual(recovery.consecutiveSuccessesSinceMiss, 2)
    }

    func testRepeatedPauseCyclesAreEachInvisibleToTheStreak() {
        let habit = makeHabit(schedule: .daily, createdAt: day(0))
        let snapshots = [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(0), revision: 0)]
        // Mon missed; Tue/Thu/Mon(next week) completed, around two separate pauses.
        let completions = [day(1), day(3), day(7)].map { completion(habit.id, on: $0) }
        let periods = [
            archivePeriod(habit.id, archivedAt: day(1), reactivatedAt: day(3)), // archived Tue, back Thu
            archivePeriod(habit.id, archivedAt: day(4), reactivatedAt: day(7)), // archived Fri, back Mon
        ]

        let streak = HabitProgressCalculator.streak(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: periods, asOf: day(7), calendar: calendar
        )
        XCTAssertEqual(streak.currentStreak, 3, "Tue, Thu, and the following Mon combine across two separate pauses")
        XCTAssertEqual(streak.bestStreak, 3)

        let recovery = HabitProgressCalculator.recoveryProgress(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: periods, asOf: day(7), calendar: calendar
        )
        XCTAssertEqual(recovery.lastMissedLocalDateKey, key(day(0)), "Monday's miss predates both pauses and must still be visible")
        XCTAssertEqual(recovery.consecutiveSuccessesSinceMiss, 3)
    }

    func testArchiveAndReactivateWithinTheSameWeekSplitsTheFlexibleWeeklyPeriod() {
        let habit = makeHabit(schedule: .timesPerWeek(3), createdAt: day(-1)) // Sunday, week-aligned
        let snapshots = [snapshot(habitID: habit.id, schedule: .timesPerWeek(3), effectiveFrom: day(-1), revision: 0)]
        // Before the pause: only Monday completed (1 distinct day, short of 3).
        // Archived Tue, reactivated Thu (same natural week).
        // After reactivation: Thu/Fri/Sat completed (3 distinct days, meets target).
        let completions = [day(0), day(3), day(4), day(5)].map { completion(habit.id, on: $0) }
        let periods = [archivePeriod(habit.id, archivedAt: day(1), reactivatedAt: day(3))]

        let streak = HabitProgressCalculator.streak(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: periods, asOf: day(5), calendar: calendar
        )
        XCTAssertEqual(
            streak.currentStreak, 1,
            "the pre-pause partial week (1/3) must resolve as pending, not a miss, and must not merge with the post-pause period"
        )
        XCTAssertEqual(streak.bestStreak, 1)

        let recovery = HabitProgressCalculator.recoveryProgress(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: periods, asOf: day(5), calendar: calendar
        )
        XCTAssertFalse(recovery.isRecovering, "no miss ever occurred — only a pending period and a success")
    }

    func testRecoveryEndsAfterThreeConsecutiveSuccesses() {
        let habit = makeHabit(schedule: .daily, createdAt: day(0))
        let snapshots = [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(0), revision: 0)]
        // Mon missed; Tue, Wed, Thu completed.
        let completions = [day(1), day(2), day(3)].map { completion(habit.id, on: $0) }

        let afterTwo = HabitProgressCalculator.recoveryProgress(
            for: habit, snapshots: snapshots, completions: [completions[0], completions[1]], skips: [], archivePeriods: [],
            asOf: day(2), calendar: calendar
        )
        XCTAssertEqual(afterTwo.consecutiveSuccessesSinceMiss, 2)
        XCTAssertTrue(afterTwo.isRecovering, "still below the 3-success threshold")

        let afterThree = HabitProgressCalculator.recoveryProgress(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: [],
            asOf: day(3), calendar: calendar
        )
        XCTAssertEqual(afterThree.consecutiveSuccessesSinceMiss, 3)
        XCTAssertFalse(afterThree.isRecovering, "recovery ends at the 3rd consecutive success")
        XCTAssertNotNil(afterThree.lastMissedLocalDateKey, "the miss remains a historical fact even once recovery ends")
    }

    func testRecoveryCountsAcrossAScheduleKindChangeAndEndsAtThreshold() {
        let habit = makeHabit(schedule: .timesPerWeek(2), createdAt: day(0))
        let snapshots = [
            snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(0), revision: 0),
            snapshot(habitID: habit.id, schedule: .timesPerWeek(2), effectiveFrom: day(2), revision: 1), // Wed
        ]
        // Mon missed (daily). Tue completed (daily) — 1st success.
        // Wed/Thu completed under the new weekly schedule, meeting that week's
        // target of 2 — 2nd success (a week, not a day).
        // The following Mon/Tue also meet the next week's target of 2,
        // evaluated mid-week — 3rd success.
        let completions = [day(1), day(2), day(3), day(7), day(8)].map { completion(habit.id, on: $0) }

        let streak = HabitProgressCalculator.streak(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: [], asOf: day(8), calendar: calendar
        )
        XCTAssertEqual(streak.currentStreak, 3)
        XCTAssertEqual(streak.bestStreak, 3)

        let recovery = HabitProgressCalculator.recoveryProgress(
            for: habit, snapshots: snapshots, completions: completions, skips: [], archivePeriods: [], asOf: day(8), calendar: calendar
        )
        XCTAssertEqual(recovery.lastMissedLocalDateKey, key(day(0)))
        XCTAssertEqual(recovery.consecutiveSuccessesSinceMiss, 3)
        XCTAssertFalse(recovery.isRecovering, "3 commitments — a day, then two weeks — ends recovery regardless of unit kind")
    }
}
