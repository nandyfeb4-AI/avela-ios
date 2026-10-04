import Foundation

/// A frozen record of a habit's schedule and polarity as of a given local day.
///
/// Editing a habit's schedule or polarity must not retroactively change how past
/// completions are interpreted (AGENTS.md: "Preserve historical facts when users
/// edit goals"). Every creation and every schedule/polarity edit appends one of
/// these; evaluating a past date always resolves the snapshot that was effective
/// on that date rather than the habit's current configuration.
struct HabitConfigurationSnapshot: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let habitID: UUID
    let polarity: HabitPolarity
    let schedule: HabitSchedule
    /// `yyyy-MM-dd`, local to the calendar in effect when the snapshot was created.
    let effectiveLocalDateKey: String
    /// Per-habit, zero-based, strictly increasing sequence number assigned by the
    /// repository at write time (0 for the creation snapshot, incrementing by 1 per
    /// later edit). This — not `createdAt` — is authoritative for ordering two
    /// snapshots that share an `effectiveLocalDateKey`: `createdAt` can collide
    /// (e.g. two edits made from the same captured `Date()`, or two snapshots
    /// constructed with the same injected timestamp in a test), which would make
    /// resolution depend on incidental array/fetch order. `revision` cannot
    /// collide, because the repository computes it from already-persisted rows.
    let revision: Int
    let createdAt: Date
}
