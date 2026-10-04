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
