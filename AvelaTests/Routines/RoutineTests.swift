import Foundation
import SwiftData
import XCTest
@testable import Avela

@MainActor
final class RoutineTests: XCTestCase {
    private var container: ModelContainer?
    private let date = Date(timeIntervalSince1970: 1_718_632_800)

    private func repositories() throws -> (SwiftDataHabitRepository, SwiftDataRoutineRepository) {
        let schema = Schema([RoutineRecord.self, HabitRecord.self, HabitConfigurationSnapshotRecord.self, CompletionRecord.self, SkipRecord.self, HabitArchivePeriodRecord.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        self.container = container
        let habits = SwiftDataHabitRepository(modelContext: container.mainContext)
        return (habits, SwiftDataRoutineRepository(modelContext: container.mainContext, habits: habits))
    }

    private func create(_ name: String, in habits: SwiftDataHabitRepository) throws -> Habit {
        try habits.createHabit(HabitDraft(name: name, iconName: "book.fill", category: .learning, polarity: .positive, schedule: .daily), at: date)
    }

    func testRoutinePreservesChosenOrderAndEditingDoesNotChangeCheckIns() throws {
        let (habits, routines) = try repositories()
        let first = try create("Read", in: habits), second = try create("Walk", in: habits)
        let completion = try habits.recordCompletion(habitID: first.id, at: date, source: .app, note: nil)
        let routine = try routines.save(id: nil, name: "  Morning  ", habitIDs: [second.id, first.id], at: date)
        XCTAssertEqual(routine.name, "Morning")
        XCTAssertEqual(try routines.routines().first?.habitIDs, [second.id, first.id])
        _ = try routines.save(id: routine.id, name: "Evening", habitIDs: [first.id], at: date)
        let day = try XCTUnwrap(Calendar.current.dateInterval(of: .day, for: date))
        XCTAssertEqual(try habits.completions(for: first.id, in: day).map(\.id), [completion.id])
        XCTAssertEqual(try habits.configurationHistory(for: first.id).count, 1)
    }

    func testInvalidAndStaleSelectionsWriteNothing() throws {
        let (habits, routines) = try repositories()
        let habit = try create("Read", in: habits)
        XCTAssertThrowsError(try routines.save(id: nil, name: "", habitIDs: [habit.id], at: date))
        XCTAssertThrowsError(try routines.save(id: nil, name: "Morning", habitIDs: [], at: date))
        XCTAssertThrowsError(try routines.save(id: nil, name: "Morning", habitIDs: [habit.id, habit.id], at: date))
        try habits.archiveHabit(id: habit.id, at: date)
        XCTAssertThrowsError(try routines.save(id: nil, name: "Morning", habitIDs: [habit.id], at: date))
        XCTAssertTrue(try routines.routines().isEmpty)
    }

    func testRunnerReadsFactsInOrderOmitsArchivesAndNeverLogs() throws {
        let (habits, routines) = try repositories()
        let first = try create("Read", in: habits), second = try create("Walk", in: habits)
        let routine = try routines.save(id: nil, name: "Morning", habitIDs: [second.id, first.id], at: date)
        let model = RoutineRunViewModel(routine: routine, habits: habits)
        model.load(asOf: date)
        XCTAssertEqual(model.steps.map(\.id), [second.id, first.id])
        XCTAssertTrue(model.steps.allSatisfy { !$0.isComplete })
        _ = try habits.recordCompletion(habitID: first.id, at: date, source: .app, note: nil)
        try habits.archiveHabit(id: second.id, at: date)
        model.load(asOf: date)
        XCTAssertEqual(model.steps.map(\.id), [first.id])
        XCTAssertTrue(try XCTUnwrap(model.steps.first).isComplete)
        XCTAssertEqual(model.unavailableCount, 1)
        XCTAssertEqual(try routines.routines().first?.habitIDs, [second.id, first.id], "Archiving does not erase grouping history.")
    }

    func testDeletingGroupingRetainsHabitAndCompletion() throws {
        let (habits, routines) = try repositories()
        let habit = try create("Read", in: habits)
        let routine = try routines.save(id: nil, name: "Morning", habitIDs: [habit.id], at: date)
        let completion = try habits.recordCompletion(habitID: habit.id, at: date, source: .app, note: nil)
        try routines.delete(id: routine.id)
        XCTAssertTrue(try routines.routines().isEmpty)
        XCTAssertNotNil(try habits.fetchHabit(id: habit.id))
        let day = try XCTUnwrap(Calendar.current.dateInterval(of: .day, for: date))
        XCTAssertEqual(try habits.completions(for: habit.id, in: day).first?.id, completion.id)
    }

    func testRestartStoresExplicitDurationWithoutChangingCommitments() throws {
        let (habits, routines) = try repositories()
        let habit = try create("Read", in: habits)
        let restart = try routines.save(id: nil, name: "Start gently", habitIDs: [habit.id], restartDays: 3, at: date)
        XCTAssertEqual(try routines.routines().first?.restartDays, 3)
        XCTAssertNotNil(restart.restartReviewDate(calendar: .current))
        XCTAssertEqual(try habits.fetchHabit(id: habit.id)?.schedule, .daily)
        XCTAssertEqual(try habits.configurationHistory(for: habit.id).count, 1)
        XCTAssertThrowsError(try routines.save(id: nil, name: "Invalid", habitIDs: [habit.id], restartDays: 4, at: date))
        XCTAssertEqual(try routines.routines().count, 1)
    }

    func testViewModelRejectsStaleDraftInsteadOfSavingPartialRoutine() throws {
        let (habits, routines) = try repositories()
        let habit = try create("Read", in: habits)
        let model = RoutinesViewModel(repository: routines, habits: habits)
        model.load()
        try habits.archiveHabit(id: habit.id, at: date)
        XCTAssertFalse(model.save(id: nil, name: "Morning", habitIDs: [habit.id], at: date))
        XCTAssertNotNil(model.errorMessage)
        XCTAssertTrue(try routines.routines().isEmpty)
    }

    func testRoutineAndRestartSurviveDiskReopen() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let schema = Schema([RoutineRecord.self, HabitRecord.self, HabitConfigurationSnapshotRecord.self, CompletionRecord.self, SkipRecord.self, HabitArchivePeriodRecord.self])
        let config = ModelConfiguration(schema: schema, url: folder.appendingPathComponent("routines.store"), cloudKitDatabase: .none)
        var id: UUID!
        var habitID: UUID!
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let habits = SwiftDataHabitRepository(modelContext: container.mainContext)
            let repository = SwiftDataRoutineRepository(modelContext: container.mainContext, habits: habits)
            habitID = try create("Read", in: habits).id
            id = try repository.save(id: nil, name: "Restart", habitIDs: [habitID], restartDays: 7, at: date).id
        }
        let reopened = try ModelContainer(for: schema, configurations: [config])
        let habits = SwiftDataHabitRepository(modelContext: reopened.mainContext)
        let repository = SwiftDataRoutineRepository(modelContext: reopened.mainContext, habits: habits)
        let routine = try XCTUnwrap(repository.routines().first)
        XCTAssertEqual(routine.id, id)
        XCTAssertEqual(routine.habitIDs, [habitID])
        XCTAssertEqual(routine.restartDays, 7)
        XCTAssertNotNil(try habits.fetchHabit(id: habitID))
    }


    private func manageableRepositories() throws -> (SwiftDataHabitRepository, SwiftDataHabitActivityRepository, SwiftDataRoutineRepository) {
        let container = try AppPersistence.makeContainer(inMemory: true)
        self.container = container
        let habits = SwiftDataHabitRepository(modelContext: container.mainContext)
        let activities = SwiftDataHabitActivityRepository(context: container.mainContext, habits: habits)
        let routines = SwiftDataRoutineRepository(modelContext: container.mainContext, habits: habits)
        return (habits, activities, routines)
    }

    func testManageableWeekReviewAndSelectionNeverWrite() throws {
        let (habits, activities, routines) = try manageableRepositories()
        let habit = try create("Read", in: habits)
        let model = ManageableWeekViewModel(habits: habits, activities: activities, routines: routines)
        model.load(asOf: date)
        model.focusIDs.insert(habit.id)
        XCTAssertFalse(try XCTUnwrap(habits.fetchHabit(id: habit.id)).isArchived)
        XCTAssertTrue(try routines.routines().isEmpty)
        XCTAssertTrue(try habits.archivePeriods(for: habit.id).isEmpty)
    }

    func testManageableWeekPausesOnlyExplicitHabitAndCanReactivateWithoutLostHistory() throws {
        let (habits, activities, routines) = try manageableRepositories()
        let first = try create("Read", in: habits), second = try create("Walk", in: habits)
        let completion = try habits.recordCompletion(habitID: first.id, at: date, source: .app, note: nil)
        let model = ManageableWeekViewModel(habits: habits, activities: activities, routines: routines)
        model.load(asOf: date)
        XCTAssertTrue(model.pause(id: first.id, at: date))
        XCTAssertTrue(try XCTUnwrap(habits.fetchHabit(id: first.id)).isArchived)
        XCTAssertFalse(try XCTUnwrap(habits.fetchHabit(id: second.id)).isArchived)
        XCTAssertFalse(model.pause(id: first.id, at: date), "A stale repeated pause is rejected.")
        XCTAssertEqual(try habits.archivePeriods(for: first.id).count, 1)
        try habits.reactivateHabit(id: first.id, at: date.addingTimeInterval(86_400))
        let interval = try XCTUnwrap(Calendar.current.dateInterval(of: .day, for: date))
        XCTAssertEqual(try habits.completions(for: first.id, in: interval).first?.id, completion.id)
        XCTAssertTrue(try routines.routines().isEmpty)
    }

    func testManageableRestartGroupsFocusAndSmallerActionsDoNotInflateProgress() throws {
        let (habits, activities, routines) = try manageableRepositories()
        let first = try create("Read", in: habits), second = try create("Walk", in: habits)
        try activities.configure(habitID: first.id, target: nil, smallerAction: "One page", at: date)
        let model = ManageableWeekViewModel(habits: habits, activities: activities, routines: routines)
        model.load(asOf: date)
        XCTAssertEqual(model.rows.first { $0.id == first.id }?.smallerAction, "One page")
        model.focusIDs.insert(first.id)
        XCTAssertTrue(model.createPlan(days: 3, at: date))
        let plan = try XCTUnwrap(model.createdPlan)
        XCTAssertEqual(plan.habitIDs, [first.id])
        XCTAssertFalse(try XCTUnwrap(habits.fetchHabit(id: second.id)).isArchived)
        let config = try XCTUnwrap(activities.configuration(for: first.id, on: date))
        try activities.log(habitID: first.id, kind: .smallerAction, amount: 0, expectedConfigurationID: config.id, on: date, now: date)
        let runner = RoutineRunViewModel(routine: plan, habits: habits)
        runner.load(asOf: date)
        XCTAssertEqual(runner.steps.first?.restartSuccessfulCommitments, 0)
        XCTAssertFalse(try XCTUnwrap(runner.steps.first).isComplete)
        _ = try habits.recordCompletion(habitID: first.id, at: date, source: .app, note: nil)
        runner.load(asOf: date)
        XCTAssertEqual(runner.steps.first?.restartSuccessfulCommitments, 1)
    }

}
