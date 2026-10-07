import Foundation

/// Re-validates every watch action against canonical phone data, not the cached
/// watch row. The caller supplies whether protected phone data is available for a write.
@MainActor
final class WatchHabitLoggingService {
    private let repository: any HabitRepository
    private let calendar: Calendar
    private let supportsQuickLog: (Habit) -> Bool

    init(repository: any HabitRepository, calendar: Calendar = .current,
         supportsQuickLog: @escaping (Habit) -> Bool = { _ in true }) {
        self.repository = repository
        self.calendar = calendar
        self.supportsQuickLog = supportsQuickLog
    }

    func snapshot(at date: Date = Date()) throws -> WatchHabitSnapshot {
        let interval = dayInterval(date)
        let key = LocalDay.key(for: date, calendar: calendar)
        let habits = try repository.fetchHabits(includeArchived: false)
        var items: [WatchHabitItem] = []
        for habit in habits {
            guard habit.createdAt <= date else { continue }
            let schedule = try repository.activeConfiguration(for: habit.id, on: date)?.schedule ?? habit.schedule
            guard HabitScheduleEvaluator.isDue(schedule, on: date, calendar: calendar) else { continue }
            let completed = try repository.completions(for: habit.id, in: interval).contains { $0.localDateKey == key }
            let skipped = try repository.skips(for: habit.id, in: interval).contains { $0.localDateKey == key }
            guard !skipped else { continue }
            items.append(WatchHabitItem(id: habit.id, name: habit.name, iconName: habit.iconName,
                                       isCompleted: completed, supportsQuickLog: supportsQuickLog(habit)))
        }
        return WatchHabitSnapshot(protocolVersion: WatchHabitSnapshot.version, generatedAt: date,
                                 localDateKey: key, expiresAt: interval.end, habits: items)
    }

    func log(_ request: WatchHabitLogRequest, at date: Date = Date(), phoneAvailable: Bool) -> WatchHabitReply {
        guard phoneAvailable else { return WatchHabitReply(status: .openPhone, snapshot: nil) }
        guard request.protocolVersion == WatchHabitSnapshot.version,
              request.localDateKey == LocalDay.key(for: date, calendar: calendar) else {
            return WatchHabitReply(status: .staleDay, snapshot: try? snapshot(at: date))
        }
        do {
            guard let habit = try repository.fetchHabit(id: request.habitID), !habit.isArchived, habit.createdAt <= date,
                  supportsQuickLog(habit) else { return WatchHabitReply(status: .unavailable, snapshot: try? snapshot(at: date)) }
            let schedule = try repository.activeConfiguration(for: habit.id, on: date)?.schedule ?? habit.schedule
            guard HabitScheduleEvaluator.isDue(schedule, on: date, calendar: calendar),
                  try repository.skips(for: habit.id, in: dayInterval(date)).isEmpty else {
                return WatchHabitReply(status: .unavailable, snapshot: try? snapshot(at: date))
            }
            let key = LocalDay.key(for: date, calendar: calendar)
            if try repository.completions(for: habit.id, in: dayInterval(date)).contains(where: { $0.localDateKey == key }) {
                return WatchHabitReply(status: .alreadyLogged, snapshot: try? snapshot(at: date))
            }
            try repository.recordCompletion(habitID: habit.id, at: date, source: .watch, note: nil)
            return WatchHabitReply(status: .logged, snapshot: try? snapshot(at: date))
        } catch {
            return WatchHabitReply(status: .failed, snapshot: nil)
        }
    }

    private func dayInterval(_ date: Date) -> DateInterval {
        let start = calendar.startOfDay(for: date)
        return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 1, to: start)!)
    }
}
