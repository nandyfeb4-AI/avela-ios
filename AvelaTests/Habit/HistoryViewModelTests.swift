import Foundation
import SwiftData
import XCTest
@testable import Avela

@MainActor
final class HistoryViewModelTests: XCTestCase {
    // A ModelContext does not keep its container alive; retain it for the test.
    private var container: ModelContainer?

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 1
        return calendar
    }()

    private let day0 = Date(timeIntervalSince1970: 1_718_632_800) // Mon 2024-06-17, 10:00 EDT
    private func day(_ n: Int) -> Date { day0.addingTimeInterval(Double(n) * 86_400) }
    private func key(_ date: Date) -> String { LocalDay.key(for: date, calendar: calendar) }

    private func makeRepository() throws -> SwiftDataHabitRepository {
        let container = try AppPersistence.makeContainer(inMemory: true)
        self.container = container
        return SwiftDataHabitRepository(modelContext: container.mainContext, calendar: calendar)
    }

    func testCompletionAndSkipOrderingAndGrouping() throws {
        let repository = try makeRepository()
        let apple = try repository.createHabit(
            HabitDraft(name: "Apple", iconName: "a", category: .other, polarity: .positive, schedule: .daily), at: day0
        )
        let banana = try repository.createHabit(
            HabitDraft(name: "Banana", iconName: "b", category: .other, polarity: .positive, schedule: .daily), at: day0
        )
        let cherry = try repository.createHabit(
            HabitDraft(name: "Cherry", iconName: "c", category: .other, polarity: .positive, schedule: .daily), at: day0
        )
        try repository.recordCompletion(habitID: apple.id, at: day0, source: .app, note: nil)
        try repository.recordSkip(habitID: banana.id, on: day0, reason: .illness)
        try repository.recordCompletion(habitID: cherry.id, at: day0, source: .app, note: nil)

        let viewModel = HistoryViewModel(repository: repository, calendar: calendar)
        viewModel.load(asOf: day0)

        XCTAssertEqual(viewModel.sections.count, 1)
        let section = try XCTUnwrap(viewModel.sections.first)
        XCTAssertEqual(section.id, key(day0))
        XCTAssertEqual(section.rows.map(\.habitName), ["Apple", "Banana", "Cherry"], "rows must be ordered alphabetically by habit name")
        XCTAssertEqual(section.rows.map(\.kindLabel), ["Completed", "Skipped", "Completed"])
    }

    func testHalfOpenDateRangeBoundaries() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book", category: .other, polarity: .positive, schedule: .daily), at: day(0)
        )
        let asOf = day(29)
        // The 30-day window is [asOf's day - 29, asOf's day + 1), i.e. exactly
        // [day(0)'s midnight, day(30)'s midnight). Using those precise instants
        // (not just "some time on day(0)/day(30)") tests the boundary itself.
        let dayStart = calendar.startOfDay(for: asOf)
        let rangeStart = try XCTUnwrap(calendar.date(byAdding: .day, value: -29, to: dayStart))
        let rangeEnd = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: dayStart))

        try repository.recordCompletion(habitID: habit.id, at: rangeStart, source: .app, note: nil)
        try repository.recordCompletion(habitID: habit.id, at: rangeEnd, source: .app, note: nil)

        let viewModel = HistoryViewModel(repository: repository, calendar: calendar)
        viewModel.load(asOf: asOf)

        let allKeys = viewModel.sections.map(\.id)
        XCTAssertTrue(allKeys.contains(key(rangeStart)), "the range start is inclusive")
        XCTAssertFalse(allKeys.contains(key(rangeEnd)), "the range end is exclusive")
    }

    /// `completions(in:)` filters by precise instant; `skips(in:)` filters by
    /// comparing stored local-day keys, since a skip only ever carries a day,
    /// not an instant (see `SwiftDataHabitRepository.skips(in:)`). Those are two
    /// different mechanisms computing membership in the *same* range, so a
    /// boundary bug could make one disagree with the other even though each is
    /// independently well-tested. This locks in that a completion and a skip
    /// recorded at the exact same boundary instant land in the same section —
    /// or are excluded together — regardless of which filtering mechanism
    /// produced that answer.
    func testCompletionAndSkipRangeBoundariesAgree() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book", category: .other, polarity: .positive, schedule: .daily), at: day(0)
        )
        let asOf = day(29)
        let dayStart = calendar.startOfDay(for: asOf)
        let rangeStart = try XCTUnwrap(calendar.date(byAdding: .day, value: -29, to: dayStart))
        let rangeEnd = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: dayStart))

        try repository.recordCompletion(habitID: habit.id, at: rangeStart, source: .app, note: nil)
        try repository.recordSkip(habitID: habit.id, on: rangeStart, reason: .illness)
        try repository.recordCompletion(habitID: habit.id, at: rangeEnd, source: .app, note: nil)
        try repository.recordSkip(habitID: habit.id, on: rangeEnd, reason: .illness)

        let viewModel = HistoryViewModel(repository: repository, calendar: calendar)
        viewModel.load(asOf: asOf)

        let startSection = try XCTUnwrap(viewModel.sections.first { $0.id == key(rangeStart) })
        XCTAssertEqual(
            Set(startSection.rows.map(\.kindLabel)), Set(["Completed", "Skipped"]),
            "both the completion and the skip at the range's inclusive start must appear together"
        )
        XCTAssertNil(
            viewModel.sections.first { $0.id == key(rangeEnd) },
            "neither the completion nor the skip at the range's exclusive end must appear"
        )
    }

    func testStoredLocalDayGroupingSurvivesACurrentTimeZoneChange() throws {
        let repository = try makeRepository() // records written under America/New_York
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book", category: .other, polarity: .positive, schedule: .daily), at: day0
        )
        // 2024-06-18 23:30 America/New_York — already 2024-06-19 in Asia/Tokyo.
        let instant = Date(timeIntervalSince1970: 1_718_767_800)
        let completion = try repository.recordCompletion(habitID: habit.id, at: instant, source: .app, note: nil)
        XCTAssertEqual(completion.localDateKey, "2024-06-18")

        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        tokyo.locale = Locale(identifier: "en_US_POSIX")
        tokyo.firstWeekday = 1
        // Same underlying store, but everything now evaluates "now" (and would
        // recompute any date) under Tokyo's calendar instead.
        let tokyoRepository = SwiftDataHabitRepository(modelContext: try XCTUnwrap(container).mainContext, calendar: tokyo)
        let viewModel = HistoryViewModel(repository: tokyoRepository, calendar: tokyo)
        viewModel.load(asOf: instant)

        let sectionIDs = viewModel.sections.map(\.id)
        XCTAssertTrue(sectionIDs.contains("2024-06-18"), "grouping must use the stored key, not a key recomputed under the new current time zone")
        XCTAssertFalse(sectionIDs.contains("2024-06-19"))
    }

    func testArchivedHabitInclusionAndFiltering() throws {
        let repository = try makeRepository()
        let oldHabit = try repository.createHabit(
            HabitDraft(name: "Old Habit", iconName: "book", category: .other, polarity: .positive, schedule: .daily), at: day0
        )
        let newHabit = try repository.createHabit(
            HabitDraft(name: "New Habit", iconName: "book", category: .other, polarity: .positive, schedule: .daily), at: day0
        )
        try repository.recordCompletion(habitID: oldHabit.id, at: day0, source: .app, note: nil)
        try repository.recordCompletion(habitID: newHabit.id, at: day0, source: .app, note: nil)
        try repository.archiveHabit(id: oldHabit.id, at: day(1))

        let viewModel = HistoryViewModel(repository: repository, calendar: calendar)
        viewModel.load(asOf: day(1))

        let section = try XCTUnwrap(viewModel.sections.first)
        XCTAssertEqual(section.rows.count, 2, "an archived habit's past records must still appear")
        XCTAssertEqual(section.rows.first { $0.habitName == "Old Habit" }?.isHabitArchived, true)
        XCTAssertEqual(
            Set(viewModel.habitOptions.map(\.label)), Set(["New Habit", "Old Habit (Archived)"]),
            "the habit filter must list archived habits too, clearly marked"
        )

        viewModel.selectedHabitID = oldHabit.id
        viewModel.load(asOf: day(1))
        let filteredSection = try XCTUnwrap(viewModel.sections.first)
        XCTAssertEqual(filteredSection.rows.map(\.habitName), ["Old Habit"])
    }

    func testHistoricalScheduleContextReflectsConfigurationAtTheTime() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book", category: .other, polarity: .positive, schedule: .daily), at: day0
        )
        try repository.recordCompletion(habitID: habit.id, at: day0, source: .app, note: nil)
        try repository.updateHabit(
            id: habit.id,
            with: HabitDraft(name: "Read", iconName: "book", category: .other, polarity: .positive, schedule: .timesPerWeek(3)),
            at: day(5)
        )
        try repository.recordCompletion(habitID: habit.id, at: day(6), source: .app, note: nil)

        let viewModel = HistoryViewModel(repository: repository, calendar: calendar)
        viewModel.load(asOf: day(6))

        let dayZeroRow = try XCTUnwrap(viewModel.sections.first { $0.id == key(day0) }?.rows.first)
        let daySixRow = try XCTUnwrap(viewModel.sections.first { $0.id == key(day(6)) }?.rows.first)
        XCTAssertEqual(dayZeroRow.scheduleContextLabel, "Daily", "must reflect the schedule effective on that record's day, not the current one")
        XCTAssertEqual(daySixRow.scheduleContextLabel, "3x / week")
    }

    func testUndoneCompletionsDoNotAppear() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book", category: .other, polarity: .positive, schedule: .daily), at: day0
        )
        let completion = try repository.recordCompletion(habitID: habit.id, at: day0, source: .app, note: nil)
        try repository.undoCompletion(id: completion.id)

        let viewModel = HistoryViewModel(repository: repository, calendar: calendar)
        viewModel.load(asOf: day0)

        XCTAssertTrue(viewModel.sections.isEmpty, "an undone completion must not appear in history")
    }

    func testEmptyStateWhenNoRecordsInRange() throws {
        let repository = try makeRepository()
        try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book", category: .other, polarity: .positive, schedule: .daily), at: day0
        )

        let viewModel = HistoryViewModel(repository: repository, calendar: calendar)
        viewModel.load(asOf: day0)

        XCTAssertTrue(viewModel.sections.isEmpty)
        XCTAssertEqual(viewModel.habitOptions.count, 1, "the filter list is populated even with no records yet")
    }

    func testMultipleCompletionsOnSameDayAreAllPreservedNotDeduplicated() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book", category: .other, polarity: .positive, schedule: .daily), at: day0
        )
        let first = try repository.recordCompletion(habitID: habit.id, at: day0, source: .app, note: nil)
        let second = try repository.recordCompletion(habitID: habit.id, at: day0.addingTimeInterval(7200), source: .app, note: nil)

        let viewModel = HistoryViewModel(repository: repository, calendar: calendar)
        viewModel.load(asOf: day0)

        let section = try XCTUnwrap(viewModel.sections.first)
        XCTAssertEqual(section.rows.count, 2, "progress calculations treat same-day completions as one, but History must show every actual record")
        XCTAssertEqual(section.rows.map(\.id), [first.id, second.id], "same-day, same-habit rows are ordered by time")
    }
    func testAttentionHistoryPreservesManualAmountsAndHistoricalBudget() throws {
        let repository = try makeRepository()
        let attention = SwiftDataAttentionRepository(modelContext: try XCTUnwrap(container).mainContext, calendar: calendar)
        let goal = try attention.createGoal(AttentionGoalDraft(name: "News", appOrCategoryLabel: nil,
            type: .maxDurationPerDay, targetValue: 30, unit: .minutes), at: day0)
        let entry = try attention.recordUsage(goalID: goal.id, amount: 15, at: day0, source: .manual)
        _ = try attention.updateGoal(id: goal.id, with: AttentionGoalDraft(name: "News", appOrCategoryLabel: nil,
            type: .maxDurationPerDay, targetValue: 60, unit: .minutes), at: day(1))
        let model = HistoryViewModel(repository: repository, attentionRepository: attention, calendar: calendar)
        model.load(asOf: day(2))
        let row = try XCTUnwrap(model.sections.first?.rows.first)
        XCTAssertEqual(row.id, entry.id)
        XCTAssertEqual(row.kindLabel, "Usage logged")
        XCTAssertTrue(row.detailText?.contains("15 min logged manually") == true)
        XCTAssertTrue(row.scheduleContextLabel.contains("30"))
        XCTAssertFalse(row.scheduleContextLabel.contains("60"))
        XCTAssertEqual(model.sections.first?.id, entry.localDateKey)
    }

    func testSelectingAHabitExcludesAttentionHistoryWithoutLosingUnfilteredEntries() throws {
        let repository = try makeRepository()
        let attention = SwiftDataAttentionRepository(modelContext: try XCTUnwrap(container).mainContext, calendar: calendar)
        let habit = try repository.createHabit(HabitDraft(name: "Read", iconName: "book", category: .other,
            polarity: .positive, schedule: .daily), at: day0)
        let goal = try attention.createGoal(AttentionGoalDraft(name: "News", appOrCategoryLabel: nil,
            type: .maxDurationPerDay, targetValue: 30, unit: .minutes), at: day0)
        _ = try attention.recordUsage(goalID: goal.id, amount: 5, at: day0, source: .manual)
        _ = try repository.recordCompletion(habitID: habit.id, at: day0, source: .app, note: nil)
        let model = HistoryViewModel(repository: repository, attentionRepository: attention, calendar: calendar)
        model.selectedHabitID = habit.id
        model.load(asOf: day0)
        XCTAssertEqual(model.sections.flatMap(\.rows).map(\.kindLabel), ["Completed"])
        model.selectedHabitID = nil
        model.load(asOf: day0)
        XCTAssertEqual(model.sections.flatMap(\.rows).count, 2)
    }

}
