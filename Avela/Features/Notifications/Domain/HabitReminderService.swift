import Foundation

/// Coordinates persistence and platform delivery. Habit scheduling remains in
/// the domain; neither SwiftUI nor the habit repository schedules notifications.
@MainActor
final class HabitReminderService {
    private let habits: HabitRepository
    private let reminders: HabitReminderRepository
    private let adapter: HabitNotificationAdapter
    private var isSynchronizing = false
    private var needsSynchronization = false

    init(habits: HabitRepository, reminders: HabitReminderRepository, adapter: HabitNotificationAdapter) {
        self.habits = habits
        self.reminders = reminders
        self.adapter = adapter
    }

    func reminder(for habitID: UUID) throws -> HabitReminder? { try reminders.reminder(for: habitID) }
    func permission() async -> ReminderPermission { await adapter.permission() }

    /// This is the only path that can ask permission, called from explicit
    /// enablement. Denied authorization is never requested again here.
    @discardableResult
    func setReminder(_ reminder: HabitReminder) async throws -> ReminderPermission {
        guard reminder.isValid else { throw ReminderError.invalidTime }
        guard try habits.fetchHabit(id: reminder.habitID) != nil else { throw ReminderError.habitNotFound }
        var permission = await adapter.permission()
        if reminder.isEnabled && permission == .notDetermined {
            permission = try await adapter.requestPermission()
        }
        try reminders.save(reminder)
        if !reminder.isEnabled { adapter.cancelHabitReminder(habitID: reminder.habitID) }
        try await synchronize()
        return permission
    }

    /// Call after habit mutation, and on activation (permission changes in
    /// Settings, time-zone changes, and relaunch). This never prompts.
    func synchronize() async throws {
        needsSynchronization = true
        guard !isSynchronizing else { return }
        isSynchronizing = true
        defer { isSynchronizing = false }
        while needsSynchronization {
            needsSynchronization = false
            let permission = await adapter.permission()
            let habitsByID = Dictionary(uniqueKeysWithValues: try habits.fetchHabits(includeArchived: true).map { ($0.id, $0) })
            let requests = try reminders.allReminders().flatMap { reminder -> [HabitReminderRequest] in
                guard permission == .authorized, let habit = habitsByID[reminder.habitID] else { return [] }
                return HabitReminderPlanner.requests(for: habit, reminder: reminder)
            }
            try await adapter.replaceHabitReminders(with: requests)
        }
    }

    /// An archive action can remove requests synchronously before navigation;
    /// the saved preference survives so reactivation can schedule it again.
    func cancel(for habitID: UUID) {
        // A replacement suspended inside the platform adapter can still add an
        // old pre-archive request after this immediate removal. Make the active
        // reconciliation loop reload repository state before it finishes.
        needsSynchronization = true
        adapter.cancelHabitReminder(habitID: habitID)
    }
}
