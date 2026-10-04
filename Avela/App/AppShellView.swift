import SwiftData
import SwiftUI
import OSLog

/// Composition root for tab navigation. Owns the one `HabitRepository` and the
/// Today/Insights/History view models for the app's lifetime, resolving the
/// repository from the environment's `ModelContext` — persistence composition
/// stays here in `App/`, not inside feature views. Local onboarding/preferences
/// and StoreKit ownership live here so feature screens share one authority.
struct AppShellView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .today
    @Environment(\.modelContext) private var modelContext
    @State private var repository: HabitRepository?
    @State private var todayViewModel: TodayViewModel?
    @State private var insightsViewModel: InsightsViewModel?
    @State private var historyViewModel: HistoryViewModel?
    @State private var reminderService: HabitReminderService?
    @State private var liveActivityService: SessionLiveActivityService?
    @State private var attentionRepository: AttentionRepository?
    @State private var attentionViewModel: AttentionSummaryViewModel?
    @State private var profiles: CompanionProfileRepository?
    @State private var companionProfile = CompanionProfile()
    @State private var onboardingViewModel: OnboardingViewModel?
    @State private var subscriptionManager = SubscriptionManager()
    @State private var pendingWidgetURL: URL?
    @State private var widgetActionError: String?
    @State private var didInitialize = false
    @State private var initializationError: String?

    var body: some View {
        Group {
            if !didInitialize {
                if let initializationError {
                    ContentUnavailableView {
                        Label("Couldn't Load Your Preferences", systemImage: "exclamationmark.triangle")
                    } description: { Text(initializationError) } actions: {
                        Button("Try Again") { initialize() }
                    }
                } else { ProgressView() }
            } else if !companionProfile.onboardingCompleted && !bypassesOnboarding, let onboardingViewModel {
                OnboardingView(viewModel: onboardingViewModel) {
                    reloadProfile()
                    refreshVisibleData()
                }
            } else {
                tabs
            }
        }
        .task {
            initialize()
            // Core local data and onboarding are rendered before any StoreKit
            // request; lack of connectivity never blocks app startup.
            await subscriptionManager.start()
        }
        .task(id: liveActivityService?.nextExpiration) {
            guard let deadline = liveActivityService?.nextExpiration else { return }
            do { try await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow))) }
            catch { return }
            guard !Task.isCancelled else { return }
            // Runs while the app is executing. iOS may suspend the app in the
            // background; staleDate provides the honest expired system UI.
            await liveActivityService?.synchronize()
        }
        .environment(\.habitReminderService, reminderService)
        .environment(\.sessionLiveActivityService, liveActivityService)
        .onOpenURL { url in
            if didInitialize { handleWidgetURL(url) } else { pendingWidgetURL = url }
        }
        .onReceive(NotificationCenter.default.publisher(for: .avelaPersistenceDidChange)) { _ in
            exportWidgetSnapshot()
            synchronizeLiveActivity()
        }
        .alert("Unable to Log This Habit", isPresented: Binding(
            get: { widgetActionError != nil }, set: { if !$0 { widgetActionError = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(widgetActionError ?? "") }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshVisibleData()
                Task { await subscriptionManager.refreshEntitlements() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in refreshVisibleData() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in refreshVisibleData() }
        .onChange(of: selectedTab) { _, newTab in
            reloadProfile()
            switch newTab {
            case .today:
                todayViewModel?.load()
                attentionViewModel?.load()
            case .insights: insightsViewModel?.load()
            case .history: historyViewModel?.load()
            default: break
            }
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack {
                    destinationView(for: tab)
                        .navigationTitle(tab.title)
                }
                .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                .tag(tab)
            }
        }
    }

    private func initialize() {
        guard !didInitialize else { return }
        do {
            let repository = SwiftDataHabitRepository(modelContext: modelContext)
            self.repository = repository
            todayViewModel = TodayViewModel(repository: repository)
            let subscriptionManager = self.subscriptionManager
            todayViewModel?.creationAllowed = { subscriptionManager.canCreateHabit(activeCount: $0) }
            let attentionRepository = SwiftDataAttentionRepository(modelContext: modelContext)
            self.attentionRepository = attentionRepository
            insightsViewModel = InsightsViewModel(repository: repository, attentionRepository: attentionRepository)
            historyViewModel = HistoryViewModel(repository: repository, attentionRepository: attentionRepository)
            let service = HabitReminderService(habits: repository,
                reminders: SwiftDataHabitReminderRepository(modelContext: modelContext), adapter: UserNotificationAdapter())
            reminderService = service
            attentionViewModel = AttentionSummaryViewModel(repository: attentionRepository)
            attentionViewModel?.creationAllowed = { subscriptionManager.canCreateAttentionGoal(activeCount: $0) }
            let profiles = SwiftDataCompanionProfileRepository(modelContext: modelContext)
            self.profiles = profiles
            companionProfile = try profiles.profile()
            if allowsLiveActivityAdapter {
                liveActivityService = SessionLiveActivityService(repository: attentionRepository,
                    profiles: profiles, adapter: ActivityKitSessionAdapter())
            }
            onboardingViewModel = OnboardingViewModel(habits: repository, attention: attentionRepository,
                profiles: profiles, reminderService: service,
                habitCreationAllowed: { subscriptionManager.canCreateHabit(activeCount: $0) },
                attentionCreationAllowed: { subscriptionManager.canCreateAttentionGoal(activeCount: $0) })
            initializationError = nil
            didInitialize = true
            exportWidgetSnapshot()
            synchronizeLiveActivity()
            if let url = pendingWidgetURL {
                pendingWidgetURL = nil
                handleWidgetURL(url)
            }
            Task { try? await service.synchronize() }
        } catch {
            Logger(subsystem: "com.example.Avela", category: "AppShell").error("Preferences load failed: \(String(describing: error), privacy: .private)")
            initializationError = "Your saved data hasn't been changed. Please try again."
        }
    }

    private var bypassesOnboarding: Bool {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        return environment["AVELA_UI_TEST_STORE_PATH"] != nil && environment["AVELA_UI_TEST_ONBOARDING"] != "1"
        #else
        return false
        #endif
    }

    private var allowsLiveActivityAdapter: Bool {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        return environment["AVELA_UI_TEST_STORE_PATH"] == nil || environment["AVELA_UI_TEST_LIVE_ACTIVITY"] == "1"
        #else
        return true
        #endif
    }

    private func synchronizeLiveActivity() {
        Task { await liveActivityService?.synchronize() }
    }

    private func reloadProfile() {
        guard let profiles else { return }
        do { companionProfile = try profiles.profile() }
        catch {
            Logger(subsystem: "com.example.Avela", category: "AppShell").error("Preferences refresh failed: \(String(describing: error), privacy: .private)")
        }
    }

    private func exportWidgetSnapshot() {
        guard let repository, let attentionRepository else { return }
        // UI tests never export isolated fixture records into the real widget group.
        #if DEBUG
        guard ProcessInfo.processInfo.environment["AVELA_UI_TEST_STORE_PATH"] == nil else { return }
        #endif
        do { try WidgetSnapshotExporter().export(habits: repository, attention: attentionRepository, profiles: profiles, calendar: .autoupdatingCurrent) }
        catch {
            Logger(subsystem: "com.example.Avela", category: "Widgets").error("Widget export failed: \(String(describing: error), privacy: .private)")
        }
    }

    private func handleWidgetURL(_ url: URL) {
        guard let repository else { return }
        do {
            let result = try WidgetActionHandler(repository: repository, calendar: .autoupdatingCurrent).handle(url)
            if result != .ignored {
                selectedTab = .today
                refreshVisibleData()
            }
        } catch { widgetActionError = "Your completion couldn't be saved. Open Today and try again." }
    }

    private func refreshVisibleData() {
        reloadProfile()
        exportWidgetSnapshot()
        synchronizeLiveActivity()
        Task { try? await reminderService?.synchronize() }
        todayViewModel?.load()
        attentionViewModel?.load()
        if selectedTab == .insights { insightsViewModel?.load() }
        if selectedTab == .history { historyViewModel?.load() }
    }

    @ViewBuilder
    private func destinationView(for tab: AppTab) -> some View {
        switch tab {
        case .today:
            if let todayViewModel, let repository, let attentionViewModel, let attentionRepository {
                TodayView(
                    viewModel: todayViewModel,
                    repository: repository,
                    attentionViewModel: attentionViewModel,
                    attentionRepository: attentionRepository,
                    companionProfile: companionProfile,
                    subscriptionManager: subscriptionManager,
                    onViewHistory: { habitID in
                        historyViewModel?.selectedHabitID = habitID
                        historyViewModel?.load()
                        selectedTab = .history
                    }
                )
            } else {
                ProgressView()
            }
        case .insights:
            if let insightsViewModel {
                InsightsView(viewModel: insightsViewModel)
            } else {
                ProgressView()
            }
        case .history:
            if let historyViewModel {
                HistoryView(viewModel: historyViewModel)
            } else {
                ProgressView()
            }
        case .settings:
            if let repository {
                SettingsView(repository: repository, profiles: profiles, subscriptionManager: subscriptionManager,
                             onPreferencesChanged: {
                                 reloadProfile()
                                 exportWidgetSnapshot()
                                 synchronizeLiveActivity()
                             })
            } else {
                ProgressView()
            }
        }
    }
}

#Preview {
    AppShellView()
        .modelContainer(try! AppPersistence.makeContainer(inMemory: true))
}
