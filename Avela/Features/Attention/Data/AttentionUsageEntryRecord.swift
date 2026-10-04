import Foundation
import SwiftData

@Model
final class AttentionUsageEntryRecord {
    @Attribute(.unique) var id: UUID
    var attentionGoalID: UUID
    var amount: Double
    var unitRaw: String
    var recordedAt: Date
    var localDateKey: String
    var sourceRaw: String

    init(
        id: UUID,
        attentionGoalID: UUID,
        amount: Double,
        unitRaw: String,
        recordedAt: Date,
        localDateKey: String,
        sourceRaw: String
    ) {
        self.id = id
        self.attentionGoalID = attentionGoalID
        self.amount = amount
        self.unitRaw = unitRaw
        self.recordedAt = recordedAt
        self.localDateKey = localDateKey
        self.sourceRaw = sourceRaw
    }
}

extension AttentionUsageEntryRecord {
    convenience init(domain entry: AttentionUsageEntry) {
        self.init(
            id: entry.id,
            attentionGoalID: entry.attentionGoalID,
            amount: entry.amount,
            unitRaw: entry.unit.rawValue,
            recordedAt: entry.recordedAt,
            localDateKey: entry.localDateKey,
            sourceRaw: entry.source.rawValue
        )
    }

    func toDomain() -> AttentionUsageEntry {
        AttentionUsageEntry(
            id: id,
            attentionGoalID: attentionGoalID,
            amount: amount,
            unit: AttentionUnit(rawValue: unitRaw) ?? .minutes,
            recordedAt: recordedAt,
            localDateKey: localDateKey,
            source: AttentionUsageSource(rawValue: sourceRaw) ?? .manual
        )
    }
}
