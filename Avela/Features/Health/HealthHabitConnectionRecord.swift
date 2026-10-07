import SwiftData
import Foundation

@Model final class HealthHabitConnectionRecord {
    @Attribute(.unique) var habitID: UUID
    var connectionID: UUID
    var metricRawValue: String
    var target: Double
    var connectedAt: Date
    /// Lossless local recovery decoding; validation happens before insertion.
    init(backup row: BackupPayload.HealthHabitConnectionRecordRow) {
        self.habitID = row.habitID
        self.connectionID = row.connectionID
        self.metricRawValue = row.metricRawValue
        self.target = row.target
        self.connectedAt = row.connectedAt
    }

    init(habitID: UUID, metric: HealthHabitMetric, target: Double, at date: Date) {
        self.habitID = habitID; connectionID = UUID()
        metricRawValue = metric.rawValue; self.target = target; connectedAt = date
    }
}

@MainActor struct SwiftDataHealthHabitConnectionRepository: HealthHabitConnectionRepository {
    let context: ModelContext
    func connections() throws -> [HealthHabitConnection] {
        try context.fetch(FetchDescriptor<HealthHabitConnectionRecord>()).compactMap {
            guard let metric = HealthHabitMetric(rawValue: $0.metricRawValue) else { return nil }
            return HealthHabitConnection(id: $0.connectionID, habitID: $0.habitID,
                metric: metric, target: $0.target, connectedAt: $0.connectedAt)
        }
    }
    func save(habitID: UUID, metric: HealthHabitMetric, target: Double, at date: Date) throws {
        guard target.isFinite, target > 0, target <= metric.maximumTarget else { throw HealthHabitError.invalidTarget }
        if let row = try context.fetch(FetchDescriptor<HealthHabitConnectionRecord>()).first(where: { $0.habitID == habitID }) {
            row.connectionID = UUID(); row.metricRawValue = metric.rawValue
            row.target = target; row.connectedAt = date
        } else { context.insert(HealthHabitConnectionRecord(habitID: habitID, metric: metric, target: target, at: date)) }
        try context.save()
    }
    func disconnect(habitID: UUID) throws {
        for row in try context.fetch(FetchDescriptor<HealthHabitConnectionRecord>()) where row.habitID == habitID {
            context.delete(row)
        }
        try context.save()
    }
}
