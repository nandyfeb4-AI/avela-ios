import SwiftUI

/// Preferences and discoverable entry points to optional native features.
struct SettingsView: View {
    @Environment(\.appProtectionModel) private var protection
    @Environment(\.appProtectionDriver) private var protectionDriver
    @State private var showingProtection = false
    @Environment(\.appPalette) private var palette
    let repository: HabitRepository
    var reflectionRepository: ReflectionRepository? = nil
    var cloudBackup: CloudBackupModel? = nil
    @Binding var watchEnabled: Bool
    var profiles: CompanionProfileRepository? = nil
    var appearance: AppearanceRepository? = nil
    var subscriptionManager: SubscriptionManager? = nil
    var onPreferencesChanged: () -> Void = {}
    @State private var isShowingPremium = false
    @State private var isShowingHabitOrder = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image("BrandIcon").resizable().scaledToFit()
                        .frame(width: 58, height: 58)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Rilova").font(.system(.title, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Habits that fit real life.").font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(24).frame(maxWidth: .infinity, alignment: .leading)
                .background { RilovaAurora() }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("settings.brand")
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            Section {
                Toggle(isOn: $watchEnabled) { settingsLabel("Apple Watch quick logging", systemImage: "applewatch") }
                    .accessibilityIdentifier("settings.watchEnabled")
                Button { isShowingHabitOrder = true } label: {
                    settingsLabel("Habit Order", systemImage: "arrow.up.arrow.down")
                }
                .accessibilityIdentifier("settings.habitOrderButton")
                NavigationLink { WidgetGuideView() } label: {
                    settingsLabel("Home Screen Widgets", systemImage: "square.grid.2x2")
                }
                .accessibilityIdentifier("settings.widgetsLink")
                NavigationLink {
                    ShortcutsGuideView()
                } label: {
                    settingsLabel("Siri & Shortcuts", systemImage: "mic")
                }
                .accessibilityIdentifier("settings.shortcutsLink")
            } header: { Text("Quick Logging") } footer: {
                Text("Watch shares today's habit names and status. Logging needs a reachable, unlocked iPhone; quantities open on iPhone. Offline actions aren't queued.")
            }
            if let protection {
                Section("Optional App Protection") {
                    Button { showingProtection = true } label: {
                        settingsLabel("App Protection", systemImage: "hand.raised")
                    }
                        .accessibilityIdentifier("settings.appProtection")
                }
                AppProtectionStatusView(model: protection)
            }
            if let subscriptionManager {
                Section("Rilova") {
                    Button {
                        isShowingPremium = true
                    } label: {
                        settingsLabel(subscriptionManager.hasPremium ? "Rilova Premium" : "Explore Rilova Premium", systemImage: "sparkles")
                    }
                    .accessibilityIdentifier("settings.premiumButton")
                }
            }
            if appearance != nil || profiles != nil {
                Section("Personalize") {
                    if let appearance {
                        NavigationLink {
                            AppThemeView(repository: appearance, onThemeChanged: onPreferencesChanged)
                        } label: { settingsLabel("App Theme", systemImage: "paintpalette") }
                        .accessibilityIdentifier("settings.appThemeLink")
                    }
                    if let profiles {
                        NavigationLink {
                            CompanionSettingsView(repository: profiles)
                                .onDisappear(perform: onPreferencesChanged)
                        } label: { settingsLabel("Companion & Feedback", systemImage: "leaf") }
                        .accessibilityIdentifier("settings.companionLink")
                    }
                }
            }
            Section {
                if let reflectionRepository {
                    NavigationLink {
                        ReflectionView(repository: reflectionRepository, habits: repository)
                    } label: { settingsLabel("Weekly Reflection", systemImage: "square.and.pencil") }
                    .accessibilityIdentifier("settings.reflection")
                }
                NavigationLink {
                    ArchivedHabitsView(viewModel: ArchivedHabitsViewModel(repository: repository), subscriptionManager: subscriptionManager)
                } label: { settingsLabel("Archived Habits", systemImage: "archivebox") }
                .accessibilityIdentifier("settings.archivedHabitsLink")
            } header: { Text("Your Habits") } footer: {
                Text("Archived habits keep their history and can be reactivated anytime.")
            }
            Section("Privacy & Data") {
                NavigationLink { PrivacyView() } label: {
                    settingsLabel("Privacy", systemImage: "hand.raised")
                }
                .accessibilityIdentifier("settings.privacyLink")
                if let cloudBackup, cloudBackup.shouldShowSettings {
                    NavigationLink {
                        CloudBackupView(model: cloudBackup, onRestore: onPreferencesChanged)
                    } label: { settingsLabel("Progress Protection", systemImage: "icloud.and.arrow.up") }
                    .accessibilityIdentifier("settings.backupLink")
                }
            }
        }
        .sheet(isPresented: $showingProtection) {
            if let protection { AppProtectionSetupView(model: protection, driver: protectionDriver) }
        }
        .appThemeCanvas()
        .sheet(isPresented: $isShowingPremium) {
            if let subscriptionManager { PremiumPaywallView(manager: subscriptionManager) }
        }
        .sheet(isPresented: $isShowingHabitOrder) {
            NavigationStack {
                HabitOrderView(repository: repository, onSaved: onPreferencesChanged)
            }
        }
    }
    private func settingsLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(palette.accent)
                .frame(width: 34, height: 34)
                .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            Text(title).lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }

}

#Preview {
    let container = try! AppPersistence.makeContainer(inMemory: true)
    NavigationStack {
        SettingsView(repository: SwiftDataHabitRepository(modelContext: container.mainContext), watchEnabled: .constant(false))
    }
}
