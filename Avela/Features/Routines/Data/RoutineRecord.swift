import Foundation
import SwiftData

@Model
final class RoutineRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var habitIDs: [UUID]
    var createdAt: Date
    var restartDays: Int? = nil
    var updatedAt: Date
    /// Lossless local recovery decoding; validation happens before insertion.
    init(backup row: BackupPayload.RoutineRecordRow) {
        self.id = row.id
        self.name = row.name
        self.habitIDs = row.habitIDs
        self.createdAt = row.createdAt
        self.restartDays = row.restartDays
        self.updatedAt = row.updatedAt
    }


    init(_ routine: HabitRoutine) {
        restartDays = routine.restartDays
        id = routine.id
        name = routine.name
        habitIDs = routine.habitIDs
        createdAt = routine.createdAt
        updatedAt = routine.updatedAt
    }

    var domain: HabitRoutine {
        HabitRoutine(id: id, name: name, habitIDs: habitIDs, createdAt: createdAt, updatedAt: updatedAt, restartDays: restartDays)
    }
}
