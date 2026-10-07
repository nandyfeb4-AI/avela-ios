# Connected differentiation verification

October 6, 2026. Native simulator screenshots and XCTest results; no user-behavior or market-differentiation claim.

## Implemented

- Habit create/edit: optional 240-character text reason. Recovery Detail and pre-Make Room show it, with a persistent Hide option. Photos are not implemented. Private reasons and visibility stay out of Avela logical cloud backups and shared extension data.
- Habit Detail → Momentum: separate Recent Rhythm, Coming Back and Lasting Effort facts. No weighted score. Skips/pauses/open periods and weekly commitments retain canonical semantics. Smaller effort is separate from full success.
- Today → A smaller step: an optional evidence-based choice after repeated resolved misses on the current configuration. Opens the existing smaller-action logger without saving, or confirms a pause. Manual reactivation in Settings is explicit; no automatic date is promised.
- Make Room / weekly review: distinct linked session starts counted independently of session outcomes and habit check-ins.
- Companion: four labelled app-facing states with distinct existing poses. Recorded facts drive them; timers/unknown usage never imply success or overload. Legacy six-state artwork/widget keys remain compatible.

## Native screenshots

[Momentum](momentum-light.png) · [Recovery choices](recovery-choices-light.png) · [Pause confirmation](recovery-pause-light.png) · [Today recovery](today-recovery-light.png)

The Today capture is after smaller effort is logged, so its repeated recovery-choice invitation is suppressed. Smaller effort does not advance the two-of-three success counter. Screenshots use isolated fixture data, not user tracking.

## Results

- **501 unit tests pass**, zero failures. Includes seven Momentum tests, nine recovery-choice tests, eight memory/connection tests, and four companion-state tests added this pass.
- **Four affected UI flows pass across verification runs**: Momentum + memory persistence after relaunch; companion selection/visibility persistence; recovery tools and separate smaller effort; cancellation → open logger without saving → confirmed pause → archived-habit visibility. The final two recovery flows pass together after the layout refinement. This is not a full UI-suite run.
- Debug simulator test build and Release device build succeed. Release binary contains zero occurrences of checked DEBUG store/fixture hooks; `HabitRecord` sanity symbols are present.
- Copied an actual pre-change populated SwiftData store to a temporary location, opened it with the new app using its DEBUG-only store override, and verified migration. All original counts (including 3 habits and 12 completions) and habit/completion/configuration/skip/archive business row values remain identical. New optional reason columns initialize nil. Original store was not changed or reset.
- Project membership: 210 Swift sources, zero issues. Project plist validates; whitespace check passes.
- Latest Debug app installed and launched on the owner's iPhone 18 Pro simulator without uninstalling or resetting its data.

## Fixes found during integration

Two SwiftUI compiler failures were resolved by splitting Today's large presentation composition and using the correct Section header/footer initializer for memory. A custom accessibility identifier on the native pause alert action produced duplicate nested Button nodes on this toolchain; removing it restored the native action's accessible representation and the public UI flow passes. The recovery controls use two columns at normal text sizes and stack at accessibility sizes, avoiding a crowded four-action horizontal row.

## Reproduction

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=2ACFE418-44EC-4A44-9B2A-1B45BDF1EF38' \
  -derivedDataPath /tmp/AvelaCodexMVP -parallel-testing-enabled NO \
  -only-testing:AvelaTests CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test

xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=2ACFE418-44EC-4A44-9B2A-1B45BDF1EF38' \
  -derivedDataPath /tmp/AvelaCodexMVP -parallel-testing-enabled NO \
  -only-testing:AvelaUITests/MVPFlowTests/testMomentumShowsRecordedFactsAndOptionalReasonSurvivesRelaunch \
  -only-testing:AvelaUITests/MVPFlowTests/testCompanionChoiceAndVisibilitySurviveRelaunch \
  -only-testing:AvelaUITests/MVPFlowTests/testRecoveryCardToolsKeepSmallerActionsSeparateAndCancellationSafe \
  -only-testing:AvelaUITests/MVPFlowTests/testRecoveryChoicesRequireConfirmationAndSmallerLoggerDoesNotAutoSave \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test

xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/AvelaDictationRelease \
  CODE_SIGNING_ALLOWED=NO build
```

## Remaining verification

Physical VoiceOver/focus, small-device/large-text visual review, OLED/dark appearance, Increase Contrast and energy checks remain needed. No new dark/AX3 or physical-device evidence is claimed for this slice. Signed distribution, CloudKit provisioning, real purchases and native integration delivery remain separate release gates. No AI, third-party dependency, new permission or extra tab was added.
