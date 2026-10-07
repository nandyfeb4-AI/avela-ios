import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class HabitCalendarViewModel {
    private(set) var month: HabitCalendarCalculator.Month?
    private(set) var habitName = "Calendar History"
    private(set) var monthTitle = ""
    private(set) var weekdayLabels: [String] = []
    private(set) var canGoBack = false
    private(set) var canGoForward = false
    private(set) var isCurrentMonth = true
    var errorMessage: String?
    private var selectedMonth: Date?
    private let habitID: UUID
    private let repository: HabitRepository
    private let calendar: Calendar

    init(habitID: UUID, repository: HabitRepository, calendar: Calendar = .autoupdatingCurrent) {
        self.habitID = habitID
        self.repository = repository
        self.calendar = calendar
    }

    func load(asOf date: Date = Date()) {
        do {
            guard let habit = try repository.fetchHabit(id: habitID) else { throw HabitRepositoryError.habitNotFound(habitID) }
            let civil = HabitCalendarCalculator.civilCalendar(from: calendar)
            let current = civil.dateInterval(of: .month, for: date)!.start
            let start = civil.dateInterval(of: .month, for: habit.createdAt)!.start
            // Fetch all facts, then group by stored keys. A month-sized instant
            // query could drop boundary records after a time-zone change.
            let allTime = DateInterval(start: .distantPast, end: .distantFuture)
            let snapshots = try repository.configurationHistory(for: habitID)
            let completions = try repository.completions(for: habitID, in: allTime)
            let skips = try repository.skips(for: habitID, in: allTime)
            // Travel can move an instant across a month boundary. Include the
            // months of stored facts even when they're ahead of today's local
            // month; this permits viewing facts, not inventing future misses.
            func monthForKey(_ key: String) -> Date? {
                let parts = key.split(separator: "-").compactMap { Int($0) }
                guard parts.count == 3 else { return nil }
                return civil.date(from: DateComponents(year: parts[0], month: parts[1], day: 1))
            }
            let factMonths = (completions.map(\.localDateKey) + skips.map(\.localDateKey)).compactMap(monthForKey)
            let snapshotMonths = snapshots.map(\.effectiveLocalDateKey).compactMap(monthForKey)
            let earliest = ([start, current] + factMonths + snapshotMonths).min()!
            let latest = ([current] + factMonths).max()!
            let selected = min(max(selectedMonth ?? current, earliest), latest)
            selectedMonth = selected
            month = HabitCalendarCalculator.month(containing: selected, habit: habit,
                snapshots: snapshots, completions: completions, skips: skips,
                archivePeriods: try repository.archivePeriods(for: habitID), asOf: date, calendar: calendar)
            habitName = habit.name
            let formatter = DateFormatter()
            formatter.calendar = civil
            formatter.timeZone = civil.timeZone
            formatter.locale = civil.locale ?? .current
            formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
            monthTitle = formatter.string(from: selected)
            let symbols = formatter.shortWeekdaySymbols!
            weekdayLabels = (0..<7).map { symbols[(civil.firstWeekday - 1 + $0) % 7] }
            canGoBack = selected > earliest
            canGoForward = selected < latest
            isCurrentMonth = selected == current
            errorMessage = nil
        } catch {
            month = nil
            Logger(subsystem: "com.example.Avela", category: "HabitCalendar").error("Calendar load failed: \(String(describing: error), privacy: .private)")
            errorMessage = "Couldn't load this calendar. Please try again."
        }
    }

    func moveMonth(by offset: Int, asOf date: Date = Date()) {
        guard (offset < 0 && canGoBack) || (offset > 0 && canGoForward), let selectedMonth else { return }
        self.selectedMonth = HabitCalendarCalculator.civilCalendar(from: calendar).date(byAdding: .month, value: offset, to: selectedMonth)
        load(asOf: date)
    }

    func showCurrentMonth(asOf date: Date = Date()) { selectedMonth = nil; load(asOf: date) }

    func dateLabel(_ day: HabitCalendarCalculator.Day) -> String {
        let formatter = DateFormatter()
        formatter.calendar = HabitCalendarCalculator.civilCalendar(from: calendar)
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? .current
        formatter.dateStyle = .full
        return formatter.string(from: day.date)
    }

    func periodLabel(_ period: HabitProgressCalculator.ProgressPeriod) -> String {
        let civil = HabitCalendarCalculator.civilCalendar(from: calendar)
        let formatter = DateFormatter()
        formatter.calendar = civil
        formatter.timeZone = civil.timeZone
        formatter.locale = civil.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        let last = civil.date(byAdding: .day, value: -1, to: period.periodEnd)!
        return "\(formatter.string(from: period.periodStart)) – \(formatter.string(from: last))"
    }
}
