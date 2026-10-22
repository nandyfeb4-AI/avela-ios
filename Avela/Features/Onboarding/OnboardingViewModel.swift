import Foundation
import Observation
import OSLog

enum OnboardingStep: Int, CaseIterable {
    case welcome, goal, obstacle, habit, companion, finish
}

/// Optional setup answers rank existing starting points; they are not measured
/// behaviour, a diagnosis, or persisted progress.
enum OnboardingGoal: String, CaseIterable, Identifiable, Sendable {
    case routine, restart, focus
    var id: String { rawValue }
    var title: String {
        switch self {
        case .routine: "Build a routine"
        case .restart: "Start again"
        case .focus: "Protect my focus"
        }
    }
    var detail: String {
        switch self {
        case .routine: "Find a rhythm for the everyday."
        case .restart: "Take a small next step, without a reset."
        case .focus: "Make room for what matters to you."
        }
    }
    var symbol: String {
        switch self {
        case .routine: "sunrise.fill"
        case .restart: "arrow.counterclockwise"
        case .focus: "scope"
        }
    }
}

enum OnboardingObstacle: String, CaseIterable, Identifiable, Sendable {
    case forgetting, time, distractions, tooBig
    var id: String { rawValue }
    var title: String {
        switch self {
        case .forgetting: "I forget"
        case .time: "Time is tight"
        case .distractions: "I get distracted"
        case .tooBig: "It feels too big"
        }
    }
    var detail: String {
        switch self {
        case .forgetting: "Choose a clear cue for your habit."
        case .time: "Begin with a simple check-in."
        case .distractions: "Protect a little room for one thing."
        case .tooBig: "Keep a smaller action within reach."
        }
    }
    var symbol: String {
        switch self {
        case .forgetting: "bell"
        case .time: "clock"
        case .distractions: "iphone.slash"
        case .tooBig: "leaf"
        }
    }
}

@MainActor
@Observable
final class OnboardingViewModel {
    private(set) var step: OnboardingStep = .welcome
    var profile = CompanionProfile()
    private(set) var firstHabit: Habit?
    private(set) var didFinish = false
    private(set) var selectedGoal: OnboardingGoal?
    private(set) var selectedObstacle: OnboardingObstacle?
    private(set) var selectedStarterID: String?
    private(set) var selectedHabitDraft: HabitDraft?
    var isShowingHabitForm = false
    var errorMessage: String?
    let reminderService: HabitReminderService?
    private let habits: HabitRepository
    private let profiles: CompanionProfileRepository
    private let habitCreationAllowed: (Int) -> Bool
    private var savedProfile = CompanionProfile()
    private var hasLoadedProfile = false

    init(habits: HabitRepository, profiles: CompanionProfileRepository,
         reminderService: HabitReminderService? = nil,
         habitCreationAllowed: @escaping (Int) -> Bool = { _ in true }) {
        self.habits = habits
        self.profiles = profiles
        self.reminderService = reminderService
        self.habitCreationAllowed = habitCreationAllowed
    }

    var suggestedStarters: [HabitStarter] {
        let ids: [String]
        switch (selectedGoal, selectedObstacle) {
        case (.focus, .time), (.focus, .tooBig):
            ids = ["phone-away", "pause", "read-article"]
        case (.restart, .time):
            ids = ["pause", "journal", "stretch"]
        case (.restart, .tooBig):
            ids = ["pause", "stretch", "learn"]
        case (_, .time):
            ids = ["walk", "wind-down", "plan-day"]
        case (_, .tooBig):
            ids = ["plan-day", "pause", "walk"]
        case (.focus, .distractions):
            ids = ["phone-away", "single-task", "read"]
        case (.restart, .distractions):
            ids = ["pause", "phone-away", "journal"]
        case (_, .distractions):
            ids = ["phone-away", "plan-day", "walk"]
        case (_, .forgetting):
            ids = ["plan-day", "walk", "read"]
        case (.focus, nil):
            ids = ["read", "single-task", "phone-away"]
        case (.restart, nil):
            ids = ["pause", "stretch", "journal"]
        case (.routine, nil):
            ids = ["water", "walk", "read"]
        case (nil, nil):
            ids = ["walk", "read", "pause"]
        }
        return ids.compactMap { id in HabitStarter.library.first { $0.id == id } }
    }

    func selectGoal(_ goal: OnboardingGoal?) {
        guard !didFinish else { return }
        selectedGoal = goal
    }

    func selectObstacle(_ obstacle: OnboardingObstacle?) {
        guard !didFinish else { return }
        selectedObstacle = obstacle
    }

    func selectStarter(_ id: String) {
        guard !didFinish, firstHabit == nil else { return }
        let starter = HabitStarter.library.first { $0.id == id }
        selectedStarterID = starter?.id
        selectedHabitDraft = starter?.draft
    }

    func load() {
        // Returning from a contextual sheet must not discard companion edits or
        // replace the user's current setup choices. Failed reads remain retryable.
        guard !hasLoadedProfile else { return }
        do {
            let storedProfile = try profiles.profile()
            let existingHabit = try habits.fetchHabits(includeArchived: false).first
            savedProfile = storedProfile
            profile = storedProfile
            hasLoadedProfile = true
            if firstHabit == nil { firstHabit = existingHabit }
            didFinish = storedProfile.onboardingCompleted
            if didFinish { step = .finish; isShowingHabitForm = false }
            errorMessage = nil
        } catch { handle(error) }
    }

    func advance() {
        guard !didFinish, let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        do {
            if step == .companion {
                guard ensureProfileLoaded(), !didFinish else { return }
                try profiles.save(profile)
                savedProfile = profile
            }
            errorMessage = nil
            step = next
        } catch { handle(error) }
    }

    func goBack() {
        guard !didFinish, let previous = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        isShowingHabitForm = false
        errorMessage = nil
        step = previous
    }

    func skipCurrentStep() {
        guard !didFinish, let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        switch step {
        case .goal: selectedGoal = nil
        case .obstacle: selectedObstacle = nil
        case .companion:
            guard ensureProfileLoaded(), !didFinish else { return }
            profile = savedProfile
        case .welcome, .habit, .finish: break
        }
        isShowingHabitForm = false
        errorMessage = nil
        step = next
    }

    func requestHabitCreation() {
        guard !didFinish, step == .habit else { return }
        do {
            guard try canCreateFirstHabit() else { return }
            errorMessage = nil
            isShowingHabitForm = true
        } catch { handle(error) }
    }

    func createHabit(_ draft: HabitDraft, at date: Date = Date()) {
        guard !didFinish, step == .habit else { return }
        do {
            guard try canCreateFirstHabit() else { return }
            // The repository atomically saves the habit, schedule and optional
            // quantity/smaller-action configuration. Nothing is logged here.
            firstHabit = try habits.createHabit(draft, at: date)
            isShowingHabitForm = false
            errorMessage = nil
            step = .companion
        } catch { handle(error) }
    }

    func finish() {
        guard step == .finish else { return }
        completeSetup()
    }

    /// Early exit accepts no unconfirmed companion edits and creates no goals.
    func exploreFirst() { completeSetup() }

    private func completeSetup() {
        guard !didFinish, ensureProfileLoaded(), !didFinish else { return }
        do {
            var completed = savedProfile
            completed.onboardingCompleted = true
            try profiles.save(completed)
            savedProfile = completed
            profile = completed
            isShowingHabitForm = false
            step = .finish
            didFinish = true
            errorMessage = nil
        } catch { handle(error) }
    }

    private func ensureProfileLoaded() -> Bool {
        if !hasLoadedProfile { load() }
        return hasLoadedProfile
    }

    private func canCreateFirstHabit() throws -> Bool {
        guard firstHabit == nil else {
            errorMessage = "Your first habit is already ready. You can add more from Today."
            return false
        }
        let active = try habits.fetchHabits(includeArchived: false)
        guard habitCreationAllowed(active.count) else {
            errorMessage = "Free includes 3 active habits. Continue to Today to explore Premium, or use an existing habit."
            return false
        }
        guard active.isEmpty else {
            firstHabit = active.first
            errorMessage = "Your first habit is already ready. You can add more from Today."
            return false
        }
        return true
    }

    private func handle(_ error: Error) {
        Logger(subsystem: "com.example.Avela", category: "Onboarding").error("Onboarding operation failed: \(String(describing: error), privacy: .private)")
        errorMessage = "Couldn't save your changes. Please try again."
    }
}
