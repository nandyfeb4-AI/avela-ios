import SwiftUI

/// Habit identity, explicit action routes and read-only progress. Opening
/// this screen never logs or undoes a completion. All data comes from `HabitDetailViewModel`; this view
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Group {
            if let display = viewModel.display {
                List {
                    Section {
                        habitHero(display)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }

                    if activityRepository != nil || (!display.isArchived && attentionIntentionRepository != nil && intentionLinks != nil) {
                        Section {
                            let layout = dynamicTypeSize.isAccessibilitySize
                                ? AnyLayout(VStackLayout(spacing: 12))
                                : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
                            layout {
                                if activityRepository != nil {
                                    Button { showingActivity = true } label: {
                                        actionTile("Log Progress", detail: "Amounts, timer & check-ins", symbol: "plus", prominent: true)
                                    }
                                    .buttonStyle(RilovaPressStyle())
                                    .accessibilityLabel("Progress, Timer & History Corrections")
                                    .accessibilityIdentifier("habitDetail.activity")
                                }
                                if !display.isArchived, let attentionIntentionRepository, let intentionLinks {
                                    NavigationLink {
                                        IntentionSessionView(viewModel: IntentionSessionViewModel(habitID: viewModel.habitID,
                                            habits: viewModel.habitsRepository, attention: attentionIntentionRepository, links: intentionLinks))
                                    } label: {
                                        actionTile("Make Room", detail: "A little time for this", symbol: "sparkle", prominent: false)
                                    }
                                    .buttonStyle(RilovaPressStyle())
                                    .accessibilityLabel("Make Room with a Focus or Phone-Free Session")
                                    .accessibilityIdentifier("habitDetail.intention")
                                }
                            }
                            .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                        }
                    }

                    Section("Your Rhythm") {
                        NavigationLink {
                            HabitCalendarView(viewModel: viewModel.makeCalendarViewModel())
                        } label: {
                            toolLabel("Calendar History", symbol: "calendar", subtitle: "Your recorded days, together")
                        }.accessibilityIdentifier("habitDetail.calendarLink")
                        rhythmFacts(display)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(display.consistencyRangeLabel).font(.caption).foregroundStyle(Color.appInkSecondary)
                            Text(display.consistencyLabel).font(.subheadline.weight(.semibold))
                                .accessibilityIdentifier("habitDetail.consistency")
                        }.padding(.vertical, 4)
                        if let recoveryMessage = display.recoveryMessage {
                            Label(recoveryMessage, systemImage: "leaf")
                                .font(.subheadline).foregroundStyle(Color.appInkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("habitDetail.recoveryMessage")
                        }
                    }

                    if let memory = viewModel.whyMemory {
                        Section {
                            Text(memory).accessibilityIdentifier("habitDetail.whyMemory")
                            Button("Hide this reminder") { viewModel.hideWhyMemory() }
                                .accessibilityIdentifier("habitDetail.hideWhyMemory")
                        } header: { Text("Why this matters") } footer: { Text("Your reason, in your own words. Restore it in Edit Habit.") }
                    }

                    Section("Schedule") {
                        detailRow("Schedule", value: display.scheduleLabel)
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

                    Section("Explore Progress") {
                        NavigationLink {
                            HabitMomentumView(viewModel: HabitMomentumViewModel(habitID: viewModel.habitID,
                                habits: viewModel.habitsRepository, activity: activityRepository))
                        } label: {
                            toolLabel("Momentum", symbol: "chart.bar.xaxis", subtitle: "Recent consistency, recovery & lasting effort")
                        }.accessibilityIdentifier("habitDetail.momentum")
                        NavigationLink {
                            HabitLifetimeView(viewModel: viewModel.makeLifetimeViewModel(activity: activityRepository))
                        } label: {
                            toolLabel("Lifetime Progress", symbol: "chart.bar")
                        }.accessibilityIdentifier("habitDetail.lifetimeProgress")
                    }
                    if !display.isArchived {
                        Section("Support Your Habit") {
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

    private func habitHero(_ display: HabitDetailDisplay) -> some View {
        let identity = AppPalette(theme: HabitIconBadge.identityTheme(for: display.iconName))
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 13) {
                Image(systemName: display.iconName)
                    .font(.system(size: 27, weight: .medium))
                    .foregroundStyle(display.isArchived ? Color.appInkSecondary : identity.accent)
                    .frame(width: 56, height: 56)
                    .background(identity.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(display.categoryLabel.uppercased())
                        .font(.caption2.weight(.bold)).tracking(1.6)
                    Text(display.polarityLabel)
                        .font(.subheadline).foregroundStyle(Color.appInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if !dynamicTypeSize.isAccessibilitySize && contrast != .increased && !reduceTransparency {
                    RilovaWorldArtwork(scene: .coast)
                        .frame(width: 88, height: 58).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .accessibilityHidden(true).allowsHitTesting(false)
                }
            }
            Text(display.name)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(Color.appInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("habitDetail.name")
            let statusLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 5))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 10))
            statusLayout {
                Text(display.isArchived ? "ARCHIVED" : display.weeklyProgress == nil ? "TODAY" : "THIS WEEK")
                    .font(.caption2.weight(.bold)).tracking(1.4)
                    .foregroundStyle(Color.appInkSecondary)
                if let progress = display.weeklyProgress {
                    Text("\(progress.completed)/\(progress.target)")
                        .font(.system(.title3, design: .rounded, weight: .bold)).monospacedDigit()
                        .foregroundStyle(palette.accent)
                        .accessibilityIdentifier("habitDetail.progress")
                } else {
                    Label(display.todayStatusLabel, systemImage: display.isCompletedToday ? "checkmark.circle.fill" : "circle")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Color.appInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("habitDetail.progress")
                }
            }
        }
        .foregroundStyle(Color.appInk).padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .leading) {
                palette.surface
                if contrast != .increased && !reduceTransparency {
                    LinearGradient(colors: [identity.accent.opacity(0.09), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
                RoundedRectangle(cornerRadius: 3)
                    .fill(display.isArchived ? Color.appInkSecondary : identity.accent)
                    .frame(width: 4).padding(.vertical, 26)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(identity.accent.opacity(contrast == .increased ? 0.5 : 0.14), lineWidth: 1))
    }

    private func actionTile(_ title: String, detail: String, symbol: String, prominent: Bool) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbol).font(.title3.weight(.semibold))
                .frame(width: 28).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.bold)).fontDesign(.rounded)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail).font(.caption).fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(prominent ? palette.prominentInk : Color.appInk)
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .padding(14)
        .background(prominent ? palette.prominentFill : palette.surface,
                    in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 21).strokeBorder(palette.accent.opacity(0.15), lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 21))
    }

    private func rhythmFacts(_ display: HabitDetailDisplay) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 20))
        return layout {
            VStack(alignment: .leading, spacing: 5) {
                Text("Current streak").font(.caption).foregroundStyle(Color.appInkSecondary)
                Text(display.currentStreakLabel).font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("habitDetail.currentStreak")
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                Text("Personal best").font(.caption).foregroundStyle(Color.appInkSecondary)
                Text(display.bestStreakLabel).font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("habitDetail.bestStreak")
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.vertical, 6)
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
