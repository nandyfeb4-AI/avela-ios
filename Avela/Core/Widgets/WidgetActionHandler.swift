import Foundation

enum WidgetActionResult: Equatable {
    case ignored
    case openedToday
    case openedHabit(UUID)
    case openedProgress(UUID)
    case completed(UUID)
    case alreadyCompleted(UUID)
}

/// Every widget write runs in the main app's single-writer repository.
/// A stale or forged URL cannot complete yesterday, an archived habit,
/// an unknown habit or a habit that is not due. Repeated taps are idempotent.
@MainActor
struct WidgetActionHandler {
    let repository: HabitRepository
    var calendar: Calendar = .current

    func handle(_ url: URL, asOf date: Date = Date()) throws -> WidgetActionResult {
        guard let link = WidgetDeepLink.parse(url) else { return .ignored }
        switch link {
        case .today: return .openedToday
        case .habit(let id), .logProgress(let id):
            guard try repository.fetchHabit(id: id) != nil else { return .ignored }
            return link == .habit(habitID: id) ? .openedHabit(id) : .openedProgress(id)
        case .complete(let habitID, let dayKey):
            guard dayKey == LocalDay.key(for: date, calendar: calendar),
                  let habit = try repository.fetchHabit(id: habitID),
                  habit.archivedAt == nil, habit.createdAt <= date,
                  let configuration = try repository.activeConfiguration(for: habitID, on: date),
                  HabitScheduleEvaluator.isDue(configuration.schedule, on: date, calendar: calendar)
            else { return .ignored }
            let start = calendar.startOfDay(for: date)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return .ignored }
            let range = DateInterval(start: start, end: end)
            if !(try repository.completions(for: habitID, in: range)).isEmpty {
                return .alreadyCompleted(habitID)
            }
            do { try repository.validateCompletion(habitID: habitID, at: date) }
            catch HabitActivityError.invalidAmount { return .openedToday }
            // An explicit completion replaces an excused skip, as it does
            // from Today; do not leave conflicting same-day facts.
            for skip in try repository.skips(for: habitID, in: range) {
                try repository.undoSkip(id: skip.id)
            }
            _ = try repository.recordCompletion(habitID: habitID, at: date, source: .widget, note: nil)
            return .completed(habitID)
        }
    }
}
