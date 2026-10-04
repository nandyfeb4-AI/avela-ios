import Foundation

/// A single manually-logged usage amount against an `AttentionGoal` on a
/// given local day. Unlike `Completion` (one per habit per day, toggled),
/// usage entries are additive — a day's total is the SUM of its entries, not
/// a single yes/no fact — because MVP.md's manual-logging flow is "log 15
/// minutes now, log another 10 later," not a single daily toggle.
struct AttentionUsageEntry: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let attentionGoalID: UUID
    var amount: Double
    let unit: AttentionUnit
    var recordedAt: Date
    /// The local calendar day this entry counts toward, in the same
    /// `yyyy-MM-dd` string form as `Completion.localDateKey` /
    /// `Skip.localDateKey`, computed once at creation time via `LocalDay` and
    /// never recomputed from `recordedAt` later (so a later system timezone
    /// change can't silently move a past entry to a different day).
    let localDateKey: String
    let source: AttentionUsageSource
}

/// `.manual` is this slice's only writer. `.screenTime` is named now, not
/// implemented, per ARCHITECTURE.md's explicit requirement that the
/// architecture "support future screenTime" as a usage source — unlike
/// `AttentionGoalType`'s deferred cases, this one is a cheap provenance tag
/// that costs nothing to pre-declare and changes no behavior today, the same
/// precedent already set by `CompletionSource.widget`/`.shortcutFuture`.
enum AttentionUsageSource: String, Codable, Hashable, Sendable {
    case manual
    case screenTime
}
