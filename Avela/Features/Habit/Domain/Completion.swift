import Foundation

/// One logged occurrence of a habit.
struct Completion: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let habitID: UUID
    let occurredAt: Date
    /// `yyyy-MM-dd` for the calendar day `occurredAt` fell on, computed once at
    /// write time. See `LocalDay.key(for:calendar:)`.
    let localDateKey: String
    let source: CompletionSource
    var note: String?
}

enum CompletionSource: String, Codable, Hashable, Sendable {
    case app
    case widget
    case shortcutFuture
    case healthKit
    case notification
    case quantity
    case watch
}
