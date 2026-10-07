import SwiftData
import XCTest
@testable import Avela

@MainActor
final class HabitOrderViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var repository: SwiftDataHabitRepository!
    private var calendar: Calendar!
    private let date = Date(timeIntervalSince1970: 1_718_632_800) // Monday

    override func setUpWithError() throws {
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        container = try AppPersistence.makeContainer(inMemory: true)
        repository = SwiftDataHabitRepository(modelContext: container.mainContext, calendar: calendar)
    }

    private func create(_ name: String, schedule: HabitSchedule = .daily) throws -> Habit {
        try repository.createHabit(HabitDraft(name: name, iconName: "book.fill", category: .learning, polarity: .positive, schedule: schedule), at: date)
    }

    func testDraftMultiMoveAndCancelNeverWrite() throws {
        let habits = try [create("Read"), create("Walk"), create("Stretch"), create("Journal")]
        let model = HabitOrderViewModel(repository: repository)
        model.load()
        XCTAssertFalse(model.canSave)
        model.move(from: IndexSet([0, 2]), to: 4)
        XCTAssertEqual(model.habits.map(\.id), [habits[1].id, habits[3].id, habits[0].id, habits[2].id])
        XCTAssertTrue(model.canSave)
        XCTAssertEqual(try repository.fetchHabits(includeArchived: false).map(\.id), habits.map(\.id))
        model.load() // Discard the unsaved draft, like reopening after Cancel.
        XCTAssertFalse(model.hasChanges)
        XCTAssertEqual(model.habits.map(\.id), habits.map(\.id))
        model.move(habits[0].id, up: true)
        model.move(habits[3].id, up: false)
        XCTAssertFalse(model.hasChanges, "Boundary moves must be harmless")
    }

    func testSavedOrderIncludesNotDueHabitsAndPreservesCompletion() throws {
        let read = try create("Read")
        let weekend = try create("Weekend walk", schedule: .weekdays([.sunday]))
        let journal = try create("Journal")
        let completion = try repository.recordCompletion(habitID: read.id, at: date, source: .shortcutFuture, note: "Chapter 2")
        let model = HabitOrderViewModel(repository: repository)
        model.load()
        XCTAssertEqual(model.habits.count, 3, "Not-due habits must still be configurable")
        model.move(journal.id, up: true)
        model.move(journal.id, up: true)
        XCTAssertTrue(model.save())
        XCTAssertFalse(model.canSave)
        let today = TodayViewModel(repository: repository, calendar: calendar)
        today.load(asOf: date)
        XCTAssertEqual(today.rows.map(\.id), [journal.id, read.id])
        XCTAssertEqual(today.activeHabitCount, 3)
        XCTAssertEqual(today.rows.last?.todaysCompletionID, completion.id)
        XCTAssertEqual(try repository.fetchHabits(includeArchived: false).map(\.id), [journal.id, read.id, weekend.id])
    }

    func testArchivingDuringDraftRequiresReloadWithoutChangingOrder() throws {
        let read = try create("Read")
        let walk = try create("Walk")
        let model = HabitOrderViewModel(repository: repository)
        model.load()
        model.move(walk.id, up: true)
        try repository.archiveHabit(id: walk.id, at: date)
        XCTAssertFalse(model.save())
        XCTAssertTrue(model.needsReload)
        XCTAssertFalse(model.canSave)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(try repository.fetchHabit(id: read.id)?.sortOrder, read.sortOrder)
        model.load()
        XCTAssertFalse(model.needsReload)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.habits.map(\.id), [read.id])
    }

    func testNewHabitDuringDraftRequiresReloadBeforeSave() throws {
        let read = try create("Read")
        let walk = try create("Walk")
        let model = HabitOrderViewModel(repository: repository)
        model.load()
        model.move(walk.id, up: true)
        let stretch = try create("Stretch")
        XCTAssertFalse(model.save())
        model.load()
        model.move(stretch.id, up: true)
        model.move(stretch.id, up: true)
        XCTAssertTrue(model.save())
        XCTAssertEqual(try repository.fetchHabits(includeArchived: false).map(\.id), [stretch.id, read.id, walk.id])
    }
}
