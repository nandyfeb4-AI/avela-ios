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
    @Bindable var viewModel: InsightsViewModel
    var onViewHistory: (UUID) -> Void = { _ in }
    var reflectionRepository: ReflectionRepository? = nil

    var body: some View {
        content
            .appThemeCanvas()
        .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
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
            .task {
                viewModel.load()
            }
    }

    @ViewBuilder
    private var content: some View {
        if !viewModel.hasAnyGoals {
            noHabitsEmptyState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    weekRangeHeader
                    if let insights = viewModel.insights, let overall = insights.overallConsistency {
                        summaryCard(for: insights, overallConsistency: overall)
                        highlightsCard(for: insights)
                        habitBreakdown(for: insights)
                    } else {
                        if viewModel.hasAnyHabits { notEnoughDataState }
                    }
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
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
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
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 22))
    }

    private var weekRangeHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your weekly review").font(.title3.weight(.semibold)).accessibilityAddTraits(.isHeader)
            Text(viewModel.weekRangeLabel).font(.subheadline).foregroundStyle(Color.appInkSecondary)
                .accessibilityIdentifier("insights.weekRangeLabel")
            Text("Completed week").font(.caption.weight(.medium)).foregroundStyle(palette.accent)
        }
    }

    private func summaryCard(for insights: WeeklyInsightsCalculator.WeeklyInsights, overallConsistency: Double) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Overall Consistency").font(.headline).accessibilityAddTraits(.isHeader)
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 18))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 22))
            layout {
                ZStack {
                    Circle().stroke(palette.accentSoft, lineWidth: 9).accessibilityHidden(true)
                    if overallConsistency > 0 {
                        Circle().trim(from: 0, to: overallConsistency)
                            .stroke(palette.accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .rotationEffect(.degrees(-90)).accessibilityHidden(true)
                    }
                    Text(Self.percentageText(overallConsistency))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.appInk).minimumScaleFactor(0.75)
                        .accessibilityIdentifier("insights.overallConsistency")
                }
                .frame(width: dynamicTypeSize.isAccessibilitySize ? 210 : 132,
                       height: dynamicTypeSize.isAccessibilitySize ? 210 : 132)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Across \(insights.eligibleHabits.count) \(insights.eligibleHabits.count == 1 ? "habit" : "habits")")
                        .font(.title3.weight(.semibold))
                    Text("Each habit counts equally. Excused skips and pauses are excluded.")
                        .font(.footnote).foregroundStyle(Color.appInkSecondary)
                }
            }
            Text(Self.trendText(insights.trendInPercentagePoints))
                .font(.subheadline.weight(.medium)).foregroundStyle(palette.accent)
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("insights.trend")
            if insights.trendInPercentagePoints != nil {
                Text("Trend compares only habits with compatible schedules and complete opportunities in both weeks. It can use a smaller group than the overall score.")
                    .font(.caption).foregroundStyle(Color.appInkSecondary)
            }
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 22))
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
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 22))
    }

    private func habitBreakdown(for insights: WeeklyInsightsCalculator.WeeklyInsights) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Habit by habit").font(.headline).accessibilityAddTraits(.isHeader)
            Text("Successful / resolved commitments. Daily schedules count days; flexible weekly schedules count weeks.")
                .font(.footnote).foregroundStyle(Color.appInkSecondary)
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
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 22))
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
