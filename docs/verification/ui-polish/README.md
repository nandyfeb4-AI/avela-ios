# Native UI polish

Implemented 2026-10-06 on the working SwiftUI app. Screenshots use synthetic DEBUG records in an isolated iPhone 18 Pro Max simulator; they are native captures, not browser mockups.

## What changed

- Today: consistent habit/attention icon tiles, more readable metadata, quieter recovery-count copy in place of the repeated Rebuilding prefix/warning treatment, clearer section heading and order control.
- Habit detail: identity and facts first, then Explore Progress and Support Your Habit; Log Progress/Make Room replace long visual tool titles while stable actions and spoken descriptions remain.
- Logging/lifetime: stronger progress hierarchy, themed quick buttons, shorter explanatory text and clearer quantity/milestone rows.
- Insights/review/History: coherent cards, readable outcomes and fewer competing icons; all factual/provenance distinctions remain.
- Settings: grouped Quick Logging, Personalize, Your Habits and Privacy & Data, consistent symbol tiles and concise footers.
- Attention/session/reflection/onboarding/calendar: matching header rhythm, onboarding progress markers, quieter routine recovery styling and a surfaced month-navigation control.
- Shared native screens: restrained theme gradients, 52-point minimum list rows and 20-point section spacing. Reading text retains Dynamic Type; decorative icon sizes are bounded. No new motion, schema, data handling, permission or dependency.

## Screens

| Native screen | Light | Dark |
| --- | --- | --- |
| Today | [Open](today.png) | [Open](today-dark.png) |
| Habit detail | [Open](habit-detail.png) | [Open](habit-detail-dark.png) |
| Logging | [Open](logging.png) | [Open](logging-dark.png) |
| Insights | [Open](insights.png) | [Open](insights-dark.png) |
| History | [Open](history.png) | [Open](history-dark.png) |
| Settings | [Open](settings.png) | [Open](settings-dark.png) |
| Lifetime at AX3 | [Open](lifetime-ax3-light.png) | [Open](lifetime-ax3-dark.png) |
| Review at AX3 (scrolled) | [Open](review-ax3-light.png) | [Open](review-ax3-dark.png) |

## Evidence boundaries

The full 454-unit suite passes, including recovery-copy and nine-theme contrast checks. Native feature flows verify navigation, logging/Undo, relaunch, privacy, purchase presentation/restore access, attention/session controls, calendar and reflection. Fourteen distinct affected UI flows pass; the screen tour and largest-text review navigation also pass when repeated in dark appearance. Debug simulator and unsigned iPhoneOS Release builds succeed. DEBUG store/fixture hooks are absent from the Release executable, with production symbols checked as a sanity control. Project integrity confirms 200 Swift files with zero issues. The entire UI suite was not rerun.

Two UI assertions initially assumed offscreen Settings/large-text review rows already existed. Tests now reveal those rows before checking them. Native compiler verification also caught an intermediate unsupported Section initializer, which was corrected. These checks do not establish physical VoiceOver quality, private-user usability or award readiness.

This pass is focused on the main iPhone screens and shared native presentation. Existing original companion art and Widget/Watch/Live Activity layouts remain separate surfaces. Signed integration, OLED and physical accessibility gates continue to apply.

## Reproduction and logs

Use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. The dedicated simulator was `2ACFE418-44EC-4A44-9B2A-1B45BDF1EF38`; discover an available iPhone simulator on another machine rather than copying this UUID.

```sh
xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UUID>' \
  -derivedDataPath /tmp/AvelaCodexMVP -parallel-testing-enabled NO \
  -only-testing:AvelaTests CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test

xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UUID>' \
  -derivedDataPath /tmp/AvelaCodexMVP -parallel-testing-enabled NO \
  -only-testing:AvelaUITests/MVPFlowTests/testPolishedCoreScreensKeepNavigationAndRecoveryReadable \
  -only-testing:AvelaUITests/MVPFlowTests/testProgressReviewRemainsNavigableAtLargestText \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test

xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/AvelaCalendarThemesRelease CODE_SIGNING_ALLOWED=NO build
```

Dark checks use `xcrun simctl ui <SIMULATOR_UUID> appearance dark` before the targeted run and restore `appearance light` afterward. Native XCTest attachments were exported with `xcresulttool export attachments`.

Local logs: `/tmp/avela-polish-test.log` (454 units and initial seven successful UI flows), `/tmp/avela-polish-final-ui.log` (seven successful follow-up UI flows), `/tmp/avela-polish-dark.log` (two repeated dark checks), `/tmp/avela-polish-release-final.log` (Release build). The initial run also contained the two offscreen assertion failures described above; both pass in the follow-up run.

At AX3, content deliberately wraps and scrolls; the review screenshot is a scrolled portion, not a full-page rendering. This verifies bounded navigation and legibility, not every accessibility setting or a physical-device audit.
