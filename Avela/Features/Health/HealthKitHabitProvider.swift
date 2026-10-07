import HealthKit

@MainActor final class HealthKitHabitProvider: HealthHabitProvider {
    private let store = HKHealthStore()
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    private func type(for metric: HealthHabitMetric) -> HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: metric == .steps ? .stepCount : .appleExerciseTime)!
    }
    func requestReadAccess(for metric: HealthHabitMetric) async throws {
        guard isAvailable else { throw HealthHabitError.unavailable }
        try await store.requestAuthorization(toShare: [], read: [type(for: metric)])
    }
    func total(for metric: HealthHabitMetric, in interval: DateInterval) async throws -> Double? {
        guard isAvailable else { throw HealthHabitError.unavailable }
        guard interval.duration > 0 else { return nil }
        let quantityType = type(for: metric)
        let unit = metric == .steps ? HKUnit.count() : HKUnit.minute()
        // Statistics uses HealthKit's source aggregation rather than adding raw
        // overlapping phone/watch samples ourselves. No background delivery.
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit)) }
            }
            store.execute(query)
        }
    }
}
