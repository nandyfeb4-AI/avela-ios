import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
import Combine

@MainActor final class AppleAppProtectionDriver: AppProtectionDriver {
    static let storeName = "avela.makeRoom"
    private let leases = ProtectionLeaseStore()
    private let settings = ManagedSettingsStore(named: .init(storeName))
    private let center = DeviceActivityCenter()
    private var authorizationObserver: AnyCancellable?
    private(set) var selection = FamilyActivitySelection()
    private let selectionURL: URL

    static var featureVisible: Bool {
        Bundle.main.object(forInfoDictionaryKey: "AvelaAppProtectionEnabled") as? String == "YES"
    }

    var isAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return Self.featureVisible
        #endif
    }
    var isAuthorized: Bool { AuthorizationCenter.shared.authorizationStatus == .approved }
    var selectionCount: Int { selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count }

    init() throws {
        // Deliberately app-private. The monitor only needs the lease, not tokens.
        let directory = try FileManager.default.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("AppProtection", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var excluded = directory
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try excluded.setResourceValues(values)
        selectionURL = directory.appendingPathComponent("selection.json")
        if FileManager.default.fileExists(atPath: selectionURL.path) {
            // Corrupt picker preferences become an empty selection, never all apps.
            selection = (try? JSONDecoder().decode(FamilyActivitySelection.self, from: Data(contentsOf: selectionURL))) ?? FamilyActivitySelection()
        }
        if isAvailable {
            authorizationObserver = AuthorizationCenter.shared.$authorizationStatus
                .receive(on: DispatchQueue.main).sink { [weak self] status in
                    guard status != .approved else { return }
                    try? self?.stop()
                }
        }
    }

    func requestAuthorization() async throws {
        guard isAvailable else { throw AppProtectionError.unavailable }
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        guard isAuthorized else { throw AppProtectionError.permissionRequired }
    }

    func saveSelection(_ value: FamilyActivitySelection) throws {
        guard isAvailable, isAuthorized else { throw AppProtectionError.permissionRequired }
        // Changing choices cannot silently broaden an already-running restriction.
        guard try readLease() == nil else { throw AppProtectionError.alreadyActive }
        try JSONEncoder().encode(value).write(to: selectionURL,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        selection = value
    }

    func readLease() throws -> ProtectionLease? { try leases.read() }

    func begin(_ lease: ProtectionLease) throws {
        guard isAvailable, isAuthorized else { throw AppProtectionError.permissionRequired }
        guard selectionCount > 0 else { throw AppProtectionError.selectionRequired }
        guard lease.isValid(at: Date()) else { throw AppProtectionError.expired }
        let name = DeviceActivityName(lease.activityName)
        // Exact absolute instants, independent of travel and daylight saving.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let fields: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        var start = calendar.dateComponents(fields, from: lease.startedAt)
        var end = calendar.dateComponents(fields, from: lease.endsAt)
        start.calendar = calendar; start.timeZone = calendar.timeZone
        end.calendar = calendar; end.timeZone = calendar.timeZone
        let schedule = DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: false)
        // Registration failure must not leave a persistent lease or shield.
        try center.startMonitoring(name, during: schedule)
        do {
            try leases.update { current in
                guard current == nil else { throw AppProtectionError.alreadyActive }
                guard isAuthorized, lease.isValid(at: Date()) else { throw AppProtectionError.expired }
                current = lease
                settings.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
                settings.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
                settings.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
                settings.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
            }
        } catch {
            // Do not erase a different valid lease after an overlap refusal.
            if (error as? AppProtectionError) != .alreadyActive { settings.clearAllSettings() }
            center.stopMonitoring([name])
            throw error
        }
    }

    func stop() throws {
        // Clear first even if metadata is corrupt; stop must remain available.
        do {
            let name: String? = try leases.update { current in
                settings.clearAllSettings()
                let name = current?.activityName
                current = nil
                return name
            }
            if let name { center.stopMonitoring([.init(name)]) }
        } catch {
            settings.clearAllSettings()
            center.stopMonitoring(center.activities.filter { $0.rawValue.hasPrefix("avela.protection.") })
            try leases.discard()
        }
    }

    func reconcile(at date: Date, sessionIsActive: (ProtectionLease) throws -> Bool) throws -> ProtectionLease? {
        guard isAvailable else { return nil }
        do {
            var stoppedName: String?
            let result = try leases.update { current in
                guard let lease = current else { settings.clearAllSettings(); return Optional<ProtectionLease>.none }
                // Never reapply shields on relaunch or guess after a failed read.
                let shouldKeep = try isAuthorized && lease.isValid(at: date) && sessionIsActive(lease)
                    && center.activities.contains(.init(lease.activityName))
                if !shouldKeep {
                    settings.clearAllSettings(); stoppedName = lease.activityName; current = nil
                }
                return current
            }
            if let stoppedName { center.stopMonitoring([.init(stoppedName)]) }
            if result == nil {
                center.stopMonitoring(center.activities.filter { $0.rawValue.hasPrefix("avela.protection.") })
            }
            return result
        } catch {
            try stop()
            throw error
        }
    }
}
