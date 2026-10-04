import Foundation

/// Shared presentation wording for attention-goal budgets and usage status.
/// Purely textual — no persistence or calculation logic lives here.
///
/// Every status string here either says nothing about today's usage (when
/// none has been logged) or explicitly says "logged manually" — this is the
/// task's own integrity requirement: a day with no entries must never read
/// as a verified zero, and a logged amount must never read as an
/// automatically measured "On track" status the way Habit consistency can
/// read for schedule-driven facts.
enum AttentionStatusFormatter {
    static func amountLabel(_ amount: Double, unit: AttentionUnit) -> String {
        guard amount.isFinite else { return "Unknown amount" }
        let rounded = amount.rounded()
        let amountText = abs(amount - rounded) < 0.01 ? String(format: "%.0f", rounded) : String(format: "%.1f", amount)
        switch unit {
        case .minutes:
            return "\(amountText) min"
        }
    }

    static func targetLabel(targetValue: Double, unit: AttentionUnit) -> String {
        "\(amountLabel(targetValue, unit: unit)) budget"
    }

    static func statusLabel(progress: AttentionProgressCalculator.DailyProgress) -> String {
        guard progress.hasLoggedUsage else {
            return "No usage logged yet today"
        }
        let totalText = amountLabel(progress.totalAmount, unit: progress.unit)
        let targetText = amountLabel(progress.target, unit: progress.unit)
        return "\(totalText) of \(targetText) logged manually · \(stateLabel(progress.state))"
    }

    static func stateLabel(_ state: AttentionProgressCalculator.ThresholdState?) -> String {
        switch state {
        case .healthy:
            return "Healthy"
        case .nearLimit:
            return "Near Limit"
        case .exceeded:
            return "Exceeded"
        case nil:
            return "No Data"
        }
    }

    /// Today's Attention pillar reduces every goal's status to one word. This
    /// is never "On track" — a single claimed-healthy word for the whole
    /// domain is exactly the kind of automatic, verified-sounding status this
    /// feature must not imply (see `AttentionProgressCalculator.DailyProgress`'s
    /// missing-data-vs-zero distinction). Instead it reuses the same
    /// per-goal vocabulary (`stateLabel`), worst case first, and says
    /// "Not logged yet" — not "Healthy" — when not a single goal has any
    /// usage recorded today.
    enum PillarState: Equatable {
        case notLoggedYet
        case manualCheckIns
        case state(AttentionProgressCalculator.ThresholdState)
    }

    static func pillarState(for rows: [AttentionGoalSummaryRow]) -> PillarState? {
        guard !rows.isEmpty else { return nil }
        let budgets = rows.filter { $0.goalType == .maxDurationPerDay }
        guard !budgets.isEmpty else { return .manualCheckIns }
        let states = budgets.compactMap(\.state)
        if states.contains(.exceeded) { return .state(.exceeded) }
        if states.contains(.nearLimit) { return .state(.nearLimit) }
        if states.contains(.healthy) { return .state(.healthy) }
        return .notLoggedYet
    }

    static func pillarLabel(for pillarState: PillarState?) -> String {
        switch pillarState {
        case .none:
            return ""
        case .manualCheckIns:
            return "Manual check-ins"
        case .notLoggedYet:
            return "Not logged yet"
        case .state(let state):
            return stateLabel(state)
        }
    }
}
