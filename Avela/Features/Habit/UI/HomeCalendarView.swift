import SwiftUI
import Observation
import OSLog

/// Read-only civil-day projection. Home never redirects today's logging action
/// to a selected past date, and an activity count is never an adherence score.
@MainActor @Observable final class HomeCalendarModel {
    struct Row: Identifiable {
        let habit: Habit
        let state: HabitCalendarCalculator.DayState
        var hasRecordedActivity = false
        var id: UUID { habit.id }
    }
    struct Day: Identifiable {
        let date: Date
        let key: String
        let number: Int
        let weekday: String
        let isToday: Bool
        let isFuture: Bool
        let rows: [Row]
        var id: String { key }
        var loggedCount: Int { rows.filter { $0.state == .success || $0.state == .logged || $0.hasRecordedActivity }.count }
    }
    private(set) var week: [Day] = []
    private(set) var month: [Day] = []
    private(set) var monthTitle = ""
    private(set) var leadingBlanks = 0
    private(set) var weekdayLabels: [String] = []
    private(set) var canGoBack = false
    private(set) var canGoForward = false
    private(set) var errorMessage: String?
    private var selectedMonth: Date?
    let repository: any HabitRepository
    let activities: (any HabitActivityRepository)?
    let calendar: Calendar

    init(repository: any HabitRepository, activities: (any HabitActivityRepository)? = nil,
         calendar: Calendar = .autoupdatingCurrent) {
        self.repository = repository
        self.activities = activities
        self.calendar = calendar
    }

    func load(asOf now: Date = Date()) {
        do {
            let civil = HabitCalendarCalculator.civilCalendar(from: calendar)
            let habits = try repository.fetchHabits(includeArchived: true)
            let all = DateInterval(start: .distantPast, end: .distantFuture)
            let completions = Dictionary(grouping: try repository.completions(in: all), by: \.habitID)
            let skips = Dictionary(grouping: try repository.skips(in: all), by: \.habitID)
            var snapshots: [UUID: [HabitConfigurationSnapshot]] = [:]
            var pauses: [UUID: [HabitArchivePeriod]] = [:]
            var periods: [UUID: [HabitProgressCalculator.ProgressPeriod]] = [:]
            var recordedActivityKeys: [UUID: Set<String>] = [:]
            for habit in habits {
                snapshots[habit.id] = try repository.configurationHistory(for: habit.id)
                pauses[habit.id] = try repository.archivePeriods(for: habit.id)
                periods[habit.id] = HabitProgressCalculator.periods(
                    for: habit, snapshots: snapshots[habit.id] ?? [],
                    completions: completions[habit.id] ?? [], skips: skips[habit.id] ?? [],
                    archivePeriods: pauses[habit.id] ?? [], asOf: now, calendar: calendar)
                let entries = try activities?.entries(for: habit.id, in: all) ?? []
                recordedActivityKeys[habit.id] = Set(entries.filter {
                    $0.habitID == habit.id && $0.loggedAt <= now
                        && ($0.kind == .smallerAction || ($0.kind == .quantity && $0.amount > 0 && $0.unit != nil))
                }.map(\.dayKey))
            }
            let current = civil.dateInterval(of: .month, for: now)!.start
            // Recorded civil keys remain authoritative after travel. Their
            // months can precede creation's current-zone month or follow the
            // current local month without becoming fabricated future misses.
            func monthForKey(_ key: String) -> Date? {
                let parts = key.split(separator: "-").compactMap { Int($0) }
                guard parts.count == 3 else { return nil }
                return civil.date(from: DateComponents(year: parts[0], month: parts[1], day: 1))
            }
            let factMonths = (completions.values.flatMap { $0.map(\.localDateKey) }
                + skips.values.flatMap { $0.map(\.localDateKey) }
                + recordedActivityKeys.values.flatMap { Array($0) }).compactMap(monthForKey)
            let snapshotMonths = snapshots.values.flatMap { $0.map(\.effectiveLocalDateKey) }.compactMap(monthForKey)
            let creationMonths = habits.map { civil.dateInterval(of: .month, for: $0.createdAt)!.start }
            let earliest = ([current] + creationMonths + factMonths + snapshotMonths).min()!
            let latest = ([current] + factMonths).max()!
            let requestedMonth = civil.dateInterval(of: .month, for: selectedMonth ?? current)!.start
            let selected = min(max(requestedMonth, earliest), latest)
            selectedMonth = selected
            var cache: [Date: [Day]] = [:]
            func days(containing date: Date) -> [Day] {
                let start = civil.dateInterval(of: .month, for: date)!.start
                if let cached = cache[start] { return cached }
                let range = civil.dateInterval(of: .month, for: start)!
                var rowsByDay: [String: [Row]] = [:]
                for habit in habits {
                    let days = HabitCalendarCalculator.monthDays(containing: start, habit: habit,
                        snapshots: snapshots[habit.id] ?? [], completions: completions[habit.id] ?? [],
                        skips: skips[habit.id] ?? [], archivePeriods: pauses[habit.id] ?? [],
                        periods: periods[habit.id] ?? [], asOf: now, calendar: calendar)
                    for day in days {
                        let hasActivity = recordedActivityKeys[habit.id]?.contains(day.key) == true
                        guard day.state != .notStarted || hasActivity else { continue }
                        rowsByDay[day.key, default: []].append(Row(habit: habit, state: day.state,
                                                                hasRecordedActivity: hasActivity))
                    }
                }
                var result: [Day] = []
                var cursor = start
                while cursor < range.end {
                    let key = LocalDay.key(for: cursor, calendar: civil)
                    let weekday = civil.veryShortStandaloneWeekdaySymbols[civil.component(.weekday, from: cursor) - 1]
                    result.append(Day(date: cursor, key: key, number: civil.component(.day, from: cursor),
                        weekday: weekday, isToday: civil.isDate(cursor, inSameDayAs: now),
                        isFuture: cursor > civil.startOfDay(for: now), rows: rowsByDay[key] ?? []))
                    cursor = civil.date(byAdding: .day, value: 1, to: cursor)!
                }
                cache[start] = result
                return result
            }
            month = days(containing: selected)
            let weekInterval = LocalDay.weekInterval(containing: now, calendar: civil)
            week = (0..<7).compactMap { offset in
                let date = civil.date(byAdding: .day, value: offset, to: weekInterval.start)!
                let key = LocalDay.key(for: date, calendar: civil)
                return days(containing: date).first { $0.key == key }
            }
            leadingBlanks = (civil.component(.weekday, from: selected) - civil.firstWeekday + 7) % 7
            weekdayLabels = (0..<7).map { civil.veryShortStandaloneWeekdaySymbols[(civil.firstWeekday - 1 + $0) % 7] }
            let formatter = DateFormatter()
            formatter.calendar = civil; formatter.timeZone = civil.timeZone
            formatter.locale = civil.locale ?? .current
            formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
            monthTitle = formatter.string(from: selected)
            canGoBack = selected > earliest
            canGoForward = selected < latest
            errorMessage = nil
        } catch {
            week = []; month = []
            errorMessage = "Your calendar couldn't be loaded. Your progress is unchanged."
            Logger(subsystem: "com.example.Avela", category: "HomeCalendar").error("Calendar projection failed: \(String(describing: error), privacy: .private)")
        }
    }

    func moveMonth(by offset: Int, asOf now: Date = Date()) {
        guard (offset < 0 && canGoBack) || (offset > 0 && canGoForward), let selectedMonth else { return }
        self.selectedMonth = HabitCalendarCalculator.civilCalendar(from: calendar)
            .date(byAdding: .month, value: offset, to: selectedMonth)
        load(asOf: now)
    }
    func showCurrentMonth(asOf now: Date = Date()) { selectedMonth = nil; load(asOf: now) }
    func showMonth(containing date: Date, asOf now: Date = Date()) { selectedMonth = date; load(asOf: now) }
}

struct HomeCalendarStrip: View {
    @State private var model: HomeCalendarModel
    @State private var showingMonth = false
    @State private var selectedDay: HomeCalendarModel.Day?
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.appPalette) private var palette
    @Environment(\.colorSchemeContrast) private var contrast
    init(repository: any HabitRepository, activities: (any HabitActivityRepository)? = nil) {
        _model = State(initialValue: HomeCalendarModel(repository: repository, activities: activities))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(Date(), format: .dateTime.month(.wide).year()).font(.subheadline.weight(.semibold))
                Spacer()
                Button { model.showCurrentMonth(); showingMonth = true } label: {
                    Label("Calendar", systemImage: "calendar")
                        .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                }.accessibilityIdentifier("today.openCalendar")
            }
            if let error = model.errorMessage {
                Text(error).font(.footnote)
                Button("Try Again") { model.load() }
            } else {
                ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(model.week) { day in
                            Button { selectedDay = day } label: {
                                VStack(spacing: 7) {
                                    Text(day.weekday).font(.caption2.weight(.medium))
                                    Text("\(day.number)").font(.system(.title3, design: .rounded, weight: .semibold))
                                    if day.loggedCount > 0 {
                                        Text("\(day.loggedCount)").font(.caption2.weight(.bold)).monospacedDigit()
                                            .frame(minWidth: 18, minHeight: 18)
                                            .background(day.isToday ? Color.white.opacity(0.12) : palette.accentSoft, in: Circle())
                                            .accessibilityHidden(true)
                                    } else {
                                        Circle().strokeBorder(day.isToday ? palette.prominentInk : Color.appInkSecondary,
                                            lineWidth: 1).frame(width: 5, height: 5)
                                            .frame(height: 18).accessibilityHidden(true)
                                    }
                                }
                                .foregroundStyle(day.isToday ? palette.prominentInk : Color.appInk)
                                .padding(.horizontal, typeSize.isAccessibilitySize ? 8 : 0)
                                .frame(minWidth: typeSize.isAccessibilitySize ? 64 : 44,
                                       minHeight: typeSize.isAccessibilitySize ? 110 : 84)
                                .background(day.isToday ? palette.prominentFill : day.loggedCount > 0 ? palette.accentSoft : palette.surface, in: Capsule())
                                .overlay(Capsule().strokeBorder(day.isToday ? palette.prominentFill : palette.accent.opacity(contrast == .increased ? 0.6 : 0.12), lineWidth: 1))
                            }
                            .buttonStyle(RilovaPressStyle())
                            .accessibilityLabel(day.date.formatted(date: .complete, time: .omitted))
                            .accessibilityValue(day.isFuture && day.loggedCount == 0 ? "Upcoming" : "\(day.loggedCount) habits logged\(day.isToday ? ", today" : "")")
                            .accessibilityIdentifier("today.calendarDay.\(day.key)")
                            .id(day.key)
                        }
                    }.padding(.vertical, 2)
                }
                .onChange(of: model.week.first(where: \.isToday)?.key, initial: true) { _, key in
                    if let key { proxy.scrollTo(key, anchor: .center) }
                }
                .onChange(of: typeSize) { _, _ in
                    if let key = model.week.first(where: \.isToday)?.key { proxy.scrollTo(key, anchor: .center) }
                }
                }
            }
        }
        .task { model.load() }
        .onReceive(NotificationCenter.default.publisher(for: .avelaPersistenceDidChange)) { _ in model.load() }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in model.load() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in model.load() }
        .sheet(isPresented: $showingMonth) { HomeMonthView(model: model) }
        .sheet(item: $selectedDay, onDismiss: { model.load() }) { day in HomeDayReviewView(day: day, repository: model.repository, activities: model.activities) }
    }
}

private struct HomeMonthView: View {
    @Bindable var model: HomeCalendarModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var selectedDay: HomeCalendarModel.Day?
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    monthIdentity
                    monthNavigation
                    Text("Counts show distinct habits with recorded activity. Tap a date to review. A blank day isn't a verdict.")
                        .font(.footnote).foregroundStyle(Color.appInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if typeSize.isAccessibilitySize {
                        ForEach(model.month) { day in dayButton(day) }
                    } else {
                        ViewThatFits(in: .horizontal) {
                            monthGrid.frame(minWidth: 320)
                            VStack(spacing: 8) {
                                ForEach(model.month) { day in dayButton(day, fullDate: true) }
                            }
                        }
                    }
                    Label("Check-ins, partial amounts and smaller steps all count as recorded activity.", systemImage: "circle.grid.3x3.fill")
                        .font(.caption).foregroundStyle(Color.appInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }.padding(20)
            }.appThemeCanvas().navigationTitle("Calendar").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("homeCalendar.done") } }
                .sheet(item: $selectedDay, onDismiss: { model.load() }) { HomeDayReviewView(day: $0, repository: model.repository, activities: model.activities) }
        }
    }

    private var monthIdentity: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Text("YOUR DAYS, IN VIEW").font(.caption2.weight(.bold)).tracking(1.7)
                    .foregroundStyle(palette.accent)
                Text("A little, over time.").font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.appInk).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading)
            if !typeSize.isAccessibilitySize && contrast != .increased && !reduceTransparency {
                RilovaWorldArtwork(scene: .coast)
                    .frame(width: 90, height: 62).clipped()
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 26, bottomLeadingRadius: 9,
                        bottomTrailingRadius: 26, topTrailingRadius: 9))
                    .accessibilityHidden(true).allowsHitTesting(false)
            }
        }
    }

    private var monthNavigation: some View {
        HStack(spacing: 10) {
            Button { moveMonth(by: -1) } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
                    .background(palette.surface, in: Circle()).contentShape(Rectangle())
            }.buttonStyle(RilovaPressStyle()).disabled(!model.canGoBack)
                .accessibilityLabel("Previous month").accessibilityIdentifier("homeCalendar.previousMonth")
            Text(model.monthTitle).font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(Color.appInk).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity)
                .accessibilityIdentifier("homeCalendar.month")
            Button { moveMonth(by: 1) } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
                    .background(palette.surface, in: Circle()).contentShape(Rectangle())
            }.buttonStyle(RilovaPressStyle()).disabled(!model.canGoForward)
                .accessibilityLabel("Next month").accessibilityIdentifier("homeCalendar.nextMonth")
        }
    }

    private func moveMonth(by amount: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { model.moveMonth(by: amount) }
    }

    private var monthGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 44), spacing: 2), count: 7), spacing: 7) {
            ForEach(Array(model.weekdayLabels.enumerated()), id: \.offset) { _, name in
                Text(name).font(.caption2.weight(.semibold)).foregroundStyle(Color.appInkSecondary)
                    .padding(.bottom, 6).accessibilityHidden(true)
            }
            ForEach(0..<model.leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 58) }
            ForEach(model.month) { day in dayButton(day) }
        }
        .padding(.horizontal, 4).padding(.vertical, 16)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(palette.accent.opacity(contrast == .increased ? 0.5 : 0.1), lineWidth: 1).allowsHitTesting(false))
    }
    private func dayButton(_ day: HomeCalendarModel.Day, fullDate: Bool = false) -> some View {
        let showsFullDate = typeSize.isAccessibilitySize || fullDate
        let intensity = min(Double(day.loggedCount), 5) / 5
        return Button { selectedDay = day } label: {
            VStack(alignment: showsFullDate ? .leading : .center, spacing: 5) {
                Text(showsFullDate ? day.date.formatted(date: .complete, time: .omitted) : "\(day.number)")
                    .font(showsFullDate ? .body.weight(.semibold) : .system(.title3, design: .rounded, weight: day.isToday ? .bold : .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if showsFullDate {
                    Text(day.isFuture && day.loggedCount == 0 ? "Upcoming" : "\(day.loggedCount) habits with recorded activity\(day.isToday ? " · Today" : "")")
                        .font(.subheadline).foregroundStyle(Color.appInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if day.loggedCount > 0 {
                    HStack(spacing: 3) {
                        Circle().fill(palette.accent).frame(width: 4, height: 4)
                        Text("\(day.loggedCount)").font(.caption2.weight(.bold)).monospacedDigit()
                    }.foregroundStyle(palette.accent)
                } else {
                    Text(day.isFuture ? "—" : "·").font(.caption.weight(.semibold)).foregroundStyle(Color.appInkSecondary)
                }
            }
            .foregroundStyle(Color.appInk)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: showsFullDate ? .leading : .center)
            .padding(.horizontal, showsFullDate ? 16 : 0).padding(.vertical, showsFullDate ? 12 : 0)
            .background {
                if showsFullDate { palette.surface }
                else if day.loggedCount > 0 && (contrast == .increased || reduceTransparency) { palette.surfaceSecondary }
                else if day.loggedCount > 0 {
                    LinearGradient(colors: [palette.accent.opacity(0.08 + intensity * 0.12), palette.accent.opacity(0.04 + intensity * 0.07)],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: showsFullDate ? 20 : 18, style: .continuous))
            .overlay {
                if day.isToday {
                    RoundedRectangle(cornerRadius: showsFullDate ? 20 : 18)
                        .strokeBorder(palette.accent, lineWidth: 2)
                }
            }
            .contentShape(Rectangle())
        }.buttonStyle(RilovaPressStyle())
            .accessibilityLabel(day.date.formatted(date: .complete, time: .omitted))
            .accessibilityValue(day.isFuture && day.loggedCount == 0 ? "Upcoming" : "\(day.loggedCount) habits logged")
            .accessibilityIdentifier("homeCalendar.day.\(day.key)")
    }
}

private struct HomeDayReviewView: View {
    let day: HomeCalendarModel.Day
    let repository: any HabitRepository
    @State private var reviewModel: HomeCalendarModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.habitActivityRepository) private var activity
    @State private var correcting: HomeCalendarSelection?
    @Environment(\.appPalette) private var palette
    init(day: HomeCalendarModel.Day, repository: any HabitRepository, activities: (any HabitActivityRepository)? = nil) {
        self.day = day; self.repository = repository
        _reviewModel = State(initialValue: HomeCalendarModel(repository: repository, activities: activities))
    }
    private var reviewedDay: HomeCalendarModel.Day { reviewModel.month.first { $0.key == day.key } ?? day }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(day.date.formatted(.dateTime.weekday(.wide)).uppercased())
                            .font(.caption2.weight(.bold)).tracking(1.8).foregroundStyle(palette.accent)
                        Text(day.date.formatted(.dateTime.month(.wide).day()))
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(day.isFuture && reviewedDay.loggedCount == 0 ? "Upcoming. No activity is assumed." : "\(reviewedDay.loggedCount) distinct habits logged. Reviewing never changes your progress.")
                            .font(.subheadline).foregroundStyle(Color.appInkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }.padding(.vertical, 8)
                        .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
                if reviewedDay.rows.isEmpty { ContentUnavailableView("No Habits Tracked", systemImage: "calendar", description: Text("No habit records apply to this day.")) }
                ForEach(reviewedDay.rows) { row in
                    Section {
                        HStack(spacing: 12) {
                            HabitIconBadge(symbol: row.habit.iconName, isArchived: row.habit.isArchived).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(row.habit.name).font(.headline)
                                Text(row.state.label).font(.subheadline).foregroundStyle(Color.appInkSecondary)
                                if row.hasRecordedActivity && row.state != .success && row.state != .logged {
                                    Text("Activity recorded · target not marked complete").font(.caption).foregroundStyle(Color.appInkSecondary)
                                }
                                if row.habit.isArchived { Text("Archived").font(.caption) }
                            }
                        }
                        if !day.isFuture, row.state != .notStarted, row.state != .paused, row.state != .notScheduled, !row.habit.isArchived, activity != nil {
                            Button("Review or Correct This Day") { correcting = HomeCalendarSelection(id: row.id) }
                                .accessibilityLabel("Review or correct \(row.habit.name) on \(day.date.formatted(date: .complete, time: .omitted))")
                        }
                    }
                }
            }.appThemeCanvas().navigationTitle("Day Review").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("homeCalendar.dayReviewDone") } }
                .task { reviewModel.showMonth(containing: day.date) }
                .sheet(item: $correcting, onDismiss: { reviewModel.showMonth(containing: day.date) }) { selected in
                    if let activity { HabitActivityView(habitID: selected.id, repository: activity, habits: repository, initialDate: day.date) }
                }
        }
    }
}

private struct HomeCalendarSelection: Identifiable { let id: UUID }
