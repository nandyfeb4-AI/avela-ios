import SwiftUI

/// Read-only weekly habit review. Defaults to the last completed local
/// calendar week; "Previous"/"Next" move between completed weeks only — the
/// in-progress current week is never shown. Renders only what
/// `InsightsViewModel` hands it: no SwiftData access or aggregation math
/// happens here. Attention-budget results and day/weekday patterns are
/// deferred (see DATA_MODEL.md's "Phase 1 Insights") and have no controls
/// here, dead or otherwise.
struct InsightsView: View {
    @Bindable var viewModel: InsightsViewModel

    var body: some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if viewModel.hasAnyGoals {
                        Button {
                            viewModel.goToPreviousWeek()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .accessibilityLabel("Previous Week")
                        .accessibilityIdentifier("insights.previousWeekButton")

                        Button {
                            viewModel.goToNextWeek()
                        } label: {
                            Image(systemName: "chevron.right")
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
                VStack(alignment: .leading, spacing: 20) {
                    weekRangeHeader
                    if let insights = viewModel.insights, let overall = insights.overallConsistency {
                        summaryCard(for: insights, overallConsistency: overall)
                    } else {
                        if viewModel.hasAnyHabits { notEnoughDataState }
                    }
                    if viewModel.hasAnyAttentionGoals { attentionCard }
                    if let pattern = viewModel.weekdayPattern {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Daily Habit Patterns").font(.headline)
                            Text("Most consistent: \(viewModel.weekdayNames(pattern.strongestWeekdays))")
                            Text("Room to rebuild: \(viewModel.weekdayNames(pattern.weakestWeekdays))")
                            Text("Based on scheduled daily habits with at least two resolved commitments per compared weekday this week.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .accessibilityIdentifier("insights.weekdayPattern")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var attentionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Attention Budgets").font(.headline)
            if let week = viewModel.attentionWeek {
                if let rate = week.successRate {
                    Text("\(Self.percentageText(rate)) of logged goal-days below budget")
                        .accessibilityIdentifier("insights.attentionSuccessRate")
                } else {
                    Text("No manual usage logged this week")
                        .accessibilityIdentifier("insights.attentionNoData")
                }
                Text("\(week.loggedGoalDays) of \(week.eligibleGoalDays) goal-days logged manually. Unlogged days are unknown.")
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("insights.attentionCoverage")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
    }

    private var weekRangeHeader: some View {
        Text(viewModel.weekRangeLabel)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("insights.weekRangeLabel")
    }

    @ViewBuilder
    private func summaryCard(for insights: WeeklyInsightsCalculator.WeeklyInsights, overallConsistency: Double) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Overall Consistency")
                    .font(.headline)
                Text(Self.percentageText(overallConsistency))
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    .accessibilityIdentifier("insights.overallConsistency")
                Text(Self.trendText(insights.trendInPercentagePoints))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("insights.trend")
            }

            if insights.isBalancedWeek {
                Text(Self.balancedSummaryText(insights))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("insights.balancedSummary")
            } else {
                if !insights.strongestHabitNames.isEmpty {
                    calloutRow(
                        symbol: "arrow.up.circle.fill",
                        tint: .accentColor,
                        title: insights.strongestHabitNames.count == 1 ? "Strongest Habit" : "Strongest Habits",
                        value: insights.strongestHabitNames.joined(separator: " and "),
                        identifier: "insights.strongestHabit"
                    )
                }

                if !insights.habitsNeedingAttentionNames.isEmpty {
                    calloutRow(
                        symbol: "arrow.up.forward.circle",
                        tint: .appRecovery,
                        title: insights.habitsNeedingAttentionNames.count == 1 ? "Needs Attention" : "Need Attention",
                        value: insights.habitsNeedingAttentionNames.joined(separator: " and "),
                        identifier: "insights.needsAttention"
                    )
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
    }

    /// `tint` colors only the icon — per COMPONENT_SPEC, a callout's tint
    /// "is never the only cue," since the section title ("Strongest Habit" /
    /// "Needs Attention") already carries the meaning in plain text.
    private func calloutRow(symbol: String, tint: Color, title: String, value: String, identifier: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
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
            Text("None of your habits had scheduled activity during this week.")
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
