import Foundation
import SwiftData

/// Versioned logical snapshot. IDs and captured civil dates are never re-derived.
struct BackupPayload: Codable {
    struct HealthHabitConnectionRecordRow: Codable {
        var habitID: UUID
        var connectionID: UUID
        var metricRawValue: String
        var target: Double
        var connectedAt: Date

        @MainActor init(_ row: HealthHabitConnectionRecord) {
            habitID = row.habitID
            connectionID = row.connectionID
            metricRawValue = row.metricRawValue
            target = row.target
            connectedAt = row.connectedAt
        }
    }
    var healthHabitConnectionRecords: [HealthHabitConnectionRecordRow] = []

    struct HabitReminderRecordRow: Codable {
        var habitID: UUID
        var isEnabled: Bool
        var hour: Int
        var minute: Int

        @MainActor init(_ row: HabitReminderRecord) {
            habitID = row.habitID
            isEnabled = row.isEnabled
            hour = row.hour
            minute = row.minute
        }
    }
    var habitReminderRecords: [HabitReminderRecordRow] = []

    struct HabitRecordRow: Codable {
        var id: UUID
        var name: String
        var iconName: String
        var categoryRaw: String
        var polarityRaw: String
        var scheduleKindRaw: String
        var scheduleWeekdaysRaw: [Int]
        var scheduleTimesPerWeek: Int?
        var createdAt: Date
        var updatedAt: Date
        var archivedAt: Date?
        var sortOrder: Int

        @MainActor init(_ row: HabitRecord) {
            id = row.id
            name = row.name
            iconName = row.iconName
            categoryRaw = row.categoryRaw
            polarityRaw = row.polarityRaw
            scheduleKindRaw = row.scheduleKindRaw
            scheduleWeekdaysRaw = row.scheduleWeekdaysRaw
            scheduleTimesPerWeek = row.scheduleTimesPerWeek
            createdAt = row.createdAt
            updatedAt = row.updatedAt
            archivedAt = row.archivedAt
            sortOrder = row.sortOrder
        }
    }
    var habitRecords: [HabitRecordRow] = []

    struct HabitActivityConfigurationRecordRow: Codable {
        var id: UUID
        var habitID: UUID
        var effectiveDayKey: String
        var revision: Int
        var targetAmount: Int
        var unitRaw: String?
        var smallerAction: String

        @MainActor init(_ row: HabitActivityConfigurationRecord) {
            id = row.id
            habitID = row.habitID
            effectiveDayKey = row.effectiveDayKey
            revision = row.revision
            targetAmount = row.targetAmount
            unitRaw = row.unitRaw
            smallerAction = row.smallerAction
        }
    }
    var habitActivityConfigurationRecords: [HabitActivityConfigurationRecordRow] = []

    struct HabitActivityEntryRecordRow: Codable {
        var id: UUID
        var habitID: UUID
        var configurationID: UUID
        var dayKey: String
        var loggedAt: Date
        var kindRaw: String
        var amount: Int
        var unitRaw: String?
        var actionDescription: String

        @MainActor init(_ row: HabitActivityEntryRecord) {
            id = row.id
            habitID = row.habitID
            configurationID = row.configurationID
            dayKey = row.dayKey
            loggedAt = row.loggedAt
            kindRaw = row.kindRaw
            amount = row.amount
            unitRaw = row.unitRaw
            actionDescription = row.actionDescription
        }
    }
    var habitActivityEntryRecords: [HabitActivityEntryRecordRow] = []

    struct HabitTimerRecordRow: Codable {
        var habitID: UUID
        var dayKey: String
        var startedAt: Date?
        var elapsedSeconds: Int

        @MainActor init(_ row: HabitTimerRecord) {
            habitID = row.habitID
            dayKey = row.dayKey
            startedAt = row.startedAt
            elapsedSeconds = row.elapsedSeconds
        }
    }
    var habitTimerRecords: [HabitTimerRecordRow] = []

    struct RoutineRecordRow: Codable {
        var id: UUID
        var name: String
        var habitIDs: [UUID]
        var createdAt: Date
        var restartDays: Int?
        var updatedAt: Date

        @MainActor init(_ row: RoutineRecord) {
            id = row.id
            name = row.name
            habitIDs = row.habitIDs
            createdAt = row.createdAt
            restartDays = row.restartDays
            updatedAt = row.updatedAt
        }
    }
    var routineRecords: [RoutineRecordRow] = []

    struct WeeklyReflectionRecordRow: Codable {
        var weekKey: String
        var id: UUID
        var weekStart: Date
        var weekEnd: Date
        var timeZoneIdentifier: String
        var whatHelped: String
        var whatGotInTheWay: String
        var createdAt: Date
        var updatedAt: Date

        @MainActor init(_ row: WeeklyReflectionRecord) {
            weekKey = row.weekKey
            id = row.id
            weekStart = row.weekStart
            weekEnd = row.weekEnd
            timeZoneIdentifier = row.timeZoneIdentifier
            whatHelped = row.whatHelped
            whatGotInTheWay = row.whatGotInTheWay
            createdAt = row.createdAt
            updatedAt = row.updatedAt
        }
    }
    var weeklyReflectionRecords: [WeeklyReflectionRecordRow] = []

    struct HabitConfigurationSnapshotRecordRow: Codable {
        var id: UUID
        var habitID: UUID
        var polarityRaw: String
        var scheduleKindRaw: String
        var scheduleWeekdaysRaw: [Int]
        var scheduleTimesPerWeek: Int?
        var effectiveLocalDateKey: String
        var revision: Int
        var createdAt: Date

        @MainActor init(_ row: HabitConfigurationSnapshotRecord) {
            id = row.id
            habitID = row.habitID
            polarityRaw = row.polarityRaw
            scheduleKindRaw = row.scheduleKindRaw
            scheduleWeekdaysRaw = row.scheduleWeekdaysRaw
            scheduleTimesPerWeek = row.scheduleTimesPerWeek
            effectiveLocalDateKey = row.effectiveLocalDateKey
            revision = row.revision
            createdAt = row.createdAt
        }
    }
    var habitConfigurationSnapshotRecords: [HabitConfigurationSnapshotRecordRow] = []

    struct CompletionRecordRow: Codable {
        var id: UUID
        var habitID: UUID
        var occurredAt: Date
        var localDateKey: String
        var sourceRaw: String
        var note: String?
        var isQuantityDerived: Bool

        @MainActor init(_ row: CompletionRecord) {
            id = row.id
            habitID = row.habitID
            occurredAt = row.occurredAt
            localDateKey = row.localDateKey
            sourceRaw = row.sourceRaw
            note = row.note
            isQuantityDerived = row.isQuantityDerived
        }
    }
    var completionRecords: [CompletionRecordRow] = []

    struct SkipRecordRow: Codable {
        var id: UUID
        var habitID: UUID
        var localDateKey: String
        var reasonRaw: String?
        var createdAt: Date

        @MainActor init(_ row: SkipRecord) {
            id = row.id
            habitID = row.habitID
            localDateKey = row.localDateKey
            reasonRaw = row.reasonRaw
            createdAt = row.createdAt
        }
    }
    var skipRecords: [SkipRecordRow] = []

    struct HabitArchivePeriodRecordRow: Codable {
        var id: UUID
        var habitID: UUID
        var archivedAt: Date
        var reactivatedAt: Date?

        @MainActor init(_ row: HabitArchivePeriodRecord) {
            id = row.id
            habitID = row.habitID
            archivedAt = row.archivedAt
            reactivatedAt = row.reactivatedAt
        }
    }
    var habitArchivePeriodRecords: [HabitArchivePeriodRecordRow] = []

    struct AttentionGoalRecordRow: Codable {
        var id: UUID
        var name: String
        var appOrCategoryLabel: String?
        var typeRaw: String
        var createdAt: Date
        var updatedAt: Date

        @MainActor init(_ row: AttentionGoalRecord) {
            id = row.id
            name = row.name
            appOrCategoryLabel = row.appOrCategoryLabel
            typeRaw = row.typeRaw
            createdAt = row.createdAt
            updatedAt = row.updatedAt
        }
    }
    var attentionGoalRecords: [AttentionGoalRecordRow] = []

    struct AttentionGoalConfigurationSnapshotRecordRow: Codable {
        var id: UUID
        var attentionGoalID: UUID
        var targetValue: Double
        var unitRaw: String
        var effectiveLocalDateKey: String
        var revision: Int
        var createdAt: Date
        var windowStartMinute: Int?
        var windowEndMinute: Int?

        @MainActor init(_ row: AttentionGoalConfigurationSnapshotRecord) {
            id = row.id
            attentionGoalID = row.attentionGoalID
            targetValue = row.targetValue
            unitRaw = row.unitRaw
            effectiveLocalDateKey = row.effectiveLocalDateKey
            revision = row.revision
            createdAt = row.createdAt
            windowStartMinute = row.windowStartMinute
            windowEndMinute = row.windowEndMinute
        }
    }
    var attentionGoalConfigurationSnapshotRecords: [AttentionGoalConfigurationSnapshotRecordRow] = []

    struct AttentionUsageEntryRecordRow: Codable {
        var id: UUID
        var attentionGoalID: UUID
        var amount: Double
        var unitRaw: String
        var recordedAt: Date
        var localDateKey: String
        var sourceRaw: String

        @MainActor init(_ row: AttentionUsageEntryRecord) {
            id = row.id
            attentionGoalID = row.attentionGoalID
            amount = row.amount
            unitRaw = row.unitRaw
            recordedAt = row.recordedAt
            localDateKey = row.localDateKey
            sourceRaw = row.sourceRaw
        }
    }
    var attentionUsageEntryRecords: [AttentionUsageEntryRecordRow] = []

    struct AttentionCheckInRecordRow: Codable {
        var id: UUID
        var attentionGoalID: UUID
        var localDateKey: String
        var windowStart: Date
        var windowEnd: Date
        var outcomeRaw: String
        var recordedAt: Date
        var revision: Int

        @MainActor init(_ row: AttentionCheckInRecord) {
            id = row.id
            attentionGoalID = row.attentionGoalID
            localDateKey = row.localDateKey
            windowStart = row.windowStart
            windowEnd = row.windowEnd
            outcomeRaw = row.outcomeRaw
            recordedAt = row.recordedAt
            revision = row.revision
        }
    }
    var attentionCheckInRecords: [AttentionCheckInRecordRow] = []

    struct AttentionSessionRecordRow: Codable {
        var id: UUID
        var attentionGoalID: UUID
        var startedAt: Date
        var expectedEnd: Date
        var targetMinutes: Double
        var endedAt: Date?
        var outcomeRaw: String?

        @MainActor init(_ row: AttentionSessionRecord) {
            id = row.id
            attentionGoalID = row.attentionGoalID
            startedAt = row.startedAt
            expectedEnd = row.expectedEnd
            targetMinutes = row.targetMinutes
            endedAt = row.endedAt
            outcomeRaw = row.outcomeRaw
        }
    }
    var attentionSessionRecords: [AttentionSessionRecordRow] = []

    struct IntentionSessionLinkRecordRow: Codable {
        var id: UUID
        var habitID: UUID
        var sessionID: UUID
        var createdAt: Date

        @MainActor init(_ row: IntentionSessionLinkRecord) {
            id = row.id
            habitID = row.habitID
            sessionID = row.sessionID
            createdAt = row.createdAt
        }
    }
    var intentionSessionLinkRecords: [IntentionSessionLinkRecordRow] = []

    struct CompanionProfileRecordRow: Codable {
        var profileID: String
        var selectedAnimalRaw: String
        var companionEnabled: Bool
        var hapticsEnabled: Bool
        var onboardingCompleted: Bool

        @MainActor init(_ row: CompanionProfileRecord) {
            profileID = row.profileID
            selectedAnimalRaw = row.selectedAnimalRaw
            companionEnabled = row.companionEnabled
            hapticsEnabled = row.hapticsEnabled
            onboardingCompleted = row.onboardingCompleted
        }
    }
    var companionProfileRecords: [CompanionProfileRecordRow] = []

    struct AppAppearanceRecordRow: Codable {
        var preferencesID: String
        var themeRaw: String

        @MainActor init(_ row: AppAppearanceRecord) {
            preferencesID = row.preferencesID
            themeRaw = row.themeRaw
        }
    }
    var appAppearanceRecords: [AppAppearanceRecordRow] = []

    @MainActor init(context: ModelContext) throws {
        healthHabitConnectionRecords = try context.fetch(FetchDescriptor<HealthHabitConnectionRecord>()).sorted { String(describing: $0.habitID) < String(describing: $1.habitID) }.map(HealthHabitConnectionRecordRow.init)
        habitReminderRecords = try context.fetch(FetchDescriptor<HabitReminderRecord>()).sorted { String(describing: $0.habitID) < String(describing: $1.habitID) }.map(HabitReminderRecordRow.init)
        habitRecords = try context.fetch(FetchDescriptor<HabitRecord>()).sorted { String(describing: $0.id) < String(describing: $1.id) }.map(HabitRecordRow.init)
        habitActivityConfigurationRecords = try context.fetch(FetchDescriptor<HabitActivityConfigurationRecord>()).sorted { String(describing: $0.id) < String(describing: $1.id) }.map(HabitActivityConfigurationRecordRow.init)
        habitActivityEntryRecords = try context.fetch(FetchDescriptor<HabitActivityEntryRecord>()).sorted { String(describing: $0.id) < String(describing: $1.id) }.map(HabitActivityEntryRecordRow.init)
        habitTimerRecords = try context.fetch(FetchDescriptor<HabitTimerRecord>()).sorted { String(describing: $0.habitID) < String(describing: $1.habitID) }.map(HabitTimerRecordRow.init)
        routineRecords = try context.fetch(FetchDescriptor<RoutineRecord>()).sorted { String(describing: $0.id) < String(describing: $1.id) }.map(RoutineRecordRow.init)
        weeklyReflectionRecords = try context.fetch(FetchDescriptor<WeeklyReflectionRecord>()).sorted { String(describing: $0.weekKey) < String(describing: $1.weekKey) }.map(WeeklyReflectionRecordRow.init)
        habitConfigurationSnapshotRecords = try context.fetch(FetchDescriptor<HabitConfigurationSnapshotRecord>()).sorted { String(describing: $0.id) < String(describing: $1.id) }.map(HabitConfigurationSnapshotRecordRow.init)
        completionRecords = try context.fetch(FetchDescriptor<CompletionRecord>()).sorted { String(describing: $0.id) < String(describing: $1.id) }.map(CompletionRecordRow.init)
        skipRecords = try context.fetch(FetchDescriptor<SkipRecord>()).sorted { String(describing: $0.id) < String(describing: $1.id) }.map(SkipRecordRow.init)
        habitArchivePeriodRecords = try context.fetch(FetchDescriptor<HabitArchivePeriodRecord>()).sorted { String(describing: $0.id) < String(describing: $1.id) }.map(HabitArchivePeriodRecordRow.init)
        attentionGoalRecords = try context.fetch(FetchDescriptor<AttentionGoalRecord>()).sorted { String(describing: $0.id) < String(describing: $1.id) }.map(AttentionGoalRecordRow.init)
        attentionGoalConfigurationSnapshotRecords = try context.fetch(FetchDescriptor<AttentionGoalConfigurationSnapshotRecord>()).sorted { String(describing: $0.id) < String(describing: $1.id) }.map(AttentionGoalConfigurationSnapshotRecordRow.init)
        attentionUsageEntryRecords = try context.fetch(FetchDescriptor<AttentionUsageEntryRecord>()).sorted { String(describing: $0.id) < String(describing: $1.id) }.map(AttentionUsageEntryRecordRow.init)
        attentionCheckInRecords = try context.fetch(FetchDescriptor<AttentionCheckInRecord>()).sorted { String(describing: $0.id) < String(describing: $1.id) }.map(AttentionCheckInRecordRow.init)
        attentionSessionRecords = try context.fetch(FetchDescriptor<AttentionSessionRecord>()).sorted { String(describing: $0.id) < String(describing: $1.id) }.map(AttentionSessionRecordRow.init)
        intentionSessionLinkRecords = try context.fetch(FetchDescriptor<IntentionSessionLinkRecord>()).sorted { String(describing: $0.id) < String(describing: $1.id) }.map(IntentionSessionLinkRecordRow.init)
        companionProfileRecords = try context.fetch(FetchDescriptor<CompanionProfileRecord>()).sorted { String(describing: $0.profileID) < String(describing: $1.profileID) }.map(CompanionProfileRecordRow.init)
        appAppearanceRecords = try context.fetch(FetchDescriptor<AppAppearanceRecord>()).sorted { String(describing: $0.preferencesID) < String(describing: $1.preferencesID) }.map(AppAppearanceRecordRow.init)
    }

    var recordCount: Int {
        var count = 0
        count += healthHabitConnectionRecords.count
        count += habitReminderRecords.count
        count += habitRecords.count
        count += habitActivityConfigurationRecords.count
        count += habitActivityEntryRecords.count
        count += habitTimerRecords.count
        count += routineRecords.count
        count += weeklyReflectionRecords.count
        count += habitConfigurationSnapshotRecords.count
        count += completionRecords.count
        count += skipRecords.count
        count += habitArchivePeriodRecords.count
        count += attentionGoalRecords.count
        count += attentionGoalConfigurationSnapshotRecords.count
        count += attentionUsageEntryRecords.count
        count += attentionCheckInRecords.count
        count += attentionSessionRecords.count
        count += intentionSessionLinkRecords.count
        count += companionProfileRecords.count
        count += appAppearanceRecords.count
        return count
    }

    func validateIdentities() throws {
        guard recordCount <= 200_000 else { throw BackupError.invalidFile }
        guard Set(healthHabitConnectionRecords.map(\.habitID)).count == healthHabitConnectionRecords.count else { throw BackupError.invalidFile }
        guard Set(habitReminderRecords.map(\.habitID)).count == habitReminderRecords.count else { throw BackupError.invalidFile }
        guard Set(habitRecords.map(\.id)).count == habitRecords.count else { throw BackupError.invalidFile }
        guard Set(habitActivityConfigurationRecords.map(\.id)).count == habitActivityConfigurationRecords.count else { throw BackupError.invalidFile }
        guard Set(habitActivityEntryRecords.map(\.id)).count == habitActivityEntryRecords.count else { throw BackupError.invalidFile }
        guard Set(habitTimerRecords.map(\.habitID)).count == habitTimerRecords.count else { throw BackupError.invalidFile }
        guard Set(routineRecords.map(\.id)).count == routineRecords.count else { throw BackupError.invalidFile }
        guard Set(weeklyReflectionRecords.map(\.weekKey)).count == weeklyReflectionRecords.count else { throw BackupError.invalidFile }
        guard Set(habitConfigurationSnapshotRecords.map(\.id)).count == habitConfigurationSnapshotRecords.count else { throw BackupError.invalidFile }
        guard Set(completionRecords.map(\.id)).count == completionRecords.count else { throw BackupError.invalidFile }
        guard Set(skipRecords.map(\.id)).count == skipRecords.count else { throw BackupError.invalidFile }
        guard Set(habitArchivePeriodRecords.map(\.id)).count == habitArchivePeriodRecords.count else { throw BackupError.invalidFile }
        guard Set(attentionGoalRecords.map(\.id)).count == attentionGoalRecords.count else { throw BackupError.invalidFile }
        guard Set(attentionGoalConfigurationSnapshotRecords.map(\.id)).count == attentionGoalConfigurationSnapshotRecords.count else { throw BackupError.invalidFile }
        guard Set(attentionUsageEntryRecords.map(\.id)).count == attentionUsageEntryRecords.count else { throw BackupError.invalidFile }
        guard Set(attentionCheckInRecords.map(\.id)).count == attentionCheckInRecords.count else { throw BackupError.invalidFile }
        guard Set(attentionSessionRecords.map(\.id)).count == attentionSessionRecords.count else { throw BackupError.invalidFile }
        guard Set(intentionSessionLinkRecords.map(\.id)).count == intentionSessionLinkRecords.count else { throw BackupError.invalidFile }
        guard Set(intentionSessionLinkRecords.map(\.sessionID)).count == intentionSessionLinkRecords.count else { throw BackupError.invalidFile }
        guard Set(companionProfileRecords.map(\.profileID)).count == companionProfileRecords.count else { throw BackupError.invalidFile }
        guard Set(appAppearanceRecords.map(\.preferencesID)).count == appAppearanceRecords.count else { throw BackupError.invalidFile }
    }

    @MainActor func insert(into context: ModelContext) {
        for row in healthHabitConnectionRecords { context.insert(HealthHabitConnectionRecord(backup: row)) }
        for row in habitReminderRecords { context.insert(HabitReminderRecord(backup: row)) }
        for row in habitRecords { context.insert(HabitRecord(backup: row)) }
        for row in habitActivityConfigurationRecords { context.insert(HabitActivityConfigurationRecord(backup: row)) }
        for row in habitActivityEntryRecords { context.insert(HabitActivityEntryRecord(backup: row)) }
        for row in habitTimerRecords { context.insert(HabitTimerRecord(backup: row)) }
        for row in routineRecords { context.insert(RoutineRecord(backup: row)) }
        for row in weeklyReflectionRecords { context.insert(WeeklyReflectionRecord(backup: row)) }
        for row in habitConfigurationSnapshotRecords { context.insert(HabitConfigurationSnapshotRecord(backup: row)) }
        for row in completionRecords { context.insert(CompletionRecord(backup: row)) }
        for row in skipRecords { context.insert(SkipRecord(backup: row)) }
        for row in habitArchivePeriodRecords { context.insert(HabitArchivePeriodRecord(backup: row)) }
        for row in attentionGoalRecords { context.insert(AttentionGoalRecord(backup: row)) }
        for row in attentionGoalConfigurationSnapshotRecords { context.insert(AttentionGoalConfigurationSnapshotRecord(backup: row)) }
        for row in attentionUsageEntryRecords { context.insert(AttentionUsageEntryRecord(backup: row)) }
        for row in attentionCheckInRecords { context.insert(AttentionCheckInRecord(backup: row)) }
        for row in attentionSessionRecords { context.insert(AttentionSessionRecord(backup: row)) }
        for row in intentionSessionLinkRecords { context.insert(IntentionSessionLinkRecord(backup: row)) }
        for row in companionProfileRecords { context.insert(CompanionProfileRecord(backup: row)) }
        for row in appAppearanceRecords { context.insert(AppAppearanceRecord(backup: row)) }
    }

    @MainActor static func hasTracking(in context: ModelContext) throws -> Bool {
        if try context.fetchCount(FetchDescriptor<HealthHabitConnectionRecord>()) > 0 { return true }
        if try context.fetchCount(FetchDescriptor<HabitReminderRecord>()) > 0 { return true }
        if try context.fetchCount(FetchDescriptor<HabitRecord>()) > 0 { return true }
        if try context.fetchCount(FetchDescriptor<HabitActivityConfigurationRecord>()) > 0 { return true }
        if try context.fetchCount(FetchDescriptor<HabitActivityEntryRecord>()) > 0 { return true }
        if try context.fetchCount(FetchDescriptor<HabitTimerRecord>()) > 0 { return true }
        if try context.fetchCount(FetchDescriptor<RoutineRecord>()) > 0 { return true }
        if try context.fetchCount(FetchDescriptor<WeeklyReflectionRecord>()) > 0 { return true }
        if try context.fetchCount(FetchDescriptor<HabitConfigurationSnapshotRecord>()) > 0 { return true }
        if try context.fetchCount(FetchDescriptor<CompletionRecord>()) > 0 { return true }
        if try context.fetchCount(FetchDescriptor<SkipRecord>()) > 0 { return true }
        if try context.fetchCount(FetchDescriptor<HabitArchivePeriodRecord>()) > 0 { return true }
        if try context.fetchCount(FetchDescriptor<AttentionGoalRecord>()) > 0 { return true }
        if try context.fetchCount(FetchDescriptor<AttentionGoalConfigurationSnapshotRecord>()) > 0 { return true }
        if try context.fetchCount(FetchDescriptor<AttentionUsageEntryRecord>()) > 0 { return true }
        if try context.fetchCount(FetchDescriptor<AttentionCheckInRecord>()) > 0 { return true }
        if try context.fetchCount(FetchDescriptor<AttentionSessionRecord>()) > 0 { return true }
        if try context.fetchCount(FetchDescriptor<IntentionSessionLinkRecord>()) > 0 { return true }
        return false
    }
    func validateScalarValues() throws {
        func validDate(_ date: Date) -> Bool {
            date.timeIntervalSince1970.isFinite && (-2_208_988_800...253_402_300_799).contains(date.timeIntervalSince1970)
        }
        func validDay(_ key: String) -> Bool {
            guard key.count == 10 else { return false }
            let format = DateFormatter()
            format.locale = Locale(identifier: "en_US_POSIX")
            format.calendar = Calendar(identifier: .gregorian)
            format.timeZone = TimeZone(secondsFromGMT: 0)
            format.dateFormat = "yyyy-MM-dd"
            format.isLenient = false
            guard let date = format.date(from: key) else { return false }
            return format.string(from: date) == key
        }
        guard healthHabitConnectionRecords.allSatisfy({ row in
            row.metricRawValue.utf8.count <= 16_384
                && row.target.isFinite
                && validDate(row.connectedAt)
        }) else { throw BackupError.invalidFile }
        guard habitRecords.allSatisfy({ row in
            row.name.utf8.count <= 16_384
                && row.iconName.utf8.count <= 16_384
                && row.categoryRaw.utf8.count <= 16_384
                && row.polarityRaw.utf8.count <= 16_384
                && row.scheduleKindRaw.utf8.count <= 16_384
                && validDate(row.createdAt)
                && validDate(row.updatedAt)
                && (row.archivedAt.map(validDate) ?? true)
        }) else { throw BackupError.invalidFile }
        guard habitActivityConfigurationRecords.allSatisfy({ row in
            validDay(row.effectiveDayKey)
                && (row.unitRaw.map { $0.utf8.count <= 16_384 } ?? true)
                && row.smallerAction.utf8.count <= 16_384
        }) else { throw BackupError.invalidFile }
        guard habitActivityEntryRecords.allSatisfy({ row in
            validDay(row.dayKey)
                && validDate(row.loggedAt)
                && row.kindRaw.utf8.count <= 16_384
                && (row.unitRaw.map { $0.utf8.count <= 16_384 } ?? true)
                && row.actionDescription.utf8.count <= 16_384
        }) else { throw BackupError.invalidFile }
        guard habitTimerRecords.allSatisfy({ row in
            validDay(row.dayKey)
                && (row.startedAt.map(validDate) ?? true)
        }) else { throw BackupError.invalidFile }
        guard routineRecords.allSatisfy({ row in
            row.name.utf8.count <= 16_384
                && validDate(row.createdAt)
                && validDate(row.updatedAt)
        }) else { throw BackupError.invalidFile }
        guard weeklyReflectionRecords.allSatisfy({ row in
            row.weekKey.utf8.count <= 16_384
                && validDate(row.weekStart)
                && validDate(row.weekEnd)
                && row.timeZoneIdentifier.utf8.count <= 16_384
                && row.whatHelped.utf8.count <= 16_384
                && row.whatGotInTheWay.utf8.count <= 16_384
                && validDate(row.createdAt)
                && validDate(row.updatedAt)
        }) else { throw BackupError.invalidFile }
        guard habitConfigurationSnapshotRecords.allSatisfy({ row in
            row.polarityRaw.utf8.count <= 16_384
                && row.scheduleKindRaw.utf8.count <= 16_384
                && validDay(row.effectiveLocalDateKey)
                && validDate(row.createdAt)
        }) else { throw BackupError.invalidFile }
        guard completionRecords.allSatisfy({ row in
            validDate(row.occurredAt)
                && validDay(row.localDateKey)
                && row.sourceRaw.utf8.count <= 16_384
                && (row.note.map { $0.utf8.count <= 16_384 } ?? true)
        }) else { throw BackupError.invalidFile }
        guard skipRecords.allSatisfy({ row in
            validDay(row.localDateKey)
                && (row.reasonRaw.map { $0.utf8.count <= 16_384 } ?? true)
                && validDate(row.createdAt)
        }) else { throw BackupError.invalidFile }
        guard habitArchivePeriodRecords.allSatisfy({ row in
            validDate(row.archivedAt)
                && (row.reactivatedAt.map(validDate) ?? true)
        }) else { throw BackupError.invalidFile }
        guard attentionGoalRecords.allSatisfy({ row in
            row.name.utf8.count <= 16_384
                && (row.appOrCategoryLabel.map { $0.utf8.count <= 16_384 } ?? true)
                && row.typeRaw.utf8.count <= 16_384
                && validDate(row.createdAt)
                && validDate(row.updatedAt)
        }) else { throw BackupError.invalidFile }
        guard attentionGoalConfigurationSnapshotRecords.allSatisfy({ row in
            row.targetValue.isFinite
                && row.unitRaw.utf8.count <= 16_384
                && validDay(row.effectiveLocalDateKey)
                && validDate(row.createdAt)
        }) else { throw BackupError.invalidFile }
        guard attentionUsageEntryRecords.allSatisfy({ row in
            row.amount.isFinite
                && row.unitRaw.utf8.count <= 16_384
                && validDate(row.recordedAt)
                && validDay(row.localDateKey)
                && row.sourceRaw.utf8.count <= 16_384
        }) else { throw BackupError.invalidFile }
        guard attentionCheckInRecords.allSatisfy({ row in
            validDay(row.localDateKey)
                && validDate(row.windowStart)
                && validDate(row.windowEnd)
                && row.outcomeRaw.utf8.count <= 16_384
                && validDate(row.recordedAt)
        }) else { throw BackupError.invalidFile }
        guard attentionSessionRecords.allSatisfy({ row in
            validDate(row.startedAt)
                && validDate(row.expectedEnd)
                && row.targetMinutes.isFinite
                && (row.endedAt.map(validDate) ?? true)
                && (row.outcomeRaw.map { $0.utf8.count <= 16_384 } ?? true)
        }) else { throw BackupError.invalidFile }
        guard intentionSessionLinkRecords.allSatisfy({ row in
            validDate(row.createdAt)
        }) else { throw BackupError.invalidFile }
        guard companionProfileRecords.allSatisfy({ row in
            row.profileID.utf8.count <= 16_384
                && row.selectedAnimalRaw.utf8.count <= 16_384
        }) else { throw BackupError.invalidFile }
        guard appAppearanceRecords.allSatisfy({ row in
            row.preferencesID.utf8.count <= 16_384
                && row.themeRaw.utf8.count <= 16_384
        }) else { throw BackupError.invalidFile }
    }

}
