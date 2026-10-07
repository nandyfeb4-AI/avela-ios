import Foundation
import SwiftData

/// SwiftData implementation of `AttentionRepository`. Owns budget-change
/// detection that appends `AttentionGoalConfigurationSnapshotRecord` rows,
/// and owns local-day-key computation for usage entries, so every other
/// layer can stay ignorant of both SwiftData and calendar math, mirroring
/// `SwiftDataHabitRepository`.
@MainActor
final class SwiftDataAttentionRepository: AttentionRepository {
    private let modelContext: ModelContext
    private let calendar: Calendar

    init(modelContext: ModelContext, calendar: Calendar = .autoupdatingCurrent) {
        self.modelContext = modelContext
        self.calendar = calendar
    }

    func fetchGoals() throws -> [AttentionGoal] {
        let descriptor = FetchDescriptor<AttentionGoalRecord>(sortBy: [SortDescriptor(\.createdAt)])
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    func fetchGoal(id: UUID) throws -> AttentionGoal? {
        try goalRecord(id: id)?.toDomain()
    }

    @discardableResult
    func createGoal(_ draft: AttentionGoalDraft, at date: Date = Date()) throws -> AttentionGoal {
        try validate(draft)
        let record = AttentionGoalRecord(domain: AttentionGoal(
            id: UUID(),
            name: draft.name,
            appOrCategoryLabel: draft.appOrCategoryLabel,
            type: draft.type,
            createdAt: date,
            updatedAt: date
        ))
        modelContext.insert(record)
        modelContext.insert(AttentionGoalConfigurationSnapshotRecord(domain: AttentionGoalConfigurationSnapshot(
            id: UUID(),
            attentionGoalID: record.id,
            targetValue: draft.targetValue,
            unit: draft.unit,
            effectiveLocalDateKey: LocalDay.key(for: date, calendar: calendar),
            revision: try nextConfigurationRevision(for: record.id),
            createdAt: date,
            windowStartMinute: draft.windowStartMinute, windowEndMinute: draft.windowEndMinute
        )))
        try modelContext.save()
        NotificationCenter.default.post(name: .avelaPersistenceDidChange, object: nil)
        return record.toDomain()
    }

    @discardableResult
    func updateGoal(id: UUID, with draft: AttentionGoalDraft, at date: Date = Date()) throws -> AttentionGoal {
        try validate(draft)
        guard let record = try goalRecord(id: id) else {
            throw AttentionRepositoryError.goalNotFound(id)
        }
        guard record.toDomain().type == draft.type else { throw AttentionRepositoryError.invalidGoal }
        let currentConfiguration = try activeConfiguration(for: id, on: date)
        let budgetChanged = currentConfiguration?.targetValue != draft.targetValue
            || currentConfiguration?.unit != draft.unit
            || currentConfiguration?.windowStartMinute != draft.windowStartMinute
            || currentConfiguration?.windowEndMinute != draft.windowEndMinute
        record.apply(draft: draft, updatedAt: date)
        if budgetChanged {
            modelContext.insert(AttentionGoalConfigurationSnapshotRecord(domain: AttentionGoalConfigurationSnapshot(
                id: UUID(),
                attentionGoalID: id,
                targetValue: draft.targetValue,
                unit: draft.unit,
                effectiveLocalDateKey: LocalDay.key(for: date, calendar: calendar),
                revision: try nextConfigurationRevision(for: id),
                createdAt: date,
                windowStartMinute: draft.windowStartMinute, windowEndMinute: draft.windowEndMinute
            )))
        }
        try modelContext.save()
        NotificationCenter.default.post(name: .avelaPersistenceDidChange, object: nil)
        return record.toDomain()
    }

    func configurationHistory(for goalID: UUID) throws -> [AttentionGoalConfigurationSnapshot] {
        let descriptor = FetchDescriptor<AttentionGoalConfigurationSnapshotRecord>(
            predicate: #Predicate { $0.attentionGoalID == goalID }
        )
        // Sort by (effectiveLocalDateKey, revision): see
        // SwiftDataHabitRepository.configurationHistory for why `revision`,
        // not `createdAt`, breaks same-day ties.
        return try modelContext.fetch(descriptor)
            .map { $0.toDomain() }
            .sorted {
                $0.effectiveLocalDateKey != $1.effectiveLocalDateKey
                    ? $0.effectiveLocalDateKey < $1.effectiveLocalDateKey
                    : $0.revision < $1.revision
            }
    }

    func activeConfiguration(for goalID: UUID, on date: Date) throws -> AttentionGoalConfigurationSnapshot? {
        let history = try configurationHistory(for: goalID)
        return AttentionGoalEvaluator.activeConfiguration(from: history, on: date, calendar: calendar)
    }

    @discardableResult
    func recordUsage(
        goalID: UUID,
        amount: Double,
        at date: Date = Date(),
        source: AttentionUsageSource
    ) throws -> AttentionUsageEntry {
        try validateAmount(amount)
        guard let configuration = try activeConfiguration(for: goalID, on: date) else {
            throw AttentionRepositoryError.goalNotFound(goalID)
        }
        guard try fetchGoal(id: goalID)?.type == .maxDurationPerDay else { throw AttentionRepositoryError.invalidGoal }
        let record = AttentionUsageEntryRecord(domain: AttentionUsageEntry(
            id: UUID(),
            attentionGoalID: goalID,
            amount: amount,
            unit: configuration.unit,
            recordedAt: date,
            localDateKey: LocalDay.key(for: date, calendar: calendar),
            source: source
        ))
        modelContext.insert(record)
        try modelContext.save()
        NotificationCenter.default.post(name: .avelaPersistenceDidChange, object: nil)
        return record.toDomain()
    }

    @discardableResult
    func updateUsageEntry(id: UUID, amount: Double) throws -> AttentionUsageEntry {
        try validateAmount(amount)
        guard let record = try usageEntryRecord(id: id) else {
            throw AttentionRepositoryError.usageEntryNotFound(id)
        }
        record.amount = amount
        try modelContext.save()
        NotificationCenter.default.post(name: .avelaPersistenceDidChange, object: nil)
        return record.toDomain()
    }

    func deleteUsageEntry(id: UUID) throws {
        guard let record = try usageEntryRecord(id: id) else {
            throw AttentionRepositoryError.usageEntryNotFound(id)
        }
        modelContext.delete(record)
        try modelContext.save()
        NotificationCenter.default.post(name: .avelaPersistenceDidChange, object: nil)
    }

    func usageEntries(for goalID: UUID, in interval: DateInterval) throws -> [AttentionUsageEntry] {
        let descriptor = FetchDescriptor<AttentionUsageEntryRecord>(
            predicate: #Predicate { $0.attentionGoalID == goalID }
        )
        return try modelContext.fetch(descriptor)
            .map { $0.toDomain() }
            .filter { $0.recordedAt >= interval.start && $0.recordedAt < interval.end }
    }

    func usageEntries(in interval: DateInterval) throws -> [AttentionUsageEntry] {
        try modelContext.fetch(FetchDescriptor<AttentionUsageEntryRecord>())
            .map { $0.toDomain() }
            .filter { $0.recordedAt >= interval.start && $0.recordedAt < interval.end }
    }


    func checkIns(for goalID: UUID, in interval: DateInterval) throws -> [AttentionCheckIn] {
        let descriptor = FetchDescriptor<AttentionCheckInRecord>(predicate: #Predicate { $0.attentionGoalID == goalID })
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
            .filter { $0.windowStart >= interval.start && $0.windowStart < interval.end }
            .sorted { $0.revision < $1.revision }
    }

    @discardableResult
    func recordCheckIn(goalID: UUID, on day: Date, outcome: AttentionCheckInOutcome, at date: Date) throws -> AttentionCheckIn {
        guard let goal = try fetchGoal(id: goalID), goal.type == .noUseBeforeTime || goal.type == .phoneFreeUntilTime,
              let snapshot = try activeConfiguration(for: goalID, on: day),
              let start = snapshot.windowStartMinute, let end = snapshot.windowEndMinute,
              let window = AttentionWindowCalculator.interval(on: day, startMinute: start, endMinute: end, calendar: calendar),
              window.start <= date, outcome == .interrupted || window.end <= date,
              day >= calendar.startOfDay(for: goal.createdAt) else { throw AttentionRepositoryError.invalidCheckIn }
        let descriptor = FetchDescriptor<AttentionCheckInRecord>(predicate: #Predicate { $0.attentionGoalID == goalID })
        let revision = (try modelContext.fetch(descriptor).map(\.revision).max() ?? -1) + 1
        let value = AttentionCheckIn(id: UUID(), attentionGoalID: goalID,
            localDateKey: LocalDay.key(for: day, calendar: calendar), windowStart: window.start, windowEnd: window.end,
            outcome: outcome, recordedAt: date, revision: revision)
        modelContext.insert(AttentionCheckInRecord(domain: value))
        try modelContext.save()
        NotificationCenter.default.post(name: .avelaPersistenceDidChange, object: nil)
        return value
    }

    func sessions(for goalID: UUID) throws -> [AttentionSession] {
        let descriptor = FetchDescriptor<AttentionSessionRecord>(predicate: #Predicate { $0.attentionGoalID == goalID })
        return try modelContext.fetch(descriptor).map { $0.toDomain() }.sorted { $0.startedAt < $1.startedAt }
    }

    @discardableResult
    func startSession(goalID: UUID, at date: Date) throws -> AttentionSession {
        guard try fetchGoal(id: goalID)?.type.isTimedSession == true,
              let snapshot = try activeConfiguration(for: goalID, on: date),
              (snapshot.targetValue * 60).isFinite else { throw AttentionRepositoryError.invalidGoal }
        guard try sessions(for: goalID).allSatisfy({ !$0.isActive }) else { throw AttentionRepositoryError.sessionAlreadyActive }
        let value = AttentionSession(id: UUID(), attentionGoalID: goalID, startedAt: date,
            expectedEnd: date.addingTimeInterval(snapshot.targetValue * 60), targetMinutes: snapshot.targetValue,
            endedAt: nil, outcome: nil)
        modelContext.insert(AttentionSessionRecord(domain: value))
        try modelContext.save()
        NotificationCenter.default.post(name: .avelaPersistenceDidChange, object: nil)
        return value
    }

    @discardableResult
    func finishSession(id: UUID, outcome: AttentionCheckInOutcome, at date: Date) throws -> AttentionSession {
        var descriptor = FetchDescriptor<AttentionSessionRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let record = try modelContext.fetch(descriptor).first else { throw AttentionRepositoryError.sessionNotFound(id) }
        guard record.endedAt == nil, date >= record.startedAt,
              outcome == .interrupted || date >= record.expectedEnd else { throw AttentionRepositoryError.invalidCheckIn }
        record.endedAt = date
        record.outcomeRaw = outcome.rawValue
        try modelContext.save()
        NotificationCenter.default.post(name: .avelaPersistenceDidChange, object: nil)
        return record.toDomain()
    }

    private func validate(_ draft: AttentionGoalDraft) throws {
        guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              draft.targetValue.isFinite, draft.targetValue > 0, draft.targetValue <= 1440 else {
            throw AttentionRepositoryError.invalidGoal
        }
        if draft.type == .noUseBeforeTime || draft.type == .phoneFreeUntilTime {
            guard let start = draft.windowStartMinute, let end = draft.windowEndMinute,
                  (0..<1440).contains(start), (0..<1440).contains(end), start != end else {
                throw AttentionRepositoryError.invalidGoal
            }
        }
    }

    private func validateAmount(_ amount: Double) throws {
        guard amount.isFinite, amount >= 0, amount <= 1440 else { throw AttentionRepositoryError.invalidAmount }
    }

    private func goalRecord(id: UUID) throws -> AttentionGoalRecord? {
        var descriptor = FetchDescriptor<AttentionGoalRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func usageEntryRecord(id: UUID) throws -> AttentionUsageEntryRecord? {
        var descriptor = FetchDescriptor<AttentionUsageEntryRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func nextConfigurationRevision(for goalID: UUID) throws -> Int {
        let descriptor = FetchDescriptor<AttentionGoalConfigurationSnapshotRecord>(
            predicate: #Predicate { $0.attentionGoalID == goalID }
        )
        let existing = try modelContext.fetch(descriptor)
        return (existing.map(\.revision).max() ?? -1) + 1
    }
}
