import Foundation
import SwiftData
import XCTest
@testable import Avela

@MainActor
final class InsightsViewModelTests: XCTestCase {
    // A ModelContext does not keep its container alive; retain it for the test.
    private var container: ModelContainer?

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 1
        return calendar
    }()

    private let day0 = Date(timeIntervalSince1970: 1_718_632_800) // Mon 2024-06-17, 10:00 EDT
    private func day(_ n: Int) -> Date { day0.addingTimeInterval(Double(n) * 86_400) }

    private func makeRepository() throws -> SwiftDataHabitRepository {
        let container = try AppPersistence.makeContainer(inMemory: true)
        self.container = container
        return SwiftDataHabitRepository(modelContext: container.mainContext, calendar: calendar)
    }

    func testDefaultsToLastCompletedWeekExcludingTheCurrentInProgressWeek() throws {
        let repository = try makeRepository()
        let now = day(3) // Thu 2024-06-20, inside the week of Jun 16-22.
        let currentWeek = LocalDay.weekInterval(containing: now, calendar: calendar)
        let lastCompletedWeekStart = try XCTUnwrap(calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeek.start))
        let lastCompletedWeek = LocalDay.weekInterval(containing: lastCompletedWeekStart, calendar: calendar)
        XCTAssertNotEqual(lastCompletedWeek, currentWeek, "sanity check: the fixture dates really do fall in two different weeks")

        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book", category: .other, polarity: .positive, schedule: .daily),
            at: try XCTUnwrap(calendar.date(byAdding: .day, value: -30, to: lastCompletedWeek.start))
        )
        // One completion on the first day of the last completed week.
        try repository.recordCompletion(habitID: habit.id, at: lastCompletedWeek.start.addingTimeInterval(3600), source: .app, note: nil)
        // A completion logged "today" (inside the current, still-open week)
        // must not be able to influence the default (last completed) week.
        try repository.recordCompletion(habitID: habit.id, at: now, source: .app, note: nil)

        let viewModel = InsightsViewModel(repository: repository, calendar: calendar)
        viewModel.load(asOf: now)

        XCTAssertEqual(viewModel.insights?.weekInterval, lastCompletedWeek)
        XCTAssertTrue(viewModel.hasAnyHabits)
        XCTAssertEqual(viewModel.insights?.eligibleHabits.first?.scheduledUnits, 7)
        XCTAssertEqual(
            viewModel.insights?.eligibleHabits.first?.successfulUnits, 1,
            "today's completion must not leak into the completed week's own tally"
        )
    }

    func testGoToPreviousWeekAndBackClampsAtTheLastCompletedWeek() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book", category: .other, polarity: .positive, schedule: .daily), at: day(-21)
        )
        try repository.recordCompletion(habitID: habit.id, at: day(-21), source: .app, note: nil)
        let now = day(3)

        let viewModel = InsightsViewModel(repository: repository, calendar: calendar)
        viewModel.load(asOf: now)
        let lastCompletedWeek = try XCTUnwrap(viewModel.insights?.weekInterval)
        XCTAssertFalse(viewModel.canGoToNextWeek, "the default view is already the most recent completed week")

        viewModel.goToPreviousWeek(asOf: now)
        let earlierWeek = try XCTUnwrap(viewModel.insights?.weekInterval)
        XCTAssertLessThan(earlierWeek.start, lastCompletedWeek.start)
        XCTAssertTrue(viewModel.canGoToNextWeek)

        viewModel.goToNextWeek(asOf: now)
        XCTAssertEqual(viewModel.insights?.weekInterval, lastCompletedWeek)
        XCTAssertFalse(viewModel.canGoToNextWeek)

        // Already at the most recent completed week: going "next" again must
        // be a no-op, never advancing into the in-progress current week.
        viewModel.goToNextWeek(asOf: now)
        XCTAssertEqual(viewModel.insights?.weekInterval, lastCompletedWeek)
    }

    func testHasAnyHabitsIsFalseWhenNoHabitsExist() throws {
        let repository = try makeRepository()
        let viewModel = InsightsViewModel(repository: repository, calendar: calendar)
        viewModel.load(asOf: day(3))

        XCTAssertFalse(viewModel.hasAnyHabits)
        XCTAssertNil(viewModel.insights?.overallConsistency)
    }

    func testInsufficientDataStateWhenHabitsExistButNoneEligibleThisWeek() throws {
        let repository = try makeRepository()
        // Created "today," inside the current in-progress week: it has no
        // resolved units in the last *completed* week at all.
        try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book", category: .other, polarity: .positive, schedule: .daily), at: day(3)
        )

        let viewModel = InsightsViewModel(repository: repository, calendar: calendar)
        viewModel.load(asOf: day(3))

        XCTAssertTrue(viewModel.hasAnyHabits, "a habit does exist — this must read as 'not enough data,' not 'no habits yet'")
        XCTAssertNil(viewModel.insights?.overallConsistency)
        XCTAssertEqual(viewModel.insights?.eligibleHabits.isEmpty, true)
    }

    func testReloadingAfterANewCompletionIsRecordedReflectsIt() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book", category: .other, polarity: .positive, schedule: .daily), at: day(-7)
        )
        let now = day(3)

        let viewModel = InsightsViewModel(repository: repository, calendar: calendar)
        viewModel.load(asOf: now)
        XCTAssertEqual(viewModel.insights?.eligibleHabits.first?.successfulUnits, 0)

        try repository.recordCompletion(habitID: habit.id, at: day(-7), source: .app, note: nil)
        viewModel.load(asOf: now)
        XCTAssertEqual(viewModel.insights?.eligibleHabits.first?.successfulUnits, 1, "a reload must pick up a completion recorded since the last load, never cache a stale result")
    }

    /// The US spring-forward transition (2024-03-10) falls on a Sunday, which
    /// is itself the first day of a `firstWeekday = 1` calendar week — so the
    /// "last completed week" as of a few days later is exactly the week
    /// containing the transition. That week has only 7×24 - 1 hours of
    /// elapsed time, but must still resolve as 7 local calendar days, proving
    /// `InsightsViewModel`'s own week-shifting arithmetic (`Calendar
    /// .weekOfYear` plus `LocalDay.weekInterval`) is DST-safe end to end, not
    /// just within `LocalDay` itself (already covered by `LocalDayTests`).
    func testWeekContainingADaylightSavingTransitionStillCountsSevenLocalDays() throws {
        let repository = try makeRepository()
        let transitionDay = Date(timeIntervalSince1970: 1_710_051_000) // 2024-03-10, 01:10 EST (a Sunday)
        let weekStart = calendar.startOfDay(for: transitionDay)
        XCTAssertEqual(LocalDay.key(for: weekStart, calendar: calendar), "2024-03-10")

        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book", category: .other, polarity: .positive, schedule: .daily),
            at: calendar.date(byAdding: .day, value: -30, to: weekStart)!
        )
        for offset in 0...6 {
            let day = calendar.date(byAdding: .day, value: offset, to: weekStart)!.addingTimeInterval(12 * 3600) // noon, clear of the 2 AM transition
            try repository.recordCompletion(habitID: habit.id, at: day, source: .app, note: nil)
        }

        let now = calendar.date(byAdding: .day, value: 10, to: weekStart)! // well into the following week
        let viewModel = InsightsViewModel(repository: repository, calendar: calendar)
        viewModel.load(asOf: now)

        XCTAssertEqual(viewModel.insights?.eligibleHabits.first?.scheduledUnits, 7, "the transition week must still resolve as 7 local days")
        XCTAssertEqual(viewModel.insights?.eligibleHabits.first?.successfulUnits, 7)
        XCTAssertEqual(viewModel.insights?.overallConsistency, 1.0)
    }
    func testAttentionOnlyUserCanReviewCompletedWeekWithExplicitCoverage() throws {
        let repository = try makeRepository()
        let attention = SwiftDataAttentionRepository(modelContext: try XCTUnwrap(container).mainContext, calendar: calendar)
        let now = day(3)
        let currentWeek = LocalDay.weekInterval(containing: now, calendar: calendar)
        let previousStart = try XCTUnwrap(calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeek.start))
        let goal = try attention.createGoal(AttentionGoalDraft(name: "News", appOrCategoryLabel: nil,
            type: .maxDurationPerDay, targetValue: 30, unit: .minutes), at: previousStart)
        _ = try attention.recordUsage(goalID: goal.id, amount: 10, at: previousStart.addingTimeInterval(3600), source: .manual)
        // Today's report must not enter last week's coverage.
        _ = try attention.recordUsage(goalID: goal.id, amount: 40, at: now, source: .manual)
        let model = InsightsViewModel(repository: repository, attentionRepository: attention, calendar: calendar)
        model.load(asOf: now)
        XCTAssertFalse(model.hasAnyHabits)
        XCTAssertTrue(model.hasAnyGoals)
        XCTAssertTrue(model.hasAnyAttentionGoals)
        XCTAssertEqual(model.attentionWeek?.loggedGoalDays, 1)
        XCTAssertEqual(model.attentionWeek?.eligibleGoalDays, 7)
        XCTAssertEqual(model.attentionWeek?.successRate, 1)
        XCTAssertNil(model.insights?.overallConsistency)
        model.goToPreviousWeek(asOf: now)
        XCTAssertNil(model.attentionWeek?.successRate)
        XCTAssertEqual(model.attentionWeek?.eligibleGoalDays, 0)
    }

    func testArchivedHabitBreakdownKeepsIdentityAndDetailNavigationDoesNotWrite() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(HabitDraft(name: "Read", iconName: "book.fill", category: .learning, polarity: .positive, schedule: .daily), at: day(-7))
        let completion = try repository.recordCompletion(habitID: habit.id, at: day(-4), source: .app, note: nil)
        try repository.archiveHabit(id: habit.id, at: day(0))
        let model = InsightsViewModel(repository: repository, calendar: calendar)
        model.load(asOf: day(3))
        let summary = try XCTUnwrap(model.insights?.eligibleHabits.first)
        XCTAssertTrue(summary.isArchived)
        XCTAssertEqual(summary.successfulUnits, 1)
        XCTAssertEqual(model.habitIcons[habit.id], "book.fill")
        let detail = model.habitDetailModel(for: habit.id)
        detail.load(asOf: day(3))
        XCTAssertTrue(try XCTUnwrap(detail.display).isArchived)
        XCTAssertEqual(try repository.completions(for: habit.id, in: DateInterval(start: day(-10), end: day(4))).map(\.id), [completion.id])
        XCTAssertEqual(try repository.configurationHistory(for: habit.id).count, 1)
    }

    func testSessionOnlyReviewDoesNotInventAnAttentionBudget() throws {
        let repository = try makeRepository()
        let attention = SwiftDataAttentionRepository(modelContext: try XCTUnwrap(container).mainContext, calendar: calendar)
        _ = try attention.createGoal(AttentionGoalDraft(name: "Reading space", appOrCategoryLabel: nil, type: .phoneFreeSession, targetValue: 15, unit: .minutes), at: day(-7))
        let model = InsightsViewModel(repository: repository, attentionRepository: attention, calendar: calendar)
        model.load(asOf: day(3))
        XCTAssertTrue(model.hasAnyGoals)
        XCTAssertTrue(model.hasAnyAttentionGoals)
        XCTAssertFalse(model.hasAnyAttentionBudgets)
        XCTAssertNil(model.attentionWeek?.successRate)
    }

}
