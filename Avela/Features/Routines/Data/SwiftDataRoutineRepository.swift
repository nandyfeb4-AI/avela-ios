import Foundation
import SwiftData

@MainActor
final class SwiftDataRoutineRepository: RoutineRepository {
    private let context: ModelContext
    private let habits: any HabitRepository

    init(modelContext: ModelContext, habits: any HabitRepository) {
        context = ModelContext(modelContext.container)
        context.autosaveEnabled = false
        self.habits = habits
    }

    func routines() throws -> [HabitRoutine] {
        try context.fetch(FetchDescriptor<RoutineRecord>()).map(\.domain).sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    func save(id: UUID?, name: String, habitIDs: [UUID], restartDays: Int? = nil, at date: Date) throws -> HabitRoutine {
        guard restartDays == nil || restartDays == 3 || restartDays == 7 else { throw RoutineError.invalidRestartDuration }
        let active = Set(try habits.fetchHabits(includeArchived: false).map(\.id))
        let name = try RoutineValidation.validate(name: name, habitIDs: habitIDs, activeIDs: active)
        if let id {
            guard let record = try record(id: id) else { throw RoutineError.routineNotFound }
            let old = record.domain
            record.restartDays = restartDays
            record.name = name
            record.habitIDs = habitIDs
            record.updatedAt = date
            do { try context.save() } catch {
                record.restartDays = old.restartDays
                record.name = old.name
                record.habitIDs = old.habitIDs
                record.updatedAt = old.updatedAt
                throw error
            }
            return record.domain
        }
        let value = HabitRoutine(id: UUID(), name: name, habitIDs: habitIDs, createdAt: date, updatedAt: date, restartDays: restartDays)
        let record = RoutineRecord(value)
        context.insert(record)
        do { try context.save() } catch { context.delete(record); throw error }
        return value
    }

    func delete(id: UUID) throws {
        guard let record = try record(id: id) else { throw RoutineError.routineNotFound }
        context.delete(record)
        do { try context.save() } catch { context.rollback(); throw error }
    }

    private func record(id: UUID) throws -> RoutineRecord? {
        try context.fetch(FetchDescriptor<RoutineRecord>(predicate: #Predicate { $0.id == id })).first
    }
}
