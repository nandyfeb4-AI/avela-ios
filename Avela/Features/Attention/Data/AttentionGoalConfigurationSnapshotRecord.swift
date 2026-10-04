import Foundation
import SwiftData

/// SwiftData-backed storage for `AttentionGoalConfigurationSnapshot`. Rows
/// are append-only: the repository never mutates or deletes a snapshot once
/// written, since each one is a historical fact about what a goal's budget
/// was, mirroring `HabitConfigurationSnapshotRecord`.
@Model
final class AttentionGoalConfigurationSnapshotRecord {
    @Attribute(.unique) var id: UUID
    var attentionGoalID: UUID
    var targetValue: Double
    var unitRaw: String
    var effectiveLocalDateKey: String
    var revision: Int
    var createdAt: Date
    var windowStartMinute: Int?
    var windowEndMinute: Int?

    init(
        id: UUID,
        attentionGoalID: UUID,
        targetValue: Double,
        unitRaw: String,
        effectiveLocalDateKey: String,
        revision: Int,
        createdAt: Date,
        windowStartMinute: Int? = nil,
        windowEndMinute: Int? = nil
    ) {
        self.id = id
        self.attentionGoalID = attentionGoalID
        self.targetValue = targetValue
        self.unitRaw = unitRaw
        self.effectiveLocalDateKey = effectiveLocalDateKey
        self.revision = revision
        self.createdAt = createdAt
        self.windowStartMinute = windowStartMinute
        self.windowEndMinute = windowEndMinute
    }
}

extension AttentionGoalConfigurationSnapshotRecord {
    convenience init(domain snapshot: AttentionGoalConfigurationSnapshot) {
        self.init(
            id: snapshot.id,
            attentionGoalID: snapshot.attentionGoalID,
            targetValue: snapshot.targetValue,
            unitRaw: snapshot.unit.rawValue,
            effectiveLocalDateKey: snapshot.effectiveLocalDateKey,
            revision: snapshot.revision,
            createdAt: snapshot.createdAt,
            windowStartMinute: snapshot.windowStartMinute, windowEndMinute: snapshot.windowEndMinute
        )
    }

    func toDomain() -> AttentionGoalConfigurationSnapshot {
        AttentionGoalConfigurationSnapshot(
            id: id,
            attentionGoalID: attentionGoalID,
            targetValue: targetValue,
            unit: AttentionUnit(rawValue: unitRaw) ?? .minutes,
            effectiveLocalDateKey: effectiveLocalDateKey,
            revision: revision,
            createdAt: createdAt,
            windowStartMinute: windowStartMinute, windowEndMinute: windowEndMinute
        )
    }
}
