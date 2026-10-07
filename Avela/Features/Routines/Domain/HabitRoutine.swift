import Foundation

/// A presentation sequence of habits, never a second source of completion facts.
struct HabitRoutine: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var habitIDs: [UUID]
    let createdAt: Date
    var updatedAt: Date
    var restartDays: Int? = nil

    func restartReviewDate(calendar: Calendar) -> Date? {
        guard let restartDays else { return nil }
        return calendar.date(byAdding: .day, value: restartDays, to: createdAt)
    }
}

enum RoutineError: Error, Equatable {
    case invalidName
    case invalidSelection
    case invalidRestartDuration
    case routineNotFound
}

@MainActor
protocol RoutineRepository {
    func routines() throws -> [HabitRoutine]
    @discardableResult
    func save(id: UUID?, name: String, habitIDs: [UUID], restartDays: Int?, at: Date) throws -> HabitRoutine
    func delete(id: UUID) throws
}

/// Validation is shared by persistence and drafts. A routine cannot create habits
/// or bypass habit creation limits; it references already-active stable IDs.
enum RoutineValidation {
    static func validate(name: String, habitIDs: [UUID], activeIDs: Set<UUID>) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 80 else { throw RoutineError.invalidName }
        guard !habitIDs.isEmpty, Set(habitIDs).count == habitIDs.count,
              habitIDs.allSatisfy(activeIDs.contains) else { throw RoutineError.invalidSelection }
        return trimmed
    }
}
