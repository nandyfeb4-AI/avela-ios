import Foundation
import SwiftData
import XCTest
@testable import Avela

@MainActor
final class SwiftDataAttentionRepositoryTests: XCTestCase {
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

    private func makeRepository() throws -> SwiftDataAttentionRepository {
        let container = try AppPersistence.makeContainer(inMemory: true)
        self.container = container
        return SwiftDataAttentionRepository(modelContext: container.mainContext, calendar: calendar)
    }

    private let day1 = Date(timeIntervalSince1970: 1_718_632_800) // Mon 2024-06-17
    private let day2 = Date(timeIntervalSince1970: 1_718_805_600) // Wed 2024-06-19

    private func makeDraft(name: String = "Instagram", target: Double = 30) -> AttentionGoalDraft {
        AttentionGoalDraft(name: name, appOrCategoryLabel: "Social", type: .maxDurationPerDay, targetValue: target, unit: .minutes)
    }

    func testCreateGoalPersistsFieldsAndInitialConfigurationSnapshot() throws {
        let repository = try makeRepository()
        let goal = try repository.createGoal(makeDraft(), at: day1)

        XCTAssertEqual(goal.name, "Instagram")
        XCTAssertEqual(goal.appOrCategoryLabel, "Social")
        XCTAssertEqual(goal.type, .maxDurationPerDay)

        let history = try repository.configurationHistory(for: goal.id)
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.targetValue, 30)
        XCTAssertEqual(history.first?.effectiveLocalDateKey, "2024-06-17")
    }

    func testFetchGoalsReturnsEveryCreatedGoal() throws {
        let repository = try makeRepository()
        _ = try repository.createGoal(makeDraft(name: "Instagram"), at: day1)
        _ = try repository.createGoal(makeDraft(name: "YouTube"), at: day1)

        let goals = try repository.fetchGoals()
        XCTAssertEqual(Set(goals.map(\.name)), Set(["Instagram", "YouTube"]))
    }

    func testUpdatingNameOnlyDoesNotAppendConfigurationSnapshot() throws {
        let repository = try makeRepository()
        let goal = try repository.createGoal(makeDraft(), at: day1)

        var renamed = makeDraft()
        renamed.name = "Instagram (renamed)"
        let updated = try repository.updateGoal(id: goal.id, with: renamed, at: day2)

        XCTAssertEqual(updated.name, "Instagram (renamed)")
        let history = try repository.configurationHistory(for: goal.id)
        XCTAssertEqual(history.count, 1, "cosmetic edits must not fabricate budget history")
    }

    func testEditingBudgetAppendsSnapshotAndPreservesPriorHistory() throws {
        let repository = try makeRepository()
        let goal = try repository.createGoal(makeDraft(target: 30), at: day1)

        let updated = try repository.updateGoal(id: goal.id, with: makeDraft(target: 15), at: day2)
        XCTAssertEqual(updated.id, goal.id)

        let history = try repository.configurationHistory(for: goal.id)
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].targetValue, 30)
        XCTAssertEqual(history[0].effectiveLocalDateKey, "2024-06-17")
        XCTAssertEqual(history[1].targetValue, 15)
        XCTAssertEqual(history[1].effectiveLocalDateKey, "2024-06-19")

        // The budget active on day1 is still 30, unaffected by the later edit.
        let configurationOnDay1 = try repository.activeConfiguration(for: goal.id, on: day1)
        XCTAssertEqual(configurationOnDay1?.targetValue, 30)
        let configurationOnDay2 = try repository.activeConfiguration(for: goal.id, on: day2)
        XCTAssertEqual(configurationOnDay2?.targetValue, 15)
    }

    func testRecordUsagePersistsAmountAndLocalDayKey() throws {
        let repository = try makeRepository()
        let goal = try repository.createGoal(makeDraft(), at: day1)
        let entry = try repository.recordUsage(goalID: goal.id, amount: 12, at: day1, source: .manual)

        XCTAssertEqual(entry.amount, 12)
        XCTAssertEqual(entry.localDateKey, "2024-06-17")
        XCTAssertEqual(entry.source, .manual)
        XCTAssertEqual(entry.unit, .minutes)
    }

    func testMultipleUsageEntriesOnTheSameDaySumRatherThanOverwrite() throws {
        let repository = try makeRepository()
        let goal = try repository.createGoal(makeDraft(), at: day1)
        try repository.recordUsage(goalID: goal.id, amount: 10, at: day1, source: .manual)
        try repository.recordUsage(goalID: goal.id, amount: 5, at: day1.addingTimeInterval(3600), source: .manual)

        let entries = try repository.usageEntries(
            for: goal.id, in: DateInterval(start: calendar.startOfDay(for: day1), end: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day1))!)
        )
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.reduce(0) { $0 + $1.amount }, 15)
    }

    func testCorrectingAnEntryUpdatesItsAmountInPlace() throws {
        let repository = try makeRepository()
        let goal = try repository.createGoal(makeDraft(), at: day1)
        let entry = try repository.recordUsage(goalID: goal.id, amount: 10, at: day1, source: .manual)

        let corrected = try repository.updateUsageEntry(id: entry.id, amount: 25)
        XCTAssertEqual(corrected.id, entry.id)
        XCTAssertEqual(corrected.amount, 25)
    }

    func testDeletingAnEntryRemovesIt() throws {
        let repository = try makeRepository()
        let goal = try repository.createGoal(makeDraft(), at: day1)
        let entry = try repository.recordUsage(goalID: goal.id, amount: 10, at: day1, source: .manual)

        try repository.deleteUsageEntry(id: entry.id)

        let dayEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day1))!
        let entries = try repository.usageEntries(for: goal.id, in: DateInterval(start: calendar.startOfDay(for: day1), end: dayEnd))
        XCTAssertTrue(entries.isEmpty)
    }

    func testDeletingAnUnknownEntryThrows() throws {
        let repository = try makeRepository()
        let unknownID = UUID()
        XCTAssertThrowsError(try repository.deleteUsageEntry(id: unknownID)) { error in
            XCTAssertEqual(error as? AttentionRepositoryError, .usageEntryNotFound(unknownID))
        }
    }

    func testUpdatingAnUnknownGoalThrows() throws {
        let repository = try makeRepository()
        let unknownID = UUID()
        XCTAssertThrowsError(try repository.updateGoal(id: unknownID, with: makeDraft(), at: day1)) { error in
            XCTAssertEqual(error as? AttentionRepositoryError, .goalNotFound(unknownID))
        }
    }

    func testRecordingUsageAgainstUnknownGoalThrows() throws {
        let repository = try makeRepository()
        XCTAssertThrowsError(try repository.recordUsage(goalID: UUID(), amount: 10, at: day1, source: .manual))
    }

    func testEditingGoalDoesNotCorruptExistingUsageEntries() throws {
        let repository = try makeRepository()
        let goal = try repository.createGoal(makeDraft(target: 30), at: day1)
        let entry = try repository.recordUsage(goalID: goal.id, amount: 10, at: day1, source: .manual)

        _ = try repository.updateGoal(id: goal.id, with: makeDraft(target: 15), at: day2)

        let dayEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day1))!
        let entries = try repository.usageEntries(for: goal.id, in: DateInterval(start: calendar.startOfDay(for: day1), end: dayEnd))
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.id, entry.id)
        XCTAssertEqual(entries.first?.amount, 10)
    }

    func testUsageEntriesAcrossGoalsReturnsRecordsFromEveryGoal() throws {
        let repository = try makeRepository()
        let goalA = try repository.createGoal(makeDraft(name: "A"), at: day1)
        let goalB = try repository.createGoal(makeDraft(name: "B"), at: day1)
        let entryA = try repository.recordUsage(goalID: goalA.id, amount: 5, at: day1, source: .manual)
        let entryB = try repository.recordUsage(goalID: goalB.id, amount: 5, at: day1, source: .manual)

        let all = try repository.usageEntries(in: DateInterval(start: day1.addingTimeInterval(-3600), end: day1.addingTimeInterval(3600)))
        XCTAssertEqual(Set(all.map(\.id)), Set([entryA.id, entryB.id]))
    }
    func testWindowCheckInsRequireElapsedWindowAndKeepExplicitReports() throws {
        let repository = try makeRepository()
        let startOfDay = calendar.startOfDay(for: day1)
        let goal = try repository.createGoal(AttentionGoalDraft(name: "No news before 9", appOrCategoryLabel: nil,
            type: .noUseBeforeTime, targetValue: 30, unit: .minutes,
            windowStartMinute: 0, windowEndMinute: 540), at: startOfDay)
        XCTAssertThrowsError(try repository.recordCheckIn(goalID: goal.id, on: day1, outcome: .kept,
            at: startOfDay.addingTimeInterval(8 * 3600)))
        let first = try repository.recordCheckIn(goalID: goal.id, on: day1, outcome: .kept, at: day1)
        let correction = try repository.recordCheckIn(goalID: goal.id, on: day1, outcome: .interrupted, at: day1)
        let reports = try repository.checkIns(for: goal.id,
            in: DateInterval(start: startOfDay, end: startOfDay.addingTimeInterval(86400)))
        XCTAssertEqual(reports.map(\.outcome), [.kept, .interrupted])
        XCTAssertEqual(correction.revision, first.revision + 1)
        XCTAssertEqual(reports.map(\.recordedAt), [day1, day1])
        XCTAssertEqual(first.windowEnd, startOfDay.addingTimeInterval(9 * 3600))
    }

    func testWindowEditsAppendSnapshotsAndCannotChangeGoalFamily() throws {
        let repository = try makeRepository()
        let original = AttentionGoalDraft(name: "Morning", appOrCategoryLabel: nil,
            type: .phoneFreeUntilTime, targetValue: 30, unit: .minutes,
            windowStartMinute: 420, windowEndMinute: 540)
        let goal = try repository.createGoal(original, at: day1)
        var edited = original
        edited.windowEndMinute = 600
        _ = try repository.updateGoal(id: goal.id, with: edited, at: day2)
        XCTAssertEqual(try repository.configurationHistory(for: goal.id).map(\.windowEndMinute), [540, 600])
        XCTAssertEqual(try repository.activeConfiguration(for: goal.id, on: day1)?.windowEndMinute, 540)
        edited.type = .maxDurationPerDay
        XCTAssertThrowsError(try repository.updateGoal(id: goal.id, with: edited, at: day2))
        XCTAssertEqual(try repository.fetchGoal(id: goal.id)?.type, .phoneFreeUntilTime)
        XCTAssertThrowsError(try repository.recordUsage(goalID: goal.id, amount: 5, at: day1, source: .manual))
    }

    func testPhoneFreeSessionRetainsOriginalTargetAcrossEditsAndNeverAutoCompletes() throws {
        let repository = try makeRepository()
        let goal = try repository.createGoal(AttentionGoalDraft(name: "Focus", appOrCategoryLabel: nil,
            type: .phoneFreeSession, targetValue: 30, unit: .minutes), at: day1)
        let session = try repository.startSession(goalID: goal.id, at: day1)
        XCTAssertThrowsError(try repository.startSession(goalID: goal.id, at: day1))
        XCTAssertThrowsError(try repository.finishSession(id: session.id, outcome: .kept, at: day1.addingTimeInterval(60)))
        _ = try repository.updateGoal(id: goal.id, with: AttentionGoalDraft(name: "Focus", appOrCategoryLabel: nil,
            type: .phoneFreeSession, targetValue: 60, unit: .minutes), at: day1.addingTimeInterval(120))
        let reopened = SwiftDataAttentionRepository(modelContext: try XCTUnwrap(container).mainContext, calendar: calendar)
        let pending = try XCTUnwrap(reopened.sessions(for: goal.id).first)
        XCTAssertTrue(pending.isActive)
        XCTAssertNil(pending.outcome)
        XCTAssertEqual(pending.targetMinutes, 30)
        XCTAssertEqual(pending.expectedEnd, day1.addingTimeInterval(1800))
        let finished = try reopened.finishSession(id: session.id, outcome: .kept, at: day1.addingTimeInterval(1800))
        XCTAssertEqual(finished.outcome, .kept)
        XCTAssertFalse(finished.isActive)
        XCTAssertThrowsError(try reopened.finishSession(id: session.id, outcome: .interrupted, at: day2))
    }

    func testInterruptedSessionCanEndEarlyAndNextSessionCanStart() throws {
        let repository = try makeRepository()
        let goal = try repository.createGoal(AttentionGoalDraft(name: "Focus", appOrCategoryLabel: nil,
            type: .phoneFreeSession, targetValue: 30, unit: .minutes), at: day1)
        let first = try repository.startSession(goalID: goal.id, at: day1)
        _ = try repository.finishSession(id: first.id, outcome: .interrupted, at: day1.addingTimeInterval(60))
        _ = try repository.startSession(goalID: goal.id, at: day1.addingTimeInterval(120))
        XCTAssertEqual(try repository.sessions(for: goal.id).count, 2)
        XCTAssertEqual(try repository.sessions(for: goal.id).first?.outcome, .interrupted)
    }

    func testRepositoryRejectsNonFiniteNegativeAndOversizedQuantitiesWithoutWrites() throws {
        let repository = try makeRepository()
        for target in [-1.0, 0, .nan, .infinity, -.infinity, 1441, 1e100] {
            XCTAssertThrowsError(try repository.createGoal(makeDraft(target: target), at: day1)) {
                XCTAssertEqual($0 as? AttentionRepositoryError, .invalidGoal)
            }
        }
        XCTAssertTrue(try repository.fetchGoals().isEmpty)
        let goal = try repository.createGoal(makeDraft(target: 1440), at: day1)
        for amount in [-1.0, .nan, .infinity, -.infinity, 1441, 1e100] {
            XCTAssertThrowsError(try repository.recordUsage(goalID: goal.id, amount: amount, at: day1, source: .manual)) {
                XCTAssertEqual($0 as? AttentionRepositoryError, .invalidAmount)
            }
        }
        let zero = try repository.recordUsage(goalID: goal.id, amount: 0, at: day1, source: .manual)
        for amount in [-1.0, .nan, .infinity, 1441, 1e100] {
            XCTAssertThrowsError(try repository.updateUsageEntry(id: zero.id, amount: amount))
        }
        XCTAssertEqual(try repository.usageEntries(for: goal.id,
            in: DateInterval(start: day1.addingTimeInterval(-1), end: day1.addingTimeInterval(1))).map(\.amount), [0])
        XCTAssertThrowsError(try repository.updateGoal(id: goal.id, with: makeDraft(target: 1e100), at: day2))
        XCTAssertEqual(try repository.configurationHistory(for: goal.id).count, 1)
    }

}
