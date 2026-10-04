import Foundation

/// Deterministic, SwiftUI-independent schedule math. Every function takes an
/// explicit `Calendar` so behavior around local day/week boundaries, daylight
/// saving, and time-zone changes is test-controlled rather than ambient.
enum HabitScheduleEvaluator {
    /// Whether `schedule` calls for action on `date`'s local calendar day.
    /// `timesPerWeek` habits have no single due day — any day is eligible toward
    /// the weekly target — so this always returns `true` for them.
    static func isDue(_ schedule: HabitSchedule, on date: Date, calendar: Calendar) -> Bool {
        switch schedule {
        case .daily, .timesPerWeek:
            return true
        case .weekdays(let days):
            guard let weekday = Weekday(calendarWeekday: calendar.component(.weekday, from: date)) else {
                return false
            }
            return days.contains(weekday)
        }
    }

    /// The snapshot that was in effect on `date`'s local day: the latest snapshot
    /// with `effectiveLocalDateKey <= date's key`, falling back to the earliest
    /// known snapshot if `date` precedes every snapshot (e.g. a clock set back
    /// past the habit's creation day).
    ///
    /// Ties on `effectiveLocalDateKey` (multiple edits on the same local day) are
    /// broken by `revision`, not `createdAt`: `createdAt` can collide (two edits
    /// sharing a captured `Date()`, or two snapshots built with the same injected
    /// timestamp), in which case the result would otherwise depend on the order
    /// `snapshots` happens to arrive in — SwiftData fetch order is not guaranteed
    /// to match insertion order. `revision` is a persisted, strictly increasing
    /// per-habit counter, so it cannot collide.
    static func activeConfiguration(
        from snapshots: [HabitConfigurationSnapshot],
        on date: Date,
        calendar: Calendar
    ) -> HabitConfigurationSnapshot? {
        activeConfiguration(from: snapshots, onKey: LocalDay.key(for: date, calendar: calendar))
    }

    /// Same resolution as `activeConfiguration(from:on:calendar:)`, but against
    /// an already-computed local-date key rather than a `Date`. Needed by
    /// callers — History, specifically — that only have a *stored*
    /// `localDateKey` (e.g. from a `Completion` or `Skip`) and must resolve
    /// against it directly: reconstructing a `Date` from the key and then
    /// re-deriving a key under the *current* calendar would risk landing on a
    /// different day than the one actually stored, exactly the kind of
    /// time-zone-induced drift historical records must never be subject to.
    static func activeConfiguration(
        from snapshots: [HabitConfigurationSnapshot],
        onKey key: String
    ) -> HabitConfigurationSnapshot? {
        guard !snapshots.isEmpty else { return nil }
        let eligible = snapshots.filter { $0.effectiveLocalDateKey <= key }
        if let latestEligible = eligible.max(by: isChronologicallyBefore) {
            return latestEligible
        }
        return snapshots.min(by: isChronologicallyBefore)
    }

    private static func isChronologicallyBefore(
        _ lhs: HabitConfigurationSnapshot,
        _ rhs: HabitConfigurationSnapshot
    ) -> Bool {
        if lhs.effectiveLocalDateKey != rhs.effectiveLocalDateKey {
            return lhs.effectiveLocalDateKey < rhs.effectiveLocalDateKey
        }
        return lhs.revision < rhs.revision
    }

    struct WeeklyProgress: Equatable {
        let weekInterval: DateInterval
        let target: Int
        let completedCount: Int

        var isSatisfied: Bool { completedCount >= target }
    }

    /// Progress toward a `timesPerWeek` target for the local calendar week
    /// containing `date`. Completions outside that week are ignored; a week with
    /// more *distinct days* completed than the target still reports the true
    /// count so "extra" completions remain visible per MVP.md. Progress counts
    /// distinct local days with a completion, not raw completion count, so
    /// logging twice on the same day cannot satisfy two units of the target by
    /// itself — the target means "N different days," not "N taps."
    static func weeklyProgress(
        habitID: UUID,
        target: Int,
        completions: [Completion],
        on date: Date,
        calendar: Calendar
    ) -> WeeklyProgress {
        let interval = LocalDay.weekInterval(containing: date, calendar: calendar)
        let completedDayKeys = Set(completions.filter { completion in
            completion.habitID == habitID
                && completion.occurredAt >= interval.start
                && completion.occurredAt < interval.end
        }.map(\.localDateKey))
        return WeeklyProgress(weekInterval: interval, target: target, completedCount: completedDayKeys.count)
    }
}
