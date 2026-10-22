import Foundation
import SwiftData
import XCTest
@testable import Avela

@MainActor
final class TodayQuickAmountTests: XCTestCase {
    private var store: ModelContainer!
    private var habits: SwiftDataHabitRepository!
    private var activity: SwiftDataHabitActivityRepository!
    private var model: TodayViewModel!
    private var presets: HabitQuickLogPresets!
    private var defaultsSuite: String!
    private let now = Date(timeIntervalSince1970: 1_718_632_800)
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    override func setUpWithError() throws {
        store = try AppPersistence.makeContainer(inMemory: true)
        habits = SwiftDataHabitRepository(modelContext: store.mainContext, calendar: calendar)
        activity = SwiftDataHabitActivityRepository(context: store.mainContext, habits: habits, calendar: calendar)
        defaultsSuite = "TodayQuickAmountTests." + UUID().uuidString
        presets = HabitQuickLogPresets(defaults: try XCTUnwrap(UserDefaults(suiteName: defaultsSuite)))
        model = TodayViewModel(repository: habits, calendar: calendar, presets: presets)
        model.activityRepository = activity
    }

    override func tearDownWithError() throws {
        model = nil
        presets = nil
        activity = nil
        habits = nil
        store = nil
        UserDefaults.standard.removePersistentDomain(forName: defaultsSuite)
    }

    private func create(_ name: String = "Read", amount: Int = 5, unit: HabitQuantityUnit = .pages,
                        at date: Date? = nil) throws -> Habit {
        let habit = try habits.createHabit(.init(name: name, iconName: "book.fill", category: .learning,
            polarity: .positive, schedule: .daily, quantityTarget: .init(amount: amount, unit: unit),
            smallerAction: "One paragraph"), at: date ?? now)
        try presets.save([2, 1], for: habit.id, unit: unit)
        return habit
    }

    private func row(_ habit: Habit, at date: Date? = nil) throws -> TodayHabitRow {
        model.load(asOf: date ?? now)
        return try XCTUnwrap(model.rows.first { $0.id == habit.id })
    }

    private func completions(_ habit: Habit, at date: Date? = nil) throws -> [Completion] {
        try habits.completions(for: habit.id, in: XCTUnwrap(calendar.dateInterval(of: .day, for: date ?? now)))
    }

    func testFirstSavedPresetLogsRealPartialProgressWithoutCompletingHabit() throws {
        let habit = try create()
        let displayed = try row(habit)
        XCTAssertEqual(displayed.quickAmount, 2)
        XCTAssertEqual(displayed.quantityTarget, .init(amount: 5, unit: .pages))
        let entry = try XCTUnwrap(model.logQuickAmount(for: displayed, asOf: now))
        XCTAssertEqual(entry.amount, 2)
        XCTAssertEqual(entry.unit, .pages)
        XCTAssertEqual(entry.configurationID, displayed.activityConfigurationID)
        XCTAssertEqual(try activity.entries(for: habit.id, on: now).map(\.id), [entry.id])
        XCTAssertEqual(model.rows.first?.quantityProgress, "2 of 5 pages")
        XCTAssertFalse(try XCTUnwrap(model.rows.first).isCompletedToday)
        XCTAssertTrue(try completions(habit).isEmpty)
    }

    func testReachingTargetThenExactUndoPreservesEarlierQuantityAndWithdrawsGeneratedSuccess() throws {
        let habit = try create(amount: 4)
        let first = try XCTUnwrap(model.logQuickAmount(for: row(habit), asOf: now))
        let second = try XCTUnwrap(model.logQuickAmount(for: row(habit), asOf: now))
        XCTAssertTrue(try XCTUnwrap(model.rows.first).isCompletedToday)
        XCTAssertEqual(try completions(habit).count, 1)
        XCTAssertTrue(model.undoQuickAmount(entryID: second.id, habitID: habit.id, asOf: now))
        XCTAssertEqual(try activity.entries(for: habit.id, on: now).map(\.id), [first.id])
        XCTAssertTrue(try completions(habit).isEmpty)
        XCTAssertFalse(try XCTUnwrap(model.rows.first).isCompletedToday)
        XCTAssertFalse(model.undoQuickAmount(entryID: second.id, habitID: habit.id, asOf: now))
        XCTAssertEqual(try activity.entries(for: habit.id, on: now).map(\.id), [first.id])
    }

    func testStaleSimpleToggleCannotEraseSuccessWhileRecordedAmountsStillMeetTarget() throws {
        let habit = try create(amount: 4)
        let first = try XCTUnwrap(model.logQuickAmount(for: row(habit), asOf: now))
        let second = try XCTUnwrap(model.logQuickAmount(for: row(habit), asOf: now))
        let originalCompletion = try XCTUnwrap(completions(habit).first)
        var staleSimpleRow = try row(habit)
        staleSimpleRow.requiresQuantityLogging = false
        staleSimpleRow.quantityTarget = nil
        model.toggleCompletion(for: staleSimpleRow, asOf: now)
        XCTAssertEqual(try completions(habit).map(\.id), [originalCompletion.id])
        XCTAssertEqual(Set(try activity.entries(for: habit.id, on: now).map(\.id)), [first.id, second.id])
        XCTAssertNotNil(model.errorMessage)
        XCTAssertTrue(model.undoQuickAmount(entryID: second.id, habitID: habit.id, asOf: now))
        XCTAssertTrue(try completions(habit).isEmpty, "Only removing quantity below the target withdraws its generated success")
        XCTAssertEqual(try activity.entries(for: habit.id, on: now).map(\.id), [first.id])
    }

    func testUndoCannotRemoveAnotherHabitEarlierDayOrSmallerAction() throws {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let first = try create(at: yesterday)
        let second = try create("Another habit")
        let config = try XCTUnwrap(activity.configuration(for: first.id, on: now))
        try activity.log(habitID: first.id, kind: .quantity, amount: 1,
            expectedConfigurationID: config.id, on: yesterday, now: now)
        let old = try XCTUnwrap(activity.entries(for: first.id, on: yesterday).first)
        try activity.log(habitID: first.id, kind: .smallerAction, amount: 0,
            expectedConfigurationID: config.id, on: now, now: now)
        let smaller = try XCTUnwrap(activity.entries(for: first.id, on: now).first)
        let current = try XCTUnwrap(model.logQuickAmount(for: row(first), asOf: now))
        XCTAssertFalse(model.undoQuickAmount(entryID: old.id, habitID: first.id, asOf: now))
        XCTAssertNotNil(model.errorMessage, "An unavailable Undo must explain why no action occurred")
        XCTAssertFalse(model.undoQuickAmount(entryID: current.id, habitID: second.id, asOf: now))
        XCTAssertFalse(model.undoQuickAmount(entryID: smaller.id, habitID: first.id, asOf: now))
        XCTAssertTrue(model.undoQuickAmount(entryID: current.id, habitID: first.id, asOf: now))
        XCTAssertEqual(try activity.entries(for: first.id, on: yesterday).map(\.id), [old.id])
        XCTAssertEqual(try activity.entries(for: first.id, on: now).map(\.id), [smaller.id])
    }

    func testChangedConfigurationRejectsCapturedAmountWithoutWriting() throws {
        let habit = try create()
        let displayed = try row(habit)
        try activity.configure(habitID: habit.id, target: .init(amount: 20, unit: .pages),
            smallerAction: "One paragraph", at: now)
        XCTAssertNil(model.logQuickAmount(for: displayed, asOf: now))
        XCTAssertNotNil(model.errorMessage)
        XCTAssertTrue(try activity.entries(for: habit.id, on: now).isEmpty)
        XCTAssertTrue(try completions(habit).isEmpty)
    }

    func testArchivedHabitCannotLogOrUndoAndExistingQuantityStaysIntact() throws {
        let habit = try create()
        let original = try row(habit)
        let entry = try XCTUnwrap(model.logQuickAmount(for: original, asOf: now))
        let latest = try row(habit)
        try habits.archiveHabit(id: habit.id, at: now)
        XCTAssertNil(model.logQuickAmount(for: latest, asOf: now))
        XCTAssertFalse(model.undoQuickAmount(entryID: entry.id, habitID: habit.id, asOf: now))
        XCTAssertEqual(try activity.entries(for: habit.id, on: now).map(\.id), [entry.id])
    }

    func testCapturedRowCannotLogAnotherDayEvenAfterTodayReloads() throws {
        let habit = try create()
        let previous = try row(habit)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        _ = try row(habit, at: tomorrow)
        XCTAssertNil(model.logQuickAmount(for: previous, asOf: tomorrow))
        XCTAssertTrue(try activity.entries(for: habit.id, on: now).isEmpty)
        XCTAssertTrue(try activity.entries(for: habit.id, on: tomorrow).isEmpty)
    }

    func testChangedScheduleAndNewExcusedSkipRequireReviewBeforeQuickLogging() throws {
        let habit = try create()
        let displayed = try row(habit)
        let skip = try habits.recordSkip(habitID: habit.id, on: now, reason: nil)
        XCTAssertNil(model.logQuickAmount(for: displayed, asOf: now))
        XCTAssertEqual(try habits.skips(for: habit.id,
            in: XCTUnwrap(calendar.dateInterval(of: .day, for: now))).map(\.id), [skip.id])
        try habits.undoSkip(id: skip.id)
        var draft = HabitDraft(name: habit.name, iconName: habit.iconName, category: habit.category,
            polarity: habit.polarity, schedule: .weekdays([.sunday]))
        draft.whyItMatters = habit.whyItMatters
        _ = try habits.updateHabit(id: habit.id, with: draft, at: now)
        XCTAssertNil(model.logQuickAmount(for: displayed, asOf: now))
        XCTAssertTrue(try activity.entries(for: habit.id, on: now).isEmpty)
    }

    func testMinuteTargetsExposeTheExistingMinutePresetWithoutStartingATimer() throws {
        let habit = try create("Practice", amount: 15, unit: .minutes)
        try presets.save([5, 10, 20], for: habit.id, unit: .minutes)
        let displayed = try row(habit)
        XCTAssertEqual(displayed.quickAmount, 5)
        XCTAssertEqual(displayed.quantityTarget?.unit, .minutes)
        let entry = try XCTUnwrap(model.logQuickAmount(for: displayed, asOf: now))
        XCTAssertEqual(entry.amount, 5)
        XCTAssertEqual(entry.unit, .minutes)
        XCTAssertNil(try activity.timer(for: habit.id, on: now))
        XCTAssertTrue(try completions(habit).isEmpty)
    }
}
