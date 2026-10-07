import Foundation

/// Captures what the user wanted to make room for. It is a declared intention,
/// never evidence that a habit was performed or phone use was prevented.
struct IntentionSessionLink: Identifiable, Equatable, Sendable {
    let id: UUID
    let habitID: UUID
    let sessionID: UUID
    let createdAt: Date
}

@MainActor
protocol IntentionSessionLinkRepository {
    func links(for habitID: UUID) throws -> [IntentionSessionLink]
    func save(_ link: IntentionSessionLink) throws
}

enum IntentionSessionLinkError: Error { case conflictingIntention }
