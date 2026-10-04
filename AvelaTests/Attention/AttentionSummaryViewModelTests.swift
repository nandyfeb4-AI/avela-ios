import Foundation
import SwiftData
import XCTest
@testable import Avela

@MainActor
final class AttentionSummaryViewModelTests: XCTestCase {
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

    func testSessionActivityIsComposedWithoutInferringElapsedSuccess() throws {
        let repository = try makeRepository()
        let goal = try repository.createGoal(AttentionGoalDraft(name: "Break", appOrCategoryLabel: nil, type: .phoneFreeSession, targetValue: 30, unit: .minutes), at: day1)
        let model = AttentionSummaryViewModel(repository: repository, calendar: calendar)
        model.load(asOf: day1)
        XCTAssertFalse(model.hasActiveSession)
        let session = try repository.startSession(goalID: goal.id, at: day1)
        model.load(asOf: session.expectedEnd.addingTimeInterval(60))
        XCTAssertTrue(model.hasActiveSession)
        XCTAssertNil(model.rows.first?.state)
        _ = try repository.finishSession(id: session.id, outcome: .interrupted, at: session.expectedEnd.addingTimeInterval(60))
        model.load(asOf: session.expectedEnd.addingTimeInterval(60))
        XCTAssertFalse(model.hasActiveSession)
    }

    func testLogFixedAmountRecordsUsageImmediately() throws {
        let repository = try makeRepository()
        let goal = try repository.createGoal(
            AttentionGoalDraft(name: "Instagram", appOrCategoryLabel: nil, type: .maxDurationPerDay, targetValue: 30, unit: .minutes),
            at: day1
        )
        let viewModel = AttentionSummaryViewModel(repository: repository, calendar: calendar)
        viewModel.load(asOf: day1)

        viewModel.logFixedAmount(5, goalID: goal.id, asOf: day1)

        XCTAssertEqual(viewModel.rows.first?.statusLabel.contains("5 min"), true)
    }

    func testUndoLastQuickLogRemovesExactlyThatEntry() throws {
        let repository = try makeRepository()
        let goal = try repository.createGoal(
            AttentionGoalDraft(name: "Instagram", appOrCategoryLabel: nil, type: .maxDurationPerDay, targetValue: 30, unit: .minutes),
            at: day1
        )
        let viewModel = AttentionSummaryViewModel(repository: repository, calendar: calendar)
        viewModel.load(asOf: day1)

        // An existing entry from some other path must survive the undo.
        try repository.recordUsage(goalID: goal.id, amount: 10, at: day1, source: .manual)
        viewModel.logFixedAmount(5, goalID: goal.id, asOf: day1)
        XCTAssertEqual(viewModel.rows.first?.statusLabel.contains("15 min"), true)

        viewModel.undoLastQuickLog(asOf: day1)

        XCTAssertEqual(viewModel.rows.first?.statusLabel.contains("10 min"), true, "undo must remove only the chip-logged entry")
    }

    func testUndoLastQuickLogIsANoOpOnceAlreadyUndone() throws {
        let repository = try makeRepository()
        let goal = try repository.createGoal(
            AttentionGoalDraft(name: "Instagram", appOrCategoryLabel: nil, type: .maxDurationPerDay, targetValue: 30, unit: .minutes),
            at: day1
        )
        let viewModel = AttentionSummaryViewModel(repository: repository, calendar: calendar)
        viewModel.load(asOf: day1)

        viewModel.logFixedAmount(5, goalID: goal.id, asOf: day1)
        viewModel.undoLastQuickLog(asOf: day1)

        // Calling it again must not throw or affect any later, unrelated entry.
        viewModel.undoLastQuickLog(asOf: day1)
        XCTAssertEqual(viewModel.rows.first?.statusLabel, "No usage logged yet today")
    }
    func testWindowPresentationDeadlineOnlyUsesFutureBoundariesAndNeverCompletesSession() throws {
        let repository = try makeRepository()
        let day = calendar.startOfDay(for: day1)
        let windowGoal = try repository.createGoal(AttentionGoalDraft(name: "Morning", appOrCategoryLabel: nil,
            type: .noUseBeforeTime, targetValue: 30, unit: .minutes,
            windowStartMinute: 420, windowEndMinute: 540), at: day)
        let windowModel = AttentionWindowDetailViewModel(goalID: windowGoal.id, repository: repository, calendar: calendar)
        let before = day.addingTimeInterval(6 * 3600)
        let start = day.addingTimeInterval(7 * 3600)
        let end = day.addingTimeInterval(9 * 3600)
        let midnight = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: day))
        windowModel.load(asOf: before)
        XCTAssertEqual(windowModel.refreshDeadline, start)
        windowModel.load(asOf: start)
        XCTAssertEqual(windowModel.refreshDeadline, end)
        XCTAssertFalse(windowModel.canReportKept(at: start))
        windowModel.load(asOf: end)
        XCTAssertTrue(windowModel.canReportKept(at: end))
        XCTAssertEqual(windowModel.refreshDeadline, midnight)

        let sessionGoal = try repository.createGoal(AttentionGoalDraft(name: "Break", appOrCategoryLabel: nil,
            type: .phoneFreeSession, targetValue: 30, unit: .minutes), at: day)
        let sessionModel = AttentionWindowDetailViewModel(goalID: sessionGoal.id, repository: repository, calendar: calendar)
        sessionModel.load(asOf: before)
        XCTAssertEqual(sessionModel.refreshDeadline, midnight, "No active session needs no ticking timer")
        sessionModel.startSession(asOf: before)
        XCTAssertEqual(sessionModel.refreshDeadline, before.addingTimeInterval(1800))
        sessionModel.load(asOf: before.addingTimeInterval(1800))
        XCTAssertEqual(sessionModel.refreshDeadline, midnight)
        XCTAssertTrue(sessionModel.activeSession?.isActive == true)
        XCTAssertNil(sessionModel.activeSession?.outcome, "Refreshing presentation cannot manufacture a successful report")
    }

    func testSameDayWindowEditDoesNotReuseReportForDifferentBounds() throws {
        let repository = try makeRepository()
        let day = calendar.startOfDay(for: day1)
        let original = AttentionGoalDraft(name: "Morning", appOrCategoryLabel: nil,
            type: .noUseBeforeTime, targetValue: 30, unit: .minutes,
            windowStartMinute: 420, windowEndMinute: 540)
        let goal = try repository.createGoal(original, at: day)
        let ten = day.addingTimeInterval(10 * 3600)
        let report = try repository.recordCheckIn(goalID: goal.id, on: day, outcome: .kept, at: ten)
        var changed = original
        changed.windowEndMinute = 720
        _ = try repository.updateGoal(id: goal.id, with: changed, at: ten)
        let model = AttentionWindowDetailViewModel(goalID: goal.id, repository: repository, calendar: calendar)
        model.load(asOf: ten)
        XCTAssertTrue(model.summary?.statusLabel.contains("Not reported yet") == true)
        XCTAssertFalse(model.canReportKept(at: ten))
        XCTAssertEqual(model.window?.end, day.addingTimeInterval(12 * 3600))
        let history = try repository.checkIns(for: goal.id, in: DateInterval(start: day, end: day.addingTimeInterval(86400)))
        XCTAssertEqual(history.first?.id, report.id)
        XCTAssertEqual(history.first?.windowEnd, day.addingTimeInterval(9 * 3600))
        XCTAssertEqual(history.first?.outcome, .kept)
    }

    func testOvernightWindowKeepsStartDayConfigurationAfterMorningEdit() throws {
        let repository = try makeRepository()
        let day = calendar.startOfDay(for: day1)
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: day))
        let original = AttentionGoalDraft(name: "Night", appOrCategoryLabel: nil,
            type: .phoneFreeUntilTime, targetValue: 30, unit: .minutes,
            windowStartMinute: 1320, windowEndMinute: 540)
        let goal = try repository.createGoal(original, at: day.addingTimeInterval(12 * 3600))
        var changed = original
        changed.windowStartMinute = 1380
        changed.windowEndMinute = 660
        let eight = tomorrow.addingTimeInterval(8 * 3600)
        _ = try repository.updateGoal(id: goal.id, with: changed, at: eight)
        let model = AttentionWindowDetailViewModel(goalID: goal.id, repository: repository, calendar: calendar)
        model.load(asOf: eight)
        XCTAssertEqual(model.window?.start, day.addingTimeInterval(22 * 3600))
        XCTAssertEqual(model.window?.end, tomorrow.addingTimeInterval(9 * 3600))
        let nine = tomorrow.addingTimeInterval(9 * 3600)
        model.report(.kept, asOf: nine)
        XCTAssertNil(model.errorMessage)
        XCTAssertTrue(model.summary?.statusLabel.contains("Kept") == true)
        let reports = try repository.checkIns(for: goal.id, in: DateInterval(start: day, end: tomorrow))
        XCTAssertEqual(reports.first?.windowStart, model.window?.start)
        XCTAssertEqual(reports.first?.windowEnd, model.window?.end)
    }

    func testNewOvernightGoalBeforeItsStartCannotOfferPreCreationReport() throws {
        let repository = try makeRepository()
        let day = calendar.startOfDay(for: day1)
        let goal = try repository.createGoal(AttentionGoalDraft(name: "Night", appOrCategoryLabel: nil,
            type: .phoneFreeUntilTime, targetValue: 30, unit: .minutes,
            windowStartMinute: 1320, windowEndMinute: 540), at: day1)
        let model = AttentionWindowDetailViewModel(goalID: goal.id, repository: repository, calendar: calendar)
        model.load(asOf: day1)
        XCTAssertEqual(model.window?.start, day.addingTimeInterval(22 * 3600))
        XCTAssertFalse(model.canReportKept(at: day1))
        XCTAssertFalse(model.canReportInterrupted(at: day1))
        XCTAssertTrue(model.summary?.statusLabel.contains("Not reported yet") == true)
        XCTAssertEqual(model.refreshDeadline, day.addingTimeInterval(22 * 3600))
    }

    func testActiveSessionSummaryShowsCapturedTargetAfterGoalEdit() throws {
        let repository = try makeRepository()
        let goal = try repository.createGoal(AttentionGoalDraft(name: "Break", appOrCategoryLabel: nil,
            type: .phoneFreeSession, targetValue: 15, unit: .minutes), at: day1)
        _ = try repository.startSession(goalID: goal.id, at: day1)
        _ = try repository.updateGoal(id: goal.id, with: AttentionGoalDraft(name: "Break", appOrCategoryLabel: nil,
            type: .phoneFreeSession, targetValue: 60, unit: .minutes), at: day1.addingTimeInterval(60))
        let model = AttentionWindowDetailViewModel(goalID: goal.id, repository: repository, calendar: calendar)
        model.load(asOf: day1.addingTimeInterval(60))
        XCTAssertEqual(model.summary?.targetLabel, "15 min phone-free session")
        XCTAssertEqual(model.activeSession?.expectedEnd, day1.addingTimeInterval(15 * 60))
        XCTAssertEqual(model.draft?.targetValue, 60, "Editing still uses the target for future sessions")
    }

}
