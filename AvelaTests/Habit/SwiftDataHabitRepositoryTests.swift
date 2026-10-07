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

    func testRecordWithoutOptionalMemoryDecodesToLegacyDefaults() {
        let record = HabitRecord(id: UUID(), name: "Existing habit", iconName: "book.fill",
            categoryRaw: "learning", polarityRaw: "positive", scheduleKindRaw: "daily",
            scheduleWeekdaysRaw: [], scheduleTimesPerWeek: nil, createdAt: day1,
            updatedAt: day1, archivedAt: nil, sortOrder: 0)
        XCTAssertNil(record.whyItMatters)
        XCTAssertNil(record.whyMemoryHidden)
        XCTAssertNil(record.toDomain().whyItMatters)
        XCTAssertFalse(record.toDomain().isWhyMemoryHidden)
    }

    func testPrivateMotivationPersistsWithoutChangingHistoricalFactsAndCanBeRemoved() throws {
        let repository = try makeRepository()
        var draft = HabitDraft(name: "Read", iconName: "book.fill", category: .learning,
            polarity: .positive, schedule: .daily, whyItMatters: "  Be curious for my children.  ")
        let habit = try repository.createHabit(draft, at: day1)
        XCTAssertEqual(habit.whyItMatters, "Be curious for my children.")
        let completion = try repository.recordCompletion(habitID: habit.id, at: day1, source: .app, note: nil)
        draft.whyItMatters = "Learn something new."
        draft.isWhyMemoryHidden = true
        _ = try repository.updateHabit(id: habit.id, with: draft, at: day2)
        let fresh = SwiftDataHabitRepository(modelContext: try XCTUnwrap(container).mainContext, calendar: calendar)
        XCTAssertEqual(try fresh.fetchHabit(id: habit.id)?.whyItMatters, "Learn something new.")
        XCTAssertEqual(try fresh.fetchHabit(id: habit.id)?.isWhyMemoryHidden, true)
        XCTAssertEqual(try fresh.configurationHistory(for: habit.id).count, 1)
        XCTAssertEqual(try fresh.completions(for: habit.id, in: DateInterval(start: day1, end: day2)).first, completion)
        draft.whyItMatters = "   "
        _ = try fresh.updateHabit(id: habit.id, with: draft, at: day2)
        XCTAssertNil(try fresh.fetchHabit(id: habit.id)?.whyItMatters)
    }

    func testInvalidMemoryEditLeavesPersistedHabitUntouched() throws {
        let repository = try makeRepository()
        var draft = HabitDraft(name: "Read", iconName: "book.fill", category: .learning,
            polarity: .positive, schedule: .daily, whyItMatters: "Stay curious.")
        let habit = try repository.createHabit(draft, at: day1)
        draft.name = "Changed"
        draft.whyItMatters = String(repeating: "x", count: 241)
        XCTAssertThrowsError(try repository.updateHabit(id: habit.id, with: draft, at: day2)) {
            XCTAssertEqual($0 as? HabitRepositoryError, .invalidWhyMemory)
        }
        XCTAssertEqual(try repository.fetchHabit(id: habit.id), habit)
        XCTAssertEqual(try repository.configurationHistory(for: habit.id).count, 1)
    }

    func testMemoryAndVisibilitySurviveDiskRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("memory.store")
        let id: UUID
        do {
            let store = try AppPersistence.makeContainer(storeURL: url)
            let repo = SwiftDataHabitRepository(modelContext: store.mainContext)
            id = try repo.createHabit(.init(name: "Read", iconName: "book.fill", category: .learning,
                polarity: .positive, schedule: .daily, whyItMatters: "Be curious.", isWhyMemoryHidden: true), at: day1).id
        }
        let reopened = try AppPersistence.makeContainer(storeURL: url)
        let habit = try XCTUnwrap(SwiftDataHabitRepository(modelContext: reopened.mainContext).fetchHabit(id: id))
        XCTAssertEqual(habit.whyItMatters, "Be curious.")
        XCTAssertTrue(habit.isWhyMemoryHidden)
    }

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

    // MARK: - Presentation ordering

    func testReorderedHabitsSurviveDiskRelaunchWithoutChangingHistoryOrTimestamps() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("HabitOrder.store")
        var expected: [Habit] = []
        var completionID: UUID!
        var skipID: UUID!
        var configurationIDs: [UUID] = []
        var archivePeriodID: UUID!
        do {
            let container = try AppPersistence.makeContainer(storeURL: storeURL)
            let repository = SwiftDataHabitRepository(modelContext: container.mainContext, calendar: calendar)
            let habits = try ["Read", "Walk", "Quiet"].map { try createOrderingHabit($0, repository: repository) }
            completionID = try repository.recordCompletion(habitID: habits[0].id, at: day1,
                                                           source: .app, note: "Keep this note").id
            skipID = try repository.recordSkip(habitID: habits[0].id, on: day2, reason: .travel).id
            var edited = HabitDraft(name: "Read more", iconName: "book.fill", category: .learning,
                                   polarity: .positive, schedule: .timesPerWeek(3))
            _ = try repository.updateHabit(id: habits[0].id, with: edited, at: day2)
            edited.polarity = .avoidance
            _ = try repository.updateHabit(id: habits[0].id, with: edited, at: day2)
            try repository.archiveHabit(id: habits[0].id, at: day2)
            try repository.reactivateHabit(id: habits[0].id, at: day2.addingTimeInterval(3600))
            configurationIDs = try repository.configurationHistory(for: habits[0].id).map(\.id)
            archivePeriodID = try repository.archivePeriods(for: habits[0].id).first?.id
            let before = try repository.fetchHabits(includeArchived: false)
            try repository.reorderHabits(ids: [habits[2].id, habits[0].id, habits[1].id])
            expected = try repository.fetchHabits(includeArchived: false)
            XCTAssertEqual(expected.map(\.id), [habits[2].id, habits[0].id, habits[1].id])
            for habit in expected {
                let original = try XCTUnwrap(before.first { $0.id == habit.id })
                XCTAssertEqual(habit.createdAt, original.createdAt)
                XCTAssertEqual(habit.updatedAt, original.updatedAt)
                XCTAssertEqual(habit.schedule, original.schedule)
                XCTAssertEqual(habit.polarity, original.polarity)
            }
        }
        let reopened = try AppPersistence.makeContainer(storeURL: storeURL)
        let repository = SwiftDataHabitRepository(modelContext: reopened.mainContext, calendar: calendar)
        XCTAssertEqual(try repository.fetchHabits(includeArchived: false), expected)
        let tracked = expected[1]
        let history = DateInterval(start: .distantPast, end: .distantFuture)
        let completions = try repository.completions(for: tracked.id, in: history)
        XCTAssertEqual(completions.map(\.id), [completionID!])
        XCTAssertEqual(completions.first?.note, "Keep this note")
        XCTAssertEqual(try repository.skips(for: tracked.id, in: history).map(\.id), [skipID!])
        XCTAssertEqual(try repository.configurationHistory(for: tracked.id).map(\.id), configurationIDs)
        XCTAssertEqual(try repository.archivePeriods(for: tracked.id).map(\.id), [archivePeriodID!])
    }

    func testInvalidHabitOrdersAreRejectedBeforeAnyMutation() throws {
        let repository = try makeRepository()
        let a = try createOrderingHabit("A", repository: repository)
        let b = try createOrderingHabit("B", repository: repository)
        let archived = try createOrderingHabit("Archived", repository: repository)
        try repository.archiveHabit(id: archived.id, at: day2)
        let before = try repository.fetchHabits(includeArchived: true)
        for invalid in [[], [a.id], [a.id, a.id], [a.id, UUID()], [a.id, archived.id], [a.id, b.id, archived.id]] {
            XCTAssertThrowsError(try repository.reorderHabits(ids: invalid)) { error in
                XCTAssertEqual(error as? HabitRepositoryError, .invalidHabitOrder)
            }
            XCTAssertEqual(try repository.fetchHabits(includeArchived: true), before)
        }
    }

    func testStaleOrderAfterCreationOrArchiveCannotOverwriteCurrentOrder() throws {
        let repository = try makeRepository()
        let a = try createOrderingHabit("A", repository: repository)
        let b = try createOrderingHabit("B", repository: repository)
        let c = try createOrderingHabit("C", repository: repository)
        let afterCreation = try repository.fetchHabits(includeArchived: true)
        XCTAssertThrowsError(try repository.reorderHabits(ids: [b.id, a.id]))
        XCTAssertEqual(try repository.fetchHabits(includeArchived: true), afterCreation)
        try repository.archiveHabit(id: c.id, at: day2)
        let afterArchive = try repository.fetchHabits(includeArchived: true)
        XCTAssertThrowsError(try repository.reorderHabits(ids: [c.id, b.id, a.id]))
        XCTAssertEqual(try repository.fetchHabits(includeArchived: true), afterArchive)
    }

    func testReorderingKeepsArchivedSlotAndNewHabitsAppendAfterReactivation() throws {
        let repository = try makeRepository()
        let habits = try ["A", "B", "C", "D"].map { try createOrderingHabit($0, repository: repository) }
        try repository.archiveHabit(id: habits[1].id, at: day2)
        let archived = try XCTUnwrap(repository.fetchHabit(id: habits[1].id))
        try repository.reorderHabits(ids: [habits[3].id, habits[2].id, habits[0].id])
        XCTAssertEqual(try repository.fetchHabits(includeArchived: false).map(\.sortOrder), [0, 2, 3])
        XCTAssertEqual(try repository.fetchHabit(id: archived.id), archived)
        try repository.reactivateHabit(id: archived.id, at: day2.addingTimeInterval(3600))
        XCTAssertEqual(try repository.fetchHabits(includeArchived: false).map(\.id),
                       [habits[3].id, habits[1].id, habits[2].id, habits[0].id])
        let appended = try createOrderingHabit("E", repository: repository)
        XCTAssertEqual(appended.sortOrder, 4)
        XCTAssertEqual(try repository.fetchHabits(includeArchived: false).last?.id, appended.id)
    }

    func testLegacyDuplicateOrdersFetchDeterministicallyAndCanBeRepaired() throws {
        let repository = try makeRepository()
        let active = try ["A", "B", "C"].map { try createOrderingHabit($0, repository: repository) }
        let archived = try createOrderingHabit("Archived", repository: repository)
        try repository.archiveHabit(id: archived.id, at: day2)
        let context = try XCTUnwrap(container).mainContext
        let records = try context.fetch(FetchDescriptor<HabitRecord>())
        for record in records { record.sortOrder = 0 }
        try context.save()
        let expectedLegacy = active.map(\.id).sorted { $0.uuidString < $1.uuidString }
        XCTAssertEqual(try repository.fetchHabits(includeArchived: false).map(\.id), expectedLegacy)
        let archivedBefore = try XCTUnwrap(repository.fetchHabit(id: archived.id))
        let requested = Array(expectedLegacy.reversed())
        try repository.reorderHabits(ids: requested)
        XCTAssertEqual(try repository.fetchHabits(includeArchived: false).map(\.id), requested)
        XCTAssertEqual(try repository.fetchHabits(includeArchived: false).map(\.sortOrder), [1, 2, 3])
        XCTAssertEqual(try repository.fetchHabit(id: archived.id), archivedBefore)
    }

    func testEmptyActiveOrderAcceptsEmptyInputWithoutChangingArchivedHabit() throws {
        let repository = try makeRepository()
        try repository.reorderHabits(ids: [])
        let habit = try createOrderingHabit("Paused", repository: repository)
        try repository.archiveHabit(id: habit.id, at: day2)
        let before = try repository.fetchHabits(includeArchived: true)
        try repository.reorderHabits(ids: [])
        XCTAssertEqual(try repository.fetchHabits(includeArchived: true), before)
        XCTAssertThrowsError(try repository.reorderHabits(ids: [habit.id]))
    }

    private func createOrderingHabit(_ name: String, repository: SwiftDataHabitRepository) throws -> Habit {
        try repository.createHabit(HabitDraft(name: name, iconName: "book.fill", category: .learning,
                                             polarity: .positive, schedule: .daily), at: day1)
    }

}
