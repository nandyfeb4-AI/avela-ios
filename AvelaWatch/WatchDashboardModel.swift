import Foundation
import Observation
import WatchConnectivity

@MainActor @Observable
final class WatchDashboardModel: NSObject, WCSessionDelegate {
    private(set) var snapshot: WatchHabitSnapshot?
    private(set) var pendingHabitID: UUID?
    private(set) var isRefreshing = false
    var message: String?
    var timerStartedAt: Date? {
        didSet {
            if let timerStartedAt { UserDefaults.standard.set(timerStartedAt, forKey: "watch.timerStartedAt") }
            else { UserDefaults.standard.removeObject(forKey: "watch.timerStartedAt") }
        }
    }

    override init() {
        timerStartedAt = UserDefaults.standard.object(forKey: "watch.timerStartedAt") as? Date
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func log(_ habit: WatchHabitItem) {
        guard pendingHabitID == nil else { return }
        guard let snapshot, snapshot.isCurrent(at: Date()) else {
            message = "Open Avela on your iPhone to refresh today's habits."
            return
        }
        guard habit.supportsQuickLog else { message = "Add progress for this habit on your iPhone."; return }
        guard WCSession.default.activationState == .activated, WCSession.default.isReachable else {
            message = "Unlock your iPhone and keep it nearby, then try again. Nothing was logged."
            return
        }
        let request = WatchHabitLogRequest(protocolVersion: WatchHabitSnapshot.version,
                                          habitID: habit.id, localDateKey: snapshot.localDateKey)
        guard let data = try? JSONEncoder().encode(request) else { return }
        pendingHabitID = habit.id
        WCSession.default.sendMessageData(data, replyHandler: { [weak self] data in
            Task { @MainActor in
                guard let self else { return }
                self.pendingHabitID = nil
                guard let reply = try? JSONDecoder().decode(WatchHabitReply.self, from: data) else {
                    self.message = "Could not confirm the check-in. Review it on your iPhone."
                    return
                }
                if let snapshot = reply.snapshot { self.snapshot = snapshot }
                switch reply.status {
                case .refreshed: break
                case .logged: self.message = "Logged on your iPhone."
                case .alreadyLogged: self.message = "Already logged today."
                case .openPhone: self.message = "Unlock your iPhone and keep it nearby, then try again. Nothing was logged."
                case .staleDay: self.message = "Today's habits changed. Please review them and try again."
                case .unavailable: self.message = "This habit can't be logged here. Review it on your iPhone."
                case .failed: self.message = "Could not confirm the check-in. Review it on your iPhone."
                }
            }
        }, errorHandler: { [weak self] _ in
            Task { @MainActor in
                self?.pendingHabitID = nil
                self?.message = "Connection interrupted. Check your iPhone before trying again."
            }
        })
    }

    func refresh() {
        guard !isRefreshing else { return }
        guard WCSession.default.activationState == .activated, WCSession.default.isReachable else {
            message = "Unlock your iPhone and keep it nearby. Open Avela there if it hasn't connected yet."
            return
        }
        guard let data = try? JSONEncoder().encode(WatchSnapshotRequest()) else { return }
        isRefreshing = true
        WCSession.default.sendMessageData(data, replyHandler: { [weak self] data in
            Task { @MainActor in
                guard let self else { return }
                self.isRefreshing = false
                guard let reply = try? JSONDecoder().decode(WatchHabitReply.self, from: data),
                      reply.status == .refreshed, let snapshot = reply.snapshot else {
                    self.message = "Enable Apple Watch in Avela Settings and unlock your paired iPhone."
                    return
                }
                self.snapshot = snapshot
            }
        }, errorHandler: { [weak self] _ in
            Task { @MainActor in
                self?.isRefreshing = false
                self?.message = "Could not refresh. Check Avela on your paired iPhone."
            }
        })
    }

    func startTimer() { if timerStartedAt == nil { timerStartedAt = Date() } }
    func stopTimer() {
        let elapsed = max(0, Int(Date().timeIntervalSince(timerStartedAt ?? Date())))
        timerStartedAt = nil
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        message = "Timed \(minutes) min \(seconds) sec. No habit was completed. Log your progress on your iPhone."
    }

    private func receive(_ context: [String: Any]) {
        snapshot = (context["snapshot"] as? Data).flatMap { try? JSONDecoder().decode(WatchHabitSnapshot.self, from: $0) }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let context = session.receivedApplicationContext
        Task { @MainActor [weak self] in self?.receive(context) }
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor [weak self] in self?.receive(applicationContext) }
    }
}
