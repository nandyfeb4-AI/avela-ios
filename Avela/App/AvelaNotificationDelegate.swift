import SwiftUI
import UIKit
import UserNotifications

/// Retained by SwiftUI's app delegate adaptor. Notification callbacks queue
/// explicit review on the main actor.
/// The shell confirms identity before writing through its existing repository.
@MainActor
final class AvelaNotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, ObservableObject {
    @Published var pendingAction: HabitReminderAction?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([UserNotificationAdapter.habitCategory])
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let request = response.notification.request
        let action = HabitReminderAction.parse(action: response.actionIdentifier,
            category: request.content.categoryIdentifier, identifier: request.identifier,
            habitID: request.content.userInfo["habitID"] as? String,
            deliveredAt: response.notification.date)
        // UIKit's foreground response completion performs scene/snapshot work.
        // Complete on the main actor too, not the async delegate bridge's
        // cooperative executor (which asserts inside UIKit on this toolchain).
        Task { @MainActor [weak self] in
            if let action { self?.pendingAction = action }
            completionHandler()
        }
    }

}
