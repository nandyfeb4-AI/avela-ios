import SwiftData
import XCTest
@testable import Avela

@MainActor
final class QuickLogTests: XCTestCase {
    private var container: ModelContainer!
    private var calendar: Calendar!
    private var date: Date!
    private var habits: SwiftDataHabitRepository!
    private var activities: SwiftDataHabitActivityRepository!

    override func setUpWithError() throws {
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: 12))!
        container = try AppPersistence.makeContainer(inMemory: true)
        habits = SwiftDataHabitRepository(modelContext: container.mainContext, calendar: calendar)
        activities = SwiftDataHabitActivityRepository(context: container.mainContext, habits: habits, calendar: calendar)
    }
    func testRichTideTextAndActionsHaveContrastAcrossEveryTheme() {
        func luminance(_ rgb: UInt32) -> Double {
            let channels = [16, 8, 0].map { Double((rgb >> $0) & 255) / 255 }
                .map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
            return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
        }
        func ratio(_ a: UInt32, _ b: UInt32) -> Double {
            let x = luminance(a), y = luminance(b)
            return (max(x, y) + 0.05) / (min(x, y) + 0.05)
        }
        for theme in AppTheme.allCases {
            for dark in [false, true] {
                let palette = WidgetRichPalette(accent: theme.lightAccent, dark: dark)
                for surface in [palette.start, palette.end] {
                    XCTAssertGreaterThanOrEqual(ratio(palette.ink, surface), 4.5, "\(theme) primary")
                    XCTAssertGreaterThanOrEqual(ratio(palette.secondary, surface), 4.5, "\(theme) secondary")
                    XCTAssertGreaterThanOrEqual(ratio(palette.action, surface), 3, "\(theme) action")
                }
                XCTAssertGreaterThanOrEqual(ratio(palette.actionInk, palette.action), 4.5)
            }
        }
    }

    private func create(_ schedule: HabitSchedule = .daily) throws -> Habit {
        try habits.createHabit(HabitDraft(name: "Read", iconName: "book", category: .learning,
                                         polarity: .positive, schedule: schedule), at: date.addingTimeInterval(-3600))
    }
    private func log(_ habit: Habit, day: String? = nil, zone: String? = nil, revision: Int = 0) throws -> QuickLogService.Result {
        try QuickLogService(habits: habits, activities: activities, calendar: calendar).log(
            habitID: habit.id, dayKey: day ?? LocalDay.key(for: date, calendar: calendar),
            timeZone: zone ?? calendar.timeZone.identifier, revision: revision, asOf: date)
    }
    private func rows() throws -> [Completion] {
        try habits.completions(in: DateInterval(start: calendar.startOfDay(for: date), end: date.addingTimeInterval(1)))
    }


    func testRepeatedCheckInIsIdempotentAndUsesWidgetSource() throws {
        let habit = try create()
        XCTAssertEqual(try log(habit), .logged)
        XCTAssertEqual(try log(habit), .alreadyLogged)
        XCTAssertEqual(try rows().count, 1)
        XCTAssertEqual(try rows().first?.source, .widget)
        // Another app-owned repository sees the persisted fact.
        let reader = SwiftDataHabitRepository(modelContext: ModelContext(container), calendar: calendar)
        XCTAssertEqual(try reader.completions(for: habit.id, in: DateInterval(start: date.addingTimeInterval(-1), end: date.addingTimeInterval(1))).count, 1)
    }
    func testStaleDayAndTimeZoneNeverWrite() throws {
        let habit = try create()
        XCTAssertEqual(try log(habit, day: "2026-10-05"), .needsApp)
        XCTAssertEqual(try log(habit, zone: "America/Denver"), .needsApp)
        XCTAssertTrue(try rows().isEmpty)
    }
    func testMidnightRejectsYesterdayEvenWhenWidgetHasNotRefreshed() throws {
        let habit = try create()
        let oldKey = LocalDay.key(for: date, calendar: calendar)
        date = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
        XCTAssertEqual(try log(habit, day: oldKey), .needsApp)
        XCTAssertTrue(try rows().isEmpty)
    }
    func testChangedConfigurationRequiresAppReview() throws {
        let habit = try create()
        try habits.updateHabit(id: habit.id, with: HabitDraft(name: "Read", iconName: "book", category: .learning,
            polarity: .avoidance, schedule: .daily), at: date)
        XCTAssertEqual(try log(habit), .needsApp)
        XCTAssertTrue(try rows().isEmpty)
        XCTAssertEqual(try log(habit, revision: 1), .logged)
    }
    func testArchivedNonDueAndUnknownHabitsNeverWrite() throws {
        let habit = try create()
        try habits.archiveHabit(id: habit.id, at: date)
        XCTAssertEqual(try log(habit), .needsApp)
        XCTAssertEqual(try log(create(.weekdays([.monday]))), .needsApp)
        let result = try QuickLogService(habits: habits, activities: activities, calendar: calendar).log(
            habitID: UUID(), dayKey: LocalDay.key(for: date, calendar: calendar), timeZone: calendar.timeZone.identifier, revision: 0, asOf: date)
        XCTAssertEqual(result, .needsApp)
        XCTAssertTrue(try rows().isEmpty)
    }
    func testSkipIsPreservedWithoutManufacturingSuccess() throws {
        let habit = try create()
        _ = try habits.recordSkip(habitID: habit.id, on: date, reason: nil)
        XCTAssertEqual(try log(habit), .needsApp)
        XCTAssertTrue(try rows().isEmpty)
        XCTAssertEqual(try habits.skips(for: habit.id, in: DateInterval(start: calendar.startOfDay(for: date), end: date.addingTimeInterval(1))).count, 1)
    }
    func testQuantityTargetRequiresLoggerEvenWithStaleSimpleSnapshot() throws {
        let habit = try create()
        try activities.configure(habitID: habit.id, target: HabitQuantityTarget(amount: 10, unit: .pages), smallerAction: "", at: date)
        XCTAssertEqual(try log(habit), .needsApp)
        XCTAssertTrue(try rows().isEmpty)
    }
    func testFlexibleWeeklyAllowsOneCheckInTodayWithoutCompletingWholeWeek() throws {
        let habit = try create(.timesPerWeek(3))
        XCTAssertEqual(try log(habit), .logged)
        XCTAssertEqual(try log(habit), .alreadyLogged)
        XCTAssertEqual(try rows().count, 1)
    }
    private func snapshot(_ rows: [WidgetHabitSnapshot]) -> WidgetSnapshot {
        var value = WidgetSnapshot(localDateKey: LocalDay.key(for: date, calendar: calendar), generatedAt: date, habits: rows, attentionGoals: [])
        value.timeZoneIdentifier = calendar.timeZone.identifier
        return value
    }
    private func row(_ name: String, completed: Bool = false, quantity: Bool = false, skipped: Bool = false) -> WidgetHabitSnapshot {
        WidgetHabitSnapshot(id: UUID(), name: name, iconName: "book", isCompletedToday: completed, progressLabel: "Daily", configurationRevision: 0, requiresQuantityLogging: quantity, isSkippedToday: skipped)
    }
    func testOrderingPendingFirstPreservesUserOrderAndRespectsCapacity() {
        let done = row("Done", completed: true), read = row("Read"), walk = row("Walk"), skip = row("Skipped", skipped: true)
        let projection = QuickLogProjection(snapshot: snapshot([done, read, walk, skip]), date: date)
        XCTAssertEqual(projection.rows(capacity: 2).map(\.id), [read.id, walk.id])
        XCTAssertEqual(projection.rows(capacity: 4).map(\.id), [read.id, walk.id, done.id, skip.id])
        XCTAssertEqual(projection.rows(capacity: 1).count, 1)
    }
    func testCompletedRowStaysInPlaceBrieflyThenPendingHabitsReturnFirst() {
        let first = row("Read", completed: true), second = row("Walk")
        var value = snapshot([first, second])
        value.quickLogPinnedIDs = [first.id, second.id]
        value.quickLogPinUntil = date.addingTimeInterval(30)
        XCTAssertEqual(QuickLogProjection(snapshot: value, date: date).rows(capacity: 2).map(\.id), [first.id, second.id])
        XCTAssertEqual(QuickLogProjection(snapshot: value, date: date.addingTimeInterval(30)).rows(capacity: 2).map(\.id), [second.id, first.id])
    }
    func testSummaryDoesNotClaimAllDoneForHiddenOrSkippedRows() {
        XCTAssertEqual(QuickLogProjection(snapshot: snapshot([row("Done", completed: true), row("Hidden")]), date: date).summary, "1 left today")
        XCTAssertEqual(QuickLogProjection(snapshot: snapshot([row("Skipped", skipped: true)]), date: date).summary, "No check-ins left today")
        XCTAssertEqual(QuickLogProjection(snapshot: snapshot([row("Done", completed: true)]), date: date).summary, "All logged today")
        XCTAssertEqual(QuickLogProjection(snapshot: snapshot([]), date: date).summary, "No habits due today")
    }
    func testSatisfiedWeeklyTargetDoesNotAppearAsAnotherRequiredCheckIn() {
        var weekly = row("Weekly")
        weekly.weeklyTargetMet = true
        let pending = row("Read")
        let projection = QuickLogProjection(snapshot: snapshot([weekly, pending]), date: date)
        XCTAssertEqual(projection.rows(capacity: 1).first?.id, pending.id)
        XCTAssertEqual(projection.summary, "1 left today")
        XCTAssertFalse(projection.canLog(weekly))
        XCTAssertEqual(QuickLogProjection(snapshot: snapshot([weekly]), date: date).summary, "No check-ins left today")
    }
    func testOldSnapshotCannotEnableInteractiveWriteAndStillDecodes() throws {
        let old = WidgetHabitSnapshot(id: UUID(), name: "Read", iconName: "book", isCompletedToday: false, progressLabel: "Daily")
        let encoded = try JSONEncoder().encode(snapshot([old]))
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: encoded)
        XCTAssertFalse(QuickLogProjection(snapshot: decoded, date: date).canLog(old))
        XCTAssertTrue(decoded.isCurrent(asOf: date, calendar: calendar))
    }
    func testCapabilitiesOnlyEnableSimpleUnskippedUncompletedRows() {
        let simple = row("Read"), quantity = row("Pages", quantity: true), skipped = row("Skipped", skipped: true), done = row("Done", completed: true)
        let projection = QuickLogProjection(snapshot: snapshot([simple, quantity, skipped, done]), date: date)
        XCTAssertTrue(projection.canLog(simple))
        XCTAssertFalse(projection.canLog(quantity))
        XCTAssertFalse(projection.canLog(skipped))
        XCTAssertFalse(projection.canLog(done))
    }
    func testSnapshotRejectsTimeZoneChangeWithoutReDerivingItsFacts() {
        let value = snapshot([row("Read")])
        calendar.timeZone = TimeZone(identifier: "America/Denver")!
        XCTAssertFalse(value.isCurrent(asOf: date, calendar: calendar))
    }
    func testNameAndQuantityDeepLinksNeverCompleteAnything() throws {
        let habit = try create()
        let handler = WidgetActionHandler(repository: habits, calendar: calendar)
        for link in [WidgetDeepLink.habit(habitID: habit.id), .logProgress(habitID: habit.id)] {
            XCTAssertEqual(WidgetDeepLink.parse(link.url), link)
            XCTAssertNotEqual(try handler.handle(link.url, asOf: date), .ignored)
        }
        XCTAssertTrue(try rows().isEmpty)
        XCTAssertNil(WidgetDeepLink.parse(URL(string: "avela://habit?habit=\(habit.id)&day=2026-10-06")!))
    }
    func testNextDayRefreshPreservesSavedProgressAndOnlyResetsTheDisplayDay() throws {
        let habit = try create()
        XCTAssertEqual(try log(habit), .logged)
        let before = try rows()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = WidgetSnapshotStore(directoryURL: directory)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: date)!
        try WidgetSnapshotExporter(store: store).export(habits: habits,
            attention: SwiftDataAttentionRepository(modelContext: container.mainContext, calendar: calendar),
            activity: activities, asOf: nextDay, calendar: calendar)
        let value = try XCTUnwrap(store.load())
        XCTAssertTrue(value.isCurrent(asOf: nextDay, calendar: calendar))
        XCTAssertEqual(value.habits.first?.isCompletedToday, false)
        XCTAssertEqual(try rows(), before)
        XCTAssertEqual(QuickLogProjection(snapshot: value, date: nextDay).summary, "1 left today")
    }
    func testExporterUsesActualQuantitySkipRevisionAndSelectedTheme() throws {
        let habit = try create()
        try activities.configure(habitID: habit.id, target: HabitQuantityTarget(amount: 10, unit: .pages), smallerAction: "", at: date)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = WidgetSnapshotStore(directoryURL: directory)
        try WidgetSnapshotExporter(store: store).export(habits: habits, attention: SwiftDataAttentionRepository(modelContext: container.mainContext, calendar: calendar), activity: activities, theme: .plum, asOf: date, calendar: calendar)
        let value = try XCTUnwrap(store.load())
        XCTAssertEqual(value.habits.first?.requiresQuantityLogging, true)
        XCTAssertEqual(value.habits.first?.configurationRevision, 0)
        XCTAssertEqual(value.accentLight, AppTheme.plum.lightAccent)
        XCTAssertEqual(value.timeZoneIdentifier, calendar.timeZone.identifier)
    }
    func testRoutinePreservesStepOrderAndOmitsNonDueOrUnavailableMembers() throws {
        let first = row("First"), second = row("Second"), outside = row("Outside")
        var value = snapshot([outside, second, first])
        let id = UUID()
        value.routines = [WidgetRoutineSnapshot(id: id, name: "Morning", habitIDs: [first.id, UUID(), second.id, first.id])]
        let selected = try XCTUnwrap(RoutineLogProjection(snapshot: value, routineID: id).selectedSnapshot)
        XCTAssertEqual(selected.habits.map(\.id), [first.id, second.id])
        XCTAssertEqual(selected.timeZoneIdentifier, value.timeZoneIdentifier)
        XCTAssertNil(selected.quickLogPinnedIDs)
        XCTAssertNil(RoutineLogProjection(snapshot: value, routineID: UUID()).selectedSnapshot)
    }

    func testRoutineNextStepFollowsActualSavedSuccessAndNeverFabricatesBulkCompletion() throws {
        let first = row("First", completed: true), second = row("Second"), skip = row("Skipped", skipped: true)
        var value = snapshot([first, second, skip])
        let id = UUID()
        value.routines = [WidgetRoutineSnapshot(id: id, name: "Evening", habitIDs: [first.id, skip.id, second.id])]
        let selected = try XCTUnwrap(RoutineLogProjection(snapshot: value, routineID: id).selectedSnapshot)
        let projection = QuickLogProjection(snapshot: selected, date: date)
        XCTAssertEqual(projection.rows(capacity: 1).first?.id, second.id)
        XCTAssertEqual(projection.summary, "1 left today")
        XCTAssertFalse(projection.canLog(skip))
        XCTAssertEqual(value.habits.filter(\.isCompletedToday).count, 1)
    }

    func testExporterRefreshesRoutineEditsDeletionAndQuantityCapabilities() throws {
        let first = try create(), second = try create()
        let routines = SwiftDataRoutineRepository(modelContext: container.mainContext, habits: habits)
        let routine = try routines.save(id: nil, name: "Morning", habitIDs: [second.id, first.id], at: date)
        try activities.configure(habitID: second.id, target: HabitQuantityTarget(amount: 10, unit: .pages), smallerAction: "", at: date)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = WidgetSnapshotStore(directoryURL: directory)
        let exporter = WidgetSnapshotExporter(store: store)
        let attention = SwiftDataAttentionRepository(modelContext: container.mainContext, calendar: calendar)
        try exporter.export(habits: habits, attention: attention, activity: activities, routines: routines, asOf: date, calendar: calendar)
        let value = try XCTUnwrap(store.load())
        XCTAssertEqual(value.routines?.first?.habitIDs, [second.id, first.id])
        let selected = try XCTUnwrap(RoutineLogProjection(snapshot: value, routineID: routine.id).selectedSnapshot)
        XCTAssertFalse(QuickLogProjection(snapshot: selected, date: date).canLog(selected.habits[0]))
        _ = try routines.save(id: routine.id, name: "Evening", habitIDs: [first.id], at: date)
        try exporter.export(habits: habits, attention: attention, activity: activities, routines: routines, asOf: date, calendar: calendar)
        XCTAssertEqual(try store.load()?.routines?.first?.name, "Evening")
        XCTAssertEqual(try store.load()?.routines?.first?.habitIDs, [first.id])
        try routines.delete(id: routine.id)
        try exporter.export(habits: habits, attention: attention, activity: activities, routines: routines, asOf: date, calendar: calendar)
        XCTAssertTrue(try XCTUnwrap(store.load()).routines?.isEmpty == true)
        XCTAssertTrue(try rows().isEmpty)
    }

}
