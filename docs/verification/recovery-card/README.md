# Recovery card and accessible Undo

Native implementation evidence for the owner-approved recovery presentation slice, 2026-10-06.

## Behavior

Today keeps logging first and groups recovery for active habits due today into one Build Momentum card. Three restrained segments accompany the factual count. Daily/weekly recovery uses the existing period units; mixed runs use commitments. Habit rows keep schedule or quantity context instead of repeated recovery captions. Spoken row context retains recovery.

View Progress opens the existing detail screen. Make It Easier appears only when the existing calculator proposes a lighter schedule, and the existing save flow revalidates the proposal. Smaller Action appears for positive habits with a configured action and opens the existing activity screen with that section first. Neither navigation nor separate effort logging completes the habit. Reminder scheduling synchronizes after an accepted schedule change.

Completing the third commitment from Today shows “Momentum restored for [habit]” through the existing logging confirmation. Undo targets the exact completion fact and restores the recovery projection. At accessibility text sizes, VoiceOver or Switch Control, confirmation stays until dismissal/navigation or a subsequent action. The accessibility layout keeps Undo and Dismiss together, without a decorative checkmark consuming a separate line. No new celebration or recommendation engine.

## Screenshots

| Native state | Light | Dark |
| --- | --- | --- |
| Recovery card, two successful days | [Light](recovery-card-light.png) | [Dark](recovery-card-dark.png) |
| Existing smaller-action tool opened from card | [Light](smaller-action-light.png) | [Dark](smaller-action-dark.png) |
| Third success and reachable Undo at AX3 | [Light](recovery-undo-ax3-light.png) | [Dark](recovery-undo-ax3-dark.png) |
| Recovery restored after Undo, scrolled into view at AX3 | [Light](recovery-card-ax3-light.png) | [Dark](recovery-card-ax3-dark.png) |

Screenshots are unmodified XCTest attachments from an isolated current-day fixture. Ordinary captures use the original theme; AX3 means the largest accessibility text category. Scrolled AX3 captures deliberately show the card instead of pretending it fits above the fold.

## Changed files

Production: `Features/Habit/UI/TodayViewModel.swift`, `TodayView.swift`, `Features/HabitActivity/UI/HabitActivityView.swift`. Existing files hold the typed projection, card/support entry points and optional prioritized smaller-action section. Debug fixture: `App/DebugFixtures.swift`. Tests: `TodayViewModelTests.swift`, `MVPFlowTests.swift`. No project memberships, storage migrations, permissions, dependencies, AI or purchase-policy changes.

## Verification

458 unit tests pass; five distinct affected UI flows pass, with eight successful UI executions across light/dark and AX3. Debug simulator and unsigned iPhoneOS Release builds succeed. The entire UI suite was not rerun. Release binary contains zero matches for the test-store override, fixture environment variable, DebugFixtures or seedRecoveryProgress, with 27 production TodayRecoveryDisplay symbol matches as a sanity control. Project integrity: 200 Swift sources, zero issues; plutil and whitespace checks pass.

Three new unit checks cover projection/Undo, mixed units and positive-only support. Two new UI checks cover support cancellation/separate effort/relaunch and threshold Undo at AX3. Existing core-screen tour, quantity/smaller-action and lifetime/Undo/relaunch checks also pass. Initial UI failures revealed that the card needed an explicit accessibility container; AX screenshot capture also needed to scroll the card into view. Both were corrected. The large Today view's modifier chain was split from its content to stay within Swift compiler type-checking limits.

Logs: `/tmp/avela-recovery-tests.log` (458 units), `/tmp/avela-recovery-ui.log` (two light flows), `/tmp/avela-recovery-regression.log` (458 units and five dark flows), `/tmp/avela-recovery-ax-light.log` (updated light AX3 capture), `/tmp/avela-recovery-release.log`. Passing result bundles use the prefix `/tmp/AvelaCodexMVP/Logs/Test/`: `Test-Avela-2026.10.06_18-25-49--0600.xcresult`, `Test-Avela-2026.10.06_18-27-27--0600.xcresult` and `Test-Avela-2026.10.06_18-32-06--0600.xcresult`.

### Reproduction

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UUID>' \
  -derivedDataPath /tmp/AvelaCodexMVP -parallel-testing-enabled NO \
  -only-testing:AvelaTests \
  -only-testing:AvelaUITests/MVPFlowTests/testRecoveryCardToolsKeepSmallerActionsSeparateAndCancellationSafe \
  -only-testing:AvelaUITests/MVPFlowTests/testRecoveryCompletionUndoAtAccessibilityTextSize \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test

xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/AvelaCalendarThemesRelease CODE_SIGNING_ALLOWED=NO build
```

The isolated device was `2ACFE418-44EC-4A44-9B2A-1B45BDF1EF38`. Dark appearance uses native `simctl ui`; the simulator was restored to light. No owner store/device was used. Physical VoiceOver focus, Switch Control and device usability checks remain release work; simulator results do not establish adherence improvement or award readiness.
