import SwiftUI

/// Wrapper distinguishing an attention-goal ID from a habit ID on Today's
/// shared navigation path: both are plain `UUID`s, and pushing a bare `UUID`
/// for both row kinds would leave a single `navigationDestination(for:
/// UUID.self)` unable to tell which detail screen to show.
struct AttentionGoalNavigationID: Hashable {
    let id: UUID
}

/// What the undo toast's single action undoes. Kept generic over both
/// sources (a habit completion, a fast attention quick-log) so there is one
/// toast implementation, not two.
private enum TodayToastKind: Equatable {
    case habitCompletion(habitID: UUID)
    case attentionQuickLog
}

private struct TodayToast: Identifiable {
    let id = UUID()
    let message: String
    let kind: TodayToastKind
}

/// Today screen, in the "Tidewater Balance" layout
/// (`design/exploration/TODAY_CONCEPTS.md`): a Habits/Attention pillar strip,
/// a collapsible Done group, a branded undo toast, and fast inline attention
/// logging — built on real habit and manual-attention data, with one-tap
/// completion/undo and recovery context carried over unchanged. All data
/// comes from `TodayViewModel`/`AttentionSummaryViewModel`; this view neither
/// queries SwiftData nor computes scheduling/progress/threshold math itself.
struct TodayView: View {
    @Bindable var viewModel: TodayViewModel
    let repository: HabitRepository
    @Bindable var attentionViewModel: AttentionSummaryViewModel
    let attentionRepository: AttentionRepository
    var companionProfile: CompanionProfile = CompanionProfile()
    var subscriptionManager: SubscriptionManager? = nil

    var onViewHistory: (UUID) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Habits whose completion toggle fired less than `collapseDelay` ago:
    /// shown as still "to do" even though they're done, so a row never
    /// vanishes out from under the thumb that just completed it
    /// (COMPONENT_SPEC "Row moves 'To do' → 'Done': after 0.6s"; this uses a
    /// longer, touch-appropriate delay since there is no mouse-hover signal
    /// to extend it with, unlike the web prototype this layout is based on).
    @State private var pendingDoneIDs: Set<UUID> = []
    @State private var isDoneSectionExpanded = false
    @State private var toast: TodayToast?
    @State private var toastDismissTask: Task<Void, Never>?
    /// Keyed by habit ID so a still-pending collapse can be cancelled (not
    /// just superseded) — see `scheduleCollapse` and the `.onDisappear` below
    /// for why cancelling, not merely letting it run, matters.
    @State private var collapseTasks: [UUID: Task<Void, Never>] = [:]

    private static let collapseDelay: Duration = .seconds(1.5)
    private static let toastDuration: Duration = .seconds(4)

    private var isAccessibilitySize: Bool { dynamicTypeSize.isAccessibilitySize }

    private var toDoRows: [TodayHabitRow] {
        viewModel.rows.filter { !$0.isCompletedToday || pendingDoneIDs.contains($0.id) }
    }

    private var doneRows: [TodayHabitRow] {
        viewModel.rows.filter { $0.isCompletedToday && !pendingDoneIDs.contains($0.id) }
    }

    var body: some View {
        Group {
            if viewModel.rows.isEmpty && attentionViewModel.rows.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        CompanionView(profile: companionProfile, input: companionInput)
                        pillarStrip
                        habitsSection
                        if !attentionViewModel.rows.isEmpty {
                            attentionSection
                        }
                    }
                    .padding(16)
                }
                .background(Color.appBackground)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { toastView }
        .sensoryFeedback(.success, trigger: toast?.id) { _, new in
            companionProfile.hapticsEnabled && new != nil
        }
        // Bare presentation timers need explicit cleanup. Destination models
        // own their state independently, so correctness does not depend on
        // whether a particular navigation method invokes this cleanup.
        .onDisappear {
            for task in collapseTasks.values { task.cancel() }
            collapseTasks.removeAll()
            pendingDoneIDs.removeAll()
            hideToast()
        }
        .navigationDestination(for: UUID.self) { habitID in
            HabitDetailDestination(
                habitID: habitID, repository: repository,
                onViewHistory: onViewHistory
            )
            .onDisappear { viewModel.load() }
        }
        .navigationDestination(for: AttentionGoalNavigationID.self) { navigationID in
            AttentionDetailDestination(
                goalID: navigationID.id,
                type: attentionViewModel.rows.first(where: { $0.id == navigationID.id })?.goalType ?? .maxDurationPerDay,
                repository: attentionRepository
            )
            .onDisappear { attentionViewModel.load() }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                addButton(label: "Create Habit", systemImage: "plus", identifier: "today.addHabitButton") {
                    viewModel.requestCreation()
                }
            }
            ToolbarItem(placement: .primaryAction) {
                addButton(label: "Add Attention Goal", systemImage: "hourglass.badge.plus", identifier: "today.addAttentionGoalButton") {
                    attentionViewModel.requestCreation()
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.isShowingPremium || attentionViewModel.isShowingPremium },
            set: { if !$0 { viewModel.isShowingPremium = false; attentionViewModel.isShowingPremium = false } }
        )) {
            if let subscriptionManager { PremiumPaywallView(manager: subscriptionManager) }
        }
        .sheet(isPresented: $viewModel.isShowingCreateHabit) {
            HabitFormView { draft in
                viewModel.createHabit(draft)
            }
        }
        .sheet(isPresented: $attentionViewModel.isShowingCreateGoal) {
            AttentionGoalFormView { draft in
                attentionViewModel.createGoal(draft)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { attentionViewModel.quickLogGoalID != nil },
                set: { if !$0 { attentionViewModel.quickLogGoalID = nil } }
            )
        ) {
            if let goalID = attentionViewModel.quickLogGoalID,
               let row = attentionViewModel.rows.first(where: { $0.id == goalID }) {
                AttentionUsageFormView(unit: row.targetUnit) { amount in
                    attentionViewModel.logQuickUsage(amount: amount)
                }
            }
        }
        .alert(
            "Something Went Wrong",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil || attentionViewModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.errorMessage = nil
                        attentionViewModel.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? attentionViewModel.errorMessage ?? "")
        }
        .task {
            viewModel.load()
            attentionViewModel.load()
        }
    }

    private var companionInput: CompanionInput {
        CompanionInput(
            loggedAttentionStates: attentionViewModel.rows.filter { $0.goalType == .maxDurationPerDay }.compactMap(\.state),
            attentionGoalCount: attentionViewModel.rows.count,
            isRecovering: viewModel.rows.contains { $0.recoveryContext != nil },
            meaningfulCompletion: toast != nil,
            hasActiveSession: attentionViewModel.hasActiveSession,
            completedHabits: viewModel.rows.filter(\.isCompletedToday).count,
            dueHabits: viewModel.rows.count
        )
    }

    // MARK: - Pillars

    private var pillarStrip: some View {
        let layout: AnyLayout = isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))
        return layout {
            habitsPillar
            if !attentionViewModel.rows.isEmpty {
                attentionPillar
            }
        }
    }

    private var habitsPillar: some View {
        let done = viewModel.rows.filter(\.isCompletedToday).count
        let total = viewModel.rows.count
        return VStack(alignment: .leading, spacing: 4) {
            Text("Habits")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.appInkSecondary)
            Text("\(done) of \(total)")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Color.accentColor)
                .monospacedDigit()
            if total > 0 && total <= 12 {
                HStack(spacing: 5) {
                    ForEach(viewModel.rows) { row in
                        Circle()
                            .strokeBorder(Color.appInkTertiary, lineWidth: 1.6)
                            .background(Circle().fill(row.isCompletedToday ? Color.accentColor : Color.clear))
                            .frame(width: 9, height: 9)
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Habits: \(done) of \(total) done")
    }

    private var attentionPillar: some View {
        let pillarState = AttentionStatusFormatter.pillarState(for: attentionViewModel.rows)
        let label = AttentionStatusFormatter.pillarLabel(for: pillarState)
        return VStack(alignment: .leading, spacing: 4) {
            Text("Attention")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.appInkSecondary)
            Text(label)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(pillarColor(pillarState))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Attention: \(label)")
    }

    private func pillarColor(_ state: AttentionStatusFormatter.PillarState?) -> Color {
        switch state {
        case .none, .some(.notLoggedYet), .some(.manualCheckIns):
            return .secondary
        case .some(.state(.healthy)):
            return .accentColor
        case .some(.state(.nearLimit)):
            return .appRecovery
        case .some(.state(.exceeded)):
            return .appOverBudget
        }
    }

    // MARK: - Habits

    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !viewModel.rows.isEmpty {
                HStack {
                    Text("Habits").font(.subheadline.weight(.semibold)).foregroundStyle(Color.appInkSecondary)
                    Spacer()
                    Text("\(viewModel.rows.filter(\.isCompletedToday).count) of \(viewModel.rows.count)")
                        .font(.subheadline)
                        .foregroundStyle(Color.appInkTertiary)
                }
                habitsCard
            }
        }
    }

    private var habitsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(toDoRows.enumerated()), id: \.element.id) { index, row in
                if index > 0 { Divider().padding(.leading, isAccessibilitySize ? 0 : 66) }
                HabitRowView(row: row, isAccessibilitySize: isAccessibilitySize, onToggle: { toggle(row) }, onNavigate: prepareForNavigation)
            }
            if !doneRows.isEmpty {
                if !toDoRows.isEmpty { Divider() }
                doneToggleRow
                if isDoneSectionExpanded {
                    ForEach(doneRows) { row in
                        Divider().padding(.leading, isAccessibilitySize ? 0 : 66)
                        HabitRowView(row: row, isAccessibilitySize: isAccessibilitySize, onToggle: { toggle(row) }, onNavigate: prepareForNavigation)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCornerRadius, style: .continuous))
    }

    private var doneToggleRow: some View {
        Button {
            withAnimation(reduceMotion ? nil : .default) { isDoneSectionExpanded.toggle() }
        } label: {
            HStack {
                Text("Done · \(doneRows.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appInkSecondary)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundStyle(Color.appInkTertiary)
                    .rotationEffect(.degrees(isDoneSectionExpanded ? 180 : 0))
            }
            .frame(minHeight: 44)
        }
        .accessibilityIdentifier("today.doneToggle")
        .accessibilityLabel(
            "Done, \(doneRows.count) \(doneRows.count == 1 ? "habit" : "habits"), "
                + (isDoneSectionExpanded ? "expanded" : "collapsed")
        )
    }

    private func toggle(_ row: TodayHabitRow) {
        let wasCompleted = row.isCompletedToday
        viewModel.toggleCompletion(for: row)
        guard let updatedRow = viewModel.rows.first(where: { $0.id == row.id }),
              updatedRow.isCompletedToday != wasCompleted else { return }
        if wasCompleted {
            withAnimation(reduceMotion ? nil : .default) { pendingDoneIDs.remove(row.id) }
            hideToast()
            announce(
                (row.polarity == .avoidance ? "Success undone for " : "Completion undone for ") + row.name + "."
            )
        } else {
            withAnimation(reduceMotion ? nil : .default) { pendingDoneIDs.insert(row.id) }
            let message = HabitPolarityFormatter.toastMessage(habitName: row.name, polarity: row.polarity)
            showToast(message: message, kind: .habitCompletion(habitID: row.id))
            announce(message + ". Undo available.")
            scheduleCollapse(for: row.id)
        }
    }

    private func scheduleCollapse(for habitID: UUID) {
        collapseTasks[habitID]?.cancel()
        collapseTasks[habitID] = Task {
            try? await Task.sleep(for: Self.collapseDelay)
            guard !Task.isCancelled else { return }
            if reduceMotion {
                pendingDoneIDs.remove(habitID)
            } else {
                withAnimation { pendingDoneIDs.remove(habitID) }
            }
            collapseTasks[habitID] = nil
        }
    }

    /// Settle presentation state before pointer/touch navigation. VoiceOver
    /// and keyboard activation may bypass the tap gesture; state-owned
    /// destinations remain stable even if these timers run after a push.
    private func prepareForNavigation() {
        for task in collapseTasks.values { task.cancel() }
        collapseTasks.removeAll()
        pendingDoneIDs.removeAll()
        hideToast()
    }

    // MARK: - Attention

    private var attentionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Attention").font(.subheadline.weight(.semibold)).foregroundStyle(Color.appInkSecondary)
            attentionCard
        }
    }

    private var attentionCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(attentionViewModel.rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 { Divider().padding(.leading, isAccessibilitySize ? 0 : 66) }
                AttentionGoalRowView(
                    row: row,
                    isAccessibilitySize: isAccessibilitySize,
                    onOpenQuickLogSheet: { attentionViewModel.quickLogGoalID = row.id },
                    onLogFixed: { amount in logFixedAttention(amount, row: row) },
                    onNavigate: prepareForNavigation
                )
            }
        }
        .padding(.horizontal, 12)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCornerRadius, style: .continuous))
    }

    private func logFixedAttention(_ amount: Double, row: AttentionGoalSummaryRow) {
        let previousEntryID = attentionViewModel.lastQuickLoggedEntryID
        attentionViewModel.logFixedAmount(amount, goalID: row.id)
        guard attentionViewModel.lastQuickLoggedEntryID != previousEntryID else { return }
        let amountText = AttentionStatusFormatter.amountLabel(amount, unit: row.targetUnit)
        let message = "Logged \(amountText) for \(row.name)"
        showToast(message: message, kind: .attentionQuickLog)
        announce(message + ". Undo available.")
    }

    // MARK: - Undo toast

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            let layout: AnyLayout = isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(spacing: 10))
            layout {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.appToastIcon)
                Text(toast.message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.appToastInk)
                    .fixedSize(horizontal: false, vertical: true)
                if !isAccessibilitySize { Spacer(minLength: 0) }
                Button("Undo") { performUndo(for: toast) }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(Color.appToastInk)
                    .foregroundStyle(Color.appToastBackground)
                    .fontWeight(.semibold)
                    .clipShape(Capsule())
                    .accessibilityIdentifier("today.undoToast.undoButton")
            }
            .padding(.leading, 18)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .background(Color.appToastBackground)
            .clipShape(RoundedRectangle(cornerRadius: isAccessibilitySize ? 20 : 30, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("today.undoToast")
        }
    }

    private func showToast(message: String, kind: TodayToastKind) {
        toastDismissTask?.cancel()
        withAnimation(reduceMotion ? nil : .default) {
            toast = TodayToast(message: message, kind: kind)
        }
        toastDismissTask = Task {
            try? await Task.sleep(for: Self.toastDuration)
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .default) { toast = nil }
        }
    }

    private func hideToast() {
        toastDismissTask?.cancel()
        withAnimation(reduceMotion ? nil : .default) { toast = nil }
    }

    private func performUndo(for toast: TodayToast) {
        switch toast.kind {
        case .habitCompletion(let habitID):
            if let freshRow = viewModel.rows.first(where: { $0.id == habitID }) {
                viewModel.toggleCompletion(for: freshRow)
            }
            withAnimation(reduceMotion ? nil : .default) { pendingDoneIDs.remove(habitID) }
        case .attentionQuickLog:
            attentionViewModel.undoLastQuickLog()
        }
        hideToast()
    }

    private func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Label {
                Text("No Habits Yet")
                    .accessibilityIdentifier("today.emptyState.title")
            } icon: {
                Image(systemName: "sun.max")
            }
        } description: {
            Text("Habits you create will show up here when they're due today.")
        } actions: {
            Button("Create Habit") {
                viewModel.requestCreation()
            }
            .accessibilityIdentifier("today.emptyState.createHabitButton")
        }
    }

    // MARK: - Toolbar

    /// `.glassProminent` is iOS 26+; `.borderedProminent` is the iOS 17
    /// fallback this app's deployment target still needs to support.
    @ViewBuilder
    private func addButton(label: String, systemImage: String, identifier: String, action: @escaping () -> Void) -> some View {
        if #available(iOS 26, *) {
            Button(action: action) { Label(label, systemImage: systemImage) }
                .buttonStyle(.glassProminent)
                .tint(Color.accentColor)
                .accessibilityIdentifier(identifier)
        } else {
            Button(action: action) { Label(label, systemImage: systemImage) }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor)
                .accessibilityIdentifier(identifier)
        }
    }
}

/// Each navigation destination owns its model for the destination's identity.
/// Re-evaluating Today (timers, tab refresh, accessibility activation) must
/// never replace a loaded detail model with a fresh, unloaded instance.
private struct HabitDetailDestination: View {
    @State private var viewModel: HabitDetailViewModel
    let onViewHistory: (UUID) -> Void

    init(habitID: UUID, repository: HabitRepository, onViewHistory: @escaping (UUID) -> Void) {
        _viewModel = State(initialValue: HabitDetailViewModel(habitID: habitID, repository: repository))
        self.onViewHistory = onViewHistory
    }

    var body: some View {
        HabitDetailView(viewModel: viewModel, onViewHistory: onViewHistory)
    }
}

private struct AttentionDetailDestination: View {
    let goalID: UUID
    let type: AttentionGoalType
    let repository: AttentionRepository
    var body: some View {
        if type == .maxDurationPerDay {
            AttentionGoalDetailDestination(goalID: goalID, repository: repository)
        } else {
            AttentionWindowDetailView(viewModel: AttentionWindowDetailViewModel(goalID: goalID, repository: repository))
        }
    }
}

private struct AttentionGoalDetailDestination: View {
    @State private var viewModel: AttentionGoalDetailViewModel

    init(goalID: UUID, repository: AttentionRepository) {
        _viewModel = State(initialValue: AttentionGoalDetailViewModel(goalID: goalID, repository: repository))
    }

    var body: some View {
        AttentionGoalDetailView(viewModel: viewModel)
    }
}

private struct HabitRowView: View {
    let row: TodayHabitRow
    let isAccessibilitySize: Bool
    let onToggle: () -> Void
    let onNavigate: () -> Void

    var body: some View {
        if isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                openLink
                Button(action: onToggle) {
                    Text(row.isCompletedToday ? toggleLabel.done : toggleLabel.pending)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor)
                .accessibilityIdentifier("today.completeButton.\(row.id.uuidString)")
                .accessibilityLabel(accessibilityToggleLabel)
            }
            .padding(.vertical, 10)
        } else {
            HStack(spacing: 12) {
                openLink
                toggleControl
            }
            .padding(.vertical, 4)
        }
    }

    private var openLink: some View {
        // A sibling NavigationLink, not a wrapper around the completion
        // button below: nesting a Button inside a NavigationLink's label
        // would make the button unreachable, since the link intercepts all
        // taps within its own content. Opening detail must never also log a
        // completion, so the two controls must stay independent.
        NavigationLink(value: row.id) {
            HStack(spacing: 12) {
                Image(systemName: row.iconName)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: isAccessibilitySize ? nil : 32)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.appInk)
                    if let recoveryContext = row.recoveryContext {
                        Label(recoveryContext, systemImage: "arrow.clockwise")
                            .labelStyle(.titleAndIcon)
                            .font(.caption)
                            .foregroundStyle(Color.appRecovery)
                    } else {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Color.appInkSecondary)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .accessibilityLabel("Open \(row.name) details")
        // Fires synchronously on tap, before the push — see
        // `TodayView.prepareForNavigation`'s doc comment for why this can't
        // wait for `.onDisappear`.
        .simultaneousGesture(TapGesture().onEnded(onNavigate))
    }

    private var toggleControl: some View {
        Button(action: onToggle) {
            ZStack {
                Circle()
                    .strokeBorder(Color.accentColor, lineWidth: 2.5)
                    .opacity(row.isCompletedToday ? 0 : 1)
                Circle()
                    .fill(Color.accentColor)
                    .opacity(row.isCompletedToday ? 1 : 0)
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.appOnAccent)
                    .opacity(row.isCompletedToday ? 1 : 0)
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .contentTransition(.symbolEffect(.replace))
        .accessibilityIdentifier("today.completeButton.\(row.id.uuidString)")
        .accessibilityLabel(accessibilityToggleLabel)
    }

    private var accessibilityToggleLabel: String {
        row.isCompletedToday
            ? HabitPolarityFormatter.undoActionLabel(habitName: row.name, polarity: row.polarity)
            : HabitPolarityFormatter.completionActionLabel(habitName: row.name, polarity: row.polarity)
    }

    private var toggleLabel: (pending: String, done: String) {
        switch row.polarity {
        case .positive: return ("Mark done", "Done")
        case .avoidance: return ("Log success", "Logged")
        }
    }

    private var subtitle: String {
        if row.isSkippedToday { return "Skipped today · " + row.scheduleDescription }
        if let weeklyProgress = row.weeklyProgress {
            return "\(row.scheduleDescription) — \(weeklyProgress.completed)/\(weeklyProgress.target) this week"
        }
        return row.scheduleDescription
    }
}

private struct AttentionGoalRowView: View {
    let row: AttentionGoalSummaryRow
    let isAccessibilitySize: Bool
    let onOpenQuickLogSheet: () -> Void
    let onLogFixed: (Double) -> Void
    let onNavigate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // A sibling NavigationLink, not a wrapper around the chips below,
            // for the same reason as `HabitRowView`: opening detail must
            // never also log usage.
            NavigationLink(value: AttentionGoalNavigationID(id: row.id)) {
                HStack(spacing: 12) {
                    Image(systemName: "hourglass")
                        .font(.title2)
                        .foregroundStyle(stateColor)
                        .frame(width: isAccessibilitySize ? nil : 32)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.appInk)
                        Text(row.statusLabel)
                            .font(.caption)
                            .foregroundStyle(Color.appInkSecondary)
                    }

                    Spacer(minLength: 0)
                }
            }
            .accessibilityLabel("Open \(row.name) details")
            .simultaneousGesture(TapGesture().onEnded(onNavigate))

            if row.goalType == .maxDurationPerDay { chipRow }
        }
        .padding(.vertical, 8)
    }

    /// "+5"/"+15" log a fixed amount instantly, with no sheet — the fast
    /// one-tap path `design/exploration/TODAY_CONCEPTS.md`'s Balance concept
    /// calls for. "Other…" keeps the original tap-to-open-sheet flow and its
    /// exact accessibility label, unchanged, for a custom amount.
    private var chipRow: some View {
        let layout: AnyLayout = isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            chip("+5") { onLogFixed(5) }
                .accessibilityIdentifier("today.logUsage5Button.\(row.id.uuidString)")
                .accessibilityLabel("Log 5 \(unitNoun) for \(row.name)")
            chip("+15") { onLogFixed(15) }
                .accessibilityIdentifier("today.logUsage15Button.\(row.id.uuidString)")
                .accessibilityLabel("Log 15 \(unitNoun) for \(row.name)")
            chip("Other…", action: onOpenQuickLogSheet)
                .accessibilityIdentifier("today.logUsageOtherButton.\(row.id.uuidString)")
                .accessibilityLabel("Log usage for \(row.name)")
        }
    }

    private func chip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .frame(minHeight: 44)
                .padding(.horizontal, 14)
                .frame(maxWidth: isAccessibilitySize ? .infinity : nil)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .background(Color.appAccentSoft)
        .clipShape(Capsule())
    }

    private var unitNoun: String {
        switch row.targetUnit {
        case .minutes: return "minutes"
        }
    }

    private var stateColor: Color {
        switch row.state {
        case .healthy: return .accentColor
        case .nearLimit: return .appRecovery
        case .exceeded: return .appOverBudget
        case nil: return .secondary
        }
    }
}

#Preview {
    let container = try! AppPersistence.makeContainer(inMemory: true)
    let repository = SwiftDataHabitRepository(modelContext: container.mainContext)
    let attentionRepository = SwiftDataAttentionRepository(modelContext: container.mainContext)
    NavigationStack {
        TodayView(
            viewModel: TodayViewModel(repository: repository),
            repository: repository,
            attentionViewModel: AttentionSummaryViewModel(repository: attentionRepository),
            attentionRepository: attentionRepository
        )
    }
}
