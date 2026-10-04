import Foundation
import XCTest
@testable import Avela

final class AttentionProgressCalculatorTests: XCTestCase {
    private let goalID = UUID()

    private func entry(amount: Double, at date: Date = Date()) -> AttentionUsageEntry {
        AttentionUsageEntry(
            id: UUID(), attentionGoalID: goalID, amount: amount, unit: .minutes,
            recordedAt: date, localDateKey: "2024-06-17", source: .manual
        )
    }

    func testNoEntriesMeansMissingDataNotMeasuredZero() {
        let progress = AttentionProgressCalculator.DailyProgress(entries: [], target: 30, unit: .minutes)

        XCTAssertFalse(progress.hasLoggedUsage)
        XCTAssertEqual(progress.entryCount, 0)
        XCTAssertEqual(progress.totalAmount, 0, "the total is still a real zero sum")
        XCTAssertNil(progress.percentOfTarget, "no entries must not imply a verified 0% status")
        XCTAssertNil(progress.state, "no entries must not imply an automatically measured 'healthy' status")
    }

    func testMultipleEntriesAreSummedNotDeduplicated() throws {
        let progress = AttentionProgressCalculator.DailyProgress(
            entries: [entry(amount: 10), entry(amount: 5), entry(amount: 5)], target: 30, unit: .minutes
        )

        XCTAssertTrue(progress.hasLoggedUsage)
        XCTAssertEqual(progress.entryCount, 3)
        XCTAssertEqual(progress.totalAmount, 20)
        XCTAssertEqual(try XCTUnwrap(progress.percentOfTarget), (20.0 / 30.0) * 100, accuracy: 0.0001)
    }

    func testThresholdJustBelowSeventyPercentIsHealthy() {
        let progress = AttentionProgressCalculator.DailyProgress(entries: [entry(amount: 20)], target: 30, unit: .minutes)
        XCTAssertEqual(progress.state, .healthy)
    }

    func testThresholdAtExactlySeventyPercentIsNearLimit() throws {
        let progress = AttentionProgressCalculator.DailyProgress(entries: [entry(amount: 21)], target: 30, unit: .minutes)
        XCTAssertEqual(try XCTUnwrap(progress.percentOfTarget), 70, accuracy: 0.0001)
        XCTAssertEqual(progress.state, .nearLimit)
    }

    func testThresholdJustBelowOneHundredPercentIsNearLimit() {
        let progress = AttentionProgressCalculator.DailyProgress(entries: [entry(amount: 29)], target: 30, unit: .minutes)
        XCTAssertEqual(progress.state, .nearLimit)
    }

    func testThresholdAtExactlyOneHundredPercentIsExceeded() {
        let progress = AttentionProgressCalculator.DailyProgress(entries: [entry(amount: 30)], target: 30, unit: .minutes)
        XCTAssertEqual(progress.state, .exceeded)
    }

    func testUsageBeyondTargetIsExceeded() {
        let progress = AttentionProgressCalculator.DailyProgress(entries: [entry(amount: 45)], target: 30, unit: .minutes)
        XCTAssertEqual(progress.state, .exceeded)
    }

    func testHistoricalTargetResolutionAcrossABudgetEdit() {
        let day1Key = "2024-06-17"
        let day2Key = "2024-06-19"
        let snapshots = [
            AttentionGoalConfigurationSnapshot(
                id: UUID(), attentionGoalID: goalID, targetValue: 30, unit: .minutes,
                effectiveLocalDateKey: day1Key, revision: 0, createdAt: Date(timeIntervalSince1970: 0)
            ),
            AttentionGoalConfigurationSnapshot(
                id: UUID(), attentionGoalID: goalID, targetValue: 15, unit: .minutes,
                effectiveLocalDateKey: day2Key, revision: 1, createdAt: Date(timeIntervalSince1970: 1)
            ),
        ]

        let beforeEdit = AttentionGoalEvaluator.activeConfiguration(from: snapshots, onKey: day1Key)
        XCTAssertEqual(beforeEdit?.targetValue, 30, "editing today's budget must not rewrite what the budget was on a past day")

        let afterEdit = AttentionGoalEvaluator.activeConfiguration(from: snapshots, onKey: day2Key)
        XCTAssertEqual(afterEdit?.targetValue, 15)
    }

    func testHistoricalResolutionFallsBackToEarliestSnapshotWhenDatePrecedesAllSnapshots() {
        let snapshot = AttentionGoalConfigurationSnapshot(
            id: UUID(), attentionGoalID: goalID, targetValue: 30, unit: .minutes,
            effectiveLocalDateKey: "2024-06-17", revision: 0, createdAt: Date()
        )
        let resolved = AttentionGoalEvaluator.activeConfiguration(from: [snapshot], onKey: "2024-01-01")
        XCTAssertEqual(resolved?.targetValue, 30)
    }

    func testSameDayEditsResolveByRevisionNotCreatedAt() {
        let sharedTimestamp = Date(timeIntervalSince1970: 1000)
        let snapshots = [
            AttentionGoalConfigurationSnapshot(
                id: UUID(), attentionGoalID: goalID, targetValue: 30, unit: .minutes,
                effectiveLocalDateKey: "2024-06-17", revision: 0, createdAt: sharedTimestamp
            ),
            AttentionGoalConfigurationSnapshot(
                id: UUID(), attentionGoalID: goalID, targetValue: 45, unit: .minutes,
                effectiveLocalDateKey: "2024-06-17", revision: 1, createdAt: sharedTimestamp
            ),
        ]
        let resolved = AttentionGoalEvaluator.activeConfiguration(from: snapshots, onKey: "2024-06-17")
        XCTAssertEqual(resolved?.targetValue, 45)
    }
    func testProtectedWindowUsesCalendarAcrossDSTAndOvernight() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let spring = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 3, day: 10)))
        let springWindow = try XCTUnwrap(AttentionWindowCalculator.interval(on: spring,
            startMinute: 60, endMinute: 240, calendar: calendar))
        XCTAssertEqual(springWindow.duration, 2 * 3600)
        let fall = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 11, day: 3)))
        let fallWindow = try XCTUnwrap(AttentionWindowCalculator.interval(on: fall,
            startMinute: 0, endMinute: 180, calendar: calendar))
        XCTAssertEqual(fallWindow.duration, 4 * 3600)
        let yearEnd = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 12, day: 31)))
        let overnight = try XCTUnwrap(AttentionWindowCalculator.interval(on: yearEnd,
            startMinute: 1320, endMinute: 540, calendar: calendar))
        XCTAssertEqual(overnight.duration, 11 * 3600)
        XCTAssertEqual(calendar.component(.year, from: overnight.end), 2025)
    }

    func testProtectedWindowRejectsInvalidBoundsAndUsesNextValidSpringTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 3, day: 10)))
        XCTAssertNil(AttentionWindowCalculator.interval(on: date, startMinute: 540, endMinute: 540, calendar: calendar))
        XCTAssertNil(AttentionWindowCalculator.interval(on: date, startMinute: -1, endMinute: 540, calendar: calendar))
        let window = try XCTUnwrap(AttentionWindowCalculator.interval(on: date,
            startMinute: 150, endMinute: 240, calendar: calendar))
        XCTAssertEqual(calendar.component(.hour, from: window.start), 3)
        XCTAssertEqual(calendar.component(.minute, from: window.start), 0)
    }

}
