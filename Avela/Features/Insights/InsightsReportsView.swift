import SwiftUI
import Charts

/// Presentation of canonical, read-only reports. Separate bars are snapshots,
/// never an interpolated trend; accessible values stay available without plots.
struct InsightsReportsView: View {
    enum Lens: String, CaseIterable, Identifiable {
        case week = "Week", rhythm = "Rhythm", activity = "Activity"
        var id: String { rawValue }
    }

    @Environment(\.appPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    let report: InsightsReportCalculator.Report
    let calendar: Calendar
    let lens: Lens
    @State private var selectedQuantityID: String?
    @State private var monthNumber: Int?
    @State private var selectedWeek: Date?
    @State private var selectedQuantityWeek: String?

    private let foam = Color(red: 0.77, green: 0.96, blue: 0.88)
    private let lavender = Color(red: 0.77, green: 0.74, blue: 0.98)
    private let sunlight = Color(red: 0.99, green: 0.84, blue: 0.58)
    private var usesReadableValues: Bool { dynamicTypeSize >= .xxLarge }
    private var chartAnimation: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.4) }

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            if lens == .rhythm {
                rhythmCard
                weekdayCard
                if !report.quantities.isEmpty { quantityCard }
                if report.hasSessions { sessionCard }
            } else if lens == .activity {
                activityCard
            }
        }
        .onChange(of: report.interval) { _, _ in
            selectedWeek = nil
            selectedQuantityWeek = nil
        }
    }

    private var inspectedWeek: InsightsReportCalculator.Week? {
        guard let selectedWeek else { return report.weeks.last }
        return report.weeks.first { calendar.isDate($0.interval.start, equalTo: selectedWeek, toGranularity: .weekOfYear) } ?? report.weeks.last
    }

    private var rhythmCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 7) {
                Label("Your rhythm", systemImage: "water.waves")
                    .font(.title2.weight(.bold)).fontDesign(.rounded).accessibilityAddTraits(.isHeader)
                Text("12 completed weeks · \(rangeLabel(report.interval))").font(.caption).foregroundStyle(.white.opacity(0.85))
            }
            if let week = inspectedWeek {
                let layout = usesReadableValues
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 7))
                    : AnyLayout(HStackLayout(alignment: .lastTextBaseline, spacing: 16))
                layout {
                    Text(week.consistency.map(percent) ?? "—")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold)).monospacedDigit()
                        .foregroundStyle(foam).contentTransition(.numericText())
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Week of \(shortDate(week.interval.start))").font(.subheadline.weight(.semibold))
                        Text(week.consistency == nil ? "No resolved commitments" : "\(week.eligibleHabitIDs.count) eligible \(week.eligibleHabitIDs.count == 1 ? "habit" : "habits")")
                            .font(.caption).foregroundStyle(.white.opacity(0.85))
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("insights.rhythm.selection")
                .animation(chartAnimation, value: week.id)
            }
            if !usesReadableValues { tidalChart }
            if !report.weeks.contains(where: { $0.consistency != nil }) {
                Text("A little time, then a little perspective. Your first weekly snapshot will appear after a week with resolved commitments.")
                    .font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }
            Text(usesReadableValues
                 ? "Each week uses that week's eligible habits. These are weekly snapshots, not a like-for-like trend. No data means no resolved commitments."
                 : "Each bar uses that week's eligible habits. These are weekly snapshots, not a like-for-like trend. × means no resolved commitments.")
                .font(.caption).foregroundStyle(.white.opacity(0.87))
                .accessibilityIdentifier(usesReadableValues ? "insights.rhythm.accessibleSummary" : "insights.rhythm.chartSummary")
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(report.weeks) { week in
                        let layout = usesReadableValues
                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
                        layout {
                            Text(shortDate(week.interval.start))
                            if !usesReadableValues { Spacer() }
                            Text(week.consistency.map(percent) ?? "No data").fontWeight(.semibold).monospacedDigit()
                        }
                        .fixedSize(horizontal: false, vertical: true).accessibilityElement(children: .combine)
                    }
                }.font(.subheadline).padding(.top, 10)
            } label: { Text("View weekly values").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading) }
            .font(.subheadline)
            .disclosureGroupStyle(ReportValuesDisclosureStyle(identifier: "insights.rhythm.values"))
        }
        .foregroundStyle(.white).padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.luminousGradient)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var tidalChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart(report.weeks) { week in
                if let rate = week.consistency {
                    BarMark(x: .value("Week", week.interval.start, unit: .weekOfYear), y: .value("Consistency", rate), width: .ratio(0.68))
                        .foregroundStyle(LinearGradient(colors: [foam, Color.cyan.opacity(0.55)], startPoint: .top, endPoint: .bottom))
                        .cornerRadius(7)
                    PointMark(x: .value("Week", week.interval.start, unit: .weekOfYear), y: .value("Consistency", rate))
                        .symbolSize(rate > 0 ? 16 : 11).foregroundStyle(foam)
                } else {
                    PointMark(x: .value("Week", week.interval.start, unit: .weekOfYear), y: .value("No data", 0))
                        .symbol(.cross).symbolSize(22).foregroundStyle(.white.opacity(0.85))
                }
                if let selectedWeek, calendar.isDate(selectedWeek, equalTo: week.interval.start, toGranularity: .weekOfYear) {
                    RuleMark(x: .value("Selected week", week.interval.start, unit: .weekOfYear))
                        .foregroundStyle(sunlight).lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                }
            }
            .chartYScale(domain: 0...1)
            .chartYAxis { AxisMarks(values: [0.0, 0.5, 1.0]) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.14))
                AxisValueLabel { if let value = value.as(Double.self) { Text(percent(value)).foregroundStyle(.white.opacity(0.85)) } }
            } }
            .chartXAxis { AxisMarks(values: .stride(by: .weekOfYear, count: 3)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day()).foregroundStyle(.white.opacity(0.85))
            } }
            .chartXSelection(value: $selectedWeek)
            .frame(height: 200).accessibilityHidden(true)
            .animation(chartAnimation, value: report.interval)
            Text("Tap or drag a bar to explore a week.").font(.caption).foregroundStyle(.white.opacity(0.85)).accessibilityHidden(true)
        }
    }

    private var weekdayCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            reportHeading("A week in perspective", subtitle: "12 completed weeks · daily commitments", symbol: "calendar")
            Text("Which days have had room?").font(.title2.weight(.semibold)).fontDesign(.rounded)
                .fixedSize(horizontal: false, vertical: true)
            if !usesReadableValues {
                VStack(spacing: 12) {
                    ForEach(report.weekdays) { day in
                        HStack(spacing: 12) {
                            Text(calendar.shortWeekdaySymbols[day.number - 1]).font(.subheadline.weight(.semibold)).frame(width: 42, alignment: .leading)
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(palette.accentSoft)
                                    if let value = day.consistency, value > 0 {
                                        Capsule().fill(palette.accent.gradient).frame(width: geometry.size.width * value)
                                    }
                                    if day.consistency == nil {
                                        Circle().stroke(palette.accent, lineWidth: 1).frame(width: 8, height: 8).padding(.leading, 4)
                                    }
                                }
                            }.frame(height: 10)
                            Text(day.consistency.map(percent) ?? "—").font(.subheadline.weight(.semibold)).monospacedDigit().frame(width: 48, alignment: .trailing)
                        }
                    }
                }.padding(.vertical, 4).accessibilityHidden(true)
            }
            Text("Successful / resolved opportunities. Flexible weekly habits, skips, pauses and pending days are excluded.")
                .font(.caption).foregroundStyle(Color.appInkSecondary)
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(report.weekdays) { day in
                        Text("\(calendar.weekdaySymbols[day.number - 1]): \(day.successes) of \(day.resolved) successful\(day.resolved == 0 ? " · no resolved opportunities" : "")")
                            .font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(.top, 10)
            } label: { Text("View weekday counts").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading) }.font(.subheadline)
        }
        .padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quantity: InsightsReportCalculator.Quantity? {
        report.quantities.first { $0.id == selectedQuantityID } ?? report.quantities.first
    }

    private var quantityCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            reportHeading("What adds up", subtitle: "Recorded amounts · 12 completed weeks", symbol: "chart.bar.xaxis")
            Picker("Habit and captured unit", selection: Binding(get: { quantity?.id ?? "" }, set: { selectedQuantityID = $0; selectedQuantityWeek = nil })) {
                ForEach(report.quantities) { item in Text("\(item.habitName) · \(item.unit.rawValue)").tag(item.id) }
            }.pickerStyle(.menu).accessibilityIdentifier("insights.quantityPicker")
            if let quantity {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(quantity.total.formatted()) \(quantity.unit.name(for: quantity.total))")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(Color.appInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(quantity.habitName).font(.headline).foregroundStyle(Color.appInkSecondary)
                }
                if !usesReadableValues { quantityChart(quantity) }
                Text(usesReadableValues
                     ? "Amounts stay in their captured unit. A week with no amount recorded does not establish what happened."
                     : "Amounts stay in their captured unit. An empty bar means no amount recorded; it does not establish what happened.")
                    .font(.caption).foregroundStyle(Color.appInkSecondary)
                    .accessibilityIdentifier(usesReadableValues ? "insights.quantity.accessibleSummary" : "insights.quantity.chartSummary")
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(quantity.weeks) { week in
                            Text("\(shortDate(week.date)): \(week.amount) \(quantity.unit.name(for: week.amount)) recorded")
                                .font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }.padding(.top, 10)
                } label: { Text("View recorded amounts").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading) }.font(.subheadline)
            }
        }
        .padding(22).frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.atmosphere, in: RoundedRectangle(cornerRadius: 28))
        .overlay(alignment: .topLeading) { Capsule().fill(palette.accent).frame(width: 42, height: 4).padding(.leading, 22) }
    }

    private func quantityChart(_ quantity: InsightsReportCalculator.Quantity) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart(quantity.weeks) { week in
                BarMark(x: .value(quantity.unit.rawValue, week.amount), y: .value("Week", shortDate(week.date)), height: .ratio(0.6))
                    .foregroundStyle(palette.accent.opacity(selectedQuantityWeek == nil || selectedQuantityWeek == shortDate(week.date) ? 1 : 0.4).gradient)
                    .cornerRadius(5)
            }
            .chartXAxis { AxisMarks(position: .bottom) { _ in AxisGridLine().foregroundStyle(palette.accent.opacity(0.12)); AxisValueLabel() } }
            .chartYAxis { AxisMarks { _ in AxisValueLabel() } }
            .chartYSelection(value: $selectedQuantityWeek)
            .frame(height: 270).accessibilityHidden(true)
            .animation(chartAnimation, value: quantity.id)
            if let selectedQuantityWeek, let week = quantity.weeks.first(where: { shortDate($0.date) == selectedQuantityWeek }) {
                Text("\(shortDate(week.date)): \(week.amount) \(quantity.unit.name(for: week.amount)) recorded")
                    .font(.subheadline.weight(.medium)).foregroundStyle(palette.accent)
                    .accessibilityIdentifier("insights.quantity.selection")
            } else {
                Text("Tap a week to inspect its recorded amount.").font(.caption).foregroundStyle(Color.appInkSecondary).accessibilityHidden(true)
            }
        }
    }

    private var sessionCard: some View {
        let kept = report.sessions.reduce(0) { $0 + $1.kept }
        let interrupted = report.sessions.reduce(0) { $0 + $1.interrupted }
        let unreported = report.sessions.reduce(0) { $0 + $1.unreported }
        return VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 7) {
                Label("Space you made", systemImage: "leaf").font(.title2.weight(.bold)).fontDesign(.rounded).accessibilityAddTraits(.isHeader)
                Text("Sessions started in these 12 completed weeks").font(.caption).foregroundStyle(.white.opacity(0.85))
            }
            Text("\(report.sessions.reduce(0) { $0 + $1.started }) sessions started")
                .font(.system(.title, design: .rounded, weight: .bold)).fixedSize(horizontal: false, vertical: true)
            if !usesReadableValues {
                Chart(report.sessions) { week in
                    BarMark(x: .value("Week", week.date, unit: .weekOfYear), y: .value("Kept", week.kept), width: .ratio(0.64))
                        .foregroundStyle(foam)
                    BarMark(x: .value("Week", week.date, unit: .weekOfYear), y: .value("Interrupted", week.interrupted), width: .ratio(0.64))
                        .foregroundStyle(lavender)
                    BarMark(x: .value("Week", week.date, unit: .weekOfYear), y: .value("Unreported", week.unreported), width: .ratio(0.64))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .chartXAxis { AxisMarks(values: .stride(by: .weekOfYear, count: 3)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day()).foregroundStyle(.white.opacity(0.85))
                } }
                .chartYAxis { AxisMarks { _ in AxisGridLine().foregroundStyle(.white.opacity(0.12)); AxisValueLabel().foregroundStyle(.white.opacity(0.85)) } }
                .frame(height: 152).accessibilityHidden(true)
                .animation(chartAnimation, value: report.interval)
            }
            VStack(alignment: .leading, spacing: 12) {
                sessionKey("\(kept) reported kept", color: foam, symbol: "checkmark.circle")
                sessionKey("\(interrupted) reported interrupted", color: lavender, symbol: "pause.circle")
                sessionKey("\(unreported) unfinished or unreported", color: .white.opacity(0.7), symbol: "circle.dashed")
                Divider().overlay(.white.opacity(0.2))
                Label("\(MadeRoomReviewViewModel.minutes(report.sessions.reduce(0) { $0 + $1.timerMinutes } * 60)) elapsed timer minutes", systemImage: "timer")
                    .font(.subheadline.weight(.medium))
            }
            Text("Timer minutes include ended sessions only. They are not verified focus, phone-free or saved time. Outcomes are self-reported; sessions never complete a habit.")
                .font(.caption).foregroundStyle(.white.opacity(0.87))
                .accessibilityIdentifier(usesReadableValues ? "insights.sessions.accessibleSummary" : "insights.sessions.chartSummary")
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(report.sessions) { week in
                        Text("\(shortDate(week.date)): \(week.started) started, \(week.kept) kept, \(week.interrupted) interrupted, \(week.unreported) unfinished or unreported")
                            .font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(.top, 10)
            } label: { Text("View session weeks").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading) }
            .font(.subheadline).disclosureGroupStyle(ReportValuesDisclosureStyle(identifier: "insights.sessions.values"))
        }
        .foregroundStyle(.white).padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.luminousColors.last ?? palette.heroEnd, in: RoundedRectangle(cornerRadius: 30))
    }

    private func sessionKey(_ title: String, color: Color, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(color).frame(width: 20).accessibilityHidden(true)
            Text(title).font(.subheadline)
        }
    }

    private var displayedMonth: Int {
        monthNumber ?? calendar.component(.month, from: report.interval.end.addingTimeInterval(-1))
    }
    private var monthDays: [InsightsReportCalculator.ActivityDay] {
        report.activityDays.filter { calendar.component(.month, from: $0.date) == displayedMonth }
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            annualAtlas
            VStack(alignment: .leading, spacing: 18) {
                Picker("Activity month", selection: Binding(get: { displayedMonth }, set: { monthNumber = $0 })) {
                    ForEach(1...12, id: \.self) { month in Text(calendar.monthSymbols[month - 1]).tag(month) }
                }.pickerStyle(.menu).accessibilityIdentifier("insights.activity.month")
                Text(calendar.monthSymbols[displayedMonth - 1]).font(.system(.title, design: .rounded, weight: .bold))
                if !usesReadableValues { monthMatrix }
                Text("A record of check-ins, amounts and smaller actions. Colour shows activity, not adherence. Skips and days with no record remain separate.")
                    .font(.caption).foregroundStyle(Color.appInkSecondary)
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(monthDays) { day in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(shortDate(day.date)).fontWeight(.semibold)
                                Text(dayDescription(day)).foregroundStyle(Color.appInkSecondary)
                            }
                            .font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityElement(children: .combine)
                        }
                    }.padding(.top, 10)
                } label: { Text(usesReadableValues ? "Activity dates and recorded values" : "View dates and recorded values").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading) }
                .font(.subheadline).accessibilityIdentifier("insights.activity.values")
            }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 28))
        }
        .onChange(of: report.activityYear) { _, _ in monthNumber = nil }
    }

    private var annualAtlas: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("A year of showing up", systemImage: "square.grid.3x3.fill")
                .font(.title2.weight(.bold)).fontDesign(.rounded).accessibilityAddTraits(.isHeader)
            Text("\(yearLabel) · through \(shortDate(report.interval.end.addingTimeInterval(-1)))")
                .font(.caption).foregroundStyle(.white.opacity(0.85))
            VStack(alignment: .leading, spacing: 3) {
                Text("\(report.recordedDays) recorded activity \(report.recordedDays == 1 ? "day" : "days")")
                    .font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(foam)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Every mark is something you recorded.").font(.subheadline).foregroundStyle(.white.opacity(0.85))
            }
            if !usesReadableValues { annualCells }
            let layout = usesReadableValues
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(spacing: 18))
            layout {
                Label("Recorded", systemImage: "square.fill").foregroundStyle(foam)
                Label("Skipped", systemImage: "minus.square").foregroundStyle(sunlight)
                Label("No record", systemImage: "square").foregroundStyle(.white.opacity(0.8))
            }.font(.caption)
            Text("Recorded activity, not an adherence score. Dates after this review are not included.")
                .font(.caption).foregroundStyle(.white.opacity(0.87))
        }
        .foregroundStyle(.white).padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.luminousGradient, in: RoundedRectangle(cornerRadius: 30))
    }

    private var annualCells: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                let firstOffset = (calendar.component(.weekday, from: report.activityYear.start) - calendar.firstWeekday + 7) % 7
                LazyHGrid(rows: Array(repeating: GridItem(.fixed(12), spacing: 4), count: 7), spacing: 4) {
                    ForEach(0..<firstOffset, id: \.self) { _ in Color.clear.frame(width: 12, height: 12) }
                    ForEach(report.activityDays) { day in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(day.hasActivity ? foam : .white.opacity(day.state == .afterReview || day.state == .beforeTracking ? 0.025 : (contrast == .increased ? 0.18 : 0.09)))
                            .overlay {
                                if day.state == .skipped { RoundedRectangle(cornerRadius: 3).stroke(sunlight, lineWidth: 1.2) }
                                else if day.state == .noRecord { RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(contrast == .increased ? 0.65 : 0.2), lineWidth: 0.6) }
                            }
                            .frame(width: 12, height: 12).id(day.key)
                    }
                }.padding(.vertical, 5)
            }
            .onAppear { scrollAtlas(proxy) }
            .onChange(of: report.interval) { _, _ in scrollAtlas(proxy) }
        }.accessibilityHidden(true)
    }

    private func scrollAtlas(_ proxy: ScrollViewProxy) {
        if let last = report.activityDays.last(where: { $0.state != .afterReview }) {
            proxy.scrollTo(last.key, anchor: .trailing)
        }
    }

    private var monthMatrix: some View {
        VStack(spacing: 10) {
            if let first = monthDays.first {
                let offset = (calendar.component(.weekday, from: first.date) - calendar.firstWeekday + 7) % 7
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 8) {
                    ForEach(0..<7, id: \.self) { offset in
                        let index = (calendar.firstWeekday - 1 + offset) % 7
                        Text(calendar.veryShortWeekdaySymbols[index]).font(.caption.weight(.semibold)).foregroundStyle(Color.appInkSecondary)
                    }
                    ForEach(0..<offset, id: \.self) { _ in Color.clear.frame(height: 36) }
                    ForEach(monthDays) { day in
                        ZStack {
                            RoundedRectangle(cornerRadius: 11).fill(cellColor(day))
                            if day.state == .skipped { RoundedRectangle(cornerRadius: 11).stroke(palette.accent, style: StrokeStyle(lineWidth: 1, dash: [3, 2])) }
                            Text("\(calendar.component(.day, from: day.date))")
                                .font(.subheadline.weight(day.hasActivity ? .bold : .regular))
                                .foregroundStyle(day.hasActivity ? Color.white : Color.appInkSecondary)
                        }.frame(height: 36)
                    }
                }
            }
        }
        .accessibilityHidden(true)
        .animation(chartAnimation, value: displayedMonth)
    }

    private func cellColor(_ day: InsightsReportCalculator.ActivityDay) -> Color {
        switch day.state {
        case .recorded: palette.prominentFill
        case .skipped: palette.accentSoft
        case .noRecord, .paused: palette.surfaceSecondary
        case .beforeTracking, .afterReview: palette.surface
        }
    }
    private func dayDescription(_ day: InsightsReportCalculator.ActivityDay) -> String {
        switch day.state {
        case .recorded: return "\(day.checkInCount) check-ins, \(day.quantityEntryCount) amount entries, \(day.smallerActionCount) smaller actions\(day.skipCount > 0 ? ", \(day.skipCount) excused skips" : "")"
        case .skipped: return "\(day.skipCount) excused skips · no recorded activity"
        case .noRecord: return "No activity recorded · not an adherence result"
        case .paused: return "All habits paused · no commitment"
        case .beforeTracking: return "Before habit tracking began"
        case .afterReview: return "After this review · not included"
        }
    }
    private func reportHeading(_ title: String, subtitle: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: symbol).font(.headline).accessibilityAddTraits(.isHeader)
            Text(subtitle).font(.caption).foregroundStyle(Color.appInkSecondary)
        }
    }
    private var yearLabel: String {
        let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("yyyy")
        return formatter.string(from: report.activityYear.start)
    }
    private func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: date)
    }
    private func rangeLabel(_ interval: DateInterval) -> String { "\(shortDate(interval.start))–\(shortDate(interval.end.addingTimeInterval(-1)))" }
}

/// Explicit white disclosure controls remain readable on the dark report panels.
/// IDs live on the action itself, avoiding identifiers cascading into child values.
private struct ReportValuesDisclosureStyle: DisclosureGroupStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let identifier: String
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    configuration.label
                    Spacer(minLength: 8)
                    Image(systemName: configuration.isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold)).accessibilityHidden(true)
                }
                .foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityIdentifier(identifier)
            .accessibilityValue(configuration.isExpanded ? "Expanded" : "Collapsed")
            if configuration.isExpanded { configuration.content.foregroundStyle(.white) }
        }
    }
}

/// The image is built locally only after a deliberate preview. Names are off
/// initially; private reasons, notes, Health samples and attention never enter it.
struct InsightsShareView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    let insights: WeeklyInsightsCalculator.WeeklyInsights
    let weekLabel: String
    @State private var includesDates = true
    @State private var includesNames = false
    @State private var renderedImage: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    shareCard
                    VStack(spacing: 12) {
                        Toggle("Include week dates", isOn: $includesDates).accessibilityIdentifier("insights.shareDates")
                        Toggle("Include habit names", isOn: $includesNames).accessibilityIdentifier("insights.shareNames")
                    }
                    .font(.subheadline)
                    Text("Only the information in this preview is included. Sharing is optional and opens Apple's share sheet.")
                        .font(.footnote).foregroundStyle(Color.appInkSecondary)
                    if let renderedImage {
                        ShareLink(item: Image(uiImage: renderedImage), preview: SharePreview("My Rilova weekly review", image: Image(uiImage: renderedImage))) {
                            Label("Share This Card", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 44)
                        }.buttonStyle(.borderedProminent).tint(palette.prominentFill)
                    }
                }.padding(24)
            }
            .appThemeCanvas()
            .navigationTitle("Preview Your Card").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .task { render() }
            .onChange(of: includesDates) { _, _ in render() }
            .onChange(of: includesNames) { _, _ in render() }
        }
    }

    private var shareCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Rilova").font(.title2.weight(.bold)).fontDesign(.rounded)
                Spacer()
                Image(systemName: "waveform.path").font(.title2)
            }
            Text("Finding my rhythm.").font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text("\(Int(((insights.overallConsistency ?? 0) * 100).rounded()))%")
                .font(.system(size: 68, weight: .bold, design: .rounded)).monospacedDigit()
            Text("Weekly consistency across \(insights.eligibleHabits.count) \(insights.eligibleHabits.count == 1 ? "habit" : "habits")").font(.subheadline)
            if includesDates { Text(weekLabel).font(.caption) }
            if includesNames { Text(insights.eligibleHabits.map(\.habitName).joined(separator: " · ")).font(.subheadline) }
            Divider().overlay(Color.white.opacity(0.4))
            Text("Habits that fit real life.").font(.caption.weight(.medium))
        }
        .foregroundStyle(.white).padding(26).frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.luminousGradient)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .accessibilityIdentifier("insights.sharePreview")
    }

    @MainActor private func render() {
        // A fixed export width is independent of the preview viewport; names
        // wrap naturally rather than clipping and there is no remote upload.
        let renderer = ImageRenderer(content: shareCard.frame(width: 360).environment(\.appPalette, palette))
        renderer.scale = 3
        renderedImage = renderer.uiImage
    }
}
