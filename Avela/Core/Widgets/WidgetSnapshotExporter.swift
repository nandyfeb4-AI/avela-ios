import Foundation
import WidgetKit

/// Call after app mutations and foreground refresh. Snapshot failure must
/// never roll back an otherwise successful user-data write.
@MainActor
struct WidgetSnapshotExporter {
    private let store: WidgetSnapshotStore

    init(store: WidgetSnapshotStore = WidgetSnapshotStore()) {
        self.store = store
    }

    func export(
        habits: [WidgetHabitSnapshot], attentionGoals: [WidgetAttentionSnapshot],
        companionAnimal: String? = nil, companionState: String? = nil,
        asOf date: Date = Date(), calendar: Calendar = .current
    ) throws {
        try store.save(WidgetSnapshot(
            localDateKey: LocalDay.key(for: date, calendar: calendar), generatedAt: date,
            habits: habits, attentionGoals: attentionGoals,
            companionAnimal: companionAnimal, companionState: companionState
        ))
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Reuse the app's display composition rather than duplicate scheduling
    /// or attention-threshold rules inside the widget boundary.
    func export(
        habits habitRepository: HabitRepository, attention attentionRepository: AttentionRepository,
        profiles: CompanionProfileRepository? = nil,
        asOf date: Date = Date(), calendar: Calendar = .current
    ) throws {
        let today = TodayViewModel(repository: habitRepository, calendar: calendar)
        let attention = AttentionSummaryViewModel(repository: attentionRepository, calendar: calendar)
        today.load(asOf: date)
        attention.load(asOf: date)
        guard today.errorMessage == nil, attention.errorMessage == nil else {
            throw WidgetSnapshotError.projectionUnavailable
        }
        let profile = try profiles?.profile()
        let companionEnabled = profile?.companionEnabled == true
        let input = CompanionInput(
            loggedAttentionStates: attention.rows.filter { $0.goalType == .maxDurationPerDay }.compactMap(\.state),
            attentionGoalCount: attention.rows.count,
            isRecovering: today.rows.contains { $0.recoveryContext != nil },
            // A saved completion is not a new completion event. Widgets do
            // not persist Today's temporary celebration/undo-toast state.
            meaningfulCompletion: false,
            hasActiveSession: attention.hasActiveSession,
            completedHabits: today.rows.filter(\.isCompletedToday).count,
            dueHabits: today.rows.count
        )
        try export(
            habits: today.rows.map {
                WidgetHabitSnapshot(id: $0.id, name: $0.name, iconName: $0.iconName,
                    isCompletedToday: $0.isCompletedToday,
                    progressLabel: $0.weeklyProgress.map { "\($0.completed)/\($0.target) this week" } ?? $0.scheduleDescription)
            },
            attentionGoals: attention.rows.filter { $0.goalType == .maxDurationPerDay }.map {
                WidgetAttentionSnapshot(id: $0.id, name: $0.name, statusLabel: $0.statusLabel, hasLoggedUsage: $0.state != nil)
            },
            companionAnimal: companionEnabled ? profile?.selectedAnimal.rawValue : nil,
            companionState: companionEnabled ? CompanionStateEngine.state(for: input).rawValue : nil,
            asOf: date, calendar: calendar
        )
    }
}
