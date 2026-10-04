import Foundation

/// Deterministic resolution of which budget was in effect on a given local
/// day. Not shared/generalized with `HabitScheduleEvaluator` via generics —
/// the two snapshot types resolve against unrelated domain concepts
/// (schedule vs. budget) and keeping them independent avoids a premature
/// shared abstraction across otherwise-unrelated features.
enum AttentionGoalEvaluator {
    /// The snapshot in effect on `date`'s local day: the latest snapshot with
    /// `effectiveLocalDateKey <= date's key`, falling back to the earliest
    /// known snapshot if `date` precedes every snapshot. Ties on
    /// `effectiveLocalDateKey` are broken by `revision`, not `createdAt`, for
    /// the same reason documented on
    /// `HabitScheduleEvaluator.activeConfiguration`.
    static func activeConfiguration(
        from snapshots: [AttentionGoalConfigurationSnapshot],
        on date: Date,
        calendar: Calendar
    ) -> AttentionGoalConfigurationSnapshot? {
        activeConfiguration(from: snapshots, onKey: LocalDay.key(for: date, calendar: calendar))
    }

    /// Same resolution as `activeConfiguration(from:on:calendar:)`, but
    /// against an already-computed local-date key — needed when a caller
    /// only has a stored `localDateKey` (e.g. from an `AttentionUsageEntry`)
    /// and must resolve against it directly, for the same drift-avoidance
    /// reason documented on `HabitScheduleEvaluator`'s key-based overload.
    static func activeConfiguration(
        from snapshots: [AttentionGoalConfigurationSnapshot],
        onKey key: String
    ) -> AttentionGoalConfigurationSnapshot? {
        guard !snapshots.isEmpty else { return nil }
        let eligible = snapshots.filter { $0.effectiveLocalDateKey <= key }
        if let latestEligible = eligible.max(by: isChronologicallyBefore) {
            return latestEligible
        }
        return snapshots.min(by: isChronologicallyBefore)
    }

    private static func isChronologicallyBefore(
        _ lhs: AttentionGoalConfigurationSnapshot,
        _ rhs: AttentionGoalConfigurationSnapshot
    ) -> Bool {
        if lhs.effectiveLocalDateKey != rhs.effectiveLocalDateKey {
            return lhs.effectiveLocalDateKey < rhs.effectiveLocalDateKey
        }
        return lhs.revision < rhs.revision
    }
}
