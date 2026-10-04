import Foundation
import SwiftData

@Model
final class SkipRecord {
    @Attribute(.unique) var id: UUID
    var habitID: UUID
    var localDateKey: String
    var reasonRaw: String?
    var createdAt: Date

    init(
        id: UUID,
        habitID: UUID,
        localDateKey: String,
        reasonRaw: String?,
        createdAt: Date
    ) {
        self.id = id
        self.habitID = habitID
        self.localDateKey = localDateKey
        self.reasonRaw = reasonRaw
        self.createdAt = createdAt
    }
}

extension SkipRecord {
    convenience init(domain skip: Skip) {
        self.init(
            id: skip.id,
            habitID: skip.habitID,
            localDateKey: skip.localDateKey,
            reasonRaw: skip.reason?.rawValue,
            createdAt: skip.createdAt
        )
    }

    func toDomain() -> Skip {
        Skip(
            id: id,
            habitID: habitID,
            localDateKey: localDateKey,
            reason: reasonRaw.flatMap(SkipReason.init(rawValue:)),
            createdAt: createdAt
        )
    }
}
