import Foundation

struct WidgetHabitSnapshot: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let iconName: String
    let isCompletedToday: Bool
    let progressLabel: String
    // Missing capabilities in an older snapshot must never enable a write.
    var configurationRevision: Int? = nil
    var requiresQuantityLogging: Bool? = nil
    var isSkippedToday: Bool? = nil
    var checkInLabel: String? = nil
    var weeklyTargetMet: Bool? = nil
}

struct WidgetRoutineSnapshot: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let habitIDs: [UUID]
}

struct WidgetAttentionSnapshot: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let statusLabel: String
    let hasLoggedUsage: Bool
}

/// Read-only display facts exported by the app. The extension does not open
/// SwiftData or evaluate historical business rules independently.
struct WidgetSnapshot: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let localDateKey: String
    let generatedAt: Date
    let habits: [WidgetHabitSnapshot]
    let attentionGoals: [WidgetAttentionSnapshot]
    let companionAnimal: String?
    let companionState: String?
    var timeZoneIdentifier: String? = nil
    var accentLight: UInt32? = nil
    var accentDark: UInt32? = nil
    var quickLogPinnedIDs: [UUID]? = nil
    var quickLogPinUntil: Date? = nil
    var quickLogMessage: String? = nil
    var routines: [WidgetRoutineSnapshot]? = nil

    init(localDateKey: String, generatedAt: Date, habits: [WidgetHabitSnapshot], attentionGoals: [WidgetAttentionSnapshot], companionAnimal: String? = nil, companionState: String? = nil) {
        schemaVersion = 1
        self.localDateKey = localDateKey
        self.generatedAt = generatedAt
        self.habits = habits
        self.attentionGoals = attentionGoals
        self.companionAnimal = companionAnimal
        self.companionState = companionState
    }

    func isCurrent(asOf date: Date, calendar: Calendar) -> Bool {
        schemaVersion == 1
            && localDateKey == LocalDay.key(for: date, calendar: calendar)
            && generatedAt <= date.addingTimeInterval(60)
            && (timeZoneIdentifier == nil || timeZoneIdentifier == calendar.timeZone.identifier)
    }
}
