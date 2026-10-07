import SwiftData
import SwiftUI
import OSLog
import CloudKit

/// Composition root for tab navigation. Owns the one `HabitRepository` and the
/// Today/Insights/History view models for the app's lifetime, resolving the
/// repository from the environment's `ModelContext` — persistence composition
/// stays here in `App/`, not inside feature views. Local onboarding/preferences
/// and StoreKit ownership live here so feature screens share one authority.
struct AppShellView: View {
    @ObservedObject var notificationDelegate: AvelaNotificationDelegate

    init(notificationDelegate: AvelaNotificationDelegate) {
        _notificationDelegate = ObservedObject(wrappedValue: notificationDelegate)
    }
    @Environment(\.scenePhase) private var scenePhase
    @State private var todayNavigationID = UUID()
    @State private var selectedTab: AppTab = .today
    @Environment(\.modelContext) private var modelContext
    @State private var repository: HabitRepository?
    @State private var todayViewModel: TodayViewModel?
    @State private var insightsViewModel: InsightsViewModel?
    @State private var historyViewModel: HistoryViewModel?
    @State private var reminderService: HabitReminderService?
    @State private var healthService: HealthHabitService?
    @State private var liveActivityService: SessionLiveActivityService?
    @State private var activityRepository: HabitActivityRepository?
    @State private var routineRepository: RoutineRepository?
    @State private var reflectionRepository: ReflectionRepository?
    @State private var cloudBackup: CloudBackupModel?
    @State private var watchCoordinator: WatchConnectivityCoordinator?
    @AppStorage("avela.watchIntegrationEnabled") private var watchEnabled = false
    @State private var attentionRepository: AttentionRepository?
    @State private var intentionLinks: IntentionSessionLinkRepository?
    @State private var attentionViewModel: AttentionSummaryViewModel?
    @State private var appearance: AppearanceRepository?
    @State private var appTheme: AppTheme = .tidewater
    @State private var profiles: CompanionProfileRepository?
    @State private var companionProfile = CompanionProfile()
    @State private var onboardingViewModel: OnboardingViewModel?
    @State private var subscriptionManager = SubscriptionManager()
    private struct WidgetSelection: Identifiable {
        let id: UUID
        let logsProgress: Bool
    }
    @State private var widgetSelection: WidgetSelection?
    @State private var pendingWidgetURL: URL?
    @State private var widgetActionError: String?
    @State private var didInitialize = false
    @State private var reminderReviewAction: HabitReminderAction?
    @State private var reminderReviewName: String?
    @State private var reminderFeedback: String?
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
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            cloudBackup?.scheduleBackup()
        }
        .onReceive(NotificationCenter.default.publisher(for: .CKAccountChanged)) { _ in
            cloudBackup?.accountDidChange()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { cloudBackup?.scheduleBackup() }
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
        .environment(\.appPalette, AppPalette(theme: appTheme))
        .tint(AppPalette(theme: appTheme).accent)
        .environment(\.habitActivityRepository, activityRepository)
        .environment(\.routineRepository, routineRepository)
        .environment(\.attentionIntentionRepository, attentionRepository)
        .environment(\.attentionGoalCreationAllowed, { subscriptionManager.canCreateAttentionGoal(activeCount: $0) })
        .environment(\.intentionLinkRepository, intentionLinks)
        .environment(\.habitReminderService, reminderService)
        .environment(\.healthHabitService, healthService)
        .environment(\.sessionLiveActivityService, liveActivityService)
        .sheet(item: $widgetSelection, onDismiss: refreshVisibleData) { selection in
            if let repository {
                if selection.logsProgress, let activityRepository {
                    HabitActivityView(habitID: selection.id, repository: activityRepository, habits: repository)
                } else {
                    WidgetHabitDestination(habitID: selection.id, repository: repository, onViewHistory: { id in
                        widgetSelection = nil
                        historyViewModel?.selectedHabitID = id
                        selectedTab = .history
                        historyViewModel?.load()
                    })
                }
            }
        }
        .onOpenURL { url in
            if didInitialize { handleWidgetURL(url) } else { pendingWidgetURL = url }
        }
        .onReceive(NotificationCenter.default.publisher(for: .avelaPersistenceDidChange)) { _ in
            // Background widget intents publish their final, pinned projection
            // after the save. Do not race that export with an unpinned reload.
            if scenePhase == .active { exportWidgetSnapshot() }
            synchronizeLiveActivity()
            watchCoordinator?.refresh()
            todayViewModel?.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .avelaShortcutDidLog)) { _ in
            refreshVisibleData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .avelaHealthDidLog)) { _ in
            todayViewModel?.load()
            attentionViewModel?.load()
            if selectedTab == .history { historyViewModel?.load() }
            if selectedTab == .insights { insightsViewModel?.load() }
        }
        .onReceive(notificationDelegate.$pendingAction) { action in
            if let action, didInitialize { prepareReminderReview(action) }
        }
        .alert(reminderReviewName != nil ? "Log Success?" : (widgetActionError != nil ? "Unable to Log This Habit" : "Reminder Update"), isPresented: Binding(
            get: { reminderReviewName != nil || reminderFeedback != nil || widgetActionError != nil },
            set: { if !$0 {
                    reminderReviewName = nil
                    reminderReviewAction = nil
                    reminderFeedback = nil
                    widgetActionError = nil
                    clearPendingReminderAfterViewUpdate()
                } }
        )) {
            if let action = reminderReviewAction {
                Button("Log success") { confirmReminderAction(action) }
                Button("Cancel", role: .cancel) { reminderReviewAction = nil; clearPendingReminderAfterViewUpdate() }
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: {
            if let name = reminderReviewName {
                Text("Log success for \(name) today? This is your own check-in; you can undo it in Today.")
            } else {
                Text(reminderFeedback ?? widgetActionError ?? "")
            }
        }
        .onChange(of: watchEnabled) { _, enabled in watchCoordinator?.setEnabled(enabled) }
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
                .id(tab == .today ? todayNavigationID.uuidString : tab.title)
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
            healthService = HealthHabitService(habits: repository,
                connections: SwiftDataHealthHabitConnectionRepository(context: modelContext),
                provider: HealthKitHabitProvider())
            let activity = SwiftDataHabitActivityRepository(context: modelContext, habits: repository)
            activityRepository = activity
            healthService?.permitsConnection = { id in
                do { return try activity.configuration(for: id, on: Date())?.target == nil } catch { return false }
            }
            routineRepository = SwiftDataRoutineRepository(modelContext: modelContext, habits: repository)
            reflectionRepository = SwiftDataReflectionRepository(context: modelContext)
            cloudBackup = CloudBackupModel(store: BackupStore(context: modelContext), provider: try CloudBackupProviders.make())
            cloudBackup?.scheduleBackup()
            todayViewModel = TodayViewModel(repository: repository)
            todayViewModel?.activityRepository = activity
            watchCoordinator = WatchConnectivityCoordinator(service: WatchHabitLoggingService(repository: repository,
                supportsQuickLog: { habit in
                    do { return try activity.configuration(for: habit.id, on: Date())?.target == nil } catch { return false }
                }),
                didLog: { refreshVisibleData() })
            #if DEBUG
            if ProcessInfo.processInfo.environment["AVELA_UI_TEST_STORE_PATH"] == nil { watchCoordinator?.setEnabled(watchEnabled) }
            #else
            watchCoordinator?.setEnabled(watchEnabled)
            #endif
            let subscriptionManager = self.subscriptionManager
            todayViewModel?.creationAllowed = { subscriptionManager.canCreateHabit(activeCount: $0) }
            let attentionRepository = SwiftDataAttentionRepository(modelContext: modelContext)
            self.attentionRepository = attentionRepository
            intentionLinks = SwiftDataIntentionSessionLinkRepository(modelContext: modelContext)
            insightsViewModel = InsightsViewModel(repository: repository, attentionRepository: attentionRepository, intentionLinks: intentionLinks)
            historyViewModel = HistoryViewModel(repository: repository, attentionRepository: attentionRepository)
            let service = HabitReminderService(habits: repository,
                reminders: SwiftDataHabitReminderRepository(modelContext: modelContext), adapter: UserNotificationAdapter())
            reminderService = service
            attentionViewModel = AttentionSummaryViewModel(repository: attentionRepository)
            attentionViewModel?.creationAllowed = { subscriptionManager.canCreateAttentionGoal(activeCount: $0) }
            let appearance = SwiftDataAppearanceRepository(context: modelContext)
            self.appearance = appearance
            appTheme = try appearance.theme()
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
            if let action = notificationDelegate.pendingAction { prepareReminderReview(action) }
            exportWidgetSnapshot()
            synchronizeLiveActivity()
            Task { await healthService?.refresh() }
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

    /// UIKit may reset an alert binding during SwiftUI's update transaction.
    /// Defer the ObservableObject publication, and never consume a newer
    /// reminder that arrived while the previous dismissal was completing.
    private func clearPendingReminderAfterViewUpdate() {
        let delegate = notificationDelegate
        guard let action = delegate.pendingAction else { return }
        Task { @MainActor [weak delegate] in
            guard delegate?.pendingAction == action else { return }
            delegate?.pendingAction = nil
        }
    }

    private func prepareReminderReview(_ action: HabitReminderAction) {
        guard reminderReviewAction == nil, let repository else { return }
        selectedTab = .today
        todayNavigationID = UUID()
        do {
            if let result = try ReminderActionHandler(habits: repository).validate(action, at: Date()) {
                clearPendingReminderAfterViewUpdate()
                reminderFeedback = result.message
            } else {
                reminderReviewAction = action
                reminderReviewName = try repository.fetchHabit(id: action.habitID)?.name
            }
        } catch {
            clearPendingReminderAfterViewUpdate()
            reminderFeedback = "Unable to open this habit. Please try again from Today."
        }
    }

    private func confirmReminderAction(_ action: HabitReminderAction) {
        guard let repository else { return }
        reminderReviewAction = nil
        clearPendingReminderAfterViewUpdate()
        reminderReviewName = nil
        do {
            let result = try ReminderActionHandler(habits: repository).handle(action, at: Date())
            selectedTab = .today
            todayNavigationID = UUID()
            refreshVisibleData()
            // A successful write is visible in Today; errors/stale actions need
            // an explanation, not a success alert stacked over confirmation.
            if result != .logged { reminderFeedback = result.message }
        } catch {
            reminderFeedback = "Unable to save this check-in. Open Today and try again."
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
        do {
            companionProfile = try profiles.profile()
            if let appearance { appTheme = try appearance.theme() }
        }
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
        do { try WidgetSnapshotExporter().export(habits: repository, attention: attentionRepository, profiles: profiles, activity: activityRepository, routines: routineRepository, theme: appTheme, calendar: .autoupdatingCurrent) }
        catch {
            Logger(subsystem: "com.example.Avela", category: "Widgets").error("Widget export failed: \(String(describing: error), privacy: .private)")
        }
    }

    private func handleWidgetURL(_ url: URL) {
        guard let repository else { return }
        do {
            let result = try WidgetActionHandler(repository: repository, calendar: .autoupdatingCurrent).handle(url)
            switch result {
            case .openedHabit(let id): widgetSelection = WidgetSelection(id: id, logsProgress: false)
            case .openedProgress(let id): widgetSelection = WidgetSelection(id: id, logsProgress: true)
            default: break
            }
            if result != .ignored {
                selectedTab = .today
                refreshVisibleData()
            }
        } catch { widgetActionError = "Your completion couldn't be saved. Open Today and try again." }
    }

    private func refreshVisibleData() {
        reloadProfile()
        watchCoordinator?.refresh()
        exportWidgetSnapshot()
        synchronizeLiveActivity()
        Task { try? await reminderService?.synchronize() }
        todayViewModel?.load()
        attentionViewModel?.load()
        Task {
            await healthService?.refresh()
            todayViewModel?.load()
            if selectedTab == .history { historyViewModel?.load() }
        }
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
                InsightsView(viewModel: insightsViewModel, onViewHistory: { habitID in
                    historyViewModel?.selectedHabitID = habitID
                    historyViewModel?.load()
                    selectedTab = .history
                }, reflectionRepository: reflectionRepository)
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
                SettingsView(repository: repository, reflectionRepository: reflectionRepository, cloudBackup: cloudBackup, watchEnabled: $watchEnabled, profiles: profiles, appearance: appearance, subscriptionManager: subscriptionManager,
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
    AppShellView(notificationDelegate: AvelaNotificationDelegate())
        .modelContainer(try! AppPersistence.makeContainer(inMemory: true))
}
