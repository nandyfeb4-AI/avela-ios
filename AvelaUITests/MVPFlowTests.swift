import XCTest

/// Public user flows only. Each method uses an isolated persistent store;
/// no fixture can reach a real user's data or manufacture a session result.
final class MVPFlowTests: XCTestCase {
    private var storeDirectory: URL!
    private var application: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
        storeDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        application?.terminate()
        application = nil
        try? FileManager.default.removeItem(at: storeDirectory)
    }

    private func launch(onboarding: Bool = false, liveActivity: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["AVELA_UI_TEST_STORE_PATH"] = storeDirectory.appendingPathComponent("MVPFlow.store").path
        if liveActivity { app.launchEnvironment["AVELA_UI_TEST_LIVE_ACTIVITY"] = "1" }
        if onboarding { app.launchEnvironment["AVELA_UI_TEST_ONBOARDING"] = "1" }
        application = app
        app.launch()
        return app
    }

    private func waitAndTap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), file: file, line: line)
        // Lists may instantiate a row before it is actually visible. Bound
        // scrolling instead of treating accessibility existence as visibility.
        for _ in 0..<6 {
            if element.isHittable { break }
            application?.swipeUp()
        }
        XCTAssertTrue(element.isHittable, file: file, line: line)
        element.tap()
    }

    func testCompanionChoiceAndVisibilitySurviveRelaunch() {
        let app = launch()
        waitAndTap(app.buttons["today.addHabitButton"])
        let name = app.textFields["habitForm.nameField"]
        waitAndTap(name)
        name.typeText("Read a chapter")
        waitAndTap(app.buttons["habitForm.saveButton"])
        XCTAssertTrue(app.staticTexts["companion.summary"].waitForExistence(timeout: 10))
        waitAndTap(app.tabBars.buttons["Settings"])
        waitAndTap(app.buttons["settings.companionLink"])
        for animal in ["owl", "fox", "otter"] {
            waitAndTap(app.buttons["companion.select." + animal])
        }
        let preview = XCTAttachment(screenshot: app.screenshot())
        preview.name = "Companion-selection-native"
        preview.lifetime = .keepAlways
        add(preview)
        waitAndTap(app.buttons["companion.savePreferences"])
        waitAndTap(app.tabBars.buttons["Today"])
        let summary = app.staticTexts["companion.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        XCTAssertTrue(summary.label.contains("otter"))
        app.terminate()
        app.launch()
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        XCTAssertTrue(summary.label.contains("otter"))
        waitAndTap(app.tabBars.buttons["Settings"])
        waitAndTap(app.buttons["settings.companionLink"])
        let visibility = app.switches["Show companion"]
        XCTAssertTrue(visibility.waitForExistence(timeout: 10))
        XCTAssertEqual(visibility.value as? String, "1")
        // SwiftUI exposes the entire row as a Switch. Its center is the
        // label; tap the trailing native switch and verify the actual value.
        visibility.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(visibility.value as? String, "0")
        waitAndTap(app.buttons["companion.savePreferences"])
        waitAndTap(app.tabBars.buttons["Today"])
        XCTAssertFalse(summary.exists)
        app.terminate()
        app.launch()
        XCTAssertFalse(summary.exists)
        XCTAssertTrue(app.buttons["today.addHabitButton"].exists)
    }

    func testPrivacyIsAccessibleWithoutPremium() {
        let app = launch()
        waitAndTap(app.tabBars.buttons["Settings"])
        waitAndTap(app.buttons["settings.privacyLink"])
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Your tracking stays local")).firstMatch.exists)
        XCTAssertFalse(app.buttons["premium.subscribeButton"].exists)
    }

    func testOnboardingOptionalStepsCanBeSkippedAndCompletionSurvivesRelaunch() {
        let app = launch(onboarding: true)
        XCTAssertTrue(app.staticTexts["onboarding.title"].waitForExistence(timeout: 10))
        waitAndTap(app.buttons["onboarding.continue"])
        for _ in 0..<4 { waitAndTap(app.buttons["onboarding.skip"]) }
        let finish = app.buttons["onboarding.continue"]
        XCTAssertTrue(finish.waitForExistence(timeout: 10))
        XCTAssertEqual(finish.label, "Start My Day")
        finish.tap()
        XCTAssertTrue(app.buttons["today.addHabitButton"].waitForExistence(timeout: 10))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["today.addHabitButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["onboarding.title"].exists)
    }

    private func createGoal(named name: String, type: String, in app: XCUIApplication) {
        waitAndTap(app.buttons["today.addAttentionGoalButton"])
        let field = app.textFields["attentionGoalForm.nameField"]
        waitAndTap(field)
        field.typeText(name)
        // Hide the keyboard before interacting with the picker below it.
        waitAndTap(app.buttons["attentionGoalForm.typePicker"])
        let typeButton = app.buttons[type]
        if typeButton.waitForExistence(timeout: 3) {
            typeButton.tap()
        } else {
            waitAndTap(app.staticTexts[type])
        }
        waitAndTap(app.buttons["attentionGoalForm.saveButton"])
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 10))
    }

    private func openGoal(named name: String, in app: XCUIApplication) {
        waitAndTap(app.buttons["Open \(name) details"])
        XCTAssertTrue(app.staticTexts["attentionWindow.status"].waitForExistence(timeout: 10))
    }

    func testPhoneFreeLiveActivityIsOptionalAndDoesNotCertifySuccess() throws {
        let app = launch(liveActivity: true)
        createGoal(named: "Island session", type: "Phone-free session", in: app)
        openGoal(named: "Island session", in: app)
        XCTAssertFalse(app.buttons["attentionWindow.showLiveActivity"].exists)
        waitAndTap(app.buttons["attentionWindow.startSession"])
        XCTAssertFalse(app.buttons["attentionWindow.kept"].isEnabled)
        waitAndTap(app.buttons["attentionWindow.showLiveActivity"])
        let message = app.staticTexts["attentionWindow.liveActivityMessage"]
        // The optional section sits below primary check-in controls; its
        // feedback row may need scrolling into the List's instantiated area.
        app.swipeUp()
        XCTAssertTrue(message.waitForExistence(timeout: 10))
        if !message.label.contains("Session shown") {
            app.swipeDown()
            waitAndTap(app.buttons["attentionWindow.interrupted"])
            throw XCTSkip("Native ActivityKit is unavailable on this simulator: \(message.label)")
        }
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(springboard.wait(for: .runningForeground, timeout: 10))
        // SpringBoard running does not imply its Island host has finished rendering.
        _ = springboard.staticTexts["Time remaining"].waitForExistence(timeout: 5)
        let compact = XCTAttachment(screenshot: springboard.screenshot())
        compact.name = "LiveActivity-DynamicIsland-compact"
        compact.lifetime = .keepAlways
        add(compact)
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02)).press(forDuration: 1.5)
        let expanded = XCTAttachment(screenshot: springboard.screenshot())
        expanded.name = "LiveActivity-DynamicIsland-expanded"
        expanded.lifetime = .keepAlways
        add(expanded)
        app.activate()
        app.swipeDown()
        XCTAssertFalse(app.buttons["attentionWindow.kept"].isEnabled)
        waitAndTap(app.buttons["attentionWindow.hideLiveActivity"])
        XCTAssertTrue(message.label.contains("hidden"))
        waitAndTap(app.buttons["attentionWindow.showLiveActivity"])
        app.swipeDown()
        waitAndTap(app.buttons["attentionWindow.interrupted"])
        XCTAssertTrue(app.buttons["attentionWindow.startSession"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["attentionWindow.showLiveActivity"].exists)
    }

    func testActivePhoneFreeSessionSurvivesRelaunchAndCanBeReportedInterrupted() {
        let app = launch()
        createGoal(named: "Phone break", type: "Phone-free session", in: app)
        openGoal(named: "Phone break", in: app)
        waitAndTap(app.buttons["attentionWindow.startSession"])
        let kept = app.buttons["attentionWindow.kept"]
        XCTAssertTrue(kept.waitForExistence(timeout: 10))
        XCTAssertFalse(kept.isEnabled, "A 30-minute target cannot be reported kept immediately")
        XCTAssertTrue(app.buttons["attentionWindow.interrupted"].isEnabled)
        app.terminate()
        app.launch()
        openGoal(named: "Phone break", in: app)
        XCTAssertTrue(app.buttons["attentionWindow.kept"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["attentionWindow.startSession"].exists, "The persisted session must remain active")
        waitAndTap(app.buttons["attentionWindow.interrupted"])
        XCTAssertTrue(app.buttons["attentionWindow.startSession"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Interrupted")).firstMatch.exists)
        app.terminate()
        app.launch()
        openGoal(named: "Phone break", in: app)
        XCTAssertTrue(app.buttons["attentionWindow.startSession"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Interrupted")).firstMatch.exists)
    }

    func testProtectedWindowStartsUnknownWithoutImpliedMeasurementOrUsageChips() {
        let app = launch()
        createGoal(named: "Morning news", type: "Protected window", in: app)
        XCTAssertFalse(app.buttons["Log usage for Morning news"].exists)
        openGoal(named: "Morning news", in: app)
        let status = app.staticTexts["attentionWindow.status"]
        XCTAssertTrue(status.label.contains("Not reported yet"))
        XCTAssertFalse(status.label.contains("Healthy"))
        XCTAssertFalse(status.label.contains("On track"))
        XCTAssertFalse(app.textFields["attentionUsageForm.amountField"].exists)
    }

    func testSettingsPremiumHasRestoreAndCanReturnToFreeTracking() {
        let app = launch()
        waitAndTap(app.tabBars.buttons["Settings"])
        waitAndTap(app.buttons["settings.premiumButton"])
        XCTAssertTrue(app.buttons["premium.restoreButton"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["Avela Premium"].exists)
        waitAndTap(app.buttons["premium.closeButton"])
        waitAndTap(app.tabBars.buttons["Today"])
        XCTAssertTrue(app.buttons["today.addHabitButton"].waitForExistence(timeout: 10))
    }
    func testHabitSkipSurvivesRelaunchAndCanBeUndone() {
        let app = launch()
        waitAndTap(app.buttons["today.addHabitButton"])
        let field = app.textFields["habitForm.nameField"]
        waitAndTap(field)
        field.typeText("Morning walk")
        waitAndTap(app.buttons["habitForm.saveButton"])
        waitAndTap(app.buttons["Open Morning walk details"])
        waitAndTap(app.buttons["habitDetail.skipButton"])
        XCTAssertEqual(app.buttons["habitDetail.skipButton"].label, "Undo Today's Skip")
        app.terminate()
        app.launch()
        waitAndTap(app.buttons["Open Morning walk details"])
        let undo = app.buttons["habitDetail.skipButton"]
        XCTAssertTrue(undo.waitForExistence(timeout: 10))
        XCTAssertEqual(undo.label, "Undo Today's Skip")
        undo.tap()
        XCTAssertEqual(app.buttons["habitDetail.skipButton"].label, "Skip Today")
    }

}
