import XCTest

/// Public user flows only. Each method uses an isolated persistent store;
/// no fixture can reach a real user's data or manufacture a session result.
final class MVPFlowTests: XCTestCase {
    func testVisualInsightsShowsExactCommitmentsCoverageAndReadOnlyNavigation() {
        let app = launch(fixture: "visualInsights")
        waitAndTap(app.tabBars.buttons["Insights"])
        let overall = app.staticTexts["insights.overallConsistency"]
        XCTAssertTrue(overall.waitForExistence(timeout: 10))
        XCTAssertEqual(overall.label, "68%")
        let top = XCTAttachment(screenshot: app.screenshot()); top.name = "Visual Insights summary"; top.lifetime = .keepAlways; add(top)
        let read = app.buttons["insights.habit.Read"]
        for _ in 0..<5 where !read.isHittable { app.swipeUp() }
        XCTAssertTrue(read.label.contains("7 of 7 commitments successful"))
        XCTAssertTrue(app.buttons["insights.habit.Swim"].label.contains("archived, 1 of 1 commitment successful"))
        let breakdown = XCTAttachment(screenshot: app.screenshot()); breakdown.name = "Visual habit breakdown"; breakdown.lifetime = .keepAlways; add(breakdown)
        waitAndTap(read)
        XCTAssertTrue(app.staticTexts["habitDetail.name"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["habitDetail.name"].label, "Read")
        waitAndTap(app.buttons["habitDetail.viewHistoryButton"])
        XCTAssertTrue(app.tabBars.buttons["History"].isSelected)
        waitAndTap(app.tabBars.buttons["Insights"])
        let coverage = app.staticTexts["insights.attentionCoverage"]
        for _ in 0..<8 where !coverage.isHittable { app.swipeUp() }
        XCTAssertEqual(coverage.label, "3 of 7 goal-days logged manually. Unlogged days are unknown.")
        XCTAssertEqual(app.otherElements["insights.attentionSuccessRate"].label, "33% of logged goal-days below budget")
        let attention = XCTAttachment(screenshot: app.screenshot()); attention.name = "Visual manual attention coverage"; attention.lifetime = .keepAlways; add(attention)
        app.terminate(); app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE"); app.launch()
        waitAndTap(app.tabBars.buttons["Insights"])
        XCTAssertEqual(overall.label, "68%", "Reading charts must not alter weekly facts")
    }

    func testVisualInsightsAtLargestTextKeepsChartsAndControlsReadable() {
        let app = launch(fixture: "visualInsights")
        app.terminate(); app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE")
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        waitAndTap(app.tabBars.buttons["Insights"])
        XCTAssertTrue(app.staticTexts["insights.overallConsistency"].waitForExistence(timeout: 10))
        let top = XCTAttachment(screenshot: app.screenshot()); top.name = "Visual Insights at AX3"; top.lifetime = .keepAlways; add(top)
        let read = app.buttons["insights.habit.Read"]
        for _ in 0..<10 where !read.isHittable { app.swipeUp() }
        XCTAssertTrue(read.isHittable, app.debugDescription)
        let breakdown = XCTAttachment(screenshot: app.screenshot()); breakdown.name = "Visual breakdown at AX3"; breakdown.lifetime = .keepAlways; add(breakdown)
        waitAndTap(read)
        XCTAssertTrue(app.staticTexts["habitDetail.name"].waitForExistence(timeout: 10))
    }

    func testRecoveryCardToolsKeepSmallerActionsSeparateAndCancellationSafe() {
        let app = launch(fixture: "recoveryProgress")
        let progress = app.staticTexts["today.recovery.progress.Read"]
        XCTAssertTrue(progress.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertEqual(progress.label, "2 of 3 good days")
        waitAndTap(app.buttons["Make Read easier"])
        XCTAssertTrue(app.buttons["habitAdjustment.review"].waitForExistence(timeout: 10))
        waitAndTap(app.buttons["habitAdjustment.cancel"])
        XCTAssertEqual(progress.label, "2 of 3 good days")
        waitAndTap(app.buttons["Smaller action for Read"])
        XCTAssertTrue(app.buttons["activity.logSmaller"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Read one paragraph"].exists)
        let tool = XCTAttachment(screenshot: app.screenshot()); tool.name = "Recovery smaller action"; tool.lifetime = .keepAlways; add(tool)
        waitAndTap(app.buttons["activity.logSmaller"])
        waitAndTap(app.buttons["Done"])
        XCTAssertEqual(progress.label, "2 of 3 good days", "Effort is not a full commitment")
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Recovery progress card"; capture.lifetime = .keepAlways; add(capture)
        app.terminate(); app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE"); app.launch()
        XCTAssertEqual(progress.label, "2 of 3 good days")
        XCTAssertTrue(app.buttons["Mark Read complete"].exists)
    }

    func testRecoveryCompletionUndoAtAccessibilityTextSize() {
        let app = launch(fixture: "recoveryProgress")
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE")
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        waitAndTap(app.buttons["Mark Read complete"])
        let message = app.staticTexts["Momentum restored for Read"]
        XCTAssertTrue(message.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["today.recovery.progress.Read"].exists)
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Recovery restored with accessible Undo"; capture.lifetime = .keepAlways; add(capture)
        let undo = app.buttons["today.undoToast.undoButton"]
        XCTAssertTrue(undo.isHittable)
        // AX confirmation remains available beyond the ordinary four seconds.
        XCTAssertTrue(app.buttons["today.undoToast.dismissButton"].exists)
        let disappears = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: undo)
        XCTAssertEqual(XCTWaiter.wait(for: [disappears], timeout: 5), .timedOut)
        waitAndTap(undo)
        for _ in 0..<4 where !app.staticTexts["today.recovery.progress.Read"].exists { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["today.recovery.progress.Read"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertEqual(app.staticTexts["today.recovery.progress.Read"].label, "2 of 3 good days")
        for _ in 0..<5 where !app.staticTexts["today.recovery.progress.Read"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["today.recovery.progress.Read"].isHittable)
        let restored = XCTAttachment(screenshot: app.screenshot()); restored.name = "Recovery progress at AX3 after Undo"; restored.lifetime = .keepAlways; add(restored)
        app.terminate(); app.launch()
        for _ in 0..<4 where !app.staticTexts["today.recovery.progress.Read"].exists { app.swipeUp() }
        XCTAssertEqual(app.staticTexts["today.recovery.progress.Read"].label, "2 of 3 good days")
    }

    func testPolishedCoreScreensKeepNavigationAndRecoveryReadable() {
        let app = launch(fixture: "progressEnrichment")
        XCTAssertTrue(app.buttons["Open Read details"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Rebuilding ·")).firstMatch.exists)
        func capture(_ name: String) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        }
        capture("Polished Today")
        waitAndTap(app.buttons["Open Read details"])
        XCTAssertTrue(app.staticTexts["habitDetail.currentStreak"].waitForExistence(timeout: 10))
        capture("Polished Habit Detail")
        waitAndTap(app.buttons["habitDetail.activity"])
        XCTAssertTrue(app.buttons["activity.configure"].waitForExistence(timeout: 10))
        capture("Polished Logging")
        app.terminate(); app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE"); app.launch()
        waitAndTap(app.tabBars.buttons["Insights"])
        XCTAssertTrue(app.buttons["insights.madeRoomReview"].waitForExistence(timeout: 10))
        capture("Polished Insights")
        waitAndTap(app.tabBars.buttons["History"])
        capture("Polished History")
        waitAndTap(app.tabBars.buttons["Settings"])
        XCTAssertTrue(app.switches["settings.watchEnabled"].waitForExistence(timeout: 10))
        capture("Polished Settings")
        waitAndTap(app.buttons["settings.privacyLink"])
    }

    func testLifetimeMilestonePersistsAndUndoRecomputesTotal() {
        let app = launch(fixture: "progressEnrichment")
        waitAndTap(app.buttons["Open Read details"])
        waitAndTap(app.buttons["habitDetail.lifetimeProgress"])
        XCTAssertTrue(app.staticTexts["lifetime.checkInDays"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["lifetime.checkInDays"].label, "10 successful check-in days")
        XCTAssertTrue(app.staticTexts["10 check-in days reached"].exists)
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Lifetime progress milestone"; capture.lifetime = .keepAlways; add(capture)
        app.terminate(); app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE"); app.launch()
        waitAndTap(app.buttons["Mark Read complete"])
        app.terminate(); app.launch()
        waitAndTap(app.buttons["today.doneToggle"])
        waitAndTap(app.buttons["Open Read details"])
        waitAndTap(app.buttons["habitDetail.lifetimeProgress"])
        XCTAssertEqual(app.staticTexts["lifetime.checkInDays"].label, "11 successful check-in days")
        app.terminate(); app.launch()
        waitAndTap(app.buttons["today.doneToggle"])
        waitAndTap(app.buttons["Undo completion for Read"])
        waitAndTap(app.buttons["Open Read details"])
        waitAndTap(app.buttons["habitDetail.lifetimeProgress"])
        XCTAssertEqual(app.staticTexts["lifetime.checkInDays"].label, "10 successful check-in days")
    }

    func testMadeRoomReviewShowsOnlyRecordedFactsForSelectedWeek() {
        let app = launch(fixture: "progressEnrichment")
        waitAndTap(app.tabBars.buttons["Insights"])
        waitAndTap(app.buttons["insights.madeRoomReview"])
        XCTAssertTrue(app.staticTexts["madeRoom.keptSessions"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["madeRoom.keptSessions"].label, "1 session reported kept")
        XCTAssertEqual(app.staticTexts["madeRoom.timerMinutes"].label, "20 timer minutes")
        XCTAssertTrue(app.staticTexts["1 unfinished or unreported session"].exists)
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Made room recorded weekly review"; capture.lifetime = .keepAlways; add(capture)
        app.terminate(); app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE"); app.launch()
        XCTAssertTrue(app.buttons["Mark Read complete"].waitForExistence(timeout: 10), "Reading a review cannot complete a habit")
        waitAndTap(app.tabBars.buttons["Insights"])
        waitAndTap(app.buttons["insights.madeRoomReview"])
        XCTAssertEqual(app.staticTexts["madeRoom.timerMinutes"].label, "20 timer minutes")
    }

    func testPersonalQuickPresetsSaveCancelUndoAndRelaunch() {
        let app = launch(fixture: "populated")
        waitAndTap(app.buttons["Open Read details"])
        waitAndTap(app.buttons["habitDetail.activity"])
        waitAndTap(app.buttons["activity.configure"])
        let enabled = app.switches["activity.quantityEnabled"]
        XCTAssertTrue(enabled.waitForExistence(timeout: 10))
        enabled.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
        waitAndTap(app.buttons["activity.saveConfiguration"])
        waitAndTap(app.buttons["activity.editPresets"])
        let first = app.textFields["activity.presetAmount.0"]
        first.tap(); first.typeText(XCUIKeyboardKey.delete.rawValue + "7")
        waitAndTap(app.buttons["Cancel"])
        XCTAssertTrue(app.buttons["activity.quickPreset.5"].exists, "Cancel cannot change preferences")
        waitAndTap(app.buttons["activity.editPresets"])
        first.tap(); first.typeText(XCUIKeyboardKey.delete.rawValue + "7")
        waitAndTap(app.buttons["activity.savePresets"])
        waitAndTap(app.buttons["activity.quickPreset.7"])
        XCTAssertEqual(app.staticTexts["activity.progress"].label, "7 of 20 minutes logged")
        waitAndTap(app.buttons["activity.undoQuickPreset"])
        XCTAssertEqual(app.staticTexts["activity.progress"].label, "0 of 20 minutes logged")
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Personal quick log amounts"; capture.lifetime = .keepAlways; add(capture)
        app.terminate(); app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE"); app.launch()
        waitAndTap(app.buttons["Log progress for Read"])
        waitAndTap(app.buttons["activity.quickPreset.7"])
        XCTAssertEqual(app.staticTexts["activity.progress"].label, "7 of 20 minutes logged")
    }

    func testProgressReviewRemainsNavigableAtLargestText() {
        let app = launch(fixture: "progressEnrichment")
        app.terminate(); app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE")
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        waitAndTap(app.buttons["Open Read details"])
        waitAndTap(app.buttons["habitDetail.lifetimeProgress"])
        XCTAssertTrue(app.staticTexts["lifetime.checkInDays"].waitForExistence(timeout: 10))
        let lifetime = XCTAttachment(screenshot: app.screenshot()); lifetime.name = "Lifetime progress at AX3"; lifetime.lifetime = .keepAlways; add(lifetime)
        for _ in 0..<10 { if app.staticTexts["Accumulated Progress"].isHittable { break }; app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Accumulated Progress"].isHittable, "Lifetime sections remain reachable at largest text")
        app.terminate(); app.launch()
        waitAndTap(app.tabBars.buttons["Insights"])
        waitAndTap(app.buttons["insights.madeRoomReview"])
        for _ in 0..<8 { if app.staticTexts["madeRoom.keptSessions"].exists { break }; app.swipeUp() }
        XCTAssertTrue(app.staticTexts["madeRoom.keptSessions"].waitForExistence(timeout: 10))
        for _ in 0..<10 { if app.staticTexts["madeRoom.timerMinutes"].isHittable { break }; app.swipeUp() }
        XCTAssertTrue(app.staticTexts["madeRoom.timerMinutes"].isHittable, "Recorded results remain reachable at largest text")
        let review = XCTAttachment(screenshot: app.screenshot()); review.name = "Made room review at AX3"; review.lifetime = .keepAlways; add(review)
    }

    func testCloudBackupUnavailableBuildNeverClaimsProtection() {
        let app = launch(fixture: "populated")
        waitAndTap(app.tabBars.buttons["Settings"])
        waitAndTap(app.buttons["settings.backupLink"])
        XCTAssertTrue(app.switches["backup.enabled"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.switches["backup.enabled"].isEnabled)
        XCTAssertFalse(app.staticTexts["backup.lastSuccess"].exists)
    }

    func testCloudRecoveryPreviewCancelConfirmAndRelaunch() {
        let app = launch(fixture: "cloudBackupRecovery")
        waitAndTap(app.tabBars.buttons["Settings"])
        waitAndTap(app.buttons["settings.backupLink"])
        waitAndTap(app.buttons["backup.refresh"])
        waitAndTap(app.buttons["Delete Cloud Copy"])
        XCTAssertTrue(app.alerts["Delete This Recovery Point?"].waitForExistence(timeout: 10))
        waitAndTap(app.alerts.buttons["Cancel"])
        waitAndTap(app.buttons["Review Restore"])
        XCTAssertTrue(app.alerts["Restore Tracking History?"].waitForExistence(timeout: 10))
        waitAndTap(app.alerts.buttons["Cancel"])
        waitAndTap(app.buttons["Review Restore"])
        waitAndTap(app.alerts.buttons["Restore"])
        for _ in 0..<6 {
            if app.staticTexts["backup.message"].exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["backup.message"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["backup.message"].label.contains("restored"))
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Progress protection after confirmed recovery"
        capture.lifetime = .keepAlways; add(capture)
        app.terminate(); app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE"); app.launch()
        XCTAssertTrue(app.buttons["Open Recovered Reading details"].waitForExistence(timeout: 10))
    }

    func testManageableWeekPauseRequiresConfirmationAndSurvivesRelaunch() {
        let app = launch(fixture: "populated")
        waitAndTap(app.buttons["today.routines"])
        waitAndTap(app.buttons["routines.manageWeek"])
        waitAndTap(app.buttons["Pause Read"])
        waitAndTap(app.alerts.buttons["Keep Habit"])
        XCTAssertTrue(app.buttons["Pause Read"].exists)
        waitAndTap(app.buttons["Pause Read"])
        waitAndTap(app.alerts.buttons["Pause Read"])
        XCTAssertFalse(app.buttons["Pause Read"].exists)
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Enrichment manageable week"; capture.lifetime = .keepAlways; add(capture)
        app.terminate(); app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE"); app.launch()
        XCTAssertFalse(app.buttons["Open Read details"].exists)
        waitAndTap(app.tabBars.buttons["Settings"])
        let archived = app.buttons["settings.archivedHabitsLink"]
        for _ in 0..<6 { if archived.isHittable { break }; app.swipeUp() }
        waitAndTap(archived)
        XCTAssertTrue(app.staticTexts["Read"].waitForExistence(timeout: 10))
    }

    func testManageableWeekRestartRequiresSelectionAndExplicitConfirmation() {
        let app = launch(fixture: "populated")
        waitAndTap(app.buttons["today.routines"])
        waitAndTap(app.buttons["routines.manageWeek"])
        let focus = app.switches["Focus on Read"]
        XCTAssertTrue(focus.waitForExistence(timeout: 10))
        focus.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
        let restart = app.buttons["manageWeek.restart3"]
        for _ in 0..<6 { if restart.isHittable { break }; app.swipeUp() }
        waitAndTap(restart)
        waitAndTap(app.alerts.buttons["Cancel"])
        XCTAssertFalse(app.buttons["Open Your Restart Plan"].exists)
        waitAndTap(restart)
        waitAndTap(app.alerts.buttons["Create 3-Day Restart"])
        let open = app.buttons["Open Your Restart Plan"]
        for _ in 0..<6 { if open.isHittable { break }; app.swipeUp() }
        waitAndTap(open)
        XCTAssertTrue(app.buttons["Read, open check-in"].waitForExistence(timeout: 10))
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Enrichment gentle restart"; capture.lifetime = .keepAlways; add(capture)
        app.terminate(); app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE"); app.launch()
        XCTAssertTrue(app.buttons["Mark Read complete"].waitForExistence(timeout: 10), "Restart selection cannot complete a habit")
        waitAndTap(app.buttons["today.routines"])
        XCTAssertTrue(app.staticTexts["A Gentle Restart"].waitForExistence(timeout: 10))
    }

    func testPhoneFreeIntentionStaysSeparateFromHabitCompletion() {
        let app = launch(fixture: "populated")
        createGoal(named: "Room to read", type: "Phone-free session", in: app)
        app.swipeDown()
        waitAndTap(app.buttons["Open Read details"])
        waitAndTap(app.buttons["habitDetail.intention"])
        XCTAssertFalse(app.buttons["intentionSession.openStarted"].exists, "Opening alone cannot start a session")
        waitAndTap(app.buttons["intentionSession.start"])
        waitAndTap(app.buttons["intentionSession.openStarted"])
        XCTAssertFalse(app.buttons["attentionWindow.kept"].isEnabled)
        waitAndTap(app.buttons["attentionWindow.interrupted"])
        app.terminate(); app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE"); app.launch()
        XCTAssertTrue(app.buttons["Mark Read complete"].waitForExistence(timeout: 10), "An intention or session result never logs the habit")
        waitAndTap(app.buttons["Open Read details"])
        waitAndTap(app.buttons["habitDetail.intention"])
        let outcome = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Interrupted · reported manually")).firstMatch
        for _ in 0..<6 { if outcome.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(outcome.waitForExistence(timeout: 10))
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Enrichment phone free intention"; capture.lifetime = .keepAlways; add(capture)
    }

    func testQuantityProgressAndSmallerActionRemainDistinctAcrossRelaunch() {
        let app = launch(fixture: "populated")
        waitAndTap(app.buttons["Open Read details"])
        waitAndTap(app.buttons["habitDetail.activity"])
        waitAndTap(app.buttons["activity.configure"])
        let quantityToggle = app.switches["activity.quantityEnabled"]
        XCTAssertTrue(quantityToggle.waitForExistence(timeout: 10))
        quantityToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
        XCTAssertEqual(quantityToggle.value as? String, "1")
        let smaller = app.textFields["activity.smallerAction"]
        waitAndTap(smaller); smaller.typeText("Read one paragraph")
        waitAndTap(app.buttons["activity.saveConfiguration"])
        waitAndTap(app.buttons["activity.quickPreset.5"])
        XCTAssertEqual(app.staticTexts["activity.progress"].label, "5 of 20 minutes logged")
        for _ in 0..<5 {
            if app.buttons["activity.logSmaller"].isHittable { break }; app.swipeUp()
        }
        waitAndTap(app.buttons["activity.logSmaller"])
        XCTAssertFalse(app.buttons["activity.logSmaller"].isEnabled)
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Enrichment smaller action"; capture.lifetime = .keepAlways; add(capture)
        app.terminate(); app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE"); app.launch()
        XCTAssertTrue(app.buttons["Log progress for Read"].waitForExistence(timeout: 10), "Partial progress and smaller action cannot complete the full target")
        waitAndTap(app.buttons["Log progress for Read"])
        XCTAssertTrue(app.staticTexts["activity.progress"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["activity.progress"].label, "5 of 20 minutes logged")
        for _ in 0..<2 { waitAndTap(app.buttons["activity.quickPreset.10"]) }
        XCTAssertEqual(app.staticTexts["activity.progress"].label, "25 of 20 minutes logged")
        let progress = XCTAttachment(screenshot: app.screenshot()); progress.name = "Enrichment quantity progress"; progress.lifetime = .keepAlways; add(progress)
        app.terminate(); app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE"); app.launch()
        let done = app.buttons["today.doneToggle"]
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        XCTAssertTrue(done.label.contains("1 habit"))
    }

    func testWeeklyReflectionSaveCancelAndRelaunch() {
        let app = launch()
        waitAndTap(app.tabBars.buttons["Settings"])
        let link = app.buttons["settings.reflection"]
        for _ in 0..<6 { if link.isHittable { break }; app.swipeUp() }
        waitAndTap(link)
        waitAndTap(app.buttons["reflection.write"])
        let answer = app.textViews["reflection.helpedEditor"]
        waitAndTap(answer); answer.typeText("A short walk helped.")
        waitAndTap(app.buttons["reflection.cancel"])
        XCTAssertFalse(app.staticTexts["reflection.savedHelped"].exists)
        waitAndTap(app.buttons["reflection.write"])
        waitAndTap(answer); answer.typeText("A short walk helped.")
        waitAndTap(app.buttons["reflection.save"])
        XCTAssertEqual(app.staticTexts["reflection.savedHelped"].label, "A short walk helped.")
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Enrichment private reflection"; capture.lifetime = .keepAlways; add(capture)
        app.terminate(); app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE"); app.launch()
        waitAndTap(app.tabBars.buttons["Settings"])
        for _ in 0..<6 { if link.isHittable { break }; app.swipeUp() }
        waitAndTap(link)
        XCTAssertTrue(app.staticTexts["reflection.savedHelped"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["reflection.savedHelped"].label, "A short walk helped.")
    }

    func testReflectionFromInsightsShowsRecordedProgressForReviewedWeek() {
        let app = launch(fixture: "populated")
        waitAndTap(app.tabBars.buttons["Insights"])
        waitAndTap(app.buttons["insights.reflection"])
        XCTAssertTrue(app.staticTexts["Recorded This Week"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "identifier BEGINSWITH %@", "reflection.progress.")).firstMatch.exists)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Reflection with recorded weekly progress"
        capture.lifetime = .keepAlways
        add(capture)
    }

    func testRoutineCreationCancelAndExplicitHabitLogging() {
        let app = launch(fixture: "populated")
        waitAndTap(app.buttons["today.routines"])
        waitAndTap(app.buttons["New Routine"])
        waitAndTap(app.textFields["routine.name"]); app.textFields["routine.name"].typeText("Gentle morning")
        waitAndTap(app.buttons["Add Read to routine"])
        waitAndTap(app.buttons["Cancel"])
        XCTAssertFalse(app.staticTexts["Gentle morning"].exists)
        waitAndTap(app.buttons["New Routine"])
        waitAndTap(app.textFields["routine.name"]); app.textFields["routine.name"].typeText("Gentle morning")
        waitAndTap(app.buttons["Add Read to routine"])
        waitAndTap(app.buttons["routine.save"])
        waitAndTap(app.staticTexts["Gentle morning"])
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Enrichment routine"; capture.lifetime = .keepAlways; add(capture)
        let log = app.buttons["Read, open check-in"]
        XCTAssertTrue(log.waitForExistence(timeout: 10))
        waitAndTap(log)
        waitAndTap(app.buttons["activity.logSuccess"])
        app.terminate(); app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE"); app.launch()
        XCTAssertTrue(app.buttons["today.doneToggle"].waitForExistence(timeout: 10))
    }

    func testActivityConfigurationAtLargestTextRemainsReachable() throws {
        let app = launch(fixture: "populated")
        app.terminate(); app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE")
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        waitAndTap(app.buttons["Open Read details"])
        waitAndTap(app.buttons["habitDetail.activity"])
        waitAndTap(app.buttons["activity.configure"])
        let toggle = app.switches["activity.quantityEnabled"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "1")
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .textClipped, .trait])
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Enrichment large text setup"; capture.lifetime = .keepAlways; add(capture)
        XCTAssertTrue(app.buttons["activity.saveConfiguration"].isHittable)
        waitAndTap(app.buttons["Cancel"])
        XCTAssertFalse(app.buttons["activity.logQuantity"].exists, "Cancelled configuration creates no target")
    }

    func testApplicationLaunchPerformanceBaseline() {
        let app = launch()
        app.terminate()
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)], options: options) {
            app.launch()
            app.terminate()
        }
    }

    func testSupportingScreensPassNativeAccessibilityAudit() throws {
        let app = launch(fixture: "populated")
        let checks: XCUIAccessibilityAuditType = [.hitRegion, .sufficientElementDescription, .textClipped, .trait]
        for tab in ["History", "Insights", "Settings"] {
            waitAndTap(app.tabBars.buttons[tab])
            try app.performAccessibilityAudit(for: checks) { issue in
                print("Accessibility finding on \(tab): \(issue.compactDescription); \(issue.element?.debugDescription ?? issue.detailedDescription)")
                return false
            }
            let capture = XCTAttachment(screenshot: app.screenshot())
            capture.name = "Quality audit \(tab)"; capture.lifetime = .keepAlways; add(capture)
        }
        waitAndTap(app.buttons["settings.premiumButton"])
        try app.performAccessibilityAudit(for: checks) { issue in
            print("Accessibility finding on paywall: \(issue.compactDescription); \(issue.element?.debugDescription ?? issue.detailedDescription)")
            return false
        }
    }

    func testCoreScreensPassNativeAccessibilityAudit() throws {
        let app = launch(fixture: "populated")
        XCTAssertTrue(app.buttons["Open Read details"].waitForExistence(timeout: 10))
        // Geometry, descriptions, clipping and traits are observable here.
        // Contrast has separate palette tests; real VoiceOver remains a device gate.
        let checks: XCUIAccessibilityAuditType = [.hitRegion, .sufficientElementDescription, .textClipped, .trait]
        for button in app.buttons.allElementsBoundByIndex where button.isHittable {
            print("Audit control: \(button.label), \(button.frame)")
        }
        try app.performAccessibilityAudit(for: checks) { issue in
            print("Accessibility finding: \(issue.compactDescription); \(issue.element?.debugDescription ?? issue.detailedDescription)")
            return false
        }
        let todayCapture = XCTAttachment(screenshot: app.screenshot())
        todayCapture.name = "Quality audit Today"; todayCapture.lifetime = .keepAlways; add(todayCapture)
        waitAndTap(app.buttons["Open Read details"])
        let calendarLink = app.buttons["habitDetail.calendarLink"]
        for _ in 0..<6 { if calendarLink.isHittable { break }; app.swipeUp() }
        waitAndTap(calendarLink)
        XCTAssertTrue(app.staticTexts["habitCalendar.currentStreak"].waitForExistence(timeout: 10))
        for button in app.buttons.allElementsBoundByIndex where button.isHittable {
            print("Audit control: \(button.label), \(button.frame)")
        }
        try app.performAccessibilityAudit(for: checks) { issue in
            print("Accessibility finding: \(issue.compactDescription); \(issue.element?.debugDescription ?? issue.detailedDescription)")
            return false
        }
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Quality audit calendar"; capture.lifetime = .keepAlways; add(capture)
    }

    func testWeekdayFormAtLargestTextHasComfortableTargetsAndPersists() throws {
        let app = launch()
        app.terminate()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        waitAndTap(app.buttons["today.addHabitButton"])
        waitAndTap(app.textFields["habitForm.nameField"])
        app.textFields["habitForm.nameField"].typeText("Weekly reading")
        let selectedDays = app.buttons["Selected Days"]
        for _ in 0..<12 {
            if selectedDays.exists && selectedDays.isHittable { break }
            app.swipeUp()
        }
        waitAndTap(selectedDays)
        let sunday = app.buttons["habitForm.weekday.1"]
        for _ in 0..<8 {
            if sunday.exists && sunday.isHittable { break }
            app.swipeUp()
        }
        XCTAssertFalse(app.buttons["habitForm.saveButton"].isEnabled, "At least one day must be selected")
        waitAndTap(sunday)
        XCTAssertGreaterThanOrEqual(sunday.frame.height.rounded(), 44)
        XCTAssertGreaterThanOrEqual(sunday.frame.width.rounded(), 44)
        XCTAssertEqual(sunday.value as? String, "Selected")
        XCTAssertTrue(app.buttons["habitForm.saveButton"].isEnabled)
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .textClipped, .trait]) { issue in
            print("Accessibility finding: \(issue.compactDescription); \(issue.element?.debugDescription ?? issue.detailedDescription)")
            return false
        }
        // Auditing may scroll the Form while evaluating other text sizes.
        // Restore the actual weekday control before capturing visual evidence.
        for _ in 0..<10 {
            if sunday.exists && sunday.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(sunday.isHittable)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Quality audit largest text weekday form"; capture.lifetime = .keepAlways; add(capture)
        waitAndTap(app.buttons["habitForm.saveButton"])
        app.terminate(); app.launch()
        // Sunday may not be due today; Settings' order screen lists all active habits.
        waitAndTap(app.tabBars.buttons["Settings"])
        waitAndTap(app.buttons["settings.habitOrderButton"])
        XCTAssertTrue(app.staticTexts["Weekly reading"].waitForExistence(timeout: 10))
    }

    func testDismissConfirmationPreservesLoggingAndDoneUndo() {
        let app = launch(fixture: "populated")
        waitAndTap(app.buttons["Mark Read complete"])
        let dismiss = app.buttons["today.undoToast.dismissButton"]
        waitAndTap(dismiss)
        XCTAssertFalse(app.buttons["today.undoToast.undoButton"].exists)
        let done = app.buttons["today.doneToggle"]
        waitAndTap(done)
        waitAndTap(app.buttons["Undo completion for Read"])
        XCTAssertTrue(app.buttons["Mark Read complete"].waitForExistence(timeout: 10))
    }

    func testOnboardingWelcomePassesNativeAccessibilityAudit() throws {
        let app = launch(onboarding: true)
        XCTAssertTrue(app.staticTexts["onboarding.title"].waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .textClipped, .trait]) { issue in
            print("Accessibility finding: \(issue.compactDescription); \(issue.element?.debugDescription ?? issue.detailedDescription)")
            return false
        }
        let welcome = XCTAttachment(screenshot: app.screenshot())
        welcome.name = "Quality audit onboarding"; welcome.lifetime = .keepAlways; add(welcome)
        waitAndTap(app.buttons["onboarding.continue"])
        XCTAssertTrue(app.buttons["onboarding.createHabit"].waitForExistence(timeout: 10))
    }

    func testImmersiveThemeAndStreakCalendarPreserveReadOnlyHistory() {
        let app = launch(fixture: "populated")
        let firstHabit = app.buttons["Mark Read complete"]
        XCTAssertTrue(firstHabit.waitForExistence(timeout: 10))
        XCTAssertTrue(firstHabit.isHittable, "The first habit action should be visible without scrolling past companion/routines")
        let originalToday = XCTAttachment(screenshot: app.screenshot())
        originalToday.name = "Atmospheric Tidewater Today"; originalToday.lifetime = .keepAlways; add(originalToday)
        waitAndTap(app.tabBars.buttons["Settings"])
        waitAndTap(app.buttons["settings.appThemeLink"])
        waitAndTap(app.buttons["appearance.theme.indigo"])
        let picker = XCTAttachment(screenshot: app.screenshot())
        picker.name = "Immersive Indigo theme picker"; picker.lifetime = .keepAlways; add(picker)
        waitAndTap(app.tabBars.buttons["Today"])
        let today = XCTAttachment(screenshot: app.screenshot())
        today.name = "Immersive Indigo Today"; today.lifetime = .keepAlways; add(today)
        waitAndTap(app.buttons["Open Read details"])
        waitAndTap(app.buttons["habitDetail.calendarLink"])
        let streak = app.staticTexts["habitCalendar.currentStreak"]
        XCTAssertTrue(streak.waitForExistence(timeout: 10))
        XCTAssertTrue(streak.label.contains("Current streak:"))
        XCTAssertTrue(app.staticTexts["habitCalendar.bestStreak"].exists)
        // Last completed week crosses into the previous month on some dates;
        // browse there to make a recorded ribbon visible without writing facts.
        waitAndTap(app.buttons["habitCalendar.previousMonth"])
        let calendar = XCTAttachment(screenshot: app.screenshot())
        calendar.name = "Immersive Indigo streak calendar"; calendar.lifetime = .keepAlways; add(calendar)
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE")
        app.launch()
        waitAndTap(app.buttons["Open Read details"])
        XCTAssertEqual(app.buttons["habitDetail.skipButton"].label, "Skip Today")
        waitAndTap(app.tabBars.buttons["Settings"])
        waitAndTap(app.buttons["settings.appThemeLink"])
        XCTAssertEqual(app.buttons["appearance.theme.indigo"].value as? String, "Selected")
    }

    func testLighterScheduleCancelConfirmAndRelaunch() {
        let app = launch(fixture: "populated")
        waitAndTap(app.buttons["Open Meditate details"])
        waitAndTap(app.buttons["habitDetail.makeEasier"])
        XCTAssertTrue(app.staticTexts["habitAdjustment.current"].waitForExistence(timeout: 10))
        waitAndTap(app.buttons["habitAdjustment.keep"])
        XCTAssertTrue(app.staticTexts["Daily"].waitForExistence(timeout: 10))
        waitAndTap(app.buttons["habitDetail.makeEasier"])
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Native lighter schedule review"
        capture.lifetime = .keepAlways; add(capture)
        waitAndTap(app.buttons["habitAdjustment.review"])
        waitAndTap(app.alerts.buttons["Cancel"])
        XCTAssertTrue(app.buttons["habitAdjustment.review"].exists)
        waitAndTap(app.buttons["habitAdjustment.review"])
        waitAndTap(app.alerts.buttons["Use This Schedule"])
        XCTAssertTrue(app.staticTexts["3x / week"].waitForExistence(timeout: 10))
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE")
        app.launch()
        waitAndTap(app.buttons["Open Meditate details"])
        XCTAssertTrue(app.staticTexts["3x / week"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["habitDetail.makeEasier"].exists)
    }

    func testLighterScheduleAtAccessibilityTextSize() {
        let app = launch(fixture: "populated")
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE")
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        waitAndTap(app.buttons["Open Meditate details"])
        for identifier in ["habitDetail.makeEasier", "habitAdjustment.review"] {
            // List/Form lazily materialize rows at AX3; scroll before waiting
            // for existence, not only after an element becomes hittable.
            let button = app.buttons[identifier]
            for _ in 0..<6 {
                if button.exists && button.isHittable { break }
                app.swipeUp()
            }
            waitAndTap(button)
        }
        XCTAssertTrue(app.alerts.buttons["Use This Schedule"].waitForExistence(timeout: 10))
        waitAndTap(app.alerts.buttons["Cancel"])
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Accessible native lighter schedule"
        capture.lifetime = .keepAlways; add(capture)
        waitAndTap(app.buttons["habitAdjustment.cancel"])
        XCTAssertTrue(app.buttons["habitDetail.makeEasier"].waitForExistence(timeout: 10))
    }

    func testAdditionalThemesSurviveRelaunch() {
        let app = launch(fixture: "populated")
        waitAndTap(app.tabBars.buttons["Settings"])
        waitAndTap(app.buttons["settings.appThemeLink"])
        for theme in ["indigo", "forest", "coral", "gold"] {
            let choice = app.buttons["appearance.theme.\(theme)"]
            waitAndTap(choice)
            XCTAssertEqual(choice.value as? String, "Selected")
        }
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Nine native colour themes"
        capture.lifetime = .keepAlways; add(capture)
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE")
        app.launch()
        waitAndTap(app.tabBars.buttons["Settings"])
        waitAndTap(app.buttons["settings.appThemeLink"])
        let gold = app.buttons["appearance.theme.gold"]
        waitAndTap(gold)
        XCTAssertEqual(gold.value as? String, "Selected")
        waitAndTap(app.tabBars.buttons["Today"])
        XCTAssertTrue(app.buttons["Open Meditate details"].waitForExistence(timeout: 10))
    }

    func testNativeHabitOrderDragHandleChangesDraftOnlyUntilSave() {
        let app = launch(fixture: "populated")
        waitAndTap(app.buttons["today.habitOrderButton"])
        let lastRow = app.cells.containing(.staticText, identifier: "Meditate").firstMatch
        let firstRow = app.cells.containing(.staticText, identifier: "Read").firstMatch
        XCTAssertTrue(lastRow.waitForExistence(timeout: 10))
        XCTAssertTrue(firstRow.exists)
        lastRow.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5))
            .press(forDuration: 1.2, thenDragTo: firstRow.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.1)))
        XCTAssertTrue(app.buttons["habitOrder.save"].isEnabled)
        XCTAssertFalse(app.buttons["Move Meditate up"].isEnabled, "Dragged habit should now be first")
        waitAndTap(app.buttons["habitOrder.save"])
        assertTodayOrder(["Meditate", "Read", "Walk"], in: app)
    }

    func testHabitOrderCancelSaveAndRelaunchPreserveTracking() {
        let app = launch()
        for name in ["Read", "Walk", "Journal"] {
            waitAndTap(app.buttons["today.addHabitButton"])
            let field = app.textFields["habitForm.nameField"]
            waitAndTap(field); field.typeText(name)
            waitAndTap(app.buttons["habitForm.saveButton"])
        }
        waitAndTap(app.buttons["today.habitOrderButton"])
        waitAndTap(app.buttons["Move Journal up"])
        waitAndTap(app.buttons["Move Journal up"])
        waitAndTap(app.buttons["habitOrder.cancel"])
        assertTodayOrder(["Read", "Walk", "Journal"], in: app)
        waitAndTap(app.buttons["today.habitOrderButton"])
        waitAndTap(app.buttons["Move Journal up"])
        waitAndTap(app.buttons["Move Journal up"])
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Native habit order draft"
        capture.lifetime = .keepAlways
        add(capture)
        waitAndTap(app.buttons["habitOrder.save"])
        assertTodayOrder(["Journal", "Read", "Walk"], in: app)
        app.terminate(); app.launch()
        assertTodayOrder(["Journal", "Read", "Walk"], in: app)
        waitAndTap(app.tabBars.buttons["History"])
        XCTAssertTrue(app.staticTexts["history.emptyState.title"].waitForExistence(timeout: 10), "Arranging must not create check-ins")
        waitAndTap(app.tabBars.buttons["Today"])
        waitAndTap(app.buttons["Mark Journal complete"])
        waitAndTap(app.buttons["today.undoToast.undoButton"])
        XCTAssertTrue(app.buttons["Mark Journal complete"].waitForExistence(timeout: 10))
    }

    func testHabitOrderingFromSettingsAtAccessibilityTextSize() {
        let app = launch(fixture: "populated")
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE")
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        waitAndTap(app.tabBars.buttons["Settings"])
        waitAndTap(app.buttons["settings.habitOrderButton"])
        let moveUp = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Move ")).allElementsBoundByIndex.first { $0.label.hasSuffix(" up") && $0.isEnabled }
        XCTAssertNotNil(moveUp)
        waitAndTap(moveUp!)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Accessible native habit ordering"
        capture.lifetime = .keepAlways
        add(capture)
        waitAndTap(app.buttons["habitOrder.save"])
        XCTAssertTrue(app.buttons["settings.habitOrderButton"].waitForExistence(timeout: 10))
        app.terminate(); app.launch()
        waitAndTap(app.tabBars.buttons["Settings"])
        waitAndTap(app.buttons["settings.habitOrderButton"])
        XCTAssertFalse(app.buttons["habitOrder.save"].isEnabled, "Reopening starts from the persisted order")
        waitAndTap(app.buttons["habitOrder.cancel"])
    }

    private func assertTodayOrder(_ names: [String], in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let rows = names.map { app.buttons["Open \($0) details"] }
        for row in rows { XCTAssertTrue(row.waitForExistence(timeout: 10), file: file, line: line) }
        for index in 1..<rows.count {
            XCTAssertLessThan(rows[index - 1].frame.minY, rows[index].frame.minY, file: file, line: line)
        }
    }

    func testCalendarShowsPersistedHistoryAndMonthNavigationWithoutLogging() {
        let app = launch(fixture: "populated")
        waitAndTap(app.buttons["Open Read details"])
        waitAndTap(app.buttons["habitDetail.calendarLink"])
        XCTAssertTrue(app.staticTexts["habitCalendar.currentStreak"].waitForExistence(timeout: 10))
        let title = app.staticTexts["habitCalendar.monthTitle"]
        let original = title.label
        XCTAssertFalse(app.buttons["habitCalendar.nextMonth"].isEnabled)
        waitAndTap(app.buttons["habitCalendar.previousMonth"])
        XCTAssertNotEqual(title.label, original)
        XCTAssertTrue(app.buttons["habitCalendar.nextMonth"].isEnabled)
        XCTAssertGreaterThan(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "habitCalendar.day.")).count, 20)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Native month calendar with persisted facts"
        capture.lifetime = .keepAlways
        add(capture)
        waitAndTap(app.buttons["habitCalendar.nextMonth"])
        XCTAssertEqual(title.label, original)
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE")
        app.launch()
        waitAndTap(app.buttons["Open Read details"])
        let skip = app.buttons["habitDetail.skipButton"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10))
        XCTAssertEqual(skip.label, "Skip Today", "Browsing history must never log a success")
    }

    func testWeeklyCalendarExplainsCommitmentsAtAccessibilityTextSize() {
        let app = launch()
        waitAndTap(app.buttons["today.addHabitButton"])
        let field = app.textFields["habitForm.nameField"]
        waitAndTap(field); field.typeText("Weekly reading")
        waitAndTap(app.segmentedControls["habitForm.scheduleTypePicker"].buttons["Times per Week"])
        waitAndTap(app.buttons["habitForm.saveButton"])
        app.terminate()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        waitAndTap(app.buttons["Open Weekly reading details"])
        XCTAssertTrue(app.staticTexts["habitDetail.name"].waitForExistence(timeout: 10))
        for _ in 0..<8 {
            if app.buttons["habitDetail.calendarLink"].exists { break }
            app.swipeUp()
        }
        waitAndTap(app.buttons["habitDetail.calendarLink"])
        XCTAssertTrue(app.staticTexts["habitCalendar.monthTitle"].waitForExistence(timeout: 10))
        let days = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "habitCalendar.day."))
        XCTAssertGreaterThan(days.count, 0)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Calendar accessibility date list"
        capture.lifetime = .keepAlways
        add(capture)
        let weekly = app.staticTexts["Weekly Commitments"]
        for _ in 0..<12 {
            if weekly.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(weekly.isHittable)
        let pending = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Pending · no miss")).firstMatch
        XCTAssertTrue(pending.exists)
        for _ in 0..<10 {
            if pending.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(pending.isHittable)
        let weeklyCapture = XCTAttachment(screenshot: app.screenshot())
        weeklyCapture.name = "Accessible weekly commitment outcome"
        weeklyCapture.lifetime = .keepAlways
        add(weeklyCapture)
    }

    func testAppThemeAppliesImmediatelyAndSurvivesRelaunch() {
        let app = launch(fixture: "populated")
        waitAndTap(app.tabBars.buttons["Settings"])
        waitAndTap(app.buttons["settings.appThemeLink"])
        let sapphire = app.buttons["appearance.theme.sapphire"]
        waitAndTap(sapphire)
        XCTAssertEqual(sapphire.value as? String, "Selected")
        XCTAssertEqual(app.buttons["appearance.theme.tidewater"].value as? String, "Not selected")
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Native curated colour theme selection"
        capture.lifetime = .keepAlways
        add(capture)
        waitAndTap(app.tabBars.buttons["Today"])
        XCTAssertTrue(app.buttons["today.addHabitButton"].waitForExistence(timeout: 10))
        let todayCapture = XCTAttachment(screenshot: app.screenshot())
        todayCapture.name = "Sapphire theme applied to populated Today"
        todayCapture.lifetime = .keepAlways
        add(todayCapture)
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "AVELA_UI_TEST_SEED_FIXTURE")
        app.launch()
        waitAndTap(app.tabBars.buttons["Settings"])
        waitAndTap(app.buttons["settings.appThemeLink"])
        XCTAssertEqual(app.buttons["appearance.theme.sapphire"].value as? String, "Selected")
        waitAndTap(app.buttons["appearance.theme.rose"])
        XCTAssertEqual(app.buttons["appearance.theme.rose"].value as? String, "Selected")
    }

    func testShortcutsGuideExplainsSelfReportedLogging() {
        let app = launch()
        waitAndTap(app.tabBars.buttons["Settings"])
        waitAndTap(app.buttons["settings.shortcutsLink"])
        XCTAssertTrue(app.staticTexts["Log a habit in Avela"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Log attention in Avela"].exists)
        let explanation = app.staticTexts["shortcuts.additiveExplanation"]
        XCTAssertTrue(explanation.exists)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Siri and Shortcuts guide"
        capture.lifetime = .keepAlways
        add(capture)
    }

    func testHealthSetupIsExplicitAndLeavesHabitUncompleted() {
        let app = launch()
        waitAndTap(app.buttons["today.addHabitButton"])
        let name = app.textFields["habitForm.nameField"]
        waitAndTap(name)
        name.typeText("Walk for health")
        waitAndTap(app.buttons["habitForm.saveButton"])
        waitAndTap(app.buttons["Open Walk for health details"])
        waitAndTap(app.buttons["habitDetail.healthLink"])
        XCTAssertTrue(app.textFields["health.targetField"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["health.targetField"].value as? String, "5000")
        XCTAssertTrue(app.buttons["health.connectButton"].exists)
        XCTAssertFalse(app.buttons["health.refreshButton"].exists)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Apple Health opt-in setup"
        capture.lifetime = .keepAlways
        add(capture)
        waitAndTap(app.navigationBars.buttons.element(boundBy: 0))
        let skip = app.buttons["habitDetail.skipButton"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10))
        XCTAssertEqual(skip.label, "Skip Today", "Viewing setup must not complete or skip a habit")
    }

    func testHabitIdeaCanBeCustomizedSavedAndEditedAfterRelaunch() {
        let app = launch()
        waitAndTap(app.buttons["today.addHabitButton"])
        waitAndTap(app.buttons["habitForm.ideasLink"])
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Native habit starter library"
        capture.lifetime = .keepAlways
        add(capture)
        waitAndTap(app.buttons["habitStarter.stretch"])
        let name = app.textFields["habitForm.nameField"]
        XCTAssertEqual(name.value as? String, "Stretch")
        XCTAssertTrue(app.segmentedControls["habitForm.scheduleTypePicker"].buttons["Times per Week"].isSelected)
        waitAndTap(name)
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 7) + "Stretch after work")
        waitAndTap(app.buttons["habitForm.saveButton"])
        XCTAssertTrue(app.staticTexts["3x / week — 0/3 this week"].waitForExistence(timeout: 10))
        app.terminate()
        app.launch()
        waitAndTap(app.buttons["Open Stretch after work details"])
        waitAndTap(app.buttons["habitDetail.editButton"])
        XCTAssertEqual(app.textFields["habitForm.nameField"].value as? String, "Stretch after work")
        XCTAssertFalse(app.buttons["habitForm.ideasLink"].exists, "Editing must not offer template replacement")
    }

    func testBrowsingIdeasAndCancellingDoesNotCreateAHabit() {
        let app = launch()
        waitAndTap(app.buttons["today.addHabitButton"])
        waitAndTap(app.buttons["habitForm.ideasLink"])
        waitAndTap(app.buttons["habitStarter.walk"])
        XCTAssertEqual(app.textFields["habitForm.nameField"].value as? String, "Take a walk")
        waitAndTap(app.buttons["habitForm.ideasLink"])
        waitAndTap(app.navigationBars["Habit Ideas"].buttons.element(boundBy: 0))
        XCTAssertEqual(app.textFields["habitForm.nameField"].value as? String, "Take a walk")
        waitAndTap(app.buttons["habitForm.cancelButton"])
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["today.emptyState.title"].waitForExistence(timeout: 10))
    }

    func testAvoidanceIdeaKeepsHonestSuccessCopyAtLargeText() {
        let app = launch()
        app.terminate()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        waitAndTap(app.buttons["today.addHabitButton"])
        waitAndTap(app.buttons["habitForm.ideasLink"])
        let search = app.searchFields.firstMatch
        waitAndTap(search)
        search.typeText("scrolling")
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Habit ideas search at AX3"
        capture.lifetime = .keepAlways
        add(capture)
        waitAndTap(app.buttons["habitStarter.scroll"])
        XCTAssertEqual(app.textFields["habitForm.nameField"].value as? String, "Cut down on scrolling")
        waitAndTap(app.buttons["habitForm.saveButton"])
        XCTAssertTrue(app.buttons["Log success for Cut down on scrolling"].waitForExistence(timeout: 10))
    }

    func testNativeReminderReviewConfirmsIdentityBeforeLoggingAndSurvivesRelaunch() {
        exerciseNativeReminder(confirm: true)
    }

    func testNativeReminderReviewCanBeCancelledWithoutLogging() {
        exerciseNativeReminder(confirm: false)
    }

    func testOpeningNativeReminderAloneDoesNotLog() {
        exerciseNativeReminder(confirm: false, review: false)
    }

    private func exerciseNativeReminder(confirm: Bool, review: Bool = true) {
        let app = launch(reminderDelivery: true)
        waitAndTap(app.buttons["today.addHabitButton"])
        let name = app.textFields["habitForm.nameField"]
        waitAndTap(name)
        name.typeText("Read after lunch")
        waitAndTap(app.buttons["habitForm.saveButton"])
        waitAndTap(app.buttons["Open Read after lunch details"])
        waitAndTap(app.buttons["habitDetail.reminderLink"])
        let enabled = app.switches["habitReminder.enabled"]
        XCTAssertTrue(enabled.waitForExistence(timeout: 10))
        enabled.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        waitAndTap(app.buttons["habitReminder.save"])
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons["Allow"]
        if allow.waitForExistence(timeout: 3) { allow.tap() }
        XCTAssertTrue(app.staticTexts["habitReminder.saved"].waitForExistence(timeout: 10))
        XCUIDevice.shared.press(.home)
        let notification = springboard.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "A moment for your habit")).firstMatch
        XCTAssertTrue(notification.waitForExistence(timeout: 20), springboard.debugDescription)
        if review {
            notification.press(forDuration: 1.5)
            let capture = XCTAttachment(screenshot: springboard.screenshot())
            capture.name = "Native actionable habit reminder"
            capture.lifetime = .keepAlways
            add(capture)
            let review = springboard.buttons["Review & log"]
            XCTAssertTrue(review.waitForExistence(timeout: 10), springboard.debugDescription)
            review.tap()
            let confirmation = app.alerts["Log Success?"]
            XCTAssertTrue(confirmation.waitForExistence(timeout: 10), app.debugDescription)
            XCTAssertTrue(confirmation.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Read after lunch")).firstMatch.exists)
            let reviewCapture = XCTAttachment(screenshot: app.screenshot())
            reviewCapture.name = "Named habit review with explicit Cancel"
            reviewCapture.lifetime = .keepAlways
            add(reviewCapture)
            confirmation.buttons[confirm ? "Log success" : "Cancel"].tap()
        } else {
            notification.tap()
            XCTAssertTrue(app.navigationBars["Reminder"].waitForExistence(timeout: 10))
            XCTAssertFalse(app.alerts["Log Success?"].exists)
        }
        app.terminate()
        app.launch()
        waitAndTap(app.tabBars.buttons["History"])
        if confirm {
            XCTAssertTrue(app.staticTexts["Read after lunch"].waitForExistence(timeout: 10))
        } else {
            XCTAssertTrue(app.staticTexts["history.emptyState.title"].waitForExistence(timeout: 10), app.debugDescription)
        }
    }

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

    private func launch(onboarding: Bool = false, liveActivity: Bool = false, reminderDelivery: Bool = false, fixture: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["AVELA_UI_TEST_STORE_PATH"] = storeDirectory.appendingPathComponent("MVPFlow.store").path
        if let fixture { app.launchEnvironment["AVELA_UI_TEST_SEED_FIXTURE"] = fixture }
        if reminderDelivery { app.launchEnvironment["AVELA_UI_TEST_REMINDER_DELIVERY"] = "1" }
        if liveActivity { app.launchEnvironment["AVELA_UI_TEST_LIVE_ACTIVITY"] = "1" }
        if onboarding { app.launchEnvironment["AVELA_UI_TEST_ONBOARDING"] = "1" }
        application = app
        app.launch()
        return app
    }

    private func waitAndTap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        // Native Lists can omit offscreen rows from the accessibility tree.
        // Allow presentation to settle, then reveal the row before asserting.
        if !element.waitForExistence(timeout: 3) {
            for _ in 0..<8 {
                if element.exists { break }
                application?.swipeUp()
            }
        }
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
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Tracking is saved on your device")).firstMatch.exists)
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
