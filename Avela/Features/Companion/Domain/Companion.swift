import Foundation

enum CompanionAnimal: String, CaseIterable, Codable, Identifiable, Sendable {
    case owl, fox, otter
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var assetName: String { "Companion" + title }
}

struct CompanionProfile: Equatable, Sendable {
    var selectedAnimal: CompanionAnimal = .owl
    var companionEnabled = true
    var hapticsEnabled = true
    var onboardingCompleted = false
}

@MainActor
protocol CompanionProfileRepository {
    func profile() throws -> CompanionProfile
    func save(_ profile: CompanionProfile) throws
}

enum CompanionState: String, CaseIterable, Equatable, Sendable {
    case calm, focused, nearLimit, overloaded, recovering, celebrating
}

/// Normalized facts supplied by feature composition; no persistence, platform
/// API, animation, or unobserved usage is interpreted as a measured success.
struct CompanionInput: Equatable {
    var loggedAttentionStates: [AttentionProgressCalculator.ThresholdState] = []
    var attentionGoalCount = 0
    var isRecovering = false
    var meaningfulCompletion = false
    var hasActiveSession = false
    var completedHabits = 0
    var dueHabits = 0
}

enum CompanionStateEngine {
    static func state(for input: CompanionInput) -> CompanionState {
        if input.loggedAttentionStates.contains(.exceeded) { return .overloaded }
        if input.loggedAttentionStates.contains(.nearLimit) { return .nearLimit }
        if input.isRecovering { return .recovering }
        if input.meaningfulCompletion && input.completedHabits > 0 { return .celebrating }
        if input.hasActiveSession { return .focused }
        return .calm
    }

    static func message(for input: CompanionInput) -> String {
        switch state(for: input) {
        case .overloaded: return "Your logged usage has reached a limit. A pause is always an option."
        case .nearLimit: return "Your logged usage is close to a limit. You can choose what comes next."
        case .recovering: return "You're rebuilding momentum, one commitment at a time."
        case .celebrating: return "A little progress worth noticing."
        case .focused: return "Some space for what matters to you."
        case .calm:
            if input.attentionGoalCount > input.loggedAttentionStates.count {
                return "No check-in needed to begin. Log your attention when you're ready."
            }
            if input.dueHabits > 0 {
                return "\(input.completedHabits) of \(input.dueHabits) habits logged today. One step at a time."
            }
            return "Make room for a small step today."
        }
    }
}

/// Four app-facing states, composed only from recorded facts. Legacy six-state
/// keys stay unchanged for the shared artwork atlases and widget snapshots.
enum CompanionPresentationState: String, CaseIterable, Equatable, Sendable {
    case steady, buildingMomentum, recovering, needsSpace

    var title: String {
        switch self {
        case .steady: return "Steady"
        case .buildingMomentum: return "Building momentum"
        case .recovering: return "Recovering"
        case .needsSpace: return "Logged budget exceeded"
        }
    }

    var artworkState: CompanionState {
        switch self {
        case .steady: return .calm
        case .buildingMomentum: return .celebrating
        case .recovering: return .recovering
        case .needsSpace: return .overloaded
        }
    }

    var symbol: String {
        switch self {
        case .steady: return "leaf"
        case .buildingMomentum: return "arrow.up.right"
        case .recovering: return "arrow.clockwise"
        case .needsSpace: return "pause.circle"
        }
    }
}

enum CompanionPresentation {
    static func state(for input: CompanionInput) -> CompanionPresentationState {
        if input.loggedAttentionStates.contains(.exceeded) { return .needsSpace }
        if input.isRecovering { return .recovering }
        // A saved check-in counts here; it need not be a transient celebration.
        // An active timer or an unlogged budget alone is never progress evidence.
        if input.completedHabits > 0 { return .buildingMomentum }
        return .steady
    }

    static func message(for input: CompanionInput) -> String {
        switch state(for: input) {
        case .needsSpace:
            return "Your manually logged usage reached a budget. A pause is an option, not a requirement."
        case .recovering:
            if input.loggedAttentionStates.contains(.nearLimit) {
                return "Your progress is still here. Logged attention is close to a budget; your next step can be small."
            }
            return "A missed commitment doesn't erase your progress. One next step is enough."
        case .buildingMomentum:
            let count = input.completedHabits
            let progress = "\(count) \(count == 1 ? "habit" : "habits") logged today."
            if input.loggedAttentionStates.contains(.nearLimit) {
                return progress + " Logged attention is close to a budget."
            }
            return progress + " Every recorded step stays part of your story."
        case .steady:
            if input.loggedAttentionStates.contains(.nearLimit) {
                return "Your manually logged usage is close to a budget. Choose what comes next."
            }
            if input.hasActiveSession {
                return "A session is running. What you do with that time is yours to report."
            }
            if input.attentionGoalCount > input.loggedAttentionStates.count {
                return "Attention isn't fully logged yet. Take your next step when you're ready."
            }
            return "Make room for what matters. Your next step can be small."
        }
    }
}
