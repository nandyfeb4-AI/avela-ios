import Foundation
import SwiftData

/// SwiftData implementation of `HabitRepository`. Owns schedule-change detection
/// that appends `HabitConfigurationSnapshotRecord` rows, and owns local-day-key
/// computation for completions and skips, so every other layer can stay ignorant
/// of both SwiftData and calendar math.
@MainActor
final class SwiftDataHabitRepository: HabitRepository {
    private let modelContext: ModelContext
    private let calendar: Calendar

    init(modelContext: ModelContext, calendar: Calendar = .autoupdatingCurrent) {
        self.modelContext = modelContext
        self.calendar = calendar
    }

    func fetchHabits(includeArchived: Bool) throws -> [Habit] {
        let descriptor = FetchDescriptor<HabitRecord>(sortBy: [SortDescriptor(\.sortOrder)])
        return try modelContext.fetch(descriptor)
            .filter { includeArchived || $0.archivedAt == nil }
            .map { $0.toDomain() }
    }

    func fetchHabit(id: UUID) throws -> Habit? {
        try habitRecord(id: id)?.toDomain()
    }

    @discardableResult
    func createHabit(_ draft: HabitDraft, at date: Date = Date()) throws -> Habit {
        try validate(draft.schedule)
        let record = HabitRecord(domain: Habit(
            id: UUID(),
            name: draft.name,
            iconName: draft.iconName,
            category: draft.category,
            polarity: draft.polarity,
            schedule: draft.schedule,
            createdAt: date,
            updatedAt: date,
            archivedAt: nil,
            sortOrder: try nextSortOrder()
        ))
        modelContext.insert(record)
        modelContext.insert(HabitConfigurationSnapshotRecord(domain: HabitConfigurationSnapshot(
            id: UUID(),
            habitID: record.id,
            polarity: draft.polarity,
            schedule: draft.schedule,
            effectiveLocalDateKey: LocalDay.key(for: date, calendar: calendar),
            revision: try nextConfigurationRevision(for: record.id),
            createdAt: date
        )))
        try modelContext.save()
        NotificationCenter.default.post(name: .avelaPersistenceDidChange, object: nil)
        return record.toDomain()
    }

    @discardableResult
    func updateHabit(id: UUID, with draft: HabitDraft, at date: Date = Date()) throws -> Habit {
        try validate(draft.schedule)
        guard let record = try habitRecord(id: id) else {
            throw HabitRepositoryError.habitNotFound(id)
        }
        let configurationChanged = record.currentSchedule != draft.schedule
            || record.currentPolarity != draft.polarity
        record.apply(draft: draft, updatedAt: date)
        if configurationChanged {
            modelContext.insert(HabitConfigurationSnapshotRecord(domain: HabitConfigurationSnapshot(
                id: UUID(),
                habitID: id,
                polarity: draft.polarity,
                schedule: draft.schedule,
                effectiveLocalDateKey: LocalDay.key(for: date, calendar: calendar),
                revision: try nextConfigurationRevision(for: id),
                createdAt: date
            )))
        }
        try modelContext.save()
        NotificationCenter.default.post(name: .avelaPersistenceDidChange, object: nil)
        return record.toDomain()
    }

    func archiveHabit(id: UUID, at date: Date = Date()) throws {
        guard let record = try habitRecord(id: id) else {
            throw HabitRepositoryError.habitNotFound(id)
        }
        // Idempotent: archiving an already-archived habit must not open a
        // second period, which would leave two open periods and make
        // reactivation ambiguous about which one to close.
        if record.archivedAt == nil {
            modelContext.insert(HabitArchivePeriodRecord(domain: HabitArchivePeriod(
                id: UUID(), habitID: id, archivedAt: date, reactivatedAt: nil
            )))
        }
        record.archivedAt = date
        record.updatedAt = date
        try modelContext.save()
        NotificationCenter.default.post(name: .avelaPersistenceDidChange, object: nil)
    }

    func reactivateHabit(id: UUID, at date: Date = Date()) throws {
        guard let record = try habitRecord(id: id) else {
            throw HabitRepositoryError.habitNotFound(id)
        }
        if let openPeriod = try openArchivePeriodRecord(for: id) {
            openPeriod.reactivatedAt = date
        }
        record.archivedAt = nil
        record.updatedAt = date
        try modelContext.save()
        NotificationCenter.default.post(name: .avelaPersistenceDidChange, object: nil)
    }

    func archivePeriods(for habitID: UUID) throws -> [HabitArchivePeriod] {
        let descriptor = FetchDescriptor<HabitArchivePeriodRecord>(predicate: #Predicate { $0.habitID == habitID })
        return try modelContext.fetch(descriptor)
            .map { $0.toDomain() }
            .sorted { $0.archivedAt < $1.archivedAt }
    }

    func configurationHistory(for habitID: UUID) throws -> [HabitConfigurationSnapshot] {
        let descriptor = FetchDescriptor<HabitConfigurationSnapshotRecord>(
            predicate: #Predicate { $0.habitID == habitID }
        )
        // Sort by (effectiveLocalDateKey, revision): SwiftData's fetch order is not
        // guaranteed to match insertion order, and multiple edits on the same local
        // day share an effectiveLocalDateKey. `revision` (not `createdAt`) breaks
        // that tie because `createdAt` can collide — e.g. two edits made from a
        // single captured `Date()` — whereas `revision` is a persisted, strictly
        // increasing per-habit counter that cannot.
        return try modelContext.fetch(descriptor)
            .map { $0.toDomain() }
            .sorted {
                $0.effectiveLocalDateKey != $1.effectiveLocalDateKey
                    ? $0.effectiveLocalDateKey < $1.effectiveLocalDateKey
                    : $0.revision < $1.revision
            }
    }

    func activeConfiguration(for habitID: UUID, on date: Date) throws -> HabitConfigurationSnapshot? {
        let history = try configurationHistory(for: habitID)
        return HabitScheduleEvaluator.activeConfiguration(from: history, on: date, calendar: calendar)
    }

    @discardableResult
    func recordCompletion(
        habitID: UUID,
        at date: Date = Date(),
        source: CompletionSource,
        note: String? = nil
    ) throws -> Completion {
        guard try habitRecord(id: habitID) != nil else {
            throw HabitRepositoryError.habitNotFound(habitID)
        }
        let record = CompletionRecord(domain: Completion(
            id: UUID(),
            habitID: habitID,
            occurredAt: date,
            localDateKey: LocalDay.key(for: date, calendar: calendar),
            source: source,
            note: note
        ))
        modelContext.insert(record)
        try modelContext.save()
        NotificationCenter.default.post(name: .avelaPersistenceDidChange, object: nil)
        return record.toDomain()
    }

    func undoCompletion(id: UUID) throws {
        var descriptor = FetchDescriptor<CompletionRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let record = try modelContext.fetch(descriptor).first else {
            throw HabitRepositoryError.completionNotFound(id)
        }
        modelContext.delete(record)
        try modelContext.save()
        NotificationCenter.default.post(name: .avelaPersistenceDidChange, object: nil)
    }

    func completions(for habitID: UUID, in interval: DateInterval) throws -> [Completion] {
        let descriptor = FetchDescriptor<CompletionRecord>(predicate: #Predicate { $0.habitID == habitID })
        return try modelContext.fetch(descriptor)
            .map { $0.toDomain() }
            .filter { $0.occurredAt >= interval.start && $0.occurredAt < interval.end }
    }

    func completions(in interval: DateInterval) throws -> [Completion] {
        try modelContext.fetch(FetchDescriptor<CompletionRecord>())
            .map { $0.toDomain() }
            .filter { $0.occurredAt >= interval.start && $0.occurredAt < interval.end }
    }

    @discardableResult
    func recordSkip(habitID: UUID, on date: Date = Date(), reason: SkipReason? = nil) throws -> Skip {
        guard try habitRecord(id: habitID) != nil else {
            throw HabitRepositoryError.habitNotFound(habitID)
        }
        let record = SkipRecord(domain: Skip(
            id: UUID(),
            habitID: habitID,
            localDateKey: LocalDay.key(for: date, calendar: calendar),
            reason: reason,
            createdAt: date
        ))
        modelContext.insert(record)
        try modelContext.save()
        NotificationCenter.default.post(name: .avelaPersistenceDidChange, object: nil)
        return record.toDomain()
    }

    func undoSkip(id: UUID) throws {
        var descriptor = FetchDescriptor<SkipRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let record = try modelContext.fetch(descriptor).first else {
            throw HabitRepositoryError.skipNotFound(id)
        }
        modelContext.delete(record)
        try modelContext.save()
        NotificationCenter.default.post(name: .avelaPersistenceDidChange, object: nil)
    }

    func skips(for habitID: UUID, in interval: DateInterval) throws -> [Skip] {
        // Skips only carry a local-day key, not a precise instant, so interval
        // membership is decided by comparing day keys rather than timestamps.
        let startKey = LocalDay.key(for: interval.start, calendar: calendar)
        let lastMomentKey = LocalDay.key(for: interval.end.addingTimeInterval(-1), calendar: calendar)
        let descriptor = FetchDescriptor<SkipRecord>(predicate: #Predicate { $0.habitID == habitID })
        return try modelContext.fetch(descriptor)
            .map { $0.toDomain() }
            .filter { $0.localDateKey >= startKey && $0.localDateKey <= lastMomentKey }
    }

    func skips(in interval: DateInterval) throws -> [Skip] {
        let startKey = LocalDay.key(for: interval.start, calendar: calendar)
        let lastMomentKey = LocalDay.key(for: interval.end.addingTimeInterval(-1), calendar: calendar)
        return try modelContext.fetch(FetchDescriptor<SkipRecord>())
            .map { $0.toDomain() }
            .filter { $0.localDateKey >= startKey && $0.localDateKey <= lastMomentKey }
    }

    private func habitRecord(id: UUID) throws -> HabitRecord? {
        var descriptor = FetchDescriptor<HabitRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func nextSortOrder() throws -> Int {
        let existing = try modelContext.fetch(FetchDescriptor<HabitRecord>())
        return (existing.map(\.sortOrder).max() ?? -1) + 1
    }

    private func openArchivePeriodRecord(for habitID: UUID) throws -> HabitArchivePeriodRecord? {
        let descriptor = FetchDescriptor<HabitArchivePeriodRecord>(
            predicate: #Predicate { $0.habitID == habitID && $0.reactivatedAt == nil }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func nextConfigurationRevision(for habitID: UUID) throws -> Int {
        let descriptor = FetchDescriptor<HabitConfigurationSnapshotRecord>(
            predicate: #Predicate { $0.habitID == habitID }
        )
        let existing = try modelContext.fetch(descriptor)
        return (existing.map(\.revision).max() ?? -1) + 1
    }

    private func validate(_ schedule: HabitSchedule) throws {
        switch schedule {
        case .daily:
            break
        case .weekdays(let days):
            if days.isEmpty { throw HabitRepositoryError.invalidSchedule }
        case .timesPerWeek(let count):
            if count < 1 || count > 7 { throw HabitRepositoryError.invalidSchedule }
        }
    }
}
