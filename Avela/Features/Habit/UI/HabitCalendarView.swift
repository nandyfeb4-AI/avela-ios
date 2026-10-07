import SwiftUI

/// Read-only month history. Dates are accessibility elements, not undersized
/// buttons. At accessibility text sizes the grid becomes a dated vertical list.
struct HabitCalendarView: View {
    @State var viewModel: HabitCalendarViewModel
    @ScaledMetric(relativeTo: .largeTitle) private var streakFontSize = 64.0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.appPalette) private var palette
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(viewModel.habitName).font(.title3.weight(.semibold)).accessibilityAddTraits(.isHeader)
                if let month = viewModel.month {
                    streakSummary(month.streak, mixedUnits: month.hasMixedStreakUnits)
                    monthNavigation
                    if dynamicTypeSize.isAccessibilitySize {
                        if !month.weeklyPeriods.isEmpty { weeklyCommitments(month.weeklyPeriods) }
                        Text("Recorded and tracked dates. Dates before tracking and unrecorded upcoming dates are omitted from this list.")
                            .font(.footnote).foregroundStyle(Color.appInkSecondary)
                        VStack(spacing: 0) {
                            ForEach(month.days.filter { $0.state != .notStarted && $0.state != .future }) { day in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(viewModel.dateLabel(day)).font(.body.weight(.semibold))
                                    Label(day.state.label, systemImage: symbol(for: day.state))
                                        .foregroundStyle(stateColor(day.state))
                                }
                                .padding(.vertical, 10)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(accessibilityLabel(day))
        .accessibilityAddTraits(.isStaticText)
                                .accessibilityIdentifier("habitCalendar.day.\(day.key)")
                                Divider()
                            }
                        }
                    } else {
                        calendarGrid(month)
                    }
                    legend
                    if !dynamicTypeSize.isAccessibilitySize && !month.weeklyPeriods.isEmpty {
                        weeklyCommitments(month.weeklyPeriods)
                    }
                    Text("Read-only history. Skips and pauses don't break or extend your streak. Calendar dates keep the day recorded when you logged them.")
                        .font(.footnote).foregroundStyle(Color.appInkSecondary)
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView("Calendar Unavailable", systemImage: "calendar.badge.exclamationmark", description: Text(error))
                    Button("Try Again") { viewModel.load() }
                } else { ProgressView() }
            }
            .padding(20)
        }
        .appThemeCanvas()
        .navigationTitle("Calendar History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.isCurrentMonth {
                ToolbarItem(placement: .primaryAction) {
                    Button("This Month") { viewModel.showCurrentMonth() }
                        .accessibilityIdentifier("habitCalendar.currentMonth")
                }
            }
        }
        .task { viewModel.load() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { viewModel.load() } }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in viewModel.load() }
    }

    private var monthNavigation: some View {
        HStack {
            Button { viewModel.moveMonth(by: -1) } label: {
                Image(systemName: "chevron.backward").frame(minWidth: 48, minHeight: 48)
            }.disabled(!viewModel.canGoBack)
                .accessibilityLabel("Previous month").accessibilityIdentifier("habitCalendar.previousMonth")
            Spacer(minLength: 4)
            Text(viewModel.monthTitle).font(.headline).multilineTextAlignment(.center)
                .accessibilityIdentifier("habitCalendar.monthTitle")
            Spacer(minLength: 4)
            Button { viewModel.moveMonth(by: 1) } label: {
                Image(systemName: "chevron.forward").frame(minWidth: 48, minHeight: 48)
            }.disabled(!viewModel.canGoForward)
                .accessibilityLabel("Next month").accessibilityIdentifier("habitCalendar.nextMonth")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: AppMetrics.cardCornerRadius))
    }

    private func streakSummary(_ streak: HabitProgressCalculator.StreakResult, mixedUnits: Bool) -> some View {
        let singular = mixedUnits ? "successful commitment" : streak.unit == .days ? "day" : "weekly commitment"
        let noun = streak.currentStreak == 1 ? singular : singular + "s"
        let bestNoun = streak.bestStreak == 1 ? singular : singular + "s"
        return VStack(alignment: .leading, spacing: 10) {
            Label("Current Streak", systemImage: "link")
                .font(.subheadline.weight(.semibold))
            Text("\(streak.currentStreak)")
                .font(.system(size: streakFontSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
                .accessibilityLabel("Current streak: \(streak.currentStreak) \(noun)")
                .accessibilityIdentifier("habitCalendar.currentStreak")
            Text(noun).font(.headline)
            Divider().overlay(Color.white.opacity(0.35)).accessibilityHidden(true)
            if dynamicTypeSize.isAccessibilitySize {
                Text("Personal best: \(streak.bestStreak) \(bestNoun)")
                    .font(.subheadline.weight(.medium))
                    .accessibilityIdentifier("habitCalendar.bestStreak")
            } else {
                Label("Personal best: \(streak.bestStreak) \(bestNoun)", systemImage: "sparkles")
                    .font(.subheadline.weight(.medium))
                    .accessibilityIdentifier("habitCalendar.bestStreak")
            }
            Text("Totals through today. Skips and pauses are neutral.")
                .font(.caption)
        }
        .foregroundStyle(.white)
        .padding(22).frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.heroGradient)
        .padding(.bottom, dynamicTypeSize.isAccessibilitySize ? 0 : 96)
        .overlay(alignment: .bottom) {
            if !dynamicTypeSize.isAccessibilitySize {
                ThemeLandscape(theme: palette.theme).frame(height: 96)
            }
        }
        .background(palette.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCornerRadius, style: .continuous))
    }

    private func calendarGrid(_ month: HabitCalendarCalculator.Month) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(Array(viewModel.weekdayLabels.enumerated()), id: \.offset) { _, label in
                    Text(label).font(.caption).foregroundStyle(Color.appInkSecondary).frame(maxWidth: .infinity)
                }
            }.accessibilityHidden(true)
            let count = month.leadingBlankCount + month.days.count
            ForEach(0..<((count + 6) / 7), id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { column in
                        let index = row * 7 + column - month.leadingBlankCount
                        if month.days.indices.contains(index) {
                            let day = month.days[index]
                            dayCell(day, column: column,
                                connectsLeft: column > 0 && index > 0 && month.days[index - 1].state == .success,
                                connectsRight: column < 6 && index + 1 < month.days.count && month.days[index + 1].state == .success)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 54).accessibilityHidden(true)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: AppMetrics.cardCornerRadius))
    }

    private func dayCell(_ day: HabitCalendarCalculator.Day, column: Int, connectsLeft: Bool, connectsRight: Bool) -> some View {
        VStack(spacing: 3) {
            Text("\(day.number)").font(.body.monospacedDigit().weight(day.isToday ? .bold : .medium))
            Image(systemName: symbol(for: day.state)).font(.caption2)
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .foregroundStyle(day.state == .success ? palette.prominentInk : stateColor(day.state))
        // Adjacent successful daily commitments form a visible ribbon. Weekly
        // check-ins have separate period outcomes below, never a fake daily chain.
         .background {
            if day.state == .success {
                UnevenRoundedRectangle(topLeadingRadius: connectsLeft ? 0 : 14,
                    bottomLeadingRadius: connectsLeft ? 0 : 14,
                    bottomTrailingRadius: connectsRight ? 0 : 14,
                    topTrailingRadius: connectsRight ? 0 : 14)
                    .fill(LinearGradient(colors: [palette.prominentFill, palette.heroEnd],
                        startPoint: UnitPoint(x: -Double(column), y: 0),
                        endPoint: UnitPoint(x: Double(7 - column), y: 1)))
                    .padding(.vertical, 2)
            }
        }
        .overlay {
            if day.isToday { RoundedRectangle(cornerRadius: 9).strokeBorder(day.state == .success ? palette.prominentInk : Color.appInk, lineWidth: 1.5).padding(2) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(day))
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier("habitCalendar.day.\(day.key)")
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Success", systemImage: "checkmark.circle.fill")
            Label("Skipped · excused", systemImage: "minus.circle")
            Label("No success logged · finished daily commitment", systemImage: "circle.slash")
            Label("Pending · no miss", systemImage: "clock")
            Label("Not scheduled or before tracking", systemImage: "minus")
            Label("Paused", systemImage: "pause")
            Label("Upcoming", systemImage: "circle")
        }.font(.caption).foregroundStyle(Color.appInkSecondary)
    }

    private func weeklyCommitments(_ periods: [HabitProgressCalculator.ProgressPeriod]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Commitments").font(.headline).accessibilityAddTraits(.isHeader)
            Text("Targets count weeks, not daily check-ins. Edits and pauses can split a week.")
                .font(.footnote).foregroundStyle(Color.appInkSecondary)
            ForEach(Array(periods.enumerated()), id: \.offset) { _, period in
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.periodLabel(period)).font(.subheadline.weight(.semibold))
                    Label("\(period.completedCount) of \(period.target) days · \(weeklyLabel(period.outcome))",
                          systemImage: period.outcome == .success ? "checkmark.circle.fill" : period.outcome == .miss ? "circle.slash" : "clock")
                        .foregroundStyle(period.outcome == .success ? palette.accent : Color.appInkSecondary)
                }.accessibilityElement(children: .combine)
                    .accessibilityIdentifier("habitCalendar.week.\(period.localDateKey)")
            }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: AppMetrics.cardCornerRadius))
    }

    private func weeklyLabel(_ outcome: HabitProgressCalculator.Outcome) -> String {
        switch outcome {
        case .success: "Target met"
        case .miss: "Target not met"
        case .pending: "Pending · no miss"
        case .skip: "Excused"
        }
    }

    private func symbol(for state: HabitCalendarCalculator.DayState) -> String {
        switch state {
        case .success, .logged: "checkmark"
        case .skipped: "minus.circle"
        case .missed: "circle.slash"
        case .pending: "clock"
        case .weekly: "circle.dotted"
        case .paused: "pause"
        case .future: "circle"
        case .notScheduled, .notStarted: "minus"
        }
    }

    private func stateColor(_ state: HabitCalendarCalculator.DayState) -> Color {
        state == .success || state == .logged ? palette.accent : .appInkSecondary
    }

    private func accessibilityLabel(_ day: HabitCalendarCalculator.Day) -> String {
        "\(viewModel.dateLabel(day))\(day.isToday ? ", today" : ""), \(day.state.label)"
    }
}
