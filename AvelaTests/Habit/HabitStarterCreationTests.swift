import Foundation
import SwiftData
import XCTest
@testable import Avela

@MainActor
final class HabitStarterCreationTests: XCTestCase {
    private var store: ModelContainer!
    private var habits: SwiftDataHabitRepository!
    private var activity: SwiftDataHabitActivityRepository!
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return value
    }
    // October 20 locally, despite the next UTC date.
    private let now = Date(timeIntervalSince1970: 1_792_544_400)

    override func setUpWithError() throws {
        store = try AppPersistence.makeContainer(inMemory: true)
        habits = SwiftDataHabitRepository(modelContext: store.mainContext, calendar: calendar)
        activity = SwiftDataHabitActivityRepository(context: store.mainContext, habits: habits, calendar: calendar)
    }

    override func tearDownWithError() throws {
        activity = nil
        habits = nil
        store = nil
    }

    private func draft(target: HabitQuantityTarget? = nil, smaller: String? = nil) -> HabitDraft {
        HabitDraft(name: "Read", iconName: "book.fill", category: .learning,
            polarity: .positive, schedule: .daily, quantityTarget: target, smallerAction: smaller)
    }

    func testEveryEditableStarterCreatesItsActualTrackingConfigurationWithoutProgress() throws {
        var identifiers = Set<String>()
        for starter in HabitStarter.library {
            XCTAssertTrue(identifiers.insert(starter.id).inserted, "Template IDs must remain unambiguous")
            let habit = try habits.createHabit(starter.draft, at: now)
            let configuration = try XCTUnwrap(activity.configuration(for: habit.id, on: now), starter.id)
            XCTAssertEqual(configuration.target, starter.draft.quantityTarget, starter.id)
            XCTAssertEqual(configuration.smallerAction, starter.draft.smallerAction, starter.id)
            XCTAssertEqual(try habits.configurationHistory(for: habit.id).count, 1, starter.id)
            XCTAssertTrue(try activity.entries(for: habit.id, on: now).isEmpty, starter.id)
            XCTAssertTrue(try habits.completions(for: habit.id,
                in: calendar.dateInterval(of: .day, for: now)!).isEmpty, starter.id)
        }
        XCTAssertEqual(Set(HabitStarter.library.map(\.group)), Set(HabitStarter.Group.allCases))
    }

    func testAmountAndSmallerActionAreSavedWithTheHabitAndItsLocalCreationDay() throws {
        let habit = try habits.createHabit(draft(target: .init(amount: 10, unit: .pages),
            smaller: "  One paragraph  "), at: now)
        let freshContext = ModelContext(store)
        let reopenedHabits = SwiftDataHabitRepository(modelContext: freshContext, calendar: calendar)
        let reopenedActivity = SwiftDataHabitActivityRepository(context: freshContext, habits: reopenedHabits, calendar: calendar)
        XCTAssertNotNil(try reopenedHabits.fetchHabit(id: habit.id))
        let configuration = try XCTUnwrap(reopenedActivity.configuration(for: habit.id, on: now))
        XCTAssertEqual(configuration.effectiveDayKey, LocalDay.key(for: now, calendar: calendar))
        XCTAssertEqual(configuration.revision, 0)
        XCTAssertEqual(configuration.target, .init(amount: 10, unit: .pages))
        XCTAssertEqual(configuration.smallerAction, "One paragraph")
        let previousDay = calendar.date(byAdding: .day, value: -1, to: now)!
        XCTAssertNil(try reopenedActivity.configuration(for: habit.id, on: previousDay))
    }

    func testAllAmountUnitsUseCanonicalPartialProgressAndThresholdCompletion() throws {
        for unit in HabitQuantityUnit.allCases {
            let habit = try habits.createHabit(draft(target: .init(amount: 2, unit: unit)), at: now)
            let config = try XCTUnwrap(activity.configuration(for: habit.id, on: now))
            try activity.log(habitID: habit.id, kind: .quantity, amount: 1,
                expectedConfigurationID: config.id, on: now, now: now)
            XCTAssertTrue(try habits.completions(for: habit.id,
                in: calendar.dateInterval(of: .day, for: now)!).isEmpty)
            try activity.log(habitID: habit.id, kind: .quantity, amount: 1,
                expectedConfigurationID: config.id, on: now, now: now)
            XCTAssertEqual(try activity.entries(for: habit.id, on: now).map(\.unit), [unit, unit])
            let completions = try habits.completions(for: habit.id, in: calendar.dateInterval(of: .day, for: now)!)
            XCTAssertEqual(completions.count, 1)
            XCTAssertEqual(completions.first?.source, .quantity)
        }
    }

    func testTimedCreationCanLogPausedMinutesThroughExistingTimerFlow() throws {
        let habit = try habits.createHabit(draft(target: .init(amount: 2, unit: .minutes)), at: now)
        try activity.saveTimer(.init(habitID: habit.id, dayKey: LocalDay.key(for: now, calendar: calendar),
            startedAt: nil, elapsedSeconds: 125), now: now)
        try activity.logTimer(habitID: habit.id, now: now)
        XCTAssertEqual(try activity.entries(for: habit.id, on: now).map(\.amount), [2])
        XCTAssertNil(try activity.timer(for: habit.id, on: now))
        XCTAssertEqual(try habits.completions(for: habit.id,
            in: calendar.dateInterval(of: .day, for: now)!).count, 1)
    }

    func testLegacyDraftRemainsASimpleCheckInAndOptionalSmallStepCreatesNoTarget() throws {
        let plain = try habits.createHabit(draft(), at: now)
        XCTAssertNil(try activity.configuration(for: plain.id, on: now))
        let supported = try habits.createHabit(draft(smaller: "One paragraph"), at: now)
        let config = try XCTUnwrap(activity.configuration(for: supported.id, on: now))
        XCTAssertNil(config.target)
        try activity.log(habitID: supported.id, kind: .smallerAction, amount: 0,
            expectedConfigurationID: config.id, on: now, now: now)
        XCTAssertEqual(try activity.entries(for: supported.id, on: now).map(\.kind), [.smallerAction])
        XCTAssertTrue(try habits.completions(for: supported.id,
            in: calendar.dateInterval(of: .day, for: now)!).isEmpty)
        XCTAssertNoThrow(try habits.recordCompletion(habitID: plain.id, at: now, source: .app, note: nil))
    }

    func testInvalidActivityDraftsLeaveNoHabitScheduleOrActivityRows() throws {
        for amount in [-1, 0, 10_001] {
            XCTAssertThrowsError(try habits.createHabit(draft(target: .init(amount: amount, unit: .pages)), at: now)) {
                XCTAssertEqual($0 as? HabitActivityError, .invalidTarget)
            }
        }
        XCTAssertThrowsError(try habits.createHabit(draft(smaller: String(repeating: "x", count: 161)), at: now))
        var avoidance = draft(target: .init(amount: 1, unit: .count))
        avoidance.polarity = .avoidance
        XCTAssertThrowsError(try habits.createHabit(avoidance, at: now)) {
            XCTAssertEqual($0 as? HabitRepositoryError, .manualQuantityRequiresPositivePolarity)
        }
        // Saving the context later must not resurrect a partially-created draft.
        try store.mainContext.save()
        XCTAssertTrue(try habits.fetchHabits(includeArchived: true).isEmpty)
        XCTAssertTrue(try store.mainContext.fetch(FetchDescriptor<HabitConfigurationSnapshotRecord>()).isEmpty)
        XCTAssertTrue(try store.mainContext.fetch(FetchDescriptor<HabitActivityConfigurationRecord>()).isEmpty)
    }

    func testInvalidScheduleAndMemoryDoNotCommitAValidActivityConfiguration() throws {
        var invalid = draft(target: .init(amount: 5, unit: .minutes))
        invalid.schedule = .weekdays([])
        XCTAssertThrowsError(try habits.createHabit(invalid, at: now))
        invalid.schedule = .daily
        invalid.whyItMatters = String(repeating: "x", count: 241)
        XCTAssertThrowsError(try habits.createHabit(invalid, at: now))
        try store.mainContext.save()
        XCTAssertTrue(try habits.fetchHabits(includeArchived: true).isEmpty)
        XCTAssertTrue(try store.mainContext.fetch(FetchDescriptor<HabitActivityConfigurationRecord>()).isEmpty)
    }

    func testOrdinaryHabitEditCannotReplaceAnActivityTargetOrRewriteItsEntries() throws {
        let habit = try habits.createHabit(draft(target: .init(amount: 10, unit: .pages), smaller: "One paragraph"), at: now)
        let original = try XCTUnwrap(activity.configuration(for: habit.id, on: now))
        try activity.log(habitID: habit.id, kind: .quantity, amount: 3,
            expectedConfigurationID: original.id, on: now, now: now)
        var edit = draft(target: .init(amount: 1, unit: .minutes), smaller: "Should not replace the saved setup")
        edit.name = "Read for myself"
        _ = try habits.updateHabit(id: habit.id, with: edit, at: now)
        XCTAssertEqual(try habits.fetchHabit(id: habit.id)?.name, edit.name)
        XCTAssertEqual(try activity.configuration(for: habit.id, on: now), original)
        XCTAssertEqual(try activity.entries(for: habit.id, on: now).map(\.amount), [3])
        XCTAssertEqual(try activity.entries(for: habit.id, on: now).map(\.unit), [.pages])
        XCTAssertEqual(try store.mainContext.fetch(FetchDescriptor<HabitActivityConfigurationRecord>()).count, 1)
    }

    func testRoutineStarterCollectionsResolveUniqueEditableIdeasWithoutBulkCreation() throws {
        for collection in HabitStarter.collections {
            XCTAssertEqual(collection.starters.map(\.id), collection.starterIDs)
            XCTAssertEqual(Set(collection.starterIDs).count, collection.starterIDs.count)
            XCTAssertTrue(collection.starters.allSatisfy { !$0.draft.name.isEmpty })
        }
        XCTAssertTrue(try habits.fetchHabits(includeArchived: true).isEmpty)
    }
}
