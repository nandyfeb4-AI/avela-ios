# Visual weekly review — 2026-10-06

Native implementation evidence for the owner-approved Insights/analytics polish. No metric, schema, permission, dependency or AI changes.

## What changed

- Equal-weight habit consistency ring with the actual selected completed-week percentage.
- Separate neutral highlights preserving balanced weeks, all ties and selected-week misses.
- Habit-by-habit bars showing exact successful/resolved commitments, current icon identity and explicit archived status. Daily schedules count days; flexible schedules count weeks. Counts are not pooled into the overall score.
- Comparable-cohort trend with an explanation that its group may differ from the overall score. No fabricated intermediate points or forecast chart.
- Separate manual attention performance and logging-coverage bars. Unlogged days remain unknown. The existing threshold treats usage at 100% of budget as exceeded, so the result is labeled **below budget** consistently.
- Habit bars open state-owned native detail screens with working filtered History navigation. Opening reviews/details does not log success. Existing support/edit actions stay explicit.
- Session-only goals no longer display a phantom attention budget. Intention review and completed-week navigation remain available.
- Neutral metadata colours, outlined bar tracks and static charts. Accessibility labels state values and destinations; large text stacks the summary and scrolls instead of truncating an entire dashboard.

## Screenshots

| Native state | Light | Dark |
| --- | --- | --- |
| Weekly summary and highlights | [Light](summary-light.png) | [Dark](summary-dark.png) |
| Daily/weekly habit breakdown with archived history | [Light](habits-light.png) | [Dark](habits-dark.png) |
| Manual result versus logging coverage | [Light](attention-light.png) | [Dark](attention-dark.png) |
| Summary at AX3 | [Light](summary-ax3-light.png) | [Dark](summary-ax3-dark.png) |
| Reachable habit row at AX3 | [Light](habits-ax3-light.png) | [Dark](habits-ax3-dark.png) |

Regression states: [balanced week](balanced-dark.png), [all ties named](ties-dark.png), [unavailable comparison](unavailable-trend-dark.png).

These are unmodified XCTest attachments, using the real public repositories in an isolated DEBUG store. The populated fixture has four habits with a rounded 68% equal-weight average. Manual usage is logged on three of seven eligible goal-days; one is below budget, one over and one exactly at budget, giving 33% below budget and 3/7 coverage. AX3 is the largest accessibility text category. Its content is intentionally scrollable; a screenshot is not a claim that every metric fits above the fold.

## Files changed

Production: `Avela/Features/Insights/InsightsView.swift`, `InsightsViewModel.swift`, `Avela/App/AppShellView.swift`. Debug-only fixture: `Avela/App/DebugFixtures.swift`. Tests: `AvelaTests/Insights/InsightsViewModelTests.swift`, `AvelaUITests/MVPFlowTests.swift`. Existing source files hold the native vector charts and state-owned destination; no target memberships were added. MVP, design, UX, data-model, testing, setup, compliance, build plan and README indexes were updated.

## Verification

460 unit tests pass. Nine distinct affected UI flows pass, covering the two new populated/AX3 journeys plus seven existing Insights checks (empty/insufficient, week navigation, populated rankings, balanced results, ties, valid trend and incompatible comparison). Populated flows were additionally checked in light and dark; final wording was checked through the full chart/detail/History/relaunch journey in both appearances. The entire UI suite was not rerun.

Two new unit tests prove archived identity/read-only detail navigation and session-only budget-card exclusion. Two new UI tests exercise exact ratios, separate manual coverage, archived weekly commitments, detail/filtered History/relaunch and largest text. Initial checks caught an accessibility grouping that stripped the native chart-link button role; removing the unnecessary grouping restored native interaction. The exact-budget fixture also caught incorrect new “at or below” copy; existing threshold behavior was preserved and copy corrected.

Debug simulator and unsigned iPhoneOS Release builds succeed. Release binary contains zero matches for `AVELA_UI_TEST_STORE_PATH`, `AVELA_UI_TEST_SEED_FIXTURE`, `DebugFixtures` and `seedVisualInsights`; 100 production `InsightsHabitDestination` symbol matches provide a sanity control. Project integrity: 200 Swift sources, zero issues. `plutil` and whitespace checks pass.

Logs: `/tmp/avela-visual-insights-final.log` (460 units and nine dark UI flows), `/tmp/avela-visual-insights-light.log` (two light UI flows), `/tmp/avela-visual-insights-copy-light.log`, `/tmp/avela-visual-insights-copy-dark.log` (final visible copy/navigation), `/tmp/avela-visual-insights-release-final.log`.

## Reproduction and limits

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UUID>' \
  -derivedDataPath /tmp/AvelaCodexMVP -parallel-testing-enabled NO \
  -only-testing:AvelaTests \
  -only-testing:AvelaUITests/MVPFlowTests/testVisualInsightsShowsExactCommitmentsCoverageAndReadOnlyNavigation \
  -only-testing:AvelaUITests/MVPFlowTests/testVisualInsightsAtLargestTextKeepsChartsAndControlsReadable \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test

xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/AvelaCalendarThemesRelease CODE_SIGNING_ALLOWED=NO build
```

Dedicated simulator: `2ACFE418-44EC-4A44-9B2A-1B45BDF1EF38`. Appearance uses `simctl ui`, restored to light after verification. No owner store/device was used. Fixture `visualInsights` is guarded by the existing empty redirected-store requirement and compiled out of Release.

Physical VoiceOver focus, small-device usability, OLED and Increase Contrast checks remain pending. Charts summarize the existing completed-week metrics; they do not add multi-month trends, automatic attention measurement, causal recommendations or AI analysis. Private user validation and award readiness are not established by these simulator checks. No commits or pushes.

Passing result bundles under `/tmp/AvelaCodexMVP/Logs/Test/`: `Test-Avela-2026.10.06_18-54-48--0600.xcresult` (units/dark regression), `Test-Avela-2026.10.06_18-58-34--0600.xcresult` (light/AX3), `Test-Avela-2026.10.06_19-00-53--0600.xcresult` and `Test-Avela-2026.10.06_19-02-04--0600.xcresult` (final copy in light/dark).
