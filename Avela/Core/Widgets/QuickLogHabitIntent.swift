import AppIntents
import Foundation
import WidgetKit

/// Apple's app-process marker lets WidgetKit invoke the canonical app writer
/// in the background. No Live Activity is started by this intent.
struct QuickLogHabitIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Log an Avela check-in"
    static var description = IntentDescription("Log today's simple check-in from an Avela widget.")
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @Parameter(title: "Habit") var habitID: String
    @Parameter(title: "Day") var dayKey: String
    @Parameter(title: "Time Zone") var timeZone: String
    @Parameter(title: "Configuration") var revision: Int

    init() {}
    init(habitID: UUID, dayKey: String, timeZone: String, revision: Int) {
        self.habitID = habitID.uuidString
        self.dayKey = dayKey
        self.timeZone = timeZone
        self.revision = revision
    }

    @MainActor
    func perform() async throws -> IntentResultContainer<Never, Never, Never, Never> {
        #if AVELA_WIDGET_EXTENSION
        // If the system cannot route to the app, never simulate a save.
        throw QuickLogIntentError.unavailable
        #else
        #if DEBUG
        guard ProcessInfo.processInfo.environment["AVELA_UI_TEST_STORE_PATH"] == nil else {
            throw QuickLogIntentError.unavailable
        }
        #endif
        let store = WidgetSnapshotStore()
        let previous = try? store.load()
        var logged = false
        do {
            guard let id = UUID(uuidString: habitID) else { throw QuickLogIntentError.unavailable }
            let context = try AppPersistence.liveContainer.get().mainContext
            let habits = SwiftDataHabitRepository(modelContext: context, calendar: .autoupdatingCurrent)
            let activities = SwiftDataHabitActivityRepository(context: context, habits: habits)
            let result = try QuickLogService(habits: habits, activities: activities)
                .log(habitID: id, dayKey: dayKey, timeZone: timeZone, revision: revision)
            logged = result != .needsApp
            let now = Date()
            let pinned = previous.flatMap { snapshot in
                snapshot.isCurrent(asOf: now, calendar: .autoupdatingCurrent)
                    ? Array(QuickLogProjection(snapshot: snapshot, date: now).orderedHabits.prefix(4).map(\.id)) : nil
            }
            try WidgetSnapshotExporter(store: store).export(
                habits: habits, attention: SwiftDataAttentionRepository(modelContext: context),
                profiles: SwiftDataCompanionProfileRepository(modelContext: context),
                activity: activities, routines: SwiftDataRoutineRepository(modelContext: context, habits: habits), theme: try SwiftDataAppearanceRepository(context: context).theme(),
                pinnedIDs: logged ? pinned : nil,
                pinUntil: logged ? now.addingTimeInterval(30) : nil,
                message: logged ? nil : "Open Avela to review this check-in", asOf: now)
        } catch {
            // Completed state is only ever exported from saved records. If a
            // save or projection failed, retain facts and give a recovery path.
            if var snapshot = previous {
                snapshot.quickLogMessage = logged ? "Open Avela to refresh" : "Open Avela to retry"
                try? store.save(snapshot)
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
        return .result()
        #endif
    }
}

private enum QuickLogIntentError: Error { case unavailable }

/// User-initiated refresh after midnight needs no foreground visit and never
/// evaluates schedules or opens a database inside the extension.
struct RefreshQuickLogIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Refresh Avela habits"
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @MainActor
    func perform() async throws -> IntentResultContainer<Never, Never, Never, Never> {
        #if AVELA_WIDGET_EXTENSION
        throw QuickLogIntentError.unavailable
        #else
        #if DEBUG
        guard ProcessInfo.processInfo.environment["AVELA_UI_TEST_STORE_PATH"] == nil else {
            throw QuickLogIntentError.unavailable
        }
        #endif
        let store = WidgetSnapshotStore()
        do {
            let context = try AppPersistence.liveContainer.get().mainContext
            let habits = SwiftDataHabitRepository(modelContext: context)
            try WidgetSnapshotExporter(store: store).export(
                habits: habits, attention: SwiftDataAttentionRepository(modelContext: context),
                profiles: SwiftDataCompanionProfileRepository(modelContext: context),
                activity: SwiftDataHabitActivityRepository(context: context, habits: habits),
                routines: SwiftDataRoutineRepository(modelContext: context, habits: habits),
                theme: try SwiftDataAppearanceRepository(context: context).theme())
        } catch {
            // Keep the refresh/open-app paths rather than manufacture an empty
            // list or update the date on yesterday's facts after a read failure.
            WidgetCenter.shared.reloadAllTimelines()
        }
        return .result()
        #endif
    }
}

// Configuration reads only the app-exported projection, in either process.
// Routine names/IDs are visible only in the system's explicit widget picker.
struct WidgetRoutineEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Routine"
    static var defaultQuery = WidgetRoutineQuery()
    let id: UUID
    let name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct WidgetRoutineQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [WidgetRoutineEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }
    func suggestedEntities() async throws -> [WidgetRoutineEntity] {
        (try WidgetSnapshotStore().load()?.routines ?? []).map { WidgetRoutineEntity(id: $0.id, name: $0.name) }
    }
}

struct RoutineWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose your routine"
    static var description = IntentDescription("Follow one saved routine from your Home Screen.")
    @Parameter(title: "Routine") var routine: WidgetRoutineEntity?
    static var parameterSummary: some ParameterSummary { Summary("Show \(\.$routine)") }
}
