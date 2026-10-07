import ActivityKit
import Foundation

/// Shared with the widget extension. No goal names or tracking history leave
/// the main app. Captured dates never change when a goal is edited.
struct PhoneFreeActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var animal: String?
        var isFocusSession: Bool? = nil
    }
    let sessionID: UUID
    let startedAt: Date
    let expectedEnd: Date
}
