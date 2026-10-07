import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class HabitAdjustmentViewModel {
    private(set) var proposal: HabitAdjustmentProposal?
    private(set) var habitName = ""
    var frequency = 1
    var frequencyLabel: String { frequency == 1 ? "1 time per week" : "\(frequency) times per week" }
    private(set) var errorMessage: String?
    private(set) var needsReload = false
    private var reviewedRevision: Int?
    private var reviewedDay: String?
    private let habitID: UUID
    private let repository: HabitRepository
    private let calendar: Calendar
    private static let logger = Logger(subsystem: "com.example.Avela", category: "HabitAdjustment")

    init(habitID: UUID, repository: HabitRepository, calendar: Calendar = .autoupdatingCurrent) {
        self.habitID = habitID
        self.repository = repository
        self.calendar = calendar
    }

    func load(asOf date: Date = Date()) {
        proposal = nil
        reviewedRevision = nil
        errorMessage = nil
        needsReload = false
        do {
            guard let habit = try repository.fetchHabit(id: habitID) else { markStale(); return }
            let facts = try readProposal(for: habit, asOf: date)
            habitName = habit.name
            proposal = facts
            frequency = facts?.suggestedFrequency ?? 1
            reviewedRevision = try repository.activeConfiguration(for: habitID, on: date)?.revision
            reviewedDay = LocalDay.key(for: date, calendar: calendar)
        } catch { handle(error) }
    }

    /// Revalidates the review immediately before the synchronous main-actor write.
    /// Cosmetic edits are preserved using the latest habit, rather than an old form draft.
    func save(asOf date: Date = Date()) -> Bool {
        guard !needsReload, let proposal else { return false }
        guard (1...proposal.maximumFrequency).contains(frequency) else {
            errorMessage = "Choose a frequency from 1 to \(proposal.maximumFrequency)."
            return false
        }
        do {
            guard reviewedDay == LocalDay.key(for: date, calendar: calendar),
                  let habit = try repository.fetchHabit(id: habitID),
                  let latest = try readProposal(for: habit, asOf: date),
                  latest.currentSchedule == proposal.currentSchedule,
                  try repository.activeConfiguration(for: habitID, on: date)?.revision == reviewedRevision
            else { markStale(); return false }
            _ = try repository.updateHabit(id: habitID, with: HabitDraft(
                name: habit.name, iconName: habit.iconName, category: habit.category,
                polarity: habit.polarity, schedule: .timesPerWeek(frequency),
                whyItMatters: habit.whyItMatters, isWhyMemoryHidden: habit.isWhyMemoryHidden
            ), at: date)
            self.proposal = nil // a repeated confirmation cannot append another edit
            return true
        } catch { handle(error); return false }
    }

    private func readProposal(for habit: Habit, asOf date: Date) throws -> HabitAdjustmentProposal? {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
        let interval = DateInterval(start: min(habit.createdAt, date), end: end)
        return HabitAdjustmentCalculator.proposal(for: habit,
            snapshots: try repository.configurationHistory(for: habitID),
            completions: try repository.completions(for: habitID, in: interval),
            skips: try repository.skips(for: habitID, in: interval),
            archivePeriods: try repository.archivePeriods(for: habitID), asOf: date, calendar: calendar)
    }

    private func markStale() {
        needsReload = true
        errorMessage = "This habit or day changed. Reload and review the schedule again."
    }

    private func handle(_ error: Error) {
        Self.logger.error("Schedule adjustment failed: \(String(describing: error), privacy: .private)")
        errorMessage = "Couldn't update this schedule. Please try again."
    }
}
