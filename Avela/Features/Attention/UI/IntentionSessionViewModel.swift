import Foundation
import Observation

struct IntentionSessionHistoryRow: Identifiable {
    var id: UUID { session.id }
    let session: AttentionSession
    let goalName: String

    var outcomeLabel: String {
        if let outcome = session.outcome {
            return outcome == .kept ? "Kept · reported manually" : "Interrupted · reported manually"
        }
        return "Awaiting your check-in"
    }
}

@MainActor @Observable
final class IntentionSessionViewModel {
    let habitID: UUID
    private let habits: any HabitRepository
    private let attention: any AttentionRepository
    private let links: any IntentionSessionLinkRepository
    private(set) var habitName = ""
    private(set) var habitAvailable = false
    private(set) var goals: [AttentionGoal] = []
    private(set) var selectedTargetMinutes: Double?
    private(set) var history: [IntentionSessionHistoryRow] = []
    private(set) var startedSessionGoalID: UUID?
    var selectedGoalID: UUID? { didSet { updateSelectedTarget() } }
    var errorMessage: String?

    init(habitID: UUID, habits: any HabitRepository, attention: any AttentionRepository,
         links: any IntentionSessionLinkRepository) {
        self.habitID = habitID
        self.habits = habits
        self.attention = attention
        self.links = links
    }

    func load(asOf date: Date = Date()) {
        do {
            guard let habit = try habits.fetchHabit(id: habitID) else {
                habitAvailable = false
                return
            }
            habitName = habit.name
            habitAvailable = !habit.isArchived
            goals = try attention.fetchGoals().filter { $0.type == .phoneFreeSession }
            if !goals.contains(where: { $0.id == selectedGoalID }) { selectedGoalID = goals.first?.id }
            updateSelectedTarget(asOf: date)
            var rows: [IntentionSessionHistoryRow] = []
            let storedLinks = try links.links(for: habitID)
            for goal in goals {
                let linkedIDs = Set(storedLinks.map(\.sessionID))
                rows += try attention.sessions(for: goal.id).filter { linkedIDs.contains($0.id) }.map {
                    IntentionSessionHistoryRow(session: $0, goalName: goal.name)
                }
            }
            history = rows.sorted { $0.session.startedAt > $1.session.startedAt }
        } catch {
            habitAvailable = false
            errorMessage = "Couldn't load your intentions. Please try again."
        }
    }

    /// Starting is an explicit action. Two repositories mean link persistence is
    /// a second write: if it fails, disclose the started session and preserve a
    /// path to review it, instead of inviting a duplicate retry or hiding it.
    func start(asOf date: Date = Date()) {
        do {
            guard let habit = try habits.fetchHabit(id: habitID), !habit.isArchived,
                  let goalID = selectedGoalID, let goal = try attention.fetchGoal(id: goalID),
                  goal.type == .phoneFreeSession else {
                errorMessage = "This habit or session goal is no longer available. Refresh before starting."
                load(asOf: date)
                return
            }
            let session = try attention.startSession(goalID: goalID, at: date)
            startedSessionGoalID = goalID
            do {
                try links.save(IntentionSessionLink(id: UUID(), habitID: habitID, sessionID: session.id, createdAt: date))
            } catch {
                errorMessage = "Your phone-free session started, but its habit intention wasn't saved. Open the session below to manage it. No habit was completed."
            }
            load(asOf: date)
        } catch AttentionRepositoryError.sessionAlreadyActive {
            startedSessionGoalID = selectedGoalID
            errorMessage = "A session is already running for this goal. Open it below to review it before starting another."
        } catch {
            errorMessage = "Couldn't start the session. Please try again."
        }
    }

    func detailModel(goalID: UUID) -> AttentionWindowDetailViewModel {
        AttentionWindowDetailViewModel(goalID: goalID, repository: attention)
    }

    private func updateSelectedTarget(asOf date: Date = Date()) {
        guard let selectedGoalID else { selectedTargetMinutes = nil; return }
        selectedTargetMinutes = (try? attention.activeConfiguration(for: selectedGoalID, on: date))?.targetValue
    }
}
