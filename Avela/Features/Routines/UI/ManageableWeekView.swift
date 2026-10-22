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
    @Environment(\.appPalette) private var palette
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
                VStack(alignment: .leading, spacing: 14) {
                    Label("A little more room.", systemImage: "leaf.fill")
                        .font(.largeTitle.weight(.bold)).fontDesign(.rounded)
                        .foregroundStyle(.white).accessibilityAddTraits(.isHeader)
                    Text("Your day can change. Choose a smaller step, pause one habit, or make a short restart list.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.84))
                        .fixedSize(horizontal: false, vertical: true)
                    Label("Your earlier progress stays with you.", systemImage: "checkmark.shield")
                        .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.9))
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { RilovaAurora() }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
            if let message = model.confirmationMessage {
                Section {
                    Label(message, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(palette.accent)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("manageWeek.confirmation")
                }
            }
            if model.rows.isEmpty {
                ContentUnavailableView("No Active Habits", systemImage: "leaf", description: Text("Create or reactivate a habit to build your restart plan."))
            }
            ForEach(model.rows) { row in
                Section {
                    HStack(spacing: 12) {
                        HabitIconBadge(symbol: row.habit.iconName).accessibilityHidden(true)
                        Text(row.habit.name).font(.title3.weight(.bold)).fontDesign(.rounded)
                            .foregroundStyle(Color.appInk)
                    }.padding(.vertical, 4)
                    Toggle("Include in my restart", isOn: Binding(
                        get: { model.focusIDs.contains(row.id) },
                        set: { selected in if selected { model.focusIDs.insert(row.id) } else { model.focusIDs.remove(row.id) } }
                    ))
                    .accessibilityIdentifier("manageWeek.focus.\(row.id.uuidString)")
                    .accessibilityLabel("Focus on \(row.habit.name)")
                    if let action = row.smallerAction {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("THE SMALLER STEP").font(.caption2.weight(.semibold)).tracking(1)
                                .foregroundStyle(Color.appInkSecondary)
                            Text(action).font(.title3.weight(.semibold)).fontDesign(.rounded)
                                .foregroundStyle(Color.appInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }.padding(.vertical, 4)
                        Button {
                            onLogHabit(row.id)
                        } label: {
                            Label("Open smaller-action check-in", systemImage: "arrow.up.right")
                                .frame(minHeight: 44)
                        }
                        .accessibilityIdentifier("manageWeek.smaller.\(row.id.uuidString)")
                        Text("Choosing a smaller action records it separately; it never counts as full success.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Button {
                        pauseCandidate = row
                    } label: {
                        Label("Pause \(row.habit.name)", systemImage: "pause.circle")
                            .foregroundStyle(Color.appInkSecondary).frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("manageWeek.pause.\(row.id.uuidString)")
                } footer: { Text("Leave this habit as it is by making no change. Pause retains history and requires confirmation.") }
            }
            if !model.rows.isEmpty {
                Section {
                    Text(model.focusIDs.isEmpty ? "Choose a focus habit above to begin." : "\(model.focusIDs.count) \(model.focusIDs.count == 1 ? "habit" : "habits") selected for your restart")
                        .font(.subheadline).foregroundStyle(Color.appInkSecondary)
                    Button { planDays = 3 } label: {
                        restartRow(days: 3, subtitle: "A small beginning")
                    }
                        .disabled(model.focusIDs.isEmpty).accessibilityIdentifier("manageWeek.restart3")
                    Button { planDays = 7 } label: {
                        restartRow(days: 7, subtitle: "Room to find a rhythm")
                    }
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

    private func restartRow(days: Int, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Text("\(days)").font(.title.weight(.bold)).fontDesign(.rounded)
                .foregroundStyle(palette.accent)
                .frame(width: 46, height: 50)
                .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Review \(days)-Day Restart").font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(Color.appInkSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right").font(.caption.weight(.semibold)).accessibilityHidden(true)
        }
        .frame(minHeight: 60).padding(.vertical, 4)
    }
}
