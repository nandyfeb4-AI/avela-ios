import XCTest
@testable import Avela

@MainActor
final class HabitCalendarPlanTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_791_000_000)

    func testPlanUsesChosenTitleAndExactElapsedDuration() throws {
        let start = Date(timeIntervalSince1970: 1_793_516_400)
        let plan = try HabitCalendarPlan(habitName: "  Read  ", start: start, minutes: 90, now: now)
        XCTAssertEqual(plan.title, "Make room for Read")
        XCTAssertEqual(plan.start, start)
        XCTAssertEqual(plan.end.timeIntervalSince(start), 5400)
    }
    func testInvalidPlansDoNotProduceAnEditorDraft() {
        for minutes in [0, -1, 181, Int.max] {
            XCTAssertThrowsError(try HabitCalendarPlan(habitName: "Read", start: now, minutes: minutes, now: now))
        }
        XCTAssertThrowsError(try HabitCalendarPlan(habitName: " ", start: now, minutes: 20, now: now))
        XCTAssertThrowsError(try HabitCalendarPlan(habitName: "Read", start: now.addingTimeInterval(-1), minutes: 20, now: now))
    }
    func testInvalidSuggestedDurationFallsBackAndLargeTargetsClamp() {
        XCTAssertEqual(HabitCalendarSchedulingModel(habitName: "Read", suggestedMinutes: .nan, now: now).minutes, 20)
        XCTAssertEqual(HabitCalendarSchedulingModel(habitName: "Read", suggestedMinutes: .infinity, now: now).minutes, 20)
        XCTAssertEqual(HabitCalendarSchedulingModel(habitName: "Read", suggestedMinutes: 1440, now: now).minutes, 180)
    }
    func testReviewCancelKeepsPlanChoicesAndDoesNotClaimSave() {
        let model = HabitCalendarSchedulingModel(habitName: "Read", suggestedMinutes: 15, now: now)
        model.prepare(now: now)
        XCTAssertNotNil(model.plan)
        model.finish(saved: false)
        XCTAssertNil(model.plan)
        XCTAssertNil(model.feedback)
        XCTAssertEqual(model.minutes, 15)
        XCTAssertEqual(model.start, now.addingTimeInterval(3600))
    }
    func testPastStartCannotBeSubmittedAndSavedFeedbackDoesNotClaimSuccess() {
        let model = HabitCalendarSchedulingModel(habitName: "Read", suggestedMinutes: 20, now: now)
        model.start = now.addingTimeInterval(-1)
        model.prepare(now: now)
        XCTAssertNil(model.plan)
        XCTAssertNotNil(model.errorMessage)
        model.start = now.addingTimeInterval(3600)
        model.prepare(now: now)
        XCTAssertNil(model.errorMessage)
        model.finish(saved: true)
        XCTAssertTrue(model.feedback?.contains("no session was started or habit logged") == true)
    }

    func testSavedFeedbackClearsWhenPlanningAnotherTimeOrReviewingAgain() {
        let model = HabitCalendarSchedulingModel(habitName: "Read", suggestedMinutes: 20, now: now)
        model.prepare(now: now)
        model.finish(saved: true)
        model.start = model.start.addingTimeInterval(3600)
        XCTAssertNil(model.feedback, "A changed draft has not been saved in Calendar")

        model.prepare(now: now)
        model.finish(saved: true)
        model.minutes = 30
        XCTAssertNil(model.feedback)

        model.prepare(now: now)
        model.finish(saved: true)
        model.prepare(now: now)
        XCTAssertNil(model.feedback, "Opening a new review must not retain an earlier save acknowledgment")
        XCTAssertNotNil(model.plan)
        model.finish(saved: false)
        XCTAssertNil(model.feedback)
    }

    func testExpiredPlanCannotKeepOldEditorOrSuccessOnFailedReview() {
        let model = HabitCalendarSchedulingModel(habitName: "Read", suggestedMinutes: 20, now: now)
        model.prepare(now: now)
        XCTAssertNotNil(model.plan)
        model.prepare(now: model.start.addingTimeInterval(1))
        XCTAssertNil(model.plan, "Failed validation cannot keep an older valid editor draft")
        XCTAssertNotNil(model.errorMessage)
        XCTAssertNil(model.feedback)
    }
}
