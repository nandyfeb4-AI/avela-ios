import Foundation
import Observation

@MainActor protocol AppProtectionDriver: AnyObject {
    var isAvailable: Bool { get }
    var isAuthorized: Bool { get }
    var selectionCount: Int { get }
    func requestAuthorization() async throws
    func readLease() throws -> ProtectionLease?
    /// Must arm expiry monitoring before applying any restriction.
    func begin(_ lease: ProtectionLease) throws
    func stop() throws
    func reconcile(at date: Date, sessionIsActive: (ProtectionLease) throws -> Bool) throws -> ProtectionLease?
}

@MainActor @Observable final class AppProtectionModel {
    private let driver: any AppProtectionDriver
    private let sessionIsActive: (ProtectionLease) throws -> Bool
    private(set) var active: ProtectionLease?
    private(set) var isRequesting = false
    private(set) var authorized = false
    private(set) var selectionCount = 0
    var message: String?
    var isAvailable: Bool { driver.isAvailable }

    init(driver: any AppProtectionDriver, sessionIsActive: @escaping (ProtectionLease) throws -> Bool) {
        self.driver = driver
        self.sessionIsActive = sessionIsActive
    }

    func refresh(asOf date: Date = Date()) {
        authorized = driver.isAuthorized
        selectionCount = driver.selectionCount
        guard isAvailable else { active = nil; return }
        do { active = try driver.reconcile(at: date, sessionIsActive: sessionIsActive) }
        catch { message = "Protection couldn't be checked. Use Stop Protection to release restrictions." }
    }

    func authorize() async {
        guard !isRequesting else { return }
        guard isAvailable else { message = AppProtectionError.unavailable.message; return }
        message = nil
        isRequesting = true
        defer { isRequesting = false }
        do { try await driver.requestAuthorization(); refresh() }
        catch { message = AppProtectionError.permissionRequired.message; refresh() }
    }

    func validateStart(minutes: Double, asOf date: Date = Date()) throws {
        guard isAvailable else { throw AppProtectionError.unavailable }
        guard driver.isAuthorized else { throw AppProtectionError.permissionRequired }
        guard driver.selectionCount > 0 else { throw AppProtectionError.selectionRequired }
        try ProtectionLease.validateDuration(minutes * 60)
        refresh(asOf: date)
        guard try driver.readLease() == nil else { throw AppProtectionError.alreadyActive }
    }

    @discardableResult func start(session: AttentionSession, asOf date: Date = Date()) -> Bool {
        do {
            try validateStart(minutes: session.targetMinutes, asOf: date)
            let lease = ProtectionLease(id: UUID(), sessionID: session.id, goalID: session.attentionGoalID,
                startedAt: session.startedAt, endsAt: session.expectedEnd)
            guard session.isActive, lease.isValid(at: date), try sessionIsActive(lease) else {
                throw AppProtectionError.expired
            }
            try driver.begin(lease)
            active = lease
            message = nil
            return true
        } catch {
            message = "Your session is saved without app protection. " + ((error as? AppProtectionError)?.message
                ?? "Restrictions couldn't be started safely. Try again from a new session.")
            refresh(asOf: date)
            return false
        }
    }

    func stop() {
        do { try driver.stop(); active = nil; message = "Protection stopped. Your session and habit progress are unchanged." }
        catch { message = "Couldn't finish clearing protection. Try Stop Protection again, or revoke Rilova's access in Settings → Screen Time." }
    }
}

/// Simulator/unsupported signing path: never opens shared state or system stores.
@MainActor final class UnavailableAppProtectionDriver: AppProtectionDriver {
    let isAvailable = false
    let isAuthorized = false
    let selectionCount = 0
    func requestAuthorization() async throws { throw AppProtectionError.unavailable }
    func readLease() throws -> ProtectionLease? { nil }
    func begin(_ lease: ProtectionLease) throws { throw AppProtectionError.unavailable }
    func stop() throws {}
    func reconcile(at date: Date, sessionIsActive: (ProtectionLease) throws -> Bool) throws -> ProtectionLease? { nil }
}
