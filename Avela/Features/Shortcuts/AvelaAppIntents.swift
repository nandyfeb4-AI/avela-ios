import AppIntents
import OSLog

extension Notification.Name {
    static let avelaShortcutDidLog = Notification.Name("avelaShortcutDidLog")
}

/// This app-target adapter always uses the app's launch context. There is no
/// intent extension or App Group SwiftData store, and no additional writer.
@MainActor
enum ShortcutRepositories {
    static func service() throws -> ShortcutLoggingService {
        do {
            let context = try AppPersistence.liveContainer.get().mainContext
            let habits = SwiftDataHabitRepository(modelContext: context)
            return ShortcutLoggingService(habits: habits, attention: SwiftDataAttentionRepository(modelContext: context),
                activity: SwiftDataHabitActivityRepository(context: context, habits: habits))
        } catch { throw ShortcutLoggingError.storeUnavailable }
    }

    static func safely<T>(_ action: () throws -> T) throws -> T {
        do { return try action() }
        catch let error as ShortcutLoggingError { throw error }
        catch {
            Logger(subsystem: "com.example.Avela", category: "Shortcuts")
                .error("Shortcut failed: \(String(describing: error), privacy: .private)")
            throw ShortcutLoggingError.storeUnavailable
        }
    }
}

struct HabitShortcutEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Habit"
    static var defaultQuery = HabitShortcutQuery()
    let id: UUID
    let name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct HabitShortcutQuery: EntityStringQuery {
    @MainActor func entities(for identifiers: [UUID]) async throws -> [HabitShortcutEntity] {
        try entities().filter { identifiers.contains($0.id) }
    }
    @MainActor func entities(matching string: String) async throws -> [HabitShortcutEntity] {
        try entities().filter { $0.name.localizedStandardContains(string) }
    }
    @MainActor func suggestedEntities() async throws -> [HabitShortcutEntity] { try entities() }
    @MainActor private func entities() throws -> [HabitShortcutEntity] {
        try ShortcutRepositories.safely {
            try ShortcutRepositories.service().habits.fetchHabits(includeArchived: false)
                .map { HabitShortcutEntity(id: $0.id, name: $0.name) }
        }
    }
}

struct AttentionBudgetShortcutEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Attention Budget"
    static var defaultQuery = AttentionBudgetShortcutQuery()
    let id: UUID
    let name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct AttentionBudgetShortcutQuery: EntityStringQuery {
    @MainActor func entities(for identifiers: [UUID]) async throws -> [AttentionBudgetShortcutEntity] {
        try entities().filter { identifiers.contains($0.id) }
    }
    @MainActor func entities(matching string: String) async throws -> [AttentionBudgetShortcutEntity] {
        try entities().filter { $0.name.localizedStandardContains(string) }
    }
    @MainActor func suggestedEntities() async throws -> [AttentionBudgetShortcutEntity] { try entities() }
    @MainActor private func entities() throws -> [AttentionBudgetShortcutEntity] {
        try ShortcutRepositories.safely {
            try ShortcutRepositories.service().attention.fetchGoals()
                .filter { $0.type == .maxDurationPerDay }
                .map { AttentionBudgetShortcutEntity(id: $0.id, name: $0.name) }
        }
    }
}

struct CompleteHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Habit Success"
    static var description = IntentDescription("Log a selected habit for today. Repeating this action never undoes it.")
    static var openAppWhenRun = true
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    @Parameter(title: "Habit") var habit: HabitShortcutEntity
    static var parameterSummary: some ParameterSummary { Summary("Log success for \(\.$habit)") }

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let logged = try ShortcutRepositories.safely {
            try ShortcutRepositories.service().completeHabit(id: habit.id, at: Date())
        }
        NotificationCenter.default.post(name: .avelaShortcutDidLog, object: nil)
        // Do not speak private habit names by default.
        return .result(dialog: logged ? "Habit success logged for today." : "Already logged for today. Nothing changed.")
    }
}

struct LogAttentionMinutesIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Attention Minutes"
    static var description = IntentDescription("Add self-reported minutes to a daily attention budget. Each run adds a new entry.")
    static var openAppWhenRun = true
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    @Parameter(title: "Budget") var budget: AttentionBudgetShortcutEntity
    @Parameter(title: "Minutes") var minutes: Double
    static var parameterSummary: some ParameterSummary { Summary("Log \(\.$minutes) minutes for \(\.$budget)") }

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        try ShortcutRepositories.safely {
            try ShortcutRepositories.service().logMinutes(minutes, goalID: budget.id, at: Date())
        }
        NotificationCenter.default.post(name: .avelaShortcutDidLog, object: nil)
        return .result(dialog: "Self-reported attention minutes added for today.")
    }
}

struct LogHabitProgressIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Habit Progress"
    static var description = IntentDescription("Add an amount in the habit's configured unit (count, pages, glasses or minutes). Each run adds a new entry.")
    static var openAppWhenRun = true
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    @Parameter(title: "Habit") var habit: HabitShortcutEntity
    @Parameter(title: "Amount") var amount: Int
    static var parameterSummary: some ParameterSummary { Summary("Add \(\.$amount) to \(\.$habit)") }
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        try ShortcutRepositories.safely {
            let service = try ShortcutRepositories.service()
            guard let activity = service.activity, let config = try activity.configuration(for: habit.id, on: Date()), config.target != nil else { throw ShortcutLoggingError.quantityRequired }
            try activity.log(habitID: habit.id, kind: .quantity, amount: amount, expectedConfigurationID: config.id, on: Date(), now: Date())
        }
        NotificationCenter.default.post(name: .avelaShortcutDidLog, object: nil)
        return .result(dialog: "Progress added in your habit's configured unit.")
    }
}

struct SessionGoalShortcutEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Session Goal"
    static var defaultQuery = SessionGoalShortcutQuery()
    let id: UUID
    let name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct SessionGoalShortcutQuery: EntityStringQuery {
    @MainActor func entities(for identifiers: [UUID]) async throws -> [SessionGoalShortcutEntity] {
        try entities().filter { identifiers.contains($0.id) }
    }
    @MainActor func entities(matching string: String) async throws -> [SessionGoalShortcutEntity] {
        try entities().filter { $0.name.localizedStandardContains(string) }
    }
    @MainActor func suggestedEntities() async throws -> [SessionGoalShortcutEntity] { try entities() }
    @MainActor private func entities() throws -> [SessionGoalShortcutEntity] {
        try ShortcutRepositories.safely {
            try ShortcutRepositories.service().attention.fetchGoals().filter { $0.type.isTimedSession }
                .map { SessionGoalShortcutEntity(id: $0.id, name: $0.name) }
        }
    }
}

struct MakeRoomIntent: AppIntent {
    static var title: LocalizedStringResource = "Make Room for a Habit"
    static var description = IntentDescription("Start a chosen focus or phone-free session linked to a habit. This does not complete the habit or block apps.")
    static var openAppWhenRun = true
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    @Parameter(title: "Habit") var habit: HabitShortcutEntity
    @Parameter(title: "Session Goal") var goal: SessionGoalShortcutEntity
    static var parameterSummary: some ParameterSummary { Summary("Make room for \(\.$habit) with \(\.$goal)") }

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = try ShortcutRepositories.safely {
            let context = try AppPersistence.liveContainer.get().mainContext
            return IntentionSessionViewModel(habitID: habit.id,
                habits: SwiftDataHabitRepository(modelContext: context),
                attention: SwiftDataAttentionRepository(modelContext: context),
                links: SwiftDataIntentionSessionLinkRepository(modelContext: context))
        }
        model.load()
        model.selectedGoalID = goal.id
        guard model.start() else { throw MakeRoomShortcutError.startUnavailable }
        NotificationCenter.default.post(name: .avelaShortcutDidLog, object: nil)
        if model.errorMessage != nil {
            return .result(dialog: "Session started, but its habit link wasn't saved. Review it in Rilova. No habit was completed.")
        }
        return .result(dialog: "Session started. Log what you actually do separately; no habit was completed and no apps were blocked.")
    }
}

private enum MakeRoomShortcutError: LocalizedError {
    case startUnavailable
    var errorDescription: String? { "Couldn't start this session. It may already be running, or its habit or goal may be unavailable. Review Make Room in Rilova." }
}

struct AvelaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: MakeRoomIntent(), phrases: ["Make room for a habit in \(.applicationName)"],
            shortTitle: "Make Room", systemImageName: "timer")
        AppShortcut(intent: LogHabitProgressIntent(), phrases: ["Log habit progress in \(.applicationName)"],
            shortTitle: "Log Progress", systemImageName: "plus.circle")
        AppShortcut(intent: CompleteHabitIntent(), phrases: ["Log a habit in \(.applicationName)"],
            shortTitle: "Log Habit", systemImageName: "checkmark.circle")
        AppShortcut(intent: LogAttentionMinutesIntent(), phrases: ["Log attention in \(.applicationName)"],
            shortTitle: "Log Attention", systemImageName: "hourglass")
    }
}
