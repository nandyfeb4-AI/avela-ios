import Foundation
import SwiftData

@Model
final class CompletionRecord {
    @Attribute(.unique) var id: UUID
    var habitID: UUID
    var occurredAt: Date
    var localDateKey: String
    var sourceRaw: String
    var note: String?
    var isQuantityDerived: Bool = false
    /// Lossless local recovery decoding; validation happens before insertion.
    init(backup row: BackupPayload.CompletionRecordRow) {
        self.id = row.id
        self.habitID = row.habitID
        self.occurredAt = row.occurredAt
        self.localDateKey = row.localDateKey
        self.sourceRaw = row.sourceRaw
        self.note = row.note
        self.isQuantityDerived = row.isQuantityDerived
    }


    init(
        id: UUID,
        habitID: UUID,
        occurredAt: Date,
        localDateKey: String,
        sourceRaw: String,
        note: String?
    ) {
        self.id = id
        self.habitID = habitID
        self.occurredAt = occurredAt
        self.localDateKey = localDateKey
        self.sourceRaw = sourceRaw
        self.note = note
    }
}

extension CompletionRecord {
    convenience init(domain completion: Completion) {
        self.init(
            id: completion.id,
            habitID: completion.habitID,
            occurredAt: completion.occurredAt,
            localDateKey: completion.localDateKey,
            sourceRaw: completion.source.rawValue,
            note: completion.note
        )
    }

    func toDomain() -> Completion {
        Completion(
            id: id,
            habitID: habitID,
            occurredAt: occurredAt,
            localDateKey: localDateKey,
            source: CompletionSource(rawValue: sourceRaw) ?? .app,
            note: note
        )
    }
}
