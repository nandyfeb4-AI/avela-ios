import XCTest
import SwiftData
@testable import Avela

@MainActor
final class SessionLiveActivityServiceTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_780_000_000)

    func testExplicitRequestUsesPersistedSessionAndDuplicateDoesNotRequestAgain() throws {
        let fixture = try Fixture()
        let (_, session) = try fixture.startSession(at: start)
        let service = fixture.service()
        try service.show(sessionID: session.id, at: start)
        try service.show(sessionID: session.id, at: start.addingTimeInterval(10))
        XCTAssertEqual(fixture.adapter.requests, [Fixture.descriptor(session)])
        XCTAssertEqual(try fixture.repository.sessions(for: session.attentionGoalID), [session])
    }

    func testDisabledPresentationDoesNotEndSession() throws {
        let fixture = try Fixture()
        let (goal, session) = try fixture.startSession(at: start)
        fixture.adapter.areEnabled = false
        XCTAssertThrowsError(try fixture.service().show(sessionID: session.id, at: start)) {
            guard case SessionLiveActivityError.disabled = $0 else { return XCTFail("Unexpected error: \($0)") }
        }
        XCTAssertTrue(fixture.adapter.requests.isEmpty)
        XCTAssertEqual(try fixture.repository.sessions(for: goal.id), [session])
    }

    func testRequestFailurePreservesSessionAndExistingPresentation() async throws {
        let fixture = try Fixture()
        let (_, previous) = try fixture.startSession(at: start)
        let (_, requested) = try fixture.startSession(at: start, name: "Second")
        fixture.adapter.activities = [Fixture.descriptor(previous)]
        fixture.adapter.failRequest = true
        let service = fixture.service()
        XCTAssertThrowsError(try service.show(sessionID: requested.id, at: start))
        await service.synchronize(asOf: start)
        XCTAssertEqual(fixture.adapter.activities.map(\.sessionID), [previous.id])
        XCTAssertTrue(fixture.adapter.ended.isEmpty)
        XCTAssertEqual(try fixture.repository.sessions(for: requested.attentionGoalID), [requested])
    }

    func testForegroundReconciliationNeverStartsAnActivity() async throws {
        let fixture = try Fixture()
        _ = try fixture.startSession(at: start)
        await fixture.service().synchronize(asOf: start)
        XCTAssertTrue(fixture.adapter.requests.isEmpty)
        XCTAssertTrue(fixture.adapter.activities.isEmpty)
    }

    func testNewServiceReconcilesExistingActivityAfterRelaunchWithoutRequest() async throws {
        let fixture = try Fixture()
        let (_, session) = try fixture.startSession(at: start)
        fixture.adapter.activities = [Fixture.descriptor(session, animal: nil)]
        await fixture.service().synchronize(asOf: start.addingTimeInterval(5))
        XCTAssertEqual(fixture.adapter.updates, [Fixture.descriptor(session)])
        XCTAssertTrue(fixture.adapter.requests.isEmpty)
        XCTAssertTrue(fixture.adapter.ended.isEmpty)
    }

    func testExpiredActivityEndsWithoutInventingKeptOutcome() async throws {
        let fixture = try Fixture()
        let (_, session) = try fixture.startSession(at: start)
        let service = fixture.service()
        try service.show(sessionID: session.id, at: start)
        await service.synchronize(asOf: session.expectedEnd)
        XCTAssertEqual(fixture.adapter.ended, [session.id])
        XCTAssertEqual(try fixture.repository.sessions(for: session.attentionGoalID), [session])
        XCTAssertNil(try fixture.repository.sessions(for: session.attentionGoalID).first?.outcome)
    }

    func testExplicitlyInterruptedSessionEndsPresentationWithoutChangingOutcome() async throws {
        let fixture = try Fixture()
        let (_, session) = try fixture.startSession(at: start)
        let service = fixture.service()
        try service.show(sessionID: session.id, at: start)
        let interrupted = try fixture.repository.finishSession(id: session.id, outcome: .interrupted, at: start.addingTimeInterval(60))
        await service.synchronize(asOf: start.addingTimeInterval(60))
        XCTAssertEqual(fixture.adapter.ended, [session.id])
        XCTAssertEqual(try fixture.repository.sessions(for: session.attentionGoalID), [interrupted])
    }

    func testSystemDismissalIsNotRecreatedBySynchronization() async throws {
        let fixture = try Fixture()
        let (_, session) = try fixture.startSession(at: start)
        let service = fixture.service()
        try service.show(sessionID: session.id, at: start)
        fixture.adapter.activities = [] // User dismisses the system presentation.
        await service.synchronize(asOf: start.addingTimeInterval(10))
        XCTAssertEqual(fixture.adapter.requests.count, 1)
        XCTAssertTrue(fixture.adapter.activities.isEmpty)
        XCTAssertEqual(try fixture.repository.sessions(for: session.attentionGoalID), [session])
    }

    func testForegroundDeadlineFollowsPresentationAndClearsAtExpiry() async throws {
        let fixture = try Fixture()
        let (_, session) = try fixture.startSession(at: start)
        let service = fixture.service()
        XCTAssertNil(service.nextExpiration)
        try service.show(sessionID: session.id, at: start)
        XCTAssertEqual(service.nextExpiration, session.expectedEnd)
        await service.synchronize(asOf: session.expectedEnd)
        XCTAssertNil(service.nextExpiration)
        XCTAssertEqual(try fixture.repository.sessions(for: session.attentionGoalID), [session])
    }

    func testHideRemovesPresentationButKeepsSessionActive() async throws {
        let fixture = try Fixture()
        let (_, session) = try fixture.startSession(at: start)
        let service = fixture.service()
        try service.show(sessionID: session.id, at: start)
        try await service.hide()
        await service.synchronize(asOf: start.addingTimeInterval(10))
        XCTAssertEqual(fixture.adapter.ended, [session.id])
        XCTAssertEqual(fixture.adapter.requests.count, 1)
        XCTAssertEqual(try fixture.repository.sessions(for: session.attentionGoalID), [session])
    }

    func testHidingAnotherSessionDoesNotDismissSelectedPresentation() async throws {
        let fixture = try Fixture()
        let (_, session) = try fixture.startSession(at: start)
        let service = fixture.service()
        try service.show(sessionID: session.id, at: start)
        try await service.hide(sessionID: UUID())
        XCTAssertEqual(fixture.adapter.activities.map(\.sessionID), [session.id])
        XCTAssertTrue(fixture.adapter.ended.isEmpty)
    }

    func testShowDuringSuspendedHideCannotReportFalseSuccess() async throws {
        let fixture = try Fixture()
        let (_, session) = try fixture.startSession(at: start)
        let service = fixture.service()
        try service.show(sessionID: session.id, at: start)
        let ending = expectation(description: "Platform dismissal has started")
        fixture.adapter.suspendEnd = true
        fixture.adapter.endObserver = { ending.fulfill() }
        let task = Task { try await service.hide(sessionID: session.id) }
        await fulfillment(of: [ending], timeout: 2)
        XCTAssertTrue(service.isChangingPresentation)
        XCTAssertThrowsError(try service.show(sessionID: session.id, at: start)) {
            guard case SessionLiveActivityError.presentationChanging = $0 else {
                return XCTFail("Unexpected error: \($0)")
            }
        }
        do {
            try await service.hide(sessionID: session.id)
            XCTFail("A concurrent hide must not falsely report success")
        } catch {
            guard case SessionLiveActivityError.presentationChanging = error else {
                fixture.adapter.suspendedEnd?.resume()
                return XCTFail("Unexpected error: \(error)")
            }
        }
        fixture.adapter.suspendedEnd?.resume()
        try await task.value
        XCTAssertFalse(service.isChangingPresentation)
        XCTAssertTrue(fixture.adapter.activities.isEmpty)
        XCTAssertEqual(fixture.adapter.requests.count, 1)
        XCTAssertEqual(try fixture.repository.sessions(for: session.attentionGoalID), [session])
    }

    func testGoalEditDoesNotChangeCapturedSessionDeadline() async throws {
        let fixture = try Fixture()
        let (goal, session) = try fixture.startSession(at: start, minutes: 25)
        let service = fixture.service()
        try service.show(sessionID: session.id, at: start)
        _ = try fixture.repository.updateGoal(id: goal.id, with: Fixture.draft(name: goal.name, minutes: 60), at: start.addingTimeInterval(10))
        await service.synchronize(asOf: start.addingTimeInterval(20))
        XCTAssertEqual(fixture.adapter.updates.last?.expectedEnd, start.addingTimeInterval(25 * 60))
        XCTAssertEqual(try fixture.repository.sessions(for: goal.id), [session])
    }

    func testMissingFutureAndExpiredSessionsCannotBePresented() throws {
        let fixture = try Fixture()
        let (_, session) = try fixture.startSession(at: start)
        let service = fixture.service()
        for (id, date) in [(UUID(), start), (session.id, start.addingTimeInterval(-1)), (session.id, session.expectedEnd)] {
            XCTAssertThrowsError(try service.show(sessionID: id, at: date)) {
                guard case SessionLiveActivityError.noActiveSession = $0 else { return XCTFail("Unexpected error: \($0)") }
            }
        }
        XCTAssertTrue(fixture.adapter.requests.isEmpty)
    }

    func testEightHourBoundaryAcceptedAndLongerDurationRejected() throws {
        let fixture = try Fixture()
        let (_, allowed) = try fixture.startSession(at: start, minutes: 480)
        let (_, tooLong) = try fixture.startSession(at: start, minutes: 481, name: "Long")
        let service = fixture.service()
        try service.show(sessionID: allowed.id, at: start)
        XCTAssertThrowsError(try service.show(sessionID: tooLong.id, at: start)) {
            guard case SessionLiveActivityError.unsupportedDuration = $0 else { return XCTFail("Unexpected error: \($0)") }
        }
        XCTAssertEqual(fixture.adapter.requests.map(\.sessionID), [allowed.id])
        XCTAssertEqual(try fixture.repository.sessions(for: tooLong.attentionGoalID), [tooLong])
    }

    func testNewExplicitSelectionEndsOldPresentationAfterSuccessfulRequestOnly() async throws {
        let fixture = try Fixture()
        let (_, first) = try fixture.startSession(at: start)
        let (_, second) = try fixture.startSession(at: start, name: "Second")
        let service = fixture.service()
        try service.show(sessionID: first.id, at: start)
        try service.show(sessionID: second.id, at: start)
        await service.synchronize(asOf: start)
        XCTAssertEqual(fixture.adapter.activities.map(\.sessionID), [second.id])
        XCTAssertEqual(fixture.adapter.events.prefix(3), ["request:\(first.id)", "request:\(second.id)", "end:\(first.id)"])
        XCTAssertEqual(try fixture.repository.sessions(for: first.attentionGoalID), [first])
    }

    func testCompanionSelectionAndDisablingRefreshExistingActivity() async throws {
        let fixture = try Fixture()
        let (_, session) = try fixture.startSession(at: start)
        var profile = CompanionProfile(selectedAnimal: .fox)
        try fixture.profiles.save(profile)
        let service = fixture.service()
        try service.show(sessionID: session.id, at: start)
        XCTAssertEqual(fixture.adapter.requests.first?.animal, "fox")
        profile.selectedAnimal = .otter
        try fixture.profiles.save(profile)
        await service.synchronize(asOf: start)
        XCTAssertEqual(fixture.adapter.updates.last?.animal, "otter")
        profile.companionEnabled = false
        try fixture.profiles.save(profile)
        await service.synchronize(asOf: start)
        XCTAssertNil(fixture.adapter.updates.last?.animal)
        XCTAssertEqual(fixture.adapter.requests.count, 1)
    }

    @MainActor
    private final class Fixture {
        let container: ModelContainer
        let repository: SwiftDataAttentionRepository
        let profiles: SwiftDataCompanionProfileRepository
        let adapter = FakeAdapter()

        init() throws {
            let schema = Schema([AttentionGoalRecord.self, AttentionGoalConfigurationSnapshotRecord.self,
                AttentionUsageEntryRecord.self, AttentionCheckInRecord.self, AttentionSessionRecord.self,
                CompanionProfileRecord.self])
            container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            repository = SwiftDataAttentionRepository(modelContext: container.mainContext, calendar: calendar)
            profiles = SwiftDataCompanionProfileRepository(modelContext: container.mainContext)
        }

        func service() -> SessionLiveActivityService {
            SessionLiveActivityService(repository: repository, profiles: profiles, adapter: adapter)
        }

        func startSession(at date: Date, minutes: Double = 25, name: String = "Focus") throws -> (AttentionGoal, AttentionSession) {
            let goal = try repository.createGoal(Self.draft(name: name, minutes: minutes), at: date)
            return (goal, try repository.startSession(goalID: goal.id, at: date))
        }

        static func draft(name: String, minutes: Double) -> AttentionGoalDraft {
            AttentionGoalDraft(name: name, appOrCategoryLabel: nil, type: .phoneFreeSession, targetValue: minutes, unit: .minutes)
        }

        static func descriptor(_ session: AttentionSession, animal: String? = "owl") -> SessionLiveActivityDescriptor {
            SessionLiveActivityDescriptor(sessionID: session.id, startedAt: session.startedAt, expectedEnd: session.expectedEnd, animal: animal)
        }
    }

    @MainActor
    private final class FakeAdapter: SessionLiveActivityAdapter {
        enum RequestFailure: Error { case unavailable }
        var areEnabled = true
        var activities: [SessionLiveActivityDescriptor] = []
        var requests: [SessionLiveActivityDescriptor] = []
        var updates: [SessionLiveActivityDescriptor] = []
        var ended: [UUID] = []
        var events: [String] = []
        var failRequest = false
        var suspendEnd = false
        var suspendedEnd: CheckedContinuation<Void, Never>?
        var endObserver: (() -> Void)?

        func request(_ descriptor: SessionLiveActivityDescriptor) throws {
            if failRequest { throw RequestFailure.unavailable }
            requests.append(descriptor)
            activities.append(descriptor)
            events.append("request:\(descriptor.sessionID)")
        }

        func update(_ descriptor: SessionLiveActivityDescriptor) async {
            updates.append(descriptor)
            activities = activities.map { $0.sessionID == descriptor.sessionID ? descriptor : $0 }
            events.append("update:\(descriptor.sessionID)")
        }

        func end(sessionID: UUID) async {
            if suspendEnd {
                await withCheckedContinuation { continuation in
                    suspendedEnd = continuation
                    endObserver?()
                }
            }
            ended.append(sessionID)
            activities.removeAll { $0.sessionID == sessionID }
            events.append("end:\(sessionID)")
        }
    }
}
