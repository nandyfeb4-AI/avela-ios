import SwiftUI
import Charts

/// Longitudinal views are deliberately separate from the completed-week review.
/// Each chart includes a readable values alternative and its own period/units.
struct InsightsReportsView: View {
    enum Lens: String, CaseIterable, Identifiable {
        case week = "Week", rhythm = "Rhythm", activity = "Activity"
        var id: String { rawValue }
    }

    @Environment(\.appPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let report: InsightsReportCalculator.Report
    let calendar: Calendar
    let lens: Lens
    @State private var selectedQuantityID: String?
    @State private var monthNumber: Int?
    @State private var selectedWeek: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if lens == .rhythm {
                rhythmCard
                weekdayCard
                if !report.quantities.isEmpty { quantityCard }
                if report.hasSessions { sessionCard }
            } else if lens == .activity {
                activityCard
            }
        }
        .onChange(of: report.interval) { _, _ in selectedWeek = nil }
    }

    private var rhythmCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            reportHeading("Your rhythm", subtitle: "12 completed weeks · \(rangeLabel(report.interval))", symbol: "waveform.path")
            if let recent = report.weeks.last, let rate = recent.consistency {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
                layout {
                    Text(percent(rate)).font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(palette.accent)
                    Text("in the latest review").font(.subheadline).foregroundStyle(Color.appInkSecondary)
                }
            }
            if !dynamicTypeSize.isAccessibilitySize {
                Chart(report.weeks) { week in
                    if let rate = week.consistency {
                        BarMark(x: .value("Week", week.interval.start, unit: .weekOfYear), y: .value("Consistency", rate), width: .ratio(0.62))
                            .foregroundStyle(palette.accent.gradient).cornerRadius(5)
                    } else {
                        PointMark(x: .value("Week", week.interval.start, unit: .weekOfYear), y: .value("No data", 0))
                            .symbol(.cross).symbolSize(18).foregroundStyle(Color.appInkSecondary)
                    }
                    if let selectedWeek, calendar.isDate(selectedWeek, equalTo: week.interval.start, toGranularity: .weekOfYear) {
                        RuleMark(x: .value("Selected week", week.interval.start, unit: .weekOfYear))
                            .foregroundStyle(palette.accent.opacity(0.35)).lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                .chartYScale(domain: 0...1)
                .chartYAxis { AxisMarks(values: [0.0, 0.5, 1.0]) { value in
                    AxisGridLine().foregroundStyle(palette.accent.opacity(0.12))
                    AxisValueLabel { if let value = value.as(Double.self) { Text(percent(value)) } }
                } }
                .chartXAxis { AxisMarks(values: .stride(by: .weekOfYear, count: 3)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
                .chartXSelection(value: $selectedWeek)
                .frame(height: 188)
                .accessibilityHidden(true)
            }
            if let selectedWeek, let week = report.weeks.first(where: { calendar.isDate($0.interval.start, equalTo: selectedWeek, toGranularity: .weekOfYear) }) {
                Text("\(shortDate(week.interval.start)): \(week.consistency.map(percent) ?? "No resolved commitments") · \(week.eligibleHabitIDs.count) eligible habits")
                    .font(.subheadline.weight(.medium)).foregroundStyle(palette.accent)
            }
            Text(dynamicTypeSize.isAccessibilitySize
                 ? "Each week uses that week's eligible habits. These are weekly snapshots, not a like-for-like trend. No data means no resolved commitments."
                 : "Each bar uses that week's eligible habits. These are weekly snapshots, not a like-for-like trend. × means no resolved commitments.")
                .font(.caption).foregroundStyle(Color.appInkSecondary)
                .accessibilityIdentifier(dynamicTypeSize.isAccessibilitySize ? "insights.rhythm.accessibleSummary" : "insights.rhythm.chartSummary")
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(report.weeks) { week in
                        let layout = dynamicTypeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
                        layout {
                            Text(shortDate(week.interval.start))
                            if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                            Text(week.consistency.map(percent) ?? "No data").fontWeight(.semibold).monospacedDigit()
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityElement(children: .combine)
                    }
                }.font(.subheadline).padding(.top, 10)
            } label: { Text("View weekly values").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading) }
            .font(.subheadline).accessibilityIdentifier("insights.rhythm.values")
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .rilovaCard()

    }

    private var weekdayCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            reportHeading("A week in perspective", subtitle: "12 completed weeks · daily commitments", symbol: "calendar")
            Text("Which days have had room?").font(.title3.weight(.semibold)).fontDesign(.rounded)
            if !dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(report.weekdays) { day in
                        VStack(spacing: 7) {
                            Text(day.consistency.map(percent) ?? "—").font(.caption2.weight(.semibold)).monospacedDigit()
                            GeometryReader { geometry in
                                ZStack(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 6).fill(palette.accentSoft)
                                    if let value = day.consistency, value > 0 {
                                        RoundedRectangle(cornerRadius: 6).fill(palette.accent.gradient)
                                            .frame(height: geometry.size.height * value)
                                    }
                                }
                            }.frame(height: 94)
                            Text(calendar.veryShortWeekdaySymbols[day.number - 1]).font(.caption.weight(.semibold))
                        }
                    }
                }
                .accessibilityHidden(true)
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
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .rilovaCard()
    }

    private var quantity: InsightsReportCalculator.Quantity? {
        report.quantities.first { $0.id == selectedQuantityID } ?? report.quantities.first
    }

    private var quantityCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            reportHeading("What adds up", subtitle: "Recorded amounts · 12 completed weeks", symbol: "chart.bar.xaxis")
            Picker("Habit and captured unit", selection: Binding(get: { quantity?.id ?? "" }, set: { selectedQuantityID = $0 })) {
                ForEach(report.quantities) { item in Text("\(item.habitName) · \(item.unit.rawValue)").tag(item.id) }
            }.pickerStyle(.menu).accessibilityIdentifier("insights.quantityPicker")
            if let quantity {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(quantity.total.formatted()) \(quantity.unit.name(for: quantity.total))")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(palette.accent)
                    Text(quantity.habitName).font(.headline)
                }
                if !dynamicTypeSize.isAccessibilitySize {
                    Chart(quantity.weeks) { week in
                        BarMark(x: .value("Week", week.date, unit: .weekOfYear), y: .value(quantity.unit.rawValue, week.amount), width: .ratio(0.62))
                            .foregroundStyle(palette.accent.gradient).cornerRadius(5)
                    }
                    .chartXAxis { AxisMarks(values: .stride(by: .weekOfYear, count: 3)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
                    .frame(height: 160).accessibilityHidden(true)
                }
                Text(dynamicTypeSize.isAccessibilitySize
                     ? "Amounts stay in their captured unit. A week with no amount recorded does not establish what happened."
                     : "Amounts stay in their captured unit. An empty bar means no amount recorded; it does not establish what happened.")
                    .font(.caption).foregroundStyle(Color.appInkSecondary)
                    .accessibilityIdentifier(dynamicTypeSize.isAccessibilitySize ? "insights.quantity.accessibleSummary" : "insights.quantity.chartSummary")
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
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .rilovaCard()
    }

    private var sessionCard: some View {
        let kept = report.sessions.reduce(0) { $0 + $1.kept }
        let interrupted = report.sessions.reduce(0) { $0 + $1.interrupted }
        let unreported = report.sessions.reduce(0) { $0 + $1.unreported }
        return VStack(alignment: .leading, spacing: 18) {
            reportHeading("Space you made", subtitle: "Sessions started in these 12 completed weeks", symbol: "leaf")
            Text("\(report.sessions.reduce(0) { $0 + $1.started }) sessions started")
                .font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(palette.accent)
            if !dynamicTypeSize.isAccessibilitySize {
                Chart(report.sessions) { week in
                    BarMark(x: .value("Week", week.date, unit: .weekOfYear), y: .value("Sessions started", week.started), width: .ratio(0.62))
                        .foregroundStyle(palette.accent.gradient).cornerRadius(5)
                }
                .chartXAxis { AxisMarks(values: .stride(by: .weekOfYear, count: 3)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
                .frame(height: 144).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 8) {
                Label("\(kept) reported kept", systemImage: "checkmark.circle")
                Label("\(interrupted) reported interrupted", systemImage: "pause.circle")
                Label("\(unreported) unfinished or unreported", systemImage: "circle.dashed")
                Label("\(MadeRoomReviewViewModel.minutes(report.sessions.reduce(0) { $0 + $1.timerMinutes } * 60)) elapsed timer minutes", systemImage: "timer")
            }.font(.subheadline)
            Text("Timer minutes include ended sessions only. They are not verified focus, phone-free or saved time. Outcomes are self-reported; sessions never complete a habit.")
                .font(.caption).foregroundStyle(Color.appInkSecondary)
                .accessibilityIdentifier(dynamicTypeSize.isAccessibilitySize ? "insights.sessions.accessibleSummary" : "insights.sessions.chartSummary")
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(report.sessions) { week in
                        Text("\(shortDate(week.date)): \(week.started) started, \(week.kept) kept, \(week.interrupted) interrupted, \(week.unreported) unfinished or unreported")
                            .font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(.top, 10)
            } label: { Text("View session weeks").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading) }.font(.subheadline)
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .rilovaCard()
    }

    private var displayedMonth: Int {
        monthNumber ?? calendar.component(.month, from: report.interval.end.addingTimeInterval(-1))
    }

    private var monthDays: [InsightsReportCalculator.ActivityDay] {
        report.activityDays.filter { calendar.component(.month, from: $0.date) == displayedMonth }
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            reportHeading("A year of showing up", subtitle: "\(report.activityYear.start.formatted(.dateTime.year())) · through \(shortDate(report.interval.end.addingTimeInterval(-1)))", symbol: "square.grid.3x3.fill")
            Text("\(report.recordedDays) recorded activity \(report.recordedDays == 1 ? "day" : "days")")
                .font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(palette.accent)
            if !dynamicTypeSize.isAccessibilitySize {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        let firstOffset = (calendar.component(.weekday, from: report.activityYear.start) - calendar.firstWeekday + 7) % 7
                        LazyHGrid(rows: Array(repeating: GridItem(.fixed(10), spacing: 3), count: 7), spacing: 3) {
                            ForEach(0..<firstOffset, id: \.self) { _ in Color.clear.frame(width: 10, height: 10) }
                            ForEach(report.activityDays) { day in activityCell(day, size: 10).id(day.key) }
                        }.padding(.vertical, 4)
                    }
                    .onAppear {
                        if let lastReviewedDay = report.activityDays.last(where: { $0.state != .afterReview }) {
                            proxy.scrollTo(lastReviewedDay.key, anchor: .trailing)
                        }
                    }
                }
                .accessibilityHidden(true)
            }
            Text("A record of check-ins, amounts and smaller actions. Colour shows activity, not adherence. Skips and days with no record remain separate.")
                .font(.caption).foregroundStyle(Color.appInkSecondary)
            HStack(spacing: 16) {
                Label("Recorded", systemImage: "square.fill").foregroundStyle(palette.accent)
                Label("Skipped", systemImage: "minus.square")
            }.font(.caption)
            Picker("Activity month", selection: Binding(get: { displayedMonth }, set: { monthNumber = $0 })) {
                ForEach(1...12, id: \.self) { month in Text(calendar.monthSymbols[month - 1]).tag(month) }
            }.pickerStyle(.menu).accessibilityIdentifier("insights.activity.month")
            if !dynamicTypeSize.isAccessibilitySize, let first = monthDays.first {
                let offset = (calendar.component(.weekday, from: first.date) - calendar.firstWeekday + 7) % 7
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 8) {
                    ForEach(0..<7, id: \.self) { offset in
                        let index = (calendar.firstWeekday - 1 + offset) % 7
                        Text(calendar.veryShortWeekdaySymbols[index]).font(.caption.weight(.semibold)).foregroundStyle(Color.appInkSecondary)
                    }
                    ForEach(0..<offset, id: \.self) { _ in Color.clear.frame(height: 34) }
                    ForEach(monthDays) { day in
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(cellColor(day))
                            if day.state == .skipped { RoundedRectangle(cornerRadius: 10).stroke(palette.accent, style: StrokeStyle(lineWidth: 1, dash: [3, 2])) }
                            Text("\(calendar.component(.day, from: day.date))")
                                .font(.subheadline.weight(day.hasActivity ? .bold : .regular))
                                .foregroundStyle(day.hasActivity ? Color.white : Color.appInkSecondary)
                        }.frame(height: 34)
                    }
                }.accessibilityHidden(true)
            }
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
            } label: { Text(dynamicTypeSize.isAccessibilitySize ? "Activity dates and recorded values" : "View dates and recorded values").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading) }.font(.subheadline).accessibilityIdentifier("insights.activity.values")
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .rilovaCard()
        .onChange(of: report.activityYear) { _, _ in monthNumber = nil }
    }

    private func activityCell(_ day: InsightsReportCalculator.ActivityDay, size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2).fill(cellColor(day))
            .overlay { if day.state == .skipped { RoundedRectangle(cornerRadius: 2).stroke(palette.accent, lineWidth: 1) } }
            .frame(width: size, height: size)
    }

    private func cellColor(_ day: InsightsReportCalculator.ActivityDay) -> Color {
        switch day.state {
        case .recorded: palette.prominentFill
        case .skipped: palette.accentSoft
        case .noRecord: palette.surfaceSecondary
        case .paused: palette.surfaceSecondary
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
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol).font(.headline).accessibilityAddTraits(.isHeader)
            Text(subtitle).font(.caption).foregroundStyle(Color.appInkSecondary)
        }
    }

    private func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: date)
    }
    private func rangeLabel(_ interval: DateInterval) -> String { "\(shortDate(interval.start))–\(shortDate(interval.end.addingTimeInterval(-1)))" }
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
