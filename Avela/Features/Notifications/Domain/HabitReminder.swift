import Foundation

struct HabitReminder: Equatable, Sendable {
    let habitID: UUID
    var isEnabled: Bool
    var hour: Int
    var minute: Int

    var isValid: Bool { (0...23).contains(hour) && (0...59).contains(minute) }
}

enum ReminderPermission: Equatable, Sendable {
    case notDetermined, denied, authorized
}

enum ReminderError: Error, Equatable {
    case invalidTime
    case tooManyReminders
    case habitNotFound
}

/// A local-wall-clock recurrence. No fixed time zone is stored, so travel
/// keeps a reminder at the selected local time rather than its original instant.
struct HabitReminderRequest: Equatable, Sendable {
    let identifier: String
    let habitID: UUID
    let hour: Int
    let minute: Int
    let weekday: Int?
}

enum HabitReminderPlanner {
    static let identifierPrefix = "avela.habit-reminder."

    static func requests(for habit: Habit, reminder: HabitReminder) -> [HabitReminderRequest] {
        guard reminder.habitID == habit.id, reminder.isEnabled,
              reminder.isValid, !habit.isArchived else { return [] }
        let weekdays: [Int?]
        switch habit.schedule {
        case .daily, .timesPerWeek:
            weekdays = [nil]
        case .weekdays(let days):
            weekdays = days.map(\.rawValue).sorted().map { Optional($0) }
        }
        return weekdays.map { weekday in
            HabitReminderRequest(
                identifier: identifierPrefix + habit.id.uuidString + "." + (weekday.map(String.init) ?? "daily"),
                habitID: habit.id, hour: reminder.hour, minute: reminder.minute, weekday: weekday
            )
        }
    }
}

@MainActor
protocol HabitReminderRepository {
    func allReminders() throws -> [HabitReminder]
    func reminder(for habitID: UUID) throws -> HabitReminder?
    func save(_ reminder: HabitReminder) throws
}

@MainActor
protocol HabitNotificationAdapter {
    func permission() async -> ReminderPermission
    func requestPermission() async throws -> ReminderPermission
    /// Replaces only this feature's requests; other feature notifications survive.
    func replaceHabitReminders(with requests: [HabitReminderRequest]) async throws
    func cancelHabitReminder(habitID: UUID)
}
