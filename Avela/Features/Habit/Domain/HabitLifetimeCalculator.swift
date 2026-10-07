import Foundation

/// Recomputed from surviving records: a miss or pause never resets a lifetime
/// total, while undo and corrections can lower it. Check-in days are distinct
/// stored local dates, not a streak or successful weekly commitments.
enum HabitLifetimeCalculator {
    static let milestoneThresholds = [10, 25, 50, 100, 250, 500, 1_000]

    struct QuantityTotal: Identifiable, Equatable {
        let unit: HabitQuantityUnit
        let amount: Int
        var id: String { unit.rawValue }
    }

    struct Summary: Equatable {
        let checkInDays: Int
        let smallerActionDays: Int
        let quantities: [QuantityTotal]
        var achievedMilestones: [Int] { milestoneThresholds.filter { $0 <= checkInDays } }
        var nextMilestone: Int? { milestoneThresholds.first { $0 > checkInDays } }
    }

    static func summarize(habitID: UUID, completions: [Completion], entries: [HabitActivityEntry], asOf date: Date) -> Summary {
        let days = Set(completions.filter { $0.habitID == habitID && $0.occurredAt <= date }.map(\.localDateKey))
        var seenEntries = Set<UUID>()
        var smallerDays = Set<String>()
        var totals: [String: Int] = [:]
        for entry in entries where entry.habitID == habitID && entry.loggedAt <= date {
            guard seenEntries.insert(entry.id).inserted else { continue }
            switch entry.kind {
            case .smallerAction:
                smallerDays.insert(entry.dayKey)
            case .quantity:
                guard let unit = entry.unit, entry.amount > 0 else { continue }
                totals[unit.rawValue, default: 0] += entry.amount
            }
        }
        return Summary(checkInDays: days.count, smallerActionDays: smallerDays.count,
            quantities: HabitQuantityUnit.allCases.compactMap { unit in
                totals[unit.rawValue].map { QuantityTotal(unit: unit, amount: $0) }
            })
    }
}
