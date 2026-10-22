import SwiftUI

enum PrivacyPolicyLink {
    static var configuredURL: URL? {
        validatedURL(Bundle.main.object(forInfoDictionaryKey: "AvelaPrivacyPolicyURL") as? String)
    }

    static func validatedURL(_ value: String?) -> URL? {
        guard let value, let url = URL(string: value),
              url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else { return nil }
        return url
    }
}

/// Shared native privacy explanation for Settings and the purchase sheet.
/// Publishing the owner's public policy remains a distribution requirement.
struct PrivacyView: View {
    var policyURL: URL? = PrivacyPolicyLink.configuredURL

    var body: some View {
        List {
            Section("Local Tracking, Optional Protection") {
                Text("Tracking is saved on your device. Rilova doesn't require its own account. If you enable optional iCloud backup, eligible tracking and preferences are copied to your private Apple iCloud storage.")
                Text("Rilova doesn't track how you use the app or show advertisements. It doesn't automatically measure Screen Time. Ordinary logging and unprotected sessions never restrict apps. Microphone access is used only when you explicitly start reflection dictation.")
            }

            Section("Device backups") {
                Text("Rilova doesn't provide app-managed cloud sync. iOS may include local app data in a device backup according to your Apple backup settings. Manage those backups separately in iOS settings.")
                Text("Optional Rilova iCloud backup keeps dated recovery copies while the app is active. It isn't live sync or a guarantee against every loss. Health-connected habits, health/fitness habits, imported Health history, reflection notes, completion notes and private habit reasons are excluded. Local logging remains available offline.")
                Text("Turn backup off in Progress Protection to stop future upload requests; an upload already sent may finish. Existing cloud copies remain until you explicitly delete them there. Restore is available only before tracking begins on an installation; existing progress is never overwritten. Apple iCloud account availability and storage affect backup delivery.")
            }

            Section("Optional Siri and Shortcuts") {
                Text("Apple handles Siri voice processing. Rilova doesn't record audio. Habit and budget names may appear in Apple's suggestions and your saved shortcuts. Logging opens Rilova and may require device authentication; attention minutes remain self-reported.")
            }

            Section("Optional reflection dictation") {
                Text("When you tap Start Dictation, Rilova requests microphone and speech recognition permission. Recognition must be available on-device; there is no server fallback. Audio is used temporarily and isn't saved. You review or edit the transcript before adding it to a reflection, then explicitly save the note.")
                Text("Capture stops when you stop, leave the recording screen, put Rilova in the background, or reach 55 seconds. Typing stays available when access is denied or recognition is unavailable. Saved reflection text stays local and is excluded from Rilova's iCloud recovery copies; Apple device backups may include it.")
            }

            if AppleAppProtectionDriver.featureVisible {
                Section("Optional app protection") {
                    Text("On a supported iPhone build, you can allow Screen Time access for your own device and choose distractions to restrict during a session. Rilova doesn't read usage reports or send these choices anywhere. Selections and operational deadlines stay on-device and are excluded from recovery copies and backups of those files.")
                    Text("Stop Protection removes Rilova's restrictions without logging a habit or ending your timer. Other Screen Time limits may still apply. You can revoke Rilova's access in Settings → Screen Time; keep Rilova accessible if you want to stop inside the app.")
                }
            }

            Section("Optional Apple Health") {
                Text("If you connect a Build Up habit, Rilova reads today's chosen steps or exercise minutes when you open it or refresh. It saves connection settings and resulting habit successes locally, not raw Health samples. Nothing is written to Apple Health or automatically uploaded. Disconnect to stop future imports; existing history remains. Manage read permissions separately in Apple Health. Missing data isn't treated as failure.")
            }

            Section("Optional progress sharing") {
                Text("Your weekly card is created on this device. It shows weekly consistency and a habit count, with names and dates as you choose. These totals may reflect successes imported from Apple Health.")
                    .accessibilityIdentifier("privacy.progressSharingDisclosure")
                Text("Review the card, then choose a destination in Apple's share sheet. Nothing is published automatically. Private reasons, reflection notes, raw Health samples and detailed attention or session records aren't included.")
            }

            Section("Optional Calendar planning") {
                Text("Plan Time in Calendar prepares an event with your habit name and chosen times. You review it in Apple's editor and choose where to save it. That calendar may sync or share the event according to its settings. Rilova doesn't read your calendar or add your private habit reason or history.")
                    .accessibilityIdentifier("privacy.calendarDisclosure")
                Text("Saving an event doesn't start a session or log a habit. Cancelling leaves your Rilova progress unchanged.")
            }

            Section("Optional reminders") {
                Text("Notification permission is requested only when you enable a reminder. You can disable individual reminders in Rilova or change notification permission in iOS Settings. Tracking remains available when permission is denied.")
            }

            Section("Widgets") {
                Text("The app and its Quick Log and Routine widgets share a local snapshot for your Home Screen. Habit names and progress may be visible to anyone who can see your screen. Choose widget placement and names you're comfortable displaying. Lock Screen and Dynamic Island session activities are a separate feature, described below.")
            }

            Section("Optional session activities") {
                Text("When you choose Show Session Activity, iOS can display a focus or phone-free session timer and your companion on the Lock Screen and Dynamic Island, where supported. The activity contains no goal name or tracking history. Anyone who can see those screens may see it. Hide the activity without ending your session, or disable Live Activities in iOS Settings. A timer never verifies phone use or concentration.")
            }

            Section("Apple purchases") {
                Text("Apple handles payment and Apple Account information. Rilova uses verified purchase information from Apple to check Premium access; it doesn't receive your payment-card details. Manage or cancel subscriptions through your Apple Account.")
                Link("Manage Subscriptions", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
            }

            Section("Removing data") {
                Text("Archiving a habit keeps its history. To remove the local installation and app data, delete Rilova through iOS Settings. Existing device backups may still contain earlier data; manage or delete those separately. Deleting the app doesn't cancel an Apple subscription.")
                Text("Deleting Rilova also leaves any optional iCloud recovery copies intact. Delete those copies in Progress Protection before removing the app if you want to remove them too.")
                    .accessibilityIdentifier("privacy.cloudDeletionDisclosure")
            }

            Section("TestFlight feedback") {
                Text("During beta testing, Apple may share TestFlight usage, crash reports and feedback with the developer. Screenshots you submit may include your tracking details. This is separate from Rilova's local tracking.")
                Link("Apple's TestFlight Privacy Information", destination: URL(string: "https://www.apple.com/legal/privacy/data/en/test-flight/")!)
            }

            if let policyURL {
                Section {
                    Link("Read Privacy Policy", destination: policyURL)
                        .accessibilityIdentifier("privacy.publicPolicyLink")
                }
            }
        }
        .appThemeCanvas()
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("privacy.screen")
    }
}
