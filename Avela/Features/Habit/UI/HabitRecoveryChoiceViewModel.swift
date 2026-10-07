import Foundation
import Observation

@MainActor @Observable
final class HabitRecoveryChoiceViewModel {
    private let habitID: UUID
    private let habits: any HabitRepository
    private let activities: any HabitActivityRepository
    private let calendar: Calendar
    private var reviewedDay: String?
    private var reviewedActivityConfigurationID: UUID?
    private(set) var habitName = ""
    private(set) var suggestion: HabitRecoverySuggestion?
    private(set) var errorMessage: String?

    init(habitID: UUID, habits: any HabitRepository, activities: any HabitActivityRepository,
         calendar: Calendar = .autoupdatingCurrent) {
        self.habitID = habitID
        self.habits = habits
        self.activities = activities
        self.calendar = calendar
    }

    func load(asOf date: Date = Date()) {
        suggestion = nil
        errorMessage = nil
        reviewedDay = nil
        do {
            guard let habit = try habits.fetchHabit(id: habitID) else { stale(); return }
            habitName = habit.name
            suggestion = try readSuggestion(for: habit, asOf: date)
            reviewedDay = LocalDay.key(for: date, calendar: calendar)
            reviewedActivityConfigurationID = try activities.configuration(for: habitID, on: date)?.id
        } catch { errorMessage = "This option couldn’t be loaded. Your habit is unchanged." }
    }

    /// Opens the existing logger after a fresh check; never records effort itself.
    func canOpenSmallerAction(asOf date: Date = Date()) -> Bool {
        guard suggestion?.smallerAction != nil else { return false }
        return validateReview(asOf: date)
    }

    /// Called only after a named native confirmation. This is an indefinite
    /// pause, with explicit manual reactivation — never a fake Monday deadline.
    @discardableResult
    func pause(asOf date: Date = Date()) -> Bool {
        guard validateReview(asOf: date) else { return false }
        do {
            try habits.archiveHabit(id: habitID, at: date)
            suggestion = nil
            NotificationCenter.default.post(name: .avelaPersistenceDidChange, object: nil)
            return true
        } catch { errorMessage = "This habit couldn’t be paused. Please reload and try again."; return false }
    }

    func clearError() { errorMessage = nil }

    private func validateReview(asOf date: Date) -> Bool {
        errorMessage = nil
        do {
            guard reviewedDay == LocalDay.key(for: date, calendar: calendar),
                  let reviewed = suggestion,
                  let habit = try habits.fetchHabit(id: habitID),
                  try readSuggestion(for: habit, asOf: date) == reviewed,
                  try activities.configuration(for: habitID, on: date)?.id == reviewedActivityConfigurationID
            else { stale(); return false }
            return true
        } catch { errorMessage = "This option couldn’t be checked. Nothing was changed."; return false }
    }

    private func readSuggestion(for habit: Habit, asOf date: Date) throws -> HabitRecoverySuggestion? {
        guard let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)),
              habit.createdAt <= date else { return nil }
        // A smaller effort already recorded today needs no repeated invitation.
        guard !(try activities.entries(for: habitID, on: date)).contains(where: { $0.kind == .smallerAction }) else { return nil }
        let range = DateInterval(start: habit.createdAt, end: end)
        return try HabitRecoverySuggestionCalculator.suggestion(for: habit,
            snapshots: habits.configurationHistory(for: habitID),
            completions: habits.completions(for: habitID, in: range),
            skips: habits.skips(for: habitID, in: range),
            archivePeriods: habits.archivePeriods(for: habitID),
            smallerAction: activities.configuration(for: habitID, on: date)?.smallerAction,
            asOf: date, calendar: calendar)
    }

    private func stale() {
        suggestion = nil
        errorMessage = "Your check-ins, habit or day changed. Reload before choosing an option."
    }
}
