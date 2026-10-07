import XCTest
import SwiftData
@testable import Avela

@MainActor
final class SwiftDataHabitActivityTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        value.firstWeekday = 2
        return value
    }
    private func day(_ offset: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 5 + offset, hour: 12))!
    }
    private struct Fixture {
        let container: ModelContainer
        let habits: SwiftDataHabitRepository
        let activities: SwiftDataHabitActivityRepository
        let habit: Habit
    }
    private func fixture(schedule: HabitSchedule = .daily) throws -> Fixture {
        let container = try AppPersistence.makeContainer(inMemory: true)
        let habits = SwiftDataHabitRepository(modelContext: container.mainContext, calendar: calendar)
        let habit = try habits.createHabit(HabitDraft(name: "Read", iconName: "book.fill", category: .learning,
                                                    polarity: .positive, schedule: schedule), at: day(-10))
        let activities = SwiftDataHabitActivityRepository(context: container.mainContext, habits: habits, calendar: calendar)
        return Fixture(container: container, habits: habits, activities: activities, habit: habit)
    }
    private func completions(_ fixture: Fixture, on date: Date) throws -> [Completion] {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return try fixture.habits.completions(for: fixture.habit.id, in: DateInterval(start: start, end: end))
    }
    private func configure(_ fixture: Fixture, amount: Int = 4, unit: HabitQuantityUnit = .pages, at date: Date? = nil) throws -> HabitActivityConfiguration {
        let date = date ?? day()
        try fixture.activities.configure(habitID: fixture.habit.id, target: .init(amount: amount, unit: unit), smallerAction: "Read one paragraph", at: date)
        return try XCTUnwrap(fixture.activities.configuration(for: fixture.habit.id, on: date))
    }
    private func log(_ fixture: Fixture, configuration: HabitActivityConfiguration, amount: Int, on date: Date? = nil) throws {
        let date = date ?? day()
        try fixture.activities.log(habitID: fixture.habit.id, kind: .quantity, amount: amount,
                                   expectedConfigurationID: configuration.id, on: date, now: day())
    }

    func testPolarityEditCannotLeaveManualQuantityOnAnAvoidanceHabit() throws {
        let fixture = try fixture()
        _ = try configure(fixture)
        let draft = HabitDraft(name: fixture.habit.name, iconName: fixture.habit.iconName, category: fixture.habit.category,
            polarity: .avoidance, schedule: fixture.habit.schedule)
        XCTAssertThrowsError(try fixture.habits.updateHabit(id: fixture.habit.id, with: draft, at: day())) { error in
            XCTAssertEqual(error as? HabitRepositoryError, .manualQuantityRequiresPositivePolarity)
        }
        XCTAssertEqual(try fixture.habits.fetchHabit(id: fixture.habit.id)?.polarity, .positive)
        XCTAssertEqual(try fixture.habits.configurationHistory(for: fixture.habit.id).count, 1)
        try fixture.activities.configure(habitID: fixture.habit.id, target: nil, smallerAction: "", at: day())
        XCTAssertEqual(try fixture.habits.updateHabit(id: fixture.habit.id, with: draft, at: day()).polarity, .avoidance)
    }

    func testPartialQuantityIsNotSuccessAndThresholdProducesExactlyOneCompletion() throws {
        let fixture = try fixture()
        let configuration = try configure(fixture)
        try log(fixture, configuration: configuration, amount: 2)
        XCTAssertTrue(try completions(fixture, on: day()).isEmpty)
        try log(fixture, configuration: configuration, amount: 2)
        let first = try XCTUnwrap(completions(fixture, on: day()).first)
        XCTAssertEqual(first.source, .quantity)
        try log(fixture, configuration: configuration, amount: 1)
        XCTAssertEqual(try completions(fixture, on: day()).map(\.id), [first.id])
        XCTAssertEqual(try fixture.activities.entries(for: fixture.habit.id, on: day()).count, 3)
    }

    func testSmallerActionIsDistinctIdempotentAndDoesNotExtendFullStreak() throws {
        let fixture = try fixture()
        let configuration = try configure(fixture)
        for _ in 0..<2 {
            try fixture.activities.log(habitID: fixture.habit.id, kind: .smallerAction, amount: 0,
                                       expectedConfigurationID: configuration.id, on: day(), now: day())
        }
        let entries = try fixture.activities.entries(for: fixture.habit.id, on: day())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.kind, .smallerAction)
        XCTAssertEqual(entries.first?.description, "Read one paragraph")
        XCTAssertTrue(try completions(fixture, on: day()).isEmpty)
        let streak = HabitProgressCalculator.streak(
            for: fixture.habit, snapshots: try fixture.habits.configurationHistory(for: fixture.habit.id),
            completions: [], skips: [], archivePeriods: [], asOf: day(), calendar: calendar)
        XCTAssertEqual(streak.currentStreak, 0)
    }

    func testDeletingQuantityBelowThresholdWithdrawsOnlyGeneratedSuccess() throws {
        let fixture = try fixture()
        let configuration = try configure(fixture)
        try log(fixture, configuration: configuration, amount: 4)
        let entry = try XCTUnwrap(fixture.activities.entries(for: fixture.habit.id, on: day()).first)
        XCTAssertEqual(try completions(fixture, on: day()).count, 1)
        try fixture.activities.removeEntry(id: entry.id, now: day())
        XCTAssertTrue(try completions(fixture, on: day()).isEmpty)
        XCTAssertThrowsError(try fixture.habits.recordCompletion(habitID: fixture.habit.id, at: day(), source: .app, note: nil), "A generic tick must not bypass an unmet quantity target")
        try fixture.activities.configure(habitID: fixture.habit.id, target: nil, smallerAction: "", at: day())
        try fixture.habits.recordCompletion(habitID: fixture.habit.id, at: day(), source: .app, note: nil)
        let revised = try configure(fixture)
        try log(fixture, configuration: revised, amount: 4)
        let replacement = try XCTUnwrap(fixture.activities.entries(for: fixture.habit.id, on: day()).first)
        try fixture.activities.removeEntry(id: replacement.id, now: day())
        XCTAssertEqual(try completions(fixture, on: day()).map(\.source), [.app])
    }

    func testSameDayReconfigurationRejectsStaleLoggingAndKeepsCapturedEntryUnits() throws {
        let fixture = try fixture()
        let original = try configure(fixture)
        try log(fixture, configuration: original, amount: 2)
        let changed = try configure(fixture, amount: 2, unit: .glasses)
        XCTAssertEqual(changed.revision, original.revision + 1)
        XCTAssertThrowsError(try log(fixture, configuration: original, amount: 2)) {
            XCTAssertEqual($0 as? HabitActivityError, .staleConfiguration)
        }
        let entry = try XCTUnwrap(fixture.activities.entries(for: fixture.habit.id, on: day()).first)
        XCTAssertEqual(entry.unit, .pages)
        XCTAssertEqual(entry.configurationID, original.id)
        try log(fixture, configuration: changed, amount: 1)
        XCTAssertTrue(try completions(fixture, on: day()).isEmpty, "Old pages cannot become glasses")
    }

    func testLaterTargetChangeDoesNotRewriteHistoricalConfigurationOrSuccess() throws {
        let fixture = try fixture()
        let prior = day(-1)
        let original = try configure(fixture, amount: 3, at: prior)
        try log(fixture, configuration: original, amount: 3, on: prior)
        let first = try XCTUnwrap(completions(fixture, on: prior).first)
        _ = try configure(fixture, amount: 20)
        XCTAssertEqual(try fixture.activities.configuration(for: fixture.habit.id, on: prior), original)
        XCTAssertEqual(try completions(fixture, on: prior).map(\.id), [first.id])
        XCTAssertEqual(try fixture.activities.entries(for: fixture.habit.id, on: prior).first?.description, "3 pages per scheduled day")
    }

    func testHistoricalCorrectionRejectsChangedFactsAndPreservesIndependentDays() throws {
        let fixture = try fixture()
        let prior = day(-1)
        let preview = try fixture.activities.correctionPreview(habitID: fixture.habit.id, on: prior)
        try fixture.habits.recordCompletion(habitID: fixture.habit.id, at: prior, source: .app, note: nil)
        XCTAssertThrowsError(try fixture.activities.correct(preview, to: .clear, on: prior, now: day())) {
            XCTAssertEqual($0 as? HabitActivityError, .staleCorrection)
        }
        let current = try fixture.habits.recordCompletion(habitID: fixture.habit.id, at: day(), source: .app, note: nil)
        let refreshed = try fixture.activities.correctionPreview(habitID: fixture.habit.id, on: prior)
        try fixture.activities.correct(refreshed, to: .skip, on: prior, now: day())
        XCTAssertTrue(try completions(fixture, on: prior).isEmpty)
        XCTAssertEqual(try completions(fixture, on: day()).map(\.id), [current.id])
        XCTAssertEqual(try fixture.habits.skips(for: fixture.habit.id,
                                             in: DateInterval(start: calendar.startOfDay(for: prior), end: calendar.startOfDay(for: day()))).count, 1)
    }

    func testCorrectionsCannotClaimQuantitySuccessWithoutTargetBeingMet() throws {
        let fixture = try fixture()
        let configuration = try configure(fixture)
        try log(fixture, configuration: configuration, amount: 1)
        let preview = try fixture.activities.correctionPreview(habitID: fixture.habit.id, on: day())
        XCTAssertThrowsError(try fixture.activities.correct(preview, to: .success, on: day(), now: day())) {
            XCTAssertEqual($0 as? HabitActivityError, .invalidAmount)
        }
        XCTAssertTrue(try completions(fixture, on: day()).isEmpty)
    }

    func testFuturePrecreationAndArchivedPeriodsCannotBeLoggedOrCorrected() throws {
        let fixture = try fixture()
        let configuration = try configure(fixture)
        for invalid in [day(1), day(-11)] {
            XCTAssertThrowsError(try log(fixture, configuration: configuration, amount: 4, on: invalid))
            let preview = try fixture.activities.correctionPreview(habitID: fixture.habit.id, on: invalid)
            XCTAssertThrowsError(try fixture.activities.correct(preview, to: .success, on: invalid, now: day()))
        }
        try fixture.habits.archiveHabit(id: fixture.habit.id, at: day(-2))
        try fixture.habits.reactivateHabit(id: fixture.habit.id, at: day())
        let paused = day(-1)
        let preview = try fixture.activities.correctionPreview(habitID: fixture.habit.id, on: paused)
        XCTAssertThrowsError(try fixture.activities.correct(preview, to: .success, on: paused, now: day()))
        XCTAssertTrue(try completions(fixture, on: paused).isEmpty)
    }

    func testQuantityDeletionUsesGregorianStoredKeysWithBuddhistCalendar() throws {
        let fixture = try fixture()
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = calendar.timeZone
        buddhist.firstWeekday = calendar.firstWeekday
        let habits = SwiftDataHabitRepository(modelContext: fixture.container.mainContext, calendar: buddhist)
        let activities = SwiftDataHabitActivityRepository(context: fixture.container.mainContext, habits: habits, calendar: buddhist)
        try activities.configure(habitID: fixture.habit.id, target: .init(amount: 2, unit: .pages), smallerAction: "", at: day())
        let configuration = try XCTUnwrap(activities.configuration(for: fixture.habit.id, on: day()))
        try activities.log(habitID: fixture.habit.id, kind: .quantity, amount: 2,
                           expectedConfigurationID: configuration.id, on: day(), now: day())
        let entry = try XCTUnwrap(activities.entries(for: fixture.habit.id, on: day()).first)
        XCTAssertEqual(entry.dayKey, "2026-10-05")
        try activities.removeEntry(id: entry.id, now: day())
        XCTAssertTrue(try activities.entries(for: fixture.habit.id, on: day()).isEmpty)
    }

    func testTimerSurvivesRepositoryRecreationAndElapsedTimeDoesNotAutoLog() throws {
        let fixture = try fixture()
        _ = try configure(fixture, amount: 10, unit: .minutes)
        let started = day().addingTimeInterval(-120)
        let state = HabitTimerState(habitID: fixture.habit.id, dayKey: "2026-10-05", startedAt: started, elapsedSeconds: 60)
        try fixture.activities.saveTimer(state, now: day())
        let reopened = SwiftDataHabitActivityRepository(context: fixture.container.mainContext, habits: fixture.habits, calendar: calendar)
        let restored = try XCTUnwrap(reopened.timer(for: fixture.habit.id, on: day()))
        XCTAssertEqual(restored.seconds(at: day()), 180)
        XCTAssertNil(try reopened.timer(for: fixture.habit.id, on: day(1)))
        XCTAssertTrue(try completions(fixture, on: day()).isEmpty)
        XCTAssertTrue(try reopened.entries(for: fixture.habit.id, on: day()).isEmpty)
        try reopened.resetTimer(for: fixture.habit.id)
        XCTAssertNil(try reopened.timer(for: fixture.habit.id, on: day()))
    }

    func testTimerRejectsNonMinuteTargetAndInvalidStoredElapsedAmount() throws {
        let fixture = try fixture()
        _ = try configure(fixture)
        XCTAssertThrowsError(try fixture.activities.saveTimer(
            HabitTimerState(habitID: fixture.habit.id, dayKey: "2026-10-05", startedAt: nil, elapsedSeconds: 30), now: day()))
        _ = try configure(fixture, amount: 10, unit: .minutes)
        XCTAssertThrowsError(try fixture.activities.saveTimer(
            HabitTimerState(habitID: fixture.habit.id, dayKey: "2026-10-05", startedAt: nil, elapsedSeconds: 86_401), now: day()))
        XCTAssertNil(try fixture.activities.timer(for: fixture.habit.id, on: day()))
    }

    func testPausedTimerLoggingIsAtomicAndCannotRepeat() throws {
        let fixture = try fixture()
        _ = try configure(fixture, amount: 1, unit: .minutes)
        try fixture.activities.saveTimer(HabitTimerState(habitID: fixture.habit.id, dayKey: "2026-10-05", startedAt: nil, elapsedSeconds: 90), now: day())
        try fixture.activities.logTimer(habitID: fixture.habit.id, now: day())
        XCTAssertNil(try fixture.activities.timer(for: fixture.habit.id, on: day()))
        XCTAssertEqual(try fixture.activities.entries(for: fixture.habit.id, on: day()).map(\.amount), [1])
        XCTAssertEqual(try completions(fixture, on: day()).count, 1)
        XCTAssertThrowsError(try fixture.activities.logTimer(habitID: fixture.habit.id, now: day()))
        XCTAssertEqual(try fixture.activities.entries(for: fixture.habit.id, on: day()).count, 1)
    }

    func testCorrectionReviewRejectsSameDayScheduleChange() throws {
        let fixture = try fixture()
        let preview = try fixture.activities.correctionPreview(habitID: fixture.habit.id, on: day())
        let habit = fixture.habit
        try fixture.habits.updateHabit(id: habit.id, with: HabitDraft(name: habit.name, iconName: habit.iconName,
            category: habit.category, polarity: habit.polarity, schedule: .timesPerWeek(3)), at: day())
        XCTAssertThrowsError(try fixture.activities.correct(preview, to: .success, on: day(), now: day())) {
            XCTAssertEqual($0 as? HabitActivityError, .staleCorrection)
        }
        XCTAssertTrue(try completions(fixture, on: day()).isEmpty)
    }

    func testSystemLoggingCannotEraseSkipOrBypassQuantityTarget() throws {
        let fixture = try fixture()
        _ = try configure(fixture)
        let skip = try fixture.habits.recordSkip(habitID: fixture.habit.id, on: day(), reason: nil)
        let shortcut = ShortcutLoggingService(habits: fixture.habits,
            attention: SwiftDataAttentionRepository(modelContext: fixture.container.mainContext), calendar: calendar, activity: fixture.activities)
        XCTAssertThrowsError(try shortcut.completeHabit(id: fixture.habit.id, at: day()))
        let reminder = ReminderActionHandler(habits: fixture.habits, calendar: calendar)
        XCTAssertThrowsError(try reminder.handle(HabitReminderAction(habitID: fixture.habit.id, deliveredAt: day()), at: day()))
        let url = WidgetDeepLink.complete(habitID: fixture.habit.id, localDateKey: "2026-10-05").url
        XCTAssertEqual(try WidgetActionHandler(repository: fixture.habits, calendar: calendar).handle(url, asOf: day()), .openedToday)
        XCTAssertEqual(try fixture.habits.skips(for: fixture.habit.id, in: calendar.dateInterval(of: .day, for: day())!).map(\.id), [skip.id])
        XCTAssertTrue(try completions(fixture, on: day()).isEmpty)
    }

    func testInvalidConfigurationAndAmountsDoNotCreateEntries() throws {
        let fixture = try fixture()
        for invalid in [0, -1, 10_001] {
            XCTAssertThrowsError(try fixture.activities.configure(habitID: fixture.habit.id,
                target: .init(amount: invalid, unit: .pages), smallerAction: "", at: day()))
        }
        let valid = try configure(fixture)
        for invalid in [0, -1, 10_001] {
            XCTAssertThrowsError(try log(fixture, configuration: valid, amount: invalid))
        }
        XCTAssertTrue(try fixture.activities.entries(for: fixture.habit.id, on: day()).isEmpty)
        XCTAssertTrue(try completions(fixture, on: day()).isEmpty)
    }
}

/// Feature-state checks exercise production repositories; retained stores avoid
/// SwiftData contexts outliving their containers during async/native test runs.
@MainActor
final class HabitActivityViewModelTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private struct Fixture {
        let container: ModelContainer
        let habits: SwiftDataHabitRepository
        let activities: SwiftDataHabitActivityRepository
        let model: HabitActivityViewModel
        let habit: Habit
        let now: Date
    }
    private func fixture(unit: HabitQuantityUnit = .pages) throws -> Fixture {
        let now = Date()
        let container = try AppPersistence.makeContainer(inMemory: true)
        let habits = SwiftDataHabitRepository(modelContext: container.mainContext, calendar: calendar)
        let habit = try habits.createHabit(HabitDraft(name: "Read", iconName: "book.fill", category: .learning,
            polarity: .positive, schedule: .daily), at: calendar.date(byAdding: .day, value: -10, to: now)!)
        let activities = SwiftDataHabitActivityRepository(context: container.mainContext, habits: habits, calendar: calendar)
        try activities.configure(habitID: habit.id, target: .init(amount: 10, unit: unit), smallerAction: "One paragraph",
                                 at: calendar.date(byAdding: .day, value: -5, to: now)!)
        let model = HabitActivityViewModel(habitID: habit.id, repository: activities, habits: habits, calendar: calendar)
        model.selectedDate = now
        model.load()
        return Fixture(container: container, habits: habits, activities: activities, model: model, habit: habit, now: now)
    }

    func testConfigurationCancellationWritesNoTargetOrSmallerAction() throws {
        let fixture = try fixture()
        let original = try XCTUnwrap(fixture.activities.configuration(for: fixture.habit.id, on: fixture.now))
        fixture.model.prepareConfiguration()
        fixture.model.targetAmount = 2
        fixture.model.smallerAction = "Cancel this draft"
        // This is the native Cancel action: dismissal without saveConfiguration.
        fixture.model.isShowingConfiguration = false
        fixture.model.load()
        XCTAssertEqual(try fixture.activities.configuration(for: fixture.habit.id, on: fixture.now), original)
        XCTAssertTrue(try fixture.activities.entries(for: fixture.habit.id, on: fixture.now).isEmpty)
        XCTAssertTrue(fixture.model.confirmation.isEmpty)
    }

    func testSelectedDayChangeRequiresReloadBeforeLogging() throws {
        let fixture = try fixture()
        let previous = calendar.date(byAdding: .day, value: -1, to: fixture.now)!
        fixture.model.selectedDate = previous
        fixture.model.amount = 2
        fixture.model.log(.quantity, now: fixture.now)
        XCTAssertTrue(try fixture.activities.entries(for: fixture.habit.id, on: previous).isEmpty,
                      "A loaded today's projection must not write another day before its review reloads")
        XCTAssertNotNil(fixture.model.errorMessage)
        fixture.model.load()
        fixture.model.log(.quantity, now: fixture.now)
        XCTAssertEqual(try fixture.activities.entries(for: fixture.habit.id, on: previous).map(\.amount), [2])
        XCTAssertTrue(try fixture.activities.entries(for: fixture.habit.id, on: fixture.now).isEmpty)
    }

    func testBackdateConfirmationCannotBeRedirectedAfterReloadingAnotherDay() throws {
        let fixture = try fixture()
        let previous = calendar.date(byAdding: .day, value: -1, to: fixture.now)!
        fixture.model.selectedDate = previous
        fixture.model.load()
        let reviewed = fixture.model.selectedDate
        fixture.model.selectedDate = fixture.now
        fixture.model.load()
        fixture.model.log(.quantity, now: fixture.now, reviewedDate: reviewed)
        XCTAssertNotNil(fixture.model.errorMessage)
        XCTAssertTrue(try fixture.activities.entries(for: fixture.habit.id, on: previous).isEmpty)
        XCTAssertTrue(try fixture.activities.entries(for: fixture.habit.id, on: fixture.now).isEmpty)
        fixture.model.clearError()
        fixture.model.correct(to: .skip, reviewedDate: reviewed)
        XCTAssertNotNil(fixture.model.errorMessage)
        XCTAssertTrue(try fixture.habits.skips(for: fixture.habit.id,
            in: DateInterval(start: previous, end: fixture.now.addingTimeInterval(86_400))).isEmpty)
    }

    func testSelectedDayChangeCannotReuseOldCorrectionPreview() throws {
        let fixture = try fixture()
        fixture.model.selectedDate = calendar.date(byAdding: .day, value: -1, to: fixture.now)!
        fixture.model.correct(to: .skip)
        XCTAssertNotNil(fixture.model.errorMessage)
        XCTAssertTrue(try fixture.habits.skips(for: fixture.habit.id,
            in: DateInterval(start: calendar.date(byAdding: .day, value: -2, to: fixture.now)!, end: fixture.now)).isEmpty)
    }

    func testPausedTimerLogsWholeMinutesOnceAndResetsAfterSuccess() throws {
        let fixture = try fixture(unit: .minutes)
        try fixture.activities.saveTimer(HabitTimerState(habitID: fixture.habit.id,
            dayKey: LocalDay.key(for: fixture.now, calendar: calendar), startedAt: nil, elapsedSeconds: 125), now: fixture.now)
        fixture.model.load()
        fixture.model.logTimer(now: fixture.now)
        XCTAssertEqual(fixture.model.entries.map(\.amount), [2])
        XCTAssertNil(fixture.model.timer)
        fixture.model.logTimer(now: fixture.now)
        XCTAssertEqual(try fixture.activities.entries(for: fixture.habit.id, on: fixture.now).count, 1)
    }

    func testRunningOrSubMinuteTimerCannotLogAnything() throws {
        let fixture = try fixture(unit: .minutes)
        for timer in [HabitTimerState(habitID: fixture.habit.id,
                dayKey: LocalDay.key(for: fixture.now, calendar: calendar), startedAt: fixture.now, elapsedSeconds: 180),
            HabitTimerState(habitID: fixture.habit.id,
                dayKey: LocalDay.key(for: fixture.now, calendar: calendar), startedAt: nil, elapsedSeconds: 59)] {
            try fixture.activities.saveTimer(timer, now: fixture.now)
            fixture.model.load()
            fixture.model.logTimer(now: fixture.now)
            XCTAssertTrue(try fixture.activities.entries(for: fixture.habit.id, on: fixture.now).isEmpty)
            XCTAssertEqual(fixture.model.timer, timer)
        }
    }

    func testHistoricalSelectionCannotStartTodayTimerOrBypassCurrentDay() throws {
        let fixture = try fixture(unit: .minutes)
        fixture.model.selectedDate = calendar.date(byAdding: .day, value: -1, to: fixture.now)!
        fixture.model.load()
        fixture.model.toggleTimer(now: fixture.now)
        fixture.model.logTimer(now: fixture.now)
        XCTAssertNil(try fixture.activities.timer(for: fixture.habit.id, on: fixture.now))
        XCTAssertTrue(try fixture.activities.entries(for: fixture.habit.id, on: fixture.now).isEmpty)
    }

    func testQuantityConfigurationCannotBeSavedOverConnectedHealthTarget() throws {
        let fixture = try fixture()
        try SwiftDataHealthHabitConnectionRepository(context: fixture.container.mainContext).save(
            habitID: fixture.habit.id, metric: .steps, target: 100, at: fixture.now)
        let original = try fixture.activities.configuration(for: fixture.habit.id, on: fixture.now)
        fixture.model.prepareConfiguration()
        fixture.model.targetAmount = 50
        fixture.model.saveConfiguration()
        XCTAssertTrue(fixture.model.isShowingConfiguration)
        XCTAssertNotNil(fixture.model.errorMessage)
        XCTAssertEqual(try fixture.activities.configuration(for: fixture.habit.id, on: fixture.now), original)
    }

    func testTimerFailurePreservesPausedTimeAndDraftUntilRetry() throws {
        let fixture = try fixture(unit: .minutes)
        let repository = RetryTimerRepository(wrapping: fixture.activities)
        let model = HabitActivityViewModel(habitID: fixture.habit.id, repository: repository,
                                          habits: fixture.habits, calendar: calendar)
        model.selectedDate = fixture.now
        let timer = HabitTimerState(habitID: fixture.habit.id, dayKey: LocalDay.key(for: fixture.now, calendar: calendar),
                                   startedAt: nil, elapsedSeconds: 125)
        try fixture.activities.saveTimer(timer, now: fixture.now)
        model.load()
        model.logTimer(now: fixture.now)
        XCTAssertEqual(model.timer, timer)
        XCTAssertTrue(model.confirmation.isEmpty)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertTrue(try fixture.activities.entries(for: fixture.habit.id, on: fixture.now).isEmpty)
        model.clearError()
        model.logTimer(now: fixture.now)
        XCTAssertNil(model.errorMessage)
        XCTAssertNil(model.timer)
        XCTAssertEqual(model.entries.map(\.amount), [2])
    }
}

@MainActor
private final class RetryTimerRepository: HabitActivityRepository {
    private let base: HabitActivityRepository
    private var failNextLog = true
    init(wrapping base: HabitActivityRepository) { self.base = base }
    func configuration(for habitID: UUID, on date: Date) throws -> HabitActivityConfiguration? {
        try base.configuration(for: habitID, on: date)
    }
    func configure(habitID: UUID, target: HabitQuantityTarget?, smallerAction: String, at date: Date) throws {
        try base.configure(habitID: habitID, target: target, smallerAction: smallerAction, at: date)
    }
    func entries(for habitID: UUID, on date: Date) throws -> [HabitActivityEntry] { try base.entries(for: habitID, on: date) }
    func entries(for habitID: UUID, in range: DateInterval) throws -> [HabitActivityEntry] { try base.entries(for: habitID, in: range) }
    func log(habitID: UUID, kind: HabitActivityKind, amount: Int, expectedConfigurationID: UUID, on date: Date, now: Date) throws {
        try base.log(habitID: habitID, kind: kind, amount: amount, expectedConfigurationID: expectedConfigurationID, on: date, now: now)
    }
    func removeEntry(id: UUID, now: Date) throws { try base.removeEntry(id: id, now: now) }
    func correctionPreview(habitID: UUID, on date: Date) throws -> HabitCorrectionPreview {
        try base.correctionPreview(habitID: habitID, on: date)
    }
    func correct(_ preview: HabitCorrectionPreview, to outcome: HabitDayCorrection, on date: Date, now: Date) throws {
        try base.correct(preview, to: outcome, on: date, now: now)
    }
    func timer(for habitID: UUID, on date: Date) throws -> HabitTimerState? { try base.timer(for: habitID, on: date) }
    func saveTimer(_ state: HabitTimerState, now: Date) throws { try base.saveTimer(state, now: now) }
    func resetTimer(for habitID: UUID) throws { try base.resetTimer(for: habitID) }
    func logTimer(habitID: UUID, now: Date) throws {
        if failNextLog { failNextLog = false; throw HabitActivityError.invalidAmount }
        try base.logTimer(habitID: habitID, now: now)
    }
}
