import XCTest

/// Runs only against a fresh redirected DEBUG store, never an owner's data.
/// Screenshot attachments are the implemented native interface, not mockups.
final class PremiumRefreshUITests: XCTestCase {
    private var storeDirectory: URL!
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        storeDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        app?.terminate()
        try? FileManager.default.removeItem(at: storeDirectory)
        app = nil
    }

    private func launch(fixture: String? = nil, onboarding: Bool = false, largestText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["AVELA_UI_TEST_STORE_PATH"] = storeDirectory.appendingPathComponent("PremiumRefresh.store").path
        if let fixture { app.launchEnvironment["AVELA_UI_TEST_SEED_FIXTURE"] = fixture }
        if onboarding { app.launchEnvironment["AVELA_UI_TEST_ONBOARDING"] = "1" }
        if largestText { app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        self.app = app
        app.launch()
        return app
    }

    private func tap(_ element: XCUIElement, direction: String = "up", file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<12 {
            if element.exists && element.isHittable { break }
            if direction == "down" { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(element.waitForExistence(timeout: 10), app.debugDescription, file: file, line: line)
        XCTAssertTrue(element.isHittable, file: file, line: line)
        element.tap()
    }

    private func reveal(_ element: XCUIElement, direction: String = "up", file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<14 {
            if element.exists && element.isHittable { break }
            if direction == "down" { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(element.exists && element.isHittable, app.debugDescription, file: file, line: line)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func frameHeadingForCapture(_ heading: XCUIElement) {
        reveal(heading, direction: "down")
        // Keep a report's title and chart together in the native capture.
        // Drag within the scroll view, whose padded outer gutter does not
        // always receive touch events. This is a vertical scroll; the chart's
        // selection changes only horizontally. Recorded facts are unchanged.
        for _ in 0..<8 {
            let top = app.navigationBars.firstMatch.frame.maxY + 24
            let delta = heading.frame.minY - top
            if abs(delta) < 40 { break }
            let shift = min(abs(delta) / app.frame.height, 0.25) * (delta > 0 ? -1.0 : 1.0)
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.58))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.58 + shift)))
        }
    }

    private func chooseLens(_ name: String, largestText: Bool = false) {
        let picker = app.descendants(matching: .any)["insights.reportLens"].firstMatch
        // The larger-text hero can put the first picker below the viewport;
        // after reading a long chart it is above. Follow actual geometry.
        let direction = picker.exists && picker.frame.maxY < app.frame.midY ? "down" : "up"
        reveal(picker, direction: direction)
        if largestText { tap(app.buttons["insights.reportLens"]) }
        tap(app.buttons[name])
    }

    func testReportLensesAndSharePreviewPreserveRecordedFacts() {
        let app = launch(fixture: "premiumReports")
        tap(app.tabBars.buttons["Insights"])
        let consistency = app.staticTexts["insights.overallConsistency"]
        XCTAssertTrue(consistency.waitForExistence(timeout: 10))
        let originalPercentage = consistency.label
        capture("Luminous Insights weekly review")

        tap(app.buttons["insights.share"])
        XCTAssertTrue(app.navigationBars["Preview Your Card"].waitForExistence(timeout: 10))
        let names = app.switches["insights.shareNames"]
        XCTAssertEqual(names.value as? String, "0", "Habit names must be opt-in in the share preview")
        let dates = app.switches["insights.shareDates"]
        XCTAssertEqual(dates.value as? String, "1")
        names.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
        XCTAssertEqual(names.value as? String, "1")
        dates.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
        XCTAssertEqual(dates.value as? String, "0")
        capture("Luminous share preview with explicit name consent")
        tap(app.buttons["Done"])

        chooseLens("Rhythm")
        tap(app.buttons["insights.rhythm.values"])
        XCTAssertTrue(app.staticTexts["Your rhythm"].exists)
        tap(app.buttons["insights.rhythm.values"])
        frameHeadingForCapture(app.staticTexts["Your rhythm"])
        capture("Luminous twelve week recorded rhythm")
        reveal(app.buttons["insights.quantityPicker"])
        XCTAssertTrue(app.staticTexts["318 minutes"].exists, "Captured amounts are summed in their own unit")
        capture("Luminous captured quantity report")
        reveal(app.staticTexts["12 sessions started"])
        XCTAssertTrue(app.staticTexts["8 reported kept"].exists)
        XCTAssertTrue(app.staticTexts["4 reported interrupted"].exists)
        capture("Luminous self reported session report")

        chooseLens("Activity")
        reveal(app.buttons["insights.activity.month"])
        capture("Luminous year and month activity map")
        tap(app.buttons["insights.activity.values"])
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "check-ins")).firstMatch.exists)
        chooseLens("Week")
        XCTAssertEqual(consistency.label, originalPercentage)
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE")
        app.launch()
        tap(app.tabBars.buttons["Insights"])
        XCTAssertEqual(consistency.label, originalPercentage, "Charts and share preview cannot change progress")
    }

    func testReportValuesRemainReachableAtLargestText() {
        let app = launch(fixture: "premiumReports", largestText: true)
        tap(app.tabBars.buttons["Insights"])
        XCTAssertTrue(app.staticTexts["insights.overallConsistency"].waitForExistence(timeout: 10))
        capture("Luminous weekly review at largest text")
        chooseLens("Rhythm", largestText: true)
        tap(app.buttons["insights.rhythm.values"])
        XCTAssertTrue(app.staticTexts["insights.rhythm.accessibleSummary"].exists,
                      "Large text uses readable weekly values instead of overlapping chart axes")
        capture("Luminous rhythm accessible values")
        tap(app.buttons["insights.rhythm.values"])
        chooseLens("Activity", largestText: true)
        tap(app.buttons["insights.activity.values"])
        capture("Luminous activity accessible date values")
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    func testHomeDayReviewKeepsFirstAndHistoricalCorrectionDatesWithoutSaving() {
        let app = launch()
        tap(app.buttons["today.addHabitButton"])
        tap(app.textFields["habitForm.nameField"])
        app.textFields["habitForm.nameField"].typeText("First day")
        tap(app.buttons["habitForm.saveButton"])
        reviewDayWithoutSaving(Date(), habitName: "First day", in: app)
        XCTAssertTrue(app.buttons["Mark First day complete"].exists,
                      "Opening a first-day midnight projection and cancelling must not log success")

        // A second fresh redirected store supplies historical facts. Neither
        // scenario ever touches the ordinary application store or resets iOS.
        app.terminate()
        app.launchEnvironment["AVELA_UI_TEST_STORE_PATH"] = storeDirectory.appendingPathComponent("HistoricalReview.store").path
        app.launchEnvironment["AVELA_UI_TEST_SEED_FIXTURE"] = "populated"
        app.launch()
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())!.start
        let past = Calendar.current.date(byAdding: .day, value: -1, to: weekStart)!
        reviewDayWithoutSaving(past, habitName: "Read", in: app)
        XCTAssertTrue(app.buttons["Mark Read complete"].exists,
                      "A cancelled historical correction cannot create today's success")
    }

    private func reviewDayWithoutSaving(_ date: Date, habitName: String, in app: XCUIApplication) {
        tap(app.buttons["today.openCalendar"])
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let day = app.buttons["homeCalendar.day.\(formatter.string(from: date))"]
        for _ in 0..<2 where !day.exists { tap(app.buttons["homeCalendar.previousMonth"]) }
        reveal(day)
        let originalCount = day.value as? String
        tap(day)
        let review = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Review or correct \(habitName) on ")).firstMatch
        tap(review)
        XCTAssertTrue(app.descendants(matching: .any)["activity.date"].firstMatch.waitForExistence(timeout: 10))
        tap(app.buttons["activity.correctSuccess"])
        let expectedTitle = "Update \(date.formatted(date: .abbreviated, time: .omitted))?"
        XCTAssertTrue(app.alerts[expectedTitle].waitForExistence(timeout: 10),
                      "The correction must name the day selected in Home, including the habit's creation day")
        capture("Home selected day correction review - \(habitName)")
        tap(app.alerts.buttons["Cancel"])
        tap(app.navigationBars["Progress & History"].buttons["Done"])
        tap(app.buttons["homeCalendar.dayReviewDone"])
        XCTAssertEqual(day.value as? String, originalCount, "Review and Cancel retain the selected day's recorded count")
        tap(app.buttons["homeCalendar.done"])
    }

    func testHomeCalendarReviewDoesNotLogOrChangeToday() {
        let app = launch(fixture: "populated")
        XCTAssertTrue(app.buttons["Mark Read complete"].waitForExistence(timeout: 10))
        capture("Luminous Today with home week calendar")
        tap(app.buttons["today.openCalendar"])
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["homeCalendar.nextMonth"].isEnabled, "The month control cannot advance past today")
        capture("Luminous Home month calendar")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let key = formatter.string(from: Date())
        tap(app.buttons["homeCalendar.day.\(key)"])
        XCTAssertTrue(app.navigationBars["Day Review"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Read"].exists)
        capture("Luminous read only day review")
        tap(app.buttons["homeCalendar.dayReviewDone"])
        tap(app.buttons["homeCalendar.done"])
        XCTAssertTrue(app.buttons["Mark Read complete"].exists, "Reviewing dates must never log a habit")
    }

    func testAmountTemplateReviewSavesAndLogsExplicitly() {
        let app = launch()
        tap(app.buttons["today.addHabitButton"])
        tap(app.buttons["habitForm.ideasLink"])
        XCTAssertTrue(app.navigationBars["Habit Ideas"].waitForExistence(timeout: 10))
        capture("Luminous editable habit idea library")
        let search = app.searchFields.firstMatch
        reveal(search, direction: "down")
        tap(search); search.typeText("Read")
        tap(app.buttons["habitStarter.read"])
        XCTAssertEqual(app.textFields["habitForm.nameField"].value as? String, "Read")
        reveal(app.textFields["habitForm.targetAmountField"])
        XCTAssertEqual(app.textFields["habitForm.targetAmountField"].value as? String, "10")
        capture("Luminous amount habit creation preview")
        tap(app.buttons["habitForm.saveButton"])
        tap(app.buttons["Open Read details"])
        capture("Luminous habit detail with primary actions")
        tap(app.buttons["habitDetail.activity"])
        XCTAssertEqual(app.staticTexts["activity.progress"].label, "0 of 10 pages logged")
        tap(app.buttons["activity.quickPreset.5"])
        XCTAssertEqual(app.staticTexts["activity.progress"].label, "5 of 10 pages logged")
        tap(app.buttons["activity.quickPreset.5"])
        XCTAssertEqual(app.staticTexts["activity.progress"].label, "10 of 10 pages logged")
        capture("Luminous amount habit logging feedback")
        tap(app.buttons["Done"])
        app.terminate(); app.launch()
        tap(app.buttons["today.doneToggle"])
        XCTAssertTrue(app.buttons["Open Read details"].exists, "Quantity progress survives relaunch")
    }

    func testPinnedHabitStaysFirstAfterRelaunchWithoutChangingProgress() {
        let app = launch(fixture: "populated")
        tap(app.buttons["today.choosePriority"])
        tap(app.buttons["today.pin.Walk"])
        let walk = app.buttons["Open Walk details"]
        let read = app.buttons["Open Read details"]
        reveal(walk)
        XCTAssertLessThan(walk.frame.minY, read.frame.minY)
        XCTAssertTrue(app.buttons["Mark Walk complete"].exists)
        capture("Luminous Today with a user pinned habit")
        app.terminate(); app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE"); app.launch()
        reveal(walk)
        XCTAssertLessThan(walk.frame.minY, read.frame.minY)
        XCTAssertTrue(app.buttons["Mark Walk complete"].exists, "Pinning changes presentation, never progress")
    }

    func testMyDayChangedPauseCancellationKeepsHabitAndProgress() {
        let app = launch(fixture: "populated")
        tap(app.buttons["today.myDayChanged"])
        XCTAssertTrue(app.navigationBars["A Manageable Week"].waitForExistence(timeout: 10))
        capture("Luminous My day changed support")
        tap(app.buttons["Pause Read"])
        XCTAssertTrue(app.alerts["Pause This Habit?"].waitForExistence(timeout: 10))
        tap(app.alerts.buttons["Keep Habit"])
        tap(app.buttons["Done"])
        app.terminate(); app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE"); app.launch()
        XCTAssertTrue(app.buttons["Mark Read complete"].waitForExistence(timeout: 10), "Cancelling cannot pause or log the habit")
    }

    func testRoutineStarterDraftCanBeReviewedAndCancelledWithoutCreatingAnything() {
        let app = launch(fixture: "populated")
        tap(app.buttons["today.routines"])
        tap(app.buttons["routines.starter.focus"])
        XCTAssertTrue(app.navigationBars["New Routine"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["routine.name"].value as? String, "Focus")
        capture("Luminous routine starter editable review")
        tap(app.navigationBars["New Routine"].buttons["Cancel"])
        XCTAssertTrue(app.navigationBars["Routines"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "routine.")).count, 0,
                       "A starter is an unsaved draft until Save")
        tap(app.navigationBars["Routines"].buttons["Done"])
        app.terminate(); app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE"); app.launch()
        tap(app.buttons["today.routines"])
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "routine.")).count, 0)
    }

    func testTodayQuantityChipUndoRemovesOnlyItsLastEntry() {
        let app = launch()
        tap(app.buttons["today.addHabitButton"])
        tap(app.textFields["habitForm.nameField"])
        app.textFields["habitForm.nameField"].typeText("Read")
        tap(app.buttons["Amount"])
        // A native menu picker may expose a picker/pop-up role on this OS.
        let unitPicker = app.descendants(matching: .any)["habitForm.quantityUnitPicker"].firstMatch
        XCTAssertTrue(unitPicker.waitForExistence(timeout: 5), app.debugDescription)
        // Dismiss the name keyboard with a short form scroll. A full-screen
        // swipe can jump past the newly inserted target/unit rows.
        for _ in 0..<10 {
            if unitPicker.exists && unitPicker.isHittable { break }
            let above = unitPicker.exists && unitPicker.frame.maxY < app.navigationBars.firstMatch.frame.maxY
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.45))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: above ? 0.63 : 0.27)))
        }
        XCTAssertTrue(unitPicker.isHittable, app.debugDescription)
        unitPicker.tap()
        tap(app.buttons["Pages"])
        XCTAssertEqual(app.textFields["habitForm.targetAmountField"].value as? String, "10")
        tap(app.buttons["habitForm.saveButton"])
        let row = app.buttons["Open Read details"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        let quickAmount = app.buttons["today.quickAmount.Read"]
        tap(quickAmount)
        tap(quickAmount)
        tap(app.buttons["today.undoToast.undoButton"])
        let onePage = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "1 of 10 pages"), object: row)
        XCTAssertEqual(XCTWaiter.wait(for: [onePage], timeout: 10), .completed,
                       "Undo must remove only the latest amount, retaining the earlier entry")
        capture("Luminous Today quantity chip after exact entry Undo")
        XCTAssertFalse(app.buttons["Undo completion for Read"].exists, "A partial amount never becomes a full success")
        app.terminate(); app.launch()
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertTrue((row.value as? String ?? "").contains("1 of 10 pages"))
        tap(row)
        tap(app.buttons["habitDetail.activity"])
        XCTAssertEqual(app.staticTexts["activity.progress"].label, "1 of 10 pages logged")
    }

    func testMakeRoomDurationStarterRequiresReviewBeforeSave() {
        let app = launch()
        tap(app.buttons["today.addHabitButton"])
        tap(app.textFields["habitForm.nameField"])
        app.textFields["habitForm.nameField"].typeText("Read")
        tap(app.buttons["habitForm.saveButton"])
        tap(app.buttons["Open Read details"])
        tap(app.buttons["habitDetail.intention"])
        capture("Luminous Make Room session composer")
        tap(app.buttons["intentionSession.duration.25"])
        let target = app.textFields["attentionGoalForm.targetField"]
        XCTAssertTrue(target.waitForExistence(timeout: 10))
        XCTAssertEqual(Double(target.value as? String ?? ""), 25)
        tap(app.buttons["attentionGoalForm.cancelButton"])
        XCTAssertFalse(app.buttons["intentionSession.start"].exists)
        tap(app.buttons["intentionSession.duration.25"])
        tap(app.buttons["attentionGoalForm.saveButton"])
        XCTAssertTrue(app.buttons["intentionSession.start"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["intentionSession.openStarted"].exists, "Saving a goal is not a session start")
        capture("Luminous Make Room reviewed 25 minute goal")
        tap(app.buttons["intentionSession.start"])
        XCTAssertTrue(app.buttons["intentionSession.start"].label.contains("Session Started"))
        XCTAssertFalse(app.buttons["intentionSession.start"].isEnabled)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["Mark Read complete"].waitForExistence(timeout: 10), "A timer never completes a habit")
    }

    func testPremiumOnboardingAtLargestTextCanSkipWithoutPermissionPrompts() {
        let app = launch(onboarding: true, largestText: true)
        XCTAssertTrue(app.staticTexts["onboarding.brandName"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["onboarding.continue"].isHittable)
        XCTAssertGreaterThanOrEqual(app.buttons["onboarding.continue"].frame.height, 44)
        capture("Luminous onboarding welcome at largest text")
        tap(app.buttons["onboarding.continue"])
        for step in 0..<4 {
            XCTAssertFalse(XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch.exists, "Optional setup cannot trigger a permission prompt at step \(step)")
            tap(app.buttons["onboarding.skip"])
        }
        XCTAssertTrue(app.buttons["onboarding.continue"].label.contains("Start My Day"))
        capture("Luminous onboarding ready at largest text")
        tap(app.buttons["onboarding.continue"])
        XCTAssertTrue(app.buttons["today.addHabitButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.alerts.firstMatch.exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["today.addHabitButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["onboarding.title"].exists)
    }
}
