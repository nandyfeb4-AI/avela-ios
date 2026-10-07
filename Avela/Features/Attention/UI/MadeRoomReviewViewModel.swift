import Foundation
import Observation

@MainActor @Observable
final class MadeRoomReviewViewModel {
    let interval: DateInterval
    private(set) var review: MadeRoomReviewCalculator.Review?
    private(set) var errorMessage: String?
    private let habits: any HabitRepository
    private let attention: any AttentionRepository
    private let links: any IntentionSessionLinkRepository
    private let calendar: Calendar

    init(habits: any HabitRepository, attention: any AttentionRepository,
         links: any IntentionSessionLinkRepository, interval: DateInterval,
         calendar: Calendar = .autoupdatingCurrent) {
        self.habits = habits
        self.attention = attention
        self.links = links
        self.interval = interval
        self.calendar = calendar
    }

    var weekLabel: String {
        let formatter = DateIntervalFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: interval.start, to: interval.end.addingTimeInterval(-1))
    }

    /// Refreshes only stored facts. This flow never starts/finishes a session,
    /// logs a habit, or reads private reflection text.
    func load() {
        review = nil
        do {
            let allHabits = try habits.fetchHabits(includeArchived: true)
            var allLinks: [IntentionSessionLink] = []
            for habit in allHabits { allLinks += try links.links(for: habit.id) }
            let goals = try attention.fetchGoals().filter { $0.type.isTimedSession }
            var sessions: [AttentionSession] = []
            for goal in goals { sessions += try attention.sessions(for: goal.id) }
            // Repositories filter timestamps; civil-day membership is authoritative
            // for recorded check-ins after travel. Fetch a bounded padded interval.
            let padded = DateInterval(start: interval.start.addingTimeInterval(-2 * 86400),
                                      end: interval.end.addingTimeInterval(2 * 86400))
            let completions = try habits.completions(in: padded)
            review = MadeRoomReviewCalculator.calculate(habits: allHabits, links: allLinks, sessions: sessions,
                                                       completions: completions, interval: interval, calendar: calendar)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load your recorded intentions. Please try again."
        }
    }

    static func minutes(_ seconds: TimeInterval) -> String {
        (seconds / 60).formatted(.number.precision(.fractionLength(0...1)))
    }
}
