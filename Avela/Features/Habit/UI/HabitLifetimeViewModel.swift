import Foundation
import Observation
import OSLog

@MainActor @Observable
final class HabitLifetimeViewModel {
    private let habitID: UUID
    private let habits: HabitRepository
    private let activity: HabitActivityRepository?
    private(set) var habitName = ""
    private(set) var summary: HabitLifetimeCalculator.Summary?
    private(set) var errorMessage: String?
    private(set) var hasQuantityHistory = false
    private static let logger = Logger(subsystem: "com.example.Avela", category: "HabitLifetime")

    init(habitID: UUID, habits: HabitRepository, activity: HabitActivityRepository?) {
        self.habitID = habitID
        self.habits = habits
        self.activity = activity
    }

    func load(asOf date: Date = Date()) {
        errorMessage = nil
        do {
            guard let habit = try habits.fetchHabit(id: habitID) else { throw HabitRepositoryError.habitNotFound(habitID) }
            let end = date.addingTimeInterval(0.001)
            let range = DateInterval(start: .distantPast, end: end)
            let completions = try habits.completions(for: habitID, in: range)
            // Entries are grouped by captured day keys. Read all keys so travel
            // cannot hide a logged date that lies ahead of today's local key;
            // the calculator filters their actual write timestamps instead.
            let entries = try activity?.entries(for: habitID, in: DateInterval(start: .distantPast, end: .distantFuture)) ?? []
            habitName = habit.name
            hasQuantityHistory = activity != nil
            summary = HabitLifetimeCalculator.summarize(habitID: habitID, completions: completions, entries: entries, asOf: date)
        } catch {
            summary = nil
            errorMessage = "Couldn't load your progress. Please try again."
            Self.logger.error("Lifetime read failed: \(String(describing: error), privacy: .private)")
        }
    }
}
