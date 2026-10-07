import Foundation
import SwiftData

/// SwiftData-backed storage for `HabitConfigurationSnapshot`. Rows are append-only:
/// the repository never mutates or deletes a snapshot once written, since each one
/// is a historical fact about what a habit's configuration was.
@Model
final class HabitConfigurationSnapshotRecord {
    @Attribute(.unique) var id: UUID
    var habitID: UUID
    var polarityRaw: String
    var scheduleKindRaw: String
    var scheduleWeekdaysRaw: [Int]
    var scheduleTimesPerWeek: Int?
    var effectiveLocalDateKey: String
    var revision: Int
    var createdAt: Date
    /// Lossless local recovery decoding; validation happens before insertion.
    init(backup row: BackupPayload.HabitConfigurationSnapshotRecordRow) {
        self.id = row.id
        self.habitID = row.habitID
        self.polarityRaw = row.polarityRaw
        self.scheduleKindRaw = row.scheduleKindRaw
        self.scheduleWeekdaysRaw = row.scheduleWeekdaysRaw
        self.scheduleTimesPerWeek = row.scheduleTimesPerWeek
        self.effectiveLocalDateKey = row.effectiveLocalDateKey
        self.revision = row.revision
        self.createdAt = row.createdAt
    }


    init(
        id: UUID,
        habitID: UUID,
        polarityRaw: String,
        scheduleKindRaw: String,
        scheduleWeekdaysRaw: [Int],
        scheduleTimesPerWeek: Int?,
        effectiveLocalDateKey: String,
        revision: Int,
        createdAt: Date
    ) {
        self.id = id
        self.habitID = habitID
        self.polarityRaw = polarityRaw
        self.scheduleKindRaw = scheduleKindRaw
        self.scheduleWeekdaysRaw = scheduleWeekdaysRaw
        self.scheduleTimesPerWeek = scheduleTimesPerWeek
        self.effectiveLocalDateKey = effectiveLocalDateKey
        self.revision = revision
        self.createdAt = createdAt
    }
}

extension HabitConfigurationSnapshotRecord {
    convenience init(domain snapshot: HabitConfigurationSnapshot) {
        let encoded = HabitRecord.encode(schedule: snapshot.schedule)
        self.init(
            id: snapshot.id,
            habitID: snapshot.habitID,
            polarityRaw: snapshot.polarity.rawValue,
            scheduleKindRaw: encoded.kind,
            scheduleWeekdaysRaw: encoded.weekdays,
            scheduleTimesPerWeek: encoded.timesPerWeek,
            effectiveLocalDateKey: snapshot.effectiveLocalDateKey,
            revision: snapshot.revision,
            createdAt: snapshot.createdAt
        )
    }

    func toDomain() -> HabitConfigurationSnapshot {
        HabitConfigurationSnapshot(
            id: id,
            habitID: habitID,
            polarity: HabitPolarity(rawValue: polarityRaw) ?? .positive,
            schedule: HabitRecord.decodeSchedule(
                kind: scheduleKindRaw,
                weekdays: scheduleWeekdaysRaw,
                timesPerWeek: scheduleTimesPerWeek
            ),
            effectiveLocalDateKey: effectiveLocalDateKey,
            revision: revision,
            createdAt: createdAt
        )
    }
}
