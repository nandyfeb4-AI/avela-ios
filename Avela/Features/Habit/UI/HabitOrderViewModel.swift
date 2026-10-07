import Foundation
import Observation
import OSLog

/// A cancellable ordering draft containing every active habit, including
/// habits not due today. No tracking facts are written by this screen.
@MainActor
@Observable
final class HabitOrderViewModel {
    private(set) var habits: [Habit] = []
    private(set) var isLoaded = false
    private(set) var needsReload = false
    private(set) var errorMessage: String?
    private var originalIDs: [UUID] = []
    private let repository: HabitRepository
    private static let logger = Logger(subsystem: "com.example.Avela", category: "HabitOrder")

    init(repository: HabitRepository) { self.repository = repository }

    var hasChanges: Bool { habits.map(\.id) != originalIDs }
    var canSave: Bool { isLoaded && hasChanges && !needsReload }

    func load() {
        do {
            habits = try repository.fetchHabits(includeArchived: false)
            originalIDs = habits.map(\.id)
            isLoaded = true
            needsReload = false
            errorMessage = nil
        } catch {
            isLoaded = false
            report(error)
        }
    }

    func move(from offsets: IndexSet, to destination: Int) {
        guard isLoaded, !needsReload, destination >= 0, destination <= habits.count,
              !offsets.isEmpty, offsets.allSatisfy({ habits.indices.contains($0) }) else { return }
        let moving = offsets.sorted().map { habits[$0] }
        let insertion = destination - offsets.filter { $0 < destination }.count
        for index in offsets.sorted(by: >) { habits.remove(at: index) }
        habits.insert(contentsOf: moving, at: insertion)
    }

    func move(_ id: UUID, up: Bool) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        let target = up ? index - 1 : index + 1
        guard habits.indices.contains(target) else { return }
        move(from: IndexSet(integer: index), to: up ? target : target + 1)
    }

    @discardableResult
    func save() -> Bool {
        guard canSave else { return false }
        do {
            try repository.reorderHabits(ids: habits.map(\.id))
            originalIDs = habits.map(\.id)
            errorMessage = nil
            return true
        } catch HabitRepositoryError.invalidHabitOrder {
            needsReload = true
            errorMessage = "Your habit list changed. Reload it before arranging again."
            return false
        } catch {
            report(error)
            return false
        }
    }

    private func report(_ error: Error) {
        Self.logger.error("Habit ordering failed: \(String(describing: error), privacy: .private)")
        errorMessage = "Couldn’t update your habit order. Please try again."
    }
}
