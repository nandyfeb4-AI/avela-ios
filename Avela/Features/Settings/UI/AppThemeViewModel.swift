import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class AppThemeViewModel {
    private let repository: AppearanceRepository
    private(set) var selectedTheme: AppTheme = .tidewater
    private(set) var hasLoaded = false
    var errorMessage: String?

    init(repository: AppearanceRepository) { self.repository = repository }

    func load() {
        do {
            selectedTheme = try repository.theme()
            hasLoaded = true
            errorMessage = nil
        } catch { hasLoaded = false; handle(error) }
    }

    /// Publish selection only after persistence succeeds; failed writes do not
    /// claim a changed preference or trigger a misleading live preview.
    @discardableResult
    func select(_ theme: AppTheme) -> Bool {
        guard hasLoaded else { return false }
        do {
            try repository.save(theme: theme)
            selectedTheme = theme
            errorMessage = nil
            return true
        } catch { handle(error); return false }
    }

    private func handle(_ error: Error) {
        Logger(subsystem: "com.example.Avela", category: "Appearance").error("Theme preference failed: \(String(describing: error), privacy: .private)")
        errorMessage = "Couldn't update your app theme. Your saved tracking data hasn't changed. Please try again."
    }
}
