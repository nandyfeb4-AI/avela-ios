import Foundation
import SwiftData

/// Development-only schema probe, not a habit or a canonical product model.
/// Replace this schema deliberately when implementing DATA_MODEL.md.
@Model
final class ScaffoldRecord {
    @Attribute(.unique) var id: UUID
    var createdAt: Date

    init(id: UUID = UUID(), createdAt: Date = Date()) {
        self.id = id
        self.createdAt = createdAt
    }
}
