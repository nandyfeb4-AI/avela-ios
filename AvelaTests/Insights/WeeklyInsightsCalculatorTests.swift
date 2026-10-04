import Foundation
import XCTest
@testable import Avela

final class WeeklyInsightsCalculatorTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 1
        return calendar
    }()

    /// Sunday 2024-06-16, 10:00 America/New_York — the first day of the
    /// calendar week containing Monday 2024-06-17 (the anchor every other
    /// test file in this project uses), since `firstWeekday = 1` (Sunday).
    private let anchor = Date(timeIntervalSince1970: 1_718_546_400)
    private func day(_ n: Int) -> Date { anchor.addingTimeInterval(Double(n) * 86_400) }
    private func midnight(_ n: Int) -> Date { calendar.startOfDay(for: day(n)) }
    private func key(_ date: Date) -> String { LocalDay.key(for: date, calendar: calendar) }

    /// Week 1: days 0-6. Week 2 (previous week, for trend tests): days -7...-1.
    private var week1: DateInterval { DateInterval(start: midnight(0), end: midnight(7)) }
    private var previousWeek: DateInterval { DateInterval(start: midnight(-7), end: midnight(0)) }
    /// Evaluated well after week 1 so its last day is always fully resolved
    /// (never the still-open "pending" boundary day).
    private var asOf: Date { day(13) }

    private func makeHabit(
        name: String = "Test", schedule: HabitSchedule, createdAt: Date, archivedAt: Date? = nil
    ) -> Habit {
        Habit(
            id: UUID(), name: name, iconName: "star", category: .other, polarity: .positive,
            schedule: schedule, createdAt: createdAt, updatedAt: createdAt, archivedAt: archivedAt, sortOrder: 0
        )
    }

    private func snapshot(
        habitID: UUID, schedule: HabitSchedule, effectiveFrom date: Date, revision: Int = 0, polarity: HabitPolarity = .positive
    ) -> HabitConfigurationSnapshot {
        HabitConfigurationSnapshot(
            id: UUID(), habitID: habitID, polarity: polarity, schedule: schedule,
            effectiveLocalDateKey: key(date), revision: revision, createdAt: date
        )
    }

    private func archivePeriod(_ habitID: UUID, archivedAt: Date, reactivatedAt: Date?) -> HabitArchivePeriod {
        HabitArchivePeriod(id: UUID(), habitID: habitID, archivedAt: archivedAt, reactivatedAt: reactivatedAt)
    }

    private func completion(_ habitID: UUID, on date: Date) -> Completion {
        Completion(id: UUID(), habitID: habitID, occurredAt: date, localDateKey: key(date), source: .app, note: nil)
    }

    private func skip(_ habitID: UUID, on date: Date, reason: SkipReason = .planned) -> Skip {
        Skip(id: UUID(), habitID: habitID, localDateKey: key(date), reason: reason, createdAt: date)
    }

    private func insights(
        habits: [Habit],
        snapshotsByHabitID: [UUID: [HabitConfigurationSnapshot]],
        completions: [Completion] = [],
        skips: [Skip] = [],
        archivePeriodsByHabitID: [UUID: [HabitArchivePeriod]] = [:],
        week: DateInterval? = nil,
        previousWeek: DateInterval? = nil
    ) -> WeeklyInsightsCalculator.WeeklyInsights {
        WeeklyInsightsCalculator.weeklyInsights(
            habits: habits,
            snapshotsByHabitID: snapshotsByHabitID,
            completions: completions,
            skips: skips,
            archivePeriodsByHabitID: archivePeriodsByHabitID,
            weekInterval: week ?? self.week1,
            previousWeekInterval: previousWeek ?? self.previousWeek,
            asOf: asOf,
            calendar: calendar
        )
    }

    // MARK: - Weekly aggregation and explicit denominators

    func testOverallConsistencyIsAverageOfHabitPercentagesNotPooledAcrossHabits() {
        let dailyHabit = makeHabit(name: "Daily", schedule: .daily, createdAt: day(0))
        let weeklyHabit = makeHabit(name: "Weekly", schedule: .timesPerWeek(3), createdAt: day(0))
        // Daily: every day of week 1 completed -> 7/7 = 100%.
        let completions = (0...6).map { completion(dailyHabit.id, on: day($0)) }
        // Weekly habit: target of 3, zero completions -> 0/1 = 0% once the week closes.

        let result = insights(
            habits: [dailyHabit, weeklyHabit],
            snapshotsByHabitID: [
                dailyHabit.id: [snapshot(habitID: dailyHabit.id, schedule: .daily, effectiveFrom: day(0))],
                weeklyHabit.id: [snapshot(habitID: weeklyHabit.id, schedule: .timesPerWeek(3), effectiveFrom: day(0))],
            ],
            completions: completions
        )

        XCTAssertEqual(result.eligibleHabits.count, 2)
        // Average of 100% and 0% is 50% — pooling (7 successes / 8 resolved
        // units) would instead give 87.5%.
        XCTAssertEqual(result.overallConsistency!, 0.5, accuracy: 0.0001)
    }

    // MARK: - Historical configuration and archive periods

    func testHabitCreatedAfterTheWeekBeganIsExcludedNotCountedAsZero() {
        // Created on day 3 of week 1: it has some scheduled days that week
        // (3-6), so it IS eligible for week 1, but has zero scheduled days in
        // the *previous* week, where it is excluded entirely.
        let habit = makeHabit(schedule: .daily, createdAt: day(3))
        let result = insights(
            habits: [habit],
            snapshotsByHabitID: [habit.id: [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(3))]],
            completions: [day(3), day(4)].map { completion(habit.id, on: $0) }
        )

        XCTAssertEqual(result.eligibleHabits.count, 1)
        XCTAssertEqual(result.eligibleHabits.first?.scheduledUnits, 4, "days 3-6 only")
        XCTAssertNil(
            result.trendInPercentagePoints,
            "the habit did not exist yet in the previous week; it cannot be part of the comparable cohort"
        )
    }

    func testHabitArchivedBeforeTheWeekBeganIsExcluded() {
        let habit = makeHabit(schedule: .daily, createdAt: day(-20), archivedAt: day(-10))
        let result = insights(
            habits: [habit],
            snapshotsByHabitID: [habit.id: [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(-20))]]
        )

        XCTAssertTrue(result.eligibleHabits.isEmpty, "a habit archived before the week began has no resolved units that week")
        XCTAssertNil(result.overallConsistency)
    }

    func testHistoricalScheduleChangeMidWeekIsReflectedInThatWeeksFigure() {
        // Daily for days 0-3, then switches to timesPerWeek(2) from day 4
        // onward, met by one completion on day 5.
        let habit = makeHabit(schedule: .daily, createdAt: day(0))
        let snapshots = [
            snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(0), revision: 0),
            snapshot(habitID: habit.id, schedule: .timesPerWeek(2), effectiveFrom: day(4), revision: 1),
        ]
        // Days 0-2 completed (3 successes), day 3 missed, then the new
        // timesPerWeek(2) partial period (days 4-6) is met by completions on
        // two of its three days.
        let completions = [day(0), day(1), day(2), day(5), day(6)].map { completion(habit.id, on: $0) }

        let result = insights(habits: [habit], snapshotsByHabitID: [habit.id: snapshots], completions: completions)

        let summary = try! XCTUnwrap(result.eligibleHabits.first)
        // 3 daily successes + 1 daily miss (day 3) + 1 timesPerWeek success = 4/5.
        XCTAssertEqual(summary.successfulUnits, 4)
        XCTAssertEqual(summary.scheduledUnits, 5)
    }

    // MARK: - Skips, duplicate completions, and insufficient data

    func testSkipsAreExcusedFromBothNumeratorAndDenominator() {
        let habit = makeHabit(schedule: .daily, createdAt: day(0))
        // Days 0-1 completed, day 2 skipped (excused), days 3-6 missed.
        let completions = [day(0), day(1)].map { completion(habit.id, on: $0) }
        let skips = [skip(habit.id, on: day(2))]

        let result = insights(
            habits: [habit],
            snapshotsByHabitID: [habit.id: [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(0))]],
            completions: completions, skips: skips
        )

        let summary = try! XCTUnwrap(result.eligibleHabits.first)
        XCTAssertEqual(summary.successfulUnits, 2)
        XCTAssertEqual(summary.scheduledUnits, 6, "the skipped day is removed from the denominator entirely, not counted as a miss")
    }

    func testDuplicateCompletionsOnTheSameDayDoNotInflateTheWeeklyFigure() {
        let habit = makeHabit(schedule: .daily, createdAt: day(0))
        // Three completions logged on the same day must still count as one success.
        let completions = [day(0), day(0).addingTimeInterval(3600), day(0).addingTimeInterval(7200)]
            .map { completion(habit.id, on: $0) }

        let result = insights(
            habits: [habit],
            snapshotsByHabitID: [habit.id: [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(0))]],
            completions: completions
        )

        let summary = try! XCTUnwrap(result.eligibleHabits.first)
        XCTAssertEqual(summary.successfulUnits, 1)
    }

    func testOverallConsistencyIsNilNotZeroWhenNoHabitIsEligible() {
        let habit = makeHabit(schedule: .daily, createdAt: day(30)) // created well after week 1
        let result = insights(
            habits: [habit],
            snapshotsByHabitID: [habit.id: [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(30))]]
        )

        XCTAssertTrue(result.eligibleHabits.isEmpty)
        XCTAssertNil(result.overallConsistency, "no eligible habits means no data to average, not a measured 0%")
        XCTAssertTrue(result.strongestHabitNames.isEmpty)
        XCTAssertTrue(result.habitsNeedingAttentionNames.isEmpty)
    }

    // MARK: - Ranking ties

    func testStrongestHabitNamesListsEveryHabitTiedAtTheMaximum() {
        let habitA = makeHabit(name: "Apple", schedule: .daily, createdAt: day(0))
        let habitB = makeHabit(name: "Banana", schedule: .daily, createdAt: day(0))
        let habitC = makeHabit(name: "Cherry", schedule: .daily, createdAt: day(0))
        // A and B both complete every day (100%); C completes none (0%).
        let completions = (0...6).flatMap { n in [habitA, habitB].map { completion($0.id, on: day(n)) } }

        let result = insights(
            habits: [habitA, habitB, habitC],
            snapshotsByHabitID: Dictionary(uniqueKeysWithValues: [habitA, habitB, habitC].map {
                ($0.id, [snapshot(habitID: $0.id, schedule: .daily, effectiveFrom: day(0))])
            }),
            completions: completions
        )

        XCTAssertEqual(result.strongestHabitNames, ["Apple", "Banana"], "both tied habits must be named, not an arbitrary one")
    }

    func testStrongestIsEmptyWhenTheMaximumPercentageIsZero() {
        let habit = makeHabit(schedule: .daily, createdAt: day(0))
        let result = insights(
            habits: [habit],
            snapshotsByHabitID: [habit.id: [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(0))]]
        ) // zero completions: every day missed

        XCTAssertTrue(result.strongestHabitNames.isEmpty, "there is no 'strongest' performer when nothing succeeded")
    }

    func testHabitsNeedingAttentionListsEveryHabitTiedAtTheLowestPercentageAmongThoseWithAMiss() {
        let habitA = makeHabit(name: "Apple", schedule: .daily, createdAt: day(0)) // 7/7, no miss
        let habitB = makeHabit(name: "Banana", schedule: .daily, createdAt: day(0)) // 0/7, all missed
        let habitC = makeHabit(name: "Cherry", schedule: .daily, createdAt: day(0)) // 0/7, all missed
        let completions = (0...6).map { completion(habitA.id, on: day($0)) }

        let result = insights(
            habits: [habitA, habitB, habitC],
            snapshotsByHabitID: Dictionary(uniqueKeysWithValues: [habitA, habitB, habitC].map {
                ($0.id, [snapshot(habitID: $0.id, schedule: .daily, effectiveFrom: day(0))])
            }),
            completions: completions
        )

        XCTAssertEqual(
            result.habitsNeedingAttentionNames, ["Banana", "Cherry"],
            "every habit tied at the lowest percentage among those with a miss must be named"
        )
    }

    func testHabitsNeedingAttentionIsEmptyWhenNoEligibleHabitHasAMiss() {
        let habit = makeHabit(schedule: .daily, createdAt: day(0))
        let completions = (0...6).map { completion(habit.id, on: day($0)) }
        let result = insights(
            habits: [habit],
            snapshotsByHabitID: [habit.id: [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(0))]],
            completions: completions
        )

        XCTAssertTrue(result.habitsNeedingAttentionNames.isEmpty, "a perfect week has nothing needing attention")
    }

    func testHabitsNeedingAttentionIsBasedOnPercentageNotRawMissCount() {
        // Daily habit: 6 misses out of 7 (lower raw miss count would wrongly
        // favor this habit if ranked by percentage alone is NOT used)...
        // Actually: Daily habit misses 1/7 (one miss, low rate); a
        // timesPerWeek(1) habit misses its only unit (1 miss, 100% miss rate).
        // By percentage, the timesPerWeek habit is clearly the one needing
        // attention (0%), even though its raw miss count (1) is lower than
        // a hypothetical worse daily habit's would be.
        let dailyHabit = makeHabit(name: "Daily", schedule: .daily, createdAt: day(0))
        let weeklyHabit = makeHabit(name: "Weekly", schedule: .timesPerWeek(1), createdAt: day(0))
        // Daily: 6/7 completed (one miss on day 6).
        let completions = (0...5).map { completion(dailyHabit.id, on: day($0)) }
        // Weekly: zero completions -> misses its single unit entirely.

        let result = insights(
            habits: [dailyHabit, weeklyHabit],
            snapshotsByHabitID: [
                dailyHabit.id: [snapshot(habitID: dailyHabit.id, schedule: .daily, effectiveFrom: day(0))],
                weeklyHabit.id: [snapshot(habitID: weeklyHabit.id, schedule: .timesPerWeek(1), effectiveFrom: day(0))],
            ],
            completions: completions
        )

        XCTAssertEqual(result.habitsNeedingAttentionNames, ["Weekly"], "ranked by percentage (0%), not by raw miss count (both have exactly 1 miss)")
    }

    // MARK: - Comparable prior-week trends

    func testTrendIsNilWhenThePreviousWeekHasNoEligibleHabit() {
        let habit = makeHabit(schedule: .daily, createdAt: day(0)) // did not exist in the previous week
        let completions = (0...6).map { completion(habit.id, on: day($0)) }
        let result = insights(
            habits: [habit],
            snapshotsByHabitID: [habit.id: [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(0))]],
            completions: completions
        )

        XCTAssertNotNil(result.overallConsistency)
        XCTAssertNil(result.trendInPercentagePoints, "comparing against a week with no eligible habit would be a fabricated trend")
    }

    func testTrendIsExpressedInPercentagePoints() {
        let habit = makeHabit(schedule: .daily, createdAt: day(-7))
        let snapshots = [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(-7))]
        // Previous week (days -7...-1): 3/7 completed.
        // Week 1 (days 0-6): 5/7 completed.
        let previousWeekCompletions = [day(-7), day(-6), day(-5)].map { completion(habit.id, on: $0) }
        let week1Completions = [day(0), day(1), day(2), day(3), day(4)].map { completion(habit.id, on: $0) }

        let result = insights(
            habits: [habit],
            snapshotsByHabitID: [habit.id: snapshots],
            completions: previousWeekCompletions + week1Completions
        )

        XCTAssertEqual(result.overallConsistency!, 5.0 / 7.0, accuracy: 0.0001)
        // (5/7 - 3/7) * 100 = ~28.57 percentage points.
        XCTAssertEqual(result.trendInPercentagePoints!, (5.0 / 7.0 - 3.0 / 7.0) * 100, accuracy: 0.0001)
    }

    // MARK: - Balanced weeks (identical results replace rankings)

    func testIsBalancedWeekWhenMultipleHabitsShareTheSameImperfectPercentage() {
        let habitA = makeHabit(name: "Walk", schedule: .daily, createdAt: day(0))
        let habitB = makeHabit(name: "Read", schedule: .daily, createdAt: day(0))
        // Both complete the same 5 of 7 days -> identical ~71.4% each, each
        // with real misses -- the case naive independent min/max selection
        // would otherwise name as both "strongest" and "needing attention."
        let completions = [0, 1, 2, 3, 4].flatMap { n in [habitA, habitB].map { completion($0.id, on: day(n)) } }

        let result = insights(
            habits: [habitA, habitB],
            snapshotsByHabitID: Dictionary(uniqueKeysWithValues: [habitA, habitB].map {
                ($0.id, [snapshot(habitID: $0.id, schedule: .daily, effectiveFrom: day(0))])
            }),
            completions: completions
        )

        XCTAssertTrue(result.isBalancedWeek, "identical results across every eligible habit must be flagged balanced")
        XCTAssertTrue(result.strongestHabitNames.isEmpty, "a balanced week must not single out a 'strongest' habit")
        XCTAssertTrue(
            result.habitsNeedingAttentionNames.isEmpty,
            "a balanced week must not single out a habit 'needing attention', even though both habits had misses"
        )
        // Preserve actual success/miss counts despite not ranking anyone.
        XCTAssertEqual(result.eligibleHabits.map(\.successfulUnits).sorted(), [5, 5])
        XCTAssertEqual(result.eligibleHabits.map(\.scheduledUnits).sorted(), [7, 7])
    }

    func testIsBalancedWeekForASingleEligibleHabitPreservingItsActualCounts() {
        let habit = makeHabit(schedule: .daily, createdAt: day(0))
        let completions = [0, 1, 2, 3, 4].map { completion(habit.id, on: day($0)) }

        let result = insights(
            habits: [habit],
            snapshotsByHabitID: [habit.id: [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(0))]],
            completions: completions
        )

        XCTAssertTrue(result.isBalancedWeek, "a single eligible habit is trivially 'balanced' -- there is nothing to rank it against")
        XCTAssertTrue(result.strongestHabitNames.isEmpty)
        XCTAssertTrue(result.habitsNeedingAttentionNames.isEmpty)
        XCTAssertEqual(result.eligibleHabits.first?.successfulUnits, 5, "the real count must remain available even though nothing is ranked")
        XCTAssertEqual(result.eligibleHabits.first?.scheduledUnits, 7)
    }

    // MARK: - Trend comparable-cohort rules

    func testTrendExcludesAHabitWhoseScheduleChangedDuringTheComparisonSpan() {
        let habit = makeHabit(schedule: .daily, createdAt: day(-30))
        let snapshots = [
            snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(-30)),
            snapshot(habitID: habit.id, schedule: .timesPerWeek(3), effectiveFrom: day(2), revision: 1),
        ]
        // Week 1: daily on days 0-1 (both completed), then timesPerWeek(3)
        // for days 2-6, met with 3 completions.
        let completions = [0, 1, 3, 4, 5].map { completion(habit.id, on: day($0)) }

        let result = insights(habits: [habit], snapshotsByHabitID: [habit.id: snapshots], completions: completions)

        XCTAssertNotNil(result.overallConsistency, "the current week's own summary must still be shown")
        XCTAssertNil(
            result.trendInPercentagePoints,
            "a schedule change inside the comparison span makes the two weeks measure different things"
        )
    }

    func testTrendExcludesAHabitThatWasPausedDuringPartOfTheComparisonSpan() {
        let habit = makeHabit(schedule: .daily, createdAt: day(-30))
        let snapshots = [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(-30))]
        // Paused for one day (day -4) in the middle of the previous week.
        let archivePeriods = [archivePeriod(habit.id, archivedAt: day(-5), reactivatedAt: day(-3))]
        let completions = [-7, -6, -5, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6].map { completion(habit.id, on: day($0)) }

        let result = insights(
            habits: [habit], snapshotsByHabitID: [habit.id: snapshots],
            completions: completions, archivePeriodsByHabitID: [habit.id: archivePeriods]
        )

        XCTAssertNotNil(result.overallConsistency)
        XCTAssertNil(
            result.trendInPercentagePoints,
            "a pause touching the comparison span breaks the 'continuously tracked' assumption a trend needs"
        )
    }

    func testTrendExcludesAHabitCreatedPartwayThroughThePreviousWeek() {
        // Created on day -4 (three days into the previous week): that week
        // only has 4 scheduled days, not a full 7, even though the schedule
        // itself never changed and the habit was never paused.
        let habit = makeHabit(schedule: .daily, createdAt: day(-4))
        let snapshots = [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(-4))]
        let completions = [-4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6].map { completion(habit.id, on: day($0)) }

        let result = insights(habits: [habit], snapshotsByHabitID: [habit.id: snapshots], completions: completions)

        XCTAssertEqual(result.eligibleHabits.first?.scheduledUnits, 7, "fully eligible for week 1")
        XCTAssertNotNil(result.overallConsistency)
        XCTAssertNil(
            result.trendInPercentagePoints,
            "a truncated previous week (created partway through it) isn't a fair comparison point even with an unchanged schedule"
        )
    }

    func testTrendAveragesOnlyTheComparableCohortWhileOverallConsistencyIncludesEveryEligibleHabit() {
        // "Stable" is unchanged and continuously tracked across both weeks:
        // 7/7 previous week, 3/7 this week -- a real, comparable drop.
        let stable = makeHabit(name: "Stable", schedule: .daily, createdAt: day(-30))
        let stableSnapshots = [snapshot(habitID: stable.id, schedule: .daily, effectiveFrom: day(-30))]
        let stablePrevious = [-7, -6, -5, -4, -3, -2, -1].map { completion(stable.id, on: day($0)) }
        let stableThisWeek = [0, 1, 2].map { completion(stable.id, on: day($0)) }

        // "NewHabit" only exists this week (100%) -- eligible this week, but
        // absent from the previous week entirely, so it cannot be part of
        // the comparable cohort.
        let newHabit = makeHabit(name: "NewHabit", schedule: .daily, createdAt: day(0))
        let newHabitSnapshots = [snapshot(habitID: newHabit.id, schedule: .daily, effectiveFrom: day(0))]
        let newHabitCompletions = (0...6).map { completion(newHabit.id, on: day($0)) }

        let result = insights(
            habits: [stable, newHabit],
            snapshotsByHabitID: [stable.id: stableSnapshots, newHabit.id: newHabitSnapshots],
            completions: stablePrevious + stableThisWeek + newHabitCompletions
        )

        // Overall consistency for the selected week reflects BOTH eligible
        // habits: (3/7 + 7/7) / 2.
        XCTAssertEqual(result.overallConsistency!, (3.0 / 7.0 + 1.0) / 2, accuracy: 0.0001)
        // The trend, however, only compares "Stable" against itself week
        // over week -- NewHabit has no comparable prior week at all.
        XCTAssertEqual(result.trendInPercentagePoints!, (3.0 / 7.0 - 1.0) * 100, accuracy: 0.0001)
    }

    func testTrendIsUnaffectedByAPolarityOnlyChangeDuringTheSpan() {
        let habit = makeHabit(schedule: .daily, createdAt: day(-30))
        // Same schedule throughout; only polarity flips mid-span.
        let snapshots = [
            snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(-30), polarity: .positive),
            snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(2), revision: 1, polarity: .avoidance),
        ]
        let previousWeekCompletions = [-7, -6, -5].map { completion(habit.id, on: day($0)) } // 3/7
        let week1Completions = [0, 1, 2, 3, 4].map { completion(habit.id, on: day($0)) } // 5/7

        let result = insights(
            habits: [habit], snapshotsByHabitID: [habit.id: snapshots],
            completions: previousWeekCompletions + week1Completions
        )

        XCTAssertEqual(
            result.trendInPercentagePoints!, (5.0 / 7.0 - 3.0 / 7.0) * 100, accuracy: 0.0001,
            "a polarity-only edit does not change what's being measured and must not disqualify the comparison"
        )
    }
    func testAttentionWeekUsesHistoricalBudgetsAndCountsOnlyLoggedDays() {
        let goal = AttentionGoal(id: UUID(), name: "News", appOrCategoryLabel: nil,
                                 type: .maxDurationPerDay, createdAt: day(0), updatedAt: day(0))
        let snapshots = [
            AttentionGoalConfigurationSnapshot(id: UUID(), attentionGoalID: goal.id,
                targetValue: 30, unit: .minutes, effectiveLocalDateKey: key(day(0)), revision: 0, createdAt: day(0)),
            AttentionGoalConfigurationSnapshot(id: UUID(), attentionGoalID: goal.id,
                targetValue: 60, unit: .minutes, effectiveLocalDateKey: key(day(2)), revision: 1, createdAt: day(2))
        ]
        let entries = [0, 2].map { index in
            AttentionUsageEntry(id: UUID(), attentionGoalID: goal.id, amount: 40, unit: .minutes,
                recordedAt: day(index), localDateKey: key(day(index)), source: .manual)
        }
        let result = SupplementalWeeklyInsightsCalculator.attentionWeek(
            goals: [goal], snapshotsByGoalID: [goal.id: snapshots], entries: entries,
            interval: week1, calendar: calendar
        )
        XCTAssertEqual(result.successfulGoalDays, 1)
        XCTAssertEqual(result.loggedGoalDays, 2)
        XCTAssertEqual(result.eligibleGoalDays, 7)
        XCTAssertEqual(result.successRate, 0.5)
    }

    func testAttentionWeekUnknownDaysNeverBecomeSuccessAndCreationLimitsCoverage() {
        let goal = AttentionGoal(id: UUID(), name: "News", appOrCategoryLabel: nil,
                                 type: .maxDurationPerDay, createdAt: day(4), updatedAt: day(4))
        let snapshot = AttentionGoalConfigurationSnapshot(id: UUID(), attentionGoalID: goal.id,
            targetValue: 30, unit: .minutes, effectiveLocalDateKey: key(day(4)), revision: 0, createdAt: day(4))
        let result = SupplementalWeeklyInsightsCalculator.attentionWeek(
            goals: [goal], snapshotsByGoalID: [goal.id: [snapshot]], entries: [],
            interval: week1, calendar: calendar
        )
        XCTAssertNil(result.successRate)
        XCTAssertEqual(result.loggedGoalDays, 0)
        XCTAssertEqual(result.eligibleGoalDays, 3)
    }

    func testAttentionWeekSumsEntriesBeforeClassifyingAndTreatsExactLimitAsExceeded() {
        let goal = AttentionGoal(id: UUID(), name: "News", appOrCategoryLabel: nil,
                                 type: .maxDurationPerDay, createdAt: day(0), updatedAt: day(0))
        let snapshot = AttentionGoalConfigurationSnapshot(id: UUID(), attentionGoalID: goal.id,
            targetValue: 30, unit: .minutes, effectiveLocalDateKey: key(day(0)), revision: 0, createdAt: day(0))
        let entries = [10.0, 20.0].map { amount in
            AttentionUsageEntry(id: UUID(), attentionGoalID: goal.id, amount: amount, unit: .minutes,
                recordedAt: day(0), localDateKey: key(day(0)), source: .manual)
        }
        let result = SupplementalWeeklyInsightsCalculator.attentionWeek(
            goals: [goal], snapshotsByGoalID: [goal.id: [snapshot]], entries: entries,
            interval: week1, calendar: calendar
        )
        XCTAssertEqual(result.loggedGoalDays, 1)
        XCTAssertEqual(result.successfulGoalDays, 0)
        XCTAssertEqual(result.successRate, 0)
    }

    func testWeekdayPatternRequiresEnoughResolvedDailyData() {
        let habit = makeHabit(schedule: .daily, createdAt: day(-14))
        let snapshots = [habit.id: [snapshot(habitID: habit.id, schedule: .daily, effectiveFrom: day(-14))]]
        XCTAssertNil(SupplementalWeeklyInsightsCalculator.weekdayPattern(
            habits: [habit], snapshotsByHabitID: snapshots,
            completions: [completion(habit.id, on: day(0))], skips: [], archivePeriodsByHabitID: [:],
            interval: week1, asOf: asOf, calendar: calendar
        ))
    }

    func testWeekdayPatternListsTiesAndExcludesFlexibleWeeklyHabits() {
        let a = makeHabit(name: "A", schedule: .daily, createdAt: day(-14))
        let b = makeHabit(name: "B", schedule: .daily, createdAt: day(-14))
        let weekly = makeHabit(name: "Weekly", schedule: .timesPerWeek(1), createdAt: day(-14))
        let snapshots = Dictionary(uniqueKeysWithValues: [a, b, weekly].map {
            ($0.id, [snapshot(habitID: $0.id, schedule: $0.schedule, effectiveFrom: day(-14))])
        })
        let completions = [a, b].flatMap { habit in [0, 1].map { completion(habit.id, on: day($0)) } }
        let pattern = SupplementalWeeklyInsightsCalculator.weekdayPattern(
            habits: [a, b, weekly], snapshotsByHabitID: snapshots,
            completions: completions, skips: [], archivePeriodsByHabitID: [:],
            interval: week1, asOf: asOf, calendar: calendar
        )
        XCTAssertEqual(pattern?.strongestWeekdays, [1, 2])
        XCTAssertEqual(pattern?.weakestWeekdays, [3, 4, 5, 6, 7])
    }

    func testWeekdayPatternOmitsRankingForBalancedResults() {
        let habits = [makeHabit(name: "A", schedule: .daily, createdAt: day(-14)),
                      makeHabit(name: "B", schedule: .daily, createdAt: day(-14))]
        let snapshots = Dictionary(uniqueKeysWithValues: habits.map {
            ($0.id, [snapshot(habitID: $0.id, schedule: $0.schedule, effectiveFrom: day(-14))])
        })
        XCTAssertNil(SupplementalWeeklyInsightsCalculator.weekdayPattern(
            habits: habits, snapshotsByHabitID: snapshots, completions: [], skips: [], archivePeriodsByHabitID: [:],
            interval: week1, asOf: asOf, calendar: calendar
        ))
    }

}
