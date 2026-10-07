import Foundation
import WatchConnectivity
import UIKit

/// One retained app-owned coordinator. Opt-in is a composition-root preference;
/// do not activate merely because the app launches. No background logging queue.
@MainActor
final class WatchConnectivityCoordinator: NSObject, WCSessionDelegate {
    private let service: WatchHabitLoggingService
    private let didLog: () -> Void
    private var enabled = false

    init(service: WatchHabitLoggingService, didLog: @escaping () -> Void = {}) {
        self.service = service
        self.didLog = didLog
        super.init()
    }

    func setEnabled(_ value: Bool) {
        enabled = value
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        refresh()
    }

    func refresh() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              WCSession.default.isPaired, WCSession.default.isWatchAppInstalled else { return }
        // Empty context revokes names and actions after disconnect.
        let data = enabled ? (try? JSONEncoder().encode(service.snapshot())) : nil
        try? WCSession.default.updateApplicationContext(data.map { ["snapshot": $0] } ?? [:])
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor [weak self] in self?.refresh() }
    }
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.refresh() }
    }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data,
                             replyHandler: @escaping (Data) -> Void) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let reply: WatchHabitReply
            if !self.enabled {
                reply = WatchHabitReply(status: .unavailable, snapshot: nil)
            } else if let request = try? JSONDecoder().decode(WatchSnapshotRequest.self, from: messageData),
                      request.protocolVersion == WatchHabitSnapshot.version, request.action == "refresh" {
                if UIApplication.shared.isProtectedDataAvailable {
                    reply = WatchHabitReply(status: .refreshed, snapshot: try? self.service.snapshot())
                } else {
                    reply = WatchHabitReply(status: .openPhone, snapshot: nil)
                }
            } else if let request = try? JSONDecoder().decode(WatchHabitLogRequest.self, from: messageData) {
                reply = self.service.log(request, phoneAvailable: UIApplication.shared.isProtectedDataAvailable)
                if reply.status == .logged { self.didLog() }
            } else {
                reply = WatchHabitReply(status: .failed, snapshot: nil)
            }
            if let data = try? JSONEncoder().encode(reply) { replyHandler(data) }
            self.refresh()
        }
    }
}
