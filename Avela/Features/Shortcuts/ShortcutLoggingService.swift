import Foundation

enum ShortcutLoggingError: LocalizedError, Equatable {
    case habitUnavailable
    case habitNotDue
    case budgetUnavailable
    case invalidMinutes
    case storeUnavailable
    case quantityRequired

    var errorDescription: String? {
        switch self {
        case .habitUnavailable: return "This habit is no longer active. Choose an active habit in Avela."
        case .habitNotDue: return "This habit isn't scheduled for today. Nothing was logged."
        case .budgetUnavailable: return "Choose a daily attention budget. Windows and sessions use check-ins in Avela."
        case .invalidMinutes: return "Enter more than 0 and no more than 1,440 minutes. Nothing was logged."
        case .quantityRequired: return "Use Log Habit Progress to add an amount in the configured unit before recording full success."
        case .storeUnavailable: return "Your data couldn't be opened or saved. Open Avela and try again."
        }
    }
}

/// Siri reports explicit user actions; it never infers what was completed.
/// Main-actor synchronous writes retain the app's single-writer contract.
@MainActor
struct ShortcutLoggingService {
    let habits: HabitRepository
    let attention: AttentionRepository
    var calendar: Calendar = .current
    var activity: HabitActivityRepository? = nil

    /// Repeating completion is safe: it never toggles or inserts a duplicate.
    func completeHabit(id: UUID, at date: Date) throws -> Bool {
        guard let habit = try habits.fetchHabit(id: id),
              habit.archivedAt == nil, habit.createdAt <= date else {
            throw ShortcutLoggingError.habitUnavailable
        }
        guard let configuration = try habits.activeConfiguration(for: id, on: date),
              HabitScheduleEvaluator.isDue(configuration.schedule, on: date, calendar: calendar),
              let interval = calendar.dateInterval(of: .day, for: date) else {
            throw ShortcutLoggingError.habitNotDue
        }
        if let target = try activity?.configuration(for: id, on: date)?.target {
            let total = try activity?.entries(for: id, on: date).filter { $0.kind == .quantity && $0.unit == target.unit }.reduce(0) { $0 + $1.amount } ?? 0
            guard total >= target.amount else { throw ShortcutLoggingError.quantityRequired }
        }
        if !(try habits.completions(for: id, in: interval)).isEmpty { return false }
        try habits.validateCompletion(habitID: id, at: date)
        for skip in try habits.skips(for: id, in: interval) {
            try habits.undoSkip(id: skip.id)
        }
        try habits.recordCompletion(habitID: id, at: date, source: .shortcutFuture, note: nil)
        return true
    }

    /// Each invocation is additive, just like an explicit quick-log tap.
    func logMinutes(_ minutes: Double, goalID: UUID, at date: Date) throws {
        guard minutes.isFinite, minutes > 0, minutes <= 1440 else {
            throw ShortcutLoggingError.invalidMinutes
        }
        guard let goal = try attention.fetchGoal(id: goalID),
              goal.type == .maxDurationPerDay, goal.createdAt <= date else {
            throw ShortcutLoggingError.budgetUnavailable
        }
        try attention.recordUsage(goalID: goalID, amount: minutes, at: date, source: .manual)
    }
}
