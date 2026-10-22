import Foundation

/// Operational restriction state, never a completion or evidence of focus.
/// Shared only with the monitor extension; no habit names or picker tokens.
struct ProtectionLease: Codable, Equatable, Sendable {
    let id: UUID
    let sessionID: UUID
    let goalID: UUID
    let startedAt: Date
    let endsAt: Date
    var activityName: String { "avela.protection.\(id.uuidString)" }

    func shouldRelease(activityName: String, intervalEnded: Bool, at date: Date) -> Bool {
        self.activityName == activityName && (intervalEnded || !isValid(at: date))
    }

    static func validateDuration(_ duration: TimeInterval) throws {
        guard duration.isFinite, duration >= 15 * 60, duration <= 8 * 60 * 60 else {
            throw AppProtectionError.unsupportedDuration
        }
    }

    func isValid(at date: Date) -> Bool {
        let duration = endsAt.timeIntervalSince(startedAt)
        return startedAt.timeIntervalSince1970.isFinite && endsAt.timeIntervalSince1970.isFinite
            && duration >= 900 && duration <= 28800 && date >= startedAt && date < endsAt
    }
}

enum AppProtectionError: Error, Equatable {
    case unavailable, permissionRequired, selectionRequired, unsupportedDuration, alreadyActive, expired, storageUnavailable

    var message: String {
        switch self {
        case .unavailable: return "App protection needs a signed iPhone build with Family Controls enabled. Your normal sessions still work."
        case .permissionRequired: return "Allow Screen Time access to protect your selected apps. Sessions without protection remain available."
        case .selectionRequired: return "Choose the apps, categories or websites you want to restrict first."
        case .unsupportedDuration: return "App protection supports sessions from 15 minutes to 8 hours. Shorter sessions still work without protection."
        case .alreadyActive: return "Protection is already running. Stop it before protecting another session."
        case .expired: return "This session has ended. No new restrictions were applied."
        case .storageUnavailable: return "Protection couldn't be saved safely. Open Rilova and try again; normal tracking is unchanged."
        }
    }
}
