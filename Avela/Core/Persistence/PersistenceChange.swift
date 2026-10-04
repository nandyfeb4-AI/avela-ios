import Foundation

/// Successful local writes invalidate app-owned projections and widget snapshots.
/// The notification carries no user data and is not an authority for persistence.
extension Notification.Name {
    static let avelaPersistenceDidChange = Notification.Name("Avela.persistenceDidChange")
}
