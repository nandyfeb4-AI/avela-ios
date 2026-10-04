import Foundation

enum HabitRepositoryError: Error, Equatable {
    case habitNotFound(UUID)
    case completionNotFound(UUID)
    case skipNotFound(UUID)
    case invalidSchedule
}

/// Domain-facing persistence boundary for habits, their configuration history,
/// completions, and skips. UI and higher-level services depend on this protocol,
/// never on SwiftData directly (ARCHITECTURE.md).
/// Synchronous access is main-actor isolated to match the local store's context
/// and serialize configuration revision assignment with each write.
@MainActor
protocol HabitRepository {
    func fetchHabits(includeArchived: Bool) throws -> [Habit]
    func fetchHabit(id: UUID) throws -> Habit?

    @discardableResult
    func createHabit(_ draft: HabitDraft, at date: Date) throws -> Habit

    /// Updates a habit's fields. If `draft.schedule` or `draft.polarity` differ
    /// from the habit's current configuration, a new `HabitConfigurationSnapshot`
    /// is appended effective `date`; prior snapshots, and any history computed
    /// from them, are left untouched.
    @discardableResult
    func updateHabit(id: UUID, with draft: HabitDraft, at date: Date) throws -> Habit

    func archiveHabit(id: UUID, at date: Date) throws
    func reactivateHabit(id: UUID, at date: Date) throws

    /// All archive/reactivate cycles for a habit, ordered oldest to newest. The
    /// last entry is open (`reactivatedAt == nil`) if the habit is currently
    /// archived.
    func archivePeriods(for habitID: UUID) throws -> [HabitArchivePeriod]

    /// All configuration snapshots for a habit, ordered oldest to newest.
    func configurationHistory(for habitID: UUID) throws -> [HabitConfigurationSnapshot]

    /// The snapshot that was in effect on `date`'s local calendar day.
    func activeConfiguration(for habitID: UUID, on date: Date) throws -> HabitConfigurationSnapshot?

    @discardableResult
    func recordCompletion(
        habitID: UUID,
        at date: Date,
        source: CompletionSource,
        note: String?
    ) throws -> Completion

    func undoCompletion(id: UUID) throws

    func completions(for habitID: UUID, in interval: DateInterval) throws -> [Completion]

    /// Every completion across every habit (active or archived) whose
    /// `occurredAt` falls in `interval`. For History, which shows records from
    /// many habits at once; prefer `completions(for:in:)` when only one
    /// habit's records are needed.
    func completions(in interval: DateInterval) throws -> [Completion]

    @discardableResult
    func recordSkip(habitID: UUID, on date: Date, reason: SkipReason?) throws -> Skip

    func undoSkip(id: UUID) throws

    func skips(for habitID: UUID, in interval: DateInterval) throws -> [Skip]

    /// Every skip across every habit (active or archived) whose `localDateKey`
    /// falls in `interval`. See `completions(in:)`.
    func skips(in interval: DateInterval) throws -> [Skip]
}
