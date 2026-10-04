import Foundation
import SwiftData
import XCTest
@testable import Avela

@MainActor
final class ArchivedHabitsViewModelTests: XCTestCase {
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

    func testReactivationLimitPreservesArchiveAndHistoryUntilSpaceAvailable() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(HabitDraft(name: "Read", iconName: "book.fill", category: .learning, polarity: .positive, schedule: .daily), at: day0)
        try repository.archiveHabit(id: habit.id, at: day(1))
        let model = ArchivedHabitsViewModel(repository: repository)
        model.load()
        model.activationAllowed = { _ in false }
        model.reactivate(try XCTUnwrap(model.rows.first), asOf: day(2))
        XCTAssertTrue(model.isShowingPremium)
        XCTAssertTrue(try XCTUnwrap(repository.fetchHabit(id: habit.id)).isArchived)
        XCTAssertNil(try repository.archivePeriods(for: habit.id).first?.reactivatedAt)
        model.activationAllowed = { _ in true }
        model.reactivate(try XCTUnwrap(model.rows.first), asOf: day(2))
        XCTAssertFalse(try XCTUnwrap(repository.fetchHabit(id: habit.id)).isArchived)
        XCTAssertEqual(try repository.archivePeriods(for: habit.id).first?.reactivatedAt, day(2))
    }

    func testListsOnlyArchivedHabits() throws {
        let repository = try makeRepository()
        let active = try repository.createHabit(
            HabitDraft(name: "Walk", iconName: "figure.walk", category: .fitness, polarity: .positive, schedule: .daily),
            at: day0
        )
        let archived = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book.fill", category: .learning, polarity: .positive, schedule: .daily),
            at: day0
        )
        try repository.archiveHabit(id: archived.id, at: day(1))
        _ = active

        let viewModel = ArchivedHabitsViewModel(repository: repository)
        viewModel.load()

        XCTAssertEqual(viewModel.rows.map(\.name), ["Read"])
    }

    func testReactivateRemovesHabitFromArchivedListAndClearsArchivedState() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book.fill", category: .learning, polarity: .positive, schedule: .daily),
            at: day0
        )
        try repository.archiveHabit(id: habit.id, at: day(1))

        let viewModel = ArchivedHabitsViewModel(repository: repository)
        viewModel.load()
        XCTAssertEqual(viewModel.rows.count, 1)

        viewModel.reactivate(viewModel.rows[0], asOf: day(2))

        XCTAssertTrue(viewModel.rows.isEmpty)
        let reloaded = try repository.fetchHabit(id: habit.id)
        XCTAssertFalse(reloaded?.isArchived ?? true)
    }

    func testRepeatedArchiveReactivateCyclesLeaveConsistentState() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book.fill", category: .learning, polarity: .positive, schedule: .daily),
            at: day0
        )

        try repository.archiveHabit(id: habit.id, at: day(1))
        try repository.reactivateHabit(id: habit.id, at: day(2))
        try repository.archiveHabit(id: habit.id, at: day(3))

        let viewModel = ArchivedHabitsViewModel(repository: repository)
        viewModel.load()
        XCTAssertEqual(viewModel.rows.map(\.name), ["Read"], "the habit is archived again after the second cycle")

        viewModel.reactivate(viewModel.rows[0], asOf: day(4))
        XCTAssertTrue(viewModel.rows.isEmpty)

        let periods = try repository.archivePeriods(for: habit.id)
        XCTAssertEqual(periods.count, 2, "both archive/reactivate cycles must be preserved")
        XCTAssertEqual(periods[0].archivedAt, day(1))
        XCTAssertEqual(periods[0].reactivatedAt, day(2))
        XCTAssertEqual(periods[1].archivedAt, day(3))
        XCTAssertEqual(periods[1].reactivatedAt, day(4))
    }
}
