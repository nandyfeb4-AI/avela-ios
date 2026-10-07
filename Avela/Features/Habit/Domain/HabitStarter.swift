import Foundation

/// Local, editable starting points. Selection never creates a habit or enables
/// Health/reminder permissions; the normal creation flow owns those decisions.
struct HabitStarter: Identifiable, Sendable {
    let id: String
    let group: Group
    let description: String
    let draft: HabitDraft

    enum Group: String, CaseIterable, Sendable {
        case move = "Move"
        case learn = "Learn"
        case makeSpace = "Make Space"
    }

    static let library: [HabitStarter] = [
        HabitStarter(id: "walk", group: .move,
            description: "A walk that fits your day. Optional step tracking is available in habit details.",
            draft: HabitDraft(name: "Take a walk", iconName: "figure.walk", category: .fitness, polarity: .positive, schedule: .daily)),
        HabitStarter(id: "stretch", group: .move,
            description: "Make a little room for movement, three times a week to start.",
            draft: HabitDraft(name: "Stretch", iconName: "figure.yoga", category: .fitness, polarity: .positive, schedule: .timesPerWeek(3))),
        HabitStarter(id: "exercise", group: .move,
            description: "Choose what counts as a session. Apple Health can be connected separately.",
            draft: HabitDraft(name: "Exercise", iconName: "dumbbell.fill", category: .fitness, polarity: .positive, schedule: .timesPerWeek(3))),
        HabitStarter(id: "read", group: .learn,
            description: "A page or a chapter—choose a small commitment that suits you.",
            draft: HabitDraft(name: "Read", iconName: "book.fill", category: .learning, polarity: .positive, schedule: .daily)),
        HabitStarter(id: "learn", group: .learn,
            description: "Practice something you care about, on any three days each week.",
            draft: HabitDraft(name: "Practice a skill", iconName: "graduationcap.fill", category: .learning, polarity: .positive, schedule: .timesPerWeek(3))),
        HabitStarter(id: "journal", group: .makeSpace,
            description: "Write a thought or two. You decide what a check-in means.",
            draft: HabitDraft(name: "Journal", iconName: "pencil.line", category: .mindfulness, polarity: .positive, schedule: .daily)),
        HabitStarter(id: "pause", group: .makeSpace,
            description: "Take a quiet pause before moving to the next thing.",
            draft: HabitDraft(name: "Take a mindful pause", iconName: "leaf.fill", category: .mindfulness, polarity: .positive, schedule: .daily)),
        HabitStarter(id: "scroll", group: .makeSpace,
            description: "Spend a little less time scrolling. You decide what counts as success.",
            draft: HabitDraft(name: "Cut down on scrolling", iconName: "iphone.slash", category: .productivity, polarity: .avoidance, schedule: .daily)),
    ]
}
