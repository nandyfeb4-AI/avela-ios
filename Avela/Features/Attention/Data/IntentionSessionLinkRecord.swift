import Foundation
import SwiftData

@Model
final class IntentionSessionLinkRecord {
    @Attribute(.unique) var id: UUID
    var habitID: UUID
    @Attribute(.unique) var sessionID: UUID
    var createdAt: Date
    /// Lossless local recovery decoding; validation happens before insertion.
    init(backup row: BackupPayload.IntentionSessionLinkRecordRow) {
        self.id = row.id
        self.habitID = row.habitID
        self.sessionID = row.sessionID
        self.createdAt = row.createdAt
    }


    init(_ link: IntentionSessionLink) {
        id = link.id
        habitID = link.habitID
        sessionID = link.sessionID
        createdAt = link.createdAt
    }

    var domain: IntentionSessionLink {
        IntentionSessionLink(id: id, habitID: habitID, sessionID: sessionID, createdAt: createdAt)
    }
}

@MainActor
final class SwiftDataIntentionSessionLinkRepository: IntentionSessionLinkRepository {
    private let context: ModelContext
    init(modelContext: ModelContext) {
        context = ModelContext(modelContext.container)
        context.autosaveEnabled = false
    }

    func links(for habitID: UUID) throws -> [IntentionSessionLink] {
        let identifier = habitID
        let descriptor = FetchDescriptor<IntentionSessionLinkRecord>(
            predicate: #Predicate { $0.habitID == identifier },
            sortBy: [SortDescriptor(\IntentionSessionLinkRecord.createdAt, order: .reverse)])
        return try context.fetch(descriptor).map(\.domain)
    }

    func save(_ link: IntentionSessionLink) throws {
        let identifier = link.sessionID
        let linkID = link.id
        let descriptor = FetchDescriptor<IntentionSessionLinkRecord>(predicate: #Predicate { $0.sessionID == identifier || $0.id == linkID })
        if let existing = try context.fetch(descriptor).first {
            // An existing association is immutable; retrying the same write is
            // safe, but a session cannot silently move to another habit.
            guard existing.habitID == link.habitID, existing.sessionID == link.sessionID else { throw IntentionSessionLinkError.conflictingIntention }
            return
        }
        let record = IntentionSessionLinkRecord(link)
        context.insert(record)
        do { try context.save() }
        catch {
            context.rollback()
            throw error
        }
    }
}

