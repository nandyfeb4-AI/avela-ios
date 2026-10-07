import SwiftData
import XCTest
@testable import Avela

@MainActor final class HealthHabitServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var habits: SwiftDataHabitRepository!
    private var connections: SwiftDataHealthHabitConnectionRepository!
    private var provider: TestHealthProvider!
    private var service: HealthHabitService!
    private var calendar: Calendar!
    private var date: Date!

    override func setUpWithError() throws {
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 12))!
        container = try AppPersistence.makeContainer(inMemory: true)
        habits = SwiftDataHabitRepository(modelContext: container.mainContext, calendar: calendar)
        connections = SwiftDataHealthHabitConnectionRepository(context: container.mainContext)
        provider = TestHealthProvider()
        let anchor = date!
        service = HealthHabitService(habits: habits, connections: connections, provider: provider,
            calendar: calendar, currentDate: { anchor })
    }
    private var range: DateInterval { calendar.dateInterval(of: .day, for: date)! }
    private func habit(schedule: HabitSchedule = .daily, polarity: HabitPolarity = .positive) throws -> Habit {
        try habits.createHabit(HabitDraft(name: "Walk", iconName: "figure.walk", category: .fitness,
            polarity: polarity, schedule: schedule), at: date)
    }
    private func connect(_ habit: Habit) async throws {
        try await service.connect(habitID: habit.id, metric: .steps, target: 5000, at: date)
    }
    func testRequestsReadOnlyOnExplicitConnectAndImportsAtTargetOnce() async throws {
        let habit = try habit()
        await service.refresh(at: date)
        XCTAssertEqual(provider.requests, 0)
        try await connect(habit)
        XCTAssertEqual(provider.requests, 1)
        provider.value = 5000
        await service.refresh(at: date)
        await service.refresh(at: date)
        let completions = try habits.completions(for: habit.id, in: range)
        XCTAssertEqual(completions.count, 1)
        XCTAssertEqual(completions.first?.source, .healthKit)
    }
    func testMissingDataAndBelowTargetNeverBecomeCompletions() async throws {
        let habit = try habit()
        try await connect(habit)
        await service.refresh(at: date)
        XCTAssertTrue(service.messages[habit.id]?.contains("No accessible Health data") == true)
        for value: Double? in [nil, 0, 4999, .nan, .infinity] {
            provider.value = value
            await service.refresh(at: date)
        }
        XCTAssertTrue(try habits.completions(in: range).isEmpty)
    }
    func testConnectionLoadFailureShowsSafeErrorWithoutQueryingHealth() async {
        let service = HealthHabitService(habits: habits, connections: FailingConnections(),
            provider: provider, calendar: calendar)
        await service.refresh(at: date)
        XCTAssertEqual(service.refreshError, "Your Health connections couldn't be loaded. Manual logging still works.")
        XCTAssertEqual(provider.reads, 0)
    }
    func testImportPreservesManualCompletionAndExcusedSkip() async throws {
        let completed = try habit()
        let skipped = try habit()
        let original = try habits.recordCompletion(habitID: completed.id, at: date, source: .app, note: "Keep")
        try habits.recordSkip(habitID: skipped.id, on: date, reason: .planned)
        try await connect(completed); try await connect(skipped)
        provider.value = 9000
        await service.refresh(at: date)
        XCTAssertEqual(try habits.completions(for: completed.id, in: range), [original])
        XCTAssertTrue(try habits.completions(for: skipped.id, in: range).isEmpty)
        XCTAssertEqual(try habits.skips(for: skipped.id, in: range).count, 1)
    }
    func testArchivedNonDueAndAvoidanceHabitsAreNotImported() async throws {
        let archived = try habit()
        try await connect(archived)
        try habits.archiveHabit(id: archived.id, at: date)
        let monday = try habit(schedule: .weekdays([.monday]))
        try await connect(monday)
        let avoidance = try habit(polarity: .avoidance)
        do { try await connect(avoidance); XCTFail("Avoidance must not auto-complete") } catch {}
        provider.value = 10000
        await service.refresh(at: date)
        XCTAssertTrue(try habits.completions(in: range).isEmpty)
    }
    func testPermissionRequestFailureDoesNotPersistConnection() async throws {
        let habit = try habit()
        provider.failsRequest = true
        do { try await connect(habit); XCTFail("Request must fail") } catch {}
        XCTAssertNil(try service.connection(for: habit.id))
    }
    func testInvalidTargetsAreRejectedBeforePermission() async throws {
        let habit = try habit()
        for target in [0, -1, Double.nan, Double.infinity, 200001] {
            do {
                try await service.connect(habitID: habit.id, metric: .steps, target: target, at: date)
                XCTFail("Invalid target accepted")
            } catch {}
        }
        XCTAssertEqual(provider.requests, 0)
        XCTAssertNil(try service.connection(for: habit.id))
    }
    func testDisconnectDuringReadPreventsStaleImport() async throws {
        let habit = try habit()
        try await connect(habit)
        provider.value = 6000
        provider.onRead = { [connections] in try connections!.disconnect(habitID: habit.id) }
        await service.refresh(at: date)
        XCTAssertTrue(try habits.completions(in: range).isEmpty)
    }
    func testTargetChangeDuringReadPreventsOldTargetImport() async throws {
        let habit = try habit()
        try await connect(habit)
        provider.value = 6000
        let anchor = date!
        provider.onRead = { [connections] in
            try connections!.save(habitID: habit.id, metric: .steps, target: 10000, at: anchor)
        }
        await service.refresh(at: date)
        XCTAssertTrue(try habits.completions(in: range).isEmpty)
        XCTAssertEqual(try service.connection(for: habit.id)?.target, 10000)
    }
    func testDisconnectRetainsImportedHistoryAndStopsFutureReads() async throws {
        let habit = try habit()
        try await connect(habit)
        provider.value = 5000
        await service.refresh(at: date)
        try service.disconnect(habitID: habit.id)
        let count = provider.reads
        await service.refresh(at: date)
        XCTAssertEqual(provider.reads, count)
        XCTAssertEqual(try habits.completions(in: range).count, 1)
    }
    func testExerciseMinutesUseIndependentTargetAndConnectionReloads() async throws {
        let habit = try habit()
        try await service.connect(habitID: habit.id, metric: .exerciseMinutes, target: 30, at: date)
        let reloaded = SwiftDataHealthHabitConnectionRepository(context: ModelContext(container))
        XCTAssertEqual(try reloaded.connections().first?.metric, .exerciseMinutes)
        XCTAssertEqual(try reloaded.connections().first?.target, 30)
        provider.value = 29
        await service.refresh(at: date)
        XCTAssertTrue(try habits.completions(in: range).isEmpty)
        provider.value = 30
        await service.refresh(at: date)
        XCTAssertEqual(try habits.completions(in: range).count, 1)
    }
    func testQueryFinishingAfterLocalMidnightCannotCompleteYesterday() async throws {
        let habit = try habit()
        try await connect(habit)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date!)!
        let service = HealthHabitService(habits: habits, connections: connections,
            provider: provider, calendar: calendar, currentDate: { tomorrow })
        provider.value = 10000
        await service.refresh(at: date)
        XCTAssertTrue(try habits.completions(in: range).isEmpty)
    }

    func testLegacyStoreReopensWithNewOptionalConnectionModelWithoutDataReset() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Migration.store")
        let schema = Schema([HabitReminderRecord.self, HabitRecord.self, HabitConfigurationSnapshotRecord.self,
            CompletionRecord.self, SkipRecord.self, HabitArchivePeriodRecord.self, AttentionGoalRecord.self,
            AttentionGoalConfigurationSnapshotRecord.self, AttentionUsageEntryRecord.self,
            AttentionCheckInRecord.self, AttentionSessionRecord.self, CompanionProfileRecord.self])
        var id: UUID!
        do {
            let old = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)])
            let repository = SwiftDataHabitRepository(modelContext: old.mainContext)
            id = try repository.createHabit(HabitDraft(name: "Preserve", iconName: "book.fill", category: .learning,
                polarity: .positive, schedule: .daily), at: date).id
        }
        let reopened = try AppPersistence.makeContainer(storeURL: url)
        XCTAssertEqual(try SwiftDataHabitRepository(modelContext: reopened.mainContext).fetchHabit(id: id)?.name, "Preserve")
        XCTAssertTrue(try SwiftDataHealthHabitConnectionRepository(context: reopened.mainContext).connections().isEmpty)
    }
}

@MainActor private struct FailingConnections: HealthHabitConnectionRepository {
    func connections() throws -> [HealthHabitConnection] { throw HealthHabitError.unavailable }
    func save(habitID: UUID, metric: HealthHabitMetric, target: Double, at date: Date) throws {
        throw HealthHabitError.unavailable
    }
    func disconnect(habitID: UUID) throws { throw HealthHabitError.unavailable }
}

@MainActor private final class TestHealthProvider: HealthHabitProvider {
    var isAvailable = true
    var value: Double?
    var requests = 0
    var reads = 0
    var failsRequest = false
    var onRead: (() throws -> Void)?
    func requestReadAccess(for metric: HealthHabitMetric) async throws {
        requests += 1
        if failsRequest { throw HealthHabitError.unavailable }
    }
    func total(for metric: HealthHabitMetric, in interval: DateInterval) async throws -> Double? {
        reads += 1
        try onRead?()
        return value
    }
}
