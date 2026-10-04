import Foundation

/// Append-only historical record of an `AttentionGoal`'s budget. Mirrors
/// `HabitConfigurationSnapshot`'s role exactly: editing a goal's target must
/// never rewrite what the target was on a past day (MVP.md: "editing today's
/// goal doesn't rewrite history").
///
/// `revision` breaks ties when two snapshots share the same
/// `effectiveLocalDateKey` (possible if a goal's budget is edited more than
/// once on the same local day) — `createdAt` alone cannot be trusted to
/// order same-day edits, for the same reason already documented on
/// `HabitConfigurationSnapshot`.
struct AttentionGoalConfigurationSnapshot: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let attentionGoalID: UUID
    let targetValue: Double
    let unit: AttentionUnit
    let effectiveLocalDateKey: String
    let revision: Int
    let createdAt: Date
    /// Local wall-clock minutes after midnight. An end before start crosses midnight.
    var windowStartMinute: Int? = nil
    var windowEndMinute: Int? = nil

}
