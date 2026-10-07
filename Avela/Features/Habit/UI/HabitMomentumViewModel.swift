import Foundation
import Observation

@MainActor @Observable
final class HabitMomentumViewModel {
    private let habitID: UUID
    private let habits: HabitRepository
    private let activity: HabitActivityRepository?
    private let calendar: Calendar
    private(set) var habitName = ""
    private(set) var summary: HabitMomentumCalculator.Summary?
    private(set) var errorMessage: String?

    init(habitID: UUID, habits: HabitRepository, activity: HabitActivityRepository?,
         calendar: Calendar = .autoupdatingCurrent) {
        self.habitID = habitID; self.habits = habits; self.activity = activity; self.calendar = calendar
    }

    func load(asOf date: Date = Date()) {
        summary = nil
        errorMessage = nil
        do {
            guard let habit = try habits.fetchHabit(id: habitID) else { throw HabitRepositoryError.habitNotFound(habitID) }
            let range = DateInterval(start: .distantPast, end: .distantFuture)
            let completions = try habits.completions(for: habitID, in: range)
            let skips = try habits.skips(for: habitID, in: range)
            let snapshots = try habits.configurationHistory(for: habitID)
            let archives = try habits.archivePeriods(for: habitID)
            let entries = try activity?.entries(for: habitID, in: range) ?? []
            habitName = habit.name
            summary = HabitMomentumCalculator.summarize(habit: habit, snapshots: snapshots, completions: completions,
                skips: skips, archivePeriods: archives, entries: entries, asOf: date, calendar: calendar)
        } catch {
            errorMessage = "Couldn't load your momentum. Please try again."
        }
    }
}
