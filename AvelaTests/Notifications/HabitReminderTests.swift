import XCTest
import SwiftData
@testable import Avela

@MainActor
final class HabitReminderTests: XCTestCase {
    func testWeekdayRequestsHaveStableIDsAndLocalClockComponents() {
        let habit = makeHabit(schedule: .weekdays([.monday, .friday]))
        let setting = HabitReminder(habitID: habit.id, isEnabled: true, hour: 18, minute: 30)
        let requests = HabitReminderPlanner.requests(for: habit, reminder: setting)
        XCTAssertEqual(requests.map(\.weekday), [2, 6])
        XCTAssertTrue(requests.allSatisfy { $0.hour == 18 && $0.minute == 30 })
        XCTAssertEqual(requests, HabitReminderPlanner.requests(for: habit, reminder: setting))
        XCTAssertEqual(Set(requests.map(\.identifier)).count, 2)
    }

    func testFlexibleWeeklyReminderDoesNotAssignWeekdays() {
        let habit = makeHabit(schedule: .timesPerWeek(3))
        let requests = HabitReminderPlanner.requests(for: habit, reminder: HabitReminder(habitID: habit.id, isEnabled: true, hour: 9, minute: 0))
        XCTAssertEqual(requests.count, 1)
        XCTAssertNil(requests.first?.weekday)
    }

    func testArchivedDisabledAndInvalidRemindersProduceNoRequests() {
        var habit = makeHabit(schedule: .daily)
        let setting = HabitReminder(habitID: habit.id, isEnabled: true, hour: 9, minute: 0)
        habit.archivedAt = Date()
        XCTAssertTrue(HabitReminderPlanner.requests(for: habit, reminder: setting).isEmpty)
        habit.archivedAt = nil
        XCTAssertTrue(HabitReminderPlanner.requests(for: habit, reminder: HabitReminder(habitID: habit.id, isEnabled: false, hour: 9, minute: 0)).isEmpty)
        XCTAssertTrue(HabitReminderPlanner.requests(for: habit, reminder: HabitReminder(habitID: habit.id, isEnabled: true, hour: 24, minute: 0)).isEmpty)
    }

    func testPermissionRequestedOnlyOnExplicitEnablementAndNeverAgainAfterDenial() async throws {
        let fixture = try Fixture()
        try await fixture.service.synchronize()
        XCTAssertEqual(fixture.adapter.permissionRequests, 0)
        _ = try await fixture.service.setReminder(HabitReminder(habitID: fixture.habit.id, isEnabled: false, hour: 9, minute: 0))
        XCTAssertEqual(fixture.adapter.permissionRequests, 0)
        fixture.adapter.requestResult = .denied
        let result = try await fixture.service.setReminder(HabitReminder(habitID: fixture.habit.id, isEnabled: true, hour: 9, minute: 0))
        XCTAssertEqual(result, .denied)
        XCTAssertEqual(fixture.adapter.permissionRequests, 1)
        XCTAssertTrue(fixture.adapter.requests.isEmpty)
        XCTAssertEqual(try fixture.reminders.reminder(for: fixture.habit.id)?.isEnabled, true)
        _ = try await fixture.service.setReminder(HabitReminder(habitID: fixture.habit.id, isEnabled: true, hour: 10, minute: 0))
        XCTAssertEqual(fixture.adapter.permissionRequests, 1)
        fixture.adapter.status = .authorized
        try await fixture.service.synchronize()
        XCTAssertEqual(fixture.adapter.requests.first?.hour, 10)
        XCTAssertEqual(fixture.adapter.permissionRequests, 1)
    }

    func testArchiveCancelsAndReactivationRestoresSavedPreference() async throws {
        let fixture = try Fixture()
        fixture.adapter.status = .authorized
        _ = try await fixture.service.setReminder(HabitReminder(habitID: fixture.habit.id, isEnabled: true, hour: 20, minute: 15))
        XCTAssertEqual(fixture.adapter.requests.count, 1)
        try fixture.habits.archiveHabit(id: fixture.habit.id, at: Date())
        fixture.service.cancel(for: fixture.habit.id)
        try await fixture.service.synchronize()
        XCTAssertTrue(fixture.adapter.requests.isEmpty)
        XCTAssertEqual(try fixture.reminders.reminder(for: fixture.habit.id)?.isEnabled, true)
        try fixture.habits.reactivateHabit(id: fixture.habit.id, at: Date())
        try await fixture.service.synchronize()
        XCTAssertEqual(fixture.adapter.requests.first?.hour, 20)
    }

    func testArchiveDuringInFlightReplacementDoesNotRestoreCancelledReminder() async throws {
        let fixture = try Fixture()
        fixture.adapter.status = .authorized
        try fixture.reminders.save(HabitReminder(habitID: fixture.habit.id, isEnabled: true, hour: 20, minute: 15))
        let replacementStarted = expectation(description: "Platform replacement suspended with pre-archive plan")
        fixture.adapter.holdNextReplacement = true
        fixture.adapter.onReplacementSuspended = { replacementStarted.fulfill() }
        let reconciliation = Task { try await fixture.service.synchronize() }
        await fulfillment(of: [replacementStarted], timeout: 2)

        // The adapter has captured the active habit's plan but has not added it.
        // Archive and cancellation interleave at that real suspension point.
        try fixture.habits.archiveHabit(id: fixture.habit.id, at: Date())
        fixture.service.cancel(for: fixture.habit.id)
        fixture.adapter.resumeReplacement()
        try await reconciliation.value

        XCTAssertTrue(fixture.adapter.requests.isEmpty)
        XCTAssertEqual(fixture.adapter.replacementCalls, 2, "Reconcile the stale plan against the newly archived habit")
        XCTAssertEqual(fixture.adapter.permissionRequests, 0)
        XCTAssertEqual(try fixture.reminders.reminder(for: fixture.habit.id)?.isEnabled, true)
    }

    func testScheduleEditReplacesRequestsAndDisableRemovesThem() async throws {
        let fixture = try Fixture()
        fixture.adapter.status = .authorized
        _ = try await fixture.service.setReminder(HabitReminder(habitID: fixture.habit.id, isEnabled: true, hour: 7, minute: 45))
        var draft = fixture.draft
        draft.schedule = .weekdays([.tuesday, .thursday])
        try fixture.habits.updateHabit(id: fixture.habit.id, with: draft, at: Date())
        try await fixture.service.synchronize()
        XCTAssertEqual(fixture.adapter.requests.map(\.weekday), [3, 5])
        _ = try await fixture.service.setReminder(HabitReminder(habitID: fixture.habit.id, isEnabled: false, hour: 7, minute: 45))
        XCTAssertTrue(fixture.adapter.requests.isEmpty)
    }

    func testInvalidTimeDoesNotPersistOrAskPermission() async throws {
        let fixture = try Fixture()
        do {
            _ = try await fixture.service.setReminder(HabitReminder(habitID: fixture.habit.id, isEnabled: true, hour: 10, minute: 60))
            XCTFail("Invalid reminder should fail")
        } catch {
            XCTAssertEqual(error as? ReminderError, .invalidTime)
        }
        XCTAssertNil(try fixture.reminders.reminder(for: fixture.habit.id))
        XCTAssertEqual(fixture.adapter.permissionRequests, 0)
    }

    func testReminderPersistsAcrossDiskStoreReopeningAndUpdateDoesNotDuplicate() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let schema = Schema([HabitReminderRecord.self])
        let configuration = ModelConfiguration(schema: schema, url: directory.appendingPathComponent("reminders.store"), cloudKitDatabase: .none)
        let id = UUID()
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let repository = SwiftDataHabitReminderRepository(modelContext: container.mainContext)
            try repository.save(HabitReminder(habitID: id, isEnabled: true, hour: 8, minute: 0))
            try repository.save(HabitReminder(habitID: id, isEnabled: true, hour: 9, minute: 30))
            XCTAssertEqual(try repository.allReminders().count, 1)
        }
        let reopened = try ModelContainer(for: schema, configurations: [configuration])
        let repository = SwiftDataHabitReminderRepository(modelContext: reopened.mainContext)
        XCTAssertEqual(try repository.reminder(for: id), HabitReminder(habitID: id, isEnabled: true, hour: 9, minute: 30))
    }

    private func makeHabit(schedule: HabitSchedule) -> Habit {
        Habit(id: UUID(), name: "Read", iconName: "book.fill", category: .learning, polarity: .positive,
              schedule: schedule, createdAt: Date(), updatedAt: Date(), archivedAt: nil, sortOrder: 0)
    }

    @MainActor
    private final class Fixture {
        let container: ModelContainer
        let habits: SwiftDataHabitRepository
        let reminders: SwiftDataHabitReminderRepository
        let adapter = FakeAdapter()
        let service: HabitReminderService
        let habit: Habit
        let draft = HabitDraft(name: "Read", iconName: "book.fill", category: .learning, polarity: .positive, schedule: .daily)

        init() throws {
            let schema = Schema([HabitRecord.self, HabitConfigurationSnapshotRecord.self, CompletionRecord.self,
                                 SkipRecord.self, HabitArchivePeriodRecord.self, HabitReminderRecord.self])
            container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
            habits = SwiftDataHabitRepository(modelContext: container.mainContext)
            reminders = SwiftDataHabitReminderRepository(modelContext: container.mainContext)
            habit = try habits.createHabit(draft, at: Date())
            service = HabitReminderService(habits: habits, reminders: reminders, adapter: adapter)
        }
    }

    @MainActor
    private final class FakeAdapter: HabitNotificationAdapter {
        var status: ReminderPermission = .notDetermined
        var requestResult: ReminderPermission = .authorized
        var permissionRequests = 0
        var requests: [HabitReminderRequest] = []
        var holdNextReplacement = false
        var onReplacementSuspended: (() -> Void)?
        var replacementCalls = 0
        private var replacementContinuation: CheckedContinuation<Void, Never>?
        func permission() async -> ReminderPermission { status }
        func requestPermission() async throws -> ReminderPermission {
            permissionRequests += 1
            status = requestResult
            return status
        }
        func replaceHabitReminders(with requests: [HabitReminderRequest]) async throws {
            replacementCalls += 1
            if holdNextReplacement {
                holdNextReplacement = false
                await withCheckedContinuation { continuation in
                    replacementContinuation = continuation
                    onReplacementSuspended?()
                }
            }
            self.requests = requests
        }
        func resumeReplacement() {
            replacementContinuation?.resume()
            replacementContinuation = nil
        }
        func cancelHabitReminder(habitID: UUID) { requests.removeAll { $0.habitID == habitID } }
    }
}
