import Foundation

/// Canonical manual attention-tracking goal. Pure domain data: no SwiftData or
/// SwiftUI dependency, per ARCHITECTURE.md's layering rules.
/// Maximum-duration, protected-window and phone-free goals share identity;
/// type is immutable after creation so historical records keep their meaning.
struct AttentionGoal: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    var name: String
    /// Optional free-text label for which app/category this goal tracks
    /// (e.g. "Instagram"), shown alongside `name` but not used in any
    /// calculation.
    var appOrCategoryLabel: String?
    var type: AttentionGoalType
    let createdAt: Date
    var updatedAt: Date

    // `targetValue`/`unit` are intentionally not stored on `AttentionGoal`
    // itself, even though DATA_MODEL.md's conceptual shape lists them there —
    // see `AttentionGoalConfigurationSnapshot`, which owns them instead, for
    // the same reason `Habit`'s current schedule is never read directly for
    // historical interpretation: a budget edit must not be a destructive
    // overwrite of "what the target was." `AttentionGoal` itself never
    // changes once created except its name/category label (cosmetic) and
    // `updatedAt`.
}

/// Supported manual goal families.
enum AttentionGoalType: String, Codable, Hashable, Sendable {
    case maxDurationPerDay
    case noUseBeforeTime
    case phoneFreeUntilTime
    case phoneFreeSession

    var label: String {
        switch self {
        case .maxDurationPerDay: return "Daily budget"
        case .noUseBeforeTime: return "Protected window"
        case .phoneFreeUntilTime: return "Phone-free window"
        case .phoneFreeSession: return "Phone-free session"
        }
    }
}

/// V1 only ever creates `.minutes` values; the type exists (rather than a
/// bare `Double`) because DATA_MODEL.md documents `unit` as part of both
/// `AttentionGoal` and `AttentionUsageEntry`'s shape, and because a future
/// unit (e.g. a count-based goal) would otherwise require migrating every
/// stored amount's meaning silently.
enum AttentionUnit: String, Codable, Hashable, Sendable {
    case minutes
}
