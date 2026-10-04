import Foundation
import Observation

struct SessionLiveActivityDescriptor: Equatable, Sendable {
    let sessionID: UUID
    let startedAt: Date
    let expectedEnd: Date
    let animal: String?
}

@MainActor
protocol SessionLiveActivityAdapter {
    var areEnabled: Bool { get }
    var activities: [SessionLiveActivityDescriptor] { get }
    func request(_ descriptor: SessionLiveActivityDescriptor) throws
    func update(_ descriptor: SessionLiveActivityDescriptor) async
    func end(sessionID: UUID) async
}

enum SessionLiveActivityError: Error {
    case disabled, noActiveSession, unsupportedDuration, presentationChanging
}

/// Optional system presentation of persisted sessions. Reconciliation NEVER
/// creates an activity, so foregrounding cannot resurrect a dismissed one.
@MainActor
@Observable
final class SessionLiveActivityService {
    private let repository: AttentionRepository
    private let profiles: CompanionProfileRepository
    private let adapter: SessionLiveActivityAdapter
    private(set) var nextExpiration: Date?
    private var selectedSessionID: UUID?
    private var synchronizing = false
    private var hiding = false
    var isChangingPresentation: Bool { synchronizing || hiding }
    private var pendingSynchronization = false

    init(repository: AttentionRepository, profiles: CompanionProfileRepository, adapter: SessionLiveActivityAdapter) {
        self.repository = repository
        self.profiles = profiles
        self.adapter = adapter
    }

    func show(sessionID: UUID, at date: Date = Date()) throws {
        guard !isChangingPresentation else { throw SessionLiveActivityError.presentationChanging }
        guard adapter.areEnabled else { throw SessionLiveActivityError.disabled }
        guard let session = try activeSessions().first(where: { $0.id == sessionID }),
              session.startedAt <= date, session.expectedEnd > date else {
            throw SessionLiveActivityError.noActiveSession
        }
        guard session.expectedEnd.timeIntervalSince(session.startedAt) <= 8 * 3600 else {
            throw SessionLiveActivityError.unsupportedDuration
        }
        let descriptor = try descriptor(for: session)
        if !adapter.activities.contains(where: { $0.sessionID == sessionID }) {
            try adapter.request(descriptor)
        }
        selectedSessionID = sessionID
        nextExpiration = adapter.activities.map(\.expectedEnd).filter { $0 > date }.min()
        // The composition root schedules synchronization after the explicit
        // request, ending any prior presentation without changing its session.
    }

    func synchronize(asOf date: Date = Date()) async {
        pendingSynchronization = true
        guard !isChangingPresentation else { return }
        synchronizing = true
        defer {
            synchronizing = false
            nextExpiration = adapter.activities.map(\.expectedEnd).filter { $0 > date }.min()
        }
        while pendingSynchronization {
            pendingSynchronization = false
            do {
                let sessions = try activeSessions()
                for activity in adapter.activities {
                    guard adapter.areEnabled,
                          selectedSessionID == nil || selectedSessionID == activity.sessionID,
                          let session = sessions.first(where: { $0.id == activity.sessionID }),
                          session.startedAt <= date, session.expectedEnd > date else {
                        await adapter.end(sessionID: activity.sessionID)
                        continue
                    }
                    await adapter.update(try descriptor(for: session))
                }
            } catch {
                // Failed reads cannot authorize new presentations or outcomes.
                // Leave existing activities to their staleDate/system lifetime.
                return
            }
        }
    }

    func hide(sessionID: UUID? = nil) async throws {
        guard !isChangingPresentation else { throw SessionLiveActivityError.presentationChanging }
        hiding = true
        for activity in adapter.activities where sessionID == nil || activity.sessionID == sessionID {
            await adapter.end(sessionID: activity.sessionID)
        }
        if sessionID == nil || selectedSessionID == sessionID { selectedSessionID = nil }
        nextExpiration = adapter.activities.map(\.expectedEnd).filter { $0 > Date() }.min()
        hiding = false
        if pendingSynchronization { await synchronize() }
    }

    private func activeSessions() throws -> [AttentionSession] {
        try repository.fetchGoals().filter { $0.type == .phoneFreeSession }.flatMap {
            try repository.sessions(for: $0.id).filter(\.isActive)
        }
    }

    private func descriptor(for session: AttentionSession) throws -> SessionLiveActivityDescriptor {
        let profile = try profiles.profile()
        return SessionLiveActivityDescriptor(sessionID: session.id, startedAt: session.startedAt,
            expectedEnd: session.expectedEnd, animal: profile.companionEnabled ? profile.selectedAnimal.rawValue : nil)
    }
}
