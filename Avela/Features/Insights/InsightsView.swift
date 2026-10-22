import SwiftUI

/// Read-only weekly habit review. Defaults to the last completed local
/// calendar week; "Previous"/"Next" move between completed weeks only — the
/// in-progress current week is never shown. Renders only what
/// `InsightsViewModel` hands it: no SwiftData access or aggregation math
/// happens here. Manually reported attention remains separate from habit
/// consistency. Static charts visualize existing factual ratios, never
/// inferred usage or invented intermediate trend points.
struct InsightsView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var consistencyDisplaySize = 58
    @State private var lens: InsightsReportsView.Lens = .week
    @State private var showsSharePreview = false
    @Bindable var viewModel: InsightsViewModel
    var onViewHistory: (UUID) -> Void = { _ in }
    var reflectionRepository: ReflectionRepository? = nil

    var body: some View {
        content
            .appThemeCanvas()
        .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if viewModel.insights?.overallConsistency != nil {
                        Button { showsSharePreview = true } label: {
                            Image(systemName: "square.and.arrow.up").frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("Preview a Weekly Progress Share Card")
                        .accessibilityIdentifier("insights.share")
                    }
                    if let reflectionRepository {
                        NavigationLink { ReflectionView(viewModel: viewModel.reflectionModel(repository: reflectionRepository)) } label: { Image(systemName: "square.and.pencil").frame(minWidth: 44, minHeight: 44) }
                            .accessibilityLabel("Private Weekly Reflection").accessibilityIdentifier("insights.reflection")
                    }
                    if viewModel.hasAnyGoals {
                        Button {
                            viewModel.goToPreviousWeek()
                        } label: {
                            Image(systemName: "chevron.backward").frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("Previous Week")
                        .accessibilityIdentifier("insights.previousWeekButton")

                        Button {
                            viewModel.goToNextWeek()
                        } label: {
                            Image(systemName: "chevron.forward").frame(minWidth: 44, minHeight: 44)
                        }
                        .disabled(!viewModel.canGoToNextWeek)
                        .accessibilityLabel("Next Week")
                        .accessibilityIdentifier("insights.nextWeekButton")
                    }
                }
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
            .task { viewModel.load() }
            .sheet(isPresented: $showsSharePreview) {
                if let insights = viewModel.insights {
                    InsightsShareView(insights: insights, weekLabel: viewModel.weekRangeLabel)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if !viewModel.hasAnyGoals {
            noHabitsEmptyState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let insights = viewModel.insights, let overall = insights.overallConsistency {
                        summaryCard(for: insights, overallConsistency: overall)
                    } else {
                        weekRangeHeader
                    }
                    reportPicker
                    if lens == .week {
                        if let insights = viewModel.insights, insights.overallConsistency != nil {
                            highlightsCard(for: insights)
                            habitBreakdown(for: insights)
                        } else if viewModel.hasAnyHabits { notEnoughDataState }
                        if viewModel.hasAnyAttentionBudgets { attentionCard }
                    if viewModel.hasMadeRoomReview {
                        NavigationLink {
                            if let model = viewModel.madeRoomModel() { MadeRoomReviewView(viewModel: model) }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "leaf")
                                    .font(.title3).foregroundStyle(palette.accent)
                                    .frame(width: 40, height: 40)
                                    .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 12))
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("What I Made Room For").font(.headline)
                                    Text("Your intentions, reviewed").font(.subheadline).foregroundStyle(Color.appInkSecondary)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.appInkSecondary).accessibilityHidden(true)
                            }
                            .frame(minHeight: 44)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityIdentifier("insights.madeRoomReview")
                        .padding(20)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: 22))
                    }
                    if let pattern = viewModel.weekdayPattern {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Daily Habit Patterns").font(.headline).accessibilityAddTraits(.isHeader)
                            Text("Most consistent: \(viewModel.weekdayNames(pattern.strongestWeekdays))")
                            Text("Less consistent: \(viewModel.weekdayNames(pattern.weakestWeekdays))")
                            Text("Scheduled daily habits only. Each compared weekday has at least two resolved commitments.")
                                .font(.caption).foregroundStyle(Color.appInkSecondary)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: 22))
                        .accessibilityIdentifier("insights.weekdayPattern")
                    }
                    } else if let report = viewModel.report {
                        InsightsReportsView(report: report, calendar: viewModel.reportCalendar, lens: lens)
                    }
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: lens)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder private var reportPicker: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Picker("Report view", selection: $lens) {
                ForEach(InsightsReportsView.Lens.allCases) { value in Text(value.rawValue).tag(value) }
            }.pickerStyle(.menu).accessibilityIdentifier("insights.reportLens")
        } else {
            Picker("Report view", selection: $lens) {
                ForEach(InsightsReportsView.Lens.allCases) { value in Text(value.rawValue).tag(value) }
            }.pickerStyle(.segmented).accessibilityIdentifier("insights.reportLens")
        }
    }

    private var attentionCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Attention Budgets", systemImage: "hourglass").font(.headline).accessibilityAddTraits(.isHeader)
            if let week = viewModel.attentionWeek {
                if let rate = week.successRate {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(Self.percentageText(rate))
                            .font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(palette.accent)
                        Text("below budget").font(.subheadline).foregroundStyle(Color.appInkSecondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(Self.percentageText(rate)) of logged goal-days below budget")
                    .accessibilityIdentifier("insights.attentionSuccessRate")
                    metricBar(value: rate)
                    Text("\(week.successfulGoalDays) of \(week.loggedGoalDays) logged goal-days below budget.")
                        .font(.subheadline)
                } else {
                    Text("No manual usage logged this week")
                        .font(.subheadline).accessibilityIdentifier("insights.attentionNoData")
                }
                Divider()
                Text("Logging coverage").font(.subheadline.weight(.semibold))
                Text("\(week.loggedGoalDays) of \(week.eligibleGoalDays) goal-days logged manually. Unlogged days are unknown.")
                    .font(.footnote).foregroundStyle(Color.appInkSecondary)
                    .accessibilityIdentifier("insights.attentionCoverage")
                if week.eligibleGoalDays > 0 {
                    metricBar(value: Double(week.loggedGoalDays) / Double(week.eligibleGoalDays))
                }
            }
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .rilovaCard()
    }

    private var weekRangeHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your weekly review").font(.title2.weight(.semibold)).fontDesign(.rounded)
                .foregroundStyle(Color.appInk).accessibilityAddTraits(.isHeader)
            Text(viewModel.weekRangeLabel).font(.subheadline).foregroundStyle(Color.appInkSecondary)
                .accessibilityIdentifier("insights.weekRangeLabel")
            Label("Completed week", systemImage: "calendar")
                .font(.caption.weight(.medium)).foregroundStyle(Color.appInkSecondary)
        }
        .rilovaHeaderSurface()
    }

    private func summaryCard(for insights: WeeklyInsightsCalculator.WeeklyInsights, overallConsistency: Double) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("YOUR PROGRESS").font(.caption.weight(.bold)).tracking(1.5)
                    Text("Find your rhythm.")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer(minLength: 12)
                Image(systemName: "waveform.path").font(.title).foregroundStyle(palette.luminousHighlight)
                    .accessibilityHidden(true)
            }
            Text(viewModel.weekRangeLabel).font(.subheadline.weight(.medium))
                .accessibilityIdentifier("insights.weekRangeLabel")
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 20))
            layout {
                Text(Self.percentageText(overallConsistency))
                    .font(.system(size: consistencyDisplaySize, weight: .bold, design: .rounded))
                    .fontWidth(.expanded).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                    .accessibilityIdentifier("insights.overallConsistency")
                    .padding(.vertical, 10)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Overall Consistency").font(.headline).accessibilityAddTraits(.isHeader)
                    Text("Across \(insights.eligibleHabits.count) \(insights.eligibleHabits.count == 1 ? "habit" : "habits")")
                        .font(.subheadline)
                }
            }
            Text(Self.trendText(insights.trendInPercentagePoints))
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("insights.trend")
            Text("Completed week · Equal weight per habit")
                .font(.caption.weight(.medium))
            DisclosureGroup("How this is calculated") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Each eligible habit counts equally. Excused skips, pauses and pending periods are excluded. Daily habits count days; flexible weekly habits count weeks.")
                    Text("The prior-week change compares only habits with unchanged schedules and complete opportunities in both weeks. It can use a smaller group than the overall percentage.")
                }.font(.footnote).padding(.top, 8)
            }
            .font(.caption.weight(.medium))
            .disclosureGroupStyle(InsightsHeroDisclosureStyle())
        }
        .foregroundStyle(.white)
        .padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                palette.luminousGradient
                RilovaAurora().opacity(0.65)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func highlightsCard(for insights: WeeklyInsightsCalculator.WeeklyInsights) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("This week's highlights").font(.headline).accessibilityAddTraits(.isHeader)
            if insights.isBalancedWeek {
                Text(Self.balancedSummaryText(insights)).font(.subheadline).foregroundStyle(Color.appInkSecondary)
                    .accessibilityIdentifier("insights.balancedSummary")
            } else {
                if !insights.strongestHabitNames.isEmpty {
                    calloutRow(symbol: "sparkle", tint: palette.accent,
                               title: "Most consistent", value: insights.strongestHabitNames.joined(separator: " and "),
                               identifier: "insights.strongestHabit")
                }
                if !insights.habitsNeedingAttentionNames.isEmpty {
                    calloutRow(symbol: "arrow.up.right", tint: .appRecovery,
                               title: "Room to grow", value: insights.habitsNeedingAttentionNames.joined(separator: " and "),
                               identifier: "insights.needsAttention")
                }
            }
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .rilovaCard()
    }

    private func habitBreakdown(for insights: WeeklyInsightsCalculator.WeeklyInsights) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Habit by habit").font(.headline).accessibilityAddTraits(.isHeader)
            Text("Successful / resolved commitments")
                .font(.caption).foregroundStyle(Color.appInkSecondary)
            ForEach(insights.eligibleHabits, id: \.habitID) { habit in
                let commitmentNoun = habit.scheduledUnits == 1 ? "commitment" : "commitments"
                NavigationLink {
                    InsightsHabitDestination(viewModel: viewModel.habitDetailModel(for: habit.habitID), onViewHistory: onViewHistory)
                        .onDisappear { viewModel.load() }
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            HabitIconBadge(symbol: viewModel.habitIcons[habit.habitID] ?? "circle", isArchived: habit.isArchived)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(habit.habitName).font(.subheadline.weight(.semibold)).foregroundStyle(Color.appInk)
                                Text("\(habit.successfulUnits) of \(habit.scheduledUnits) \(commitmentNoun) successful")
                                    .font(.footnote).foregroundStyle(Color.appInkSecondary)
                                if habit.isArchived { Text("Archived").font(.caption).foregroundStyle(Color.appInkSecondary) }
                            }
                            Spacer(minLength: 4)
                            if !dynamicTypeSize.isAccessibilitySize {
                                Text(Self.percentageText(habit.percentage)).font(.subheadline.weight(.semibold)).foregroundStyle(palette.accent)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.appInkSecondary)
                            }
                        }
                        metricBar(value: habit.percentage)
                    }.padding(.vertical, 4)
                }
                .accessibilityLabel("\(habit.habitName)\(habit.isArchived ? ", archived" : ""), \(habit.successfulUnits) of \(habit.scheduledUnits) \(commitmentNoun) successful, \(Self.percentageText(habit.percentage)). View habit details")
                .accessibilityIdentifier("insights.habit.\(habit.habitName)")
                if habit.habitID != insights.eligibleHabits.last?.habitID { Divider() }
            }
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .rilovaCard()
    }

    private func metricBar(value: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.accentSoft).overlay(Capsule().stroke(palette.accent, lineWidth: 1))
                Capsule().fill(palette.accent).frame(width: geometry.size.width * value)
            }
        }.frame(height: 8).accessibilityHidden(true)
    }

    /// `tint` colors only the icon — per COMPONENT_SPEC, a callout's tint
    /// "is never the only cue," since the section title ("Strongest Habit" /
    /// "Needs Attention") already carries the meaning in plain text.
    private func calloutRow(symbol: String, tint: Color, title: String, value: String, identifier: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.medium))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(palette.surfaceSecondary, in: RoundedRectangle(cornerRadius: 11))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color.appInkSecondary)
                Text(value)
                    .font(.body.weight(.medium))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private var noHabitsEmptyState: some View {
        ContentUnavailableView {
            Label {
                Text("No Habits Yet")
                    .accessibilityIdentifier("insights.emptyState.title")
            } icon: {
                Image(systemName: "chart.bar")
            }
        } description: {
            Text("Create a habit on the Today tab, and your weekly review will appear here once a full week has passed.")
        }
    }

    private var notEnoughDataState: some View {
        ContentUnavailableView {
            Label {
                Text("Not Enough Data This Week")
                    .accessibilityIdentifier("insights.insufficientData.title")
            } icon: {
                Image(systemName: "chart.bar")
            }
        } description: {
            Text("No resolved habit commitments this week. Excused skips and pauses do not count against you.")
        }
    }

    private static func percentageText(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private static func trendText(_ percentagePoints: Double?) -> String {
        guard let percentagePoints else { return "Not enough comparable data." }
        let rounded = Int(percentagePoints.rounded())
        if rounded == 0 { return "No change from the prior week." }
        let direction = rounded > 0 ? "Up" : "Down"
        return "\(direction) \(abs(rounded)) percentage points from the prior week."
    }

    /// Replaces the strongest/needs-attention callouts when every eligible
    /// habit performed identically this week (including the single-habit
    /// case) — naming the same habit(s) as both "strongest" and "needing
    /// attention" would be self-contradictory, not informative.
    private static func balancedSummaryText(_ insights: WeeklyInsightsCalculator.WeeklyInsights) -> String {
        guard let overall = insights.overallConsistency else { return "" }
        let percent = percentageText(overall)
        if insights.eligibleHabits.count == 1, let only = insights.eligibleHabits.first {
            return "\(only.habitName) was your only tracked habit this week (\(percent))."
        }
        return "All \(insights.eligibleHabits.count) habits were equally consistent this week (\(percent))."
    }
}

#Preview {
    let container = try! AppPersistence.makeContainer(inMemory: true)
    NavigationStack {
        InsightsView(viewModel: InsightsViewModel(repository: SwiftDataHabitRepository(modelContext: container.mainContext)))
    }
}

/// State-owned destination survives parent refreshes while a detail load runs.
private struct InsightsHabitDestination: View {
    @State var viewModel: HabitDetailViewModel
    var onViewHistory: (UUID) -> Void
    var body: some View { HabitDetailView(viewModel: viewModel, onViewHistory: onViewHistory) }
}

/// Native disclosure semantics with an explicit, contrast-safe chevron and a
/// real 44-point label. The system's default disclosure arrow ignored tint on
/// the deep hero in native captures, so the style owns this small presentation.
private struct InsightsHeroDisclosureStyle: DisclosureGroupStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    configuration.label
                    Spacer(minLength: 8)
                    Image(systemName: configuration.isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold)).accessibilityHidden(true)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(configuration.isExpanded ? "Expanded" : "Collapsed")
            if configuration.isExpanded { configuration.content.foregroundStyle(.white) }
        }
    }
}
