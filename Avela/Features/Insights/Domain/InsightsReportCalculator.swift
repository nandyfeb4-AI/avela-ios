import Foundation

/// Read-only report projections. Commitment outcomes come from the existing
/// progress engine once per habit; no heat-map cell or amount is a new success.
enum InsightsReportCalculator {
    struct Week: Identifiable, Equatable {
        let interval: DateInterval
        let consistency: Double?
        let eligibleHabitIDs: Set<UUID>
        let cohortChanged: Bool
        var id: Date { interval.start }
    }

    struct ActivityDay: Identifiable, Equatable {
        enum State: Equatable { case recorded, skipped, noRecord, paused, beforeTracking, afterReview }
        let date: Date
        let key: String
        let checkInCount: Int
        let quantityEntryCount: Int
        let smallerActionCount: Int
        let skipCount: Int
        let state: State
        var id: String { key }
        var hasActivity: Bool { state == .recorded }
    }

    struct Weekday: Identifiable, Equatable {
        let number: Int
        let successes: Int
        let resolved: Int
        var id: Int { number }
        var consistency: Double? { resolved > 0 ? Double(successes) / Double(resolved) : nil }
    }

    struct QuantityWeek: Identifiable, Equatable {
        let date: Date
        let amount: Int
        var id: Date { date }
    }

    struct Quantity: Identifiable, Equatable {
        let habitID: UUID
        let habitName: String
        let unit: HabitQuantityUnit
        let weeks: [QuantityWeek]
        var id: String { habitID.uuidString + unit.rawValue }
        var total: Int { weeks.reduce(0) { $0 + $1.amount } }
    }

    struct SessionWeek: Identifiable, Equatable {
        let date: Date
        let started: Int
        let kept: Int
        let interrupted: Int
        let unreported: Int
        let timerMinutes: Double
        var id: Date { date }
    }

    struct Report: Equatable {
        let interval: DateInterval
        let activityYear: DateInterval
        let weeks: [Week]
        let activityDays: [ActivityDay]
        let weekdays: [Weekday]
        let quantities: [Quantity]
        let sessions: [SessionWeek]
        var recordedDays: Int { activityDays.filter(\.hasActivity).count }
        var hasSessions: Bool { sessions.contains { $0.started > 0 } }
    }

    /// Twelve completed local weeks ending with the review. The activity map
    /// covers that review's calendar year and labels dates after review as such.
    static func intervals(endingAt reviewEnd: Date, calendar: Calendar) -> (report: DateInterval, year: DateInterval) {
        let civil = HabitCalendarCalculator.civilCalendar(from: calendar)
        let start = calendar.date(byAdding: .weekOfYear, value: -12, to: reviewEnd) ?? reviewEnd
        let year = civil.dateInterval(of: .year, for: reviewEnd.addingTimeInterval(-1))!
        return (DateInterval(start: start, end: reviewEnd), year)
    }

    static func calculate(
        habits: [Habit], snapshots: [UUID: [HabitConfigurationSnapshot]],
        archives: [UUID: [HabitArchivePeriod]], completions: [Completion], skips: [Skip],
        entries: [HabitActivityEntry], sessions: [AttentionSession],
        reviewEnd: Date, asOf: Date, calendar: Calendar
    ) -> Report {
        let intervals = intervals(endingAt: reviewEnd, calendar: calendar)
        let civil = HabitCalendarCalculator.civilCalendar(from: calendar)
        let reportFirstKey = LocalDay.key(for: intervals.report.start, calendar: civil)
        let reportEndKey = LocalDay.key(for: reviewEnd, calendar: civil)
        let allIDs = Set(habits.map(\.id))
        // Source records can arrive in duplicate projections. Count each stable
        // fact once; retained civil keys keep backdated amounts on their day.
        let completionFacts = unique(completions, id: \.id).filter { allIDs.contains($0.habitID) && $0.occurredAt <= asOf }
        let skipFacts = unique(skips, id: \.id).filter { allIDs.contains($0.habitID) && $0.createdAt <= asOf }
        let activityFacts = unique(entries, id: \.id).filter { allIDs.contains($0.habitID) && $0.loggedAt <= asOf }
        let completionGroups = Dictionary(grouping: completionFacts, by: \.habitID)
        let skipGroups = Dictionary(grouping: skipFacts, by: \.habitID)
        var periods: [UUID: [HabitProgressCalculator.ProgressPeriod]] = [:]
        // Evaluate once per habit, not once per day/chart/bar. Existing schedule,
        // pause, skip, partial-week and pending rules remain authoritative.
        for habit in habits {
            periods[habit.id] = HabitProgressCalculator.periods(
                for: habit, snapshots: snapshots[habit.id] ?? [],
                completions: completionGroups[habit.id] ?? [], skips: skipGroups[habit.id] ?? [],
                archivePeriods: archives[habit.id] ?? [], asOf: min(asOf, reviewEnd), calendar: calendar
            ).filter { $0.periodStart >= intervals.report.start && $0.periodStart < reviewEnd }
        }
        var weekIntervals: [DateInterval] = []
        var cursor = intervals.report.start
        while cursor < reviewEnd {
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor), next > cursor else { break }
            weekIntervals.append(DateInterval(start: cursor, end: min(next, reviewEnd)))
            cursor = next
        }
        var previousSignature: [UUID: HabitSchedule] = [:]
        var weeks: [Week] = []
        for week in weekIntervals {
            var percentages: [Double] = []
            var signature: [UUID: HabitSchedule] = [:]
            for habit in habits {
                let own = (periods[habit.id] ?? []).filter { $0.periodStart >= week.start && $0.periodStart < week.end }
                let successful = own.filter { $0.outcome == .success }.count
                let resolved = successful + own.filter { $0.outcome == .miss }.count
                guard resolved > 0 else { continue }
                percentages.append(Double(successful) / Double(resolved))
                if let schedule = HabitScheduleEvaluator.activeConfiguration(from: snapshots[habit.id] ?? [], on: week.start, calendar: calendar)?.schedule {
                    signature[habit.id] = schedule
                }
            }
            let cohort = Set(habits.filter { habit in
                (periods[habit.id] ?? []).contains { $0.periodStart >= week.start && $0.periodStart < week.end && ($0.outcome == .success || $0.outcome == .miss) }
            }.map(\.id))
            let editedWithinWeek = habits.contains { habit in
                let own = snapshots[habit.id] ?? []
                let startKey = LocalDay.key(for: week.start, calendar: calendar)
                let endKey = LocalDay.key(for: week.end, calendar: calendar)
                return own.contains { snapshot in
                    snapshot.effectiveLocalDateKey > startKey && snapshot.effectiveLocalDateKey < endKey
                        && snapshot.schedule != signature[habit.id]
                }
            }
            let changed = !weeks.isEmpty && (previousSignature != signature || weeks.last?.eligibleHabitIDs != cohort || editedWithinWeek)
            weeks.append(Week(interval: week, consistency: percentages.isEmpty ? nil : percentages.reduce(0, +) / Double(percentages.count), eligibleHabitIDs: cohort, cohortChanged: changed))
            previousSignature = signature
        }
        let weekdays = (0..<7).map { offset -> Weekday in
            let number = (calendar.firstWeekday - 1 + offset) % 7 + 1
            let matching = periods.values.flatMap { $0 }.filter {
                $0.unit == .days && calendar.component(.weekday, from: $0.periodStart) == number
            }
            let successes = matching.filter { $0.outcome == .success }.count
            return Weekday(number: number, successes: successes, resolved: successes + matching.filter { $0.outcome == .miss }.count)
        }
        let quantities = habits.flatMap { habit in
            HabitQuantityUnit.allCases.compactMap { unit -> Quantity? in
                let own = activityFacts.filter { $0.habitID == habit.id && $0.kind == .quantity && $0.unit == unit && $0.amount > 0 && $0.dayKey >= reportFirstKey && $0.dayKey < reportEndKey }
                guard !own.isEmpty else { return nil }
                return Quantity(habitID: habit.id, habitName: habit.name, unit: unit, weeks: weekIntervals.map { week in
                    let firstKey = LocalDay.key(for: week.start, calendar: civil)
                    let endKey = LocalDay.key(for: week.end, calendar: civil)
                    return QuantityWeek(date: week.start, amount: own.filter { $0.dayKey >= firstKey && $0.dayKey < endKey }.reduce(0) { $0 + $1.amount })
                })
            }
        }
        let sessionFacts = unique(sessions, id: \.id).filter { $0.startedAt <= asOf }
        let sessionWeeks = weekIntervals.map { week in
            let own = sessionFacts.filter { $0.startedAt >= week.start && $0.startedAt < week.end }
            // An outcome saved after the review is still a corrected fact, as
            // with backdated check-ins. Active sessions contribute no minutes.
            let ended = own.filter { $0.endedAt.map { $0 <= asOf } == true }
            let kept = ended.filter { $0.outcome == .kept }.count
            let interrupted = ended.filter { $0.outcome == .interrupted }.count
            let minutes = ended.reduce(0.0) { total, session in
                let elapsed = session.endedAt!.timeIntervalSince(session.startedAt)
                guard elapsed.isFinite, elapsed >= 0, elapsed <= 7 * 86400 else { return total }
                return total + elapsed / 60
            }
            return SessionWeek(date: week.start, started: own.count, kept: kept, interrupted: interrupted, unreported: own.count - kept - interrupted, timerMinutes: minutes)
        }
        let completionsByDay = Dictionary(grouping: completionFacts, by: \.localDateKey)
        let activityByDay = Dictionary(grouping: activityFacts, by: \.dayKey)
        let skipsByDay = Dictionary(grouping: skipFacts, by: \.localDateKey)
        let earliest = habits.map { LocalDay.key(for: $0.createdAt, calendar: civil) }.min()
        var days: [ActivityDay] = []
        cursor = intervals.year.start
        while cursor < intervals.year.end {
            let key = LocalDay.key(for: cursor, calendar: civil)
            let checkIns = Set((completionsByDay[key] ?? []).map(\.habitID)).count
            let activities = activityByDay[key] ?? []
            let quantity = activities.filter { $0.kind == .quantity && $0.amount > 0 && $0.unit != nil }.count
            let smaller = Set(activities.filter { $0.kind == .smallerAction }.map(\.habitID)).count
            let excused = Set((skipsByDay[key] ?? []).map(\.habitID)).count
            let state: ActivityDay.State
            if key >= reportEndKey { state = .afterReview }
            else if checkIns + quantity + smaller > 0 { state = .recorded }
            else if excused > 0 { state = .skipped }
            else if earliest == nil || key < earliest! { state = .beforeTracking }
            else {
                let hasActive = habits.contains { habit in
                    guard key >= LocalDay.key(for: habit.createdAt, calendar: civil) else { return false }
                    let dormant = (archives[habit.id] ?? []).contains { pause in
                        let start = LocalDay.key(for: pause.archivedAt, calendar: civil)
                        let end = pause.reactivatedAt.map { LocalDay.key(for: $0, calendar: civil) }
                        return key > start && (end == nil || key < end!)
                    }
                    let archived = habit.archivedAt.map { key > LocalDay.key(for: $0, calendar: civil) } ?? false
                    return !dormant && !archived
                }
                state = hasActive ? .noRecord : .paused
            }
            days.append(ActivityDay(date: cursor, key: key, checkInCount: checkIns, quantityEntryCount: quantity, smallerActionCount: smaller, skipCount: excused, state: state))
            guard let next = civil.date(byAdding: .day, value: 1, to: cursor), next > cursor else { break }
            cursor = next
        }
        return Report(interval: intervals.report, activityYear: intervals.year, weeks: weeks, activityDays: days, weekdays: weekdays, quantities: quantities, sessions: sessionWeeks)
    }

    private static func unique<Value, ID: Hashable>(_ values: [Value], id: KeyPath<Value, ID>) -> [Value] {
        var seen = Set<ID>()
        return values.filter { seen.insert($0[keyPath: id]).inserted }
    }
}
