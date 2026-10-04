import Foundation

/// A deliberate, non-punitive skip of a habit on a given day. Distinct from an
/// absence of a completion record: a skip is a recorded fact, not a failure.
struct Skip: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let habitID: UUID
    let localDateKey: String
    let reason: SkipReason?
    let createdAt: Date
}

enum SkipReason: String, CaseIterable, Codable, Hashable, Sendable {
    case planned
    case illness
    case travel
    case other
}
