import Foundation

/// User-editable fields for creating or updating a habit. Identity (`id`,
/// `createdAt`) and derived bookkeeping (`updatedAt`, `sortOrder`, `archivedAt`)
/// are owned by the repository, not the draft.
struct HabitDraft: Equatable, Sendable {
    var name: String
    var iconName: String
    var category: HabitCategory
    var polarity: HabitPolarity
    var schedule: HabitSchedule
    /// Private, optional motivation; never exported to logical cloud recovery.
    var whyItMatters: String? = nil
    var isWhyMemoryHidden: Bool = false
    /// Creation-only activity setup. Later edits use Progress & History's
    /// versioned configuration flow so historical targets remain intact.
    var quantityTarget: HabitQuantityTarget? = nil
    var smallerAction: String? = nil
}
