import Foundation

/// An explicit response to an owned notification, not an inferred check-in.
struct HabitReminderAction: Equatable, Sendable {
    let habitID: UUID
    let deliveredAt: Date

    static func parse(action: String, category: String, identifier: String,
                      habitID: String?, deliveredAt: Date) -> Self? {
        guard action == "avela.habit-reminder.log",
              category == "avela.habit-reminder.actions",
              let habitID, let id = UUID(uuidString: habitID) else { return nil }
        let prefix = HabitReminderPlanner.identifierPrefix + id.uuidString + "."
        guard identifier == prefix + "daily" || (1...7).contains(where: { identifier == prefix + String($0) }) else { return nil }
        return Self(habitID: id, deliveredAt: deliveredAt)
    }
}

enum ReminderActionResult: Equatable {
    case logged, alreadyLogged, expired, unavailable

    var message: String {
        switch self {
        case .logged: return "Success logged for today. You can undo it in Today."
        case .alreadyLogged: return "This habit is already logged for today. Nothing was changed."
        case .expired: return "This reminder is from another day. Nothing was logged. Open Today to check in."
        case .unavailable: return "This habit is no longer active or isn't scheduled today. Nothing was logged."
        }
    }
}

@MainActor
struct ReminderActionHandler {
    let habits: HabitRepository
    var calendar: Calendar = .current

    func validate(_ action: HabitReminderAction, at date: Date) throws -> ReminderActionResult? {
        guard action.deliveredAt <= date,
              LocalDay.key(for: action.deliveredAt, calendar: calendar) == LocalDay.key(for: date, calendar: calendar) else { return .expired }
        guard let habit = try habits.fetchHabit(id: action.habitID), habit.archivedAt == nil,
              habit.createdAt <= action.deliveredAt,
              let configuration = try habits.activeConfiguration(for: habit.id, on: date),
              HabitScheduleEvaluator.isDue(configuration.schedule, on: date, calendar: calendar),
              let interval = calendar.dateInterval(of: .day, for: date) else { return .unavailable }
        guard try habits.completions(for: habit.id, in: interval).isEmpty else { return .alreadyLogged }
        return nil
    }

    func handle(_ action: HabitReminderAction, at date: Date) throws -> ReminderActionResult {
        if let result = try validate(action, at: date) { return result }
        guard let interval = calendar.dateInterval(of: .day, for: date) else { return .unavailable }
        // An explicit success supersedes an excused skip, as in Today/Shortcuts.
        try habits.validateCompletion(habitID: action.habitID, at: date)
        for skip in try habits.skips(for: action.habitID, in: interval) { try habits.undoSkip(id: skip.id) }
        try habits.recordCompletion(habitID: action.habitID, at: date, source: .notification, note: nil)
        return .logged
    }
}
