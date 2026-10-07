import Foundation
import SwiftData

/// SwiftData-backed storage for `Habit`. Schedule encoding lives entirely in this
/// data-layer file so the domain `Habit`/`HabitSchedule` types stay persistence-
/// agnostic.
@Model
final class HabitRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var iconName: String
    var categoryRaw: String
    var polarityRaw: String
    var scheduleKindRaw: String
    var scheduleWeekdaysRaw: [Int]
    var scheduleTimesPerWeek: Int?
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?
    var sortOrder: Int
    var whyItMatters: String? = nil
    var whyMemoryHidden: Bool? = nil
    /// Lossless local recovery decoding; validation happens before insertion.
    init(backup row: BackupPayload.HabitRecordRow) {
        self.id = row.id
        self.name = row.name
        self.iconName = row.iconName
        self.categoryRaw = row.categoryRaw
        self.polarityRaw = row.polarityRaw
        self.scheduleKindRaw = row.scheduleKindRaw
        self.scheduleWeekdaysRaw = row.scheduleWeekdaysRaw
        self.scheduleTimesPerWeek = row.scheduleTimesPerWeek
        self.createdAt = row.createdAt
        self.updatedAt = row.updatedAt
        self.archivedAt = row.archivedAt
        self.sortOrder = row.sortOrder
        // Private motivation is intentionally absent from logical recovery.
        self.whyItMatters = nil
        self.whyMemoryHidden = nil
    }


    init(
        id: UUID,
        name: String,
        iconName: String,
        categoryRaw: String,
        polarityRaw: String,
        scheduleKindRaw: String,
        scheduleWeekdaysRaw: [Int],
        scheduleTimesPerWeek: Int?,
        createdAt: Date,
        updatedAt: Date,
        archivedAt: Date?,
        sortOrder: Int,
        whyItMatters: String? = nil,
        whyMemoryHidden: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.categoryRaw = categoryRaw
        self.polarityRaw = polarityRaw
        self.scheduleKindRaw = scheduleKindRaw
        self.scheduleWeekdaysRaw = scheduleWeekdaysRaw
        self.scheduleTimesPerWeek = scheduleTimesPerWeek
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
        self.sortOrder = sortOrder
        self.whyItMatters = whyItMatters
        self.whyMemoryHidden = whyMemoryHidden
    }
}

extension HabitRecord {
    convenience init(domain habit: Habit) {
        let encoded = HabitRecord.encode(schedule: habit.schedule)
        self.init(
            id: habit.id,
            name: habit.name,
            iconName: habit.iconName,
            categoryRaw: habit.category.rawValue,
            polarityRaw: habit.polarity.rawValue,
            scheduleKindRaw: encoded.kind,
            scheduleWeekdaysRaw: encoded.weekdays,
            scheduleTimesPerWeek: encoded.timesPerWeek,
            createdAt: habit.createdAt,
            updatedAt: habit.updatedAt,
            archivedAt: habit.archivedAt,
            sortOrder: habit.sortOrder,
            whyItMatters: habit.whyItMatters,
            whyMemoryHidden: habit.isWhyMemoryHidden
        )
    }

    func apply(draft: HabitDraft, updatedAt: Date) {
        whyItMatters = draft.whyItMatters?.trimmingCharacters(in: .whitespacesAndNewlines)
        if whyItMatters?.isEmpty == true { whyItMatters = nil }
        whyMemoryHidden = draft.isWhyMemoryHidden
        name = draft.name
        iconName = draft.iconName
        categoryRaw = draft.category.rawValue
        polarityRaw = draft.polarity.rawValue
        let encoded = HabitRecord.encode(schedule: draft.schedule)
        scheduleKindRaw = encoded.kind
        scheduleWeekdaysRaw = encoded.weekdays
        scheduleTimesPerWeek = encoded.timesPerWeek
        self.updatedAt = updatedAt
    }

    var currentSchedule: HabitSchedule {
        HabitRecord.decodeSchedule(
            kind: scheduleKindRaw,
            weekdays: scheduleWeekdaysRaw,
            timesPerWeek: scheduleTimesPerWeek
        )
    }

    var currentPolarity: HabitPolarity {
        HabitPolarity(rawValue: polarityRaw) ?? .positive
    }

    func toDomain() -> Habit {
        Habit(
            id: id,
            name: name,
            iconName: iconName,
            category: HabitCategory(rawValue: categoryRaw) ?? .other,
            polarity: currentPolarity,
            schedule: currentSchedule,
            createdAt: createdAt,
            updatedAt: updatedAt,
            archivedAt: archivedAt,
            sortOrder: sortOrder,
            whyItMatters: whyItMatters,
            isWhyMemoryHidden: whyMemoryHidden ?? false
        )
    }

    static func encode(schedule: HabitSchedule) -> (kind: String, weekdays: [Int], timesPerWeek: Int?) {
        switch schedule {
        case .daily:
            return ("daily", [], nil)
        case .weekdays(let days):
            return ("weekdays", days.map(\.rawValue).sorted(), nil)
        case .timesPerWeek(let count):
            return ("timesPerWeek", [], count)
        }
    }

    static func decodeSchedule(kind: String, weekdays: [Int], timesPerWeek: Int?) -> HabitSchedule {
        switch kind {
        case "weekdays":
            return .weekdays(Set(weekdays.compactMap(Weekday.init(rawValue:))))
        case "timesPerWeek":
            return .timesPerWeek(timesPerWeek ?? 1)
        default:
            return .daily
        }
    }
}
