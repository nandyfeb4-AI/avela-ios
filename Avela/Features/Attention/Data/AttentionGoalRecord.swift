import Foundation
import SwiftData

/// SwiftData-backed storage for `AttentionGoal`. `targetValue`/`unit` are
/// deliberately NOT stored here — see `AttentionGoal`'s doc comment — only
/// `AttentionGoalConfigurationSnapshotRecord` holds them.
@Model
final class AttentionGoalRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var appOrCategoryLabel: String?
    var typeRaw: String
    var createdAt: Date
    var updatedAt: Date
    /// Lossless local recovery decoding; validation happens before insertion.
    init(backup row: BackupPayload.AttentionGoalRecordRow) {
        self.id = row.id
        self.name = row.name
        self.appOrCategoryLabel = row.appOrCategoryLabel
        self.typeRaw = row.typeRaw
        self.createdAt = row.createdAt
        self.updatedAt = row.updatedAt
    }


    init(
        id: UUID,
        name: String,
        appOrCategoryLabel: String?,
        typeRaw: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.appOrCategoryLabel = appOrCategoryLabel
        self.typeRaw = typeRaw
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension AttentionGoalRecord {
    convenience init(domain goal: AttentionGoal) {
        self.init(
            id: goal.id,
            name: goal.name,
            appOrCategoryLabel: goal.appOrCategoryLabel,
            typeRaw: goal.type.rawValue,
            createdAt: goal.createdAt,
            updatedAt: goal.updatedAt
        )
    }

    func apply(draft: AttentionGoalDraft, updatedAt: Date) {
        name = draft.name
        appOrCategoryLabel = draft.appOrCategoryLabel
        typeRaw = draft.type.rawValue
        self.updatedAt = updatedAt
    }

    var currentType: AttentionGoalType {
        AttentionGoalType(rawValue: typeRaw) ?? .maxDurationPerDay
    }

    func toDomain() -> AttentionGoal {
        AttentionGoal(
            id: id,
            name: name,
            appOrCategoryLabel: appOrCategoryLabel,
            type: currentType,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
