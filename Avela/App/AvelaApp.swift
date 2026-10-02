import OSLog
import SwiftData
import SwiftUI

@main
@MainActor
struct AvelaApp: App {
    private let persistence: Result<ModelContainer, Error>

    init() {
        persistence = Result { try AppPersistence.makeContainer() }
        if case .failure(let error) = persistence {
            Logger(subsystem: "com.example.Avela", category: "Persistence")
                .error("Unable to open local store: \(error.localizedDescription, privacy: .private)")
        }
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
}
