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
            Section("Your tracking stays local") {
                Text("Habits, completions, skips, attention entries, sessions and preferences are saved on your device. Avela doesn't require an account and doesn't send your tracking records to a server.")
                Text("Avela doesn't track how you use the app or show advertisements. It doesn't automatically monitor Screen Time, block other apps or record your microphone.")
            }

            Section("Device backups") {
                Text("Avela doesn't provide app-managed cloud sync. iOS may include local app data in a device backup according to your Apple backup settings. Manage those backups separately in iOS settings.")
            }

            Section("Optional reminders") {
                Text("Notification permission is requested only when you enable a reminder. You can disable individual reminders in Avela or change notification permission in iOS Settings. Tracking remains available when permission is denied.")
            }

            Section("Widgets") {
                Text("The app and its widgets share a local snapshot so progress can appear on your Home Screen and Lock Screen. Depending on the widget, habit names and progress may be visible to anyone who can see your screen. Choose widget placement and names you're comfortable displaying.")
            }

            Section("Optional session activities") {
                Text("When you choose Show Session Activity, iOS can display a phone-free session timer and your companion on the Lock Screen and Dynamic Island, where supported. The activity contains no goal name or tracking history. Anyone who can see those screens may see it. Hide the activity without ending your session, or disable Live Activities in iOS Settings. A timer never verifies phone use.")
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
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("privacy.screen")
    }
}
