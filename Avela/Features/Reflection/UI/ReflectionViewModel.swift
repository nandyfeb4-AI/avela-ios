import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class ReflectionViewModel {
    private let repository: ReflectionRepository
    private let calendar: Calendar
    private let habits: HabitRepository?
    private(set) var habitResults: [WeeklyInsightsCalculator.HabitWeekSummary] = []
    private(set) var progressError: String?
    private(set) var isCurrentWeek = true
    private(set) var selectedWeek: ReflectionWeek
    private(set) var reflection: WeeklyReflection?
    private(set) var hasLoaded = false
    var draft = ReflectionDraft()
    var errorMessage: String?

    init(repository: ReflectionRepository, habits: HabitRepository? = nil, calendar: Calendar = .autoupdatingCurrent, now: Date = Date()) {
        self.repository = repository
        self.habits = habits
        self.calendar = calendar
        selectedWeek = .containing(now, calendar: calendar)
    }

    var weekLabel: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        let lastDay = calendar.date(byAdding: .day, value: -1, to: selectedWeek.end) ?? selectedWeek.start
        return "\(formatter.string(from: selectedWeek.start)) – \(formatter.string(from: lastDay))"
    }
    func canMoveForward(asOf date: Date = Date()) -> Bool {
        selectedWeek.start < ReflectionWeek.containing(date, calendar: calendar).start
    }
    func load(asOf date: Date = Date()) {
        do {
            reflection = try repository.reflection(for: selectedWeek)
            hasLoaded = true
            errorMessage = nil
        } catch { hasLoaded = false; handle(error) }
        loadProgress(asOf: date)
    }
    func selectWeek(offset: Int, asOf date: Date = Date()) {
        guard offset == -1 || offset == 1,
              let candidate = calendar.date(byAdding: .weekOfYear, value: offset, to: selectedWeek.start) else { return }
        let week = ReflectionWeek.containing(candidate, calendar: calendar)
        guard week.start <= ReflectionWeek.containing(date, calendar: calendar).start else { return }
        selectedWeek = week
        load(asOf: date)
    }
    func beginEditing() {
        draft = ReflectionDraft(whatHelped: reflection?.whatHelped ?? "", whatGotInTheWay: reflection?.whatGotInTheWay ?? "")
    }
    func cancelEditing() { draft = ReflectionDraft() }
    @discardableResult
    func save(at date: Date = Date()) -> Bool {
        guard hasLoaded, draft.isValid else { return false }
        do {
            reflection = try repository.save(draft, for: selectedWeek, at: date)
            draft = ReflectionDraft()
            errorMessage = nil
            return true
        } catch { handle(error); return false }
    }
    @discardableResult
    func delete() -> Bool {
        guard hasLoaded else { return false }
        do {
            try repository.delete(for: selectedWeek)
            reflection = nil
            errorMessage = nil
            return true
        } catch { handle(error); return false }
    }
    private func handle(_ error: Error) {
        Logger(subsystem: "com.example.Avela", category: "Reflection").error("Reflection operation failed: \(String(describing: error), privacy: .private)")
        errorMessage = "Couldn't update your reflection. Please try again."
    }

    /// Read-only facts for the exact selected civil week. Notes are never
    /// analyzed, and a failed refresh cannot leave an earlier week's results.
    private func loadProgress(asOf date: Date) {
        habitResults = []
        progressError = nil
        isCurrentWeek = selectedWeek.end > date
        guard let habits else { return }
        do {
            let range = DateInterval(start: selectedWeek.start, end: selectedWeek.end)
            let completions = try habits.completions(in: range)
            let skips = try habits.skips(in: range)
            for habit in try habits.fetchHabits(includeArchived: true) {
                let result = HabitProgressCalculator.consistency(
                    for: habit, snapshots: try habits.configurationHistory(for: habit.id),
                    completions: completions.filter { $0.habitID == habit.id },
                    skips: skips.filter { $0.habitID == habit.id },
                    archivePeriods: try habits.archivePeriods(for: habit.id),
                    in: range, asOf: date, calendar: calendar)
                guard result.scheduledUnits > 0 else { continue }
                habitResults.append(.init(habitID: habit.id, habitName: habit.name,
                    isArchived: habit.isArchived, successfulUnits: result.successfulUnits,
                    scheduledUnits: result.scheduledUnits))
            }
        } catch {
            habitResults = []
            progressError = "Couldn't load this week's progress. Your reflection is still available."
        }
    }
}
