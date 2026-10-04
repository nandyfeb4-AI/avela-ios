import Foundation
import XCTest
@testable import Avela

final class AttentionStatusFormatterTests: XCTestCase {
    private func row(state: AttentionProgressCalculator.ThresholdState?) -> AttentionGoalSummaryRow {
        AttentionGoalSummaryRow(
            id: UUID(), name: "Goal", appOrCategoryLabel: nil, targetLabel: "30 min budget",
            targetUnit: .minutes, statusLabel: "", state: state
        )
    }

    func testPillarStateIsNilWhenThereAreNoGoals() {
        XCTAssertNil(AttentionStatusFormatter.pillarState(for: []))
        XCTAssertEqual(AttentionStatusFormatter.pillarLabel(for: nil), "", "an absent pillar has no label to show")
    }

    func testPillarStateIsNotLoggedYetWhenNoGoalHasUsage() {
        let rows = [row(state: nil), row(state: nil)]
        XCTAssertEqual(AttentionStatusFormatter.pillarState(for: rows), .notLoggedYet)
        XCTAssertEqual(AttentionStatusFormatter.pillarLabel(for: .notLoggedYet), "Not logged yet")
        XCTAssertNotEqual(
            AttentionStatusFormatter.pillarLabel(for: .notLoggedYet), "On track",
            "the pillar must never claim a verified status when nothing has been logged"
        )
    }

    func testPillarStateIsHealthyWhenEveryLoggedGoalIsHealthy() {
        let rows = [row(state: .healthy), row(state: nil)]
        XCTAssertEqual(AttentionStatusFormatter.pillarState(for: rows), .state(.healthy))
        XCTAssertEqual(AttentionStatusFormatter.pillarLabel(for: .state(.healthy)), "Healthy")
    }

    func testPillarStatePrefersTheWorstCaseAcrossGoals() {
        let rows = [row(state: .healthy), row(state: .nearLimit), row(state: nil)]
        XCTAssertEqual(AttentionStatusFormatter.pillarState(for: rows), .state(.nearLimit))

        let withExceeded = rows + [row(state: .exceeded)]
        XCTAssertEqual(AttentionStatusFormatter.pillarState(for: withExceeded), .state(.exceeded))
    }
    func testLegacyExtremeAndNonFiniteAmountsFormatWithoutIntegerConversionTrap() {
        XCTAssertEqual(AttentionStatusFormatter.amountLabel(30, unit: .minutes), "30 min")
        XCTAssertEqual(AttentionStatusFormatter.amountLabel(2.5, unit: .minutes), "2.5 min")
        let legacy = AttentionStatusFormatter.amountLabel(1e100, unit: .minutes)
        XCTAssertTrue(legacy.hasSuffix(" min"))
        XCTAssertGreaterThan(legacy.count, 10)
        XCTAssertEqual(AttentionStatusFormatter.amountLabel(.infinity, unit: .minutes), "Unknown amount")
        XCTAssertEqual(AttentionStatusFormatter.amountLabel(.nan, unit: .minutes), "Unknown amount")
    }

    func testWindowReportsCannotImplyExceededUsageInBudgetPillar() {
        var interrupted = row(state: .exceeded)
        interrupted.goalType = .noUseBeforeTime
        XCTAssertEqual(AttentionStatusFormatter.pillarState(for: [interrupted]), .manualCheckIns)
        XCTAssertEqual(AttentionStatusFormatter.pillarLabel(for: .manualCheckIns), "Manual check-ins")
        XCTAssertEqual(AttentionStatusFormatter.pillarState(for: [row(state: .healthy), interrupted]), .state(.healthy))
    }

}
