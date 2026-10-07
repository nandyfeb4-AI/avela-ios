import OSLog
import SwiftData
import SwiftUI

@main
@MainActor
struct AvelaApp: App {
    @UIApplicationDelegateAdaptor(AvelaNotificationDelegate.self) private var notificationDelegate
    private let persistence: Result<ModelContainer, Error>

    init() {
        persistence = AppPersistence.liveContainer
        if case .failure(let error) = persistence {
            Logger(subsystem: "com.example.Avela", category: "Persistence")
                .error("Unable to open local store: \(error.localizedDescription, privacy: .private)")
        }
        AvelaApp.seedDebugFixtureIfRequested(into: persistence)
        AvelaShortcuts.updateAppShortcutParameters()
    }

    /// Seeds a deterministic past-week fixture for UI tests that need to see
    /// *populated* Insights states (overall summaries, ties, a balanced week,
    /// a valid trend, an unavailable comparison) — states that cannot be
    /// reached by logging anything "today," since Insights never shows the
    /// in-progress current week.
    ///
    /// Gated `#if DEBUG` like the store-path override, and additionally
    /// requires `AVELA_UI_TEST_STORE_PATH` to *also* be set — so even in a
    /// Debug build, this can only ever write into the already-isolated,
    /// per-test-method store that override redirects to, never the ordinary
    /// app store, regardless of what a stray environment variable might set
    /// on its own. See `DebugFixtures` for what each named fixture seeds.
    private static func seedDebugFixtureIfRequested(into persistence: Result<ModelContainer, Error>) {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["AVELA_UI_TEST_STORE_PATH"] != nil,
              let fixtureName = ProcessInfo.processInfo.environment["AVELA_UI_TEST_SEED_FIXTURE"],
              let fixture = DebugFixtures.Fixture(rawValue: fixtureName),
              case .success(let container) = persistence
        else { return }
        let repository = SwiftDataHabitRepository(modelContext: container.mainContext)
        DebugFixtures.seed(fixture, into: repository, calendar: .current, context: container.mainContext)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            switch persistence {
            case .success(let container):
                AppShellView(notificationDelegate: notificationDelegate)
                    .modelContainer(container)
            case .failure:
                ContentUnavailableView(
                    "Unable to Open Avela",
                    systemImage: "externaldrive.badge.exclamationmark",
                    description: Text("Your local data could not be opened. Please close Avela and try again.")
                )
            }
        }
    }

}
