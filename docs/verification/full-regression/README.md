# Full simulator regression — October 8, 2026

## Scope

Unfiltered Debug `xcodebuild test` on the isolated iPhone 18 Pro Max iOS 27 simulator (`2ACFE418-44EC-4A44-9B2A-1B45BDF1EF38`). The owner’s iPhone 18 Pro simulator was neither reset nor seeded. No production code changed during this pass.

## Initial full run

- **547 unit tests passed**, zero failures, 9.3 seconds.
- **105 UI tests executed: 103 passed, 2 failed**, approximately 61 minutes.
- Result: `/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.08_11-12-44--0600.xcresult`.
- Log: `/tmp/rilova-full-regression-2026-10-08.log`.

Failures: `testHealthSetupIsExplicitAndLeavesHabitUncompleted` and `testLighterScheduleCancelConfirmAndRelaunch`. Both asserted earlier habit-detail rows immediately after returning from lower tools. Exported failure accessibility hierarchies confirm the detail screen retained scroll positions of 90% and 75%; native lazy List omitted the offscreen Skip Today/Daily rows. These were test-navigation defects, rather than evidence that opening Health or cancelling a schedule changed stored progress.

The existing assertions remain intact. Bounded upward scrolling now reveals Skip Today after Health, Daily after Keep Current Schedule, and the changed weekly schedule after confirmation. No timeouts, expected values, permissions, model behavior or production UI were relaxed or changed.

## Reproduction

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=2ACFE418-44EC-4A44-9B2A-1B45BDF1EF38' \
  -derivedDataPath /tmp/AvelaCodexMVP -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```

Targeted correction run uses the same command with these selections:

```sh
-only-testing:AvelaUITests/MVPFlowTests/testHealthSetupIsExplicitAndLeavesHabitUncompleted
-only-testing:AvelaUITests/MVPFlowTests/testLighterScheduleCancelConfirmAndRelaunch
```

Log: `/tmp/rilova-regression-scroll-followup.log`. **Both corrected tests passed**, zero failures, 98 seconds. Result: `/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.08_12-15-40--0600.xcresult`. Every one of the 547 unit and 105 UI tests has a passing result across the full run and targeted correction run. No remaining test failures are known from this pass.

## Limits

The initial unfiltered command returned TEST FAILED; its failures are preserved above. Final coverage is assessed across that full run and the correction run, not presented as a single clean unfiltered command. The full run also reported a simulator diagnostic-collection `simctl` lookup warning after tests completed; test result bundles and exported accessibility attachments are available.

Real Health authorization/data, paired Watch, Siri speech, CloudKit recovery, microphone recognition, app-protection lifecycle, App Store sandbox purchases and TestFlight still require appropriate signed-device/account verification. Simulator checks of adapters, unavailable states, configuration and local StoreKit flows do not replace those checks. No new physical-device or Release verification is claimed by this regression-only pass.
