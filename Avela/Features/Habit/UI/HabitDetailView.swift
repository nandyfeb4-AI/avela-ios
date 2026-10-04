import SwiftUI

/// Habit detail screen: read-only metrics plus editing and archiving. Opening
/// this screen never logs or undoes a completion — that only happens from
/// Today's row control. All data comes from `HabitDetailViewModel`; this view
/// neither queries SwiftData nor computes scheduling/progress itself.
struct HabitDetailView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var viewModel: HabitDetailViewModel
    var onViewHistory: (UUID) -> Void = { _ in }
    @Environment(\.habitReminderService) private var reminderService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let display = viewModel.display {
                List {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: display.iconName)
                                .font(.largeTitle)
                                .foregroundStyle(display.isArchived ? Color.secondary : Color.accentColor)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(display.name)
                                    .font(.title3)
                                    .accessibilityIdentifier("habitDetail.name")
                                Text("\(display.categoryLabel) · \(display.polarityLabel)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Section("Schedule") {
                        detailRow("Schedule", value: display.scheduleLabel)
                        if let weeklyProgress = display.weeklyProgress {
                            detailRow("This Week", value: "\(weeklyProgress.completed)/\(weeklyProgress.target)", identifier: "habitDetail.progress")
                        } else {
                            detailRow("Today", value: display.todayStatusLabel, identifier: "habitDetail.progress")
                        }
                    }

                    if display.canSkipToday || display.isSkippedToday {
                        Section {
                            Button(display.isSkippedToday ? "Undo Today's Skip" : "Skip Today") {
                                viewModel.toggleSkip()
                            }
                            .accessibilityIdentifier("habitDetail.skipButton")
                        } footer: {
                            Text("A skipped day neither extends nor breaks your streak and is excluded from consistency. Weekly targets still count completed days.")
                        }
                    }

                    if !display.isArchived, let reminderService, let schedule = viewModel.draft?.schedule {
                        Section {
                            NavigationLink("Reminder") {
                                HabitReminderView(habitID: viewModel.habitID, schedule: schedule, service: reminderService)
                            }.accessibilityIdentifier("habitDetail.reminderLink")
                        }
                    }
                    Section("Streak") {
                        detailRow("Current", value: display.currentStreakLabel, identifier: "habitDetail.currentStreak")
                        detailRow("Best", value: display.bestStreakLabel, identifier: "habitDetail.bestStreak")
                        if let recoveryMessage = display.recoveryMessage {
                            Text(recoveryMessage)
                                .foregroundStyle(Color.appRecovery)
                                .accessibilityIdentifier("habitDetail.recoveryMessage")
                        }
                    }

                    Section(display.consistencyRangeLabel) {
                        Text(display.consistencyLabel)
                            .accessibilityIdentifier("habitDetail.consistency")
                    }

                    Section {
                        Button {
                            dismiss()
                            onViewHistory(viewModel.habitID)
                        } label: {
                            HStack {
                                Text("View History")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .accessibilityIdentifier("habitDetail.viewHistoryButton")
                    }

                    if display.isArchived {
                        Section {
                            Label("This habit is archived.", systemImage: "archivebox")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Section {
                            Button("Archive Habit", role: .destructive) {
                                viewModel.isShowingArchiveConfirmation = true
                            }
                            .accessibilityIdentifier("habitDetail.archiveButton")
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(viewModel.display?.name ?? "Habit")
        .toolbar {
            if viewModel.display?.isArchived == false {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        viewModel.isShowingEditForm = true
                    }
                    .accessibilityIdentifier("habitDetail.editButton")
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingEditForm) {
            HabitFormView(initialDraft: viewModel.draft) { updatedDraft in
                viewModel.saveEdits(updatedDraft)
            }
        }
        // A plain `.alert`, not `.confirmationDialog`: on this toolchain,
        // `.confirmationDialog` presented from a row inside a `List` rendered
        // as a small anchored popover with only its destructive action
        // visible — the explicit `Button("Cancel", role: .cancel)` never
        // appeared in the accessibility tree at all (confirmed by a UI test
        // that waits for it before asserting anything, not just a one-off
        // screenshot). `.alert` is the standard native two-button
        // confirm/cancel presentation and has none of that anchoring
        // ambiguity — always a centered, fully-labeled modal.
        .alert(
            "Archive this habit?",
            isPresented: $viewModel.isShowingArchiveConfirmation
        ) {
            Button("Archive", role: .destructive) {
                viewModel.archive()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Archived habits disappear from Today, but their history is kept. You can reactivate this habit anytime from Settings.")
        }
        .alert(
            "Something Went Wrong",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onChange(of: viewModel.didArchive) { _, didArchive in
            if didArchive { reminderService?.cancel(for: viewModel.habitID); dismiss() }
        }
        .onChange(of: viewModel.isShowingEditForm) { _, showing in
            if !showing { Task { try? await reminderService?.synchronize() } }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { viewModel.load() } }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in viewModel.load() }
        .task {
            viewModel.load()
        }
    }

    /// A title/value row with the value exposed as its own accessibility
    /// element (`identifier`), rather than relying on `LabeledContent`'s
    /// automatic combined accessibility text, so UI tests can read it
    /// directly instead of parsing a concatenated string.
    private func detailRow(_ title: String, value: String, identifier: String = "") -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(identifier)
        }
    }
}

#Preview {
    let container = try! AppPersistence.makeContainer(inMemory: true)
    let repository = SwiftDataHabitRepository(modelContext: container.mainContext)
    let habit = try! repository.createHabit(
        HabitDraft(name: "Read", iconName: "book.fill", category: .learning, polarity: .positive, schedule: .timesPerWeek(3)),
        at: Date()
    )
    return NavigationStack {
        HabitDetailView(viewModel: HabitDetailViewModel(habitID: habit.id, repository: repository))
    }
}

private struct HabitReminderServiceKey: EnvironmentKey {
    static let defaultValue: HabitReminderService? = nil
}

extension EnvironmentValues {
    var habitReminderService: HabitReminderService? {
        get { self[HabitReminderServiceKey.self] }
        set { self[HabitReminderServiceKey.self] = newValue }
    }
}
