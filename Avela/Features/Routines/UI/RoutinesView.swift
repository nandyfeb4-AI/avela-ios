import SwiftUI

/// Entry point accepts logging/navigation from the app composition root, so a
/// quantity or timed habit always uses its normal logger rather than a blind tick.
struct RoutinesView: View {
    @State private var model: RoutinesViewModel
    private let habits: any HabitRepository
    private let repository: any RoutineRepository
    @Environment(\.habitActivityRepository) private var activities
    @Environment(\.appPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                VStack(alignment: .leading, spacing: 12) {
                    Label("A rhythm that fits.", systemImage: "square.stack.3d.up.fill")
                        .font(.largeTitle.weight(.bold)).fontDesign(.rounded)
                        .foregroundStyle(.white).accessibilityAddTraits(.isHeader)
                    Text("Bring a few habits together. One small step, then the next.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.84))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { RilovaAurora() }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
            Section {
                LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize
                    ? [GridItem(.flexible())]
                    : [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(RoutineStarter.allCases) { starter in
                        starterCard(starter)
                    }
                }
                .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            } header: {
                Text("Start with a rhythm")
            } footer: {
                Text("Review suggestions from your existing habits. Nothing is saved until you choose Save.")
            }
            if let activities {
                Section {
                    NavigationLink {
                        ManageableWeekView(habits: habits, activities: activities, routines: repository, onLogHabit: onLogHabit)
                    } label: {
                        HStack(spacing: 12) {
                            AppIconBadge(symbol: "leaf.fill").accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("My day changed").font(.headline)
                                Text("Keep it small. Keep your progress.")
                                    .font(.subheadline).foregroundStyle(Color.appInkSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }.accessibilityIdentifier("routines.manageWeek")
                }
            }
            if model.routines.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your routine starts here.")
                        .font(.title2.weight(.bold)).fontDesign(.rounded)
                    Text("Try a rhythm above, or use + to make your own. Each habit keeps its own schedule and history.")
                        .font(.subheadline).foregroundStyle(Color.appInkSecondary)
                }
                .padding(.vertical, 10)
            }
            ForEach(model.routines) { routine in
                NavigationLink {
                    RoutineRunView(model: RoutineRunViewModel(routine: routine, habits: habits), onLogHabit: onLogHabit)
                } label: {
                    HStack(spacing: 14) {
                        AppIconBadge(symbol: routine.restartDays == nil ? "square.stack.3d.up.fill" : "leaf.fill")
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(routine.name).font(.title3.weight(.semibold)).fontDesign(.rounded)
                            Text(routine.restartDays.map { "\($0)-day restart · \(routine.habitIDs.count) habits" } ?? "\(routine.habitIDs.count) habits · Your order")
                                .font(.subheadline).foregroundStyle(Color.appInkSecondary)
                        }
                    }
                    .frame(minHeight: 60).padding(.vertical, 5)
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

    private func starterCard(_ starter: RoutineStarter) -> some View {
        Button { draft = model.draft(for: starter) } label: {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Image(systemName: starter.symbol)
                        .font(.system(size: 28, weight: .light)).foregroundStyle(palette.accent)
                        .accessibilityHidden(true)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.caption.weight(.semibold))
                        .foregroundStyle(palette.accent).accessibilityHidden(true)
                }
                Text(starter.name).font(.title3.weight(.bold)).fontDesign(.rounded)
                    .foregroundStyle(Color.appInk)
                Text(starter.subtitle).font(.subheadline).foregroundStyle(Color.appInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
            .background(LinearGradient(colors: [palette.surface, palette.accentSoft],
                startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(RilovaPressStyle())
        .accessibilityLabel("Review \(starter.name) routine starter. \(starter.subtitle)")
        .accessibilityHint("Opens an editable draft using suggestions from your active habits.")
        .accessibilityIdentifier("routines.starter.\(starter.rawValue)")
    }
}

private struct RoutineFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPalette) private var palette
    @State var draft: RoutineFormDraft
    @State private var saveFailed = false
    let habits: [Habit]
    let save: (String, [UUID], Int?) -> Bool

    private var selectedHabits: [Habit] {
        draft.habitIDs.compactMap { id in habits.first { $0.id == id } }
    }

    var body: some View {
        Form {
            if let starter = draft.starter {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(starter.name, systemImage: starter.symbol)
                            .font(.title2.weight(.bold)).fontDesign(.rounded)
                        Text(selectedHabits.isEmpty
                            ? "Choose the habits that belong here. We haven't selected any for you."
                            : "A few suggestions from your habit categories. Keep, remove or reorder any of them.")
                            .font(.subheadline).foregroundStyle(Color.appInkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Saved only when you tap Save.")
                            .font(.caption.weight(.semibold)).foregroundStyle(palette.accent)
                    }
                    .rilovaHeaderSurface()
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
            }
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
                if selectedHabits.isEmpty {
                    Text(habits.isEmpty ? "Create a habit first, then add it to a routine." : "Add at least one habit below to begin.")
                        .foregroundStyle(Color.appInkSecondary)
                }
                ForEach(selectedHabits) { habit in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            HabitIconBadge(symbol: habit.iconName).accessibilityHidden(true)
                            Text(habit.name).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                        }
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
                        HStack(spacing: 12) {
                            HabitIconBadge(symbol: habit.iconName).accessibilityHidden(true)
                            Text(habit.name).foregroundStyle(Color.appInk)
                            Spacer(minLength: 0)
                            Image(systemName: "plus.circle.fill").foregroundStyle(palette.accent).accessibilityHidden(true)
                        }.frame(minHeight: 52)
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
    @Environment(\.appPalette) private var palette

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Text("One step at a time.")
                        .font(.largeTitle.weight(.bold)).fontDesign(.rounded)
                        .foregroundStyle(.white).accessibilityAddTraits(.isHeader)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(model.steps.filter { $0.isDue && $0.isComplete }.count)")
                            .font(.largeTitle.weight(.bold)).fontDesign(.rounded).monospacedDigit().foregroundStyle(.white)
                        Text("of \(model.steps.filter(\.isDue).count) scheduled habits logged today")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.84))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Choose a habit when you're ready. Each check-in stays with its original habit.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.84))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { RilovaAurora() }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
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
                        Text(String(format: "%02d", index + 1))
                            .font(.caption.weight(.semibold).monospacedDigit()).foregroundStyle(Color.appInkSecondary)
                        HabitIconBadge(symbol: step.habit.iconName).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.habit.name).font(.title3.weight(.semibold)).fontDesign(.rounded).foregroundStyle(Color.appInk)
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
                            .foregroundStyle(palette.accent)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 64).padding(.vertical, 8)
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
