import SwiftUI

/// Entry point accepts logging/navigation from the app composition root, so a
/// quantity or timed habit always uses its normal logger rather than a blind tick.
struct RoutinesView: View {
    @State private var model: RoutinesViewModel
    private let habits: any HabitRepository
    private let repository: any RoutineRepository
    @Environment(\.habitActivityRepository) private var activities
    let onLogHabit: (UUID) -> Void
    @State private var draft: RoutineFormDraft?
    @State private var deleting: HabitRoutine?

    init(repository: any RoutineRepository, habits: any HabitRepository, onLogHabit: @escaping (UUID) -> Void) {
        _model = State(initialValue: RoutinesViewModel(repository: repository, habits: habits))
        self.habits = habits
        self.repository = repository
        self.onLogHabit = onLogHabit
    }

    var body: some View {
        List {
            Section {
                Text("Keep a few habits together. Work through them in your order, with each check-in saved to its original habit.")
                    .foregroundStyle(Color.secondary)
            }
            if let activities {
                Section {
                    NavigationLink("Make This Week Manageable") {
                        ManageableWeekView(habits: habits, activities: activities, routines: repository, onLogHabit: onLogHabit)
                    }.accessibilityIdentifier("routines.manageWeek")
                }
            }
            if model.routines.isEmpty {
                ContentUnavailableView("Your Rhythm, Together", systemImage: "list.bullet.rectangle", description: Text("Create a morning, evening or other routine using habits you already track."))
            }
            ForEach(model.routines) { routine in
                NavigationLink {
                    RoutineRunView(model: RoutineRunViewModel(routine: routine, habits: habits), onLogHabit: onLogHabit)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(routine.name).font(.headline)
                        Text(routine.restartDays.map { "\($0)-day restart · \(routine.habitIDs.count) habits" } ?? "\(routine.habitIDs.count) habits").font(.subheadline).foregroundStyle(Color.secondary)
                    }
                    .frame(minHeight: 44)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Delete", role: .destructive) { deleting = routine }
                    Button("Edit") { draft = RoutineFormDraft(routine: routine) }
                }
                .contextMenu {
                    Button("Edit Routine") { draft = RoutineFormDraft(routine: routine) }
                    Button("Delete Routine", role: .destructive) { deleting = routine }
                }
                .accessibilityIdentifier("routine.\(routine.id.uuidString)")
            }
            if model.activeHabits.isEmpty {
                Text("Create a habit first, then bring it into a routine.").foregroundStyle(Color.secondary)
            }
        }
        .appThemeCanvas()
        .navigationTitle("Routines")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Routine", systemImage: "plus") { draft = RoutineFormDraft() }
                    .disabled(model.activeHabits.isEmpty)
                    .accessibilityIdentifier("routines.create")
            }
        }
        .sheet(item: $draft, onDismiss: { model.load() }) { initial in
            NavigationStack {
                RoutineFormView(draft: initial, habits: model.activeHabits) { name, ids, restartDays in
                    model.save(id: initial.routineID, name: name, habitIDs: ids, restartDays: restartDays)
                }
            }
        }
        .alert("Delete Routine?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Delete Routine", role: .destructive) {
                if let deleting { model.delete(deleting) }
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: { Text("Only this grouping is removed. Your habits and their history stay intact.") }
        .alert("Unable to Update Routines", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .task { model.load() }
        .onAppear { model.load() }
    }
}

struct RoutineFormDraft: Identifiable {
    let id = UUID()
    var routineID: UUID?
    var name: String = ""
    var habitIDs: [UUID] = []
    var restartDays: Int? = nil

    init() {}
    init(routine: HabitRoutine) {
        restartDays = routine.restartDays
        routineID = routine.id
        name = routine.name
        habitIDs = routine.habitIDs
    }
}

private struct RoutineFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: RoutineFormDraft
    @State private var saveFailed = false
    let habits: [Habit]
    let save: (String, [UUID], Int?) -> Bool

    private var selectedHabits: [Habit] {
        draft.habitIDs.compactMap { id in habits.first { $0.id == id } }
    }

    var body: some View {
        Form {
            Section {
                Picker("Plan", selection: $draft.restartDays) {
                    Text("Ongoing routine").tag(Int?.none)
                    Text("3-day restart").tag(Int?.some(3))
                    Text("7-day restart").tag(Int?.some(7))
                }
            } footer: { Text("A restart is a short list to focus on. It does not pause other habits, lower targets or change streak rules.") }
            Section("Name") {
                TextField("Morning, evening, or your own rhythm", text: $draft.name)
                    .accessibilityIdentifier("routine.name")
            }
            Section {
                ForEach(selectedHabits) { habit in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(habit.name).frame(maxWidth: .infinity, alignment: .leading)
                        HStack {
                        Button("Remove", systemImage: "minus.circle") { draft.habitIDs.removeAll { $0 == habit.id } }
                            .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel("Remove \(habit.name) from routine")
                        Button("Move Up", systemImage: "arrow.up") { move(habit.id, offset: -1) }
                            .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                            .disabled(draft.habitIDs.first == habit.id)
                            .accessibilityLabel("Move \(habit.name) up")
                        Button("Move Down", systemImage: "arrow.down") { move(habit.id, offset: 1) }
                            .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                            .disabled(draft.habitIDs.last == habit.id)
                            .accessibilityLabel("Move \(habit.name) down")
                        }
                    }
                    .buttonStyle(.borderless)
                }
                .onMove { source, destination in draft.habitIDs.move(fromOffsets: source, toOffset: destination) }
            } header: { Text("Your Order") } footer: { Text("A routine never changes a habit’s schedule. Archived habits are omitted when running it.") }
            Section("Add Habits") {
                ForEach(habits.filter { !draft.habitIDs.contains($0.id) }) { habit in
                    Button { draft.habitIDs.append(habit.id) } label: {
                        Label(habit.name, systemImage: habit.iconName).frame(minHeight: 44)
                    }
                    .accessibilityLabel("Add \(habit.name) to routine")
                }
            }
        }
        .appThemeCanvas()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(draft.routineID == nil ? "New Routine" : "Edit Routine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { if save(draft.name, draft.habitIDs, draft.restartDays) { dismiss() } else { saveFailed = true } }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.name.count > 80 || selectedHabits.isEmpty)
                    .accessibilityIdentifier("routine.save")
            }
        }
        .onAppear { draft.habitIDs = selectedHabits.map(\.id) }
        .alert("Routine Not Saved", isPresented: $saveFailed) { Button("OK", role: .cancel) {} } message: { Text("A habit may have changed or your name may be too long. Cancel and reopen this form to refresh available habits; nothing was saved.") }
    }

    private func move(_ id: UUID, offset: Int) {
        guard let index = draft.habitIDs.firstIndex(of: id), draft.habitIDs.indices.contains(index + offset) else { return }
        draft.habitIDs.swapAt(index, index + offset)
    }
}

struct RoutineRunView: View {
    @State var model: RoutineRunViewModel
    let onLogHabit: (UUID) -> Void
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            Section {
                Text("Choose a habit to check in when you’re ready.")
                    .foregroundStyle(Color.secondary)
            }
            if let days = model.routine.restartDays {
                Section {
                    Text("Your \(days)-day restart") .font(.headline)
                    if let end = model.restartReviewDate {
                        Text("Review on \(end.formatted(date: .abbreviated, time: .omitted)).").foregroundStyle(Color.secondary)
                        Text("Full commitments count from your restart day. Weekly habits count completed weeks; smaller actions stay separate.").font(.subheadline).foregroundStyle(Color.secondary)
                    }
                }
            }
            ForEach(Array(model.steps.enumerated()), id: \.element.id) { index, step in
                Button {
                    onLogHabit(step.id)
                } label: {
                    HStack(spacing: 12) {
                        Text("\(index + 1)").font(.headline.monospacedDigit()).foregroundStyle(Color.secondary)
                        Image(systemName: step.habit.iconName).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.habit.name).font(.headline)
                            Text(step.isComplete ? "Logged today" : (step.isDue ? "Ready when you are" : "Not scheduled today"))
                                .font(.subheadline).foregroundStyle(Color.secondary)
                            if let successful = step.restartSuccessfulCommitments {
                                Text("\(successful) successful commitments since restart day").font(.subheadline).foregroundStyle(Color.secondary)
                            }
                            if let recovery = step.recoveryMessage {
                                Text(recovery).font(.subheadline).foregroundStyle(Color.appInkSecondary)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: step.isComplete ? "checkmark.circle.fill" : "chevron.forward")
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                }
                .disabled(!step.isDue && !step.isComplete)
                .accessibilityLabel("\(step.habit.name), \(step.isComplete ? "logged today" : step.isDue ? "open check-in" : "not scheduled today")")
                .accessibilityValue([step.restartSuccessfulCommitments.map { "\($0) successful commitments since restart day" }, step.recoveryMessage].compactMap { $0 }.joined(separator: ". "))
                .accessibilityHint("Opens the habit’s regular check-in without logging automatically.")
            }
            if model.unavailableCount > 0 {
                Text("\(model.unavailableCount) archived or unavailable habits are omitted. Edit the routine to update its list.")
                    .foregroundStyle(Color.secondary)
            }
            if model.steps.isEmpty { ContentUnavailableView("No Active Habits", systemImage: "list.bullet", description: Text("Edit this routine to add active habits.")) }
        }
        .appThemeCanvas()
        .navigationTitle(model.routine.name)
        .task { model.load() }
        .onAppear { model.load() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { model.load() } }
        .onReceive(NotificationCenter.default.publisher(for: .avelaPersistenceDidChange)) { _ in model.load() }
        .alert("Unable to Load Progress", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
}

private struct RoutineRepositoryKey: EnvironmentKey { static let defaultValue: RoutineRepository? = nil }
extension EnvironmentValues {
    var routineRepository: RoutineRepository? {
        get { self[RoutineRepositoryKey.self] }
        set { self[RoutineRepositoryKey.self] = newValue }
    }
}
