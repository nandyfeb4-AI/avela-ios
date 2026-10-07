import Foundation

/// Synchronous MainActor read/check/write: no suspension between idempotency
/// checks and the canonical save. The extension never owns a database writer.
@MainActor
struct QuickLogService {
    let habits: HabitRepository
    let activities: HabitActivityRepository
    var calendar: Calendar = .autoupdatingCurrent

    enum Result: Equatable { case logged, alreadyLogged, needsApp }

    func log(habitID: UUID, dayKey: String, timeZone: String, revision: Int,
             asOf date: Date = Date()) throws -> Result {
        guard dayKey == LocalDay.key(for: date, calendar: calendar),
              timeZone == calendar.timeZone.identifier,
              let habit = try habits.fetchHabit(id: habitID),
              habit.archivedAt == nil, habit.createdAt <= date,
              let configuration = try habits.activeConfiguration(for: habitID, on: date),
              configuration.revision == revision,
              HabitScheduleEvaluator.isDue(configuration.schedule, on: date, calendar: calendar),
              try activities.configuration(for: habitID, on: date)?.target == nil else { return .needsApp }
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return .needsApp }
        let range = DateInterval(start: start, end: end)
        if !(try habits.completions(for: habitID, in: range)).isEmpty { return .alreadyLogged }
        // Replacing an excused skip requires an explicit decision in the app.
        guard try habits.skips(for: habitID, in: range).isEmpty else { return .needsApp }
        _ = try habits.recordCompletion(habitID: habitID, at: date, source: .widget, note: nil)
        return .logged
    }
}
