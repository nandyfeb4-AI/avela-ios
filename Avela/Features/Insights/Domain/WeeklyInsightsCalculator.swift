import Foundation

/// Pure, SwiftUI/SwiftData-independent weekly aggregation across every habit,
/// for the Insights screen. Reuses `HabitProgressCalculator.consistency` for
/// each habit's own per-week numbers — this adds no new per-day/per-habit
/// scheduling math, only aggregation, ranking, and week-over-week comparison
/// on top of it.
///
/// ## Confirmed product rules (presented as recommendations, explicitly
/// confirmed by the product owner — not inferred or defaulted; mirrors how
/// Phase 1's progress metrics were confirmed, see DATA_MODEL.md's "Phase 1
/// progress metrics")
///
/// - **Overall weekly consistency is the average of each eligible habit's own
///   consistency percentage**, not a pooled successful/resolved count across
///   all habits. Every eligible habit counts equally regardless of how many
///   commitments its schedule generates in a week (a daily habit can resolve
///   up to 7 units; a `timesPerWeek` habit resolves exactly 1) — pooling would
///   let higher-frequency habits dominate the number silently.
/// - **A habit is "eligible" for a given week** — counted in that week's
///   overall average, and eligible to be named strongest or needing
///   attention — only if it has at least one *resolved* unit (success or
///   miss) that week, i.e.
///   `HabitProgressCalculator.ConsistencyResult.scheduledUnits > 0`. A habit
///   created after the week ended, or archived before it began, has
///   `scheduledUnits == 0` and is excluded entirely — never counted as a
///   measured 0%, which would misrepresent "no data" as "measured and
///   failing."
/// - **The selected week's overall summary always reflects every eligible
///   habit for that week**, independent of the trend/comparison logic below.
///   Narrowing "Overall Consistency" itself to only the habits comparable to
///   last week would hide real habits from the one number meant to represent
///   the whole week.
/// - **When every eligible habit has the exact same percentage this week —
///   including the common case of exactly one eligible habit — ranking
///   callouts are replaced by a neutral summary** (`isBalancedWeek`). Naming
///   a single habit, or a group of identically-performing habits, as both
///   "strongest" and "needing attention" in the same breath (which naive
///   independent min/max selection would do) is self-contradictory, not
///   informative. The underlying per-habit `successfulUnits`/`scheduledUnits`
///   remain available on `eligibleHabits` regardless, so a caller can still
///   build a neutral sentence ("all N habits matched pace this week") from
///   real counts.
/// - **"Habit needing attention" is based on misses in the selected week
///   only**, never on today's (or any other week's) recovery state — a
///   historical week's review must not describe itself using information
///   from outside that week. Among eligible habits with at least one miss
///   that week (when the week isn't balanced), the one(s) with the *lowest*
///   consistency percentage are named — symmetric with how "strongest" is
///   chosen, both being the extremes of the same per-habit percentage
///   distribution — rather than raw miss count, which would unfairly favor
///   flagging daily/weekdays habits just because they generate more
///   opportunities to miss than a `timesPerWeek` habit does in the same week.
/// - **"Strongest habit" requires a positive percentage.** Among eligible
///   habits (when the week isn't balanced), the one(s) with the highest
///   percentage are named, but only if that percentage is greater than 0%.
/// - **Ties are never broken arbitrarily.** If multiple habits share the
///   exact maximum (strongest) or exact minimum-among-misses (needing
///   attention) percentage without *every* eligible habit matching, every
///   tied habit is named — sorted by name for a stable, non-arbitrary order.
///
/// ## Week-over-week trend: comparable-cohort rules
///
/// The trend compares a week-over-week *change*, which is only meaningful if
/// both numbers measure the same thing. A habit is included in the
/// comparison cohort — used **only** for the trend, never for the selected
/// week's own "Overall Consistency" — if **all** of the following hold:
///
/// 1. It is eligible (`scheduledUnits > 0`) in *both* the selected week and
///    the preceding completed week independently.
/// 2. Its `HabitSchedule` did not change at any point from the start of the
///    preceding week through the end of the selected week. A snapshot
///    appended for a polarity-only edit (schedule unchanged) does not count
///    as a change — polarity doesn't affect what's being measured, per
///    `Habit.swift`'s documented "polarity only changes how UI should phrase
///    progress."
/// 3. It was not archived/reactivated at any point during that same
///    two-week span — it was continuously active on both sides, not paused
///    for part of either week.
/// 4. As a defensive check on 2–3 (and to catch a habit created or archived
///    partway through either week, which wouldn't otherwise be caught by a
///    pure schedule/archive-period check): its `scheduledUnits` for *each*
///    week individually equals the full expected count for a schedule of its
///    kind — 7 for `daily`, `weekdays(set).count` for `weekdays`, 1 for
///    `timesPerWeek`. A truncated week (even with the same schedule, same
///    archive state) measures a different, smaller opportunity than a full
///    week and isn't a fair comparison point.
///
/// If the comparable cohort is empty, the trend is `nil` ("not enough
/// comparable data to compare") rather than comparing unrelated habits or
/// incompatible tracking periods against each other.
enum WeeklyInsightsCalculator {
    struct HabitWeekSummary: Equatable, Sendable {
        let habitID: UUID
        let habitName: String
        let isArchived: Bool
        let successfulUnits: Int
        let scheduledUnits: Int

        var missedUnits: Int { scheduledUnits - successfulUnits }

        /// `0` when `scheduledUnits == 0`, matching
        /// `HabitProgressCalculator.ConsistencyResult.percentage`. Every
        /// summary here already has `scheduledUnits > 0` by construction
        /// (see "eligible" above), so this is always meaningful.
        var percentage: Double {
            scheduledUnits == 0 ? 0 : Double(successfulUnits) / Double(scheduledUnits)
        }
    }

    struct WeeklyInsights: Equatable, Sendable {
        let weekInterval: DateInterval

        /// Only habits with `scheduledUnits > 0` for this specific week — see
        /// "eligible" above. A habit absent from this list had no resolved
        /// activity this week; that is different from a measured 0%.
        let eligibleHabits: [HabitWeekSummary]

        /// Average of `eligibleHabits.map(\.percentage)`. `nil` when
        /// `eligibleHabits` is empty — there is nothing to average, which is
        /// different from "averaged to zero." Always reflects every eligible
        /// habit this week, regardless of the trend's comparable cohort.
        let overallConsistency: Double?

        /// `true` when every eligible habit shares the exact same
        /// percentage this week, including the single-habit case. When
        /// `true`, `strongestHabitNames` and `habitsNeedingAttentionNames`
        /// are both empty by construction — callers should show a neutral
        /// summary instead, using `eligibleHabits`' own counts.
        let isBalancedWeek: Bool

        /// Every habit tied at the maximum percentage among `eligibleHabits`,
        /// only when that maximum is greater than 0 and the week is not
        /// balanced. Sorted by name for a stable, non-arbitrary order.
        let strongestHabitNames: [String]

        /// Every habit tied at the minimum percentage among the
        /// `eligibleHabits` that have at least one miss this week, only when
        /// the week is not balanced. Sorted by name.
        let habitsNeedingAttentionNames: [String]

        /// `(thisWeek's comparable-cohort average - previous week's
        /// comparable-cohort average) * 100`, in percentage points. `nil`
        /// when the comparable cohort (see type-level docs) is empty —
        /// "not enough comparable data" — regardless of whether either
        /// week's *overall* consistency is itself available.
        let trendInPercentagePoints: Double?
    }

    /// Aggregates `weekInterval` (and, for the trend, `previousWeekInterval`)
    /// across every habit in `habits`. Each habit's own per-week numbers come
    /// from `HabitProgressCalculator.consistency`, called once per habit per
    /// week with that habit's own configuration history, completions, skips,
    /// and archive periods — this function adds no new per-day scheduling
    /// logic, only aggregation across habits.
    ///
    /// `completions`/`skips` may be scoped to any range that fully covers
    /// both `previousWeekInterval` and `weekInterval` (the caller is not
    /// required to pass a habit's entire lifetime): `HabitProgressCalculator`
    /// only resolves outcomes for days whose `periodStart` falls inside the
    /// requested range, so data outside the two weeks being reviewed is
    /// neither required nor consulted — see
    /// `HabitProgressCalculatorTests.testConsistencyForACompletedWeekIsUnaffectedByLaterCompletionsOrConfigurationChanges`.
    /// `snapshotsByHabitID`/`archivePeriodsByHabitID` are expected to cover
    /// each habit's *entire* history (not just the two weeks under review),
    /// since the comparable-cohort check needs to see whether a schedule
    /// change or archive period touched the comparison span at all.
    static func weeklyInsights(
        habits: [Habit],
        snapshotsByHabitID: [UUID: [HabitConfigurationSnapshot]],
        completions: [Completion],
        skips: [Skip],
        archivePeriodsByHabitID: [UUID: [HabitArchivePeriod]],
        weekInterval: DateInterval,
        previousWeekInterval: DateInterval,
        asOf date: Date,
        calendar: Calendar
    ) -> WeeklyInsights {
        func summaries(in range: DateInterval) -> [HabitWeekSummary] {
            habits.compactMap { habit -> HabitWeekSummary? in
                let result = HabitProgressCalculator.consistency(
                    for: habit,
                    snapshots: snapshotsByHabitID[habit.id] ?? [],
                    completions: completions.filter { $0.habitID == habit.id },
                    skips: skips.filter { $0.habitID == habit.id },
                    archivePeriods: archivePeriodsByHabitID[habit.id] ?? [],
                    in: range, asOf: date, calendar: calendar
                )
                guard result.scheduledUnits > 0 else { return nil }
                return HabitWeekSummary(
                    habitID: habit.id,
                    habitName: habit.name,
                    isArchived: habit.isArchived,
                    successfulUnits: result.successfulUnits,
                    scheduledUnits: result.scheduledUnits
                )
            }
        }

        let eligibleHabits = summaries(in: weekInterval)
        let previousEligibleHabits = summaries(in: previousWeekInterval)

        let percentages = Set(eligibleHabits.map(\.percentage))
        let isBalancedWeek = eligibleHabits.count == 1 || (eligibleHabits.count > 1 && percentages.count == 1)

        let strongestHabitNames: [String]
        let habitsNeedingAttentionNames: [String]
        if isBalancedWeek {
            strongestHabitNames = []
            habitsNeedingAttentionNames = []
        } else {
            let maxPercentage = eligibleHabits.map(\.percentage).max() ?? 0
            strongestHabitNames = maxPercentage > 0
                ? eligibleHabits.filter { $0.percentage == maxPercentage }.map(\.habitName).sorted()
                : []

            let habitsWithMisses = eligibleHabits.filter { $0.missedUnits > 0 }
            let minPercentageAmongMisses = habitsWithMisses.map(\.percentage).min()
            habitsNeedingAttentionNames = minPercentageAmongMisses.map { minPercentage in
                habitsWithMisses.filter { $0.percentage == minPercentage }.map(\.habitName).sorted()
            } ?? []
        }

        let trend = trendInPercentagePoints(
            habits: habits,
            eligibleHabits: eligibleHabits,
            previousEligibleHabits: previousEligibleHabits,
            snapshotsByHabitID: snapshotsByHabitID,
            archivePeriodsByHabitID: archivePeriodsByHabitID,
            weekInterval: weekInterval,
            previousWeekInterval: previousWeekInterval,
            calendar: calendar
        )

        return WeeklyInsights(
            weekInterval: weekInterval,
            eligibleHabits: eligibleHabits,
            overallConsistency: average(of: eligibleHabits),
            isBalancedWeek: isBalancedWeek,
            strongestHabitNames: strongestHabitNames,
            habitsNeedingAttentionNames: habitsNeedingAttentionNames,
            trendInPercentagePoints: trend
        )
    }

    private static func average(of summaries: [HabitWeekSummary]) -> Double? {
        guard !summaries.isEmpty else { return nil }
        return summaries.map(\.percentage).reduce(0, +) / Double(summaries.count)
    }

    /// Expected `scheduledUnits` for a full, uninterrupted calendar week under
    /// `schedule` — see rule 4 of the comparable-cohort docs above.
    private static func expectedFullWeekUnitCount(for schedule: HabitSchedule) -> Int {
        switch schedule {
        case .daily: return 7
        case .weekdays(let days): return days.count
        case .timesPerWeek: return 1
        }
    }

    private static func trendInPercentagePoints(
        habits: [Habit],
        eligibleHabits: [HabitWeekSummary],
        previousEligibleHabits: [HabitWeekSummary],
        snapshotsByHabitID: [UUID: [HabitConfigurationSnapshot]],
        archivePeriodsByHabitID: [UUID: [HabitArchivePeriod]],
        weekInterval: DateInterval,
        previousWeekInterval: DateInterval,
        calendar: Calendar
    ) -> Double? {
        let eligibleByID = Dictionary(uniqueKeysWithValues: eligibleHabits.map { ($0.habitID, $0) })
        let previousEligibleByID = Dictionary(uniqueKeysWithValues: previousEligibleHabits.map { ($0.habitID, $0) })
        let comparisonSpan = DateInterval(start: previousWeekInterval.start, end: weekInterval.end)
        let spanStartKey = LocalDay.key(for: comparisonSpan.start, calendar: calendar)
        let spanLastIncludedKey = LocalDay.key(for: comparisonSpan.end.addingTimeInterval(-1), calendar: calendar)

        let comparablePairs: [(current: HabitWeekSummary, previous: HabitWeekSummary)] = habits.compactMap { habit in
            guard let current = eligibleByID[habit.id], let previous = previousEligibleByID[habit.id] else { return nil }

            let snapshots = snapshotsByHabitID[habit.id] ?? []
            guard let scheduleAtSpanStart = HabitScheduleEvaluator.activeConfiguration(from: snapshots, onKey: spanStartKey)?.schedule
            else { return nil }

            let scheduleChangedDuringSpan = snapshots.contains { snapshot in
                snapshot.effectiveLocalDateKey > spanStartKey
                    && snapshot.effectiveLocalDateKey <= spanLastIncludedKey
                    && snapshot.schedule != scheduleAtSpanStart
            }
            guard !scheduleChangedDuringSpan else { return nil }

            let archivePeriods = archivePeriodsByHabitID[habit.id] ?? []
            let wasPausedDuringSpan = archivePeriods.contains { period in
                let periodEnd = period.reactivatedAt ?? .distantFuture
                return period.archivedAt < comparisonSpan.end && periodEnd > comparisonSpan.start
            }
            guard !wasPausedDuringSpan else { return nil }

            let expectedCount = expectedFullWeekUnitCount(for: scheduleAtSpanStart)
            guard current.scheduledUnits == expectedCount, previous.scheduledUnits == expectedCount else { return nil }

            return (current, previous)
        }

        guard !comparablePairs.isEmpty else { return nil }
        let currentAverage = comparablePairs.map(\.current.percentage).reduce(0, +) / Double(comparablePairs.count)
        let previousAverage = comparablePairs.map(\.previous.percentage).reduce(0, +) / Double(comparablePairs.count)
        return (currentAverage - previousAverage) * 100
    }
}

/// Supplemental weekly summaries keep manually reported attention separate
/// from habit consistency. Missing reports never become successful zero days.
enum SupplementalWeeklyInsightsCalculator {
    struct AttentionWeek: Equatable {
        let successfulGoalDays: Int
        let loggedGoalDays: Int
        let eligibleGoalDays: Int
        var successRate: Double? {
            loggedGoalDays == 0 ? nil : Double(successfulGoalDays) / Double(loggedGoalDays)
        }
    }

    struct WeekdayPattern: Equatable {
        let strongestWeekdays: [Int]
        let weakestWeekdays: [Int]
    }

    static func attentionWeek(
        goals: [AttentionGoal], snapshotsByGoalID: [UUID: [AttentionGoalConfigurationSnapshot]],
        entries: [AttentionUsageEntry], interval: DateInterval, calendar: Calendar
    ) -> AttentionWeek {
        var successes = 0
        var logged = 0
        var eligible = 0
        var date = calendar.startOfDay(for: interval.start)
        while date < interval.end {
            let key = LocalDay.key(for: date, calendar: calendar)
            for goal in goals where goal.type == .maxDurationPerDay {
                let snapshots = snapshotsByGoalID[goal.id] ?? []
                // The evaluator's fallback before creation is useful elsewhere,
                // but a goal cannot contribute coverage before it existed.
                guard snapshots.contains(where: { $0.effectiveLocalDateKey <= key }),
                      let snapshot = AttentionGoalEvaluator.activeConfiguration(from: snapshots, onKey: key)
                else { continue }
                eligible += 1
                let dailyEntries = entries.filter { $0.attentionGoalID == goal.id && $0.localDateKey == key }
                guard !dailyEntries.isEmpty else { continue }
                logged += 1
                let progress = AttentionProgressCalculator.DailyProgress(
                    entries: dailyEntries, target: snapshot.targetValue, unit: snapshot.unit
                )
                if progress.state == .healthy || progress.state == .nearLimit { successes += 1 }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date), next > date else { break }
            date = next
        }
        return AttentionWeek(successfulGoalDays: successes, loggedGoalDays: logged, eligibleGoalDays: eligible)
    }

    /// Compare only daily/weekday commitments. A flexible weekly commitment
    /// cannot honestly be attributed to any one weekday. Two resolved
    /// commitments per compared weekday and at least two weekdays are required.
    static func weekdayPattern(
        habits: [Habit], snapshotsByHabitID: [UUID: [HabitConfigurationSnapshot]],
        completions: [Completion], skips: [Skip], archivePeriodsByHabitID: [UUID: [HabitArchivePeriod]],
        interval: DateInterval, asOf: Date, calendar: Calendar
    ) -> WeekdayPattern? {
        var successes: [Int: Int] = [:]
        var resolved: [Int: Int] = [:]
        var date = calendar.startOfDay(for: interval.start)
        while date < interval.end {
            guard let next = calendar.date(byAdding: .day, value: 1, to: date), next > date else { break }
            let weekday = calendar.component(.weekday, from: date)
            for habit in habits {
                let snapshots = snapshotsByHabitID[habit.id] ?? []
                guard let schedule = HabitScheduleEvaluator.activeConfiguration(from: snapshots, on: date, calendar: calendar)?.schedule else { continue }
                if case .timesPerWeek = schedule { continue }
                let progress = HabitProgressCalculator.consistency(
                    for: habit, snapshots: snapshots, completions: completions, skips: skips,
                    archivePeriods: archivePeriodsByHabitID[habit.id] ?? [],
                    in: DateInterval(start: date, end: next), asOf: asOf, calendar: calendar
                )
                successes[weekday, default: 0] += progress.successfulUnits
                resolved[weekday, default: 0] += progress.scheduledUnits
            }
            date = next
        }
        let eligible = resolved.filter { $0.value >= 2 }
        guard eligible.count >= 2 else { return nil }
        let percentages = Dictionary(uniqueKeysWithValues: eligible.map {
            ($0.key, Double(successes[$0.key, default: 0]) / Double($0.value))
        })
        guard let best = percentages.values.max(), let lowest = percentages.values.min(), best != lowest else { return nil }
        return WeekdayPattern(
            strongestWeekdays: percentages.filter { $0.value == best }.map(\.key).sorted(),
            weakestWeekdays: percentages.filter { $0.value == lowest }.map(\.key).sorted()
        )
    }
}
