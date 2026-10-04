import Foundation
import OSLog
import Observation

struct ArchivedHabitRow: Identifiable, Equatable {
    let id: UUID
    let name: String
    let iconName: String
    let scheduleLabel: String
}

/// Feature state for Settings' Archived Habits list. Reactivation goes through
/// the same `HabitRepository` operation Today's domain layer already exposes;
/// this type only lists archived habits and shapes them for display.
@MainActor
@Observable
final class ArchivedHabitsViewModel {
    private(set) var rows: [ArchivedHabitRow] = []
    var errorMessage: String?
    var isShowingPremium = false
    var activationAllowed: (Int) -> Bool = { _ in true }

    private let repository: HabitRepository
    private static let logger = Logger(subsystem: "com.example.Avela", category: "ArchivedHabitsViewModel")
    private static let friendlyErrorMessage = "Something went wrong. Please try again."

    init(repository: HabitRepository) {
        self.repository = repository
    }

    func load() {
        do {
            rows = try repository.fetchHabits(includeArchived: true)
                .filter(\.isArchived)
                .map { ArchivedHabitRow(id: $0.id, name: $0.name, iconName: $0.iconName, scheduleLabel: HabitScheduleFormatter.description(for: $0.schedule)) }
        } catch {
            handle(error)
        }
    }

    func reactivate(_ row: ArchivedHabitRow, asOf date: Date = Date()) {
        do {
            guard activationAllowed(try repository.fetchHabits(includeArchived: false).count) else {
                isShowingPremium = true
                return
            }
            try repository.reactivateHabit(id: row.id, at: date)
            load()
        } catch {
            handle(error)
        }
    }

    private func handle(_ error: Error) {
        Self.logger.error("Archived habits view model operation failed: \(String(describing: error), privacy: .private)")
        errorMessage = Self.friendlyErrorMessage
    }
}
