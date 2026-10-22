import Foundation

/// Local, editable starting points. A selection changes an unsaved draft only;
/// it never creates records, connects Health or requests a permission.
struct HabitStarter: Identifiable, Sendable {
    let id: String
    let group: Group
    let description: String
    let draft: HabitDraft

    enum Group: String, CaseIterable, Sendable {
        case move = "Move"
        case wellbeing = "Everyday Wellbeing"
        case learn = "Learn"
        case create = "Create"
        case home = "Home & Life"
        case connect = "Connect"
        case makeSpace = "Make Space"
        case money = "Money"

        var symbol: String {
            switch self {
            case .move: "figure.walk"
            case .wellbeing: "sun.max.fill"
            case .learn: "book.fill"
            case .create: "paintpalette.fill"
            case .home: "house.fill"
            case .connect: "person.2.fill"
            case .makeSpace: "leaf.fill"
            case .money: "banknote.fill"
            }
        }

        var subtitle: String {
            switch self {
            case .move: "A little movement, your way."
            case .wellbeing: "Small everyday acts of care."
            case .learn: "Keep your curiosity company."
            case .create: "Make something just for you."
            case .home: "More room in your everyday."
            case .connect: "Time for people who matter."
            case .makeSpace: "Protect a little breathing room."
            case .money: "A little attention to your money."
            }
        }
    }

    /// Collections help people choose a few related ideas without silently
    /// creating habits or bypassing the normal plan limits and review.
    struct Collection: Identifiable, Sendable {
        let id: String
        let name: String
        let subtitle: String
        let symbol: String
        let starterIDs: [String]

        var starters: [HabitStarter] {
            starterIDs.compactMap { id in HabitStarter.library.first { $0.id == id } }
        }
    }

    static let collections: [Collection] = [
        Collection(id: "gentle-morning", name: "A gentler morning", subtitle: "Begin with a little space.",
            symbol: "sunrise.fill", starterIDs: ["water", "stretch", "plan-day"]),
        Collection(id: "evening-reset", name: "An evening reset", subtitle: "Put the day down gently.",
            symbol: "moon.stars.fill", starterIDs: ["tidy", "journal", "phone-away"]),
        Collection(id: "reading-rhythm", name: "A reading rhythm", subtitle: "Make room for a few pages.",
            symbol: "books.vertical.fill", starterIDs: ["read", "pause", "scroll"]),
        Collection(id: "creative-space", name: "A little creative space", subtitle: "Keep making, a little at a time.",
            symbol: "paintbrush.pointed.fill", starterIDs: ["sketch", "write", "skill-minutes"]),
    ]

    var trackingLabel: String {
        guard let target = draft.quantityTarget else { return draft.polarity == .avoidance ? "Success check-in" : "Check-in" }
        return target.unit == .minutes ? "Timed · \(target.amount) min" : "\(target.amount) \(target.unit.name(for: target.amount))"
    }

    static let library: [HabitStarter] = [
        idea("walk", .move, "Take a walk", "figure.walk", .fitness,
             "A walk that fits your day. Optional Apple Health setup is available after saving.",
             smaller: "Step outside for a moment"),
        idea("stretch", .move, "Stretch", "figure.yoga", .fitness,
             "Choose a few movements that feel right for you.", schedule: .timesPerWeek(3), smaller: "One gentle stretch"),
        idea("exercise", .move, "Exercise", "dumbbell.fill", .fitness,
             "Choose what counts as a session. Connect Apple Health separately if you want.",
             schedule: .timesPerWeek(3), smaller: "A little movement"),
        idea("move-minutes", .move, "Movement break", "figure.walk", .fitness,
             "Make a little time to move between the things you do.", amount: 5, unit: .minutes, smaller: "Stand up and move for a moment"),
        idea("outside", .move, "Spend time outside", "sun.max.fill", .fitness,
             "A few minutes in a place you enjoy.", amount: 10, unit: .minutes, smaller: "Step outside"),

        idea("water", .wellbeing, "Drink water", "drop.fill", .health,
             "Set an amount that suits your own day. This example is yours to change.", amount: 1, unit: .glasses, smaller: "A few sips of water"),
        idea("lunch-break", .wellbeing, "Take a lunch break", "fork.knife", .health,
             "Make a little space for a break in your day.", schedule: .weekdays([.monday, .tuesday, .wednesday, .thursday, .friday]), smaller: "Step away for a moment"),
        idea("wind-down", .wellbeing, "Wind down", "moon.stars.fill", .health,
             "Choose one small thing that helps you close your day.", smaller: "Put one thing away"),
        idea("rest-break", .wellbeing, "Take a quiet break", "cup.and.saucer.fill", .health,
             "Pause for a little while, without another task to finish.", amount: 5, unit: .minutes, smaller: "One quiet minute"),
        idea("prepare-meal", .wellbeing, "Prepare a meal", "fork.knife", .health,
             "Make something you enjoy, on days that work for you.", schedule: .timesPerWeek(3), smaller: "Prepare one ingredient"),

        idea("read", .learn, "Read", "book.fill", .learning,
             "A few pages of something you want to read.", amount: 10, unit: .pages, smaller: "One paragraph"),
        idea("learn", .learn, "Practice a skill", "graduationcap.fill", .learning,
             "Choose a skill you care about and what a check-in means.", schedule: .timesPerWeek(3), smaller: "Try one small exercise"),
        idea("language", .learn, "Practice a language", "character.book.closed.fill", .learning,
             "A little practice in a language you want to use.", amount: 10, unit: .minutes, smaller: "Practice one phrase"),
        idea("skill-minutes", .learn, "Learn something new", "graduationcap.fill", .learning,
             "Give your curiosity a little time.", amount: 15, unit: .minutes, smaller: "Explore one question"),
        idea("read-article", .learn, "Read an article", "doc.text.fill", .learning,
             "Choose something worth your attention, then read it at your pace.", schedule: .timesPerWeek(3), smaller: "Read the first paragraph"),

        idea("sketch", .create, "Sketch", "pencil.tip", .other,
             "Make a few marks. There is nothing to get perfect.", amount: 5, unit: .minutes, smaller: "Draw one shape"),
        idea("write", .create, "Write", "pencil.line", .other,
             "Give an idea a little room on the page.", amount: 10, unit: .minutes, smaller: "Write one sentence"),
        idea("music", .create, "Practice music", "music.note", .learning,
             "Play something you enjoy, a little at a time.", amount: 10, unit: .minutes, smaller: "Play one phrase"),
        idea("photo", .create, "Notice a moment", "camera.fill", .other,
             "Take a photo of something that catches your eye.", smaller: "Look for one small detail"),
        idea("creative-project", .create, "Work on a creative project", "paintpalette.fill", .other,
             "Make a little progress on something that is yours.", schedule: .timesPerWeek(3), amount: 15, unit: .minutes, smaller: "Open your project"),

        idea("tidy", .home, "Tidy a small space", "house.fill", .other,
             "Choose one little area. The whole room can wait.", amount: 5, unit: .minutes, smaller: "Put one thing away"),
        idea("plan-day", .home, "Choose today's priorities", "checklist", .productivity,
             "Name a few things that would make today feel worthwhile.", smaller: "Choose one priority"),
        idea("reset-desk", .home, "Reset my desk", "desktopcomputer", .productivity,
             "Leave a little room for the next thing you want to do.", smaller: "Clear one small spot"),
        idea("plant-care", .home, "Care for my plants", "leaf.fill", .other,
             "Check what your plants need rather than watering on autopilot.", schedule: .weekdays([.sunday]), smaller: "Check one plant"),
        idea("declutter", .home, "Put a few things away", "tray.full.fill", .other,
             "Count the small things you return to their place.", amount: 3, unit: .count, smaller: "Put one thing away"),

        idea("reach-out", .connect, "Reach out to someone", "bubble.left.and.bubble.right.fill", .social,
             "A message, a call or a simple hello.", schedule: .timesPerWeek(3), smaller: "Send a quick hello"),
        idea("call", .connect, "Call someone I care about", "phone.fill", .social,
             "Make room for a conversation when it works for you.", schedule: .weekdays([.sunday]), smaller: "Send a message to arrange a call"),
        idea("together", .connect, "Spend time together", "person.2.fill", .social,
             "Choose what being present looks like for you.", schedule: .timesPerWeek(3), smaller: "Ask about their day"),
        idea("appreciation", .connect, "Show appreciation", "heart.fill", .social,
             "Tell someone about one thing you appreciate.", smaller: "Say thank you"),
        idea("listen", .connect, "Make time to listen", "ear.fill", .social,
             "Give a conversation your attention.", smaller: "Ask one thoughtful question"),

        idea("journal", .makeSpace, "Journal", "pencil.line", .mindfulness,
             "Write a thought or two. You decide what a check-in means.", smaller: "Write one thought"),
        idea("pause", .makeSpace, "Take a mindful pause", "leaf.fill", .mindfulness,
             "Take a quiet pause before moving to the next thing.", smaller: "Pause for a moment"),
        idea("scroll", .makeSpace, "Cut down on scrolling", "iphone.slash", .productivity,
             "Choose your own boundary and log success when you meet it.", polarity: .avoidance, smaller: "Put the phone down for a moment"),
        idea("phone-away", .makeSpace, "Put my phone away", "iphone.slash", .mindfulness,
             "Choose one moment to give your attention to something else.", smaller: "Put the phone out of reach briefly"),
        idea("single-task", .makeSpace, "Work on one thing", "timer", .productivity,
             "Choose one task and give it a little uninterrupted room.", amount: 15, unit: .minutes, smaller: "Choose the first step"),

        idea("expenses", .money, "Review my spending", "chart.pie.fill", .finance,
             "Look over what you have spent, without judging the day.", schedule: .weekdays([.sunday]), smaller: "Look at one recent purchase"),
        idea("budget", .money, "Check my budget", "banknote.fill", .finance,
             "Give your own plan a quick look.", schedule: .weekdays([.sunday]), smaller: "Open your budget"),
        idea("purchase-pause", .money, "Pause before buying", "cart.fill", .finance,
             "Choose a pause that helps you make a considered decision.", smaller: "Save the item for later"),
        idea("save", .money, "Add to my savings", "banknote.fill", .finance,
             "Log a check-in when you follow your own savings plan.", schedule: .weekdays([.friday]), smaller: "Look at your next saving step"),
        idea("money-admin", .money, "Make time for money admin", "doc.text.fill", .finance,
             "Give one small piece of personal admin a little time.", schedule: .weekdays([.sunday]), amount: 10, unit: .minutes, smaller: "Choose one thing to review"),
    ]

    private static func idea(_ id: String, _ group: Group, _ name: String, _ symbol: String,
                             _ category: HabitCategory, _ description: String,
                             schedule: HabitSchedule = .daily, polarity: HabitPolarity = .positive,
                             amount: Int? = nil, unit: HabitQuantityUnit = .count, smaller: String) -> HabitStarter {
        HabitStarter(id: id, group: group, description: description,
            draft: HabitDraft(name: name, iconName: symbol, category: category, polarity: polarity,
                schedule: schedule, quantityTarget: amount.map { HabitQuantityTarget(amount: $0, unit: unit) },
                smallerAction: smaller))
    }
}
