import Foundation
import CryptoKit
import SwiftData

enum BackupError: LocalizedError, Equatable {
    case unavailable, accountChanged, invalidFile, unsupportedVersion, existingHistory, unsavedChanges
    var errorDescription: String? {
        switch self {
        case .unavailable: return "iCloud backup isn't available right now. Your local progress is unchanged."
        case .accountChanged: return "Your iCloud account changed. Enable backup again for the current account."
        case .invalidFile: return "This backup couldn't be verified. Nothing was restored."
        case .unsupportedVersion: return "This backup needs a newer version of Avela. Nothing was restored."
        case .existingHistory: return "Restore is available only before tracking begins on this installation. Your existing history won't be overwritten."
        case .unsavedChanges: return "Finish saving your current changes before backing up or restoring."
        }
    }
}

struct BackupArchive: Codable {
    static let maximumBytes = 40 * 1024 * 1024
    let version: Int
    let id: UUID
    let createdAt: Date
    let excludedHealthHabitCount: Int
    let payload: Data
    let checksum: String

    static func make(payload: BackupPayload, excluded: Int, at date: Date) throws -> Self {
        try payload.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(payload)
        guard bytes.count <= maximumBytes else { throw BackupError.invalidFile }
        return Self(version: 1, id: UUID(), createdAt: date, excludedHealthHabitCount: excluded,
                    payload: bytes, checksum: digest(bytes))
    }
    func verifiedPayload() throws -> BackupPayload {
        guard version == 1 else { throw BackupError.unsupportedVersion }
        guard payload.count <= Self.maximumBytes, (0...200_000).contains(excludedHealthHabitCount),
              createdAt.timeIntervalSince1970.isFinite,
              (-2_208_988_800...253_402_300_799).contains(createdAt.timeIntervalSince1970),
              checksum == Self.digest(payload) else { throw BackupError.invalidFile }
        let result = try JSONDecoder().decode(BackupPayload.self, from: payload)
        try result.validate()
        guard result.habitTimerRecords.allSatisfy({ row in row.startedAt.map { $0 <= createdAt } ?? true }),
              result.attentionSessionRecords.allSatisfy({ $0.startedAt <= createdAt && ($0.endedAt != nil || $0.outcomeRaw == nil) }) else { throw BackupError.invalidFile }
        return result
    }
    static func decode(_ bytes: Data) throws -> Self {
        guard bytes.count <= maximumBytes * 2 else { throw BackupError.invalidFile }
        let archive = try JSONDecoder().decode(Self.self, from: bytes)
        _ = try archive.verifiedPayload()
        return archive
    }
    static func digest(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}

extension BackupPayload {
    /// Exclude an entire health-related habit rather than manufacturing misses
    /// by removing only its imported check-ins. No Health settings reach iCloud.
    mutating func excludeHealthTracking() -> Int {
        let healthIDs = Set(healthHabitConnectionRecords.map(\.habitID))
            .union(completionRecords.filter { $0.sourceRaw == CompletionSource.healthKit.rawValue }.map(\.habitID))
            .union(habitRecords.filter { $0.categoryRaw == "health" || $0.categoryRaw == "fitness" }.map(\.id))
        let count = habitRecords.filter { healthIDs.contains($0.id) }.count
        healthHabitConnectionRecords = []
        weeklyReflectionRecords = []
        for index in completionRecords.indices { completionRecords[index].note = nil }
        habitRecords.removeAll { healthIDs.contains($0.id) }
        habitReminderRecords.removeAll { healthIDs.contains($0.habitID) }
        habitConfigurationSnapshotRecords.removeAll { healthIDs.contains($0.habitID) }
        habitActivityConfigurationRecords.removeAll { healthIDs.contains($0.habitID) }
        habitActivityEntryRecords.removeAll { healthIDs.contains($0.habitID) }
        habitTimerRecords.removeAll { healthIDs.contains($0.habitID) }
        completionRecords.removeAll { healthIDs.contains($0.habitID) }
        skipRecords.removeAll { healthIDs.contains($0.habitID) }
        habitArchivePeriodRecords.removeAll { healthIDs.contains($0.habitID) }
        intentionSessionLinkRecords.removeAll { healthIDs.contains($0.habitID) }
        for index in routineRecords.indices { routineRecords[index].habitIDs.removeAll { healthIDs.contains($0) } }
        routineRecords.removeAll { $0.habitIDs.isEmpty }
        return count
    }

    func validate() throws {
        try validateIdentities()
        try validateScalarValues()
        // A CloudKit snapshot is never allowed to contain Health connections or
        // Health-derived successes, including a downloaded/corrupted snapshot.
        guard healthHabitConnectionRecords.isEmpty, weeklyReflectionRecords.isEmpty,
              completionRecords.allSatisfy({ $0.note == nil }),
              !habitRecords.contains(where: { $0.categoryRaw == "health" || $0.categoryRaw == "fitness" }),
              !completionRecords.contains(where: { $0.sourceRaw == "healthKit" }) else { throw BackupError.invalidFile }
        let habits = Set(habitRecords.map(\.id))
        let goals = Set(attentionGoalRecords.map(\.id))
        let configs = Dictionary(uniqueKeysWithValues: habitActivityConfigurationRecords.map { ($0.id, $0.habitID) })
        let sessions = Set(attentionSessionRecords.map(\.id))
        guard habitConfigurationSnapshotRecords.allSatisfy({ habits.contains($0.habitID) }),
              completionRecords.allSatisfy({ habits.contains($0.habitID) }),
              skipRecords.allSatisfy({ habits.contains($0.habitID) }),
              habitArchivePeriodRecords.allSatisfy({ habits.contains($0.habitID) }),
              habitReminderRecords.allSatisfy({ habits.contains($0.habitID) }),
              habitActivityConfigurationRecords.allSatisfy({ habits.contains($0.habitID) }),
              habitActivityEntryRecords.allSatisfy({ habits.contains($0.habitID) && configs[$0.configurationID] == $0.habitID }),
              habitTimerRecords.allSatisfy({ habits.contains($0.habitID) }),
              routineRecords.allSatisfy({ !$0.habitIDs.isEmpty && Set($0.habitIDs).count == $0.habitIDs.count && $0.habitIDs.allSatisfy(habits.contains) }),
              attentionGoalConfigurationSnapshotRecords.allSatisfy({ goals.contains($0.attentionGoalID) && $0.targetValue.isFinite && $0.targetValue > 0 }),
              attentionUsageEntryRecords.allSatisfy({ goals.contains($0.attentionGoalID) && $0.amount.isFinite && $0.amount >= 0 }),
              attentionCheckInRecords.allSatisfy({ goals.contains($0.attentionGoalID) && $0.windowEnd > $0.windowStart }),
              attentionSessionRecords.allSatisfy({ goals.contains($0.attentionGoalID) && $0.expectedEnd > $0.startedAt && $0.targetMinutes.isFinite && $0.targetMinutes > 0 }),
              intentionSessionLinkRecords.allSatisfy({ habits.contains($0.habitID) && sessions.contains($0.sessionID) }),
              companionProfileRecords.count <= 1, appAppearanceRecords.count <= 1 else { throw BackupError.invalidFile }
        func schedule(_ kind: String, _ weekdays: [Int], _ target: Int?) -> Bool {
            switch kind {
            case "daily": return true
            case "weekdays": return !weekdays.isEmpty && Set(weekdays).count == weekdays.count && weekdays.allSatisfy { (1...7).contains($0) }
            case "timesPerWeek": return target.map { (1...7).contains($0) } ?? false
            default: return false
            }
        }
        guard habitRecords.allSatisfy({ !$0.name.isEmpty && HabitCategory(rawValue: $0.categoryRaw) != nil && HabitPolarity(rawValue: $0.polarityRaw) != nil && schedule($0.scheduleKindRaw, $0.scheduleWeekdaysRaw, $0.scheduleTimesPerWeek) }),
              habitConfigurationSnapshotRecords.allSatisfy({ $0.revision >= 0 && HabitPolarity(rawValue: $0.polarityRaw) != nil && schedule($0.scheduleKindRaw, $0.scheduleWeekdaysRaw, $0.scheduleTimesPerWeek) }),
              habitRecords.allSatisfy({ habit in habitConfigurationSnapshotRecords.contains { $0.habitID == habit.id } }),
              attentionGoalRecords.allSatisfy({ goal in AttentionGoalType(rawValue: goal.typeRaw) != nil && attentionGoalConfigurationSnapshotRecords.contains { $0.attentionGoalID == goal.id } }),
              completionRecords.allSatisfy({ CompletionSource(rawValue: $0.sourceRaw) != nil }),
              habitReminderRecords.allSatisfy({ (0...23).contains($0.hour) && (0...59).contains($0.minute) }),
              weeklyReflectionRecords.allSatisfy({ $0.weekEnd > $0.weekStart && TimeZone(identifier: $0.timeZoneIdentifier) != nil }) else { throw BackupError.invalidFile }
        guard habitTimerRecords.allSatisfy({ $0.elapsedSeconds >= 0 && $0.elapsedSeconds <= 86_400 }),
              habitActivityEntryRecords.allSatisfy({ $0.amount >= 0 && $0.amount <= 10_000 && HabitActivityKind(rawValue: $0.kindRaw) != nil }),
              attentionGoalConfigurationSnapshotRecords.allSatisfy({ AttentionUnit(rawValue: $0.unitRaw) != nil && $0.revision >= 0 }),
              attentionUsageEntryRecords.allSatisfy({ AttentionUnit(rawValue: $0.unitRaw) != nil && AttentionUsageSource(rawValue: $0.sourceRaw) != nil }) else { throw BackupError.invalidFile }
        guard habitActivityConfigurationRecords.allSatisfy({ $0.revision >= 0 && (0...10_000).contains($0.targetAmount) && ($0.unitRaw.map { HabitQuantityUnit(rawValue: $0) != nil } ?? ($0.targetAmount == 0)) }),
              habitActivityEntryRecords.allSatisfy({ $0.unitRaw.map { HabitQuantityUnit(rawValue: $0) != nil } ?? ($0.kindRaw == "smallerAction") }),
              habitArchivePeriodRecords.allSatisfy({ row in row.reactivatedAt.map { $0 >= row.archivedAt } ?? true }),
              routineRecords.allSatisfy({ $0.restartDays == nil || $0.restartDays == 3 || $0.restartDays == 7 }),
              attentionCheckInRecords.allSatisfy({ $0.revision >= 0 && AttentionCheckInOutcome(rawValue: $0.outcomeRaw) != nil }),
              attentionSessionRecords.allSatisfy({ row in (row.outcomeRaw.map { AttentionCheckInOutcome(rawValue: $0) != nil } ?? true) && (row.endedAt.map { $0 >= row.startedAt } ?? true) }),
              companionProfileRecords.allSatisfy({ $0.profileID == "primary" && CompanionAnimal(rawValue: $0.selectedAnimalRaw) != nil }),
              appAppearanceRecords.allSatisfy({ $0.preferencesID == "primary" && AppTheme(rawValue: $0.themeRaw) != nil }) else { throw BackupError.invalidFile }
        let activityRevisions = habitActivityConfigurationRecords.map { "\($0.habitID)/\($0.revision)" }
        guard Set(activityRevisions).count == activityRevisions.count else { throw BackupError.invalidFile }
        let revisions = habitConfigurationSnapshotRecords.map { "\($0.habitID)/\($0.revision)" }
        let attentionRevisions = attentionGoalConfigurationSnapshotRecords.map { "\($0.attentionGoalID)/\($0.revision)" }
        guard Set(revisions).count == revisions.count, Set(attentionRevisions).count == attentionRevisions.count else { throw BackupError.invalidFile }
    }
}

@MainActor
final class BackupStore {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }
    func capture(at date: Date = Date()) throws -> BackupArchive {
        guard !context.hasChanges else { throw BackupError.unsavedChanges }
        let reader = ModelContext(context.container)
        reader.autosaveEnabled = false
        var payload = try BackupPayload(context: reader)
        let excluded = payload.excludeHealthTracking()
        return try BackupArchive.make(payload: payload, excluded: excluded, at: date)
    }
    func canRestore() throws -> Bool {
        guard !context.hasChanges else { return false }
        return try !BackupPayload.hasTracking(in: context)
    }
    func restore(_ archive: BackupArchive) throws {
        let payload = try archive.verifiedPayload()
        guard !context.hasChanges else { throw BackupError.unsavedChanges }
        guard try canRestore() else { throw BackupError.existingHistory }
        // One save, with rollback on failure; existing tracking is never deleted.
        do {
            for row in try context.fetch(FetchDescriptor<CompanionProfileRecord>()) { context.delete(row) }
            for row in try context.fetch(FetchDescriptor<AppAppearanceRecord>()) { context.delete(row) }
            var restored = payload
            // Restore configuration/history, not system authorizations or a
            // running timer/notification from a device that no longer exists.
            for index in restored.habitReminderRecords.indices { restored.habitReminderRecords[index].isEnabled = false }
            for index in restored.habitTimerRecords.indices {
                var timer = restored.habitTimerRecords[index]
                if let start = timer.startedAt {
                    timer.elapsedSeconds = min(86_400, timer.elapsedSeconds + Int(max(0, min(86_400, archive.createdAt.timeIntervalSince(start)))))
                    timer.startedAt = nil
                }
                restored.habitTimerRecords[index] = timer
            }
            for index in restored.attentionSessionRecords.indices where restored.attentionSessionRecords[index].endedAt == nil {
                restored.attentionSessionRecords[index].endedAt = archive.createdAt
            }
            restored.insert(into: context)
            try context.save()
        } catch { context.rollback(); throw error }
    }
}
