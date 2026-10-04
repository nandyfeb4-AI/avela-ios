import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class HabitReminderViewModel {
    let habitID: UUID
    var isEnabled = false
    var time: Date
    private(set) var permission: ReminderPermission = .notDetermined
    private(set) var isSaving = false
    private(set) var didSave = false
    var errorMessage: String?
    private let service: HabitReminderService
    private static let logger = Logger(subsystem: "com.example.Avela", category: "HabitReminders")

    init(habitID: UUID, service: HabitReminderService) {
        self.habitID = habitID
        self.service = service
        time = Calendar.current.date(from: DateComponents(year: 2001, month: 1, day: 1, hour: 9, minute: 0)) ?? Date()
    }

    func load() async {
        do {
            if let reminder = try service.reminder(for: habitID) {
                isEnabled = reminder.isEnabled
                time = Calendar.current.date(bySettingHour: reminder.hour, minute: reminder.minute, second: 0, of: Date()) ?? time
            }
            permission = await service.permission()
        } catch { handle(error) }
    }

    func save() async {
        guard !isSaving else { return }
        isSaving = true
        didSave = false
        defer { isSaving = false }
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        do {
            permission = try await service.setReminder(HabitReminder(
                habitID: habitID, isEnabled: isEnabled,
                hour: components.hour ?? 9, minute: components.minute ?? 0
            ))
            didSave = true
        } catch { handle(error) }
    }

    private func handle(_ error: Error) {
        Self.logger.error("Reminder operation failed: \(String(describing: error), privacy: .private)")
        if error as? ReminderError == .tooManyReminders {
            errorMessage = "Your iPhone's scheduled reminder limit has been reached. Disable another reminder and try again."
        } else {
            errorMessage = "Couldn't update this reminder. Please try again."
        }
    }
}
