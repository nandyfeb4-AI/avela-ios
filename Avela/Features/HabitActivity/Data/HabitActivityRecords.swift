import Foundation
import SwiftData

@Model
final class HabitActivityConfigurationRecord {
    @Attribute(.unique) var id: UUID
    var habitID: UUID
    var effectiveDayKey: String
    var revision: Int
    var targetAmount: Int
    var unitRaw: String?
    var smallerAction: String
    /// Lossless local recovery decoding; validation happens before insertion.
    init(backup row: BackupPayload.HabitActivityConfigurationRecordRow) {
        self.id = row.id
        self.habitID = row.habitID
        self.effectiveDayKey = row.effectiveDayKey
        self.revision = row.revision
        self.targetAmount = row.targetAmount
        self.unitRaw = row.unitRaw
        self.smallerAction = row.smallerAction
    }

    init(habitID: UUID, dayKey: String, revision: Int, target: HabitQuantityTarget?, smallerAction: String) {
        id = UUID(); self.habitID = habitID; effectiveDayKey = dayKey; self.revision = revision
        targetAmount = target?.amount ?? 0; unitRaw = target?.unit.rawValue; self.smallerAction = smallerAction
    }
    var domain: HabitActivityConfiguration {
        HabitActivityConfiguration(id: id, habitID: habitID, effectiveDayKey: effectiveDayKey, revision: revision,
            target: unitRaw.flatMap(HabitQuantityUnit.init(rawValue:)).map { HabitQuantityTarget(amount: targetAmount, unit: $0) }, smallerAction: smallerAction)
    }
}

@Model
final class HabitActivityEntryRecord {
    @Attribute(.unique) var id: UUID
    var habitID: UUID
    var configurationID: UUID
    var dayKey: String
    var loggedAt: Date
    var kindRaw: String
    var amount: Int
    var unitRaw: String?
    var actionDescription: String
    /// Lossless local recovery decoding; validation happens before insertion.
    init(backup row: BackupPayload.HabitActivityEntryRecordRow) {
        self.id = row.id
        self.habitID = row.habitID
        self.configurationID = row.configurationID
        self.dayKey = row.dayKey
        self.loggedAt = row.loggedAt
        self.kindRaw = row.kindRaw
        self.amount = row.amount
        self.unitRaw = row.unitRaw
        self.actionDescription = row.actionDescription
    }

    init(habitID: UUID, configuration: HabitActivityConfiguration, dayKey: String, now: Date, kind: HabitActivityKind, amount: Int) {
        id = UUID(); self.habitID = habitID; configurationID = configuration.id; self.dayKey = dayKey
        loggedAt = now; kindRaw = kind.rawValue; self.amount = amount
        unitRaw = kind == .quantity ? configuration.target?.unit.rawValue : nil
        actionDescription = kind == .smallerAction ? configuration.smallerAction : configuration.target?.label ?? ""
    }
    var domain: HabitActivityEntry {
        HabitActivityEntry(id: id, habitID: habitID, configurationID: configurationID, dayKey: dayKey, loggedAt: loggedAt,
            kind: HabitActivityKind(rawValue: kindRaw) ?? .smallerAction, amount: amount,
            unit: unitRaw.flatMap(HabitQuantityUnit.init(rawValue:)), description: actionDescription)
    }
}

@Model
final class HabitTimerRecord {
    @Attribute(.unique) var habitID: UUID
    var dayKey: String
    var startedAt: Date?
    var elapsedSeconds: Int
    /// Lossless local recovery decoding; validation happens before insertion.
    init(backup row: BackupPayload.HabitTimerRecordRow) {
        self.habitID = row.habitID
        self.dayKey = row.dayKey
        self.startedAt = row.startedAt
        self.elapsedSeconds = row.elapsedSeconds
    }

    init(_ state: HabitTimerState) {
        habitID = state.habitID; dayKey = state.dayKey; startedAt = state.startedAt; elapsedSeconds = state.elapsedSeconds
    }
    var domain: HabitTimerState { HabitTimerState(habitID: habitID, dayKey: dayKey, startedAt: startedAt, elapsedSeconds: elapsedSeconds) }
}
