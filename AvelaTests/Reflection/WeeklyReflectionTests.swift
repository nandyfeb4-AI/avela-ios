import XCTest
import SwiftData
@testable import Avela

@MainActor
final class WeeklyReflectionTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/Denver")!
        value.firstWeekday = 2
        value.minimumDaysInFirstWeek = 4
        return value
    }
    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
    private func container(url: URL? = nil) throws -> ModelContainer {
        let schema = Schema([WeeklyReflectionRecord.self])
        let configuration: ModelConfiguration
        if let url { configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none) }
        else { configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none) }
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    func testWeekIdentityHonorsFirstWeekdayAndDST() {
        let spring = ReflectionWeek.containing(date(2026, 3, 8), calendar: calendar)
        XCTAssertEqual(spring.key, "2026-03-02/2026-03-09")
        XCTAssertEqual(spring.end.timeIntervalSince(spring.start), 167 * 3600)
        let fall = ReflectionWeek.containing(date(2026, 11, 1), calendar: calendar)
        XCTAssertEqual(fall.end.timeIntervalSince(fall.start), 169 * 3600)
        var sunday = calendar
        sunday.firstWeekday = 1
        XCTAssertEqual(ReflectionWeek.containing(date(2026, 3, 8), calendar: sunday).key, "2026-03-08/2026-03-15")
    }

    func testProgressUsesSelectedWeekAndExcludesSkippedAndOpenCommitments() throws {
        let store = try AppPersistence.makeContainer(inMemory: true)
        let habits = SwiftDataHabitRepository(modelContext: store.mainContext, calendar: calendar)
        let habit = try habits.createHabit(.init(name: "Read", iconName: "book.fill", category: .learning,
            polarity: .positive, schedule: .daily), at: date(2026, 10, 5))
        try habits.recordCompletion(habitID: habit.id, at: date(2026, 10, 5), source: .app, note: nil)
        try habits.recordSkip(habitID: habit.id, on: date(2026, 10, 6), reason: .planned)
        let notes = SwiftDataReflectionRepository(context: store.mainContext)
        let model = ReflectionViewModel(repository: notes, habits: habits, calendar: calendar, now: date(2026, 10, 7))
        model.load(asOf: date(2026, 10, 7))
        XCTAssertTrue(model.isCurrentWeek)
        XCTAssertEqual(model.habitResults.first?.successfulUnits, 1)
        XCTAssertEqual(model.habitResults.first?.scheduledUnits, 1)
        model.beginEditing(); model.draft.whatHelped = "Every day was successful"
        XCTAssertTrue(model.save(at: date(2026, 10, 7)))
        model.load(asOf: date(2026, 10, 8))
        XCTAssertEqual(model.habitResults.first?.successfulUnits, 1)
        XCTAssertEqual(model.habitResults.first?.scheduledUnits, 2)
        model.selectWeek(offset: -1, asOf: date(2026, 10, 8))
        XCTAssertTrue(model.habitResults.isEmpty)
        XCTAssertFalse(model.isCurrentWeek)
    }

    func testInsightsOpensReflectionForTheReviewedWeekRatherThanToday() throws {
        let store = try AppPersistence.makeContainer(inMemory: true)
        let habits = SwiftDataHabitRepository(modelContext: store.mainContext, calendar: calendar)
        let notes = SwiftDataReflectionRepository(context: store.mainContext)
        let insights = InsightsViewModel(repository: habits, calendar: calendar)
        insights.load(asOf: date(2026, 10, 19))
        insights.goToPreviousWeek(asOf: date(2026, 10, 19))
        let model = insights.reflectionModel(repository: notes)
        XCTAssertEqual(model.selectedWeek.key, "2026-10-05/2026-10-12")
        model.load(asOf: date(2026, 10, 19))
        XCTAssertFalse(model.isCurrentWeek)
    }

    func testCivilWeekKeyIsGregorianWithDifferentCalendarIdentifier() {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = calendar.timeZone
        buddhist.firstWeekday = calendar.firstWeekday
        let result = ReflectionWeek.containing(date(2026, 10, 5), calendar: buddhist)
        XCTAssertEqual(result.key, "2026-10-05/2026-10-12")
    }

    func testSaveUpsertsOneNoteWithoutChangingCapturedWeekOrCreationDate() throws {
        let store = try container()
        let repository = SwiftDataReflectionRepository(context: store.mainContext)
        let week = ReflectionWeek.containing(date(2026, 10, 5), calendar: calendar)
        XCTAssertNil(try repository.reflection(for: week))
        let original = try repository.save(.init(whatHelped: "  Walking  "), for: week, at: week.start)
        let updated = try repository.save(.init(whatGotInTheWay: "Busy afternoons"), for: week, at: week.end)
        XCTAssertEqual(updated.id, original.id)
        XCTAssertEqual(updated.createdAt, original.createdAt)
        XCTAssertEqual(updated.week, week)
        XCTAssertEqual(updated.updatedAt, week.end)
        XCTAssertEqual(original.whatHelped, "Walking")
        XCTAssertEqual(updated.whatHelped, "")
        XCTAssertEqual(try store.mainContext.fetchCount(FetchDescriptor<WeeklyReflectionRecord>()), 1)
    }

    func testInvalidAndOversizedDraftsCannotReplaceSavedNote() throws {
        let store = try container()
        let repository = SwiftDataReflectionRepository(context: store.mainContext)
        let week = ReflectionWeek.containing(date(2026, 10, 5), calendar: calendar)
        let original = try repository.save(.init(whatHelped: "Quiet mornings"), for: week, at: week.start)
        for draft in [ReflectionDraft(), .init(whatHelped: " \n "), .init(whatHelped: String(repeating: "a", count: 501))] {
            XCTAssertThrowsError(try repository.save(draft, for: week, at: week.end))
            XCTAssertEqual(try repository.reflection(for: week), original)
        }
        XCTAssertTrue(ReflectionDraft(whatHelped: String(repeating: "🦊", count: 500)).isValid)
    }

    func testCancelAndWeekNavigationNeverWriteDraftOrFutureWeek() throws {
        let store = try container()
        let repository = SwiftDataReflectionRepository(context: store.mainContext)
        let now = date(2026, 10, 5)
        let model = ReflectionViewModel(repository: repository, calendar: calendar, now: now)
        model.load()
        model.beginEditing()
        model.draft.whatHelped = "Unsaved"
        model.cancelEditing()
        XCTAssertFalse(model.draft.hasContent)
        XCTAssertEqual(try store.mainContext.fetchCount(FetchDescriptor<WeeklyReflectionRecord>()), 0)
        let originalWeek = model.selectedWeek
        model.selectWeek(offset: 1, asOf: now)
        XCTAssertEqual(model.selectedWeek, originalWeek)
        model.selectWeek(offset: -1, asOf: now)
        XCTAssertEqual(model.selectedWeek.key, "2026-09-28/2026-10-05")
        XCTAssertTrue(model.canMoveForward(asOf: now))
        model.selectWeek(offset: 1, asOf: now)
        XCTAssertEqual(model.selectedWeek, originalWeek)
    }

    func testEditingDraftAndDeleteAffectOnlySelectedWeek() throws {
        let store = try container()
        let repository = SwiftDataReflectionRepository(context: store.mainContext)
        let now = date(2026, 10, 5)
        let current = ReflectionWeek.containing(now, calendar: calendar)
        let prior = ReflectionWeek.containing(date(2026, 9, 28), calendar: calendar)
        try repository.save(.init(whatHelped: "Earlier note"), for: prior, at: prior.start)
        let model = ReflectionViewModel(repository: repository, calendar: calendar, now: now)
        model.load(); model.beginEditing()
        model.draft.whatHelped = "This week"
        XCTAssertTrue(model.save(at: now))
        model.beginEditing(); model.draft.whatHelped = "Unsaved edit"; model.cancelEditing()
        XCTAssertEqual(try repository.reflection(for: current)?.whatHelped, "This week")
        XCTAssertTrue(model.delete())
        XCTAssertNil(try repository.reflection(for: current))
        XCTAssertEqual(try repository.reflection(for: prior)?.whatHelped, "Earlier note")
    }

    func testReflectionSurvivesDiskReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Reflection.store")
        let week = ReflectionWeek.containing(date(2026, 10, 5), calendar: calendar)
        do {
            let store = try container(url: url)
            try SwiftDataReflectionRepository(context: store.mainContext).save(
                .init(whatHelped: "Less scrolling", whatGotInTheWay: "Late meetings"), for: week, at: week.start)
        }
        let reopened = try container(url: url)
        let note = try XCTUnwrap(SwiftDataReflectionRepository(context: reopened.mainContext).reflection(for: week))
        XCTAssertEqual(note.whatHelped, "Less scrolling")
        XCTAssertEqual(note.whatGotInTheWay, "Late meetings")
        XCTAssertEqual(note.week, week)
    }

    func testAddingReflectionModelPreservesExistingTrackingAndPreferences() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Upgrade.store")
        let previousModels: [any PersistentModel.Type] = [
            HealthHabitConnectionRecord.self, HabitReminderRecord.self, HabitRecord.self,
            HabitConfigurationSnapshotRecord.self, CompletionRecord.self, SkipRecord.self,
            HabitArchivePeriodRecord.self, AttentionGoalRecord.self,
            AttentionGoalConfigurationSnapshotRecord.self, AttentionUsageEntryRecord.self,
            AttentionCheckInRecord.self, AttentionSessionRecord.self, CompanionProfileRecord.self,
            AppAppearanceRecord.self]
        var habitID: UUID!
        do {
            let schema = Schema(previousModels)
            let previous = try ModelContainer(for: schema, configurations: [
                ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)])
            habitID = try SwiftDataHabitRepository(modelContext: previous.mainContext).createHabit(
                HabitDraft(name: "Preserve me", iconName: "book.fill", category: .learning,
                           polarity: .positive, schedule: .daily), at: date(2026, 10, 5)).id
            try SwiftDataAppearanceRepository(context: previous.mainContext).save(theme: .indigo)
        }
        let schema = Schema(previousModels + [WeeklyReflectionRecord.self])
        let upgraded = try ModelContainer(for: schema, configurations: [
            ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)])
        XCTAssertEqual(try SwiftDataHabitRepository(modelContext: upgraded.mainContext).fetchHabit(id: habitID)?.name, "Preserve me")
        XCTAssertEqual(try SwiftDataAppearanceRepository(context: upgraded.mainContext).theme(), .indigo)
        let repository = SwiftDataReflectionRepository(context: upgraded.mainContext)
        let week = ReflectionWeek.containing(date(2026, 10, 5), calendar: calendar)
        XCTAssertNil(try repository.reflection(for: week))
        try repository.save(.init(whatHelped: "An update kept my history"), for: week, at: week.start)
        XCTAssertEqual(try repository.reflection(for: week)?.whatHelped, "An update kept my history")
    }

    func testFailureKeepsDraftAndDoesNotClaimSavedNote() {
        let repository = FailingReflectionRepository()
        let model = ReflectionViewModel(repository: repository, calendar: calendar, now: date(2026, 10, 5))
        model.load(); model.beginEditing(); model.draft.whatHelped = "Keep this draft"
        XCTAssertFalse(model.save())
        XCTAssertEqual(model.draft.whatHelped, "Keep this draft")
        XCTAssertNil(model.reflection)
        XCTAssertNotNil(model.errorMessage)
        repository.failRead = true
        model.load()
        XCTAssertFalse(model.hasLoaded)
        XCTAssertFalse(model.save())
    }
}

@MainActor
private final class FailingReflectionRepository: ReflectionRepository {
    var failRead = false
    func reflection(for week: ReflectionWeek) throws -> WeeklyReflection? {
        if failRead { throw ReflectionRepositoryError.invalidDraft }
        return nil
    }
    func save(_ draft: ReflectionDraft, for week: ReflectionWeek, at date: Date) throws -> WeeklyReflection {
        throw ReflectionRepositoryError.invalidDraft
    }
    func delete(for week: ReflectionWeek) throws { throw ReflectionRepositoryError.invalidDraft }
}
