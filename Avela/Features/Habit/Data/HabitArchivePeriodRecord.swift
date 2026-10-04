import Foundation
import SwiftData

/// SwiftData-backed storage for `HabitArchivePeriod`. Rows are append-only: the
/// repository only ever inserts a new open period or sets `reactivatedAt` on an
/// existing one, never deletes or rewrites `archivedAt`.
@Model
final class HabitArchivePeriodRecord {
    @Attribute(.unique) var id: UUID
    var habitID: UUID
    var archivedAt: Date
    var reactivatedAt: Date?

    init(id: UUID, habitID: UUID, archivedAt: Date, reactivatedAt: Date?) {
        self.id = id
        self.habitID = habitID
        self.archivedAt = archivedAt
        self.reactivatedAt = reactivatedAt
    }
}

extension HabitArchivePeriodRecord {
    convenience init(domain period: HabitArchivePeriod) {
        self.init(id: period.id, habitID: period.habitID, archivedAt: period.archivedAt, reactivatedAt: period.reactivatedAt)
    }

    func toDomain() -> HabitArchivePeriod {
        HabitArchivePeriod(id: id, habitID: habitID, archivedAt: archivedAt, reactivatedAt: reactivatedAt)
    }
}
