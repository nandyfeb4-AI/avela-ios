import SwiftUI

/// Habit detail screen: read-only metrics plus editing and archiving. Opening
/// this screen never logs or undoes a completion — that only happens from
/// Today's row control. All data comes from `HabitDetailViewModel`; this view
/// neither queries SwiftData nor computes scheduling/progress itself.
struct HabitDetailView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var viewModel: HabitDetailViewModel
    @State private var showingAdjustment = false
    @State private var showingActivity = false
    @Environment(\.habitActivityRepository) private var activityRepository
    @Environment(\.attentionIntentionRepository) private var attentionIntentionRepository
    @Environment(\.intentionLinkRepository) private var intentionLinks
    var onViewHistory: (UUID) -> Void = { _ in }
    @Environment(\.habitReminderService) private var reminderService
    @Environment(\.healthHabitService) private var healthService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let display = viewModel.display {
                List {
                    Section {
                        HStack(spacing: 12) {
                            HabitIconBadge(symbol: display.iconName, isArchived: display.isArchived)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(display.name)
                                    .font(.title2.weight(.semibold))
                                    .accessibilityIdentifier("habitDetail.name")
                                Text("\(display.categoryLabel) · \(display.polarityLabel)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 12)
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
                            Text("Skips are excused. They don’t break or extend a streak. Weekly targets still count completed days.")
                        }
                    }

                    Section("Streak") {
                        NavigationLink {
                            HabitCalendarView(viewModel: viewModel.makeCalendarViewModel())
                        } label: {
                            Label("Calendar History", systemImage: "calendar")
                        }.accessibilityIdentifier("habitDetail.calendarLink")
                        detailRow("Current", value: display.currentStreakLabel, identifier: "habitDetail.currentStreak")
                        detailRow("Best", value: display.bestStreakLabel, identifier: "habitDetail.bestStreak")
                        if let recoveryMessage = display.recoveryMessage {
                            Label {
                                Text(recoveryMessage)
                                    .font(.subheadline)
                                    .accessibilityIdentifier("habitDetail.recoveryMessage")
                            } icon: {
                                Image(systemName: "leaf")
                                    .accessibilityHidden(true)
                            }
                            .foregroundStyle(Color.appInkSecondary)
                            .padding(.vertical, 6)
                        }
                    }

                    Section(display.consistencyRangeLabel) {
                        Text(display.consistencyLabel)
                            .accessibilityIdentifier("habitDetail.consistency")
                    }

                    Section("Explore Progress") {
                        NavigationLink {
                            HabitLifetimeView(viewModel: viewModel.makeLifetimeViewModel(activity: activityRepository))
                        } label: {
                            toolLabel("Lifetime Progress", symbol: "chart.bar")
                        }.accessibilityIdentifier("habitDetail.lifetimeProgress")
                        if activityRepository != nil {
                            Button { showingActivity = true } label: {
                                toolLabel("Log Progress", symbol: "slider.horizontal.3", subtitle: "Quick amounts, timer and past check-ins")
                                    .accessibilityLabel("Progress, Timer & History Corrections")
                            }
                            .accessibilityIdentifier("habitDetail.activity")
                        }
                    }
                    if !display.isArchived {
                        Section("Support Your Habit") {
                            if let attentionIntentionRepository, let intentionLinks {
                                NavigationLink {
                                    IntentionSessionView(viewModel: IntentionSessionViewModel(habitID: viewModel.habitID, habits: viewModel.habitsRepository, attention: attentionIntentionRepository, links: intentionLinks))
                                } label: {
                                    toolLabel("Make Room", symbol: "moon", subtitle: "A phone-free session for this habit")
                                        .accessibilityLabel("Make Room with a Phone-Free Session")
                                }.accessibilityIdentifier("habitDetail.intention")
                            }
                            if let reminderService, let schedule = viewModel.draft?.schedule {
                                NavigationLink {
                                    HabitReminderView(habitID: viewModel.habitID, schedule: schedule, service: reminderService)
                                } label: { toolLabel("Reminder", symbol: "bell") }
                                    .accessibilityIdentifier("habitDetail.reminderLink")
                            }
                            if viewModel.adjustmentProposal != nil {
                                Button { showingAdjustment = true } label: {
                                    toolLabel("Make It Easier", symbol: "leaf")
                                }.accessibilityIdentifier("habitDetail.makeEasier")
                            }
                            if viewModel.draft?.polarity == .positive, let healthService {
                                NavigationLink {
                                    HealthHabitView(habitID: viewModel.habitID, service: healthService)
                                } label: { toolLabel("Apple Health", symbol: "heart") }
                                    .accessibilityIdentifier("habitDetail.healthLink")
                            }
                        }
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
        .appThemeCanvas()
        .navigationTitle(viewModel.display?.name ?? "Habit")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: .avelaHealthDidLog)) { _ in viewModel.load() }
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
        .sheet(isPresented: $showingActivity, onDismiss: { viewModel.load() }) {
            if let activityRepository {
                HabitActivityView(habitID: viewModel.habitID, repository: activityRepository, habits: viewModel.habitsRepository)
            }
        }
        .sheet(isPresented: $showingAdjustment) {
            HabitAdjustmentView(viewModel: viewModel.makeAdjustmentViewModel()) {
                viewModel.load()
                Task { try? await reminderService?.synchronize() }
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

    private func toolLabel(_ title: String, symbol: String, subtitle: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(palette.accent)
                .frame(width: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).foregroundStyle(Color.appInk)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Color.appInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(minHeight: 44)
        .padding(.vertical, subtitle == nil ? 0 : 4)
    }

    /// A title/value row with the value exposed as its own accessibility
    /// element (`identifier`), rather than relying on `LabeledContent`'s
    /// automatic combined accessibility text, so UI tests can read it
    /// directly instead of parsing a concatenated string.
    private func detailRow(_ title: String, value: String, identifier: String = "") -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 20) {
                Text(title)
                Spacer()
                Text(value)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(identifier)
            }.fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                Text(value)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(identifier)
            }
        }
        .padding(.vertical, 4)
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
