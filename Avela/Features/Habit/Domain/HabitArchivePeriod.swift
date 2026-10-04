import Foundation

/// A record of one archive-to-reactivate cycle for a habit. Append-only, same
/// pattern as `HabitConfigurationSnapshot`: archiving opens one (`reactivatedAt
/// == nil`); reactivating closes the open one. A habit paused and resumed
/// multiple times accumulates multiple periods, so progress metrics can treat
/// every past dormant window the same way — as time that simply didn't happen,
/// not as missed commitments — regardless of how many times it was paused.
struct HabitArchivePeriod: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let habitID: UUID
    let archivedAt: Date
    let reactivatedAt: Date?

    var isOpen: Bool { reactivatedAt == nil }
}
