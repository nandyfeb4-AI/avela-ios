import Foundation

/// Local convenience preferences, never part of target configuration or tracking history.
@MainActor
final class HabitQuickLogPresets {
    enum ValidationError: Error { case invalidAmounts }
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func amounts(for habitID: UUID, unit: HabitQuantityUnit) -> [Int] {
        guard let values = defaults.array(forKey: key(habitID, unit)) as? [Int],
              Self.isValid(values) else { return Self.defaultAmounts(for: unit) }
        return values
    }

    func save(_ values: [Int], for habitID: UUID, unit: HabitQuantityUnit) throws {
        guard Self.isValid(values) else { throw ValidationError.invalidAmounts }
        defaults.set(values, forKey: key(habitID, unit))
    }

    static func defaultAmounts(for unit: HabitQuantityUnit) -> [Int] {
        switch unit {
        case .count, .glasses: return [1, 2, 3]
        case .pages: return [1, 5, 10]
        case .minutes: return [5, 10, 20]
        }
    }
    private static func isValid(_ values: [Int]) -> Bool {
        (1...3).contains(values.count) && Set(values).count == values.count && values.allSatisfy { (1...10_000).contains($0) }
    }
    private func key(_ habitID: UUID, _ unit: HabitQuantityUnit) -> String {
        "avela.quickLogPresets.v1.\(habitID.uuidString).\(unit.rawValue)"
    }
}
