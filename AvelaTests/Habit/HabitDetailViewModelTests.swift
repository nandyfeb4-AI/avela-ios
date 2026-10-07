import Foundation
import SwiftData
import XCTest
@testable import Avela

@MainActor
final class HabitDetailViewModelTests: XCTestCase {
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

    func testMemoryOnlySurfacesDuringRecoveryAndHidingKeepsItsText() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(.init(name: "Read", iconName: "book.fill", category: .learning,
            polarity: .positive, schedule: .daily, whyItMatters: "Stay curious."), at: day0)
        let model = HabitDetailViewModel(habitID: habit.id, repository: repository, calendar: calendar)
        model.load(asOf: day0)
        XCTAssertNil(model.whyMemory, "No unsolicited reason card during an ordinary pending day")
        XCTAssertEqual(model.draft?.whyItMatters, "Stay curious.")
        model.load(asOf: day(2))
        XCTAssertEqual(model.whyMemory, "Stay curious.")
        model.hideWhyMemory(asOf: day(2))
        XCTAssertNil(model.whyMemory)
        XCTAssertEqual(try repository.fetchHabit(id: habit.id)?.whyItMatters, "Stay curious.")
        let reopened = HabitDetailViewModel(habitID: habit.id, repository: repository, calendar: calendar)
        reopened.load(asOf: day(2))
        XCTAssertNil(reopened.whyMemory)
        XCTAssertEqual(try repository.configurationHistory(for: habit.id).count, 1)
    }

    func testDetailDisplaysNameIconCategoryPolarityAndSchedule() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book.fill", category: .learning, polarity: .positive, schedule: .daily),
            at: day0
        )
        let viewModel = HabitDetailViewModel(habitID: habit.id, repository: repository, calendar: calendar)
        viewModel.load(asOf: day0)

        let display = try XCTUnwrap(viewModel.display)
        XCTAssertEqual(display.name, "Read")
        XCTAssertEqual(display.iconName, "book.fill")
        XCTAssertEqual(display.categoryLabel, "Learning")
        XCTAssertEqual(display.polarityLabel, "Build Up")
        XCTAssertEqual(display.scheduleLabel, "Daily")
        XCTAssertFalse(display.isArchived)
    }

    func testCurrentStreakLabelUsesDaysForDailySchedule() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book.fill", category: .other, polarity: .positive, schedule: .daily),
            at: day0
        )
        try repository.recordCompletion(habitID: habit.id, at: day0, source: .app, note: nil)

        let viewModel = HabitDetailViewModel(habitID: habit.id, repository: repository, calendar: calendar)
        viewModel.load(asOf: day0)

        XCTAssertEqual(viewModel.display?.currentStreakLabel, "1-day streak")
    }

    func testCurrentStreakLabelUsesWeeksForFlexibleWeeklySchedule() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Swim", iconName: "figure.pool.swim", category: .fitness, polarity: .positive, schedule: .timesPerWeek(2)),
            at: day(-1) // Sunday, week-aligned
        )
        try repository.recordCompletion(habitID: habit.id, at: day(0), source: .app, note: nil)
        try repository.recordCompletion(habitID: habit.id, at: day(1), source: .app, note: nil)

        let viewModel = HabitDetailViewModel(habitID: habit.id, repository: repository, calendar: calendar)
        viewModel.load(asOf: day(1))

        XCTAssertEqual(viewModel.display?.currentStreakLabel, "1-week streak")
    }

    func testNoStreakYetWhenNothingCompleted() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book.fill", category: .other, polarity: .positive, schedule: .daily),
            at: day0
        )
        let viewModel = HabitDetailViewModel(habitID: habit.id, repository: repository, calendar: calendar)
        viewModel.load(asOf: day0)

        XCTAssertEqual(viewModel.display?.currentStreakLabel, "No current streak yet")
        XCTAssertEqual(viewModel.display?.bestStreakLabel, "No streak yet")
        XCTAssertNil(viewModel.display?.recoveryMessage)
    }

    func testRecoveryMessageShownWhileRecoveringAndHiddenAfterThreshold() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book.fill", category: .other, polarity: .positive, schedule: .daily),
            at: day0
        )
        // Monday missed (no completion); Tue/Wed/Thu completed.
        try repository.recordCompletion(habitID: habit.id, at: day(1), source: .app, note: nil)
        try repository.recordCompletion(habitID: habit.id, at: day(2), source: .app, note: nil)
        try repository.recordCompletion(habitID: habit.id, at: day(3), source: .app, note: nil)

        let viewModel = HabitDetailViewModel(habitID: habit.id, repository: repository, calendar: calendar)

        viewModel.load(asOf: day(1))
        XCTAssertEqual(viewModel.display?.recoveryMessage, "1 good day since your miss.")

        viewModel.load(asOf: day(3))
        XCTAssertNil(viewModel.display?.recoveryMessage, "recovery messaging must stop once the 3-success threshold is reached")
        XCTAssertEqual(viewModel.display?.currentStreakLabel, "3-day streak", "the streak itself keeps counting past the threshold")
    }

    func testConsistencyShowsNotEnoughDataWhenNothingIsResolvedYet() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book.fill", category: .other, polarity: .positive, schedule: .daily),
            at: day0
        )
        let viewModel = HabitDetailViewModel(habitID: habit.id, repository: repository, calendar: calendar)
        viewModel.load(asOf: day0) // the only day so far is still "pending"

        XCTAssertEqual(viewModel.display?.consistencyLabel, "Not enough data yet")
        XCTAssertEqual(viewModel.display?.consistencyRangeLabel, "Last 14 Days")
    }

    func testConsistencyShowsFractionAndPercentage() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book.fill", category: .other, polarity: .positive, schedule: .daily),
            at: day0
        )
        // Mon, Tue completed; Wed missed; Thu completed (final, determined).
        try repository.recordCompletion(habitID: habit.id, at: day(0), source: .app, note: nil)
        try repository.recordCompletion(habitID: habit.id, at: day(1), source: .app, note: nil)
        try repository.recordCompletion(habitID: habit.id, at: day(3), source: .app, note: nil)

        let viewModel = HabitDetailViewModel(habitID: habit.id, repository: repository, calendar: calendar)
        viewModel.load(asOf: day(3))

        XCTAssertEqual(viewModel.display?.consistencyLabel, "3 of 4 days (75%)")
    }

    func testEditingPreservesHistoricalConfigurationAndCompletions() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book.fill", category: .learning, polarity: .positive, schedule: .daily),
            at: day0
        )
        let completion = try repository.recordCompletion(habitID: habit.id, at: day0, source: .app, note: nil)

        let viewModel = HabitDetailViewModel(habitID: habit.id, repository: repository, calendar: calendar)
        viewModel.load(asOf: day(2))
        viewModel.saveEdits(
            HabitDraft(name: "Read More", iconName: "book.fill", category: .learning, polarity: .positive, schedule: .timesPerWeek(2)),
            asOf: day(2)
        )

        XCTAssertEqual(viewModel.display?.name, "Read More")
        XCTAssertEqual(viewModel.display?.scheduleLabel, "2x / week")

        let history = try repository.configurationHistory(for: habit.id)
        XCTAssertEqual(history.count, 2, "the edit must append a snapshot, not overwrite the original")
        XCTAssertEqual(history.first?.schedule, .daily)

        let preservedCompletions = try repository.completions(
            for: habit.id, in: DateInterval(start: day(-1), end: day(5))
        )
        XCTAssertEqual(preservedCompletions.count, 1)
        XCTAssertEqual(preservedCompletions.first?.id, completion.id)
    }

    func testArchivingUpdatesRepositoryAndSignalsDismissal() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book.fill", category: .other, polarity: .positive, schedule: .daily),
            at: day0
        )
        let viewModel = HabitDetailViewModel(habitID: habit.id, repository: repository, calendar: calendar)
        viewModel.load(asOf: day0)
        XCTAssertFalse(viewModel.didArchive)

        viewModel.archive(asOf: day(1))

        XCTAssertTrue(viewModel.didArchive)
        let reloaded = try repository.fetchHabit(id: habit.id)
        XCTAssertTrue(reloaded?.isArchived ?? false)
    }
    func testSkipAndUndoAreExcusedAndDoNotDuplicate() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(HabitDraft(name: "Read", iconName: "book", category: .other, polarity: .positive, schedule: .daily), at: day0)
        let model = HabitDetailViewModel(habitID: habit.id, repository: repository, calendar: calendar)
        model.load(asOf: day0)
        XCTAssertTrue(model.display!.canSkipToday)
        model.toggleSkip(asOf: day0)
        XCTAssertTrue(model.display!.isSkippedToday)
        model.toggleSkip(asOf: day0)
        XCTAssertFalse(model.display!.isSkippedToday)
    }

    func testCompletedDayCannotBeSkipped() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(HabitDraft(name: "Read", iconName: "book", category: .other, polarity: .positive, schedule: .daily), at: day0)
        try repository.recordCompletion(habitID: habit.id, at: day0, source: .app, note: nil)
        let model = HabitDetailViewModel(habitID: habit.id, repository: repository, calendar: calendar)
        model.load(asOf: day0)
        model.toggleSkip(asOf: day0)
        XCTAssertFalse(model.display!.isSkippedToday)
        XCTAssertTrue(model.display!.isCompletedToday)
    }

}
