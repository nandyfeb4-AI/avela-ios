import Foundation
import OSLog
import Observation

/// One of today's logged entries, display-ready.
struct AttentionUsageEntryRow: Identifiable, Equatable {
    let id: UUID
    let amount: Double
    let amountLabel: String
    let recordedAtLabel: String
}

/// Display-ready projection of an attention goal's detail screen. Pure data —
/// the view only renders these fields; `AttentionGoalDetailViewModel` is the
/// only place that composes `AttentionRepository` reads with
/// `AttentionProgressCalculator`.
struct AttentionGoalDetailDisplay: Equatable {
    let name: String
    let appOrCategoryLabel: String?
    let targetLabel: String
    let targetUnit: AttentionUnit
    let statusLabel: String
    let state: AttentionProgressCalculator.ThresholdState?
    /// Today's entries only, oldest first — this screen shows and allows
    /// correcting/deleting only today's own logged entries. Historical
    /// entries are not reachable from here, mirroring how habit completions
    /// can only be toggled for today from Today's row; past records are
    /// read-only facts.
    let entries: [AttentionUsageEntryRow]
}

/// The detail screen's modal sheets, collapsed into one `Identifiable` enum
/// so the view can drive them from a single `.sheet(item:)` rather than three
/// separate `isPresented` bindings on the same view — chaining that many
/// independent `.sheet` modifiers on one view proved unreliable on this
/// toolchain (a UI test tapping an entry row to open the correction sheet
/// found the sheet never presented, while the same row's swipe-to-delete and
/// the screen's other, lone sheet both worked); one binding of a single
/// optional value removes the ambiguity entirely.
enum AttentionGoalDetailSheet: Identifiable, Equatable {
    case edit
    case logUsage
    case correct(entryID: UUID)

    var id: String {
        switch self {
        case .edit: return "edit"
        case .logUsage: return "logUsage"
        case .correct(let entryID): return "correct-\(entryID.uuidString)"
        }
    }
}

/// Feature state for the attention goal detail screen: today's status, entry
/// list, logging, correcting, deleting, and editing the goal's budget. All
/// threshold math is delegated to `AttentionProgressCalculator` — this type
/// only fetches the facts it needs and shapes the result for display.
@MainActor
@Observable
final class AttentionGoalDetailViewModel {
    private(set) var display: AttentionGoalDetailDisplay?
    private(set) var draft: AttentionGoalDraft?
    var activeSheet: AttentionGoalDetailSheet?
    var errorMessage: String?

    let goalID: UUID
    private let repository: AttentionRepository
    private let calendar: Calendar
    private static let logger = Logger(subsystem: "com.example.Avela", category: "AttentionGoalDetailViewModel")
    private static let friendlyErrorMessage = "Something went wrong. Please try again."
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    init(goalID: UUID, repository: AttentionRepository, calendar: Calendar = .autoupdatingCurrent) {
        self.goalID = goalID
        self.repository = repository
        self.calendar = calendar
    }

    func load(asOf date: Date = Date()) {
        do {
            guard let goal = try repository.fetchGoal(id: goalID) else {
                errorMessage = Self.friendlyErrorMessage
                return
            }
            guard let configuration = try repository.activeConfiguration(for: goalID, on: date) else {
                errorMessage = Self.friendlyErrorMessage
                return
            }
            draft = AttentionGoalDraft(
                name: goal.name,
                appOrCategoryLabel: goal.appOrCategoryLabel,
                type: goal.type,
                targetValue: configuration.targetValue,
                unit: configuration.unit
            )

            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
            let entries = try repository
                .usageEntries(for: goalID, in: DateInterval(start: dayStart, end: dayEnd))
                .sorted { $0.recordedAt < $1.recordedAt }
            let progress = AttentionProgressCalculator.DailyProgress(
                entries: entries, target: configuration.targetValue, unit: configuration.unit
            )

            display = AttentionGoalDetailDisplay(
                name: goal.name,
                appOrCategoryLabel: goal.appOrCategoryLabel,
                targetLabel: AttentionStatusFormatter.targetLabel(targetValue: configuration.targetValue, unit: configuration.unit),
                targetUnit: configuration.unit,
                statusLabel: AttentionStatusFormatter.statusLabel(progress: progress),
                state: progress.state,
                entries: entries.map {
                    AttentionUsageEntryRow(
                        id: $0.id,
                        amount: $0.amount,
                        amountLabel: AttentionStatusFormatter.amountLabel($0.amount, unit: $0.unit),
                        recordedAtLabel: Self.timeFormatter.string(from: $0.recordedAt)
                    )
                }
            )
        } catch {
            handle(error)
        }
    }

    func saveEdits(_ updatedDraft: AttentionGoalDraft, asOf date: Date = Date()) {
        do {
            _ = try repository.updateGoal(id: goalID, with: updatedDraft, at: date)
            activeSheet = nil
            load(asOf: date)
        } catch {
            handle(error)
        }
    }

    func logUsage(amount: Double, asOf date: Date = Date()) {
        do {
            _ = try repository.recordUsage(goalID: goalID, amount: amount, at: date, source: .manual)
            activeSheet = nil
            load(asOf: date)
        } catch {
            handle(error)
        }
    }

    func correctEntry(id entryID: UUID, amount: Double, asOf date: Date = Date()) {
        do {
            _ = try repository.updateUsageEntry(id: entryID, amount: amount)
            activeSheet = nil
            load(asOf: date)
        } catch {
            handle(error)
        }
    }

    func deleteEntry(id: UUID, asOf date: Date = Date()) {
        do {
            try repository.deleteUsageEntry(id: id)
            load(asOf: date)
        } catch {
            handle(error)
        }
    }

    private func handle(_ error: Error) {
        Self.logger.error("Attention goal detail view model operation failed: \(String(describing: error), privacy: .private)")
        errorMessage = Self.friendlyErrorMessage
    }
}
