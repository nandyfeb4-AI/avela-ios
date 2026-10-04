import Foundation

/// User-editable fields for creating or updating an attention goal. Identity
/// (`id`, `createdAt`) and derived bookkeeping (`updatedAt`) are owned by the
/// repository, mirroring `HabitDraft`.
///
/// `targetValue`/`unit` live on the draft (not on `AttentionGoal`) because
/// they are exactly the fields the repository must snapshot into a new
/// `AttentionGoalConfigurationSnapshot` on every create/update, never written
/// directly onto a mutable "current value" field.
struct AttentionGoalDraft: Equatable, Sendable {
    var name: String
    var appOrCategoryLabel: String?
    var type: AttentionGoalType
    var targetValue: Double
    var unit: AttentionUnit
    /// Local wall-clock minutes after midnight. An end before start crosses midnight.
    var windowStartMinute: Int? = nil
    var windowEndMinute: Int? = nil

}
