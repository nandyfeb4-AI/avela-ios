import Foundation
import SwiftData

@Model
final class HabitReminderRecord {
    @Attribute(.unique) var habitID: UUID
    var isEnabled: Bool
    var hour: Int
    var minute: Int

    init(_ reminder: HabitReminder) {
        habitID = reminder.habitID
        isEnabled = reminder.isEnabled
        hour = reminder.hour
        minute = reminder.minute
    }

    var domain: HabitReminder {
        HabitReminder(habitID: habitID, isEnabled: isEnabled, hour: hour, minute: minute)
    }
}

@MainActor
final class SwiftDataHabitReminderRepository: HabitReminderRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) { self.modelContext = modelContext }

    func allReminders() throws -> [HabitReminder] {
        try modelContext.fetch(FetchDescriptor<HabitReminderRecord>()).map(\.domain)
    }

    func reminder(for habitID: UUID) throws -> HabitReminder? {
        let id = habitID
        let query = FetchDescriptor<HabitReminderRecord>(predicate: #Predicate { $0.habitID == id })
        return try modelContext.fetch(query).first?.domain
    }

    func save(_ reminder: HabitReminder) throws {
        guard reminder.isValid else { throw ReminderError.invalidTime }
        let id = reminder.habitID
        let query = FetchDescriptor<HabitReminderRecord>(predicate: #Predicate { $0.habitID == id })
        if let record = try modelContext.fetch(query).first {
            record.isEnabled = reminder.isEnabled
            record.hour = reminder.hour
            record.minute = reminder.minute
        } else {
            modelContext.insert(HabitReminderRecord(reminder))
        }
        try modelContext.save()
    }
}
