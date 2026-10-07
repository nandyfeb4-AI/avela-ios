import Foundation
import Observation

struct IntentionSessionHistoryRow: Identifiable {
    var id: UUID { session.id }
    let session: AttentionSession
    let goalName: String
    var isFocusSession = false

    var outcomeLabel: String {
        if let outcome = session.outcome {
            return outcome == .kept ? (isFocusSession ? "Focused · reported manually" : "Kept · reported manually") : "Interrupted · reported manually"
        }
        return "Awaiting your check-in"
    }
}

@MainActor @Observable
final class IntentionSessionViewModel {
    let habitID: UUID
    var creationAllowed: (Int) -> Bool = { PremiumAccessPolicy.canCreateAttentionGoal(activeCount: $0, hasPremium: false) }
    private let habits: any HabitRepository
    private let attention: any AttentionRepository
    private let links: any IntentionSessionLinkRepository
    private(set) var habitName = ""
    private(set) var whyMemory: String?
    private(set) var habitAvailable = false
    private(set) var goals: [AttentionGoal] = []
    private(set) var selectedTargetMinutes: Double?
    private(set) var history: [IntentionSessionHistoryRow] = []
    private(set) var currentWeekSessionCount = 0
    private(set) var startedSessionGoalID: UUID?
    private(set) var startedSessionID: UUID?
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
            whyMemory = habit.isWhyMemoryHidden ? nil : habit.whyItMatters
            habitAvailable = !habit.isArchived
            goals = try attention.fetchGoals().filter { $0.type.isTimedSession }
            if !goals.contains(where: { $0.id == selectedGoalID }) { selectedGoalID = goals.first?.id }
            updateSelectedTarget(asOf: date)
            var rows: [IntentionSessionHistoryRow] = []
            let storedLinks = try links.links(for: habitID)
            for goal in goals {
                let linkedIDs = Set(storedLinks.map(\.sessionID))
                rows += try attention.sessions(for: goal.id).filter { linkedIDs.contains($0.id) }.map {
                    IntentionSessionHistoryRow(session: $0, goalName: goal.name, isFocusSession: goal.type == .focusSession)
                }
            }
            history = rows.sorted { $0.session.startedAt > $1.session.startedAt }
            let week = LocalDay.weekInterval(containing: date, calendar: .autoupdatingCurrent)
            currentWeekSessionCount = Set(rows.filter {
                $0.session.startedAt >= week.start && $0.session.startedAt < week.end && $0.session.startedAt <= date
            }.map(\.id)).count
            if startedSessionID == nil, let active = history.first(where: { $0.session.isActive }) {
                startedSessionGoalID = active.session.attentionGoalID
                startedSessionID = active.id
            }
        } catch {
            habitAvailable = false
            errorMessage = "Couldn't load your intentions. Please try again."
        }
    }

    func hideWhyMemory(asOf date: Date = Date()) {
        do {
            guard let habit = try habits.fetchHabit(id: habitID) else { return }
            _ = try habits.updateHabit(id: habitID, with: HabitDraft(name: habit.name,
                iconName: habit.iconName, category: habit.category, polarity: habit.polarity,
                schedule: habit.schedule, whyItMatters: habit.whyItMatters, isWhyMemoryHidden: true), at: date)
            load(asOf: date)
        } catch { errorMessage = "Couldn't hide your reminder. Please try again." }
    }

    /// Starting is an explicit action. Two repositories mean link persistence is
    /// a second write: if it fails, disclose the started session and preserve a
    /// path to review it, instead of inviting a duplicate retry or hiding it.
    @discardableResult
    func start(asOf date: Date = Date()) -> Bool {
        do {
            guard let habit = try habits.fetchHabit(id: habitID), !habit.isArchived,
                  let goalID = selectedGoalID, let goal = try attention.fetchGoal(id: goalID),
                  goal.type.isTimedSession else {
                errorMessage = "This habit or session goal is no longer available. Refresh before starting."
                load(asOf: date)
                return false
            }
            let session = try attention.startSession(goalID: goalID, at: date)
            startedSessionGoalID = goalID
            startedSessionID = session.id
            do {
                try links.save(IntentionSessionLink(id: UUID(), habitID: habitID, sessionID: session.id, createdAt: date))
            } catch {
                errorMessage = "Your session started, but its habit intention wasn't saved. Open the session below to manage it. No habit was completed."
            }
            load(asOf: date)
            return true
        } catch AttentionRepositoryError.sessionAlreadyActive {
            startedSessionGoalID = selectedGoalID
            errorMessage = "A session is already running for this goal. Open it below to review it before starting another."
        } catch {
            errorMessage = "Couldn't start the session. Please try again."
        }
        return false
    }

    var selectedSessionType: AttentionGoalType? {
        goals.first(where: { $0.id == selectedGoalID })?.type
    }

    func createSessionGoal(_ draft: AttentionGoalDraft, asOf date: Date = Date()) {
        do {
            guard let habit = try habits.fetchHabit(id: habitID), !habit.isArchived,
                  draft.type.isTimedSession else {
                errorMessage = "Choose a focus or phone-free session for an active habit."
                return
            }
            guard creationAllowed(try attention.fetchGoals().count) else {
                errorMessage = "Your plan's attention goal limit has been reached. Use an existing session goal or manage Premium in Settings."
                return
            }
            let goal = try attention.createGoal(draft, at: date)
            selectedGoalID = goal.id
            load(asOf: date)
        } catch { errorMessage = "Couldn't create the session goal. Please try again." }
    }

    var habitsRepository: any HabitRepository { habits }

    func detailModel(goalID: UUID) -> AttentionWindowDetailViewModel {
        AttentionWindowDetailViewModel(goalID: goalID, repository: attention)
    }

    private func updateSelectedTarget(asOf date: Date = Date()) {
        guard let selectedGoalID else { selectedTargetMinutes = nil; return }
        selectedTargetMinutes = (try? attention.activeConfiguration(for: selectedGoalID, on: date))?.targetValue
    }
}
