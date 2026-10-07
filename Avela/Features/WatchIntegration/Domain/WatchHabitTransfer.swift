import Foundation

/// Deliberately small paired-device payload. No notes, attention usage or Health
/// samples leave the phone. Names are sent only after the owner's opt-in.
struct WatchHabitSnapshot: Codable, Equatable, Sendable {
    static let version = 1
    let protocolVersion: Int
    let generatedAt: Date
    let localDateKey: String
    let expiresAt: Date
    let habits: [WatchHabitItem]

    func isCurrent(at date: Date) -> Bool {
        protocolVersion == Self.version && date >= generatedAt && date < expiresAt
    }
}

struct WatchHabitItem: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let iconName: String
    let isCompleted: Bool
    let supportsQuickLog: Bool
}

struct WatchHabitLogRequest: Codable, Equatable, Sendable {
    let protocolVersion: Int
    let habitID: UUID
    let localDateKey: String
}

struct WatchHabitReply: Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable {
        case refreshed, logged, alreadyLogged, openPhone, staleDay, unavailable, failed
    }
    let status: Status
    let snapshot: WatchHabitSnapshot?
}

struct WatchSnapshotRequest: Codable, Equatable, Sendable {
    let protocolVersion: Int
    let action: String
    init() {
        protocolVersion = WatchHabitSnapshot.version
        action = "refresh"
    }
}
