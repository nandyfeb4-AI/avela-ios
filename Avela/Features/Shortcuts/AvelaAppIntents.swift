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

struct AvelaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogHabitProgressIntent(), phrases: ["Log habit progress in \(.applicationName)"],
            shortTitle: "Log Progress", systemImageName: "plus.circle")
        AppShortcut(intent: CompleteHabitIntent(), phrases: ["Log a habit in \(.applicationName)"],
            shortTitle: "Log Habit", systemImageName: "checkmark.circle")
        AppShortcut(intent: LogAttentionMinutesIntent(), phrases: ["Log attention in \(.applicationName)"],
            shortTitle: "Log Attention", systemImageName: "hourglass")
    }
}
