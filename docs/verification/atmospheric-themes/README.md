# Atmospheric themes and action-focused Today

Native iPhone 18 Pro Max / iOS 27 simulator screenshots, 2026-10-06. All records are synthetic DEBUG fixtures in isolated stores. No owner store was used.

## Implemented

- Nine existing themes now have complementary page atmosphere, neutral reading cards, colored controls/progress and original static landscape previews.
- Calendar headers add clouds, a sun/moon and layered coast, mountain, hill or forest scenery in a separate band below the factual summary. Success ribbons and weekly outcomes still use the existing historical calculator.
- Today shows summaries and habits before routines and a compact companion. The first habit action is checked as visible without scrolling in the populated fixture.
- Habit identity uses curated symbol colors consistently across Today, detail, History, archived habits and setup. Colors do not change completion meaning, inferred category or stored data.
- Scenery is hidden from assistive navigation, non-interactive, omitted from AX calendars and hidden with Increase Contrast. Existing Reduce Motion, Undo, haptics, consent and manual-provenance behavior remains.

These changes complete the first coordinated design pass (priorities 1–4). Existing recovery, feedback, review and companion features are retained; this does not introduce a new recovery-card model, an expanded companion view or additional feature screens.

## Native gallery

| Screen | Light | Dark |
| --- | --- | --- |
| Tidewater Today | [Open](today-tidewater-light.png) | [Open](today-tidewater-dark.png) |
| Today with manual attention | [Open](today-attention-light.png) | [Open](today-attention-dark.png) |
| Indigo Today | [Open](today-indigo-light.png) | [Open](today-indigo-dark.png) |
| Illustrated Indigo calendar | [Open](calendar-indigo-light.png) | [Open](calendar-indigo-dark.png) |
| Landscape theme picker | [Open](theme-picker-light.png) | [Open](theme-picker-dark.png) |
| Habit detail | [Open](habit-detail-light.png) | [Open](habit-detail-dark.png) |
| History | [Open](history-light.png) | [Open](history-dark.png) |
| Insights | [Open](insights-light.png) | [Open](insights-dark.png) |
| Settings | [Open](settings-light.png) | [Open](settings-dark.png) |
| Logging | [Open](logging-light.png) | [Open](logging-dark.png) |

Calendar screenshots show the header and a portion of the scrollable month. Dates remain informational/read-only. Scenery is decorative, not a visualization of the user's actual weather, location or progress.

## Changed implementation

`Core/UI/AppPalette.swift` (neutral surfaces, sky stops and ThemeLandscape), `Core/UI/AppColor.swift` (HabitIconBadge), `Features/Habit/UI/TodayView.swift`, `HabitDetailView.swift`, `HabitCalendarView.swift`, `HabitFormView.swift`, `ArchivedHabitsView.swift`, `Features/History/HistoryView.swift`, `Features/Companion/UI/CompanionView.swift`, `Features/Settings/UI/AppThemeView.swift`. Tests: `AppThemeTests.swift`, `MVPFlowTests.swift`. Existing source files contain the reusable native renderer; no project memberships were added.

## Verification

**455 unit tests, zero failures; seven distinct affected UI flows, zero failures** (nine UI executions: three in light, six in dark, with two repeated flows). Debug simulator and unsigned iPhoneOS Release builds succeed. DEBUG store/fixture/recovery markers are absent from the Release executable, with ThemeLandscape production symbols checked as a sanity control. Project integrity: 200 Swift sources, zero issues. Whitespace checks pass.

The existing contrast test now includes every theme's sky stop and neutral surfaces; one new unit test measures identity-symbol contrast against its composited tile on native/custom surfaces. The immersive UI test now asserts the first habit action is immediately visible. Additional UI coverage verifies theme persistence/read-only calendar, core screen navigation, AX3 review, AX3 weekly calendar, completion/Undo/relaunch, AX3 avoidance creation, and companion selection/visibility/relaunch.

Supplementary dark captures: [AX3 calendar header](calendar-ax3-dark.png), [reachable weekly outcome at AX3](weekly-outcome-ax3-dark.png), [lifetime milestone](lifetime-milestone-dark.png), [companion selection](companion-selection-dark.png). Light AX3 captures: [lifetime](lifetime-ax3-light.png), [weekly review](review-ax3-light.png).

Logs: `/tmp/avela-landscape-test.log`, `/tmp/avela-landscape-dark.log`, `/tmp/avela-landscape-release-final.log`. Result bundles: `/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.06_18-03-43--0600.xcresult` and `/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.06_18-07-17--0600.xcresult`.

The entire UI suite was not rerun. Physical OLED, VoiceOver focus, Increase Contrast and private usability checks remain pending. No claim of adherence improvement, completed market validation or award readiness. Watch/widget/Live Activity layouts and signed cloud/device integration gates remain unchanged.

## Reproduction

Set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, discover an available iPhone simulator and replace `<SIMULATOR_UUID>` below. The isolated device used here was `2ACFE418-44EC-4A44-9B2A-1B45BDF1EF38`.

```sh
xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UUID>' \
  -derivedDataPath /tmp/AvelaCodexMVP -parallel-testing-enabled NO \
  -only-testing:AvelaTests \
  -only-testing:AvelaUITests/MVPFlowTests/testImmersiveThemeAndStreakCalendarPreserveReadOnlyHistory \
  -only-testing:AvelaUITests/MVPFlowTests/testPolishedCoreScreensKeepNavigationAndRecoveryReadable \
  -only-testing:AvelaUITests/MVPFlowTests/testProgressReviewRemainsNavigableAtLargestText \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test

xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/AvelaCalendarThemesRelease CODE_SIGNING_ALLOWED=NO build
```

Dark appearance uses `xcrun simctl ui <SIMULATOR_UUID> appearance dark`, restored to light after the selected UI run. The supplementary dark checks cover the immersive/calendar and core-screen tour again, plus weekly-calendar AX3, lifetime completion/Undo/relaunch, avoidance creation at AX3, and companion preference/visibility/relaunch. Captures are unmodified native XCTest attachments exported with `xcresulttool export attachments`.
