import Foundation
import UserNotifications

@MainActor
final class UserNotificationAdapter: HabitNotificationAdapter {
    static var habitCategory: UNNotificationCategory {
        let log = UNNotificationAction(identifier: "avela.habit-reminder.log",
            title: "Review & log", options: [.foreground, .authenticationRequired])
        return UNNotificationCategory(identifier: "avela.habit-reminder.actions",
            actions: [log], intentIdentifiers: [], options: [])
    }

    #if DEBUG
    private var didScheduleTestReminder = false
    #endif
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) { self.center = center }

    func permission() async -> ReminderPermission {
        Self.permission(from: await center.notificationSettings().authorizationStatus)
    }

    func requestPermission() async throws -> ReminderPermission {
        _ = try await center.requestAuthorization(options: [.alert, .sound])
        return await permission()
    }

    func replaceHabitReminders(with requests: [HabitReminderRequest]) async throws {
        #if DEBUG
        if didScheduleTestReminder && !requests.isEmpty,
           ProcessInfo.processInfo.environment["AVELA_UI_TEST_STORE_PATH"] != nil,
           ProcessInfo.processInfo.environment["AVELA_UI_TEST_REMINDER_DELIVERY"] == "1" { return }
        #endif
        #if DEBUG
        if !didScheduleTestReminder && !requests.isEmpty,
           ProcessInfo.processInfo.environment["AVELA_UI_TEST_STORE_PATH"] != nil,
           ProcessInfo.processInfo.environment["AVELA_UI_TEST_REMINDER_DELIVERY"] == "1" {
            let delivered = await center.deliveredNotifications()
            center.removeDeliveredNotifications(withIdentifiers: delivered.map { $0.request.identifier }
                .filter { $0.hasPrefix(HabitReminderPlanner.identifierPrefix) })
        }
        #endif
        let pending = await center.pendingNotificationRequests()
        let ownedIDs = pending.map(\.identifier).filter { $0.hasPrefix(HabitReminderPlanner.identifierPrefix) }
        guard pending.count - ownedIDs.count + requests.count <= 64 else {
            throw ReminderError.tooManyReminders
        }
        center.removePendingNotificationRequests(withIdentifiers: ownedIDs)
        do {
            for request in requests {
                let content = UNMutableNotificationContent()
                content.title = "Avela"
                content.body = "A moment for your habit. Open Avela when you're ready."
                content.sound = .default
                content.categoryIdentifier = Self.habitCategory.identifier
                content.userInfo = ["habitID": request.habitID.uuidString]
                var components = DateComponents()
                components.hour = request.hour
                components.minute = request.minute
                components.weekday = request.weekday
                // Intentionally omit timeZone and a fixed calendar: this is a
                // recurring local wall-clock time, including across DST/travel.
                var trigger: UNNotificationTrigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                #if DEBUG
                // Exercises real system delivery/actions in an isolated UI-test
                // store. Never bypasses notification permission or the delegate.
                let environment = ProcessInfo.processInfo.environment
                if environment["AVELA_UI_TEST_STORE_PATH"] != nil && environment["AVELA_UI_TEST_REMINDER_DELIVERY"] == "1" {
                    guard !didScheduleTestReminder else { continue }
                    didScheduleTestReminder = true
                    trigger = UNTimeIntervalNotificationTrigger(timeInterval: 8, repeats: false)
                }
                #endif
                try await center.add(UNNotificationRequest(identifier: request.identifier, content: content, trigger: trigger))
            }
        } catch {
            // Do not leave a misleading partially-scheduled set after an error.
            center.removePendingNotificationRequests(withIdentifiers: requests.map(\.identifier))
            throw error
        }
    }

    func cancelHabitReminder(habitID: UUID) {
        let prefix = HabitReminderPlanner.identifierPrefix + habitID.uuidString + "."
        center.removePendingNotificationRequests(withIdentifiers: [prefix + "daily"] + (1...7).map { prefix + String($0) })
        center.removeDeliveredNotifications(withIdentifiers: [prefix + "daily"] + (1...7).map { prefix + String($0) })
    }

    private static func permission(from status: UNAuthorizationStatus) -> ReminderPermission {
        switch status {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized, .provisional, .ephemeral: return .authorized
        @unknown default: return .denied
        }
    }
}
