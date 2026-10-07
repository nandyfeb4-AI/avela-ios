import SwiftData
import UserNotifications
import XCTest
@testable import Avela

@MainActor
final class ReminderActionTests: XCTestCase {
    private var container: ModelContainer!
    private var habits: SwiftDataHabitRepository!
    private var calendar: Calendar!
    private var date: Date!
    private var handler: ReminderActionHandler!

    override func setUpWithError() throws {
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Denver")!
        date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 12))!
        container = try AppPersistence.makeContainer(inMemory: true)
        habits = SwiftDataHabitRepository(modelContext: container.mainContext, calendar: calendar)
        handler = ReminderActionHandler(habits: habits, calendar: calendar)
    }
    private var range: DateInterval { calendar.dateInterval(of: .day, for: date)! }
    private func habit(polarity: HabitPolarity = .positive, schedule: HabitSchedule = .daily) throws -> Habit {
        try habits.createHabit(HabitDraft(name: "Read", iconName: "book.fill", category: .learning,
            polarity: polarity, schedule: schedule), at: range.start)
    }
    private func action(_ habit: Habit, deliveredAt: Date? = nil) -> HabitReminderAction {
        HabitReminderAction(habitID: habit.id, deliveredAt: deliveredAt ?? date)
    }

    func testExplicitSuccessLogsNotificationSourceAndRepeatedTapsDoNotToggle() throws {
        let habit = try habit()
        XCTAssertEqual(try handler.handle(action(habit), at: date), .logged)
        XCTAssertEqual(try handler.handle(action(habit), at: date), .alreadyLogged)
        let rows = try habits.completions(for: habit.id, in: range)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.source, .notification)
    }
    func testExistingManualCompletionIsPreserved() throws {
        let habit = try habit()
        let original = try habits.recordCompletion(habitID: habit.id, at: date, source: .app, note: "Original")
        XCTAssertEqual(try handler.handle(action(habit), at: date), .alreadyLogged)
        XCTAssertEqual(try habits.completions(for: habit.id, in: range), [original])
    }
    func testOldAndFutureRemindersDoNotWrite() throws {
        let habit = try habit()
        for delivery in [range.start.addingTimeInterval(-1), date.addingTimeInterval(1)] {
            XCTAssertEqual(try handler.handle(action(habit, deliveredAt: delivery), at: date), .expired)
        }
        XCTAssertTrue(try habits.completions(in: range).isEmpty)
    }
    func testSameLocalDayAcrossDSTFallbackUsesCalendarNot24Hours() throws {
        let habit = try habit()
        XCTAssertEqual(range.duration, 25 * 3600)
        XCTAssertEqual(try handler.handle(action(habit, deliveredAt: range.start), at: range.end.addingTimeInterval(-1)), .logged)
    }
    func testArchivedUnknownNonDueAndNotYetCreatedHabitsDoNotWrite() throws {
        let archived = try habit()
        try habits.archiveHabit(id: archived.id, at: date)
        let monday = try habit(schedule: .weekdays([.monday]))
        for id in [archived.id, monday.id, UUID()] {
            XCTAssertEqual(try handler.handle(HabitReminderAction(habitID: id, deliveredAt: date), at: date), .unavailable)
        }
        let new = try habits.createHabit(HabitDraft(name: "New", iconName: "book.fill", category: .learning, polarity: .positive, schedule: .daily), at: date)
        XCTAssertEqual(try handler.handle(action(new, deliveredAt: date.addingTimeInterval(-1)), at: date), .unavailable)
        XCTAssertTrue(try habits.completions(in: range).isEmpty)
    }
    func testExplicitAvoidanceSuccessReplacesSkipWithoutClaimingAbstinence() throws {
        let habit = try habit(polarity: .avoidance)
        try habits.recordSkip(habitID: habit.id, on: date, reason: .planned)
        XCTAssertEqual(try handler.handle(action(habit), at: date), .logged)
        XCTAssertTrue(try habits.skips(for: habit.id, in: range).isEmpty)
        XCTAssertEqual(try habits.completions(for: habit.id, in: range).first?.source, .notification)
    }
    func testFlexibleWeeklyHabitCanLogOncePerLocalDay() throws {
        let habit = try habit(schedule: .timesPerWeek(3))
        XCTAssertEqual(try handler.handle(action(habit), at: date), .logged)
        XCTAssertEqual(try handler.handle(action(habit), at: date), .alreadyLogged)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date)!
        XCTAssertEqual(try handler.handle(action(habit, deliveredAt: tomorrow), at: tomorrow), .logged)
    }
    func testPayloadRequiresOwnedCategoryExplicitActionMatchingIdentityAndKnownSuffix() {
        let id = UUID()
        let prefix = HabitReminderPlanner.identifierPrefix + id.uuidString + "."
        func parse(_ action: String = "avela.habit-reminder.log", _ category: String = "avela.habit-reminder.actions", _ identifier: String? = nil, _ habitID: String? = nil) -> HabitReminderAction? {
            HabitReminderAction.parse(action: action, category: category, identifier: identifier ?? prefix + "daily", habitID: habitID ?? id.uuidString, deliveredAt: date)
        }
        XCTAssertEqual(parse()?.habitID, id)
        XCTAssertNotNil(parse("avela.habit-reminder.log", "avela.habit-reminder.actions", prefix + "7"))
        XCTAssertNil(parse(UNNotificationDefaultActionIdentifier))
        XCTAssertNil(parse(UNNotificationDismissActionIdentifier))
        XCTAssertNil(parse("unexpected"))
        XCTAssertNil(parse("avela.habit-reminder.log", "other.category"))
        XCTAssertNil(parse("avela.habit-reminder.log", "avela.habit-reminder.actions", prefix + "8"))
        XCTAssertNil(parse("avela.habit-reminder.log", "avela.habit-reminder.actions", nil, UUID().uuidString))
        XCTAssertNil(parse("avela.habit-reminder.log", "avela.habit-reminder.actions", nil, "invalid"))
    }
    func testReviewDoesNotWriteAndConfirmRechecksArchiveState() throws {
        let habit = try habit()
        let response = action(habit)
        XCTAssertNil(try handler.validate(response, at: date))
        XCTAssertTrue(try habits.completions(in: range).isEmpty)
        try habits.archiveHabit(id: habit.id, at: date)
        XCTAssertEqual(try handler.handle(response, at: date), .unavailable)
        XCTAssertTrue(try habits.completions(in: range).isEmpty)
    }

    func testConfirmationAfterMidnightCannotApplyYesterdaysReminderToToday() throws {
        let habit = try habit()
        let delivery = range.end.addingTimeInterval(-1)
        let response = action(habit, deliveredAt: delivery)
        XCTAssertNil(try handler.validate(response, at: delivery))
        XCTAssertEqual(try handler.handle(response, at: range.end), .expired)
        XCTAssertTrue(try habits.completions(in: range).isEmpty)
    }

    func testNativeCategoryRequiresUnlockAndForegroundReviewWithoutDestructiveAction() {
        let category = UserNotificationAdapter.habitCategory
        XCTAssertEqual(category.actions.count, 1)
        let action = category.actions[0]
        XCTAssertEqual(action.title, "Review & log")
        XCTAssertTrue(action.options.contains(.authenticationRequired))
        XCTAssertTrue(action.options.contains(.foreground))
        XCTAssertFalse(action.options.contains(.destructive))
    }
}
