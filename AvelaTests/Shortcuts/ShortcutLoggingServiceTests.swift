import SwiftData
import XCTest
@testable import Avela

@MainActor
final class ShortcutLoggingServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var habits: SwiftDataHabitRepository!
    private var attention: SwiftDataAttentionRepository!
    private var service: ShortcutLoggingService!
    private var calendar: Calendar!
    private var date: Date!

    override func setUpWithError() throws {
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 12))!
        container = try AppPersistence.makeContainer(inMemory: true)
        habits = SwiftDataHabitRepository(modelContext: container.mainContext, calendar: calendar)
        attention = SwiftDataAttentionRepository(modelContext: container.mainContext, calendar: calendar)
        service = ShortcutLoggingService(habits: habits, attention: attention, calendar: calendar)
    }

    private var range: DateInterval { calendar.dateInterval(of: .day, for: date)! }
    private func habit(schedule: HabitSchedule = .daily) throws -> Habit {
        try habits.createHabit(HabitDraft(name: "Read", iconName: "book.fill", category: .learning,
            polarity: .positive, schedule: schedule), at: date)
    }
    private func budget(type: AttentionGoalType = .maxDurationPerDay) throws -> AttentionGoal {
        try attention.createGoal(AttentionGoalDraft(name: "Social media", type: type,
            targetValue: 30, unit: .minutes), at: date)
    }

    func testHabitCompletionIsIdempotentAndRecordsShortcutSource() throws {
        let habit = try habit()
        XCTAssertTrue(try service.completeHabit(id: habit.id, at: date))
        XCTAssertFalse(try service.completeHabit(id: habit.id, at: date))
        let entries = try habits.completions(for: habit.id, in: range)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.source, .shortcutFuture)
    }

    func testAlreadyAppCompletedHabitIsNotUndoneOrReplaced() throws {
        let habit = try habit()
        let original = try habits.recordCompletion(habitID: habit.id, at: date, source: .app, note: nil)
        XCTAssertFalse(try service.completeHabit(id: habit.id, at: date))
        XCTAssertEqual(try habits.completions(for: habit.id, in: range), [original])
    }

    func testCompletionReplacesExcusedSkip() throws {
        let habit = try habit()
        try habits.recordSkip(habitID: habit.id, on: date, reason: .planned)
        XCTAssertTrue(try service.completeHabit(id: habit.id, at: date))
        XCTAssertTrue(try habits.skips(for: habit.id, in: range).isEmpty)
    }

    func testArchivedUnknownAndNonDueHabitsCannotBeLogged() throws {
        let archived = try habit()
        try habits.archiveHabit(id: archived.id, at: date)
        let monday = try habit(schedule: .weekdays([.monday]))
        for id in [archived.id, UUID(), monday.id] {
            XCTAssertThrowsError(try service.completeHabit(id: id, at: date))
        }
        XCTAssertTrue(try habits.completions(in: range).isEmpty)
    }

    func testSameNamesRemainSeparateSelectedIdentities() throws {
        let first = try habit()
        let second = try habit()
        XCTAssertTrue(try service.completeHabit(id: second.id, at: date))
        XCTAssertTrue(try habits.completions(for: first.id, in: range).isEmpty)
        XCTAssertEqual(try habits.completions(for: second.id, in: range).count, 1)
    }

    func testWeeklyHabitLogsAtMostOnceEachDayButCanLogNextDay() throws {
        let habit = try habit(schedule: .timesPerWeek(3))
        XCTAssertTrue(try service.completeHabit(id: habit.id, at: date))
        XCTAssertFalse(try service.completeHabit(id: habit.id, at: date))
        XCTAssertTrue(try service.completeHabit(id: habit.id, at: calendar.date(byAdding: .day, value: 1, to: date)!))
    }

    func testMinutesAreAdditiveManualRecordsAndEditableThroughExistingRepository() throws {
        let goal = try budget()
        try service.logMinutes(5, goalID: goal.id, at: date)
        try service.logMinutes(15, goalID: goal.id, at: date)
        let entries = try attention.usageEntries(for: goal.id, in: range)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.reduce(0) { $0 + $1.amount }, 20)
        XCTAssertTrue(entries.allSatisfy { $0.source == .manual })
        try attention.deleteUsageEntry(id: entries[0].id)
        XCTAssertEqual(try attention.usageEntries(for: goal.id, in: range).count, 1)
    }

    func testInvalidMinutesAndNonBudgetGoalsDoNotWrite() throws {
        let goal = try budget()
        for amount in [0, -1, 1441, Double.infinity, Double.nan] {
            XCTAssertThrowsError(try service.logMinutes(amount, goalID: goal.id, at: date))
        }
        let session = try budget(type: .phoneFreeSession)
        XCTAssertThrowsError(try service.logMinutes(5, goalID: session.id, at: date))
        XCTAssertThrowsError(try service.logMinutes(5, goalID: UUID(), at: date))
        XCTAssertTrue(try attention.usageEntries(in: range).isEmpty)
    }
}
