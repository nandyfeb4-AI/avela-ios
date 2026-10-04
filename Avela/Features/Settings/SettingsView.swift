import SwiftUI

/// Settings tab root. Minimal by design for this slice: a single navigation
/// entry point to Archived Habits. No other settings are implemented yet.
struct SettingsView: View {
    let repository: HabitRepository
    var profiles: CompanionProfileRepository? = nil
    var subscriptionManager: SubscriptionManager? = nil
    var onPreferencesChanged: () -> Void = {}
    @State private var isShowingPremium = false

    var body: some View {
        List {
            if let subscriptionManager {
                Section("Avela") {
                    Button(subscriptionManager.hasPremium ? "Avela Premium" : "Explore Avela Premium") {
                        isShowingPremium = true
                    }
                    .accessibilityIdentifier("settings.premiumButton")
                }
            }
            if let profiles {
                Section("Preferences") {
                    NavigationLink("Companion & Feedback") {
                        CompanionSettingsView(repository: profiles)
                            .onDisappear(perform: onPreferencesChanged)
                    }
                    .accessibilityIdentifier("settings.companionLink")
                }
            }
            Section {
                NavigationLink("Privacy") { PrivacyView() }
                    .accessibilityIdentifier("settings.privacyLink")
            }
            Section {
                NavigationLink("Archived Habits") {
                    ArchivedHabitsView(viewModel: ArchivedHabitsViewModel(repository: repository), subscriptionManager: subscriptionManager)
                }
                .accessibilityIdentifier("settings.archivedHabitsLink")
            } footer: {
                Text("Archived habits keep their history and can be reactivated anytime.")
            }
        }
        .sheet(isPresented: $isShowingPremium) {
            if let subscriptionManager { PremiumPaywallView(manager: subscriptionManager) }
        }
    }
}

#Preview {
    let container = try! AppPersistence.makeContainer(inMemory: true)
    NavigationStack {
        SettingsView(repository: SwiftDataHabitRepository(modelContext: container.mainContext))
    }
}
