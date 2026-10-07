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
                Text("Tracking is saved on your device. Avela doesn't require its own account. If you enable optional iCloud backup, eligible tracking and preferences are copied to your private Apple iCloud storage.")
                Text("Avela doesn't track how you use the app or show advertisements. It doesn't automatically monitor Screen Time or block other apps. Microphone access is used only when you explicitly start reflection dictation.")
            }

            Section("Device backups") {
                Text("Avela doesn't provide app-managed cloud sync. iOS may include local app data in a device backup according to your Apple backup settings. Manage those backups separately in iOS settings.")
                Text("Optional Avela iCloud backup keeps dated recovery copies while the app is active. It isn't live sync or a guarantee against every loss. Health-connected habits, health/fitness habits, imported Health history, reflection notes, completion notes and private habit reasons are excluded. Local logging remains available offline.")
                Text("Turn backup off in Progress Protection to stop future upload requests; an upload already sent may finish. Existing cloud copies remain until you explicitly delete them there. Restore is available only before tracking begins on an installation; existing progress is never overwritten. Apple iCloud account availability and storage affect backup delivery.")
            }

            Section("Optional Siri and Shortcuts") {
                Text("Apple handles Siri voice processing. Avela doesn't record audio. Habit and budget names may appear in Apple's suggestions and your saved shortcuts. Logging opens Avela and may require device authentication; attention minutes remain self-reported.")
            }

            Section("Optional reflection dictation") {
                Text("When you tap Start Dictation, Avela requests microphone and speech recognition permission. Recognition must be available on-device; there is no server fallback. Audio is used temporarily and isn't saved. You review or edit the transcript before adding it to a reflection, then explicitly save the note.")
                Text("Capture stops when you stop, leave the recording screen, put Avela in the background, or reach 55 seconds. Typing stays available when access is denied or recognition is unavailable. Saved reflection text stays local and is excluded from Avela's iCloud recovery copies; Apple device backups may include it.")
            }

            Section("Optional Apple Health") {
                Text("If you connect a Build Up habit, Avela reads today's chosen steps or exercise minutes when you open it or refresh. It saves connection settings and resulting habit successes locally, not raw Health samples. Nothing is written to Apple Health or uploaded. Disconnect to stop future imports; existing history remains. Manage read permissions separately in Apple Health. Missing data isn't treated as failure.")
            }

            Section("Optional reminders") {
                Text("Notification permission is requested only when you enable a reminder. You can disable individual reminders in Avela or change notification permission in iOS Settings. Tracking remains available when permission is denied.")
            }

            Section("Widgets") {
                Text("The app and its widgets share a local snapshot so progress can appear on your Home Screen and Lock Screen. Depending on the widget, habit names and progress may be visible to anyone who can see your screen. Choose widget placement and names you're comfortable displaying.")
            }

            Section("Optional session activities") {
                Text("When you choose Show Session Activity, iOS can display a focus or phone-free session timer and your companion on the Lock Screen and Dynamic Island, where supported. The activity contains no goal name or tracking history. Anyone who can see those screens may see it. Hide the activity without ending your session, or disable Live Activities in iOS Settings. A timer never verifies phone use or concentration.")
            }

            Section("Apple purchases") {
                Text("Apple handles payment and Apple Account information. Avela uses verified purchase information from Apple to check Premium access; it doesn't receive your payment-card details. Manage or cancel subscriptions through your Apple Account.")
                Link("Manage Subscriptions", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
            }

            Section("Removing data") {
                Text("Archiving a habit keeps its history. To remove the local installation and app data, delete Avela through iOS Settings. Existing device backups may still contain earlier data; manage or delete those separately. Deleting the app doesn't cancel an Apple subscription.")
            }

            Section("TestFlight feedback") {
                Text("During beta testing, Apple may share TestFlight usage, crash reports and feedback with the developer. Screenshots you submit may include your tracking details. This is separate from Avela's local tracking.")
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
