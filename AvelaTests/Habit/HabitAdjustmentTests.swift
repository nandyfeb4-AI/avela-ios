import Foundation
import SwiftData
import XCTest
@testable import Avela

@MainActor
final class HabitAdjustmentTests: XCTestCase {
    private var container: ModelContainer!
    private var repository: SwiftDataHabitRepository!
    private var calendar: Calendar!
    private let start = Date(timeIntervalSince1970: 1_718_496_000) // Sunday 2024-06-16 UTC

    override func setUpWithError() throws {
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1
        container = try AppPersistence.makeContainer(inMemory: true)
        repository = SwiftDataHabitRepository(modelContext: container.mainContext, calendar: calendar)
    }

    private func day(_ n: Int) -> Date {
        calendar.date(byAdding: .day, value: n, to: start)!.addingTimeInterval(3600)
    }

    private func create(_ schedule: HabitSchedule = .daily, polarity: HabitPolarity = .positive) throws -> Habit {
        try repository.createHabit(HabitDraft(name: "Read", iconName: "book.fill", category: .learning,
            polarity: polarity, schedule: schedule), at: day(0))
    }

    private func proposal(_ habit: Habit, on n: Int) throws -> HabitAdjustmentProposal? {
        let date = day(n)
        let range = DateInterval(start: start, end: calendar.date(byAdding: .day, value: 1, to: date)!)
        return HabitAdjustmentCalculator.proposal(for: try XCTUnwrap(repository.fetchHabit(id: habit.id)),
            snapshots: try repository.configurationHistory(for: habit.id),
            completions: try repository.completions(for: habit.id, in: range),
            skips: try repository.skips(for: habit.id, in: range),
            archivePeriods: try repository.archivePeriods(for: habit.id), asOf: date, calendar: calendar)
    }

    func testRepeatedDailyMissesOfferAdjustableThreeTimesWeekly() throws {
        let habit = try create()
        XCTAssertNil(try proposal(habit, on: 0))
        XCTAssertNil(try proposal(habit, on: 1))
        let result = try XCTUnwrap(proposal(habit, on: 2))
        XCTAssertEqual(result.suggestedFrequency, 3)
        XCTAssertEqual(result.maximumFrequency, 6)
        XCTAssertEqual(result.recentMisses, 2)
    }

    func testSkipsAndPendingDaysDoNotQualify() throws {
        let habit = try create()
        try repository.recordSkip(habitID: habit.id, on: day(0), reason: .planned)
        XCTAssertNil(try proposal(habit, on: 2)) // one actual miss, today pending
    }

    func testRecoveryCompletionSuppressesOfferEvenWithRecentMisses() throws {
        let habit = try create()
        for n in 2...4 { try repository.recordCompletion(habitID: habit.id, at: day(n), source: .app, note: nil) }
        XCTAssertNil(try proposal(habit, on: 4))
    }

    func testAvoidanceArchivedAndOnceWeeklyHaveNoOffer() throws {
        XCTAssertNil(try proposal(create(.daily, polarity: .avoidance), on: 5))
        XCTAssertNil(try proposal(create(.timesPerWeek(1)), on: 21))
        XCTAssertNil(try proposal(create(.weekdays([.monday])), on: 21))
        let habit = try create()
        try repository.archiveHabit(id: habit.id, at: day(3))
        XCTAssertNil(try proposal(habit, on: 5))
    }

    func testPauseDoesNotManufactureMissesAndOldMissesExpire() throws {
        let habit = try create()
        try repository.archiveHabit(id: habit.id, at: day(1))
        try repository.reactivateHabit(id: habit.id, at: day(20))
        XCTAssertNil(try proposal(habit, on: 21))
    }

    func testWeeklyOfferRequiresTwoClosedMissedWeeks() throws {
        let habit = try create(.timesPerWeek(3))
        XCTAssertNil(try proposal(habit, on: 7))
        let result = try XCTUnwrap(proposal(habit, on: 14))
        XCTAssertEqual(result.suggestedFrequency, 2)
        XCTAssertEqual(result.maximumFrequency, 2)
        XCTAssertEqual(result.recentMisses, 2)
        XCTAssertEqual(result.windowDays, 28)
    }

    func testWeekdayOfferIsStrictlyLowerAndDifferentScheduleMissesDoNotQualify() throws {
        let habit = try create(.weekdays([.monday, .tuesday, .wednesday]))
        XCTAssertEqual(try proposal(habit, on: 4)?.suggestedFrequency, 2)
        _ = try repository.updateHabit(id: habit.id, with: HabitDraft(name: "Read", iconName: "book.fill",
            category: .learning, polarity: .positive, schedule: .timesPerWeek(3)), at: day(4))
        XCTAssertNil(try proposal(habit, on: 5))
    }

    func testLoadingAndDiscardingDraftNeverChangesAnything() throws {
        let habit = try create()
        let before = try repository.configurationHistory(for: habit.id)
        let model = HabitAdjustmentViewModel(habitID: habit.id, repository: repository, calendar: calendar)
        model.load(asOf: day(3)); model.frequency = 1
        XCTAssertNotNil(model.proposal)
        XCTAssertEqual(try repository.configurationHistory(for: habit.id), before)
        XCTAssertEqual(try repository.fetchHabit(id: habit.id), habit)
    }

    func testConfirmationAppendsSnapshotPreservesFactsAndEarlierPeriods() throws {
        let habit = try create()
        let completion = try repository.recordCompletion(habitID: habit.id, at: day(0), source: .app, note: nil)
        let skip = try repository.recordSkip(habitID: habit.id, on: day(1), reason: .planned)
        let historyBefore = try repository.configurationHistory(for: habit.id)
        let factsRange = DateInterval(start: start, end: day(6))
        let completedBefore = try repository.completions(for: habit.id, in: factsRange)
        let skippedBefore = try repository.skips(for: habit.id, in: factsRange)
        let boundary = calendar.startOfDay(for: day(5))
        let earlierPeriods = HabitProgressCalculator.periods(for: habit, snapshots: historyBefore,
            completions: completedBefore, skips: skippedBefore, archivePeriods: [], asOf: day(5), calendar: calendar)
            .filter { $0.periodEnd <= boundary }
        let model = HabitAdjustmentViewModel(habitID: habit.id, repository: repository, calendar: calendar)
        model.load(asOf: day(5)); model.frequency = 2
        // A concurrent cosmetic edit must survive confirmation.
        _ = try repository.updateHabit(id: habit.id, with: HabitDraft(name: "Read a page", iconName: "book",
            category: .other, polarity: .positive, schedule: .daily), at: day(5))
        XCTAssertTrue(model.save(asOf: day(5)))
        XCTAssertFalse(model.save(asOf: day(5)), "Repeated confirmation must not append")
        let updated = try XCTUnwrap(repository.fetchHabit(id: habit.id))
        XCTAssertEqual(updated.name, "Read a page")
        XCTAssertEqual(updated.schedule, .timesPerWeek(2))
        let history = try repository.configurationHistory(for: habit.id)
        XCTAssertEqual(history.map(\.revision), [0, 1])
        XCTAssertEqual(history.last?.effectiveLocalDateKey, "2024-06-21")
        let earlierAfter = HabitProgressCalculator.periods(for: updated, snapshots: history,
            completions: completedBefore, skips: skippedBefore, archivePeriods: [], asOf: day(5), calendar: calendar)
            .filter { $0.periodEnd <= boundary }
        XCTAssertEqual(earlierAfter, earlierPeriods)
        XCTAssertEqual(try repository.activeConfiguration(for: habit.id, on: day(4))?.schedule, .daily)
        let range = DateInterval(start: start, end: day(6))
        XCTAssertEqual(try repository.completions(for: habit.id, in: range), [completion])
        XCTAssertEqual(try repository.skips(for: habit.id, in: range), [skip])
    }

    func testScheduleChangeAndMidnightRejectStaleConfirmation() throws {
        let habit = try create()
        let model = HabitAdjustmentViewModel(habitID: habit.id, repository: repository, calendar: calendar)
        model.load(asOf: day(3))
        XCTAssertFalse(model.save(asOf: day(4)))
        XCTAssertTrue(model.needsReload)
        model.load(asOf: day(4))
        _ = try repository.updateHabit(id: habit.id, with: HabitDraft(name: "Read", iconName: "book.fill",
            category: .learning, polarity: .positive, schedule: .timesPerWeek(4)), at: day(4))
        XCTAssertFalse(model.save(asOf: day(4)))
        XCTAssertEqual(try repository.configurationHistory(for: habit.id).count, 2)
    }

    func testNewSuccessesOrArchivingBeforeConfirmationRejectOffer() throws {
        let habit = try create()
        let model = HabitAdjustmentViewModel(habitID: habit.id, repository: repository, calendar: calendar)
        model.load(asOf: day(5))
        for n in 3...5 { try repository.recordCompletion(habitID: habit.id, at: day(n), source: .app, note: nil) }
        XCTAssertFalse(model.save(asOf: day(5)))
        XCTAssertEqual(try repository.configurationHistory(for: habit.id).count, 1)
        let other = try create()
        let otherModel = HabitAdjustmentViewModel(habitID: other.id, repository: repository, calendar: calendar)
        otherModel.load(asOf: day(5))
        try repository.archiveHabit(id: other.id, at: day(5))
        XCTAssertFalse(otherModel.save(asOf: day(5)))
    }

    func testInvalidFrequencyCannotWrite() throws {
        let habit = try create()
        let model = HabitAdjustmentViewModel(habitID: habit.id, repository: repository, calendar: calendar)
        model.load(asOf: day(3)); model.frequency = 7
        XCTAssertFalse(model.save(asOf: day(3)))
        XCTAssertEqual(try repository.configurationHistory(for: habit.id).count, 1)
    }
}
