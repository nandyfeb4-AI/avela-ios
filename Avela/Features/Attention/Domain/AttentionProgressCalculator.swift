import Foundation

/// Deterministic, SwiftUI-independent usage math for a single attention goal
/// on a single local day.
enum AttentionProgressCalculator {
    /// A goal's status on one local day.
    ///
    /// `hasLoggedUsage`/`entryCount` are kept distinct from `totalAmount` so
    /// "nothing logged yet" can never be confused with "measured zero usage":
    /// the task explicitly requires that "no entries must not imply verified
    /// zero usage." When `hasLoggedUsage` is `false`, `percentOfTarget` and
    /// `state` are `nil` — there is no status to report, only an absence of
    /// data — mirroring the same missing-data-vs-zero distinction already
    /// established for Habit consistency and Insights eligibility.
    struct DailyProgress: Equatable {
        let totalAmount: Double
        let target: Double
        let unit: AttentionUnit
        let hasLoggedUsage: Bool
        let entryCount: Int
        let percentOfTarget: Double?
        let state: ThresholdState?

        /// - Parameters:
        ///   - entries: usage entries already filtered to one goal and one
        ///     local day; summed (not deduplicated) since logging is
        ///     additive, unlike habit completions.
        ///   - target: the budget in effect on this day, resolved by
        ///     `AttentionGoalEvaluator` beforehand — this calculator does no
        ///     historical resolution of its own.
        init(entries: [AttentionUsageEntry], target: Double, unit: AttentionUnit) {
            let total = entries.reduce(0) { $0 + $1.amount }
            self.totalAmount = total
            self.target = target
            self.unit = unit
            self.hasLoggedUsage = !entries.isEmpty
            self.entryCount = entries.count
            if entries.isEmpty {
                self.percentOfTarget = nil
                self.state = nil
            } else {
                // A zero or negative target has no meaningful ratio; treat
                // any logged usage against it as exceeded rather than
                // dividing by zero.
                let percent = target > 0 ? (total / target) * 100 : (total > 0 ? .infinity : 0)
                self.percentOfTarget = percent
                self.state = ThresholdState(percentOfTarget: percent)
            }
        }
    }

    /// UX.md's thresholds: healthy <70%, near limit 70%–<100%, exceeded
    /// >=100%. Centralized here as the single source of truth per UX.md's
    /// explicit instruction that "thresholds should be centralized and
    /// configurable."
    enum ThresholdState: Equatable {
        case healthy
        case nearLimit
        case exceeded

        init(percentOfTarget: Double) {
            switch percentOfTarget {
            case ..<70:
                self = .healthy
            case 70..<100:
                self = .nearLimit
            default:
                self = .exceeded
            }
        }
    }
}
