import XCTest

private extension XCUIElement {
    /// Deletes whatever text is already in the field (e.g. a form's prefilled
    /// default or a correction form's existing amount) before typing `text`,
    /// since `typeText` alone appends.
    func clearAndTypeText(_ text: String) {
        guard let existingValue = value as? String, !existingValue.isEmpty else {
            typeText(text)
            return
        }
        let deleteKeys = String(repeating: XCUIKeyboardKey.delete.rawValue, count: existingValue.count)
        typeText(deleteKeys)
        typeText(text)
    }
}

final class AvelaUITests: XCTestCase {
    private var storeDirectory: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        // Each test method gets its own empty, isolated disk store so "empty on
        // first launch" and "survives relaunch" assertions never depend on (or
        // leak into) data left behind by other tests or prior runs.
        storeDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: storeDirectory)
    }

    /// `seedFixture`, when provided, must name one of `DebugFixtures.Fixture`'s
    /// raw values (not referenced by type here, since the UI test target runs
    /// the app as a separate process rather than linking against it) — it
    /// asks the DEBUG-only, store-path-isolated seeding hook in `AvelaApp` to
    /// populate a deterministic past week before the app's first frame, for
    /// tests that need to see populated Insights states no amount of "today"
    /// interaction could otherwise reach.
    /// `contentSizeCategory`, when provided, must be one of the
    /// `UICTContentSizeCategory...` constants (e.g.
    /// `"UICTContentSizeCategoryAccessibilityXXXL"`) and forces that Dynamic
    /// Type size at launch via the standard `-UIPreferredContentSizeCategoryName`
    /// launch argument, which does reliably work on this toolchain.
    ///
    /// There is deliberately no equivalent per-launch light/dark override
    /// here: `-UIUserInterfaceStyle Dark` as a launch argument was tried and
    /// measured not to take effect on this Xcode 27/iOS 27 toolchain (the
    /// app still rendered light). Appearance here is controlled at the
    /// *simulator* level instead — `xcrun simctl ui <device> appearance
    /// dark|light` — which does work, but must be set before the test
    /// process launches, from outside the test target (XCUITest code cannot
    /// shell out to `simctl`). See `testVisualAppearanceInDarkMode`'s doc
    /// comment for the exact invocation this requires.
    private func launchApp(
        seedFixture: String? = nil,
        contentSizeCategory: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["AVELA_UI_TEST_STORE_PATH"] = storeDirectory.appendingPathComponent("UITest.store").path
        if let seedFixture {
            app.launchEnvironment["AVELA_UI_TEST_SEED_FIXTURE"] = seedFixture
        }
        if let contentSizeCategory {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSizeCategory]
        }
        app.launch()
        return app
    }

    /// Attaches a screenshot as test evidence, named for later identification
    /// in the result bundle (e.g. for a visual audit) — kept even when the
    /// test passes.
    private func attachScreenshot(_ name: String, of app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func createHabit(
        named name: String, in app: XCUIApplication, scheduleButtonTitle: String? = nil, polarityButtonTitle: String? = nil
    ) {
        // The toolbar "+" always exists, unlike the empty-state button, which
        // disappears once the first habit exists — needed for tests that
        // create more than one habit.
        app.buttons["today.addHabitButton"].tap()
        let nameField = app.textFields["habitForm.nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)
        if let polarityButtonTitle {
            app.segmentedControls["habitForm.polarityPicker"].buttons[polarityButtonTitle].tap()
        }
        if let scheduleButtonTitle {
            app.segmentedControls["habitForm.scheduleTypePicker"].buttons[scheduleButtonTitle].tap()
        }
        app.buttons["habitForm.saveButton"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    }

    private func openDetail(for name: String, in app: XCUIApplication) {
        app.buttons["Open \(name) details"].tap()
        XCTAssertTrue(app.staticTexts["habitDetail.name"].waitForExistence(timeout: 5))
    }

    /// SwiftUI List materializes rows lazily; a lower detail action may not
    /// exist in the accessibility tree until scrolled into view. Keep scroll
    /// attempts bounded and wait for a hittable target before tapping it.
    private func revealDetailElement(_ element: XCUIElement, in app: XCUIApplication) -> XCUIElement {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return element }
            // A presented Form can coexist with Today's underlying List.
            // Scroll the frontmost hittable container, above the keyboard;
            // the default full-frame swipe can land on keyboard keys at AX3.
            let container = app.collectionViews.allElementsBoundByIndex.last(where: { $0.isHittable })
                ?? app.tables.allElementsBoundByIndex.last(where: { $0.isHittable })
                ?? app
            let keyboard = app.keyboards.firstMatch
            if keyboard.exists {
                let bottom = min(container.frame.maxY, keyboard.frame.minY - 60) - 24
                let top = max(container.frame.minY + 60, bottom - 280)
                let origin = app.coordinate(withNormalizedOffset: .zero)
                origin.withOffset(CGVector(dx: container.frame.midX, dy: bottom))
                    .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: container.frame.midX, dy: top)))
            } else {
                container.swipeUp()
            }
        }
        XCTAssertTrue(element.waitForExistence(timeout: 3), "Detail action must exist after bounded scrolling")
        XCTAssertTrue(element.isHittable, "Detail action must be reachable before tapping")
        return element
    }

    private func tapArchiveButton(in app: XCUIApplication) {
        revealDetailElement(app.buttons["habitDetail.archiveButton"], in: app).tap()
    }

    private func completeHabit(named name: String, in app: XCUIApplication) {
        let completeButton = app.buttons["Mark \(name) complete"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))
        completeButton.tap()
        XCTAssertTrue(app.buttons["Undo completion for \(name)"].waitForExistence(timeout: 5))
    }

    /// A completed habit's row moves into the collapsible "Done · N" group a
    /// short while after completing (Tidewater Balance's deferred regroup —
    /// see `TodayView.scheduleCollapse`), and any navigation away from and
    /// back to Today reflects that final grouping immediately. Call this
    /// before looking for a completed habit's row or text whenever the test
    /// has done anything — navigated, waited, or simply isn't checking
    /// immediately after the tap that completed it.
    ///
    /// Waits for `name`'s own row to actually exist after tapping the
    /// toggle, rather than returning the instant the tap is sent: tapping
    /// "Open {name} details" immediately after an un-synchronized toggle tap
    /// raced the expand animation — the next tap could land before the row
    /// (and the `NavigationLink` it carries) had actually attached to the
    /// tree, producing a detail screen stuck on its loading spinner. That
    /// race, not a product bug, was the cause of several UI tests failing
    /// only when the deferred Done group needed expanding first.
    private func expandDoneGroupIfNeeded(for name: String, in app: XCUIApplication) {
        let openButton = app.buttons["Open \(name) details"]
        if openButton.exists { return }
        let toggle = app.buttons["today.doneToggle"]
        guard toggle.waitForExistence(timeout: 5) else { return }
        if toggle.label.contains("collapsed") {
            toggle.tap()
        }
        XCTAssertTrue(openButton.waitForExistence(timeout: 5), "expanding Done must reveal \(name)'s row")
    }

    private func createAttentionGoal(named name: String, targetMinutes: String = "30", in app: XCUIApplication) {
        app.buttons["today.addAttentionGoalButton"].tap()
        let nameField = app.textFields["attentionGoalForm.nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)
        let targetField = app.textFields["attentionGoalForm.targetField"]
        // At accessibility text sizes, the goal-type picker and keyboard
        // put the duration row below the Form's lazy visible region.
        revealDetailElement(targetField, in: app).tap()
        targetField.clearAndTypeText(targetMinutes)
        app.buttons["attentionGoalForm.saveButton"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    }

    private func openAttentionGoalDetail(for name: String, in app: XCUIApplication) {
        app.buttons["Open \(name) details"].tap()
        XCTAssertTrue(app.staticTexts["attentionGoalDetail.name"].waitForExistence(timeout: 5))
    }

    /// An entry row renders as a `Button`, which may merge its nested `Text`
    /// children into a single accessibility element rather than exposing them
    /// as separate `staticTexts` — matching by button label (which still
    /// contains the amount text either way) is robust to that, unlike
    /// querying `app.staticTexts` directly.
    private func attentionEntryRow(amountText: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", amountText)).firstMatch
    }

    func testShellNavigationAndRelaunch() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        for destination in ["Insights", "History", "Settings", "Today"] {
            app.tabBars.buttons[destination].tap()
            switch destination {
            case "Today":
                XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 5))
            case "Insights":
                XCTAssertTrue(app.staticTexts["insights.emptyState.title"].waitForExistence(timeout: 5))
            case "History":
                XCTAssertTrue(app.staticTexts["history.emptyState.title"].waitForExistence(timeout: 5))
            case "Settings":
                XCTAssertTrue(revealDetailElement(app.buttons["settings.archivedHabitsLink"], in: app).isHittable)
            default:
                XCTAssertTrue(
                    app.staticTexts["placeholder.\(destination.lowercased())"].waitForExistence(timeout: 5)
                )
            }
        }

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))
    }

    func testCreatingADailyHabitShowsItInTheTodayList() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        createHabit(named: "Read", in: app)
    }

    func testCompletingAndUndoingAHabit() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        createHabit(named: "Walk", in: app)

        let completeButton = app.buttons["Mark Walk complete"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))
        completeButton.tap()

        let undoButton = app.buttons["Undo completion for Walk"]
        XCTAssertTrue(undoButton.waitForExistence(timeout: 5), "completing must immediately offer undo")
        undoButton.tap()

        XCTAssertTrue(app.buttons["Mark Walk complete"].waitForExistence(timeout: 5), "undo must restore the incomplete state")
    }

    func testFlexibleWeeklyHabitShowsProgressTowardTarget() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        createHabit(named: "Swim", in: app, scheduleButtonTitle: "Times per Week")

        // Default target is 3 times per week; before any completion, progress reads 0/3.
        XCTAssertTrue(app.staticTexts["3x / week — 0/3 this week"].waitForExistence(timeout: 5))

        app.buttons["Mark Swim complete"].tap()
        XCTAssertTrue(app.staticTexts["3x / week — 1/3 this week"].waitForExistence(timeout: 5))
    }

    func testPersistedHabitsSurviveRelaunch() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        createHabit(named: "Meditate", in: app)

        app.terminate()
        app.launch()

        XCTAssertTrue(app.staticTexts["Meditate"].waitForExistence(timeout: 10), "habits must persist across a relaunch")
    }

    func testOpeningHabitDetailDoesNotTriggerCompletion() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        createHabit(named: "Walk", in: app)
        openDetail(for: "Walk", in: app)

        XCTAssertTrue(app.staticTexts["Walk"].exists)
        let progressValue = app.staticTexts["habitDetail.progress"]
        XCTAssertTrue(progressValue.waitForExistence(timeout: 5))
        XCTAssertEqual(progressValue.label, "Not completed yet", "opening detail must not log a completion")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Mark Walk complete"].waitForExistence(timeout: 5), "the habit must still be incomplete back on Today")
    }

    func testEditingHabitFromDetailUpdatesTodayWithoutLosingPriorCompletion() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        createHabit(named: "Walk", in: app)
        app.buttons["Mark Walk complete"].tap()
        XCTAssertTrue(app.buttons["Undo completion for Walk"].waitForExistence(timeout: 5))

        openDetail(for: "Walk", in: app)
        app.buttons["habitDetail.editButton"].tap()
        XCTAssertTrue(app.textFields["habitForm.nameField"].waitForExistence(timeout: 5))
        app.segmentedControls["habitForm.scheduleTypePicker"].buttons["Times per Week"].tap()
        app.buttons["habitForm.saveButton"].tap()

        // Today's completion, logged before the edit, must already count
        // toward the newly-switched weekly target without re-logging anything.
        let progressValue = app.staticTexts["habitDetail.progress"]
        XCTAssertTrue(progressValue.waitForExistence(timeout: 5))
        XCTAssertEqual(progressValue.label, "1/3")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        // Walk was already completed before this round trip to detail, so by
        // the time Today reloads it is grouped into "Done" (Tidewater
        // Balance's deferred regroup has long since settled by now) — expand
        // it to see the row's updated context text.
        expandDoneGroupIfNeeded(for: "Walk", in: app)
        XCTAssertTrue(app.staticTexts["3x / week — 1/3 this week"].waitForExistence(timeout: 5))
    }

    func testArchivingFromDetailRemovesHabitFromToday() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        createHabit(named: "Walk", in: app)
        openDetail(for: "Walk", in: app)

        tapArchiveButton(in: app)
        app.buttons["Archive"].tap()

        // Archiving dismisses back to Today, which must no longer list it.
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 5))
    }

    func testReactivatingFromSettingsReturnsHabitToTodayAcrossRepeatedCycles() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        createHabit(named: "Walk", in: app)

        for cycle in 1...2 {
            openDetail(for: "Walk", in: app)
            tapArchiveButton(in: app)
            app.buttons["Archive"].tap()
            XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 5), "cycle \(cycle): archiving must remove it from Today")

            app.tabBars.buttons["Settings"].tap()
            revealDetailElement(app.buttons["settings.archivedHabitsLink"], in: app).tap()
            let reactivateButton = app.buttons["Reactivate Walk"]
            XCTAssertTrue(reactivateButton.waitForExistence(timeout: 5), "cycle \(cycle): the archived habit must appear in Settings")
            reactivateButton.tap()
            XCTAssertTrue(app.staticTexts["archivedHabits.emptyState.title"].waitForExistence(timeout: 5))

            app.navigationBars.buttons.element(boundBy: 0).tap() // back to Settings root
            app.tabBars.buttons["Today"].tap()
            XCTAssertTrue(app.staticTexts["Walk"].waitForExistence(timeout: 5), "cycle \(cycle): reactivating must return it to Today")
        }
    }

    func testArchivedHabitSurvivesRelaunchAndCanStillBeReactivated() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        createHabit(named: "Walk", in: app)
        openDetail(for: "Walk", in: app)
        tapArchiveButton(in: app)
        app.buttons["Archive"].tap()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()

        app.tabBars.buttons["Settings"].tap()
        revealDetailElement(app.buttons["settings.archivedHabitsLink"], in: app).tap()
        let reactivateButton = app.buttons["Reactivate Walk"]
        XCTAssertTrue(reactivateButton.waitForExistence(timeout: 10), "the archive must survive a relaunch")
        reactivateButton.tap()

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.staticTexts["Walk"].waitForExistence(timeout: 5), "reactivation after relaunch must return it to Today")
    }

    func testHistoryShowsEmptyStateThenACompletionAfterSwitchingTabs() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["history.emptyState.title"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Today"].tap()
        createHabit(named: "Walk", in: app)
        completeHabit(named: "Walk", in: app)

        // History has no mutation path of its own; switching back to it is
        // what must pick up Today's completion.
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Walk"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Completed"].waitForExistence(timeout: 5))
    }

    func testHistoryHabitFilterShowsOnlyTheSelectedHabit() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        createHabit(named: "Walk", in: app)
        completeHabit(named: "Walk", in: app)
        createHabit(named: "Read", in: app)
        completeHabit(named: "Read", in: app)

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Walk"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Read"].waitForExistence(timeout: 5))

        app.buttons["history.habitFilter"].tap()
        app.buttons["Walk"].tap()

        XCTAssertTrue(app.staticTexts["Walk"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Read"].exists, "filtering to Walk must hide Read's records")
    }

    func testViewingHistoryFromHabitDetailFiltersToThatHabit() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        createHabit(named: "Walk", in: app)
        completeHabit(named: "Walk", in: app)
        createHabit(named: "Read", in: app)
        completeHabit(named: "Read", in: app)

        // Both are done and may already be grouped into the collapsed "Done"
        // group (Tidewater Balance's deferred regroup) by now.
        expandDoneGroupIfNeeded(for: "Walk", in: app)

        openDetail(for: "Walk", in: app)
        revealDetailElement(app.buttons["habitDetail.viewHistoryButton"], in: app).tap()

        XCTAssertTrue(app.staticTexts["Walk"].waitForExistence(timeout: 5), "must land on History already filtered to Walk")
        XCTAssertFalse(app.staticTexts["Read"].exists, "Read must be hidden by the Walk filter")
    }

    func testHistoryRecordsSurviveRelaunch() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        createHabit(named: "Walk", in: app)
        completeHabit(named: "Walk", in: app)

        app.terminate()
        app.launch()

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Walk"].waitForExistence(timeout: 10), "history must survive a relaunch")
        XCTAssertTrue(app.staticTexts["Completed"].waitForExistence(timeout: 5))
    }

    func testInsightsShowsEmptyStateThenInsufficientDataAfterCreatingAHabit() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.staticTexts["insights.emptyState.title"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Today"].tap()
        createHabit(named: "Walk", in: app)

        // A habit created "today" has no resolved activity in any already-
        // completed week, so Insights must read as "not enough data," never a
        // fabricated 0%.
        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.staticTexts["insights.weekRangeLabel"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["insights.insufficientData.title"].waitForExistence(timeout: 5))
    }

    func testInsightsWeekNavigationMovesBetweenCompletedWeeksAndBack() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        createHabit(named: "Walk", in: app)

        app.tabBars.buttons["Insights"].tap()
        let rangeLabel = app.staticTexts["insights.weekRangeLabel"]
        XCTAssertTrue(rangeLabel.waitForExistence(timeout: 5))
        let defaultRangeText = rangeLabel.label

        let previousButton = app.buttons["insights.previousWeekButton"]
        let nextButton = app.buttons["insights.nextWeekButton"]
        XCTAssertTrue(previousButton.waitForExistence(timeout: 5))
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        XCTAssertFalse(nextButton.isEnabled, "the default view is already the most recent completed week")

        previousButton.tap()
        XCTAssertNotEqual(rangeLabel.label, defaultRangeText, "moving to an earlier week must change the displayed range")
        XCTAssertTrue(nextButton.isEnabled)

        nextButton.tap()
        XCTAssertEqual(rangeLabel.label, defaultRangeText, "moving forward again must return to the original week")
        XCTAssertFalse(nextButton.isEnabled, "back at the most recent completed week, next must disable again")
    }

    /// Reproduces the audit's archive-confirmation screenshot properly: that
    /// capture was taken by an external, unsynchronized screenshot poller
    /// with no knowledge of XCUITest's own element tree, so it could not
    /// distinguish "the dialog is still presenting" from "the dialog is
    /// fully settled." This test instead waits for the confirmation
    /// dialog's own elements to exist before asserting anything about them,
    /// then exercises cancellation end to end.
    func testArchiveConfirmationCanBeCancelledLeavingTheHabitActive() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        createHabit(named: "Walk", in: app)
        openDetail(for: "Walk", in: app)
        tapArchiveButton(in: app)

        // Wait for the dialog itself — querying immediately after tap() can
        // race its presentation animation, which is exactly the ambiguity
        // the unsynchronized screenshot in the audit could not rule out.
        let archiveConfirmButton = app.buttons["Archive"]
        XCTAssertTrue(archiveConfirmButton.waitForExistence(timeout: 5), "the confirmation dialog's destructive action must be presented")

        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5), "a Cancel action must be presented alongside Archive")

        // Evidence of the dialog's true, settled state — once both actions
        // are confirmed present in the accessibility tree — for the audit.
        attachScreenshot("ArchiveConfirmationDialog-Settled", of: app)

        cancelButton.tap()

        // Cancelling must leave the habit active: still on the detail
        // screen, not showing the "This habit is archived" banner.
        XCTAssertTrue(app.buttons["habitDetail.editButton"].waitForExistence(timeout: 5), "cancelling must leave the still-active detail screen usable")
        XCTAssertFalse(app.staticTexts["This habit is archived."].exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Mark Walk complete"].waitForExistence(timeout: 5), "the habit must still be active on Today after cancelling")

        // Unchanged archive history: no period was ever opened, so Settings'
        // Archived Habits list must still be empty.
        app.tabBars.buttons["Settings"].tap()
        revealDetailElement(app.buttons["settings.archivedHabitsLink"], in: app).tap()
        XCTAssertTrue(app.staticTexts["archivedHabits.emptyState.title"].waitForExistence(timeout: 5), "cancelling must not record any archive period")
    }

    // MARK: - Populated Insights (DEBUG fixtures)

    func testInsightsShowsPopulatedSummaryWithStrongestAndNeedsAttention() {
        let app = launchApp(seedFixture: "populated")
        app.tabBars.buttons["Insights"].tap()

        XCTAssertTrue(app.staticTexts["insights.overallConsistency"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["insights.strongestHabit"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["insights.needsAttention"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["insights.strongestHabit"].label.contains("Read"), true)
        XCTAssertEqual(app.staticTexts["insights.needsAttention"].label.contains("Meditate"), true)

        attachScreenshot("InsightsPopulated", of: app)
    }

    func testInsightsShowsBalancedSummaryForIdenticalResults() {
        let app = launchApp(seedFixture: "balancedIdentical")
        app.tabBars.buttons["Insights"].tap()

        XCTAssertTrue(app.staticTexts["insights.overallConsistency"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["insights.balancedSummary"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["insights.strongestHabit"].exists, "a balanced week must not single out a strongest habit")
        XCTAssertFalse(app.staticTexts["insights.needsAttention"].exists, "a balanced week must not single out a habit needing attention")

        attachScreenshot("InsightsBalanced", of: app)
    }

    func testInsightsListsAllTiedHabitsForStrongestAndNeedsAttention() {
        let app = launchApp(seedFixture: "tiedExtremes")
        app.tabBars.buttons["Insights"].tap()

        let strongest = app.staticTexts["insights.strongestHabit"]
        let needsAttention = app.staticTexts["insights.needsAttention"]
        XCTAssertTrue(strongest.waitForExistence(timeout: 10))
        XCTAssertTrue(needsAttention.waitForExistence(timeout: 5))
        XCTAssertTrue(strongest.label.contains("Run") && strongest.label.contains("Swim"), "both tied strongest habits must be named")
        XCTAssertTrue(needsAttention.label.contains("Floss") && needsAttention.label.contains("Journal"), "both tied needs-attention habits must be named")

        attachScreenshot("InsightsTiedExtremes", of: app)
    }

    func testInsightsShowsAValidTrendForAComparableHabit() {
        let app = launchApp(seedFixture: "validTrend")
        app.tabBars.buttons["Insights"].tap()

        let trend = app.staticTexts["insights.trend"]
        XCTAssertTrue(trend.waitForExistence(timeout: 10))
        XCTAssertTrue(trend.label.contains("percentage points"), "a comparable habit's trend must be expressed in percentage points")

        attachScreenshot("InsightsValidTrend", of: app)
    }

    func testInsightsShowsNotEnoughComparableDataWhenScheduleChangedBetweenWeeks() {
        let app = launchApp(seedFixture: "noComparableData")
        app.tabBars.buttons["Insights"].tap()

        XCTAssertTrue(app.staticTexts["insights.overallConsistency"].waitForExistence(timeout: 10), "the week's own summary must still show despite no valid comparison")
        let trend = app.staticTexts["insights.trend"]
        XCTAssertTrue(trend.waitForExistence(timeout: 5))
        XCTAssertEqual(trend.label, "Not enough comparable data.")

        attachScreenshot("InsightsNotEnoughComparableData", of: app)
    }

    // MARK: - Polarity-aware wording (F2)

    func testTodayAndDetailUsePolarityAwareWordingForAvoidanceHabits() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        createHabit(named: "Late Snacking", in: app, polarityButtonTitle: "Cut Down")

        // "Log success," never "Mark avoided" — the latter would assume
        // total abstinence, which isn't true of every Cut Down habit.
        let logButton = app.buttons["Log success for Late Snacking"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 5))

        openDetail(for: "Late Snacking", in: app)
        XCTAssertTrue(app.staticTexts["habitDetail.progress"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["habitDetail.progress"].label, "Not logged yet")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        logButton.tap()
        XCTAssertTrue(app.buttons["Undo success for Late Snacking"].waitForExistence(timeout: 5))

        // Now logged, and may already be grouped into the collapsed "Done"
        // group (Tidewater Balance's deferred regroup) by the time this
        // second detail visit happens.
        expandDoneGroupIfNeeded(for: "Late Snacking", in: app)
        openDetail(for: "Late Snacking", in: app)
        XCTAssertTrue(app.staticTexts["habitDetail.progress"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["habitDetail.progress"].label, "Logged")
    }

    // MARK: - Icon picker touch targets (F5)

    func testIconPickerTouchTargetsAreAtLeast44Points() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        app.buttons["today.addHabitButton"].tap()
        let iconButton = app.buttons["Icon book.fill"]
        XCTAssertTrue(iconButton.waitForExistence(timeout: 5))
        // Rounded to the nearest point before comparing: SwiftUI's layout
        // engine can report a frame like 43.99999999999994 for a target
        // whose intended and visually rendered size is exactly 44 — floating-
        // point layout noise, not an actually undersized element.
        XCTAssertGreaterThanOrEqual(iconButton.frame.width.rounded(), 44, "icon picker touch targets must meet the 44pt minimum")
        XCTAssertGreaterThanOrEqual(iconButton.frame.height.rounded(), 44, "icon picker touch targets must meet the 44pt minimum")
    }

    func testIconPickerTouchTargetsRemainAtLeast44PointsAtLargeDynamicType() {
        let app = launchApp(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        app.buttons["today.addHabitButton"].tap()
        let iconButton = app.buttons["Icon book.fill"]
        XCTAssertTrue(iconButton.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(iconButton.frame.width.rounded(), 44, "the adaptive grid must keep targets at the 44pt minimum even at the largest Dynamic Type size")
        XCTAssertGreaterThanOrEqual(iconButton.frame.height.rounded(), 44)

        attachScreenshot("HabitForm-AccessibilityXXXL", of: app)
    }

    // MARK: - Visual evidence: light/dark appearance and icon tint consistency (F12)

    /// Runs under whatever appearance the simulator is currently set to.
    /// Defaults to light (the simulator's own default), so this passes
    /// unmodified in a normal full-suite run.
    func testVisualAppearanceInLightMode() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        createHabit(named: "Walk", in: app)
        completeHabit(named: "Walk", in: app)
        attachScreenshot("Today-Light", of: app)

        expandDoneGroupIfNeeded(for: "Walk", in: app)
        openDetail(for: "Walk", in: app)
        attachScreenshot("Detail-Light", of: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Walk"].waitForExistence(timeout: 5))
        attachScreenshot("History-Light", of: app)
    }

    /// Also runs under whatever appearance the simulator is currently set
    /// to — identical body to the light-mode test above by design, so the
    /// same flow is exercised either way. Forcing *this specific test* into
    /// dark mode regardless of the simulator's current setting is not
    /// possible from inside the test target: a `-UIUserInterfaceStyle Dark`
    /// launch argument was tried and measured to have no effect on this
    /// Xcode 27/iOS 27 toolchain (confirmed by screenshot: the app still
    /// rendered light), and XCUITest code cannot shell out to `simctl`. To
    /// actually capture this test's evidence in dark mode, set the
    /// simulator's appearance *before* invoking `xcodebuild test`:
    /// `xcrun simctl ui <device-id> appearance dark` (and `... appearance
    /// light` afterward to restore it) — see `docs/SETUP.md` for the
    /// verified, working invocation and resulting screenshots.
    func testVisualAppearanceInDarkMode() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        createHabit(named: "Walk", in: app)
        completeHabit(named: "Walk", in: app)
        attachScreenshot("Today-Dark", of: app)

        expandDoneGroupIfNeeded(for: "Walk", in: app)
        openDetail(for: "Walk", in: app)
        attachScreenshot("Detail-Dark", of: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Walk"].waitForExistence(timeout: 5))
        attachScreenshot("History-Dark", of: app)
    }

    /// Icon tint *color* itself isn't queryable through XCUITest's
    /// accessibility tree (there is no API for a rendered pixel/tint color on
    /// an `XCUIElement`), so this can only assert the behavioral side — an
    /// archived habit's text badge, the authoritative archived signal per
    /// F12's fix, is present regardless of icon color — and otherwise relies
    /// on the attached screenshot for visual confirmation that the active
    /// ("Read") and archived ("Walk") icons are tinted differently.
    func testArchivedAndActiveHabitIconsAppearTogetherInHistoryForVisualTintComparison() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        createHabit(named: "Walk", in: app)
        completeHabit(named: "Walk", in: app)
        createHabit(named: "Read", in: app)
        completeHabit(named: "Read", in: app)

        // Both habits are now done and may already have settled into the
        // collapsed "Done" group (Tidewater Balance's deferred regroup) by
        // the time the interactions above finish — expand it once so both
        // rows stay reachable through the rest of this test, since the
        // expanded/collapsed state persists on Today's single, retained view
        // instance across the detail round trip below.
        expandDoneGroupIfNeeded(for: "Walk", in: app)

        openDetail(for: "Walk", in: app)
        tapArchiveButton(in: app)
        app.buttons["Archive"].tap()
        // Archiving dismisses back to Today automatically.
        XCTAssertTrue(app.staticTexts["Read"].waitForExistence(timeout: 5), "Read must remain on Today")

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Walk"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Read"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["Archived"].waitForExistence(timeout: 5),
            "the archived habit must still carry its text badge — the authoritative archived signal, not icon color alone"
        )

        attachScreenshot("History-ArchivedVsActiveIconTint", of: app)
    }

    // MARK: - Vivid Tidewater visual evidence (populated Balance layout)

    /// A richer scene than the plain light/dark tests above: two habits (one
    /// still to do, one done and settled into the collapsed Done group) plus
    /// an attention goal with partial usage logged — so the screenshot
    /// actually shows the pillar strip, the Done toggle, and a real
    /// Attention row together, not just a single empty-ish habit. Runs under
    /// whatever appearance the simulator is currently set to, matching the
    /// existing light/dark tests' documented convention.
    private func buildPopulatedTidewaterBalanceScene(in app: XCUIApplication) {
        createHabit(named: "Walk", in: app)
        completeHabit(named: "Walk", in: app)
        createHabit(named: "Read", in: app)
        createAttentionGoal(named: "Instagram", targetMinutes: "30", in: app)
        app.buttons["Log 15 minutes for Instagram"].tap()
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "15 min of 30 min")).firstMatch.waitForExistence(timeout: 5)
        )
        // Let the toast clear and the Done group settle so the screenshot
        // shows Today's steady state, not a mid-transition frame.
        expandDoneGroupIfNeeded(for: "Walk", in: app)
    }

    func testTidewaterBalancePopulatedScreenshot() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))
        buildPopulatedTidewaterBalanceScene(in: app)
        attachScreenshot("Today-TidewaterBalance-Populated", of: app)
    }

    /// Identical body to the populated test above — the simulator's
    /// appearance must be toggled externally before this runs, for the same
    /// documented reason `testVisualAppearanceInDarkMode` already explains:
    /// `-UIUserInterfaceStyle Dark` has no effect on this toolchain, and
    /// XCUITest code cannot shell out to `simctl` itself. See docs/SETUP.md
    /// for the exact `xcrun simctl ui <device> appearance dark` invocation
    /// used to capture this test's dark-mode evidence.
    func testTidewaterBalancePopulatedScreenshotDarkMode() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))
        buildPopulatedTidewaterBalanceScene(in: app)
        attachScreenshot("Today-TidewaterBalance-Populated-Dark", of: app)
    }

    /// The pillar strip and each attention row's chips must stack vertically,
    /// not force two columns into less width, at the largest accessibility
    /// Dynamic Type size (COMPONENT_SPEC §6).
    func testTidewaterBalanceAccessibilityDynamicTypeScreenshot() {
        let app = launchApp(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))
        buildPopulatedTidewaterBalanceScene(in: app)
        attachScreenshot("Today-TidewaterBalance-AccessibilityXXXL", of: app)
    }

    // MARK: - Attention goals

    func testCreatingAnAttentionGoalShowsItInTheTodayAttentionSection() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        createAttentionGoal(named: "Instagram", in: app)

        XCTAssertTrue(app.staticTexts["Instagram"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["No usage logged yet today"].waitForExistence(timeout: 5),
            "a freshly created goal must not read as a verified zero or an automatic 'on track' status"
        )
    }

    func testLoggingUsageFromTodayUpdatesStatusImmediately() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))
        createAttentionGoal(named: "Instagram", targetMinutes: "30", in: app)

        app.buttons["Log usage for Instagram"].tap()
        let amountField = app.textFields["attentionUsageForm.amountField"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText("10")
        app.buttons["attentionUsageForm.saveButton"].tap()

        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "10 min of 30 min")).firstMatch
                .waitForExistence(timeout: 5),
            "logging usage must update Today's status immediately"
        )
    }

    func testAttentionGoalDetailShowsLoggedEntryAndAllowsCorrection() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))
        createAttentionGoal(named: "Instagram", targetMinutes: "30", in: app)

        openAttentionGoalDetail(for: "Instagram", in: app)
        app.buttons["attentionGoalDetail.logUsageButton"].tap()
        var amountField = app.textFields["attentionUsageForm.amountField"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText("10")
        app.buttons["attentionUsageForm.saveButton"].tap()

        let tenMinuteEntry = attentionEntryRow(amountText: "10 min", in: app)
        XCTAssertTrue(tenMinuteEntry.waitForExistence(timeout: 5))

        // Tapping the entry opens the correction form, prefilled with its amount.
        tenMinuteEntry.tap()
        amountField = app.textFields["attentionUsageForm.amountField"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.clearAndTypeText("20")
        app.buttons["attentionUsageForm.saveButton"].tap()

        XCTAssertTrue(attentionEntryRow(amountText: "20 min", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(attentionEntryRow(amountText: "10 min", in: app).exists, "correcting must replace the entry's amount, not add a second one")
    }

    func testDeletingAnAttentionUsageEntryRemovesItAndRestoresMissingDataStatus() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))
        createAttentionGoal(named: "Instagram", targetMinutes: "30", in: app)

        openAttentionGoalDetail(for: "Instagram", in: app)
        app.buttons["attentionGoalDetail.logUsageButton"].tap()
        let amountField = app.textFields["attentionUsageForm.amountField"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText("10")
        app.buttons["attentionUsageForm.saveButton"].tap()
        let tenMinuteEntry = attentionEntryRow(amountText: "10 min", in: app)
        XCTAssertTrue(tenMinuteEntry.waitForExistence(timeout: 5))

        tenMinuteEntry.swipeLeft()
        app.buttons["Delete"].tap()

        XCTAssertFalse(attentionEntryRow(amountText: "10 min", in: app).exists)
        XCTAssertTrue(
            app.staticTexts["No usage logged yet today"].waitForExistence(timeout: 5),
            "deleting the only entry must return to the missing-data status, not a measured zero"
        )
    }

    func testAttentionGoalsAndUsagePersistAcrossRelaunch() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))
        createAttentionGoal(named: "Instagram", targetMinutes: "30", in: app)
        app.buttons["Log usage for Instagram"].tap()
        let amountField = app.textFields["attentionUsageForm.amountField"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText("10")
        app.buttons["attentionUsageForm.saveButton"].tap()

        app.terminate()
        app.launch()

        XCTAssertTrue(app.staticTexts["Instagram"].waitForExistence(timeout: 10))
        openAttentionGoalDetail(for: "Instagram", in: app)
        XCTAssertTrue(attentionEntryRow(amountText: "10 min", in: app).waitForExistence(timeout: 5))
    }

    // MARK: - Tidewater Balance layout

    func testTodayPillarsReflectRealHabitAndAttentionData() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        createHabit(named: "Walk", in: app)
        createAttentionGoal(named: "Instagram", in: app)

        XCTAssertTrue(app.staticTexts["0 of 1"].waitForExistence(timeout: 5), "the Habits pillar must reflect real data, not a placeholder")
        XCTAssertTrue(
            app.staticTexts["Not logged yet"].waitForExistence(timeout: 5),
            "the Attention pillar must never claim a verified status before anything is logged"
        )
        XCTAssertFalse(app.staticTexts["On track"].exists, "the Attention pillar must never imply an automatically verified status")

        completeHabit(named: "Walk", in: app)
        XCTAssertTrue(app.staticTexts["1 of 1"].waitForExistence(timeout: 5), "the Habits pillar must update immediately on completion")
    }

    func testCompletingAHabitShowsAnUndoToastThatUndoesIt() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        createHabit(named: "Walk", in: app)
        completeHabit(named: "Walk", in: app)

        let toastUndo = app.buttons["today.undoToast.undoButton"]
        XCTAssertTrue(toastUndo.waitForExistence(timeout: 5))
        toastUndo.tap()

        XCTAssertTrue(app.buttons["Mark Walk complete"].waitForExistence(timeout: 5), "the toast's Undo action must restore the incomplete state")
        XCTAssertFalse(app.buttons["today.undoToast.undoButton"].exists, "the toast must dismiss once its action is used")
    }

    func testCompletedHabitRowCollapsesIntoDoneGroupAndCanStillBeUndoneAfterward() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))

        createHabit(named: "Walk", in: app)
        completeHabit(named: "Walk", in: app)

        let doneToggle = app.buttons["today.doneToggle"]
        XCTAssertTrue(
            doneToggle.waitForExistence(timeout: 5),
            "a completed habit must settle into a collapsed Done group shortly after completing"
        )
        XCTAssertFalse(
            app.buttons["Undo completion for Walk"].exists,
            "the control must not be directly reachable while the Done group is collapsed"
        )

        doneToggle.tap()
        XCTAssertTrue(
            app.buttons["Undo completion for Walk"].waitForExistence(timeout: 5),
            "expanding Done must still offer the same, familiar undo control — an obvious, accessible route to undo after the toast disappears"
        )
        app.buttons["Undo completion for Walk"].tap()
        XCTAssertTrue(app.buttons["Mark Walk complete"].waitForExistence(timeout: 5), "undo from inside the expanded Done group must restore the incomplete state")
    }

    func testAttentionQuickLogChipLogsInstantlyWithAnUndoToast() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))
        createAttentionGoal(named: "Instagram", targetMinutes: "30", in: app)

        app.buttons["Log 5 minutes for Instagram"].tap()
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "5 min of 30 min")).firstMatch.waitForExistence(timeout: 5),
            "a +5 chip must log instantly, with no sheet"
        )

        let toastUndo = app.buttons["today.undoToast.undoButton"]
        XCTAssertTrue(toastUndo.waitForExistence(timeout: 5))
        toastUndo.tap()

        XCTAssertTrue(
            app.staticTexts["No usage logged yet today"].waitForExistence(timeout: 5),
            "undo must remove exactly the chip-logged entry"
        )
    }

    func testHabitDetailRetainsLoadedStateAcrossTodayTabRefresh() {
        let app = launchApp()
        createHabit(named: "Walk", in: app)
        completeHabit(named: "Walk", in: app)
        expandDoneGroupIfNeeded(for: "Walk", in: app)
        openDetail(for: "Walk", in: app)

        // Returning to Today reloads its root model while this destination
        // remains on the stack. A destination owned only through @Bindable
        // used to be replaced by a fresh, never-loaded model on root updates.
        app.tabBars.buttons["Insights"].tap()
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.staticTexts["habitDetail.name"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["habitDetail.name"].label, "Walk")
        XCTAssertTrue(app.buttons["habitDetail.editButton"].exists)
    }

    func testAttentionDetailRetainsLoadedStateAcrossTodayTabRefresh() {
        let app = launchApp()
        createAttentionGoal(named: "Instagram", in: app)
        app.buttons["Log 5 minutes for Instagram"].tap()
        openAttentionGoalDetail(for: "Instagram", in: app)

        app.tabBars.buttons["History"].tap()
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.staticTexts["attentionGoalDetail.name"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["attentionGoalDetail.name"].label, "Instagram")
        XCTAssertTrue(app.staticTexts["attentionGoalDetail.status"].label.contains("5 min"))
    }

    func testAttentionQuickLogTargetsAreAtLeast44Points() {
        let app = launchApp()
        createAttentionGoal(named: "Instagram", in: app)
        for label in ["Log 5 minutes for Instagram", "Log 15 minutes for Instagram", "Log usage for Instagram"] {
            let button = app.buttons[label]
            XCTAssertTrue(button.exists)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44 - 0.01)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44 - 0.01)
        }
    }
}
