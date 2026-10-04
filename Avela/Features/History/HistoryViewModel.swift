import Foundation
import OSLog
import Observation

/// One completion or skip, shaped for display. Pure data — the view only
/// renders these fields; `HistoryViewModel` is the only place that composes
/// `HabitRepository` reads with `HabitScheduleEvaluator` for historical
/// schedule context.
struct HistoryRow: Identifiable, Equatable {
    let id: UUID
    let habitID: UUID
    let habitName: String
    let habitIconName: String
    let isHabitArchived: Bool
    /// The schedule as it was configured on this record's local day —
    /// resolved from historical configuration, never the habit's current
    /// schedule. See `HabitScheduleEvaluator.activeConfiguration(from:onKey:)`.
    let scheduleContextLabel: String
    let kindLabel: String
    let kindSymbolName: String
    /// For a completion, the time of day it was logged. For a skip, the
    /// reason text if one was given — never a time, since a skip's
    /// `createdAt` is when the record was written, not a precise moment the
    /// habit was "skipped."
    let detailText: String?
}

/// One local day's worth of history rows, keyed by the *stored*
/// `localDateKey` of its records — never recomputed from `occurredAt` under
/// whatever calendar/time zone happens to be current, so a day's grouping
/// cannot move after the fact.
struct HistoryDaySection: Identifiable, Equatable {
    let id: String
    let dateLabel: String
    let rows: [HistoryRow]
}

struct HistoryHabitOption: Identifiable, Equatable, Hashable {
    let id: UUID
    let label: String
}

/// Feature state for the read-only History screen. Fetches once per load —
/// one habits fetch, one cross-habit completions fetch, one cross-habit skips
/// fetch, and one configuration-history fetch per *distinct* habit referenced
/// by those records (not per row) — and shapes the result for display. Never
/// mutates anything.
@MainActor
@Observable
final class HistoryViewModel {
    private(set) var sections: [HistoryDaySection] = []
    private(set) var habitOptions: [HistoryHabitOption] = []
    var selectedHabitID: UUID?
    var errorMessage: String?

    let rangeLabel = "Last 30 Days"
    private static let rangeLengthInDays = 30

    private let repository: HabitRepository
    private let attentionRepository: AttentionRepository?
    private let calendar: Calendar
    private static let logger = Logger(subsystem: "com.example.Avela", category: "HistoryViewModel")
    private static let friendlyErrorMessage = "Something went wrong. Please try again."

    init(repository: HabitRepository, attentionRepository: AttentionRepository? = nil, calendar: Calendar = .autoupdatingCurrent) {
        self.repository = repository
        self.attentionRepository = attentionRepository
        self.calendar = calendar
    }

    func load(asOf date: Date = Date()) {
        do {
            let habits = try repository.fetchHabits(includeArchived: true)
            let habitsByID = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })
            habitOptions = habits
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .map { HistoryHabitOption(id: $0.id, label: $0.isArchived ? "\($0.name) (Archived)" : $0.name) }
            if let selectedHabitID, habitsByID[selectedHabitID] == nil {
                self.selectedHabitID = nil
            }

            let dayStart = calendar.startOfDay(for: date)
            let rangeStart = calendar.date(
                byAdding: .day, value: -(Self.rangeLengthInDays - 1), to: dayStart
            ) ?? dayStart
            let rangeEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
            let range = DateInterval(start: rangeStart, end: rangeEnd)

            var completions = try repository.completions(in: range)
            var skips = try repository.skips(in: range)
            if let selectedHabitID = self.selectedHabitID {
                completions = completions.filter { $0.habitID == selectedHabitID }
                skips = skips.filter { $0.habitID == selectedHabitID }
            }

            let relevantHabitIDs = Set(completions.map(\.habitID)).union(skips.map(\.habitID))
            var historiesByHabitID: [UUID: [HabitConfigurationSnapshot]] = [:]
            for habitID in relevantHabitIDs {
                historiesByHabitID[habitID] = try repository.configurationHistory(for: habitID)
            }

            var entries: [(localDateKey: String, row: HistoryRow, sortDate: Date)] = []

            for completion in completions {
                guard let habit = habitsByID[completion.habitID] else { continue }
                entries.append((
                    localDateKey: completion.localDateKey,
                    row: HistoryRow(
                        id: completion.id,
                        habitID: habit.id,
                        habitName: habit.name,
                        habitIconName: habit.iconName,
                        isHabitArchived: habit.isArchived,
                        scheduleContextLabel: Self.scheduleContextLabel(
                            habitID: habit.id, key: completion.localDateKey, historiesByHabitID: historiesByHabitID
                        ),
                        kindLabel: "Completed",
                        kindSymbolName: "checkmark.circle.fill",
                        detailText: Self.timeOfDayText(completion.occurredAt, calendar: calendar)
                    ),
                    sortDate: completion.occurredAt
                ))
            }

            for skip in skips {
                guard let habit = habitsByID[skip.habitID] else { continue }
                entries.append((
                    localDateKey: skip.localDateKey,
                    row: HistoryRow(
                        id: skip.id,
                        habitID: habit.id,
                        habitName: habit.name,
                        habitIconName: habit.iconName,
                        isHabitArchived: habit.isArchived,
                        scheduleContextLabel: Self.scheduleContextLabel(
                            habitID: habit.id, key: skip.localDateKey, historiesByHabitID: historiesByHabitID
                        ),
                        kindLabel: "Skipped",
                        kindSymbolName: "arrow.uturn.forward.circle.fill",
                        detailText: skip.reason.map { $0.rawValue.capitalized }
                    ),
                    // createdAt only orders same-day entries deterministically;
                    // it is never shown as "the time this was skipped."
                    sortDate: skip.createdAt
                ))
            }

            // A selected habit remains a habit-only filter. Unfiltered History
            // includes manual attention records, grouped by their persisted day.
            if selectedHabitID == nil, let attentionRepository {
                let goals = try attentionRepository.fetchGoals()
                let goalsByID = Dictionary(uniqueKeysWithValues: goals.map { ($0.id, $0) })
                let usage = try attentionRepository.usageEntries(in: range)
                var histories: [UUID: [AttentionGoalConfigurationSnapshot]] = [:]
                for goalID in Set(usage.map(\.attentionGoalID)) {
                    histories[goalID] = try attentionRepository.configurationHistory(for: goalID)
                }
                for entry in usage {
                    guard let goal = goalsByID[entry.attentionGoalID] else { continue }
                    let snapshot = AttentionGoalEvaluator.activeConfiguration(
                        from: histories[goal.id] ?? [], onKey: entry.localDateKey
                    )
                    let budget = snapshot.map {
                        AttentionStatusFormatter.targetLabel(targetValue: $0.targetValue, unit: $0.unit)
                    } ?? ""
                    entries.append((entry.localDateKey, HistoryRow(
                        id: entry.id, habitID: goal.id, habitName: goal.name,
                        habitIconName: "hourglass", isHabitArchived: false,
                        scheduleContextLabel: budget, kindLabel: "Usage logged",
                        kindSymbolName: "hourglass.circle.fill",
                        detailText: "\(entry.amount.formatted()) min logged manually · \(Self.timeOfDayText(entry.recordedAt, calendar: calendar))"
                    ), entry.recordedAt))
                }
            }

            let grouped = Dictionary(grouping: entries, by: \.localDateKey)
            errorMessage = nil
            sections = grouped.keys.sorted(by: >).map { key in
                let dayEntries = grouped[key] ?? []
                let orderedRows = dayEntries.sorted { lhs, rhs in
                    let nameOrder = lhs.row.habitName.localizedCaseInsensitiveCompare(rhs.row.habitName)
                    if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
                    if lhs.row.kindLabel != rhs.row.kindLabel { return lhs.row.kindLabel < rhs.row.kindLabel }
                    return lhs.sortDate < rhs.sortDate
                }.map(\.row)
                return HistoryDaySection(id: key, dateLabel: Self.dateLabel(for: key), rows: orderedRows)
            }
        } catch {
            handle(error)
        }
    }

    private func handle(_ error: Error) {
        Self.logger.error("History view model operation failed: \(String(describing: error), privacy: .private)")
        errorMessage = Self.friendlyErrorMessage
    }

    private static func scheduleContextLabel(
        habitID: UUID, key: String, historiesByHabitID: [UUID: [HabitConfigurationSnapshot]]
    ) -> String {
        guard let history = historiesByHabitID[habitID],
              let configuration = HabitScheduleEvaluator.activeConfiguration(from: history, onKey: key)
        else {
            return ""
        }
        return HabitScheduleFormatter.description(for: configuration.schedule)
    }

    private static func timeOfDayText(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }

    /// Formats a stored `yyyy-MM-dd` key for display. Both the parser and the
    /// formatter are pinned to a fixed (UTC) time zone so the key is treated
    /// purely as calendar digits, never reinterpreted as an instant that could
    /// shift to an adjacent day under a different zone.
    private static func dateLabel(for key: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.calendar = Calendar(identifier: .gregorian)
        parser.dateFormat = "yyyy-MM-dd"
        parser.timeZone = TimeZone(identifier: "UTC")
        guard let date = parser.date(from: key) else { return key }

        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
}
