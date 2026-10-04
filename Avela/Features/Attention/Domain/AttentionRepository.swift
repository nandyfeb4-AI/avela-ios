import Foundation

enum AttentionRepositoryError: Error, Equatable {
    case sessionNotFound(UUID)
    case sessionAlreadyActive
    case invalidCheckIn
    case goalNotFound(UUID)
    case usageEntryNotFound(UUID)
    case invalidGoal
    case invalidAmount
}

/// Domain-facing persistence boundary for attention goals, their budget
/// history, and usage entries. UI and higher-level services depend on this
/// protocol, never on SwiftData directly (ARCHITECTURE.md). Main-actor
/// isolated to match the local store's context and serialize configuration
/// revision assignment with each write, mirroring `HabitRepository`.
@MainActor
protocol AttentionRepository {
    func fetchGoals() throws -> [AttentionGoal]
    func fetchGoal(id: UUID) throws -> AttentionGoal?

    @discardableResult
    func createGoal(_ draft: AttentionGoalDraft, at date: Date) throws -> AttentionGoal

    /// Updates a goal's fields. If `draft.targetValue` or `draft.unit` differ
    /// from the goal's current budget, a new
    /// `AttentionGoalConfigurationSnapshot` is appended effective `date`;
    /// prior snapshots, and any history computed from them, are left
    /// untouched.
    @discardableResult
    func updateGoal(id: UUID, with draft: AttentionGoalDraft, at date: Date) throws -> AttentionGoal

    /// All budget snapshots for a goal, ordered oldest to newest.
    func configurationHistory(for goalID: UUID) throws -> [AttentionGoalConfigurationSnapshot]

    /// The snapshot that was in effect on `date`'s local calendar day.
    func activeConfiguration(for goalID: UUID, on date: Date) throws -> AttentionGoalConfigurationSnapshot?

    @discardableResult
    func recordUsage(
        goalID: UUID,
        amount: Double,
        at date: Date,
        source: AttentionUsageSource
    ) throws -> AttentionUsageEntry

    /// Corrects an existing entry's amount in place. Scope is deliberately
    /// limited to callers correcting today's own entries (enforced by the UI
    /// layer, not here) — mirroring how habit completions can only be
    /// toggled for today; historical entries are read-only via History.
    @discardableResult
    func updateUsageEntry(id: UUID, amount: Double) throws -> AttentionUsageEntry

    func deleteUsageEntry(id: UUID) throws

    func usageEntries(for goalID: UUID, in interval: DateInterval) throws -> [AttentionUsageEntry]

    /// Every usage entry across every goal whose `recordedAt` falls in
    /// `interval`. For History, which shows records from many goals at once;
    /// prefer `usageEntries(for:in:)` when only one goal's records are
    /// needed.
    func usageEntries(in interval: DateInterval) throws -> [AttentionUsageEntry]
    func checkIns(for goalID: UUID, in interval: DateInterval) throws -> [AttentionCheckIn]
    @discardableResult
    func recordCheckIn(goalID: UUID, on day: Date, outcome: AttentionCheckInOutcome, at date: Date) throws -> AttentionCheckIn
    func sessions(for goalID: UUID) throws -> [AttentionSession]
    @discardableResult
    func startSession(goalID: UUID, at date: Date) throws -> AttentionSession
    @discardableResult
    func finishSession(id: UUID, outcome: AttentionCheckInOutcome, at date: Date) throws -> AttentionSession

}
