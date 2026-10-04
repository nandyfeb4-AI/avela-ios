import Foundation
import Observation
import OSLog

enum OnboardingStep: Int, CaseIterable {
    case welcome, habit, attention, companion, reminder, finish
}

@MainActor
@Observable
final class OnboardingViewModel {
    private(set) var step: OnboardingStep = .welcome
    var profile = CompanionProfile()
    private(set) var firstHabit: Habit?
    private(set) var hasAttentionGoal = false
    private(set) var didFinish = false
    var isShowingHabitForm = false
    var isShowingAttentionForm = false
    var errorMessage: String?
    let reminderService: HabitReminderService?
    private let habits: HabitRepository
    private let attention: AttentionRepository
    private let profiles: CompanionProfileRepository
    private let habitCreationAllowed: (Int) -> Bool
    private let attentionCreationAllowed: (Int) -> Bool

    init(habits: HabitRepository, attention: AttentionRepository,
         profiles: CompanionProfileRepository, reminderService: HabitReminderService? = nil,
         habitCreationAllowed: @escaping (Int) -> Bool = { _ in true },
         attentionCreationAllowed: @escaping (Int) -> Bool = { _ in true }) {
        self.habits = habits
        self.attention = attention
        self.profiles = profiles
        self.reminderService = reminderService
        self.habitCreationAllowed = habitCreationAllowed
        self.attentionCreationAllowed = attentionCreationAllowed
    }

    func load() {
        do {
            profile = try profiles.profile()
            firstHabit = try habits.fetchHabits(includeArchived: false).first
            hasAttentionGoal = try !attention.fetchGoals().isEmpty
        } catch { handle(error) }
    }

    func advance() {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        do {
            if step == .companion { try profiles.save(profile) }
            step = next
        } catch { handle(error) }
    }

    func createHabit(_ draft: HabitDraft, at date: Date = Date()) {
        do {
            guard habitCreationAllowed(try habits.fetchHabits(includeArchived: false).count) else {
                errorMessage = "Free includes 3 active habits. Continue to Today to explore Premium, or use an existing habit."
                return
            }
            firstHabit = try habits.createHabit(draft, at: date)
            isShowingHabitForm = false
            advance()
        } catch { handle(error) }
    }

    func requestHabitCreation() {
        do {
            guard habitCreationAllowed(try habits.fetchHabits(includeArchived: false).count) else {
                errorMessage = "Free includes 3 active habits. Continue to Today to explore Premium, or use an existing habit."
                return
            }
            isShowingHabitForm = true
        } catch { handle(error) }
    }

    func requestAttentionCreation() {
        do {
            guard attentionCreationAllowed(try attention.fetchGoals().count) else {
                errorMessage = "Free includes 1 attention goal. Continue to Today to explore Premium, or use your existing goal."
                return
            }
            isShowingAttentionForm = true
        } catch { handle(error) }
    }

    func createAttentionGoal(_ draft: AttentionGoalDraft, at date: Date = Date()) {
        do {
            guard attentionCreationAllowed(try attention.fetchGoals().count) else {
                errorMessage = "Free includes 1 attention goal. Continue to Today to explore Premium, or use your existing goal."
                return
            }
            _ = try attention.createGoal(draft, at: date)
            hasAttentionGoal = true
            isShowingAttentionForm = false
            advance()
        } catch { handle(error) }
    }

    func finish() {
        do {
            var completed = profile
            completed.onboardingCompleted = true
            try profiles.save(completed)
            profile = completed
            didFinish = true
        } catch { handle(error) }
    }

    private func handle(_ error: Error) {
        Logger(subsystem: "com.example.Avela", category: "Onboarding").error("Onboarding operation failed: \(String(describing: error), privacy: .private)")
        errorMessage = "Couldn't save your changes. Please try again."
    }
}
