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
        activity: HabitActivityRepository? = nil, routines: RoutineRepository? = nil, theme: AppTheme = .tidewater,
        pinnedIDs: [UUID]? = nil, pinUntil: Date? = nil, message: String? = nil,
        asOf date: Date = Date(), calendar: Calendar = .current
    ) throws {
        let today = TodayViewModel(repository: habitRepository, calendar: calendar)
        today.activityRepository = activity
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
        let rows = try today.rows.map { row in
            WidgetHabitSnapshot(id: row.id, name: row.name, iconName: row.iconName,
                isCompletedToday: row.isCompletedToday,
                progressLabel: row.quantityProgress ?? row.weeklyProgress.map { "\($0.completed)/\($0.target) this week" } ?? row.scheduleDescription,
                configurationRevision: try habitRepository.activeConfiguration(for: row.id, on: date)?.revision,
                requiresQuantityLogging: row.requiresQuantityLogging,
                isSkippedToday: row.isSkippedToday,
                checkInLabel: row.polarity == .avoidance ? "Log success" : "Log check-in",
                weeklyTargetMet: row.weeklyProgress.map { $0.completed >= $0.target } ?? false)
        }
        var snapshot = WidgetSnapshot(
            localDateKey: LocalDay.key(for: date, calendar: calendar), generatedAt: date,
            habits: rows,
            attentionGoals: attention.rows.filter { $0.goalType == .maxDurationPerDay }.map {
                WidgetAttentionSnapshot(id: $0.id, name: $0.name, statusLabel: $0.statusLabel, hasLoggedUsage: $0.state != nil)
            },
            companionAnimal: companionEnabled ? profile?.selectedAnimal.rawValue : nil,
            companionState: companionEnabled ? CompanionStateEngine.state(for: input).rawValue : nil
        )
        snapshot.routines = try routines?.routines().map {
            WidgetRoutineSnapshot(id: $0.id, name: $0.name, habitIDs: $0.habitIDs)
        }
        snapshot.timeZoneIdentifier = calendar.timeZone.identifier
        snapshot.accentLight = theme.lightAccent
        snapshot.accentDark = theme.darkAccent
        snapshot.quickLogPinnedIDs = pinnedIDs
        snapshot.quickLogPinUntil = pinUntil
        snapshot.quickLogMessage = message
        try store.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
