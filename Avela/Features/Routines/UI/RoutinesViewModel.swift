import Foundation
import Observation

@Observable @MainActor
final class RoutinesViewModel {
    private let repository: any RoutineRepository
    private let habits: any HabitRepository
    var routines: [HabitRoutine] = []
    var activeHabits: [Habit] = []
    var errorMessage: String?

    init(repository: any RoutineRepository, habits: any HabitRepository) {
        self.repository = repository
        self.habits = habits
    }

    func load() {
        do {
            routines = try repository.routines()
            activeHabits = try habits.fetchHabits(includeArchived: false)
        } catch { errorMessage = "Your routines couldn’t be loaded. Please try again." }
    }

    @discardableResult
    func save(id: UUID?, name: String, habitIDs: [UUID], restartDays: Int? = nil, at date: Date = Date()) -> Bool {
        do {
            try repository.save(id: id, name: name, habitIDs: habitIDs, restartDays: restartDays, at: date)
            load()
            return true
        } catch RoutineError.invalidName { errorMessage = "Use a routine name between 1 and 80 characters." }
        catch RoutineError.invalidSelection { errorMessage = "Choose at least one active habit. A habit may have changed; reopen this form and try again." }
        catch { errorMessage = "Your routine couldn’t be saved. Please try again." }
        return false
    }

    func delete(_ routine: HabitRoutine) {
        do { try repository.delete(id: routine.id); load() }
        catch { errorMessage = "Your routine couldn’t be removed. Please try again." }
    }
}

@Observable @MainActor
final class RoutineRunViewModel {
    struct Step: Identifiable {
        let habit: Habit
        let isDue: Bool
        let isComplete: Bool
        var restartSuccessfulCommitments: Int? = nil
        var recoveryMessage: String? = nil
        var id: UUID { habit.id }
    }
    private let habits: any HabitRepository
    private let calendar: Calendar
    let routine: HabitRoutine
    var steps: [Step] = []
    var unavailableCount = 0
    var errorMessage: String?

    init(routine: HabitRoutine, habits: any HabitRepository, calendar: Calendar = .current) {
        self.routine = routine
        self.habits = habits
        self.calendar = calendar
    }

    var restartReviewDate: Date? { routine.restartReviewDate(calendar: calendar) }

    func load(asOf date: Date = Date()) {
        do {
            let active = Dictionary(uniqueKeysWithValues: try habits.fetchHabits(includeArchived: false).map { ($0.id, $0) })
            guard let interval = calendar.dateInterval(of: .day, for: date) else { return }
            steps = try routine.habitIDs.compactMap { id in
                guard let habit = active[id] else { return nil }
                let snapshots = try habits.configurationHistory(for: id)
                let schedule = HabitScheduleEvaluator.activeConfiguration(from: snapshots, on: date, calendar: calendar)?.schedule ?? habit.schedule
                let due = habit.createdAt <= date && HabitScheduleEvaluator.isDue(schedule, on: date, calendar: calendar)
                let complete = !(try habits.completions(for: id, in: interval)).isEmpty
                var step = Step(habit: habit, isDue: due, isComplete: complete)
                if routine.restartDays != nil, date >= routine.createdAt {
                    let historyInterval = DateInterval(start: habit.createdAt, end: interval.end)
                    let completions = try habits.completions(for: id, in: historyInterval)
                    let skips = try habits.skips(for: id, in: historyInterval)
                    let pauses = try habits.archivePeriods(for: id)
                    let restartRange = DateInterval(start: calendar.startOfDay(for: routine.createdAt), end: interval.end)
                    step.restartSuccessfulCommitments = HabitProgressCalculator.consistency(
                        for: habit, snapshots: snapshots, completions: completions, skips: skips,
                        archivePeriods: pauses, in: restartRange, asOf: date, calendar: calendar
                    ).successfulUnits
                    let recovery = HabitProgressCalculator.recoveryProgress(
                        for: habit, snapshots: snapshots, completions: completions, skips: skips,
                        archivePeriods: pauses, asOf: date, calendar: calendar
                    )
                    if recovery.isRecovering {
                        step.recoveryMessage = "Rebuilding momentum · \(recovery.consecutiveSuccessesSinceMiss) of \(HabitProgressCalculator.recoveryCompletionThreshold) successful commitments"
                    }
                }
                return step
            }
            unavailableCount = routine.habitIDs.count - steps.count
        } catch { errorMessage = "Your routine progress couldn’t be loaded. Please try again." }
    }
}
