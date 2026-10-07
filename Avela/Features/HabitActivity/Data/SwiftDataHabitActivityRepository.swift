import Foundation
import SwiftData

@MainActor
final class SwiftDataHabitActivityRepository: HabitActivityRepository {
    private let context: ModelContext
    private let habits: HabitRepository
    private let calendar: Calendar
    init(context: ModelContext, habits: HabitRepository, calendar: Calendar = .autoupdatingCurrent) {
        // A dedicated context keeps failed activity transactions from rolling
        // back unrelated drafts in the composition root's context.
        self.context = ModelContext(context.container)
        self.context.autosaveEnabled = false
        self.habits = habits; self.calendar = calendar
    }
    func configuration(for habitID: UUID, on date: Date) throws -> HabitActivityConfiguration? {
        let values = try context.fetch(FetchDescriptor<HabitActivityConfigurationRecord>(predicate: #Predicate { $0.habitID == habitID }))
        return .active(from: values.map(\.domain), dayKey: key(date))
    }
    func configure(habitID: UUID, target: HabitQuantityTarget?, smallerAction: String, at date: Date) throws {
        guard let habit = try habits.fetchHabit(id: habitID), !habit.isArchived else { throw HabitActivityError.unavailableDay }
        let action = smallerAction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard action.count <= 160 else { throw HabitActivityError.invalidTarget }
        if let target {
            guard habit.polarity == .positive, (1...10_000).contains(target.amount) else { throw HabitActivityError.invalidTarget }
            // Health's connected target owns its own interpretation. Avoid two
            // unrelated sources claiming success against different targets.
            let connected = try context.fetch(FetchDescriptor<HealthHabitConnectionRecord>()).contains { $0.habitID == habitID }
            guard !connected else { throw HabitActivityError.invalidTarget }
        }
        let values = try context.fetch(FetchDescriptor<HabitActivityConfigurationRecord>(predicate: #Predicate { $0.habitID == habitID }))
        let previous = try configuration(for: habitID, on: date)
        guard previous?.target != target || (previous?.smallerAction ?? "") != action else { return }
        try write {
            context.insert(HabitActivityConfigurationRecord(habitID: habitID, dayKey: key(date),
                revision: (values.map(\.revision).max() ?? -1) + 1, target: target, smallerAction: action))
        }
    }
    func entries(for habitID: UUID, on date: Date) throws -> [HabitActivityEntry] {
        let day = key(date)
        return try context.fetch(FetchDescriptor<HabitActivityEntryRecord>(predicate: #Predicate { $0.habitID == habitID && $0.dayKey == day }))
            .map(\.domain).sorted { $0.loggedAt < $1.loggedAt }
    }
    func entries(for habitID: UUID, in range: DateInterval) throws -> [HabitActivityEntry] {
        guard range.end > range.start else { return [] }
        let firstKey = key(range.start)
        let endDay = calendar.startOfDay(for: range.end)
        let exclusiveEnd = range.end == endDay ? endDay : (calendar.date(byAdding: .day, value: 1, to: endDay) ?? range.end)
        let endKey = key(exclusiveEnd)
        let rows = try context.fetch(FetchDescriptor<HabitActivityEntryRecord>(predicate: #Predicate {
            $0.habitID == habitID && $0.dayKey >= firstKey && $0.dayKey < endKey
        }))
        return rows.map(\.domain).sorted {
            if $0.dayKey != $1.dayKey { return $0.dayKey < $1.dayKey }
            if $0.loggedAt != $1.loggedAt { return $0.loggedAt < $1.loggedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
    func log(habitID: UUID, kind: HabitActivityKind, amount: Int, expectedConfigurationID: UUID, on date: Date, now: Date) throws {
        try validateDay(habitID: habitID, date: date, now: now)
        guard let config = try configuration(for: habitID, on: date), config.id == expectedConfigurationID else { throw HabitActivityError.staleConfiguration }
        if kind == .quantity {
            guard config.target != nil, (1...10_000).contains(amount) else { throw HabitActivityError.invalidAmount }
        } else {
            guard !config.smallerAction.isEmpty else { throw HabitActivityError.noSmallerAction }
            guard !(try entries(for: habitID, on: date)).contains(where: { $0.kind == .smallerAction }) else { return }
        }
        try write {
            context.insert(HabitActivityEntryRecord(habitID: habitID, configuration: config, dayKey: key(date), now: now,
                kind: kind, amount: kind == .quantity ? amount : 0))
            if kind == .quantity { try reconcileQuantity(habitID: habitID, date: date, configuration: config) }
        }
    }
    func removeEntry(id: UUID, now: Date) throws {
        guard let record = try context.fetch(FetchDescriptor<HabitActivityEntryRecord>(predicate: #Predicate { $0.id == id })).first,
              let date = date(for: record.dayKey) else { throw HabitActivityError.unavailableDay }
        try validateDay(habitID: record.habitID, date: date, now: now)
        let config = try configuration(for: record.habitID, on: date)
        let habitID = record.habitID
        try write {
            context.delete(record)
            if record.kindRaw == HabitActivityKind.quantity.rawValue, let config { try reconcileQuantity(habitID: habitID, date: date, configuration: config) }
        }
    }
    func correctionPreview(habitID: UUID, on date: Date) throws -> HabitCorrectionPreview {
        let day = key(date)
        return HabitCorrectionPreview(habitID: habitID, dayKey: day,
            completionIDs: Set(try completionRecords(habitID, day).map(\.id)),
            skipIDs: Set(try skipRecords(habitID, day).map(\.id)),
            activityConfigurationID: try configuration(for: habitID, on: date)?.id,
            scheduleConfigurationID: try habits.activeConfiguration(for: habitID, on: date)?.id)
    }
    func correct(_ preview: HabitCorrectionPreview, to outcome: HabitDayCorrection, on date: Date, now: Date) throws {
        try validateDay(habitID: preview.habitID, date: date, now: now)
        guard key(date) == preview.dayKey, try correctionPreview(habitID: preview.habitID, on: date) == preview else { throw HabitActivityError.staleCorrection }
        if outcome == .success, let target = try configuration(for: preview.habitID, on: date)?.target {
            let amount = try entries(for: preview.habitID, on: date).filter { $0.kind == .quantity && $0.unit == target.unit }.reduce(0) { $0 + $1.amount }
            guard amount >= target.amount else { throw HabitActivityError.invalidAmount }
        }
        let completions = try completionRecords(preview.habitID, preview.dayKey)
        let skips = try skipRecords(preview.habitID, preview.dayKey)
        try write {
            completions.forEach(context.delete); skips.forEach(context.delete)
            switch outcome {
            case .success:
                context.insert(CompletionRecord(domain: Completion(id: UUID(), habitID: preview.habitID, occurredAt: min(date, now),
                    localDateKey: preview.dayKey, source: try configuration(for: preview.habitID, on: date)?.target == nil ? .app : .quantity, note: "Explicit history correction")))
            case .skip:
                context.insert(SkipRecord(domain: Skip(id: UUID(), habitID: preview.habitID, localDateKey: preview.dayKey, reason: nil, createdAt: now)))
            case .clear: break
            }
        }
    }
    func timer(for habitID: UUID, on date: Date) throws -> HabitTimerState? {
        let state = try context.fetch(FetchDescriptor<HabitTimerRecord>(predicate: #Predicate { $0.habitID == habitID })).first?.domain
        return state?.dayKey == key(date) ? state : nil
    }
    func saveTimer(_ state: HabitTimerState, now: Date = Date()) throws {
        guard (0...86_400).contains(state.elapsedSeconds), let day = date(for: state.dayKey),
              let target = try configuration(for: state.habitID, on: day)?.target, target.unit == .minutes else { throw HabitActivityError.invalidTarget }
        try validateDay(habitID: state.habitID, date: day, now: now)
        guard key(now) == state.dayKey, state.startedAt == nil || state.startedAt! <= now else { throw HabitActivityError.unavailableDay }
        let habitID = state.habitID
        let existing = try context.fetch(FetchDescriptor<HabitTimerRecord>(predicate: #Predicate { $0.habitID == habitID })).first
        try write {
            if let existing { existing.dayKey = state.dayKey; existing.startedAt = state.startedAt; existing.elapsedSeconds = state.elapsedSeconds }
            else { context.insert(HabitTimerRecord(state)) }
        }
    }
    func resetTimer(for habitID: UUID) throws {
        let records = try context.fetch(FetchDescriptor<HabitTimerRecord>(predicate: #Predicate { $0.habitID == habitID }))
        try write { records.forEach(context.delete) }
    }
    func logTimer(habitID: UUID, now: Date) throws {
        try validateDay(habitID: habitID, date: now, now: now)
        guard let record = try context.fetch(FetchDescriptor<HabitTimerRecord>(predicate: #Predicate { $0.habitID == habitID })).first,
              record.dayKey == key(now), record.startedAt == nil, record.elapsedSeconds >= 60,
              let config = try configuration(for: habitID, on: now), config.target?.unit == .minutes else { throw HabitActivityError.invalidAmount }
        try write {
            context.insert(HabitActivityEntryRecord(habitID: habitID, configuration: config, dayKey: key(now), now: now,
                kind: .quantity, amount: record.elapsedSeconds / 60))
            try reconcileQuantity(habitID: habitID, date: now, configuration: config)
            context.delete(record)
        }
    }
    private func reconcileQuantity(habitID: UUID, date: Date, configuration: HabitActivityConfiguration) throws {
        guard let target = configuration.target else { return }
        let total = try entries(for: habitID, on: date).filter { $0.kind == .quantity && $0.unit == target.unit }.reduce(0) { $0 + $1.amount }
        let completions = try completionRecords(habitID, key(date))
        if total >= target.amount {
            if completions.isEmpty {
                let skips = try skipRecords(habitID, key(date)); skips.forEach(context.delete)
                context.insert(CompletionRecord(domain: Completion(id: UUID(), habitID: habitID, occurredAt: min(date, Date()),
                    localDateKey: key(date), source: .quantity, note: target.label)))
            }
        } else {
            // Withdraw only facts generated from quantity totals, never erase an
            // independently recorded historical check-in.
            completions.filter { $0.isQuantityDerived || $0.sourceRaw == CompletionSource.quantity.rawValue }.forEach(context.delete)
        }
    }
    private func validateDay(habitID: UUID, date: Date, now: Date) throws {
        guard let habit = try habits.fetchHabit(id: habitID), key(date) >= key(habit.createdAt), key(date) <= key(now),
              let config = try habits.activeConfiguration(for: habitID, on: date),
              HabitScheduleEvaluator.isDue(config.schedule, on: date, calendar: calendar) else { throw HabitActivityError.unavailableDay }
        let day = key(date)
        for pause in try habits.archivePeriods(for: habitID) {
            if day >= key(pause.archivedAt) && (pause.reactivatedAt == nil || day < key(pause.reactivatedAt!)) { throw HabitActivityError.unavailableDay }
        }
        if habit.isArchived && day >= key(habit.archivedAt!) { throw HabitActivityError.unavailableDay }
    }
    private func completionRecords(_ habitID: UUID, _ day: String) throws -> [CompletionRecord] {
        try context.fetch(FetchDescriptor<CompletionRecord>(predicate: #Predicate { $0.habitID == habitID && $0.localDateKey == day }))
    }
    private func skipRecords(_ habitID: UUID, _ day: String) throws -> [SkipRecord] {
        try context.fetch(FetchDescriptor<SkipRecord>(predicate: #Predicate { $0.habitID == habitID && $0.localDateKey == day }))
    }
    private func key(_ date: Date) -> String { LocalDay.key(for: date, calendar: calendar) }
    private func date(for key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        return gregorian.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }
    private func write(_ changes: () throws -> Void) throws {
        do { try changes(); try context.save() }
        catch { context.rollback(); throw error }
        NotificationCenter.default.post(name: .avelaPersistenceDidChange, object: nil)
    }
}
