import XCTest
import SwiftData
@testable import Avela

@MainActor
final class HabitQuickLogPresetTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!
    override func setUp() async throws {
        suiteName = "Avela.QuickPresets.Tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }
    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
    }
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = .current
        return value
    }
    private struct Fixture {
        let container: ModelContainer
        let habits: SwiftDataHabitRepository
        let activities: SwiftDataHabitActivityRepository
        let habit: Habit
        let model: HabitActivityViewModel
        let now: Date
    }
    private func fixture(unit: HabitQuantityUnit = .pages, target: Int = 10) throws -> Fixture {
        let now = Date()
        let container = try AppPersistence.makeContainer(inMemory: true)
        let habits = SwiftDataHabitRepository(modelContext: container.mainContext, calendar: calendar)
        let habit = try habits.createHabit(.init(name: "Read", iconName: "book.fill", category: .learning,
            polarity: .positive, schedule: .daily), at: calendar.date(byAdding: .day, value: -3, to: now)!)
        let activities = SwiftDataHabitActivityRepository(context: container.mainContext, habits: habits, calendar: calendar)
        try activities.configure(habitID: habit.id, target: .init(amount: target, unit: unit), smallerAction: "", at: now)
        let model = HabitActivityViewModel(habitID: habit.id, repository: activities, habits: habits,
            calendar: calendar, presets: HabitQuickLogPresets(defaults: defaults))
        model.selectedDate = now
        model.load()
        return Fixture(container: container, habits: habits, activities: activities, habit: habit, model: model, now: now)
    }

    func testCustomAmountsPersistPerHabitAndCapturedUnitWithoutWritingDefaults() throws {
        let store = HabitQuickLogPresets(defaults: defaults)
        let habitID = UUID()
        XCTAssertEqual(store.amounts(for: habitID, unit: .pages), [1, 5, 10])
        XCTAssertTrue(defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("avela.quickLogPresets") }.isEmpty)
        try store.save([4, 12], for: habitID, unit: .pages)
        let reopened = HabitQuickLogPresets(defaults: UserDefaults(suiteName: suiteName)!)
        XCTAssertEqual(reopened.amounts(for: habitID, unit: .pages), [4, 12])
        XCTAssertEqual(reopened.amounts(for: habitID, unit: .minutes), [5, 10, 20])
        XCTAssertEqual(reopened.amounts(for: UUID(), unit: .pages), [1, 5, 10])
    }

    func testInvalidAmountsNeverReplaceSavedPreferences() throws {
        let store = HabitQuickLogPresets(defaults: defaults)
        let id = UUID()
        try store.save([7], for: id, unit: .count)
        for values in [[], [1, 1], [0], [-1], [10_001], [1, 2, 3, 4]] {
            XCTAssertThrowsError(try store.save(values, for: id, unit: .count))
            XCTAssertEqual(store.amounts(for: id, unit: .count), [7])
        }
        try store.save([1, 10_000], for: id, unit: .glasses)
        XCTAssertEqual(store.amounts(for: id, unit: .glasses), [1, 10_000])
    }

    func testEditingCancelAndInvalidSaveNeverChangeHistoryOrPreferences() throws {
        let f = try fixture()
        f.model.preparePresets()
        f.model.presetDraft = ["3", "8", ""]
        f.model.cancelPresets()
        XCTAssertEqual(f.model.quickAmounts, [1, 5, 10])
        f.model.preparePresets()
        for invalid in [["", "", ""], ["1.5", "", ""], ["5", "5", ""], ["0", "", ""]] {
            f.model.presetDraft = invalid
            f.model.savePresets(now: f.now)
            XCTAssertNotNil(f.model.presetError)
            XCTAssertTrue(f.model.isShowingPresets)
            XCTAssertEqual(f.model.quickAmounts, [1, 5, 10])
        }
        XCTAssertTrue(try f.activities.entries(for: f.habit.id, on: f.now).isEmpty)
        XCTAssertEqual(try f.activities.configuration(for: f.habit.id, on: f.now), f.model.configuration)
        XCTAssertEqual(try f.habits.configurationHistory(for: f.habit.id).count, 1)
    }

    func testSavedPresetsSurviveTargetRevisionButNeverCrossUnits() throws {
        let f = try fixture()
        f.model.preparePresets()
        f.model.presetDraft = [" 4 ", "12", ""]
        f.model.savePresets(now: f.now)
        XCTAssertFalse(f.model.isShowingPresets)
        XCTAssertEqual(f.model.quickAmounts, [4, 12])
        try f.activities.configure(habitID: f.habit.id, target: .init(amount: 30, unit: .pages), smallerAction: "", at: f.now)
        f.model.load()
        XCTAssertEqual(f.model.quickAmounts, [4, 12])
        try f.activities.configure(habitID: f.habit.id, target: .init(amount: 30, unit: .minutes), smallerAction: "", at: f.now)
        f.model.load()
        XCTAssertEqual(f.model.quickAmounts, [5, 10, 20])
        try f.activities.configure(habitID: f.habit.id, target: .init(amount: 30, unit: .pages), smallerAction: "", at: f.now)
        f.model.load()
        XCTAssertEqual(f.model.quickAmounts, [4, 12])
    }

    func testQuickLogAndUndoOnlyRemoveTheExactInsertedEntry() throws {
        let f = try fixture(target: 6)
        let config = try XCTUnwrap(f.model.configuration)
        try f.activities.log(habitID: f.habit.id, kind: .quantity, amount: 1,
            expectedConfigurationID: config.id, on: f.now, now: f.now)
        let originalID = try XCTUnwrap(f.activities.entries(for: f.habit.id, on: f.now).first?.id)
        f.model.logPreset(5, now: f.now)
        XCTAssertEqual(f.model.total, 6)
        let quickID = try XCTUnwrap(f.model.lastQuickEntry?.id)
        XCTAssertNotEqual(quickID, originalID)
        try f.activities.log(habitID: f.habit.id, kind: .quantity, amount: 1,
            expectedConfigurationID: config.id, on: f.now, now: f.now)
        f.model.undoQuickLog(now: f.now)
        let entries = try f.activities.entries(for: f.habit.id, on: f.now)
        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries.contains { $0.id == originalID })
        XCTAssertFalse(entries.contains { $0.id == quickID })
        XCTAssertEqual(f.model.total, 2)
        XCTAssertNil(f.model.lastQuickEntry)
        let range = DateInterval(start: calendar.startOfDay(for: f.now), duration: 86_400)
        XCTAssertTrue(try f.habits.completions(for: f.habit.id, in: range).isEmpty,
            "Undo withdraws only quantity-generated success after dropping below its target")
    }

    func testQuickLogRefusesHistoricalUnloadedOrMidnightChangedDay() throws {
        let f = try fixture()
        f.model.selectedDate = calendar.date(byAdding: .day, value: -1, to: f.now)!
        f.model.logPreset(5, now: f.now)
        XCTAssertNotNil(f.model.errorMessage)
        f.model.load()
        f.model.logPreset(5, now: f.now)
        XCTAssertTrue(try f.activities.entries(for: f.habit.id, on: f.model.selectedDate).isEmpty)
        f.model.selectedDate = f.now
        f.model.load()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: f.now)!
        f.model.logPreset(5, now: tomorrow)
        XCTAssertTrue(try f.activities.entries(for: f.habit.id, on: f.now).isEmpty)
    }

    func testStaleTargetCannotBeLoggedOrSavedSilently() throws {
        let f = try fixture()
        f.model.preparePresets()
        f.model.presetDraft = ["2", "", ""]
        try f.activities.configure(habitID: f.habit.id, target: .init(amount: 30, unit: .minutes), smallerAction: "", at: f.now)
        f.model.savePresets(now: f.now)
        XCTAssertNotNil(f.model.presetError)
        XCTAssertEqual(HabitQuickLogPresets(defaults: defaults).amounts(for: f.habit.id, unit: .pages), [1, 5, 10])
        f.model.logPreset(5, now: f.now)
        XCTAssertNotNil(f.model.errorMessage)
        XCTAssertTrue(try f.activities.entries(for: f.habit.id, on: f.now).isEmpty)
    }

    func testUndoCannotRemoveEntryAfterConfigurationChangesOrMidnight() throws {
        let f = try fixture()
        f.model.logPreset(5, now: f.now)
        let id = try XCTUnwrap(f.model.lastQuickEntry?.id)
        f.model.undoQuickLog(now: calendar.date(byAdding: .day, value: 1, to: f.now)!)
        XCTAssertTrue(try f.activities.entries(for: f.habit.id, on: f.now).contains { $0.id == id })
        try f.activities.configure(habitID: f.habit.id, target: .init(amount: 40, unit: .pages), smallerAction: "", at: f.now)
        f.model.undoQuickLog(now: f.now)
        XCTAssertTrue(try f.activities.entries(for: f.habit.id, on: f.now).contains { $0.id == id })
    }
}
