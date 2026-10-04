import Foundation

struct WidgetHabitSnapshot: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let iconName: String
    let isCompletedToday: Bool
    let progressLabel: String
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
    }
}
