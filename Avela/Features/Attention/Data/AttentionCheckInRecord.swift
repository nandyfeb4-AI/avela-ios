import Foundation
import SwiftData

@Model
final class AttentionCheckInRecord {
    @Attribute(.unique) var id: UUID
    var attentionGoalID: UUID
    var localDateKey: String
    var windowStart: Date
    var windowEnd: Date
    var outcomeRaw: String
    var recordedAt: Date
    var revision: Int
    /// Lossless local recovery decoding; validation happens before insertion.
    init(backup row: BackupPayload.AttentionCheckInRecordRow) {
        self.id = row.id
        self.attentionGoalID = row.attentionGoalID
        self.localDateKey = row.localDateKey
        self.windowStart = row.windowStart
        self.windowEnd = row.windowEnd
        self.outcomeRaw = row.outcomeRaw
        self.recordedAt = row.recordedAt
        self.revision = row.revision
    }


    init(domain value: AttentionCheckIn) {
        id = value.id
        attentionGoalID = value.attentionGoalID
        localDateKey = value.localDateKey
        windowStart = value.windowStart
        windowEnd = value.windowEnd
        outcomeRaw = value.outcome.rawValue
        recordedAt = value.recordedAt
        revision = value.revision
    }

    func toDomain() -> AttentionCheckIn {
        AttentionCheckIn(id: id, attentionGoalID: attentionGoalID, localDateKey: localDateKey,
            windowStart: windowStart, windowEnd: windowEnd,
            outcome: AttentionCheckInOutcome(rawValue: outcomeRaw) ?? .interrupted,
            recordedAt: recordedAt, revision: revision)
    }
}

@Model
final class AttentionSessionRecord {
    @Attribute(.unique) var id: UUID
    var attentionGoalID: UUID
    var startedAt: Date
    var expectedEnd: Date
    var targetMinutes: Double
    var endedAt: Date?
    var outcomeRaw: String?
    /// Lossless local recovery decoding; validation happens before insertion.
    init(backup row: BackupPayload.AttentionSessionRecordRow) {
        self.id = row.id
        self.attentionGoalID = row.attentionGoalID
        self.startedAt = row.startedAt
        self.expectedEnd = row.expectedEnd
        self.targetMinutes = row.targetMinutes
        self.endedAt = row.endedAt
        self.outcomeRaw = row.outcomeRaw
    }


    init(domain value: AttentionSession) {
        id = value.id
        attentionGoalID = value.attentionGoalID
        startedAt = value.startedAt
        expectedEnd = value.expectedEnd
        targetMinutes = value.targetMinutes
        endedAt = value.endedAt
        outcomeRaw = value.outcome?.rawValue
    }

    func toDomain() -> AttentionSession {
        AttentionSession(id: id, attentionGoalID: attentionGoalID, startedAt: startedAt,
            expectedEnd: expectedEnd, targetMinutes: targetMinutes, endedAt: endedAt,
            outcome: outcomeRaw.flatMap(AttentionCheckInOutcome.init(rawValue:)))
    }
}
