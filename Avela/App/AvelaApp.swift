import OSLog
import SwiftData
import SwiftUI

@main
@MainActor
struct AvelaApp: App {
    private let persistence: Result<ModelContainer, Error>

    init() {
        persistence = Result { try AvelaApp.makeContainer() }
        if case .failure(let error) = persistence {
            Logger(subsystem: "com.example.Avela", category: "Persistence")
                .error("Unable to open local store: \(error.localizedDescription, privacy: .private)")
        }
        AvelaApp.seedDebugFixtureIfRequested(into: persistence)
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
        DebugFixtures.seed(fixture, into: repository, calendar: .current)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            switch persistence {
            case .success(let container):
                AppShellView()
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

    /// Resolves the store `AvelaApp` opens at launch. Normal launches use
    /// `AppPersistence`'s default on-disk location, untouched. UI tests set
    /// `AVELA_UI_TEST_STORE_PATH` (via `XCUIApplication.launchEnvironment`) to a
    /// fresh temporary file per test method, so each UI test gets an isolated,
    /// empty-at-start store — without it, every UI test would read and write the
    /// same real app store, making "empty on first launch" and "survives
    /// relaunch" assertions unreliable across test runs.
    ///
    /// The override is wrapped in `#if DEBUG` so it is compiled out of Release
    /// builds entirely — not merely unset, but physically absent from the
    /// binary. Checking the environment variable unconditionally would let any
    /// process able to set environment variables for a shipped app (TestFlight
    /// or App Store) redirect where it reads and writes the user's entire
    /// store. `xcodebuild test` builds Debug by default, so this does not
    /// affect normal UI test runs; a Release/Archive build never evaluates it.
    private static func makeContainer() throws -> ModelContainer {
        #if DEBUG
        if let testStorePath = ProcessInfo.processInfo.environment["AVELA_UI_TEST_STORE_PATH"] {
            return try AppPersistence.makeContainer(storeURL: URL(fileURLWithPath: testStorePath))
        }
        #endif
        return try AppPersistence.makeContainer()
    }
}
