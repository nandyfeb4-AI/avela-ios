import Foundation
import SwiftData

@MainActor
final class SwiftDataReflectionRepository: ReflectionRepository {
    private let context: ModelContext
    init(context: ModelContext) {
        // A private main-actor context makes rollback specific to this feature.
        self.context = ModelContext(context.container)
        self.context.autosaveEnabled = false
    }

    func reflection(for week: ReflectionWeek) throws -> WeeklyReflection? {
        try record(for: week.key)?.domain()
    }

    @discardableResult
    func save(_ draft: ReflectionDraft, for week: ReflectionWeek, at date: Date) throws -> WeeklyReflection {
        let valid = try draft.validated()
        if let existing = try record(for: week.key) {
            existing.whatHelped = valid.whatHelped
            existing.whatGotInTheWay = valid.whatGotInTheWay
            existing.updatedAt = date
            do { try context.save() }
            catch { context.rollback(); throw error }
            return existing.domain()
        }
        let inserted = WeeklyReflectionRecord(reflection: WeeklyReflection(
            id: UUID(), week: week, whatHelped: valid.whatHelped, whatGotInTheWay: valid.whatGotInTheWay,
            createdAt: date, updatedAt: date))
        context.insert(inserted)
        do { try context.save() }
        catch { context.rollback(); throw error }
        return inserted.domain()
    }

    func delete(for week: ReflectionWeek) throws {
        guard let existing = try record(for: week.key) else { return }
        context.delete(existing)
        do { try context.save() }
        catch { context.rollback(); throw error }
    }

    private func record(for key: String) throws -> WeeklyReflectionRecord? {
        let descriptor = FetchDescriptor<WeeklyReflectionRecord>(predicate: #Predicate { $0.weekKey == key })
        return try context.fetch(descriptor).first
    }
}
