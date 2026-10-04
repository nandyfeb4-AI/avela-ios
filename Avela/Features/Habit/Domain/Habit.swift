import Foundation

/// Canonical habit entity. Pure domain data: no SwiftData or SwiftUI dependency,
/// per ARCHITECTURE.md's layering rules.
struct Habit: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    var name: String
    var iconName: String
    var category: HabitCategory
    var polarity: HabitPolarity
    var schedule: HabitSchedule
    let createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?
    var sortOrder: Int

    var isArchived: Bool { archivedAt != nil }
}

enum HabitCategory: String, CaseIterable, Codable, Hashable, Sendable {
    case health
    case fitness
    case learning
    case mindfulness
    case productivity
    case social
    case finance
    case other
}

/// Whether completing the habit is the desired behavior (`positive`, e.g. "Read")
/// or whether the habit tracks restraint from a behavior (`avoidance`, e.g. "No
/// late-night snacking"). Scheduling and completion semantics are identical for
/// both; polarity only changes how UI should phrase progress.
enum HabitPolarity: String, Codable, Hashable, Sendable {
    case positive
    case avoidance
}
