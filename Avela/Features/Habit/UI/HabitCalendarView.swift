import SwiftUI

/// Read-only month history. Dates are accessibility elements, not undersized
/// buttons. At accessibility text sizes the grid becomes a dated vertical list.
struct HabitCalendarView: View {
    @State var viewModel: HabitCalendarViewModel
    @ScaledMetric(relativeTo: .title) private var streakFontSize = 34.0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.appPalette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                calendarIdentity
                if let month = viewModel.month {
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
                    if !dynamicTypeSize.isAccessibilitySize && !month.weeklyPeriods.isEmpty {
                        weeklyCommitments(month.weeklyPeriods)
                    }
                    streakSummary(month.streak, mixedUnits: month.hasMixedStreakUnits)
                    DisclosureGroup("Calendar key") { legend.padding(.top, 12) }
                        .font(.subheadline.weight(.medium)).tint(palette.accent)
                        .padding(18).rilovaCard()
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

    private var calendarIdentity: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Text("RECORDED RHYTHM").font(.caption2.weight(.bold)).tracking(1.8)
                    .foregroundStyle(palette.accent)
                Text(viewModel.habitName).font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.appInk).accessibilityAddTraits(.isHeader)
                    .fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading)
            if !dynamicTypeSize.isAccessibilitySize && contrast != .increased && !reduceTransparency {
                RilovaWorldArtwork(scene: .coast)
                    .frame(width: 92, height: 64).clipped()
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 8,
                        bottomTrailingRadius: 24, topTrailingRadius: 8))
                    .accessibilityHidden(true).allowsHitTesting(false)
            }
        }
    }

    private var monthNavigation: some View {
        HStack {
            Button { moveMonth(by: -1) } label: {
                Image(systemName: "chevron.backward").frame(minWidth: 48, minHeight: 48)
                    .background(palette.surface, in: Circle())
            }.disabled(!viewModel.canGoBack)
                .buttonStyle(RilovaPressStyle())
                .accessibilityLabel("Previous month").accessibilityIdentifier("habitCalendar.previousMonth")
            Spacer(minLength: 4)
            Text(viewModel.monthTitle).font(.system(.title2, design: .rounded, weight: .bold)).multilineTextAlignment(.center)
                .foregroundStyle(Color.appInk).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("habitCalendar.monthTitle")
            Spacer(minLength: 4)
            Button { moveMonth(by: 1) } label: {
                Image(systemName: "chevron.forward").frame(minWidth: 48, minHeight: 48)
                    .background(palette.surface, in: Circle())
            }.disabled(!viewModel.canGoForward)
                .buttonStyle(RilovaPressStyle())
                .accessibilityLabel("Next month").accessibilityIdentifier("habitCalendar.nextMonth")
        }
        .padding(.vertical, 2)
    }

    private func moveMonth(by amount: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { viewModel.moveMonth(by: amount) }
    }

    private func streakSummary(_ streak: HabitProgressCalculator.StreakResult, mixedUnits: Bool) -> some View {
        let singular = mixedUnits ? "successful commitment" : streak.unit == .days ? "day" : "weekly commitment"
        let noun = streak.currentStreak == 1 ? singular : singular + "s"
        let bestNoun = streak.bestStreak == 1 ? singular : singular + "s"
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 24))
        return VStack(alignment: .leading, spacing: 16) {
            layout {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Current streak").font(.caption.weight(.semibold))
                    Text("\(streak.currentStreak)")
                        .font(.system(size: streakFontSize, weight: .bold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(palette.accent)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 3)
                    Text(noun).font(.caption).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Current streak: \(streak.currentStreak) \(noun)")
                .accessibilityAddTraits(.isStaticText)
                .accessibilityIdentifier("habitCalendar.currentStreak")
                VStack(alignment: .leading, spacing: 5) {
                    Label("Personal best", systemImage: "sparkle").font(.caption.weight(.semibold))
                    Text("\(streak.bestStreak)")
                        .font(.system(size: streakFontSize, weight: .bold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(Color.appInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 3)
                    Text(bestNoun).font(.caption).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Personal best: \(streak.bestStreak) \(bestNoun)")
                .accessibilityAddTraits(.isStaticText)
                .accessibilityIdentifier("habitCalendar.bestStreak")
            }
            Text("Totals through today. Skips and pauses are neutral.")
                .font(.caption).foregroundStyle(Color.appInkSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color.appInk).padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surfaceSecondary, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func calendarGrid(_ month: HabitCalendarCalculator.Month) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(Array(viewModel.weekdayLabels.enumerated()), id: \.offset) { _, label in
                    Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(Color.appInkSecondary).frame(maxWidth: .infinity)
                }
            }.padding(.bottom, 7).accessibilityHidden(true)
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
                            Color.clear.frame(maxWidth: .infinity, minHeight: 60).accessibilityHidden(true)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 18)
        .rilovaCard()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: viewModel.monthTitle)
    }

    private func dayCell(_ day: HabitCalendarCalculator.Day, column: Int, connectsLeft: Bool, connectsRight: Bool) -> some View {
        VStack(spacing: 4) {
            Text("\(day.number)").font(.system(.title3, design: .rounded, weight: day.isToday ? .bold : .semibold)).monospacedDigit()
            Image(systemName: symbol(for: day.state)).font(.system(size: 10, weight: .semibold))
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .foregroundStyle(day.state == .success ? palette.prominentInk : stateColor(day.state))
        // Adjacent successful daily commitments form a visible ribbon. Weekly
        // check-ins have separate period outcomes below, never a fake daily chain.
         .background {
            if day.state == .success {
                RecordedDayRibbon(column: column, connectsLeft: connectsLeft, connectsRight: connectsRight)
                    .fill(LinearGradient(colors: [palette.prominentFill, palette.heroEnd],
                        startPoint: UnitPoint(x: -Double(column), y: 0),
                        endPoint: UnitPoint(x: Double(7 - column), y: 1)))
            } else if day.state == .logged {
                // Weekly or off-schedule facts stand alone. Joining these
                // would incorrectly turn recorded check-ins into a daily streak.
                Capsule().fill(palette.accentSoft).padding(.horizontal, 3).padding(.vertical, 5)
                    .overlay(Capsule().strokeBorder(palette.accent, lineWidth: 1).padding(.horizontal, 3).padding(.vertical, 5))
            } else if day.state == .skipped || day.state == .paused {
                Capsule().fill(palette.surfaceSecondary).padding(.horizontal, 4).padding(.vertical, 7)
            }
        }
        .overlay {
            if day.isToday { Capsule().strokeBorder(day.state == .success ? palette.prominentInk : Color.appInk, lineWidth: 1.5).padding(.horizontal, 4).padding(.vertical, 4) }
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
            ForEach(Array(periods.enumerated()), id: \.offset) { index, period in
                VStack(alignment: .leading, spacing: 10) {
                    Text(viewModel.periodLabel(period)).font(.subheadline.weight(.semibold))
                    HStack(spacing: 5) {
                        ForEach(0..<max(1, period.target), id: \.self) { opportunity in
                            Capsule().fill(opportunity < period.completedCount ? palette.accent : palette.surfaceSecondary)
                                .overlay(Capsule().strokeBorder(palette.accent.opacity(contrast == .increased ? 1 : 0.5), lineWidth: 1))
                                .frame(height: 7)
                        }
                    }.accessibilityHidden(true)
                    Label("\(period.completedCount) of \(period.target) days · \(weeklyLabel(period.outcome))",
                          systemImage: period.outcome == .success ? "checkmark.circle.fill" : period.outcome == .miss ? "circle.slash" : "clock")
                        .font(.caption).foregroundStyle(period.outcome == .success ? palette.accent : Color.appInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if index < periods.count - 1 { Divider().padding(.top, 4) }
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

/// Still, gently curved bands join only adjacent canonical daily successes.
/// Shared edge coordinates keep a row continuous without bridging a blank,
/// skip, pause or flexible-weekly check-in. Geometry never changes its meaning.
private struct RecordedDayRibbon: Shape {
    let column: Int
    let connectsLeft: Bool
    let connectsRight: Bool

    func path(in rect: CGRect) -> Path {
        let left = connectsLeft ? rect.minX : rect.minX + 3
        let right = connectsRight ? rect.maxX : rect.maxX - 3
        let leftWave = CGFloat(sin(Double(column) * 0.7) * 2)
        let rightWave = CGFloat(sin(Double(column + 1) * 0.7) * 2)
        let topLeft = rect.minY + 5 + leftWave
        let topRight = rect.minY + 5 + rightWave
        let bottomLeft = rect.maxY - 5 + leftWave
        let bottomRight = rect.maxY - 5 + rightWave
        let cap: CGFloat = min(16, (right - left) / 2)
        let start = left + (connectsLeft ? 0 : cap)
        let end = right - (connectsRight ? 0 : cap)
        var path = Path()
        path.move(to: CGPoint(x: start, y: topLeft))
        path.addCurve(to: CGPoint(x: end, y: topRight),
            control1: CGPoint(x: start + (end - start) / 3, y: topLeft),
            control2: CGPoint(x: end - (end - start) / 3, y: topRight))
        if connectsRight { path.addLine(to: CGPoint(x: right, y: bottomRight)) }
        else {
            path.addCurve(to: CGPoint(x: end, y: bottomRight),
                control1: CGPoint(x: right + cap * 0.35, y: topRight),
                control2: CGPoint(x: right + cap * 0.35, y: bottomRight))
        }
        path.addCurve(to: CGPoint(x: start, y: bottomLeft),
            control1: CGPoint(x: end - (end - start) / 3, y: bottomRight),
            control2: CGPoint(x: start + (end - start) / 3, y: bottomLeft))
        if connectsLeft { path.addLine(to: CGPoint(x: left, y: topLeft)) }
        else {
            path.addCurve(to: CGPoint(x: start, y: topLeft),
                control1: CGPoint(x: left - cap * 0.35, y: bottomLeft),
                control2: CGPoint(x: left - cap * 0.35, y: topLeft))
        }
        path.closeSubpath()
        return path
    }
}
