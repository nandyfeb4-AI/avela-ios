import XCTest
@testable import Avela

final class HabitPolarityFormatterTests: XCTestCase {
    func testCompletionActionLabelForPositivePolarity() {
        XCTAssertEqual(
            HabitPolarityFormatter.completionActionLabel(habitName: "Walk", polarity: .positive),
            "Mark Walk complete"
        )
    }

    func testCompletionActionLabelForAvoidancePolarityDoesNotAssumeTotalAbstinence() {
        // "Log success" (not "Mark avoided") stays correct whether the habit
        // means strict abstinence or merely a reduced amount, e.g. "Cut down
        // on late snacking" can be satisfied without "I ate zero snacks."
        XCTAssertEqual(
            HabitPolarityFormatter.completionActionLabel(habitName: "Late Snacking", polarity: .avoidance),
            "Log success for Late Snacking"
        )
    }

    func testUndoActionLabelForPositivePolarity() {
        XCTAssertEqual(
            HabitPolarityFormatter.undoActionLabel(habitName: "Walk", polarity: .positive),
            "Undo completion for Walk"
        )
    }

    func testUndoActionLabelForAvoidancePolarity() {
        XCTAssertEqual(
            HabitPolarityFormatter.undoActionLabel(habitName: "Late Snacking", polarity: .avoidance),
            "Undo success for Late Snacking"
        )
    }

    func testStatusLabelForPositivePolarity() {
        XCTAssertEqual(HabitPolarityFormatter.statusLabel(isCompleted: true, polarity: .positive), "Completed")
        XCTAssertEqual(HabitPolarityFormatter.statusLabel(isCompleted: false, polarity: .positive), "Not completed yet")
    }

    func testStatusLabelForAvoidancePolarity() {
        XCTAssertEqual(HabitPolarityFormatter.statusLabel(isCompleted: true, polarity: .avoidance), "Logged")
        XCTAssertEqual(HabitPolarityFormatter.statusLabel(isCompleted: false, polarity: .avoidance), "Not logged yet")
    }

    func testToastMessageForPositivePolarity() {
        XCTAssertEqual(HabitPolarityFormatter.toastMessage(habitName: "Walk", polarity: .positive), "Walk done")
    }

    func testToastMessageForAvoidancePolarity() {
        XCTAssertEqual(
            HabitPolarityFormatter.toastMessage(habitName: "Late Snacking", polarity: .avoidance),
            "Success logged for Late Snacking"
        )
    }
}
