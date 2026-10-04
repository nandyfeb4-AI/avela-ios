#if DEBUG
import Foundation

/// DEBUG-only seed data for exercising *populated* Insights states — real
/// variety, ties, a balanced week, a valid trend, and an unavailable
/// comparison — from a real launched app instance instead of only from
/// XCTest fixtures, which cannot drive screenshots.
///
/// Activated only by `AVELA_UI_TEST_SEED_FIXTURE` naming one of the cases
/// below, and only ever applied to the store `AVELA_UI_TEST_STORE_PATH`
/// already redirects `AvelaApp` to (see `AvelaApp.makeContainer()`) — never
/// the ordinary app store. This file is wrapped in `#if DEBUG`, exactly like
/// that store-path override, so it is physically absent from Release
/// binaries, not merely inert. Every fixture uses nothing but the existing
/// public `HabitRepository` API (`createHabit`, `recordCompletion`,
/// `updateHabit`) — the same calls any real use of the app would make — so
/// no production type (repository, calculator, view model) carries any
/// fixture-specific logic.
@MainActor
enum DebugFixtures {
    enum Fixture: String {
        /// Three habits with distinct, non-tied, non-balanced results: a
        /// clear strongest habit, a clear habit needing attention, and a
        /// week-over-week trend for at least one of them.
        case populated
        /// Two habits landing on the exact same (non-zero, non-100%)
        /// percentage this week — the "balanced week" neutral-summary case.
        case balancedIdentical
        /// Two habits tied for strongest, and two different habits tied for
        /// needing attention, in a week that is not itself fully balanced.
        case tiedExtremes
        /// One continuously-tracked, schedule-stable habit with a clear,
        /// valid week-over-week trend.
        case validTrend
        /// One habit whose schedule changed between the two weeks: eligible
        /// in both, but not comparable — exercises "Not enough comparable
        /// data."
        case noComparableData
    }

    static func seed(_ fixture: Fixture, into repository: HabitRepository, calendar: Calendar) {
        do {
            switch fixture {
            case .populated: try seedPopulated(repository, calendar)
            case .balancedIdentical: try seedBalancedIdentical(repository, calendar)
            case .tiedExtremes: try seedTiedExtremes(repository, calendar)
            case .validTrend: try seedValidTrend(repository, calendar)
            case .noComparableData: try seedNoComparableData(repository, calendar)
            }
        } catch {
            assertionFailure("DebugFixtures seeding failed for \(fixture): \(error)")
        }
    }

    // MARK: - Week math
    //
    // Deliberately self-contained (not shared with `InsightsViewModel`,
    // whose equivalent logic is private) so this fixture file has no
    // dependency on Insights' internals — it only needs to agree with
    // `InsightsViewModel` on what "the most recent completed week" means,
    // which is defined once here in terms of the same public `LocalDay`
    // utility `InsightsViewModel` itself uses.

    private static func lastCompletedWeek(calendar: Calendar, asOf date: Date = Date()) -> DateInterval {
        let currentWeek = LocalDay.weekInterval(containing: date, calendar: calendar)
        let previousWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeek.start) ?? currentWeek.start
        return LocalDay.weekInterval(containing: previousWeekStart, calendar: calendar)
    }

    private static func weekBefore(_ week: DateInterval, calendar: Calendar) -> DateInterval {
        let start = calendar.date(byAdding: .weekOfYear, value: -1, to: week.start) ?? week.start
        return LocalDay.weekInterval(containing: start, calendar: calendar)
    }

    /// Noon on the `offset`-th day of `week`, clear of any DST transition
    /// that might fall at a day boundary.
    private static func day(_ offset: Int, in week: DateInterval, calendar: Calendar) -> Date {
        let midnight = calendar.date(byAdding: .day, value: offset, to: week.start) ?? week.start
        return midnight.addingTimeInterval(12 * 3600)
    }

    // MARK: - Fixtures

    private static func seedPopulated(_ repository: HabitRepository, _ calendar: Calendar) throws {
        let week = lastCompletedWeek(calendar: calendar)
        let createdAt = calendar.date(byAdding: .day, value: -90, to: week.start) ?? week.start

        let read = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book.fill", category: .learning, polarity: .positive, schedule: .daily),
            at: createdAt
        )
        for offset in 0...6 {
            try repository.recordCompletion(habitID: read.id, at: day(offset, in: week, calendar: calendar), source: .app, note: nil)
        }

        let walk = try repository.createHabit(
            HabitDraft(name: "Walk", iconName: "figure.walk", category: .fitness, polarity: .positive, schedule: .daily),
            at: createdAt
        )
        for offset in [0, 1, 2, 3] {
            try repository.recordCompletion(habitID: walk.id, at: day(offset, in: week, calendar: calendar), source: .app, note: nil)
        }

        let meditate = try repository.createHabit(
            HabitDraft(name: "Meditate", iconName: "leaf.fill", category: .mindfulness, polarity: .positive, schedule: .daily),
            at: createdAt
        )
        try repository.recordCompletion(habitID: meditate.id, at: day(0, in: week, calendar: calendar), source: .app, note: nil)
    }

    private static func seedBalancedIdentical(_ repository: HabitRepository, _ calendar: Calendar) throws {
        let week = lastCompletedWeek(calendar: calendar)
        let createdAt = calendar.date(byAdding: .day, value: -90, to: week.start) ?? week.start

        for name in ["Yoga", "Stretch"] {
            let habit = try repository.createHabit(
                HabitDraft(name: name, iconName: "figure.flexibility", category: .fitness, polarity: .positive, schedule: .daily),
                at: createdAt
            )
            for offset in [0, 1, 2, 3, 4] {
                try repository.recordCompletion(habitID: habit.id, at: day(offset, in: week, calendar: calendar), source: .app, note: nil)
            }
        }
    }

    private static func seedTiedExtremes(_ repository: HabitRepository, _ calendar: Calendar) throws {
        let week = lastCompletedWeek(calendar: calendar)
        let createdAt = calendar.date(byAdding: .day, value: -90, to: week.start) ?? week.start

        func makeHabit(_ name: String, completedOffsets: [Int]) throws {
            let habit = try repository.createHabit(
                HabitDraft(name: name, iconName: "star.fill", category: .other, polarity: .positive, schedule: .daily),
                at: createdAt
            )
            for offset in completedOffsets {
                try repository.recordCompletion(habitID: habit.id, at: day(offset, in: week, calendar: calendar), source: .app, note: nil)
            }
        }

        // "Run" and "Swim" tie for strongest at 7/7.
        try makeHabit("Run", completedOffsets: Array(0...6))
        try makeHabit("Swim", completedOffsets: Array(0...6))
        // "Floss" and "Journal" tie for needing attention at 1/7.
        try makeHabit("Floss", completedOffsets: [0])
        try makeHabit("Journal", completedOffsets: [0])
    }

    private static func seedValidTrend(_ repository: HabitRepository, _ calendar: Calendar) throws {
        let week = lastCompletedWeek(calendar: calendar)
        let previous = weekBefore(week, calendar: calendar)
        let createdAt = calendar.date(byAdding: .day, value: -90, to: previous.start) ?? previous.start

        let jog = try repository.createHabit(
            HabitDraft(name: "Jog", iconName: "figure.run", category: .fitness, polarity: .positive, schedule: .daily),
            at: createdAt
        )
        for offset in [0, 1, 2] {
            try repository.recordCompletion(habitID: jog.id, at: day(offset, in: previous, calendar: calendar), source: .app, note: nil)
        }
        for offset in [0, 1, 2, 3, 4, 5] {
            try repository.recordCompletion(habitID: jog.id, at: day(offset, in: week, calendar: calendar), source: .app, note: nil)
        }
    }

    private static func seedNoComparableData(_ repository: HabitRepository, _ calendar: Calendar) throws {
        let week = lastCompletedWeek(calendar: calendar)
        let previous = weekBefore(week, calendar: calendar)
        let createdAt = calendar.date(byAdding: .day, value: -90, to: previous.start) ?? previous.start

        let swim = try repository.createHabit(
            HabitDraft(name: "Swim", iconName: "figure.pool.swim", category: .fitness, polarity: .positive, schedule: .daily),
            at: createdAt
        )
        for offset in [0, 1, 2, 3, 4] {
            try repository.recordCompletion(habitID: swim.id, at: day(offset, in: previous, calendar: calendar), source: .app, note: nil)
        }
        // Schedule changes right at the start of the selected week: eligible
        // in both weeks independently, but not comparable between them.
        try repository.updateHabit(
            id: swim.id,
            with: HabitDraft(
                name: "Swim", iconName: "figure.pool.swim", category: .fitness, polarity: .positive, schedule: .timesPerWeek(3)
            ),
            at: week.start
        )
        for offset in [0, 1, 2] {
            try repository.recordCompletion(habitID: swim.id, at: day(offset, in: week, calendar: calendar), source: .app, note: nil)
        }
    }
}
#endif
