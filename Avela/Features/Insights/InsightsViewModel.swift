import Foundation
import OSLog
import Observation

/// Feature state for the read-only weekly habit Insights screen. Fetches
/// once per load — one habits fetch, one cross-habit completions fetch and
/// one cross-habit skips fetch scoped to the two weeks under review, and one
/// configuration-history and archive-period fetch per habit (not per row) —
/// then hands the result to `WeeklyInsightsCalculator` for aggregation. Never
/// mutates facts. Manually reported attention and weekday patterns are
/// computed separately from habit consistency.
@MainActor
@Observable
final class InsightsViewModel {
    private(set) var habitIcons: [UUID: String] = [:]
    private(set) var insights: WeeklyInsightsCalculator.WeeklyInsights?
    private(set) var weekRangeLabel: String = ""
    private(set) var hasAnyHabits = false
    private(set) var hasAnyAttentionGoals = false
    private(set) var hasAnyAttentionBudgets = false
    private(set) var attentionWeek: SupplementalWeeklyInsightsCalculator.AttentionWeek?
    private(set) var weekdayPattern: SupplementalWeeklyInsightsCalculator.WeekdayPattern?
    var hasAnyGoals: Bool { hasAnyHabits || hasAnyAttentionGoals }

    func weekdayNames(_ weekdays: [Int]) -> String {
        weekdays.map { calendar.weekdaySymbols[$0 - 1] }.joined(separator: " and ")
    }
    private(set) var canGoToNextWeek = false
    var errorMessage: String?

    /// How many completed weeks before the most recent completed week is
    /// currently shown. `0` is the default: the most recent week that has
    /// fully elapsed. Insights never shows the in-progress current week.
    private var weeksBeforeLastCompleted = 0

    private let repository: HabitRepository
    private let attentionRepository: AttentionRepository?
    private let intentionLinks: IntentionSessionLinkRepository?
    private let calendar: Calendar
    private static let logger = Logger(subsystem: "com.example.Avela", category: "InsightsViewModel")
    private static let friendlyErrorMessage = "Something went wrong. Please try again."

    init(repository: HabitRepository, attentionRepository: AttentionRepository? = nil, intentionLinks: IntentionSessionLinkRepository? = nil, calendar: Calendar = .autoupdatingCurrent) {
        self.repository = repository
        self.attentionRepository = attentionRepository
        self.intentionLinks = intentionLinks
        self.calendar = calendar
    }

    func load(asOf date: Date = Date()) {
        do {
            let habits = try repository.fetchHabits(includeArchived: true)
            hasAnyHabits = !habits.isEmpty
            habitIcons = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0.iconName) })

            let weekInterval = Self.weekInterval(weeksBeforeLastCompleted: weeksBeforeLastCompleted, asOf: date, calendar: calendar)
            let previousWeekInterval = Self.weekInterval(
                weeksBeforeLastCompleted: weeksBeforeLastCompleted + 1, asOf: date, calendar: calendar
            )
            canGoToNextWeek = weeksBeforeLastCompleted > 0
            weekRangeLabel = Self.rangeLabel(for: weekInterval, calendar: calendar)

            let combinedRange = DateInterval(start: previousWeekInterval.start, end: weekInterval.end)
            let completions = try repository.completions(in: combinedRange)
            let skips = try repository.skips(in: combinedRange)

            var snapshotsByHabitID: [UUID: [HabitConfigurationSnapshot]] = [:]
            var archivePeriodsByHabitID: [UUID: [HabitArchivePeriod]] = [:]
            for habit in habits {
                snapshotsByHabitID[habit.id] = try repository.configurationHistory(for: habit.id)
                archivePeriodsByHabitID[habit.id] = try repository.archivePeriods(for: habit.id)
            }

            insights = WeeklyInsightsCalculator.weeklyInsights(
                habits: habits,
                snapshotsByHabitID: snapshotsByHabitID,
                completions: completions,
                skips: skips,
                archivePeriodsByHabitID: archivePeriodsByHabitID,
                weekInterval: weekInterval,
                previousWeekInterval: previousWeekInterval,
                asOf: date,
                calendar: calendar
            )
            weekdayPattern = SupplementalWeeklyInsightsCalculator.weekdayPattern(
                habits: habits, snapshotsByHabitID: snapshotsByHabitID,
                completions: completions, skips: skips, archivePeriodsByHabitID: archivePeriodsByHabitID,
                interval: weekInterval, asOf: date, calendar: calendar
            )
            if let attentionRepository {
                let goals = try attentionRepository.fetchGoals()
                hasAnyAttentionGoals = !goals.isEmpty
                hasAnyAttentionBudgets = goals.contains { $0.type == .maxDurationPerDay }
                var snapshots: [UUID: [AttentionGoalConfigurationSnapshot]] = [:]
                for goal in goals { snapshots[goal.id] = try attentionRepository.configurationHistory(for: goal.id) }
                attentionWeek = SupplementalWeeklyInsightsCalculator.attentionWeek(
                    goals: goals, snapshotsByGoalID: snapshots,
                    entries: try attentionRepository.usageEntries(in: weekInterval),
                    interval: weekInterval, calendar: calendar
                )
            }
            errorMessage = nil
        } catch {
            handle(error)
        }
    }

    func goToPreviousWeek(asOf date: Date = Date()) {
        weeksBeforeLastCompleted += 1
        load(asOf: date)
    }

    func habitDetailModel(for id: UUID) -> HabitDetailViewModel {
        HabitDetailViewModel(habitID: id, repository: repository, calendar: calendar)
    }

    func reflectionModel(repository reflections: ReflectionRepository) -> ReflectionViewModel {
        ReflectionViewModel(repository: reflections, habits: repository, calendar: calendar,
                            now: insights?.weekInterval.start ?? Date())
    }

    var hasMadeRoomReview: Bool { attentionRepository != nil && intentionLinks != nil && insights != nil }

    /// Captures the selected completed review week, rather than resetting to today.
    func madeRoomModel() -> MadeRoomReviewViewModel? {
        guard let attentionRepository, let intentionLinks, let interval = insights?.weekInterval else { return nil }
        return MadeRoomReviewViewModel(habits: repository, attention: attentionRepository,
                                       links: intentionLinks, interval: interval, calendar: calendar)
    }

    func goToNextWeek(asOf date: Date = Date()) {
        guard weeksBeforeLastCompleted > 0 else { return }
        weeksBeforeLastCompleted -= 1
        load(asOf: date)
    }

    private func handle(_ error: Error) {
        Self.logger.error("Insights view model operation failed: \(String(describing: error), privacy: .private)")
        errorMessage = Self.friendlyErrorMessage
    }

    /// The local calendar week `weeksBeforeLastCompleted` weeks before the
    /// most recent *completed* week (`0` = the week immediately before the
    /// one `date` currently falls in). Uses `Calendar`'s own `.weekOfYear`
    /// arithmetic and `LocalDay.weekInterval`, both of which account for
    /// daylight-saving transitions, so a shifted week's boundaries are always
    /// the correct local calendar days even across a DST change.
    private static func weekInterval(weeksBeforeLastCompleted: Int, asOf date: Date, calendar: Calendar) -> DateInterval {
        let currentWeek = LocalDay.weekInterval(containing: date, calendar: calendar)
        let shift = -(weeksBeforeLastCompleted + 1)
        let shiftedDate = calendar.date(byAdding: .weekOfYear, value: shift, to: currentWeek.start) ?? currentWeek.start
        return LocalDay.weekInterval(containing: shiftedDate, calendar: calendar)
    }

    private static func rangeLabel(for interval: DateInterval, calendar: Calendar) -> String {
        let formatter = DateIntervalFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        // `interval.end` is the exclusive midnight starting the *next* week;
        // the label must show the week's actual last day.
        let lastDay = interval.end.addingTimeInterval(-1)
        return formatter.string(from: interval.start, to: lastDay)
    }
}
