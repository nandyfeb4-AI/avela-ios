import DeviceActivity
import ManagedSettings
import Foundation
import OSLog

/// No usage events or reports. Its only job is releasing Avela's named store.
final class ProtectionMonitor: DeviceActivityMonitor {
    private let leases = ProtectionLeaseStore()
    private let settings = ManagedSettingsStore(named: .init("avela.makeRoom"))

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        release(activity, intervalEnded: true)
        // Remove finished registrations so repeated sessions do not exhaust the system limit.
        DeviceActivityCenter().stopMonitoring([activity])
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // Expired state after reboot/interruption is released, never reapplied.
        release(activity, intervalEnded: false)
    }

    private func release(_ activity: DeviceActivityName, intervalEnded: Bool) {
        guard activity.rawValue.hasPrefix("avela.protection.") else { return }
        do {
            try leases.update { current in
                guard let lease = current else { settings.clearAllSettings(); return }
                // A late callback for an earlier interval cannot stop a new one.
                if lease.shouldRelease(activityName: activity.rawValue, intervalEnded: intervalEnded, at: Date()) {
                    settings.clearAllSettings()
                    current = nil
                }
            }
        } catch {
            // Operational uncertainty fails open; never hold a stale shield.
            settings.clearAllSettings()
            try? leases.discard()
            Logger(subsystem: "com.example.Avela", category: "ProtectionMonitor")
                .error("Protection metadata unavailable; released restrictions.")
        }
    }
}
