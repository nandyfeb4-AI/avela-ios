import Foundation

/// A civil-date presentation of facts and the existing progress engine. Never
/// interprets weekly check-ins as daily streak commitments or rewrites records.
enum HabitCalendarCalculator {
    enum DayState: String, Equatable, Sendable {
        case success, logged, skipped, missed, pending, weekly, notScheduled, paused, notStarted, future

        var label: String {
            switch self {
            case .success: "Success"
            case .logged: "Success logged outside a daily commitment"
            case .skipped: "Skipped · excused"
            case .missed: "No success logged"
            case .pending: "Pending · no miss"
            case .weekly: "No check-in · evaluated weekly"
            case .notScheduled: "Not scheduled"
            case .paused: "Paused · no commitment"
            case .notStarted: "Before tracking began"
            case .future: "Upcoming"
            }
        }
    }

    struct Day: Identifiable, Equatable, Sendable {
        let date: Date
        let key: String
        let number: Int
        let state: DayState
        let isToday: Bool
        var id: String { key }
    }

    struct Month: Equatable, Sendable {
        let start: Date
        let days: [Day]
        let leadingBlankCount: Int
        let weeklyPeriods: [HabitProgressCalculator.ProgressPeriod]
        let streak: HabitProgressCalculator.StreakResult
        let hasMixedStreakUnits: Bool
    }

    static func civilCalendar(from calendar: Calendar) -> Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = calendar.timeZone
        result.locale = calendar.locale
        result.firstWeekday = calendar.firstWeekday
        result.minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        return result
    }

    static func month(
        containing monthDate: Date, habit: Habit, snapshots: [HabitConfigurationSnapshot],
        completions: [Completion], skips: [Skip], archivePeriods: [HabitArchivePeriod],
        asOf date: Date, calendar: Calendar
    ) -> Month {
        let civil = civilCalendar(from: calendar)
        let range = civil.dateInterval(of: .month, for: monthDate)!
        let periods = HabitProgressCalculator.periods(
            for: habit, snapshots: snapshots, completions: completions, skips: skips,
            archivePeriods: archivePeriods, asOf: date, calendar: calendar
        )
        let daily = Dictionary(periods.filter { $0.unit == .days }.map { ($0.localDateKey, $0.outcome) }, uniquingKeysWith: { _, latest in latest })
        let completionKeys = Set(completions.filter { $0.habitID == habit.id }.map(\.localDateKey))
        let skipKeys = Set(skips.filter { $0.habitID == habit.id }.map(\.localDateKey))
        let todayKey = LocalDay.key(for: date, calendar: civil)
        let creationKey = LocalDay.key(for: habit.createdAt, calendar: civil)
        let pauses = archivePeriods.filter { $0.habitID == habit.id }
        var days: [Day] = []
        var cursor = range.start
        while cursor < range.end {
            let key = LocalDay.key(for: cursor, calendar: civil)
            let state: DayState
            // A persisted fact stays on its original civil day after travel.
            if completionKeys.contains(key) {
                state = daily[key] == .success ? .success : .logged
            } else if skipKeys.contains(key) {
                state = .skipped
            } else if key > todayKey {
                state = .future
            } else if key < creationKey {
                state = .notStarted
            } else if let outcome = daily[key] {
                switch outcome {
                case .success: state = .success
                case .skip: state = .skipped
                case .miss: state = .missed
                case .pending: state = .pending
                }
            } else if pauses.contains(where: { pause in
                let start = LocalDay.key(for: pause.archivedAt, calendar: civil)
                let end = pause.reactivatedAt.map { LocalDay.key(for: $0, calendar: civil) }
                return key > start && (end == nil || key < end!)
            }) || habit.archivedAt.map({ key > LocalDay.key(for: $0, calendar: civil) }) == true {
                state = .paused
            } else if let snapshot = HabitScheduleEvaluator.activeConfiguration(from: snapshots, onKey: key) {
                if case .timesPerWeek = snapshot.schedule { state = .weekly }
                else { state = .notScheduled }
            } else {
                state = .notStarted
            }
            days.append(Day(date: cursor, key: key, number: civil.component(.day, from: cursor), state: state, isToday: key == todayKey))
            cursor = civil.date(byAdding: .day, value: 1, to: cursor)!
        }
        return Month(
            start: range.start, days: days,
            leadingBlankCount: (civil.component(.weekday, from: range.start) - civil.firstWeekday + 7) % 7,
            weeklyPeriods: periods.filter { $0.unit == .weeks && $0.periodStart < range.end && $0.periodEnd > range.start },
            streak: HabitProgressCalculator.streak(for: habit, snapshots: snapshots, completions: completions,
                skips: skips, archivePeriods: archivePeriods, asOf: date, calendar: calendar),
            hasMixedStreakUnits: periods.contains { $0.unit == .days } && periods.contains { $0.unit == .weeks }
        )
    }
}
