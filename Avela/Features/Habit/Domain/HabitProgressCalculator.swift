import Foundation

/// Deterministic, SwiftUI-independent streak/consistency/recovery math for a
/// single habit. Pure Foundation: no SwiftData, no persistence, no caching —
/// every result is recomputed from the habit's full fact set (its configuration
/// history, completions, and skips) each time, per ARCHITECTURE.md's preference
/// for derived metrics over redundant stored aggregates.
///
/// ## Rules this calculator encodes (not fully pinned down by docs/MVP.md or
/// docs/UX.md; concrete choices made here, documented in DATA_MODEL.md)
///
/// - A **skip** excuses a day: it does not break a streak and does not count
///   against consistency (it is removed from both the numerator and the
///   denominator), but it also does not advance a streak by itself. This
///   matches MVP.md's "Skip is distinct from failure."
/// - The **current, still-open period** (today's day, or the in-progress week
///   for a flexible-weekly habit) is never treated as a miss, because it has
///   not finished yet. If it has already succeeded (completed today, or this
///   week's target already met), it counts as a success immediately — further
///   time passing cannot undo that. Otherwise it is excluded entirely
///   ("pending") until the period ends.
/// - **Archiving** freezes evaluation at the local day the habit was archived.
///   The same "never penalize an unfinished period" rule applies there: the
///   period touching the archive date is pending, not a miss, so archiving a
///   habit never retroactively manufactures a miss for time after the user
///   stopped tracking it.
/// - **Duplicate completions on the same local day never inflate a count.**
///   A day's success is "at least one completion that day," not a tally,
///   and a flexible-weekly target is met by *distinct days* with a completion,
///   not raw completion count — logging twice in one sitting cannot satisfy a
///   3x/week target by itself. Completion records themselves are never
///   deleted or merged; only this derived calculation treats same-day
///   duplicates as one.
/// - **Historical configuration** governs each day/week: what schedule was
///   due on a given local day is resolved from the snapshot effective on that
///   day (`HabitScheduleEvaluator.activeConfiguration`), not the habit's
///   current schedule. If a habit's schedule kind changes (e.g. daily to
///   `timesPerWeek`) in the middle of a calendar week, the old kind's unit
///   closes on the day of the change and the new kind starts a fresh partial
///   period from that point — periods are never double-counted or skipped
///   across a transition.
/// - **Archived (dormant) windows are invisible to every calculation**, the
///   same way skipped days are. A closed `HabitArchivePeriod` excludes every
///   day strictly between the archive day and the reactivation day from the
///   walk entirely: no units are emitted for them, so they cannot generate a
///   miss, cannot extend a streak, and cannot reset one. The day a habit was
///   archived is still evaluated normally (pending if unresolved, matching the
///   "never penalize an unfinished period" rule above, generalized to every
///   pause, not just the current one); the day it was reactivated is live
///   again immediately. A `timesPerWeek` period interrupted by archiving
///   closes the same way a schedule-kind change closes one: pending if the
///   target wasn't met yet, success if it was already met, never a manufactured
///   miss. Reactivation starts a fresh partial period rather than resuming the
///   interrupted one, so a single natural calendar week can produce more than
///   one unit if a pause falls inside it — the same way a schedule edit mid-week
///   already can.
/// - **Recovery ends after 3 consecutive successes following a miss**
///   (`RecoveryProgress.isRecovering` becomes `false` once
///   `consecutiveSuccessesSinceMiss >= 3`). The streak itself keeps counting
///   normally past that point; only the "recovering" framing stops. The 3
///   counted periods are whatever unit is active at each point — days or
///   weeks — so a schedule-kind change or an archive/reactivate cycle during
///   recovery does not reset or restart the count, consistent with pauses and
///   transitions being invisible to the underlying scan.
enum HabitProgressCalculator {
    /// After this many consecutive successes following a miss, recovery is
    /// considered complete; see `RecoveryProgress.isRecovering`. Not private:
    /// UI copy that names the threshold (Today's and the detail screen's
    /// recovery wording) reads it directly, so the number can't drift from
    /// the rule it describes.
    static let recoveryCompletionThreshold = 3
    enum StreakUnit: Equatable, Sendable {
        case days
        case weeks
    }

    struct StreakResult: Equatable, Sendable {
        let currentStreak: Int
        let bestStreak: Int
        /// What a "streak" of 1 currently means for this habit: a day for
        /// `daily`/`weekdays` schedules, a week for `timesPerWeek`. Derived from
        /// whichever schedule is active as of the evaluation date (or the
        /// archive date, if archived), independent of what the streak count
        /// itself spans historically.
        let unit: StreakUnit
    }

    struct ConsistencyResult: Equatable, Sendable {
        let successfulUnits: Int
        let scheduledUnits: Int

        /// `0` when there is nothing to measure (`scheduledUnits == 0`) rather
        /// than `NaN`, so callers can display it without a special case.
        var percentage: Double {
            scheduledUnits == 0 ? 0 : Double(successfulUnits) / Double(scheduledUnits)
        }
    }

    struct RecoveryProgress: Equatable, Sendable {
        /// The local day (for day-based schedules) or the local day the
        /// relevant week started (for `timesPerWeek`) of the most recent miss,
        /// or `nil` if no miss exists anywhere in the habit's history.
        let lastMissedLocalDateKey: String?
        /// Consecutive successful periods since that miss, through the
        /// evaluation date. Equal to `currentStreak` when a miss exists, by
        /// construction (a streak is exactly "successes since the last miss").
        /// When there is no miss, this equals the full current streak too —
        /// there is nothing to "recover" from, so UI should prefer plain
        /// streak framing over recovery framing in that case
        /// (`isRecovering == false`).
        let consecutiveSuccessesSinceMiss: Int

        /// `true` from the miss until `consecutiveSuccessesSinceMiss` reaches
        /// `recoveryCompletionThreshold` (3). Past that point the habit is
        /// simply "on a streak" again rather than "recovering," even though
        /// `lastMissedLocalDateKey` — a historical fact — never changes back.
        var isRecovering: Bool {
            lastMissedLocalDateKey != nil && consecutiveSuccessesSinceMiss < recoveryCompletionThreshold
        }
    }

    // MARK: - Public API

    static func streak(
        for habit: Habit,
        snapshots: [HabitConfigurationSnapshot],
        completions: [Completion],
        skips: [Skip],
        archivePeriods: [HabitArchivePeriod],
        asOf date: Date,
        calendar: Calendar
    ) -> StreakResult {
        let units = buildUnitSequence(
            habit: habit, snapshots: snapshots, completions: completions, skips: skips,
            archivePeriods: archivePeriods, asOf: date, calendar: calendar
        )
        let scanned = scan(units)
        let unit = currentStreakUnit(habit: habit, snapshots: snapshots, asOf: date, calendar: calendar)
        return StreakResult(currentStreak: scanned.current, bestStreak: scanned.best, unit: unit)
    }

    static func recoveryProgress(
        for habit: Habit,
        snapshots: [HabitConfigurationSnapshot],
        completions: [Completion],
        skips: [Skip],
        archivePeriods: [HabitArchivePeriod],
        asOf date: Date,
        calendar: Calendar
    ) -> RecoveryProgress {
        let units = buildUnitSequence(
            habit: habit, snapshots: snapshots, completions: completions, skips: skips,
            archivePeriods: archivePeriods, asOf: date, calendar: calendar
        )
        let scanned = scan(units)
        return RecoveryProgress(
            lastMissedLocalDateKey: scanned.lastMissKey,
            consecutiveSuccessesSinceMiss: scanned.current
        )
    }

    /// Consistency over `range`. A unit counts toward this range if its period
    /// *starts* within `[range.start, range.end)`; `range` may extend past
    /// `asOf date` with no effect (there is simply nothing to count there yet).
    ///
    /// Deliberately half-open, computed directly rather than via
    /// `DateInterval.contains(_:)`: `DateInterval` is a *closed* interval
    /// (`start...end`, inclusive of both ends), so a caller-supplied range like
    /// `DateInterval(start: weekStart, end: weekStart + 7.days)` — the natural
    /// way to express "this week" — would otherwise also match a unit whose
    /// period starts exactly at `weekStart + 7.days`, i.e. the *next* period.
    static func consistency(
        for habit: Habit,
        snapshots: [HabitConfigurationSnapshot],
        completions: [Completion],
        skips: [Skip],
        archivePeriods: [HabitArchivePeriod],
        in range: DateInterval,
        asOf date: Date,
        calendar: Calendar
    ) -> ConsistencyResult {
        let units = buildUnitSequence(
            habit: habit, snapshots: snapshots, completions: completions, skips: skips,
            archivePeriods: archivePeriods, asOf: date, calendar: calendar
        )
        let inRange = units.filter { $0.periodStart >= range.start && $0.periodStart < range.end }
        let successes = inRange.filter { $0.outcome == .success }.count
        let misses = inRange.filter { $0.outcome == .miss }.count
        return ConsistencyResult(successfulUnits: successes, scheduledUnits: successes + misses)
    }

    // MARK: - Shared unit sequence

    enum Outcome: Equatable, Sendable {
        case success
        case skip
        case miss
        /// An unfinished period touching evaluation or an archive boundary.
        /// Excluded from streak, consistency and recovery scans.
        case pending
    }

    struct ProgressPeriod: Equatable, Sendable {
        let outcome: Outcome
        let periodStart: Date
        let localDateKey: String
        /// Half-open evaluated span; partial weeks stop at edits or pauses.
        let periodEnd: Date
        let unit: StreakUnit
        let completedCount: Int
        let target: Int
    }

    /// Read-only history for calendar presentation, sharing the exact streak engine.
    static func periods(
        for habit: Habit, snapshots: [HabitConfigurationSnapshot], completions: [Completion],
        skips: [Skip], archivePeriods: [HabitArchivePeriod], asOf date: Date, calendar: Calendar
    ) -> [ProgressPeriod] {
        buildUnitSequence(habit: habit, snapshots: snapshots, completions: completions,
                          skips: skips, archivePeriods: archivePeriods, asOf: date, calendar: calendar)
    }

    private static func scan(_ units: [ProgressPeriod]) -> (current: Int, best: Int, lastMissKey: String?) {
        var current = 0
        var best = 0
        var lastMissKey: String?
        for unit in units {
            switch unit.outcome {
            case .success:
                current += 1
                best = max(best, current)
            case .skip:
                break // excused: continues the run without extending it
            case .miss:
                current = 0
                lastMissKey = unit.localDateKey
            case .pending:
                break // unfinished evaluation/archive periods remain neutral
            }
        }
        return (current, best, lastMissKey)
    }

    private static func effectiveEnd(for habit: Habit, asOf date: Date) -> Date {
        if let archivedAt = habit.archivedAt {
            return min(archivedAt, date)
        }
        return date
    }

    private static func currentStreakUnit(
        habit: Habit,
        snapshots: [HabitConfigurationSnapshot],
        asOf date: Date,
        calendar: Calendar
    ) -> StreakUnit {
        let end = effectiveEnd(for: habit, asOf: date)
        let config = HabitScheduleEvaluator.activeConfiguration(from: snapshots, on: end, calendar: calendar)
        if case .timesPerWeek = config?.schedule {
            return .weeks
        }
        return .days
    }

    /// A past archive/reactivate cycle's dormant window, in day-aligned terms:
    /// the archive day itself and the reactivation day are both still live
    /// (`start`/`end` exclude them), so only days strictly in between are
    /// skipped entirely.
    private static func dormantRange(
        for period: HabitArchivePeriod, calendar: Calendar
    ) -> (start: Date, end: Date)? {
        guard let reactivatedAt = period.reactivatedAt else { return nil } // open: handled by effectiveEnd instead
        let archiveDay = calendar.startOfDay(for: period.archivedAt)
        let start = calendar.date(byAdding: .day, value: 1, to: archiveDay) ?? archiveDay
        let end = calendar.startOfDay(for: reactivatedAt)
        guard start < end else { return nil } // reactivated same day or next day: no gap to exclude
        return (start, end)
    }

    /// Walks the habit's lifetime one local day at a time, from its creation
    /// day through `effectiveEnd`, resolving the schedule in effect on each
    /// day and emitting one `Unit` per day (`daily`/`weekdays`) or one `Unit`
    /// per calendar week (`timesPerWeek`, accumulated across that week's days).
    /// Day-granularity iteration — even under a weekly schedule — is what lets
    /// a schedule-kind change mid-week, or a pause starting/ending mid-week,
    /// close out a partial period correctly instead of silently double-counting
    /// or dropping days. Days inside a past (closed) archive period are skipped
    /// entirely, exactly as if they didn't exist.
    private static func buildUnitSequence(
        habit: Habit,
        snapshots: [HabitConfigurationSnapshot],
        completions: [Completion],
        skips: [Skip],
        archivePeriods: [HabitArchivePeriod],
        asOf date: Date,
        calendar: Calendar
    ) -> [ProgressPeriod] {
        guard !snapshots.isEmpty else { return [] }

        let end = effectiveEnd(for: habit, asOf: date)
        let startDay = calendar.startOfDay(for: habit.createdAt)
        let endDay = calendar.startOfDay(for: end)
        guard startDay <= endDay else { return [] }

        let completionDayKeys = Set(completions.filter { $0.habitID == habit.id }.map(\.localDateKey))
        let skipDayKeys = Set(skips.filter { $0.habitID == habit.id }.map(\.localDateKey))
        let archiveBoundaryDays = Set(archivePeriods
            .filter { $0.habitID == habit.id && $0.reactivatedAt != nil }
            .map { calendar.startOfDay(for: $0.archivedAt) })
        let dormantRanges = archivePeriods
            .filter { $0.habitID == habit.id }
            .compactMap { dormantRange(for: $0, calendar: calendar) }

        struct WeekBucket {
            let weekStart: Date
            let weekEndCap: Date
            let target: Int
            var completedDayKeys: Set<String> = []
            var evaluatedEnd: Date
        }

        var units: [ProgressPeriod] = []
        var bucket: WeekBucket?

        func closeBucket(isFinal: Bool) {
            guard let bucket else { return }
            let metTarget = bucket.completedDayKeys.count >= bucket.target
            let outcome: Outcome = metTarget ? .success : (isFinal ? .pending : .miss)
            units.append(ProgressPeriod(
                outcome: outcome,
                periodStart: bucket.weekStart,
                localDateKey: LocalDay.key(for: bucket.weekStart, calendar: calendar),
                periodEnd: bucket.evaluatedEnd, unit: .weeks,
                completedCount: bucket.completedDayKeys.count, target: bucket.target
            ))
        }

        var cursor = startDay
        while cursor <= endDay {
            if let dormant = dormantRanges.first(where: { cursor >= $0.start && cursor < $0.end }) {
                // Entering a past pause: resolve whatever was in progress the
                // same lenient way a final/interrupted period resolves (success
                // if already met, pending — never a manufactured miss —
                // otherwise), then skip every dormant day with no units at all.
                closeBucket(isFinal: true)
                bucket = nil
                guard dormant.end <= endDay else { break } // evaluation point itself falls inside this pause
                cursor = dormant.end
                continue
            }

            let next = calendar.date(byAdding: .day, value: 1, to: cursor) ?? endDay.addingTimeInterval(1)
            // A day is a "boundary" — eligible for pending rather than a
            // manufactured miss — if it's the last day of the whole evaluation
            // *or* the next day starts a past pause. Archiving mid-period must
            // leave that period pending exactly like reaching the evaluation
            // end does; without this, a day archived without being resolved
            // yet would wrongly resolve as a miss once the period is reactivated
            // and the walk continues past it.
            let entersDormancyNext = dormantRanges.contains { next >= $0.start && next < $0.end }
            let isBoundaryDay = cursor == endDay || entersDormancyNext || archiveBoundaryDays.contains(cursor)

            guard let config = HabitScheduleEvaluator.activeConfiguration(from: snapshots, on: cursor, calendar: calendar) else {
                cursor = next
                continue
            }

            switch config.schedule {
            case .daily, .weekdays:
                closeBucket(isFinal: false) // a prior week bucket, if any, ends: the schedule kind changed
                bucket = nil
                if HabitScheduleEvaluator.isDue(config.schedule, on: cursor, calendar: calendar) {
                    let key = LocalDay.key(for: cursor, calendar: calendar)
                    let outcome: Outcome
                    if completionDayKeys.contains(key) {
                        outcome = .success
                    } else if skipDayKeys.contains(key) {
                        outcome = .skip
                    } else if isBoundaryDay {
                        outcome = .pending
                    } else {
                        outcome = .miss
                    }
                    units.append(ProgressPeriod(outcome: outcome, periodStart: cursor, localDateKey: key,
                                                periodEnd: next, unit: .days,
                                                completedCount: outcome == .success ? 1 : 0, target: 1))
                }

            case .timesPerWeek(let target):
                let weekInterval = LocalDay.weekInterval(containing: cursor, calendar: calendar)
                if bucket == nil || bucket!.target != target {
                    closeBucket(isFinal: false)
                    bucket = WeekBucket(weekStart: cursor, weekEndCap: weekInterval.end, target: target, evaluatedEnd: next)
                }
                bucket!.evaluatedEnd = next
                let key = LocalDay.key(for: cursor, calendar: calendar)
                if completionDayKeys.contains(key) {
                    bucket!.completedDayKeys.insert(key)
                }
            }

            if case .timesPerWeek = config.schedule, let currentBucket = bucket, next >= currentBucket.weekEndCap {
                // The last calendar day is still open until its midnight.
                // Evaluation or archiving during it cannot create a miss.
                closeBucket(isFinal: isBoundaryDay)
                bucket = nil
            }
            if isBoundaryDay {
                closeBucket(isFinal: true)
                bucket = nil
            }
            cursor = next
        }

        return units
    }
}
