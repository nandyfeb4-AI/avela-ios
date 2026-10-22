import XCTest
import SwiftData
@testable import Avela

@MainActor final class AppProtectionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_791_387_000)
    private func session(minutes: Double = 20) -> AttentionSession {
        AttentionSession(id: UUID(), attentionGoalID: UUID(), startedAt: now,
            expectedEnd: now.addingTimeInterval(minutes * 60), targetMinutes: minutes, endedAt: nil, outcome: nil)
    }
    private func model(_ driver: Driver, valid: Bool = true) -> AppProtectionModel {
        AppProtectionModel(driver: driver, sessionIsActive: { _ in valid })
    }

    func testDurationBoundsRejectShortNonfiniteAndLongProtectionWithoutChangingTimer() throws {
        for minutes in [Double.nan, .infinity, 0, 14.99, 481] {
            XCTAssertThrowsError(try ProtectionLease.validateDuration(minutes * 60))
        }
        try ProtectionLease.validateDuration(900)
        try ProtectionLease.validateDuration(28800)
    }

    func testPermissionAndSelectionMustPrecedeStart() {
        let driver = Driver(); driver.isAuthorized = false
        let model = model(driver)
        XCTAssertFalse(model.start(session: session(), asOf: now))
        XCTAssertNil(driver.lease); XCTAssertEqual(driver.begins, 0)
        driver.isAuthorized = true; driver.selectionCount = 0
        XCTAssertFalse(model.start(session: session(), asOf: now))
        XCTAssertNil(driver.lease); XCTAssertEqual(driver.begins, 0)
    }

    func testUnavailableDoesNotRequestPermissionOrRestrict() async {
        let driver = Driver(); driver.isAvailable = false
        let model = model(driver)
        await model.authorize()
        XCTAssertEqual(driver.authorizations, 0)
        XCTAssertFalse(model.start(session: session(), asOf: now))
        XCTAssertEqual(driver.begins, 0)
    }

    func testAuthorizationDenialLeavesNormalSessionsAvailable() async {
        let driver = Driver(); driver.failAuthorization = true; driver.isAuthorized = false
        let model = model(driver)
        await model.authorize()
        XCTAssertFalse(model.authorized)
        XCTAssertFalse(model.isRequesting)
        XCTAssertNotNil(model.message)
        XCTAssertNil(driver.lease)
        driver.failAuthorization = false
        await model.authorize()
        XCTAssertTrue(model.authorized)
        XCTAssertFalse(model.isRequesting)
        XCTAssertNil(model.message, "A successful retry cannot retain the earlier denial")
        XCTAssertNil(driver.lease, "Authorization alone must not restrict any apps")
    }

    func testStartCapturesCanonicalSessionWithoutAlteringOutcome() {
        let driver = Driver(); let model = model(driver); let session = session()
        XCTAssertTrue(model.start(session: session, asOf: now))
        XCTAssertEqual(driver.lease?.sessionID, session.id)
        XCTAssertEqual(driver.lease?.endsAt, session.expectedEnd)
        XCTAssertNil(session.outcome); XCTAssertNil(session.endedAt)
        XCTAssertEqual(driver.begins, 1)
    }

    func testStopReleasesProtectionWithoutEndingSession() {
        let driver = Driver(); let model = model(driver); let session = session()
        XCTAssertTrue(model.start(session: session, asOf: now))
        model.stop()
        XCTAssertNil(driver.lease); XCTAssertNil(model.active)
        XCTAssertNil(session.endedAt); XCTAssertTrue(model.message!.contains("unchanged"))
    }

    func testOverlappingStartPreservesExistingProtection() {
        let driver = Driver(); let model = model(driver)
        XCTAssertTrue(model.start(session: session(), asOf: now))
        let original = driver.lease
        XCTAssertFalse(model.start(session: session(), asOf: now))
        XCTAssertEqual(driver.lease, original); XCTAssertEqual(driver.begins, 1)
    }

    func testFailedMonitorRegistrationLeavesSessionUnprotectedAndDisclosesIt() {
        let driver = Driver(); driver.failBegin = true
        let model = model(driver)
        XCTAssertFalse(model.start(session: session(), asOf: now))
        XCTAssertNil(driver.lease); XCTAssertNil(model.active)
        XCTAssertTrue(model.message!.contains("session is saved without app protection"))
    }

    func testExpiryReleasesAtExactDeadlineNeverMarksKept() {
        let driver = Driver(); let model = model(driver); let session = session()
        XCTAssertTrue(model.start(session: session, asOf: now))
        model.refresh(asOf: session.expectedEnd.addingTimeInterval(-1))
        XCTAssertNotNil(model.active)
        model.refresh(asOf: session.expectedEnd)
        XCTAssertNil(model.active); XCTAssertNil(driver.lease); XCTAssertNil(session.outcome)
    }

    func testRevocationReleasesInsteadOfReapplying() {
        let driver = Driver(); let model = model(driver)
        XCTAssertTrue(model.start(session: session(), asOf: now))
        driver.isAuthorized = false; model.refresh(asOf: now)
        XCTAssertNil(model.active); XCTAssertNil(driver.lease)
        XCTAssertEqual(driver.begins, 1)
    }

    func testEndedOrUnavailableSessionReconcilesProtection() {
        let driver = Driver(); var valid = true
        let model = AppProtectionModel(driver: driver, sessionIsActive: { _ in valid })
        XCTAssertTrue(model.start(session: session(), asOf: now))
        valid = false; model.refresh(asOf: now)
        XCTAssertNil(model.active); XCTAssertNil(driver.lease)
    }

    func testClockRollbackAndLateStartCannotExtendProtection() {
        let driver = Driver(); let model = model(driver); let session = session()
        XCTAssertTrue(model.start(session: session, asOf: now))
        model.refresh(asOf: now.addingTimeInterval(-1))
        XCTAssertNil(driver.lease)
        XCTAssertFalse(model.start(session: session, asOf: session.expectedEnd))
        XCTAssertNil(driver.lease)
    }

    func testLeaseSurvivesReopenAndIsExcludedFromBackup() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ProtectionLeaseStore(directory: dir)
        let session = session()
        let lease = ProtectionLease(id: UUID(), sessionID: session.id, goalID: session.attentionGoalID,
            startedAt: now, endsAt: session.expectedEnd)
        try store.update { $0 = lease }
        XCTAssertEqual(try ProtectionLeaseStore(directory: dir).read(), lease)
        let values = try dir.appendingPathComponent("AppProtection").resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)
        try store.update { $0 = nil }
        XCTAssertNil(try store.read())
    }

    func testCorruptLeaseRefusesReadAndCanBeDiscarded() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ProtectionLeaseStore(directory: dir)
        _ = try store.read()
        try Data("corrupt".utf8).write(to: dir.appendingPathComponent("AppProtection/lease.json"))
        XCTAssertThrowsError(try store.read())
        try store.discard()
        XCTAssertNil(try store.read())
    }

    func testOldMonitorCallbackCannotReleaseNewSession() {
        let session = session()
        let lease = ProtectionLease(id: UUID(), sessionID: session.id, goalID: session.attentionGoalID,
            startedAt: now, endsAt: session.expectedEnd)
        XCTAssertFalse(lease.shouldRelease(activityName: "avela.protection.old", intervalEnded: true, at: now))
        XCTAssertFalse(lease.shouldRelease(activityName: lease.activityName, intervalEnded: false, at: now))
        XCTAssertTrue(lease.shouldRelease(activityName: lease.activityName, intervalEnded: true, at: now))
        XCTAssertTrue(lease.shouldRelease(activityName: lease.activityName, intervalEnded: false, at: session.expectedEnd))
    }

    func testMakeRoomRejectsUnpreparedProtectionBeforeSavingAnySession() throws {
        let container = try AppPersistence.makeContainer(inMemory: true)
        let habits = SwiftDataHabitRepository(modelContext: container.mainContext)
        let attention = SwiftDataAttentionRepository(modelContext: container.mainContext)
        let links = SwiftDataIntentionSessionLinkRepository(modelContext: container.mainContext)
        let habit = try habits.createHabit(.init(name: "Read", iconName: "book.fill", category: .learning,
            polarity: .positive, schedule: .daily), at: now)
        let goal = try attention.createGoal(.init(name: "Read time", appOrCategoryLabel: nil,
            type: .focusSession, targetValue: 20, unit: .minutes), at: now)
        let driver = Driver(); driver.selectionCount = 0
        let intention = IntentionSessionViewModel(habitID: habit.id, habits: habits, attention: attention, links: links)
        intention.protection = model(driver); intention.protectsSession = true
        intention.load(asOf: now)
        XCTAssertFalse(intention.start(asOf: now))
        XCTAssertTrue(try attention.sessions(for: goal.id).isEmpty)
        XCTAssertTrue(try links.links(for: habit.id).isEmpty)
        XCTAssertTrue(intention.errorMessage!.contains("Choose"))
        // Turning off the optional integration restores the ordinary session flow.
        intention.protectsSession = false
        XCTAssertTrue(intention.start(asOf: now))
        XCTAssertEqual(try attention.sessions(for: goal.id).count, 1)
        XCTAssertEqual(driver.begins, 0)
        withExtendedLifetime(container) {}
    }

    func testPostSaveProtectionFailureKeepsExactlyOneSessionAndNoHabitCompletion() throws {
        let container = try AppPersistence.makeContainer(inMemory: true)
        let habits = SwiftDataHabitRepository(modelContext: container.mainContext)
        let attention = SwiftDataAttentionRepository(modelContext: container.mainContext)
        let links = SwiftDataIntentionSessionLinkRepository(modelContext: container.mainContext)
        let habit = try habits.createHabit(.init(name: "Read", iconName: "book.fill", category: .learning,
            polarity: .positive, schedule: .daily), at: now)
        let goal = try attention.createGoal(.init(name: "Read time", appOrCategoryLabel: nil,
            type: .focusSession, targetValue: 20, unit: .minutes), at: now)
        let driver = Driver(); driver.failBegin = true
        let protection = model(driver)
        let intention = IntentionSessionViewModel(habitID: habit.id, habits: habits, attention: attention, links: links)
        intention.protection = protection; intention.protectsSession = true
        intention.load(asOf: now)
        XCTAssertTrue(intention.start(asOf: now))
        XCTAssertEqual(try attention.sessions(for: goal.id).count, 1)
        XCTAssertEqual(try links.links(for: habit.id).count, 1)
        XCTAssertNil(driver.lease)
        XCTAssertTrue(protection.message!.contains("without app protection"))
        XCTAssertTrue(try habits.completions(for: habit.id, in: DateInterval(start: now, duration: 86400)).isEmpty)
        XCTAssertFalse(intention.start(asOf: now))
        XCTAssertEqual(try attention.sessions(for: goal.id).count, 1)
        withExtendedLifetime(container) {}
    }

    private final class Driver: AppProtectionDriver {
        var isAvailable = true, isAuthorized = true, selectionCount = 2
        var lease: ProtectionLease?
        var begins = 0, authorizations = 0
        var failBegin = false, failAuthorization = false
        func requestAuthorization() async throws {
            authorizations += 1
            if failAuthorization { throw AppProtectionError.permissionRequired }
            isAuthorized = true
        }
        func readLease() throws -> ProtectionLease? { lease }
        func begin(_ value: ProtectionLease) throws {
            begins += 1
            if failBegin { throw AppProtectionError.storageUnavailable }
            lease = value
        }
        func stop() throws { lease = nil }
        func reconcile(at date: Date, sessionIsActive: (ProtectionLease) throws -> Bool) throws -> ProtectionLease? {
            if let value = lease {
                if try !isAuthorized || !value.isValid(at: date) || !sessionIsActive(value) { lease = nil }
            }
            return lease
        }
    }
}
