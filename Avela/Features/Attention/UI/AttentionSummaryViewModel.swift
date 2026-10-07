import Foundation
import OSLog
import Observation

/// Display-ready projection of an `AttentionGoal` for the Today screen. Pure
/// data — no SwiftData, no business logic. `AttentionSummaryViewModel`
/// computes it by composing `AttentionRepository` reads with
/// `AttentionProgressCalculator`; the view only renders it.
struct AttentionGoalSummaryRow: Identifiable, Equatable {
    let id: UUID
    let name: String
    let appOrCategoryLabel: String?
    let targetLabel: String
    let targetUnit: AttentionUnit
    let statusLabel: String
    let state: AttentionProgressCalculator.ThresholdState?
    var goalType: AttentionGoalType = .maxDurationPerDay
}

/// Feature state for Today's attention-goal section. Owns no persistence of
/// its own: every read and write goes through the injected
/// `AttentionRepository` protocol, and all threshold math is delegated to
/// `AttentionProgressCalculator` — this type only composes those calls and
/// shapes the result for the view. Deliberately independent from
/// `TodayViewModel` (a separate, focused view model per feature) so habit
/// behavior already covered by existing tests is never put at risk by this
/// slice.
@MainActor
@Observable
final class AttentionSummaryViewModel {
    private(set) var rows: [AttentionGoalSummaryRow] = []
    private(set) var hasActiveSession = false
    var isShowingCreateGoal = false
    /// The goal currently targeted by Today's quick-log sheet, or `nil` when
    /// no quick-log sheet is presented. Set by the view in response to
    /// tapping a row's log action, not by `logUsage` itself, so the sheet can
    /// bind to it directly.
    var quickLogGoalID: UUID?
    var errorMessage: String?
    var isShowingPremium = false
    var creationAllowed: (Int) -> Bool = { _ in true }

    func requestCreation() {
        do {
            let count = try repository.fetchGoals().count
            if creationAllowed(count) { isShowingCreateGoal = true }
            else { isShowingPremium = true }
        } catch { handle(error) }
    }
    /// The most recently created entry via `logFixedAmount`, so a "Balance"
    /// quick-log chip's undo toast can remove exactly that entry — never an
    /// older one — without needing its own confirmation UI. `nil` once
    /// undone, replaced, or after any other mutation that makes "undo the
    /// last chip tap" no longer well-defined.
    private(set) var lastQuickLoggedEntryID: UUID?

    private let repository: AttentionRepository
    private let calendar: Calendar
    private static let logger = Logger(subsystem: "com.example.Avela", category: "AttentionSummaryViewModel")
    private static let friendlyErrorMessage = "Something went wrong. Please try again."

    init(repository: AttentionRepository, calendar: Calendar = .autoupdatingCurrent) {
        self.repository = repository
        self.calendar = calendar
    }

    func load(asOf date: Date = Date()) {
        do {
            let goals = try repository.fetchGoals()
            rows = try goals.map { try row(for: $0, asOf: date) }
            hasActiveSession = try goals.filter { $0.type.isTimedSession }.contains {
                try repository.sessions(for: $0.id).contains(where: \.isActive)
            }
        } catch {
            handle(error)
        }
    }

    func createGoal(_ draft: AttentionGoalDraft, asOf date: Date = Date()) {
        do {
            guard creationAllowed(try repository.fetchGoals().count) else {
                isShowingCreateGoal = false
                isShowingPremium = true
                return
            }
            _ = try repository.createGoal(draft, at: date)
            isShowingCreateGoal = false
            load(asOf: date)
        } catch {
            handle(error)
        }
    }

    func logQuickUsage(amount: Double, asOf date: Date = Date()) {
        guard let goalID = quickLogGoalID else { return }
        do {
            let entry = try repository.recordUsage(goalID: goalID, amount: amount, at: date, source: .manual)
            lastQuickLoggedEntryID = entry.id
            quickLogGoalID = nil
            load(asOf: date)
        } catch {
            handle(error)
        }
    }

    /// Logs a fixed amount (the Balance Today layout's "+5"/"+15" chips)
    /// directly, with no sheet — the fast, one-tap path UX.md calls for.
    /// "Other…" (a custom amount) still goes through `quickLogGoalID` and its
    /// sheet, unchanged.
    func logFixedAmount(_ amount: Double, goalID: UUID, asOf date: Date = Date()) {
        do {
            let entry = try repository.recordUsage(goalID: goalID, amount: amount, at: date, source: .manual)
            lastQuickLoggedEntryID = entry.id
            load(asOf: date)
        } catch {
            handle(error)
        }
    }

    /// Undoes exactly the entry `logFixedAmount`/`logQuickUsage` most recently
    /// created — the undo-toast action for fast logging. A no-op once that
    /// entry has already been undone, corrected or deleted some other way.
    func undoLastQuickLog(asOf date: Date = Date()) {
        guard let entryID = lastQuickLoggedEntryID else { return }
        do {
            try repository.deleteUsageEntry(id: entryID)
            lastQuickLoggedEntryID = nil
            load(asOf: date)
        } catch {
            handle(error)
        }
    }

    private func row(for goal: AttentionGoal, asOf date: Date) throws -> AttentionGoalSummaryRow {
        guard let configuration = try repository.activeConfiguration(for: goal.id, on: date) else {
            // Every goal gets a snapshot at creation, so this should not
            // happen in practice; render a status-less row rather than
            // throwing, since there is nothing actionable the user can do
            // about a missing historical fact from here.
            return AttentionGoalSummaryRow(
                id: goal.id,
                name: goal.name,
                appOrCategoryLabel: goal.appOrCategoryLabel,
                targetLabel: "",
                targetUnit: .minutes,
                statusLabel: "No usage logged yet today",
                state: nil
            )
        }
        if goal.type != .maxDurationPerDay {
            let projection = try AttentionWindowSummary.make(goal: goal, configuration: configuration, repository: repository, date: date, calendar: calendar)
            return AttentionGoalSummaryRow(id: goal.id, name: goal.name, appOrCategoryLabel: goal.appOrCategoryLabel,
                targetLabel: projection.targetLabel, targetUnit: .minutes,
                statusLabel: projection.statusLabel, state: projection.state, goalType: goal.type)
        }
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
        let entries = try repository.usageEntries(for: goal.id, in: DateInterval(start: dayStart, end: dayEnd))
        let progress = AttentionProgressCalculator.DailyProgress(
            entries: entries, target: configuration.targetValue, unit: configuration.unit
        )
        return AttentionGoalSummaryRow(
            id: goal.id,
            name: goal.name,
            appOrCategoryLabel: goal.appOrCategoryLabel,
            targetLabel: AttentionStatusFormatter.targetLabel(targetValue: configuration.targetValue, unit: configuration.unit),
            targetUnit: configuration.unit,
            statusLabel: AttentionStatusFormatter.statusLabel(progress: progress),
            state: progress.state
        )
    }

    private func handle(_ error: Error) {
        Self.logger.error("Attention summary view model operation failed: \(String(describing: error), privacy: .private)")
        errorMessage = Self.friendlyErrorMessage
    }
}
