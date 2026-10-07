import Foundation
import SwiftData
import XCTest
@testable import Avela

@MainActor
final class TodayViewModelTests: XCTestCase {
    // A ModelContext does not keep its container alive; retain it for the test.
    private var container: ModelContainer?

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 1
        return calendar
    }()

    private let day0 = Date(timeIntervalSince1970: 1_718_632_800) // Mon 2024-06-17
    private func day(_ n: Int) -> Date { day0.addingTimeInterval(Double(n) * 86_400) }

    private func makeRepository() throws -> SwiftDataHabitRepository {
        let container = try AppPersistence.makeContainer(inMemory: true)
        self.container = container
        return SwiftDataHabitRepository(modelContext: container.mainContext, calendar: calendar)
    }

    func testConfirmationUndoIsIdempotentAndDoesNotLogAgain() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(HabitDraft(name: "Read", iconName: "book.fill", category: .other, polarity: .positive, schedule: .daily), at: day0)
        let completion = try repository.recordCompletion(habitID: habit.id, at: day0, source: .app, note: nil)
        let model = TodayViewModel(repository: repository, calendar: calendar)
        model.undoTodayCompletion(id: completion.id, habitID: habit.id, asOf: day0)
        model.undoTodayCompletion(id: completion.id, habitID: habit.id, asOf: day0)
        XCTAssertFalse(try XCTUnwrap(model.rows.first).isCompletedToday)
        XCTAssertTrue(try repository.completions(for: habit.id, in: DateInterval(start: day(-1), end: day(2))).isEmpty)
    }

    func testStaleConfirmationCannotChangeNextDaysCompletion() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(HabitDraft(name: "Read", iconName: "book.fill", category: .other, polarity: .positive, schedule: .daily), at: day0)
        let old = try repository.recordCompletion(habitID: habit.id, at: day0, source: .app, note: nil)
        let next = try repository.recordCompletion(habitID: habit.id, at: day(1), source: .app, note: nil)
        let model = TodayViewModel(repository: repository, calendar: calendar)
        model.undoTodayCompletion(id: old.id, habitID: habit.id, asOf: day(1))
        XCTAssertEqual(model.rows.first?.todaysCompletionID, next.id)
        XCTAssertEqual(Set(try repository.completions(for: habit.id, in: DateInterval(start: day(-1), end: day(2))).map(\.id)), Set([old.id, next.id]))
        model.undoTodayCompletion(id: next.id, habitID: habit.id, asOf: day(1))
        XCTAssertFalse(try XCTUnwrap(model.rows.first).isCompletedToday)
        model.undoTodayCompletion(id: old.id, habitID: habit.id, asOf: day(1))
        XCTAssertFalse(try XCTUnwrap(model.rows.first).isCompletedToday, "Old Undo must never become a fresh log")
    }

    func testCreationLimitBlocksNewHabitButPreservesTracking() throws {
        let repository = try makeRepository()
        let draft = HabitDraft(name: "Read", iconName: "book.fill", category: .other, polarity: .positive, schedule: .daily)
        let habit = try repository.createHabit(draft, at: day0)
        let model = TodayViewModel(repository: repository, calendar: calendar)
        model.creationAllowed = { _ in false }
        model.requestCreation()
        XCTAssertTrue(model.isShowingPremium)
        XCTAssertFalse(model.isShowingCreateHabit)
        model.createHabit(draft, asOf: day0)
        XCTAssertEqual(try repository.fetchHabits(includeArchived: false).count, 1)
        model.load(asOf: day0)
        model.toggleCompletion(for: try XCTUnwrap(model.rows.first), asOf: day0)
        XCTAssertEqual(model.rows.first?.id, habit.id)
        XCTAssertEqual(model.rows.first?.isCompletedToday, true)
    }

    func testCompletingSkippedDayRemovesExcusal() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(HabitDraft(name: "Read", iconName: "book.fill", category: .other, polarity: .positive, schedule: .daily), at: day0)
        _ = try repository.recordSkip(habitID: habit.id, on: day0, reason: .planned)
        let model = TodayViewModel(repository: repository, calendar: calendar)
        model.load(asOf: day0)
        XCTAssertTrue(try XCTUnwrap(model.rows.first).isSkippedToday)
        model.toggleCompletion(for: try XCTUnwrap(model.rows.first), asOf: day0)
        XCTAssertTrue(try XCTUnwrap(model.rows.first).isCompletedToday)
        XCTAssertFalse(try XCTUnwrap(model.rows.first).isSkippedToday)
    }

    func testFreshHabitHasNoRecoveryContext() throws {
        let repository = try makeRepository()
        _ = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book.fill", category: .other, polarity: .positive, schedule: .daily),
            at: day0
        )
        let viewModel = TodayViewModel(repository: repository, calendar: calendar)
        viewModel.load(asOf: day0)

        XCTAssertNil(viewModel.rows.first?.recoveryContext)
    }

    func testRecoveryContextShowsWhileRecoveringAndClearsAfterThreshold() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book.fill", category: .other, polarity: .positive, schedule: .daily),
            at: day0
        )
        // day0 (Monday) is missed (no completion); day(1)-day(3) are completed.
        try repository.recordCompletion(habitID: habit.id, at: day(1), source: .app, note: nil)
        try repository.recordCompletion(habitID: habit.id, at: day(2), source: .app, note: nil)
        try repository.recordCompletion(habitID: habit.id, at: day(3), source: .app, note: nil)

        let viewModel = TodayViewModel(repository: repository, calendar: calendar)

        viewModel.load(asOf: day(1))
        XCTAssertEqual(viewModel.rows.first?.recoveryContext, "1 of 3 good days")

        viewModel.load(asOf: day(3))
        XCTAssertNil(viewModel.rows.first?.recoveryContext, "recovery framing must stop once the 3-success threshold is reached")
    }

    func testRecoveryContextUsesWeeksForATimesPerWeekSchedule() throws {
        let repository = try makeRepository()
        // Created Sunday, week-aligned — mirrors
        // HabitProgressCalculatorTests.testFlexibleWeeklyUsesSuccessfulWeeksNotDailyStreaks,
        // whose day offsets are already verified against this calendar's
        // Sunday-first week boundaries.
        let habit = try repository.createHabit(
            HabitDraft(name: "Swim", iconName: "figure.pool.swim", category: .fitness, polarity: .positive, schedule: .timesPerWeek(2)),
            at: day(-1)
        )
        // Week 1 (Sun -1 ... Sat 5): no completions -> miss by its natural end.
        // Week 2 (Sun 6 ... Sat 12): 2 distinct days -> success, countable
        // even mid-week once the target is met.
        try repository.recordCompletion(habitID: habit.id, at: day(7), source: .app, note: nil)
        try repository.recordCompletion(habitID: habit.id, at: day(8), source: .app, note: nil)

        let viewModel = TodayViewModel(repository: repository, calendar: calendar)
        viewModel.load(asOf: day(8))

        XCTAssertEqual(viewModel.rows.first?.recoveryContext, "1 of 3 good weeks")
    }
    func testRecoveryCardCompositionAndExactUndoRestoreTwoCommitments() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(HabitDraft(name: "Read", iconName: "book.fill", category: .learning, polarity: .positive, schedule: .daily), at: day0)
        for offset in [2, 3] { try repository.recordCompletion(habitID: habit.id, at: day(offset), source: .app, note: nil) }
        let activity = SwiftDataHabitActivityRepository(context: try XCTUnwrap(container).mainContext, habits: repository, calendar: calendar)
        try activity.configure(habitID: habit.id, target: nil, smallerAction: "Read one paragraph", at: day0)
        let model = TodayViewModel(repository: repository, calendar: calendar)
        model.activityRepository = activity
        model.load(asOf: day(4))
        let before = try XCTUnwrap(model.rows.first)
        XCTAssertEqual(before.recovery?.completed, 2)
        XCTAssertEqual(before.recovery?.smallerAction, "Read one paragraph")
        XCTAssertEqual(before.recovery?.canMakeEasier, true)
        model.toggleCompletion(for: before, asOf: day(4))
        let completed = try XCTUnwrap(model.rows.first)
        XCTAssertNil(completed.recovery)
        model.undoTodayCompletion(id: try XCTUnwrap(completed.todaysCompletionID), habitID: habit.id, asOf: day(4))
        XCTAssertEqual(model.rows.first?.recovery?.completed, 2)
        XCTAssertEqual(try repository.configurationHistory(for: habit.id).count, 1)
    }

    func testMixedScheduleRecoveryIsLabeledAsCommitments() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(HabitDraft(name: "Read", iconName: "book.fill", category: .learning, polarity: .positive, schedule: .daily), at: day0)
        try repository.recordCompletion(habitID: habit.id, at: day(1), source: .app, note: nil)
        _ = try repository.updateHabit(id: habit.id, with: HabitDraft(name: habit.name, iconName: habit.iconName, category: habit.category, polarity: habit.polarity, schedule: .timesPerWeek(2)), at: day(2))
        let model = TodayViewModel(repository: repository, calendar: calendar)
        model.load(asOf: day(2))
        XCTAssertEqual(model.rows.first?.recovery?.progressLabel, "1 of 3 good commitments")
    }

    func testAvoidanceRecoveryOffersNoPositiveHabitTools() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(HabitDraft(name: "Less scrolling", iconName: "iphone", category: .other, polarity: .avoidance, schedule: .daily), at: day0)
        let activity = SwiftDataHabitActivityRepository(context: try XCTUnwrap(container).mainContext, habits: repository, calendar: calendar)
        try activity.configure(habitID: habit.id, target: nil, smallerAction: "Put phone away", at: day0)
        let model = TodayViewModel(repository: repository, calendar: calendar)
        model.activityRepository = activity
        model.load(asOf: day(2))
        XCTAssertNotNil(model.rows.first?.recovery)
        XCTAssertNil(model.rows.first?.recovery?.smallerAction)
        XCTAssertEqual(model.rows.first?.recovery?.canMakeEasier, false)
    }

}
