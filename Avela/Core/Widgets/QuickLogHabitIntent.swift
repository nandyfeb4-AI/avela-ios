import AppIntents
import Foundation
import WidgetKit
#if DEBUG
import OSLog
#endif

/// Apple's app-process marker lets WidgetKit invoke the canonical app writer
/// in the background. No Live Activity is started by this intent.
struct QuickLogHabitIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Log a Rilova check-in"
    static var description = IntentDescription("Log today's simple check-in from a Rilova widget.")
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @Parameter(title: "Habit") var habitID: String
    @Parameter(title: "Day") var dayKey: String
    @Parameter(title: "Time Zone") var timeZone: String
    @Parameter(title: "Configuration") var revision: Int
    @Parameter(title: "Displayed habits") var displayedHabitIDs: [String]

    init() {}
    init(habitID: UUID, dayKey: String, timeZone: String, revision: Int, displayedHabitIDs: [UUID] = []) {
        self.habitID = habitID.uuidString
        self.dayKey = dayKey
        self.timeZone = timeZone
        self.revision = revision
        self.displayedHabitIDs = displayedHabitIDs.map(\.uuidString)
    }

    @MainActor
    func perform() async throws -> IntentResultContainer<Never, Never, Never, Never> {
        try performQuickLogChange(habitID: habitID, dayKey: dayKey,
            timeZone: timeZone, revision: revision, displayedHabitIDs: displayedHabitIDs)
    }
}

/// Explicit reversal of the exact saved check-in offered by a widget button.
struct UndoQuickLogHabitIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Undo a Rilova check-in"
    static var description = IntentDescription("Undo the displayed simple check-in for today.")
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @Parameter(title: "Habit") var habitID: String
    @Parameter(title: "Check-in") var completionID: String
    @Parameter(title: "Day") var dayKey: String
    @Parameter(title: "Time Zone") var timeZone: String
    @Parameter(title: "Configuration") var revision: Int
    @Parameter(title: "Displayed habits") var displayedHabitIDs: [String]

    init() {}
    init(habitID: UUID, completionID: UUID, dayKey: String, timeZone: String, revision: Int, displayedHabitIDs: [UUID] = []) {
        self.habitID = habitID.uuidString
        self.completionID = completionID.uuidString
        self.dayKey = dayKey
        self.timeZone = timeZone
        self.revision = revision
        self.displayedHabitIDs = displayedHabitIDs.map(\.uuidString)
    }

    @MainActor
    func perform() async throws -> IntentResultContainer<Never, Never, Never, Never> {
        guard let id = UUID(uuidString: completionID) else { throw QuickLogIntentError.unavailable }
        return try performQuickLogChange(habitID: habitID, dayKey: dayKey,
            timeZone: timeZone, revision: revision, completionID: id, displayedHabitIDs: displayedHabitIDs)
    }
}

/// Both actions share the app-owned writer and publish only committed facts.
@MainActor
private func performQuickLogChange(habitID: String, dayKey: String, timeZone: String,
                                  revision: Int, completionID: UUID? = nil, displayedHabitIDs: [String] = []) throws
    -> IntentResultContainer<Never, Never, Never, Never> {
    #if DEBUG
    let diagnostic = Logger(subsystem: "com.example.Avela", category: "WidgetCheckIn")
    diagnostic.notice("Widget action received; undo=\(completionID != nil, privacy: .public)")
    #endif
    #if AVELA_WIDGET_EXTENSION
    #if DEBUG
    diagnostic.error("Widget action was routed to extension instead of app")
    #endif
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
    var accepted = false
    do {
        guard let id = UUID(uuidString: habitID) else { throw QuickLogIntentError.unavailable }
        let context = try AppPersistence.liveContainer.get().mainContext
        let habits = SwiftDataHabitRepository(modelContext: context, calendar: .autoupdatingCurrent)
        let activities = SwiftDataHabitActivityRepository(context: context, habits: habits)
        let service = QuickLogService(habits: habits, activities: activities)
        if let completionID {
            let outcome = try service.undo(habitID: id, completionID: completionID,
                dayKey: dayKey, timeZone: timeZone, revision: revision)
            accepted = outcome != .needsApp
            if outcome == .alreadyUndone,
               previous?.alreadyShowsUndone(habitID: id, asOf: Date(), calendar: .autoupdatingCurrent) == true {
                // WidgetKit reloads this widget after perform returns. The first
                // action already published the deletion; don't restart its refresh.
                return .result()
            }
            #if DEBUG
            diagnostic.notice("Undo outcome: \(String(describing: outcome), privacy: .public)")
            #endif
        } else {
            accepted = try service.log(habitID: id, dayKey: dayKey,
                timeZone: timeZone, revision: revision) != .needsApp
        }
        let now = Date()
        let pinned = previous.flatMap { snapshot -> [UUID]? in
            guard snapshot.isCurrent(asOf: now, calendar: .autoupdatingCurrent) else { return nil }
            let knownIDs = Set(snapshot.habits.map(\.id))
            var seen = Set<UUID>()
            let displayed = displayedHabitIDs.compactMap(UUID.init(uuidString:))
                .filter { knownIDs.contains($0) && seen.insert($0).inserted }
            return displayed.isEmpty
                ? Array(QuickLogProjection(snapshot: snapshot, date: now).orderedHabits.prefix(4).map(\.id))
                : Array(displayed.prefix(4))
        }
        try WidgetSnapshotExporter(store: store).export(
            habits: habits, attention: SwiftDataAttentionRepository(modelContext: context),
            profiles: SwiftDataCompanionProfileRepository(modelContext: context),
            activity: activities, routines: SwiftDataRoutineRepository(modelContext: context, habits: habits), theme: try SwiftDataAppearanceRepository(context: context).theme(),
            pinnedIDs: accepted ? pinned : nil,
            pinUntil: accepted ? now.addingTimeInterval(30) : nil,
            message: accepted ? nil : "Open Rilova to review this check-in", reloadTimelines: false, asOf: now)
        #if DEBUG
        diagnostic.notice("Widget saved facts exported")
        #endif
    } catch {
        #if DEBUG
        diagnostic.error("Widget action failed before publishing saved facts; accepted=\(accepted, privacy: .public)")
        #endif
        // Completed state is only ever exported from saved records. If a
        // save or projection failed, retain facts and give a recovery path.
        if var snapshot = previous {
            snapshot.quickLogMessage = accepted ? "Open Rilova to refresh" : "Open Rilova to retry"
            try? store.save(snapshot)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
    return .result()
    #endif
}

private enum QuickLogIntentError: Error { case unavailable }

/// User-initiated refresh after midnight needs no foreground visit and never
/// evaluates schedules or opens a database inside the extension.
struct RefreshQuickLogIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Refresh Rilova habits"
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
        let now = Date()
        let calendar = Calendar.current
        let previous = try? store.load()
        let acknowledgment = previous.flatMap { snapshot -> WidgetSnapshot? in
            guard snapshot.isCurrent(asOf: now, calendar: calendar),
                  snapshot.generatedAt <= now,
                  LocalDay.key(for: snapshot.generatedAt, calendar: calendar) == snapshot.localDateKey,
                  let until = snapshot.quickLogPinUntil,
                  until > now,
                  until <= snapshot.generatedAt.addingTimeInterval(30),
                  snapshot.quickLogPinnedIDs != nil else { return nil }
            return snapshot
        }
        do {
            let context = try AppPersistence.liveContainer.get().mainContext
            let habits = SwiftDataHabitRepository(modelContext: context)
            try WidgetSnapshotExporter(store: store).export(
                habits: habits, attention: SwiftDataAttentionRepository(modelContext: context),
                profiles: SwiftDataCompanionProfileRepository(modelContext: context),
                activity: SwiftDataHabitActivityRepository(context: context, habits: habits),
                routines: SwiftDataRoutineRepository(modelContext: context, habits: habits),
                theme: try SwiftDataAppearanceRepository(context: context).theme(),
                // A status tap retains an existing acknowledgment window; it
                // never restarts the countdown or pins yesterday's rows.
                pinnedIDs: acknowledgment?.quickLogPinnedIDs,
                pinUntil: acknowledgment?.quickLogPinUntil,
                asOf: now, calendar: calendar)
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
