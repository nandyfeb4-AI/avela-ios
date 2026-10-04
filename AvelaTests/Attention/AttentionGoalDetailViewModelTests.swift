import Foundation
import SwiftData
import XCTest
@testable import Avela

@MainActor
final class AttentionGoalDetailViewModelTests: XCTestCase {
    // A ModelContext does not keep its container alive; retain it for the test.
    private var container: ModelContainer?

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 1
        return calendar
    }()

    private let day1 = Date(timeIntervalSince1970: 1_718_632_800) // Mon 2024-06-17

    private func makeRepository() throws -> SwiftDataAttentionRepository {
        let container = try AppPersistence.makeContainer(inMemory: true)
        self.container = container
        return SwiftDataAttentionRepository(modelContext: container.mainContext, calendar: calendar)
    }

    private func makeDraft(name: String = "Instagram", target: Double = 30) -> AttentionGoalDraft {
        AttentionGoalDraft(name: name, appOrCategoryLabel: "Social", type: .maxDurationPerDay, targetValue: target, unit: .minutes)
    }

    func testFreshGoalReportsNoUsageLoggedRatherThanAZeroStatus() throws {
        let repository = try makeRepository()
        let goal = try repository.createGoal(makeDraft(), at: day1)
        let viewModel = AttentionGoalDetailViewModel(goalID: goal.id, repository: repository, calendar: calendar)

        viewModel.load(asOf: day1)

        let display = try XCTUnwrap(viewModel.display)
        XCTAssertNil(display.state)
        XCTAssertTrue(display.entries.isEmpty)
        XCTAssertTrue(display.statusLabel.localizedCaseInsensitiveContains("no usage logged"))
    }

    func testLoggingUsageUpdatesStatusImmediately() throws {
        let repository = try makeRepository()
        let goal = try repository.createGoal(makeDraft(target: 30), at: day1)
        let viewModel = AttentionGoalDetailViewModel(goalID: goal.id, repository: repository, calendar: calendar)
        viewModel.load(asOf: day1)

        viewModel.logUsage(amount: 10, asOf: day1)

        let display = try XCTUnwrap(viewModel.display)
        XCTAssertEqual(display.entries.count, 1)
        XCTAssertEqual(display.state, .healthy)
        XCTAssertTrue(display.statusLabel.localizedCaseInsensitiveContains("manually"), "usage must be labeled as manually recorded")
        XCTAssertNil(viewModel.activeSheet, "a successful log should dismiss its own sheet")
    }

    func testCorrectingAnEntryChangesItsAmountWithoutCreatingANewOne() throws {
        let repository = try makeRepository()
        let goal = try repository.createGoal(makeDraft(target: 30), at: day1)
        let viewModel = AttentionGoalDetailViewModel(goalID: goal.id, repository: repository, calendar: calendar)
        viewModel.load(asOf: day1)
        viewModel.logUsage(amount: 10, asOf: day1)

        let entryID = try XCTUnwrap(viewModel.display?.entries.first?.id)
        viewModel.activeSheet = .correct(entryID: entryID)
        viewModel.correctEntry(id: entryID, amount: 20, asOf: day1)

        let display = try XCTUnwrap(viewModel.display)
        XCTAssertEqual(display.entries.count, 1, "correcting must not add a second entry")
        XCTAssertEqual(display.entries.first?.amount, 20)
        XCTAssertNil(viewModel.activeSheet, "a successful correction should dismiss its own sheet")
    }

    func testDeletingAnEntryRemovesItFromTodaysList() throws {
        let repository = try makeRepository()
        let goal = try repository.createGoal(makeDraft(target: 30), at: day1)
        let viewModel = AttentionGoalDetailViewModel(goalID: goal.id, repository: repository, calendar: calendar)
        viewModel.load(asOf: day1)
        viewModel.logUsage(amount: 10, asOf: day1)
        let entryID = try XCTUnwrap(viewModel.display?.entries.first?.id)

        viewModel.deleteEntry(id: entryID, asOf: day1)

        let display = try XCTUnwrap(viewModel.display)
        XCTAssertTrue(display.entries.isEmpty)
        XCTAssertNil(display.state, "deleting the only entry must return to the missing-data state, not a 0% status")
    }

    func testEditingBudgetTodayDoesNotChangeYesterdaysResolvedTarget() throws {
        let repository = try makeRepository()
        let goal = try repository.createGoal(makeDraft(target: 30), at: day1)
        let viewModel = AttentionGoalDetailViewModel(goalID: goal.id, repository: repository, calendar: calendar)
        viewModel.load(asOf: day1)

        var editedDraft = try XCTUnwrap(viewModel.draft)
        editedDraft.targetValue = 15
        let today = day1.addingTimeInterval(86_400)
        viewModel.saveEdits(editedDraft, asOf: today)

        // Yesterday's budget is still what it was, resolved independently of today's edit.
        let yesterdaysConfiguration = try repository.activeConfiguration(for: goal.id, on: day1)
        XCTAssertEqual(yesterdaysConfiguration?.targetValue, 30)

        let display = try XCTUnwrap(viewModel.display)
        XCTAssertEqual(display.targetLabel, "15 min budget")
    }

    func testMultipleEntriesSumForTodaysStatus() throws {
        let repository = try makeRepository()
        let goal = try repository.createGoal(makeDraft(target: 30), at: day1)
        let viewModel = AttentionGoalDetailViewModel(goalID: goal.id, repository: repository, calendar: calendar)
        viewModel.load(asOf: day1)

        viewModel.logUsage(amount: 10, asOf: day1)
        viewModel.logUsage(amount: 15, asOf: day1)

        let display = try XCTUnwrap(viewModel.display)
        XCTAssertEqual(display.entries.count, 2)
        XCTAssertTrue(display.statusLabel.contains("25 min"))
        XCTAssertEqual(display.state, .nearLimit)
    }
}
