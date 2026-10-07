import Foundation
import Observation
import SwiftUI

@Observable @MainActor
final class ManageableWeekViewModel {
    struct Row: Identifiable {
        let habit: Habit
        let smallerAction: String?
        var id: UUID { habit.id }
    }
    private let habits: any HabitRepository
    private let activities: any HabitActivityRepository
    private let routines: any RoutineRepository
    var rows: [Row] = []
    var focusIDs: Set<UUID> = []
    var errorMessage: String?
    var confirmationMessage: String?
    var createdPlan: HabitRoutine?

    init(habits: any HabitRepository, activities: any HabitActivityRepository, routines: any RoutineRepository) {
        self.habits = habits
        self.activities = activities
        self.routines = routines
    }

    func load(asOf date: Date = Date()) {
        do {
            rows = try habits.fetchHabits(includeArchived: false).map { habit in
                let action = try activities.configuration(for: habit.id, on: date)?.smallerAction ?? ""
                return Row(habit: habit, smallerAction: action.isEmpty ? nil : action)
            }
            focusIDs.formIntersection(Set(rows.map(\.id)))
        } catch { errorMessage = "Your habits couldn’t be loaded. Please try again." }
    }

    @discardableResult
    func pause(id: UUID, at date: Date = Date()) -> Bool {
        errorMessage = nil
        do {
            guard let habit = try habits.fetchHabit(id: id), !habit.isArchived else {
                errorMessage = "This habit has changed. Refresh before pausing it."
                load(asOf: date)
                return false
            }
            try habits.archiveHabit(id: id, at: date)
            confirmationMessage = "\(habit.name) is paused. Its history is kept. Reactivate it in Settings → Archived Habits when you’re ready."
            focusIDs.remove(id)
            load(asOf: date)
            NotificationCenter.default.post(name: .avelaPersistenceDidChange, object: nil)
            return true
        } catch { errorMessage = "This habit couldn’t be paused. Nothing else was changed."; return false }
    }

    @discardableResult
    func createPlan(days: Int, at date: Date = Date()) -> Bool {
        errorMessage = nil
        do {
            let ids = rows.filter { focusIDs.contains($0.id) }.map(\.id)
            createdPlan = try routines.save(id: nil, name: "A Gentle Restart", habitIDs: ids, restartDays: days, at: date)
            confirmationMessage = "Your restart plan is ready. Other habits, targets and streak rules are unchanged."
            return true
        } catch { errorMessage = "Your restart plan couldn’t be saved. Reopen this screen to refresh your habits; nothing was paused or logged."; return false }
    }
}

/// A read-only review until each individual named pause or restart confirmation.
/// Pauses are intentionally one at a time, avoiding a misleading batch transaction.
struct ManageableWeekView: View {
    @State private var model: ManageableWeekViewModel
    private let habits: any HabitRepository
    let onLogHabit: (UUID) -> Void
    @Environment(\.habitReminderService) private var reminders
    @State private var pauseCandidate: ManageableWeekViewModel.Row?
    @State private var planDays: Int?

    init(habits: any HabitRepository, activities: any HabitActivityRepository, routines: any RoutineRepository, onLogHabit: @escaping (UUID) -> Void) {
        _model = State(initialValue: ManageableWeekViewModel(habits: habits, activities: activities, routines: routines))
        self.habits = habits
        self.onLogHabit = onLogHabit
    }

    var body: some View {
        List {
            Section {
                Label("Make room for this week", systemImage: "leaf")
                    .font(.title2.bold()).accessibilityAddTraits(.isHeader)
                Text("Keep what feels manageable. Pause one habit at a time, or choose a short list to focus on. Reviewing this screen never changes your tracking.")
                    .foregroundStyle(.secondary)
            }
            if let message = model.confirmationMessage {
                Section { Label(message, systemImage: "checkmark.circle").foregroundStyle(.secondary) }
            }
            if model.rows.isEmpty {
                ContentUnavailableView("No Active Habits", systemImage: "leaf", description: Text("Create or reactivate a habit to build your restart plan."))
            }
            ForEach(model.rows) { row in
                Section {
                    Label(row.habit.name, systemImage: row.habit.iconName).font(.headline)
                    Toggle("Focus on this habit", isOn: Binding(
                        get: { model.focusIDs.contains(row.id) },
                        set: { selected in if selected { model.focusIDs.insert(row.id) } else { model.focusIDs.remove(row.id) } }
                    ))
                    .accessibilityIdentifier("manageWeek.focus.\(row.id.uuidString)")
                    .accessibilityLabel("Focus on \(row.habit.name)")
                    if let action = row.smallerAction {
                        Text("Smaller action: \(action)").foregroundStyle(.secondary)
                        Button {
                            onLogHabit(row.id)
                        } label: { Text("Open smaller-action check-in").frame(minHeight: 44) }
                        Text("Choosing a smaller action records it separately; it never counts as full success.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Button {
                        pauseCandidate = row
                    } label: { Text("Pause \(row.habit.name)").frame(minHeight: 44) }
                    .accessibilityIdentifier("manageWeek.pause.\(row.id.uuidString)")
                } footer: { Text("Leave this habit as it is by making no change. Pause retains history and requires confirmation.") }
            }
            if !model.rows.isEmpty {
                Section {
                    Button { planDays = 3 } label: { Text("Review 3-Day Restart").frame(minHeight: 44) }
                        .disabled(model.focusIDs.isEmpty).accessibilityIdentifier("manageWeek.restart3")
                    Button { planDays = 7 } label: { Text("Review 7-Day Restart").frame(minHeight: 44) }
                        .disabled(model.focusIDs.isEmpty).accessibilityIdentifier("manageWeek.restart7")
                } header: { Text("Start Small") } footer: {
                    Text("A restart groups only your chosen focus habits. It never pauses other habits, lowers a target, logs success or resets progress.")
                }
            }
            if let plan = model.createdPlan {
                NavigationLink("Open Your Restart Plan") {
                    RoutineRunView(model: RoutineRunViewModel(routine: plan, habits: habits), onLogHabit: onLogHabit)
                }
            }
        }
        .appThemeCanvas()
        .navigationTitle("A Manageable Week")
        .navigationBarTitleDisplayMode(.inline)
        .task { model.load() }
        .onReceive(NotificationCenter.default.publisher(for: .avelaPersistenceDidChange)) { _ in model.load() }
        .alert("Pause This Habit?", isPresented: Binding(get: { pauseCandidate != nil }, set: { if !$0 { pauseCandidate = nil } })) {
            Button("Pause \(pauseCandidate?.habit.name ?? "Habit")") {
                if let candidate = pauseCandidate, model.pause(id: candidate.id) {
                    Task { try? await reminders?.synchronize() }
                }
                pauseCandidate = nil
            }
            Button("Keep Habit", role: .cancel) { pauseCandidate = nil }
        } message: {
            Text("\(pauseCandidate?.habit.name ?? "This habit") will leave active tracking. Earlier progress remains; paused time adds no misses or successes. Reactivate it in Settings → Archived Habits. Your other habits stay unchanged.")
        }
        .alert("Create Your Restart?", isPresented: Binding(get: { planDays != nil }, set: { if !$0 { planDays = nil } })) {
            Button("Create \(planDays ?? 3)-Day Restart") {
                if let days = planDays { model.createPlan(days: days) }
                planDays = nil
            }
            Button("Cancel", role: .cancel) { planDays = nil }
        } message: {
            Text("Focus on \(model.rows.filter { model.focusIDs.contains($0.id) }.map { $0.habit.name }.joined(separator: ", ")) for \(planDays ?? 3) days. All habit schedules and existing records stay unchanged.")
        }
        .alert("Unable to Update", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
}
