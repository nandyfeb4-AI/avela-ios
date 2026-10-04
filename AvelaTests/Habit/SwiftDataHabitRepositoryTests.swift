import Foundation
import SwiftData
import XCTest
@testable import Avela

@MainActor
final class SwiftDataHabitRepositoryTests: XCTestCase {
    // A ModelContext does not keep its container alive. Retain the fixture's
    // container for the whole test, just as the app's composition root does.
    private var container: ModelContainer?

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 1
        return calendar
    }()

    private func makeRepository() throws -> SwiftDataHabitRepository {
        let container = try AppPersistence.makeContainer(inMemory: true)
        self.container = container
        return SwiftDataHabitRepository(modelContext: container.mainContext, calendar: calendar)
    }

    private let day1 = Date(timeIntervalSince1970: 1_718_632_800) // Mon 2024-06-17
    private let day2 = Date(timeIntervalSince1970: 1_718_805_600) // Wed 2024-06-19

    func testCreateHabitPersistsFieldsAndInitialConfigurationSnapshot() throws {
        let repository = try makeRepository()
        let draft = HabitDraft(name: "Read", iconName: "book", category: .learning, polarity: .positive, schedule: .daily)

        let habit = try repository.createHabit(draft, at: day1)

        XCTAssertEqual(habit.name, "Read")
        XCTAssertEqual(habit.schedule, .daily)
        XCTAssertFalse(habit.isArchived)

        let history = try repository.configurationHistory(for: habit.id)
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.schedule, .daily)
        XCTAssertEqual(history.first?.effectiveLocalDateKey, "2024-06-17")
    }

    func testFetchHabitsExcludesArchivedUnlessRequested() throws {
        let repository = try makeRepository()
        let draft = HabitDraft(name: "Walk", iconName: "figure.walk", category: .fitness, polarity: .positive, schedule: .daily)
        let habit = try repository.createHabit(draft, at: day1)
        try repository.archiveHabit(id: habit.id, at: day2)

        XCTAssertEqual(try repository.fetchHabits(includeArchived: false).count, 0)
        let archived = try repository.fetchHabits(includeArchived: true)
        XCTAssertEqual(archived.count, 1)
        XCTAssertTrue(archived[0].isArchived)
    }

    func testReactivateHabitClearsArchivedAt() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Walk", iconName: "figure.walk", category: .fitness, polarity: .positive, schedule: .daily),
            at: day1
        )
        try repository.archiveHabit(id: habit.id, at: day2)
        try repository.reactivateHabit(id: habit.id, at: day2)

        let reactivated = try repository.fetchHabit(id: habit.id)
        XCTAssertFalse(try XCTUnwrap(reactivated).isArchived)
    }

    func testUpdatingNameOnlyDoesNotAppendConfigurationSnapshot() throws {
        let repository = try makeRepository()
        let draft = HabitDraft(name: "Read", iconName: "book", category: .learning, polarity: .positive, schedule: .daily)
        let habit = try repository.createHabit(draft, at: day1)

        var renamed = draft
        renamed.name = "Read Daily"
        let updated = try repository.updateHabit(id: habit.id, with: renamed, at: day2)

        XCTAssertEqual(updated.name, "Read Daily")
        let history = try repository.configurationHistory(for: habit.id)
        XCTAssertEqual(history.count, 1, "cosmetic edits must not fabricate configuration history")
    }

    func testEditingScheduleAppendsSnapshotAndPreservesPriorHistory() throws {
        let repository = try makeRepository()
        let draft = HabitDraft(name: "Read", iconName: "book", category: .learning, polarity: .positive, schedule: .daily)
        let habit = try repository.createHabit(draft, at: day1)

        var edited = draft
        edited.schedule = .timesPerWeek(3)
        let updated = try repository.updateHabit(id: habit.id, with: edited, at: day2)

        XCTAssertEqual(updated.schedule, .timesPerWeek(3))
        let history = try repository.configurationHistory(for: habit.id)
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].schedule, .daily)
        XCTAssertEqual(history[0].effectiveLocalDateKey, "2024-06-17")
        XCTAssertEqual(history[1].schedule, .timesPerWeek(3))
        XCTAssertEqual(history[1].effectiveLocalDateKey, "2024-06-19")

        // The configuration active on day1 is still "daily", unaffected by the later edit.
        let configurationOnDay1 = try repository.activeConfiguration(for: habit.id, on: day1)
        XCTAssertEqual(configurationOnDay1?.schedule, .daily)
        let configurationOnDay2 = try repository.activeConfiguration(for: habit.id, on: day2)
        XCTAssertEqual(configurationOnDay2?.schedule, .timesPerWeek(3))
    }

    func testTwoEditsOnTheSameLocalDayResolveToTheLatestOne() throws {
        let repository = try makeRepository()
        let draft = HabitDraft(name: "Read", iconName: "book", category: .learning, polarity: .positive, schedule: .daily)
        let habit = try repository.createHabit(draft, at: day1)

        var firstEditToday = draft
        firstEditToday.schedule = .timesPerWeek(2)
        _ = try repository.updateHabit(id: habit.id, with: firstEditToday, at: day1.addingTimeInterval(3600))

        var secondEditToday = draft
        secondEditToday.schedule = .timesPerWeek(5)
        let updated = try repository.updateHabit(id: habit.id, with: secondEditToday, at: day1.addingTimeInterval(7200))

        XCTAssertEqual(updated.schedule, .timesPerWeek(5))

        let history = try repository.configurationHistory(for: habit.id)
        XCTAssertEqual(history.count, 3, "creation + two same-day edits")
        XCTAssertEqual(history.map(\.schedule), [.daily, .timesPerWeek(2), .timesPerWeek(5)])

        // Resolving "today" must return the *second* same-day edit, not whichever
        // snapshot happens to be stored/fetched first.
        let active = try repository.activeConfiguration(for: habit.id, on: day1.addingTimeInterval(7200))
        XCTAssertEqual(active?.schedule, .timesPerWeek(5))
    }

    func testTwoEditsWithIdenticalTimestampResolveToTheLatestOneByRevision() throws {
        // A realistic variant of the same-day-edits case: both edits are made
        // from the *same* captured `Date()` (e.g. a caller reusing a `now`
        // reference for two rapid calls), so their `createdAt` is identical, not
        // just their local day. Only a persisted, strictly increasing revision
        // can disambiguate this; `createdAt` cannot.
        let repository = try makeRepository()
        let draft = HabitDraft(name: "Read", iconName: "book", category: .learning, polarity: .positive, schedule: .daily)
        let habit = try repository.createHabit(draft, at: day1)

        let sharedEditTimestamp = day1.addingTimeInterval(3600)
        var firstEdit = draft
        firstEdit.schedule = .timesPerWeek(2)
        _ = try repository.updateHabit(id: habit.id, with: firstEdit, at: sharedEditTimestamp)

        var secondEdit = draft
        secondEdit.schedule = .timesPerWeek(5)
        let updated = try repository.updateHabit(id: habit.id, with: secondEdit, at: sharedEditTimestamp)

        XCTAssertEqual(updated.schedule, .timesPerWeek(5))

        let history = try repository.configurationHistory(for: habit.id)
        XCTAssertEqual(history.count, 3)
        XCTAssertEqual(history[1].createdAt, history[2].createdAt, "the point of this test is a createdAt collision")
        XCTAssertEqual(history.map(\.schedule), [.daily, .timesPerWeek(2), .timesPerWeek(5)])
        XCTAssertEqual(history.map(\.revision), [0, 1, 2])

        let active = try repository.activeConfiguration(for: habit.id, on: sharedEditTimestamp)
        XCTAssertEqual(active?.schedule, .timesPerWeek(5))
    }

    func testEditingPolarityAlsoAppendsSnapshot() throws {
        let repository = try makeRepository()
        let draft = HabitDraft(name: "Snacking", iconName: "fork.knife", category: .health, polarity: .avoidance, schedule: .daily)
        let habit = try repository.createHabit(draft, at: day1)

        var edited = draft
        edited.polarity = .positive
        _ = try repository.updateHabit(id: habit.id, with: edited, at: day2)

        let history = try repository.configurationHistory(for: habit.id)
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].polarity, .avoidance)
        XCTAssertEqual(history[1].polarity, .positive)
    }

    func testEditingHabitDoesNotCorruptExistingCompletions() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book", category: .learning, polarity: .positive, schedule: .daily),
            at: day1
        )
        let completion = try repository.recordCompletion(habitID: habit.id, at: day1, source: .app, note: nil)

        var edited = HabitDraft(name: "Read", iconName: "book", category: .learning, polarity: .positive, schedule: .timesPerWeek(3))
        _ = try repository.updateHabit(id: habit.id, with: edited, at: day2)
        edited.name = "Read More"
        _ = try repository.updateHabit(id: habit.id, with: edited, at: day2)

        let interval = DateInterval(start: day1.addingTimeInterval(-86_400), end: day2.addingTimeInterval(86_400))
        let completions = try repository.completions(for: habit.id, in: interval)
        XCTAssertEqual(completions.count, 1)
        XCTAssertEqual(completions.first?.id, completion.id)
        XCTAssertEqual(completions.first?.localDateKey, "2024-06-17")
    }

    func testEditingHabitDoesNotCorruptExistingSkips() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book", category: .learning, polarity: .positive, schedule: .daily),
            at: day1
        )
        let skip = try repository.recordSkip(habitID: habit.id, on: day1, reason: .illness)

        var edited = HabitDraft(name: "Read", iconName: "book", category: .learning, polarity: .positive, schedule: .timesPerWeek(3))
        _ = try repository.updateHabit(id: habit.id, with: edited, at: day2)
        edited.name = "Read More"
        _ = try repository.updateHabit(id: habit.id, with: edited, at: day2)

        let interval = DateInterval(start: day1.addingTimeInterval(-86_400), end: day2.addingTimeInterval(86_400))
        let skips = try repository.skips(for: habit.id, in: interval)
        XCTAssertEqual(skips.count, 1)
        XCTAssertEqual(skips.first?.id, skip.id)
        XCTAssertEqual(skips.first?.reason, .illness)
        XCTAssertEqual(skips.first?.localDateKey, "2024-06-17")
    }

    func testUndoCompletionRemovesIt() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book", category: .learning, polarity: .positive, schedule: .daily),
            at: day1
        )
        let completion = try repository.recordCompletion(habitID: habit.id, at: day1, source: .app, note: nil)
        try repository.undoCompletion(id: completion.id)

        let interval = DateInterval(start: day1.addingTimeInterval(-3600), end: day1.addingTimeInterval(3600))
        XCTAssertEqual(try repository.completions(for: habit.id, in: interval).count, 0)
    }

    func testUndoCompletionWithUnknownIDThrows() throws {
        let repository = try makeRepository()
        let unknownID = UUID()
        XCTAssertThrowsError(try repository.undoCompletion(id: unknownID)) { error in
            XCTAssertEqual(error as? HabitRepositoryError, .completionNotFound(unknownID))
        }
    }

    func testRecordSkipIsDistinctFromCompletion() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book", category: .learning, polarity: .positive, schedule: .daily),
            at: day1
        )
        let skip = try repository.recordSkip(habitID: habit.id, on: day1, reason: .travel)

        XCTAssertEqual(skip.reason, .travel)
        XCTAssertEqual(skip.localDateKey, "2024-06-17")
        let interval = DateInterval(start: day1.addingTimeInterval(-3600), end: day1.addingTimeInterval(3600))
        XCTAssertEqual(try repository.skips(for: habit.id, in: interval).count, 1)
        XCTAssertEqual(try repository.completions(for: habit.id, in: interval).count, 0)
    }

    func testRecordingAgainstUnknownHabitThrows() throws {
        let repository = try makeRepository()
        XCTAssertThrowsError(try repository.recordCompletion(habitID: UUID(), at: day1, source: .app, note: nil))
    }

    func testCreatingHabitWithEmptyWeekdaysThrowsInvalidSchedule() throws {
        let repository = try makeRepository()
        let draft = HabitDraft(name: "Exercise", iconName: "figure.run", category: .fitness, polarity: .positive, schedule: .weekdays([]))
        XCTAssertThrowsError(try repository.createHabit(draft, at: day1)) { error in
            XCTAssertEqual(error as? HabitRepositoryError, .invalidSchedule)
        }
    }

    func testCreatingHabitWithOutOfRangeTimesPerWeekThrows() throws {
        let repository = try makeRepository()
        let draft = HabitDraft(name: "Exercise", iconName: "figure.run", category: .fitness, polarity: .positive, schedule: .timesPerWeek(8))
        XCTAssertThrowsError(try repository.createHabit(draft, at: day1)) { error in
            XCTAssertEqual(error as? HabitRepositoryError, .invalidSchedule)
        }
    }

    func testCreatingHabitWithZeroTimesPerWeekThrows() throws {
        let repository = try makeRepository()
        let draft = HabitDraft(name: "Exercise", iconName: "figure.run", category: .fitness, polarity: .positive, schedule: .timesPerWeek(0))
        XCTAssertThrowsError(try repository.createHabit(draft, at: day1)) { error in
            XCTAssertEqual(error as? HabitRepositoryError, .invalidSchedule)
        }
    }

    func testUpdatingUnknownHabitThrows() throws {
        let repository = try makeRepository()
        let unknownID = UUID()
        let draft = HabitDraft(name: "Ghost", iconName: "questionmark", category: .other, polarity: .positive, schedule: .daily)
        XCTAssertThrowsError(try repository.updateHabit(id: unknownID, with: draft, at: day1)) { error in
            XCTAssertEqual(error as? HabitRepositoryError, .habitNotFound(unknownID))
        }
    }

    func testArchivingUnknownHabitThrows() throws {
        let repository = try makeRepository()
        let unknownID = UUID()
        XCTAssertThrowsError(try repository.archiveHabit(id: unknownID, at: day1)) { error in
            XCTAssertEqual(error as? HabitRepositoryError, .habitNotFound(unknownID))
        }
    }

    func testReactivatingUnknownHabitThrows() throws {
        let repository = try makeRepository()
        let unknownID = UUID()
        XCTAssertThrowsError(try repository.reactivateHabit(id: unknownID, at: day1)) { error in
            XCTAssertEqual(error as? HabitRepositoryError, .habitNotFound(unknownID))
        }
    }

    func testArchivingOpensAnArchivePeriod() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book", category: .learning, polarity: .positive, schedule: .daily),
            at: day1
        )
        try repository.archiveHabit(id: habit.id, at: day2)

        let periods = try repository.archivePeriods(for: habit.id)
        XCTAssertEqual(periods.count, 1)
        XCTAssertEqual(periods.first?.archivedAt, day2)
        XCTAssertNil(periods.first?.reactivatedAt)
        XCTAssertTrue(periods.first?.isOpen ?? false)
    }

    func testReactivatingClosesTheOpenArchivePeriod() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book", category: .learning, polarity: .positive, schedule: .daily),
            at: day1
        )
        try repository.archiveHabit(id: habit.id, at: day2)
        let reactivationDate = day2.addingTimeInterval(86_400)
        try repository.reactivateHabit(id: habit.id, at: reactivationDate)

        let periods = try repository.archivePeriods(for: habit.id)
        XCTAssertEqual(periods.count, 1)
        XCTAssertEqual(periods.first?.archivedAt, day2)
        XCTAssertEqual(periods.first?.reactivatedAt, reactivationDate)
        XCTAssertFalse(periods.first?.isOpen ?? true)
    }

    func testRepeatedArchiveReactivateCyclesCreateSeparatePeriods() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book", category: .learning, polarity: .positive, schedule: .daily),
            at: day1
        )
        let firstArchive = day1.addingTimeInterval(86_400)
        let firstReactivate = day1.addingTimeInterval(2 * 86_400)
        let secondArchive = day1.addingTimeInterval(3 * 86_400)
        let secondReactivate = day1.addingTimeInterval(4 * 86_400)

        try repository.archiveHabit(id: habit.id, at: firstArchive)
        try repository.reactivateHabit(id: habit.id, at: firstReactivate)
        try repository.archiveHabit(id: habit.id, at: secondArchive)
        try repository.reactivateHabit(id: habit.id, at: secondReactivate)

        let periods = try repository.archivePeriods(for: habit.id)
        XCTAssertEqual(periods.count, 2, "each archive/reactivate cycle must be preserved, not overwritten")
        XCTAssertEqual(periods[0].archivedAt, firstArchive)
        XCTAssertEqual(periods[0].reactivatedAt, firstReactivate)
        XCTAssertEqual(periods[1].archivedAt, secondArchive)
        XCTAssertEqual(periods[1].reactivatedAt, secondReactivate)
    }

    func testArchivingAnAlreadyArchivedHabitDoesNotOpenASecondPeriod() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book", category: .learning, polarity: .positive, schedule: .daily),
            at: day1
        )
        try repository.archiveHabit(id: habit.id, at: day2)
        try repository.archiveHabit(id: habit.id, at: day2.addingTimeInterval(86_400)) // repeat call, still archived

        let periods = try repository.archivePeriods(for: habit.id)
        XCTAssertEqual(periods.count, 1, "re-archiving an already-archived habit must not create a second open period")
    }

    // MARK: - Cross-habit queries (History)

    func testCompletionsAcrossHabitsReturnsRecordsFromEveryHabit() throws {
        let repository = try makeRepository()
        let habitA = try repository.createHabit(
            HabitDraft(name: "A", iconName: "a", category: .other, polarity: .positive, schedule: .daily), at: day1
        )
        let habitB = try repository.createHabit(
            HabitDraft(name: "B", iconName: "b", category: .other, polarity: .positive, schedule: .daily), at: day1
        )
        let completionA = try repository.recordCompletion(habitID: habitA.id, at: day1, source: .app, note: nil)
        let completionB = try repository.recordCompletion(habitID: habitB.id, at: day1, source: .app, note: nil)

        let all = try repository.completions(in: DateInterval(start: day1.addingTimeInterval(-3600), end: day1.addingTimeInterval(3600)))
        XCTAssertEqual(Set(all.map(\.id)), Set([completionA.id, completionB.id]))
    }

    func testCompletionsAcrossHabitsRespectsHalfOpenRange() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "A", iconName: "a", category: .other, polarity: .positive, schedule: .daily), at: day1
        )
        try repository.recordCompletion(habitID: habit.id, at: day1, source: .app, note: nil)
        try repository.recordCompletion(habitID: habit.id, at: day2, source: .app, note: nil)

        let results = try repository.completions(in: DateInterval(start: day1, end: day2))
        XCTAssertEqual(results.count, 1, "the range's end (day2) must be excluded")
    }

    func testSkipsAcrossHabitsReturnsRecordsFromEveryHabit() throws {
        let repository = try makeRepository()
        let habitA = try repository.createHabit(
            HabitDraft(name: "A", iconName: "a", category: .other, polarity: .positive, schedule: .daily), at: day1
        )
        let habitB = try repository.createHabit(
            HabitDraft(name: "B", iconName: "b", category: .other, polarity: .positive, schedule: .daily), at: day1
        )
        let skipA = try repository.recordSkip(habitID: habitA.id, on: day1, reason: .illness)
        let skipB = try repository.recordSkip(habitID: habitB.id, on: day1, reason: .travel)

        let all = try repository.skips(in: DateInterval(start: day1.addingTimeInterval(-3600), end: day1.addingTimeInterval(3600)))
        XCTAssertEqual(Set(all.map(\.id)), Set([skipA.id, skipB.id]))
    }

    func testSkipsAcrossHabitsRespectsHalfOpenRange() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "A", iconName: "a", category: .other, polarity: .positive, schedule: .daily), at: day1
        )
        try repository.recordSkip(habitID: habit.id, on: day1, reason: .illness)
        try repository.recordSkip(habitID: habit.id, on: day2, reason: .illness)

        // Skips are day-granular (only a localDateKey, no instant), so the
        // range boundary that actually matters is the calendar day, not a raw
        // Date offset: midnight-aligned bounds are what every real caller
        // (HistoryViewModel) passes, and are what meaningfully exercises
        // "the day containing the range's end is excluded."
        let rangeStart = calendar.startOfDay(for: day1)
        let rangeEnd = calendar.startOfDay(for: day2)
        let results = try repository.skips(in: DateInterval(start: rangeStart, end: rangeEnd))
        XCTAssertEqual(results.count, 1, "the calendar day containing the range's end (day2) must be excluded")
    }

    func testCompletionsAcrossHabitsIncludesArchivedHabitRecords() throws {
        let repository = try makeRepository()
        let habit = try repository.createHabit(
            HabitDraft(name: "Read", iconName: "book", category: .learning, polarity: .positive, schedule: .daily), at: day1
        )
        let completion = try repository.recordCompletion(habitID: habit.id, at: day1, source: .app, note: nil)
        try repository.archiveHabit(id: habit.id, at: day2)

        let results = try repository.completions(in: DateInterval(start: day1.addingTimeInterval(-3600), end: day2.addingTimeInterval(86_400)))
        XCTAssertTrue(results.contains { $0.id == completion.id }, "archiving a habit must not hide its past completions from a cross-habit query")
    }
}
