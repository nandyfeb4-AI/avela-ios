import XCTest
import SwiftData
@testable import Avela

@MainActor final class CloudBackupTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/Denver")!
        return c
    }
    private func date(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 12))!
    }
    private func seed(_ store: ModelContainer, category: HabitCategory = .learning) throws -> Habit {
        let habits = SwiftDataHabitRepository(modelContext: store.mainContext, calendar: calendar)
        let habit = try habits.createHabit(.init(name: "Read", iconName: "book.fill", category: category,
            polarity: .positive, schedule: .daily), at: date(1))
        try habits.recordCompletion(habitID: habit.id, at: date(1), source: .app, note: "Private note")
        try habits.recordSkip(habitID: habit.id, on: date(2), reason: .planned)
        try habits.archiveHabit(id: habit.id, at: date(3))
        try habits.reactivateHabit(id: habit.id, at: date(4))
        return try XCTUnwrap(habits.fetchHabit(id: habit.id))
    }
    private func defaults() -> UserDefaults {
        let name = "CloudBackupTests." + UUID().uuidString
        let value = UserDefaults(suiteName: name)!
        addTeardownBlock { value.removePersistentDomain(forName: name) }
        return value
    }
    func testRestorePreservesIDsDatesScheduleHistoryAndProgressOnDisk() throws {
        let source = try AppPersistence.makeContainer(inMemory: true)
        let habit = try seed(source)
        let archive = try BackupStore(context: source.mainContext).capture(at: date(5))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("restored.store")
        var restoredCompletionID: UUID!
        do {
            let target = try AppPersistence.makeContainer(storeURL: url)
            try BackupStore(context: target.mainContext).restore(archive)
            let original = SwiftDataHabitRepository(modelContext: source.mainContext, calendar: calendar)
            let restored = SwiftDataHabitRepository(modelContext: target.mainContext, calendar: calendar)
            XCTAssertEqual(try restored.fetchHabit(id: habit.id), habit)
            XCTAssertEqual(try restored.configurationHistory(for: habit.id), try original.configurationHistory(for: habit.id))
            XCTAssertEqual(try restored.archivePeriods(for: habit.id), try original.archivePeriods(for: habit.id))
            XCTAssertEqual(try restored.skips(for: habit.id, in: DateInterval(start: .distantPast, end: .distantFuture)), try original.skips(for: habit.id, in: DateInterval(start: .distantPast, end: .distantFuture)))
            let completion = try XCTUnwrap(restored.completions(for: habit.id, in: DateInterval(start: .distantPast, end: .distantFuture)).first)
            restoredCompletionID = completion.id
            XCTAssertEqual(completion.localDateKey, "2026-10-01")
            XCTAssertNil(completion.note)
        }
        let reopened = try AppPersistence.makeContainer(storeURL: url)
        let rows = try SwiftDataHabitRepository(modelContext: reopened.mainContext).completions(for: habit.id, in: DateInterval(start: .distantPast, end: .distantFuture))
        XCTAssertEqual(rows.first?.id, restoredCompletionID)
    }
    func testExistingProgressAndRepeatRestoreAreNeverOverwritten() throws {
        let source = try AppPersistence.makeContainer(inMemory: true)
        _ = try seed(source)
        let archive = try BackupStore(context: source.mainContext).capture(at: date(5))
        let target = try AppPersistence.makeContainer(inMemory: true)
        let existing = try seed(target)
        XCTAssertThrowsError(try BackupStore(context: target.mainContext).restore(archive)) {
            XCTAssertEqual($0 as? BackupError, .existingHistory)
        }
        XCTAssertEqual(try target.mainContext.fetchCount(FetchDescriptor<HabitRecord>()), 1)
        XCTAssertEqual(try target.mainContext.fetch(FetchDescriptor<HabitRecord>()).first?.id, existing.id)
        let fresh = try AppPersistence.makeContainer(inMemory: true)
        let store = BackupStore(context: fresh.mainContext)
        try store.restore(archive)
        XCTAssertThrowsError(try store.restore(archive))
        XCTAssertEqual(try fresh.mainContext.fetchCount(FetchDescriptor<HabitRecord>()), 1)
    }
    func testHealthHabitsImportedHistoryAndPrivateNotesCannotReachCloud() throws {
        let source = try AppPersistence.makeContainer(inMemory: true)
        let healthy = try seed(source, category: .fitness)
        let habits = SwiftDataHabitRepository(modelContext: source.mainContext, calendar: calendar)
        let imported = try habits.createHabit(.init(name: "Steps", iconName: "figure.walk", category: .other,
            polarity: .positive, schedule: .daily), at: date(1))
        try habits.recordCompletion(habitID: imported.id, at: date(1), source: .healthKit, note: nil)
        try SwiftDataReflectionRepository(context: source.mainContext).save(.init(whatHelped: "Private health note"),
            for: .containing(date(5), calendar: calendar), at: date(5))
        let connected = try habits.createHabit(.init(name: "Connected", iconName: "figure.walk", category: .other,
            polarity: .positive, schedule: .daily), at: date(1))
        try SwiftDataHealthHabitConnectionRepository(context: source.mainContext).save(habitID: connected.id, metric: .steps, target: 1000, at: date(1))
        let retained = try seed(source)
        let archive = try BackupStore(context: source.mainContext).capture(at: date(5))
        let payload = try archive.verifiedPayload()
        XCTAssertEqual(archive.excludedHealthHabitCount, 3)
        XCTAssertEqual(payload.habitRecords.map(\.id), [retained.id])
        XCTAssertTrue(payload.healthHabitConnectionRecords.isEmpty)
        XCTAssertTrue(payload.weeklyReflectionRecords.isEmpty)
        XCTAssertTrue(payload.completionRecords.allSatisfy { $0.habitID == retained.id && $0.note == nil })
        XCTAssertEqual(try habits.fetchHabits(includeArchived: true).count, 4)
        XCTAssertNotNil(try habits.fetchHabit(id: healthy.id))
        // Even a checksum-valid CloudKit archive cannot smuggle Health data.
        let unsafe = try BackupPayload(context: source.mainContext)
        XCTAssertThrowsError(try BackupArchive.make(payload: unsafe, excluded: 0, at: date(5)))
    }
    func testCorruptionVersionDuplicatesAndDanglingReferencesAreRejectedBeforeWrites() throws {
        let source = try AppPersistence.makeContainer(inMemory: true)
        _ = try seed(source)
        let archive = try BackupStore(context: source.mainContext).capture(at: date(5))
        let corrupt = BackupArchive(version: 1, id: archive.id, createdAt: archive.createdAt,
            excludedHealthHabitCount: 0, payload: Data("bad".utf8), checksum: archive.checksum)
        XCTAssertThrowsError(try corrupt.verifiedPayload())
        let newer = BackupArchive(version: 2, id: archive.id, createdAt: archive.createdAt,
            excludedHealthHabitCount: 0, payload: archive.payload, checksum: archive.checksum)
        XCTAssertThrowsError(try newer.verifiedPayload()) { XCTAssertEqual($0 as? BackupError, .unsupportedVersion) }
        var rows = try archive.verifiedPayload()
        rows.completionRecords.append(rows.completionRecords[0])
        XCTAssertThrowsError(try rows.validate())
        rows = try archive.verifiedPayload()
        rows.completionRecords[0].habitID = UUID()
        XCTAssertThrowsError(try rows.validate())
        let target = try AppPersistence.makeContainer(inMemory: true)
        XCTAssertThrowsError(try BackupStore(context: target.mainContext).restore(corrupt))
        XCTAssertEqual(try target.mainContext.fetchCount(FetchDescriptor<HabitRecord>()), 0)
    }
    func testUnsavedWorkIsNeitherCommittedNorOverwritten() throws {
        let source = try AppPersistence.makeContainer(inMemory: true)
        _ = try seed(source)
        let store = BackupStore(context: source.mainContext)
        let archive = try store.capture(at: date(5))
        source.mainContext.insert(AppAppearanceRecord(theme: .indigo))
        XCTAssertThrowsError(try store.capture()) { XCTAssertEqual($0 as? BackupError, .unsavedChanges) }
        XCTAssertThrowsError(try store.restore(archive)) { XCTAssertEqual($0 as? BackupError, .unsavedChanges) }
        XCTAssertTrue(source.mainContext.hasChanges)
    }
    func testEnableUploadFailureAndAccountChangeNeverClaimProtection() async throws {
        let source = try AppPersistence.makeContainer(inMemory: true)
        _ = try seed(source)
        let provider = FakeBackupProvider()
        let settings = defaults()
        let model = CloudBackupModel(store: BackupStore(context: source.mainContext), provider: provider, defaults: settings)
        await model.backupNow()
        XCTAssertEqual(provider.uploads.count, 0)
        await model.setEnabled(true)
        provider.fail = true
        await model.backupNow(at: date(5))
        XCTAssertNil(model.lastSuccessfulBackup)
        provider.fail = false
        await model.backupNow(at: date(5))
        XCTAssertEqual(model.lastSuccessfulBackup, date(5))
        XCTAssertEqual(provider.uploads.count, 1)
        provider.identity = "other-account"
        await model.backupNow(at: date(6))
        XCTAssertFalse(model.isEnabled)
        XCTAssertNil(model.lastSuccessfulBackup)
        XCTAssertEqual(provider.uploads.count, 1)
        model.disable()
    }
    func testRestorePreviewCancelConfirmationAndDeletionAreExplicit() async throws {
        let source = try AppPersistence.makeContainer(inMemory: true)
        let habit = try seed(source)
        let archive = try BackupStore(context: source.mainContext).capture(at: date(5))
        let target = try AppPersistence.makeContainer(inMemory: true)
        let provider = FakeBackupProvider(); provider.uploads = [archive]
        let model = CloudBackupModel(store: BackupStore(context: target.mainContext), provider: provider, defaults: defaults())
        await model.loadBackups()
        let summary = try XCTUnwrap(model.backups.first)
        await model.prepareRestore(summary)
        XCTAssertEqual(model.previewHabitCount, 1)
        XCTAssertEqual(try target.mainContext.fetchCount(FetchDescriptor<HabitRecord>()), 0)
        model.cancelRestore()
        model.confirmRestore()
        XCTAssertEqual(try target.mainContext.fetchCount(FetchDescriptor<HabitRecord>()), 0)
        await model.prepareRestore(summary)
        model.confirmRestore()
        XCTAssertEqual(try target.mainContext.fetch(FetchDescriptor<HabitRecord>()).first?.id, habit.id)
        await model.deleteBackup(summary)
        XCTAssertTrue(provider.uploads.isEmpty)
        XCTAssertEqual(try target.mainContext.fetchCount(FetchDescriptor<HabitRecord>()), 1)
    }
    func testRecoveryPreservesAttentionRoutinesAndActivityWithoutRestartingSideEffects() throws {
        let source = try AppPersistence.makeContainer(inMemory: true)
        let habit = try seed(source)
        let context = source.mainContext
        let habits = SwiftDataHabitRepository(modelContext: context, calendar: calendar)
        let activity = SwiftDataHabitActivityRepository(context: context, habits: habits, calendar: calendar)
        try activity.configure(habitID: habit.id, target: .init(amount: 20, unit: .minutes), smallerAction: "Read one page", at: date(5))
        let configuration = try XCTUnwrap(activity.configuration(for: habit.id, on: date(5)))
        try activity.log(habitID: habit.id, kind: .quantity, amount: 5, expectedConfigurationID: configuration.id, on: date(5), now: date(5))
        try activity.saveTimer(.init(habitID: habit.id, dayKey: "2026-10-05", startedAt: date(5), elapsedSeconds: 120), now: date(5))
        let routine = try SwiftDataRoutineRepository(modelContext: context, habits: habits).save(id: nil, name: "Evening", habitIDs: [habit.id], restartDays: 3, at: date(5))
        let attention = SwiftDataAttentionRepository(modelContext: context, calendar: calendar)
        let budget = try attention.createGoal(.init(name: "Social", type: .maxDurationPerDay, targetValue: 30, unit: .minutes), at: date(1))
        let usage = try attention.recordUsage(goalID: budget.id, amount: 5, at: date(5), source: .manual)
        let window = try attention.createGoal(.init(name: "Morning", type: .noUseBeforeTime, targetValue: 60, unit: .minutes, windowStartMinute: 480, windowEndMinute: 540), at: date(1))
        let checkIn = try attention.recordCheckIn(goalID: window.id, on: date(5), outcome: .kept, at: date(5))
        let sessionGoal = try attention.createGoal(.init(name: "Focus", type: .phoneFreeSession, targetValue: 30, unit: .minutes), at: date(1))
        let session = try attention.startSession(goalID: sessionGoal.id, at: date(5))
        context.insert(IntentionSessionLinkRecord(.init(id: UUID(), habitID: habit.id, sessionID: session.id, createdAt: date(5))))
        context.insert(HabitReminderRecord(.init(habitID: habit.id, isEnabled: true, hour: 18, minute: 15)))
        try context.save()
        try SwiftDataAppearanceRepository(context: context).save(theme: .plum)
        try SwiftDataCompanionProfileRepository(modelContext: context).save(.init(selectedAnimal: .otter, onboardingCompleted: true))
        let captureDate = date(5).addingTimeInterval(300)
        let archive = try BackupStore(context: context).capture(at: captureDate)
        let target = try AppPersistence.makeContainer(inMemory: true)
        try BackupStore(context: target.mainContext).restore(archive)
        let recovered = try BackupStore(context: target.mainContext).capture(at: captureDate).verifiedPayload()
        var expected = try archive.verifiedPayload()
        expected.habitReminderRecords[0].isEnabled = false
        expected.habitTimerRecords[0].startedAt = nil
        expected.habitTimerRecords[0].elapsedSeconds = 420
        expected.attentionSessionRecords[0].endedAt = captureDate
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        XCTAssertEqual(try encoder.encode(expected), try encoder.encode(recovered))
        XCTAssertEqual(recovered.routineRecords.first?.id, routine.id)
        XCTAssertEqual(recovered.attentionUsageEntryRecords.first?.id, usage.id)
        XCTAssertEqual(recovered.attentionCheckInRecords.first?.id, checkIn.id)
        XCTAssertNil(recovered.attentionSessionRecords.first?.outcomeRaw)
    }

    func testMalformedDateAndCrossHabitActivityReferencesAreRejected() throws {
        let source = try AppPersistence.makeContainer(inMemory: true)
        let habit = try seed(source)
        let habits = SwiftDataHabitRepository(modelContext: source.mainContext, calendar: calendar)
        let other = try habits.createHabit(.init(name: "Write", iconName: "pencil", category: .learning, polarity: .positive, schedule: .daily), at: date(1))
        let activity = SwiftDataHabitActivityRepository(context: source.mainContext, habits: habits, calendar: calendar)
        try activity.configure(habitID: habit.id, target: .init(amount: 10, unit: .pages), smallerAction: "", at: date(5))
        let config = try XCTUnwrap(activity.configuration(for: habit.id, on: date(5)))
        try activity.log(habitID: habit.id, kind: .quantity, amount: 1, expectedConfigurationID: config.id, on: date(5), now: date(5))
        let archive = try BackupStore(context: source.mainContext).capture(at: date(5))
        var payload = try archive.verifiedPayload()
        payload.completionRecords[0].localDateKey = "2026-02-30"
        XCTAssertThrowsError(try payload.validate())
        payload = try archive.verifiedPayload()
        payload.habitActivityEntryRecords[0].habitID = other.id
        XCTAssertThrowsError(try payload.validate())
        let invalidDate = BackupArchive(version: 1, id: archive.id, createdAt: Date(timeIntervalSince1970: 253_402_300_800), excludedHealthHabitCount: 0, payload: archive.payload, checksum: archive.checksum)
        XCTAssertThrowsError(try invalidDate.verifiedPayload())
    }

    func testPlaceholderContainerNeverInitializesCloudKit() {
        XCTAssertFalse(CloudKitBackupProvider(identifier: nil).isConfigured)
        XCTAssertFalse(CloudKitBackupProvider(identifier: "iCloud.com.example.Avela").isConfigured)
        XCTAssertFalse(CloudKitBackupProvider(identifier: "$(AVELA_CLOUD_BACKUP_CONTAINER)").isConfigured)
    }
}

@MainActor private final class FakeBackupProvider: CloudBackupProvider {
    var isConfigured = true
    var identity = "account-one"
    var fail = false
    var uploads: [BackupArchive] = []
    func accountIdentity() async throws -> String {
        if fail { throw BackupError.unavailable }
        return identity
    }
    func upload(_ archive: BackupArchive, deviceID: String) async throws {
        if fail { throw BackupError.unavailable }; uploads.append(archive)
    }
    func list() async throws -> [CloudBackupSummary] { uploads.map { .init(id: $0.id.uuidString, createdAt: $0.createdAt) } }
    func download(id: String) async throws -> BackupArchive {
        guard let row = uploads.first(where: { $0.id.uuidString == id }) else { throw BackupError.invalidFile }
        return row
    }
    func delete(id: String) async throws { uploads.removeAll { $0.id.uuidString == id } }
}
