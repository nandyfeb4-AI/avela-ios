# Development Setup

## Habit ideas verification — 2026-10-05

New Habit → Browse Habit Ideas opens the optional local catalog. Today and
onboarding share the same form. Selecting an idea fills draft fields; edit them
and tap Save to create a normal habit. Back and Cancel do not create records.
No Health connection, reminder, permission prompt or additional package is added
by choosing an idea.

`/tmp/avela-starter-final-tests.log` records **285 unit + 4 targeted UI tests,
zero failures** on the separate iPhone 18 Pro Max simulator. The UI methods are
`MVPFlowTests/testHabitIdeaCanBeCustomizedSavedAndEditedAfterRelaunch`,
`MVPFlowTests/testBrowsingIdeasAndCancellingDoesNotCreateAHabit`,
`MVPFlowTests/testAvoidanceIdeaKeepsHonestSuccessCopyAtLargeText`, and the existing
`AvelaUITests/testCreatingADailyHabitShowsItInTheTodayList`. Use the Debug command
in the integrations section below with these `-only-testing:` selections and
`-only-testing:AvelaTests`. This is focused UI coverage, not the full UI suite.

The first native AX3 run failed because a long introduction pushed the search
result behind the keyboard. Its video was examined; the introduction was
shortened/hidden during filtering and interactive keyboard dismissal added.
The three starter flows then passed. Native screenshot review also prompted a
bounded decorative-icon size and plain-language cut-down copy; text still scales
through AX3. `/tmp/avela-starter-visual-check.log` records all three focused reruns passing.
Final native screenshot attachments were exported to
`/tmp/AvelaStarterPolishedCaptures` and visually reviewed.
`/tmp/avela-starter-release.log` records unsigned iPhone SDK Release compilation.
No schema/entitlement change is introduced by the library. Project membership
checks found both new source files correctly registered; DEBUG hooks remain
absent in Release. Real-device VoiceOver, dark-mode/Increase Contrast and older
supported-iOS checks are not established by these screenshots or test results.

## Native logging integrations — 2026-10-04

Siri/Shortcuts actions are bundled in the app target, with extracted App Intents
metadata and no separate writer/extension. Run the app once, then open Settings
→ Siri & Shortcuts or find Avela in Apple's Shortcuts app. Select the exact habit
or daily budget and parameters. “Log a habit in Avela” and “Log attention in
Avela” are the advertised Siri phrases. Habit logging is idempotent; each minute
invocation adds a self-reported entry. Actions deliberately open Avela and require
local authentication; fully background execution is not supported.

Apple Health is optional: active Build Up habit detail → Apple Health → choose
steps or exercise minutes and a target → Connect. Read permission is requested
only there. The app entitlement enables HealthKit, with a read usage description;
for physical-device signing, enable HealthKit on the production app ID/profile.
The widget target receives no HealthKit entitlement. Simulator compilation does
not verify account provisioning or real Health source aggregation.

No accessible samples does not prove read denial or measured zero. Test both
permission denial/revocation and real steps/exercise on a signed device. Avela
checks today's data on foreground/Refresh, not continuously while suspended.
Disconnect stops new imports while preserving history; a still-connected target
may reimport after undo. No raw samples, Health writes, background delivery,
third-party dependencies or network secrets are used. The added optional
connection model has a disk-store migration regression; **do not reset a current
MVP store** just to add this feature. Old pre-Habit scaffold resets below concern
only the original throwaway schema.

## Integration verification evidence — 2026-10-04

Separate iPhone 18 Pro Max / iOS 27 simulator used for this pass:
`2ACFE418-44EC-4A44-9B2A-1B45BDF1EF38`. The owner's booted iPhone 18 Pro was not
used or reset. Discover a currently available destination rather than copying
these historical UUIDs blindly.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=2ACFE418-44EC-4A44-9B2A-1B45BDF1EF38' \
  -derivedDataPath /tmp/AvelaCodexMVP -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- \
  -only-testing:AvelaTests -only-testing:AvelaUITests/MVPFlowTests test

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Avela.xcodeproj -scheme Avela -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/AvelaIntegrationsRelease CODE_SIGNING_ALLOWED=NO build
```

`/tmp/avela-integrations-final-tests.log`: 284 units and all 10 MVP UI flows
passed, including Health setup, Shortcuts guide, skip/relaunch, sessions, native
Live Activity, onboarding, companion and privacy/Premium flows. After safe Health
fetch-error handling, the extra error regression and parameter-registration
polish, `/tmp/avela-integrations-recheck.log` records **285 units + 4 focused UI
checks**, all passing. Those four are Health setup, Shortcuts guide, habit
completion/undo and attention quick-log/undo. This is 12 distinct UI methods over
the two runs; no claim of a full rerun of every older UI method.

`/tmp/avela-integrations-registration-check.log` reruns all units and the guide
after moving suggestion refresh to app startup/guide opening rather than every
persistence write. `/tmp/avela-integrations-release.log` records the final unsigned
iPhone SDK Release build. Binary inspection found no test store, seed fixture or
Live Activity test hooks; bundled Info.plist has the Health read purpose and
`Metadata.appintents` contains extracted actions. Project membership checks found
all 9 new Swift files correctly registered. Setup screenshot attachments were
exported to `/tmp/AvelaIntegrationNativeCaptures` and visually reviewed.

An initial StoreKit run on the fresh simulator failed native product loading;
rechecking after it initialized passed all three native StoreKit tests and the
subsequent complete unit runs. No StoreKit code was changed to hide the failure.
The unit host also emitted `LinkDaemon` parameter-refresh errors during an
attempt to register on every persistence write. That broad hook was removed;
system discovery and spoken Siri are still unverified, irrespective of passing
logging service tests or compiled metadata. Real Health data/permission behavior
also needs a signed device. No distribution archive/upload occurred.

## Required

- macOS capable of running the current stable Xcode
- current stable Xcode
- Apple Developer account for device testing and distribution
- Git

## No third-party backend required

V1 core product does not require:
- Supabase
- Firebase
- custom server
- external database

## No package install required initially

Start the project with Apple SDK frameworks only.

Expected imports may include:

```swift
import SwiftUI
import SwiftData
import Foundation
import UserNotifications
import StoreKit
import WidgetKit
import ActivityKit
import AppIntents
import HealthKit
```

Future optional imports:

```swift
import FamilyControls
import DeviceActivity
import ManagedSettings
import CloudKit
```

## Xcode targets

Recommended:
- Main iOS app
- Unit test target
- UI test target
- Widget extension
- Live Activity extension if shipped in V1

## Capabilities

Enable only when implementation needs them.

Possible:
- App Groups for app/widget shared state
- Push Notifications only if eventually needed; local reminders do not require remote push
- iCloud only when sync is implemented
- Family Controls only when Screen Time integration work begins

## Signing

Use development signing for local device testing.

App Store distribution setup should be done before TestFlight release.

## Local configuration

Do not store secrets in source control.

V1 should ideally have no runtime secrets.

## First build goal

A clean project that:
- launches
- displays Today shell
- initializes SwiftData
- persists a temporary scaffold record (habit models are deferred to Phase 1)
- runs tests

## Phase 0 project configuration

- Project: `Avela.xcodeproj`; shared scheme: `Avela`.
- Deployment target: iOS 17.0 for app, widget, and test targets (SwiftData minimum).
- Swift language mode: Swift 5, with Swift 5.9-or-newer syntax. Use the current
  stable full Xcode installation, with an iOS SDK and simulator runtime; Command
  Line Tools alone cannot build or run the iOS app. The project uses a conventional
  group-based project format compatible with Xcode 15 and later.
- Supports iPhone and iPad; light/dark appearance follows the system.
- Bundle identifiers are development placeholders: `com.example.Avela`,
  `com.example.Avela.widget`, `com.example.AvelaTests`, and
  `com.example.AvelaUITests`. Replace them before distribution.
- Automatic signing is configured with no team committed. Simulator builds need
  no team. For device builds, select your development team for both app and widget
  in Signing & Capabilities and choose unique bundle identifiers.
- No optional entitlements or permission prompts are enabled. App Groups, iCloud,
  Screen Time, notifications, StoreKit, and Live Activities are deferred. SwiftData
  explicitly uses a local store without CloudKit.
- Live Activity presentation can later share the WidgetKit extension; no dedicated
  Live Activity target is created.
- Phase 0 saved one temporary `ScaffoldRecord` on first initialization instead of
  seeding a habit, deliberately keeping Phase 0 outside the canonical product
  schema. Phase 1 replaced that schema with the canonical models and removed the
  seed entirely; see "Phase 1 store transition" below. Reopening a disk store
  remains covered by a unit test.

### Build and test

Open the project in Xcode, select **Avela**, and choose an installed iPhone
simulator. Run with Cmd-R and test with Cmd-U. The shared scheme includes both test
bundles and builds the embedded widget through the app's target dependency.

From the repository root:

```sh
# Select the installed full Xcode for this terminal session if xcode-select
# still points to Command Line Tools. This does not change the system default.
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -version
xcodebuild -list -project Avela.xcodeproj
xcrun simctl list devices available
xcodebuild -project Avela.xcodeproj -scheme Avela \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/AvelaDerivedData CODE_SIGNING_ALLOWED=NO build
```

Use an available simulator UUID from `simctl` for tests (replace `SIMULATOR_UUID`):

```sh
xcodebuild -project Avela.xcodeproj -scheme Avela \
  -configuration Debug -destination 'platform=iOS Simulator,id=SIMULATOR_UUID' \
  -derivedDataPath /tmp/AvelaDerivedData CODE_SIGNING_ALLOWED=NO test
```

Unit tests check shell destinations, empty canonical SwiftData initialization,
disk persistence across container recreation, repository operations, historical
configuration revisions, scheduling, and calendar/time-zone boundaries. The UI
smoke test checks all four tabs and a clean app relaunch. Habit UI flow tests are
deferred until the views consume the repository.

For manual scaffold verification, launch, visit each tab, relaunch, and check light
and dark appearance and larger Dynamic Type sizes. Add the Avela Scaffold widget
to the simulator Home Screen to inspect the intentional development placeholder.

### Initial validation environment

The scaffold was created on a machine with Command Line Tools (Swift 6.3.1) but no
full Xcode or simulator runtime. Project/plist validation and Swift parsing can be
performed here; iOS compilation, XCTest, and UI verification require full Xcode.
Do not interpret these static checks as a passing iOS build or test run.

Phase 1 (canonical Habit/Completion/Skip models and the SwiftData repository) was
also implemented on a Command-Line-Tools-only machine with no full Xcode and no
`simctl`/simulator runtime available (confirmed via `xcode-select -p`, `xcodebuild
-version`, and `xcrun simctl`, and by searching `/Applications` for an Xcode
install). `xcodebuild build`/`test` could not be run. As a substitute, the new
pure-Foundation domain types (`Avela/Features/Habit/Domain`, `Avela/Core/Utilities`)
were type-checked directly with `swiftc` against the macOS SDK, and the new
SwiftData-backed files (`Avela/Features/Habit/Data`, `AppPersistence.swift`) were
parsed for syntax errors; full semantic checking of `@Model`/`#Predicate` macro
expansion requires Xcode's bundled `SwiftDataMacros` plugin, which Command Line
Tools does not ship. The `project.pbxproj` changes that add these files to the
`Avela` and `AvelaTests` targets were validated with `plutil -lint` and a
referential-integrity check (every file reference resolves, appears in exactly one
group, one `PBXBuildFile` entry, and the matching target's sources build phase).
None of this substitutes for an actual `xcodebuild build`/`test` run on a machine
with full Xcode and an iOS simulator runtime. That verification was subsequently
completed as recorded below.

## Phase 1 store transition: ScaffoldRecord → canonical schema

Phase 0 seeded one throwaway `ScaffoldRecord` (a UUID and a timestamp) purely to
prove SwiftData could initialize and reopen a disk store. Phase 1 replaces that
schema outright with the canonical model: `HabitRecord`,
`HabitConfigurationSnapshotRecord`, `CompletionRecord`, and `SkipRecord`
(`Avela/Features/Habit/Data`). `ScaffoldRecord.swift` has been deleted and
`AppPersistence.makeContainer` now declares only the canonical schema; it no longer
seeds any record, since an empty habit list is the expected and correct starting
state.

There is intentionally no `SchemaMigrationPlan` from the scaffold schema to the
canonical one:
- No release has shipped, so no device holds data worth preserving.
- `ScaffoldRecord` carried no product meaning — it cannot be mapped onto a `Habit`.
- Writing a one-time migration plan for a schema that exists only to be deleted
  would be exactly the kind of premature machinery AGENTS.md asks us to avoid.

Practical effect: a `ModelContainer` opening a disk store written by Phase-0 code
(where the only persisted entity was `ScaffoldRecord`) against the Phase-1 schema
is an unhandled, unsupported transition — SwiftData has no lightweight-migration
path between those two shapes. In practice `AvelaApp` already surfaces any
`ModelContainer` initialization failure through its existing "Unable to Open
Avela" fallback screen rather than crashing or silently discarding data, so the
failure mode is safe, just not self-healing.

If you have a simulator or device install from before this change, delete the app
(or use **Erase All Content and Settings** on the simulator) before installing the
Phase-1 build. This is a one-time, development-only reset; no production migration
policy is implied or needed, since there is no production data yet.

## Simulator verification — 2026-10-01

Full Xcode 27.0 (build 27A266a) and the iOS 27.0 runtime are now installed.
The system `xcode-select` still points to Command Line Tools, so verification used
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` for each command.
No developer account, signing team, or runtime secrets were needed.

Verification destination: iPhone 18 Pro simulator,
`C214E655-432E-440C-ABFC-4BAF1D6F0373` (use your own available UUID elsewhere).
The Debug app and embedded widget build passed. All 38 unit tests and the one
navigation/relaunch UI test passed, with zero failures, using:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/AvelaDerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=C214E655-432E-440C-ABFC-4BAF1D6F0373' \
  -derivedDataPath /tmp/AvelaDerivedData -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO test
```

The initial run exposed a repository-test fixture crash: the helper returned a
repository whose context outlived its local container. The test fixture now retains
the container for the whole test. `HabitRepository` is also explicitly
`@MainActor`, matching the synchronous SwiftData implementation and removing its
actor-isolation conformance warning. The full test suite passed after both fixes.
This does not add product behavior or complete Phase 1's remaining features.
Device signing, release/archive builds, older deployment-version runtimes, and
production widget behavior were not verified in this pass.

## Simulator verification — 2026-10-01 (progress metrics slice)

Re-verified with the same Xcode 27.0 / iPhone 18 Pro (`C214E655-432E-440C-ABFC-4BAF1D6F0373`)
setup and commands above, after adding `HabitProgressCalculator` (current/best
streak, consistency, recovery progress) and its test suite
(`AvelaTests/Habit/HabitProgressCalculatorTests.swift`). Build succeeded on the
first attempt.

The first test run surfaced two failures, both in the new tests, found and
fixed using real `xcodebuild test` output plus a small standalone `swiftc`
reproduction (compiled outside the Xcode project, just the touched domain
files) to isolate root cause quickly:

- A test-fixture bug: `DateInterval` range boundaries built from the test's
  "10:00 anchor" `Date` values didn't align with the midnight-aligned
  `periodStart` the calculator emits for each day/week, so a range's first day
  was silently excluded. Fixed in the test file by aligning range boundaries to
  `calendar.startOfDay(...)`.
- A genuine production bug in `HabitProgressCalculator.consistency`: it
  filtered units with `range.contains(_:)`, but `DateInterval` is a *closed*
  interval (`start...end`, inclusive of `end`), so a naturally-constructed
  range like `DateInterval(start: weekStart, end: weekStart + 7 days)` — the
  obvious way to express "this week" — would also match a unit whose period
  starts exactly at `weekStart + 7 days`, i.e. the next period. Fixed by
  comparing `periodStart` against `range.start`/`range.end` directly with
  half-open (`>=` / `<`) semantics, and locked in with a dedicated regression
  test (`testConsistencyRangeIsHalfOpenAtItsEndBoundary`).

After both fixes, all 55 unit tests (up from 38) and the one UI test passed,
with zero failures.

## Simulator verification — 2026-10-01 (archive-period history, recovery threshold, Today UI)

Re-verified with the same Xcode 27.0 / iPhone 18 Pro
(`C214E655-432E-440C-ABFC-4BAF1D6F0373`) setup and commands as above, in two
checkpoints:

1. After adding `HabitArchivePeriod` persistence and the confirmed recovery
   threshold (see DATA_MODEL.md's "Phase 1 progress metrics" and
   "Archive-period history" sections): 65 unit tests (up from 55), 0 failures,
   on the first run. Every new scenario (single pause, repeated pause cycles,
   archive/reactivate within one week, schedule-kind change during recovery)
   was independently verified with a standalone `swiftc`-compiled reproduction
   of just the touched domain files *before* being written as an XCTest case,
   since the day-by-day walk's interaction with pauses is intricate enough
   that hand-tracing alone produced at least one wrong expectation along the
   way (caught by the reproduction, not by Xcode).
2. After wiring the first real Today screen (`TodayView`/`TodayViewModel`/
   `CreateHabitView`) and adding UI tests for habit creation, completion/undo,
   flexible-weekly progress, and relaunch persistence: build succeeded on the
   first attempt. The first test run had one UI test failure —
   `app.buttons["createHabit.scheduleTypePicker"].buttons[...]` found no
   match, because a segmented `Picker` is exposed to XCUITest as
   `XCUIElementTypeSegmentedControl`, not a button; querying
   `app.segmentedControls["createHabit.scheduleTypePicker"]` instead fixed it.
   After that fix, all 65 unit tests and all 5 UI tests passed, with zero
   failures.

UI tests do not use the production app's real on-disk store: `AvelaApp` honors
an `AVELA_UI_TEST_STORE_PATH` environment variable (set per test method, to a
fresh temporary file, by `AvelaUITests.setUpWithError`) and opens that instead
when present. Without this, UI tests would read and write the same real app
store across test methods and across runs, making empty-state and
relaunch-persistence assertions unreliable. No launch argument affects a real
user's device, since that environment variable is never set outside of
`XCUIApplication.launchEnvironment`.

Device signing, release/archive builds, older deployment-version runtimes, and
production widget behavior remain unverified, as before.

## Simulator verification — 2026-10-02 (AVELA_UI_TEST_STORE_PATH fix, habit lifecycle UI)

Re-verified the previously reported baseline first (Xcode 27.0, iPhone 18 Pro
`C214E655-432E-440C-ABFC-4BAF1D6F0373`, same commands as above): 65 unit tests
and 5 UI tests passed, exactly as reported, before any change this pass.

**AVELA_UI_TEST_STORE_PATH restricted to Debug builds.** Reviewing the prior
Today slice found the environment-variable override was checked
unconditionally in every build configuration. Wrapped it in `#if DEBUG`
(`Avela/App/AvelaApp.swift`) and verified the fix directly against both
configurations' compiled output, rather than only trusting the preprocessor:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Release \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/AvelaReleaseBuild CODE_SIGNING_ALLOWED=NO build
# BUILD SUCCEEDED

# Debug builds split the app into a thin stub executable plus an
# "Avela.debug.dylib" that holds the actual compiled code; Release builds do
# not split, so the main executable is where to look in each case.
grep -ac AVELA_UI_TEST_STORE_PATH \
  /tmp/AvelaDerivedData/Build/Products/Debug-iphonesimulator/Avela.app/Avela.debug.dylib
# 2 (present, as expected in Debug)
grep -ac AVELA_UI_TEST_STORE_PATH \
  /tmp/AvelaReleaseBuild/Build/Products/Release-iphonesimulator/Avela.app/Avela
# 0 (absent — confirms the override cannot exist in a Release build)
grep -ac com.example.Avela \
  /tmp/AvelaReleaseBuild/Build/Products/Release-iphonesimulator/Avela.app/Avela
# 2 (confirms this is genuinely where the Release build's code lives, not an empty/wrong binary)
```

This is the regression coverage for the fix: an XCTest assertion running in a
Debug test target cannot observe what code exists in a *different*
configuration's binary, so the meaningful check is inspecting the actual
compiled output of each configuration, which was done above. The existing
`testPersistedHabitsSurviveRelaunch` and `testShellNavigationAndRelaunch` UI
tests continue to cover that the override still works correctly for Debug/UI
test builds (relaunch within one test method reuses the same isolated store).

**Habit lifecycle UI.** After adding `HabitDetailView`/`HabitDetailViewModel`,
`ArchivedHabitsView`/`ArchivedHabitsViewModel`, `SettingsView`, and
generalizing `CreateHabitView` into `HabitFormView` (create and edit), build
succeeded on the first attempt. The first test run surfaced one UI test
failure and nothing else:

- `testShellNavigationAndRelaunch` asserted the Settings tab still showed
  `placeholder.settings` — expected to fail, since Settings tab content was
  deliberately replaced with a real (minimal) screen in this pass. Updated the
  test to check for `settings.archivedHabitsLink` on the Settings tab instead,
  leaving Insights/History's placeholder assertions unchanged.

After that fix, using:

```sh
xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=C214E655-432E-440C-ABFC-4BAF1D6F0373' \
  -derivedDataPath /tmp/AvelaDerivedData -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO test
```

all 77 unit tests (up from 65: +9 `HabitDetailViewModelTests`, +3
`ArchivedHabitsViewModelTests`) and all 10 UI tests (up from 5: +5 covering
opening detail without completing, editing without losing prior completions,
archiving removing a habit from Today, reactivation across repeated
archive/reactivate cycles, and an archived habit surviving a relaunch) passed,
with zero failures.

## Simulator verification — 2026-10-03 (read-only History slice)

Re-verified the previously reported baseline first (same Xcode 27.0 / iPhone
18 Pro setup and commands as above): 77 unit tests and 10 UI tests passed,
exactly as reported, before any change this pass.

After adding `HistoryView`/`HistoryViewModel`, two new cross-habit
`HabitRepository` query methods (`completions(in:)`, `skips(in:)`), and a new
`HabitScheduleEvaluator.activeConfiguration(from:onKey:)` overload, the build
succeeded on the first attempt. The unit test suite (90 tests: +13 — 5 new
`SwiftDataHabitRepositoryTests` cross-habit-query cases, 8 new
`HistoryViewModelTests`) passed with zero failures on the first run.

The first full UI test run surfaced three failures, all test-code bugs, not
product bugs:

- `testHistoryHabitFilterShowsOnlyTheSelectedHabit` and
  `testViewingHistoryFromHabitDetailFiltersToThatHabit` (the first tests in
  the suite to create two habits in one test method) failed because the
  shared `createHabit` UI-test helper hardcoded tapping
  `today.emptyState.createHabitButton`, which only exists while Today's list
  is empty. Fixed by tapping the toolbar's unconditional
  `today.addHabitButton` instead, in `AvelaUITests/AvelaUITests.swift`.
- `testShellNavigationAndRelaunch` still asserted History's old placeholder
  text. Fixed by adding a `case "History":` branch checking
  `history.emptyState.title`, matching the pattern already used for
  Settings' earlier placeholder-to-real-screen transition.

After those three fixes, a second full run passed 13 of 14 UI tests; the
remaining one, `testArchivedHabitSurvivesRelaunchAndCanStillBeReactivated` (a
pre-existing test, not touched this pass), failed only on
"Timed out while evaluating UI query" after ~980 seconds of otherwise-idle
wait — not a code issue. Several *passing* tests in both this pass and the
immediately preceding baseline run intermittently took 900–1,060 seconds
instead of their normal 15–30 seconds, with the delay appearing in raw
verbose XCUITest logs as a long "Wait for `com.example.Avela` to idle" pause
immediately after launch, before any test-specific interaction runs — i.e.
before any app view code the test exercises has a chance to run at all. This
is iOS Simulator/XCUITest environmental flakiness (observed on this machine
across multiple unrelated tests and multiple runs), not a regression from
this slice. Re-running the one timed-out test in isolation immediately after
passed cleanly in 29.8 seconds, confirming it was not a real failure:

```sh
xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=C214E655-432E-440C-ABFC-4BAF1D6F0373' \
  -derivedDataPath /tmp/AvelaDerivedData -parallel-testing-enabled NO \
  -only-testing:AvelaUITests/AvelaUITests/testArchivedHabitSurvivesRelaunchAndCanStillBeReactivated \
  CODE_SIGNING_ALLOWED=NO test
```

A final combined run of the full unit+UI suite (same `test` command as
above, no `-only-testing` filter) was then performed as the closing
verification for this slice: all 90 unit tests and all 14 UI tests passed,
zero failures (`** TEST SUCCEEDED **`), though the run again showed the same
environmental pattern — four tests (two of them touching History, two
pre-existing and untouched this pass) each took 950–970 seconds instead of
their normal 10–30, and one (`testEditingHabitFromDetailUpdatesTodayWithoutLosingPriorCompletion`,
also pre-existing and untouched) took 326 seconds. All of them still passed;
nothing in this run needed a fix. Total wall-clock for the combined run was
~80 minutes, almost entirely attributable to this flakiness rather than to
History's own tests (the History-specific UI tests that ran at normal speed
in this same pass — `testHistoryRecordsSurviveRelaunch`,
`testHistoryShowsEmptyStateThenACompletionAfterSwitchingTabs` — took 22–23
seconds each). Treat any future isolated, late-appearing UI test slowdown or
timeout on this machine as this same pre-existing condition unless it
reproduces consistently or correlates with a specific code change.

## Simulator verification — 2026-10-03 (weekly habit Insights slice)

Re-verified the previously reported baseline first (same Xcode 27.0 / iPhone
18 Pro setup and commands as above, each run separately to isolate build
vs. test and unit vs. UI): the app/widget build succeeded, 90 unit tests
passed, and all 14 UI tests passed with zero failures — exactly as reported,
before any change this pass.

**Focused review, before implementing Insights.** Two existing guarantees
Insights depends on were re-confirmed with new regression tests rather than
assumed (see docs/DATA_MODEL.md's "Pre-Insights focused review" for the
detailed reasoning): `HistoryViewModelTests
.testCompletionAndSkipRangeBoundariesAgree` (completions' instant-based range
filter and skips' day-key-based range filter agree at the exact same
boundary) and `HabitProgressCalculatorTests
.testConsistencyForACompletedWeekIsUnaffectedByLaterCompletionsOrConfigurationChanges`
(a completed week's consistency is unaffected by later completions or a
later schedule change). Both passed on the first run — no bug was found or
needed fixing; these close gaps in existing coverage rather than fix defects.

**Implementation.** Added `WeeklyInsightsCalculator` (new pure domain
calculator, `Avela/Features/Insights/Domain/`), `InsightsViewModel`,
`InsightsView`, and wired a real Insights screen into `AppShellView`,
replacing the placeholder. No new `HabitRepository` methods were needed —
Insights reuses `fetchHabits`, `configurationHistory`, `archivePeriods`, and
the cross-habit `completions(in:)`/`skips(in:)` added for History. The build
succeeded on the first attempt using:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/AvelaDerivedData CODE_SIGNING_ALLOWED=NO build
```

The first unit test run surfaced one compile error, fixed immediately:
`XCTAssertEqual(_:_:accuracy:)` does not accept an optional `Double` —
`WeeklyInsightsCalculatorTests
.testOverallConsistencyIsAverageOfHabitPercentagesNotPooledAcrossHabits`
force-unwrapped `result.overallConsistency` instead (consistent with the rest
of that file's non-`throws` test methods, which already use `try!
XCTUnwrap(...)` for similar cases). After that fix, using:

```sh
xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=C214E655-432E-440C-ABFC-4BAF1D6F0373' \
  -derivedDataPath /tmp/AvelaDerivedData -parallel-testing-enabled NO \
  -only-testing:AvelaTests CODE_SIGNING_ALLOWED=NO test
```

all 112 unit tests (up from 90: +2 focused-review regression tests, +14
`WeeklyInsightsCalculatorTests`, +6 `InsightsViewModelTests`) passed with
zero failures.

**UI tests.** Added `testInsightsShowsEmptyStateThenInsufficientDataAfterCreatingAHabit`
and `testInsightsWeekNavigationMovesBetweenCompletedWeeksAndBack`, and
updated `testShellNavigationAndRelaunch`'s per-tab switch with a
`case "Insights":` checking `insights.emptyState.title` (it previously fell
through to the now-obsolete `default:` placeholder-text check). A combined
run of just the two new tests plus `testShellNavigationAndRelaunch` passed
cleanly (all three in 63 seconds total, no flakiness) before committing to
the full, slower suite:

```sh
xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=C214E655-432E-440C-ABFC-4BAF1D6F0373' \
  -derivedDataPath /tmp/AvelaDerivedData -parallel-testing-enabled NO \
  -only-testing:AvelaUITests CODE_SIGNING_ALLOWED=NO test
```

All 16 UI tests (up from 14) passed with zero failures in 339 seconds total
— no recurrence of the environmental slowness pattern documented in the
previous slice's entry in this run. Per the standing guidance above, had it
recurred it would have been treated as expected infrastructure flakiness,
not an application regression; this run simply didn't exhibit it.

**Why Insights has no UI test exercising real non-zero weekly consistency
data.** Insights deliberately never displays the in-progress current week —
only completed ones — so anything a UI test does "today" (the only time it
can act) falls in a week Insights will never show by default. Proving actual
consistency math end-to-end therefore relies on `WeeklyInsightsCalculatorTests`
and `InsightsViewModelTests`, which construct habits with past `createdAt`
dates directly through the repository (the same approach
`HistoryViewModelTests` already uses for its own past-dated fixtures). The UI
tests instead verify what *is* honestly observable from "today": the
empty-vs-insufficient-data distinction and week-navigation controls.

**Closing combined verification.** A final single `xcodebuild test` run (no
`-only-testing` filter — app/widget build plus both test bundles together)
was performed as this slice's definitive result:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=C214E655-432E-440C-ABFC-4BAF1D6F0373' \
  -derivedDataPath /tmp/AvelaDerivedData -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO test
```

All 112 unit tests and all 16 UI tests passed, zero failures
(`** TEST SUCCEEDED **`), in 337 seconds for the UI suite — again no
recurrence of the environmental slowness pattern.

## Simulator verification — 2026-10-03 (UX-audit correctness pass)

Re-verified the previously reported baseline first (same Xcode 27.0 / iPhone
18 Pro setup): 112 unit tests and 16 UI tests passed, exactly as reported,
before any change this pass.

**Insights logic fixes.** `WeeklyInsightsCalculator` was changed to (a)
restrict the week-over-week trend to a "comparable cohort" of habits — see
`docs/DATA_MODEL.md`'s "Trend comparable-cohort rules" — and (b) add
`isBalancedWeek`, suppressing the strongest/needs-attention rankings in
favor of a neutral summary when every eligible habit (including the common
single-habit case) scored identically. `InsightsView` was updated to render
the balanced summary and the new "Not enough comparable data." trend copy.
7 new `WeeklyInsightsCalculatorTests` were added; the 3 pre-existing tests
that referenced the removed `previousWeekOverallConsistency` field were
updated to assert on `trendInPercentagePoints` instead. All passed on the
first run after a single compile-time fix (an obsolete field reference).

**Archive confirmation dialog.** The prior UX audit's screenshot evidence of
this dialog was captured by an external, unsynchronized screenshot poller
and could not distinguish "still presenting" from "genuinely missing." A new
UI test, `testArchiveConfirmationCanBeCancelledLeavingTheHabitActive`, waits
for `app.buttons["Archive"]` and `app.buttons["Cancel"]` to exist before
asserting anything. First run: the test failed —
`XCTAssertTrue failed - a Cancel action must be presented alongside Archive`
— confirming the Cancel button was genuinely absent from the accessibility
tree when `HabitDetailView` presented the dialog via `.confirmationDialog`
from a row inside a `List`, not merely a capture-timing artifact. Fixed by
switching to a plain `.alert` (SwiftUI's standard native two-button
confirm/cancel presentation, not a custom overlay); the same test then
passed, confirming both actions render, cancelling leaves the habit active,
and no archive period is recorded. Screenshot evidence of both the original
and fixed dialog is in `docs/audit-screenshots/` (07 and 15).

**Populated-Insights DEBUG fixtures.** Added `Avela/App/DebugFixtures.swift`
(`#if DEBUG`-gated, five named fixtures seeding deterministic past-week data
through the existing `HabitRepository` API only) and a new
`AVELA_UI_TEST_SEED_FIXTURE` launch-environment hook in `AvelaApp.init()`,
guarded to only ever apply when `AVELA_UI_TEST_STORE_PATH` is also set.
Registered in the Xcode project and verified via the same
referential-integrity script used for every prior file addition (0 new
issues). 5 new UI tests launch with one fixture each and assert on the real
rendered summary. All 5 passed on the first run. Verified absent from
Release the same way `AVELA_UI_TEST_STORE_PATH` was originally verified:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Release \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/AvelaReleaseBuild CODE_SIGNING_ALLOWED=NO build
# BUILD SUCCEEDED

grep -ac AVELA_UI_TEST_SEED_FIXTURE /tmp/AvelaDerivedData/Build/Products/Debug-iphonesimulator/Avela.app/Avela.debug.dylib
# 1 (present, as expected in Debug)
grep -ac AVELA_UI_TEST_SEED_FIXTURE /tmp/AvelaReleaseBuild/Build/Products/Release-iphonesimulator/Avela.app/Avela
# 0 (absent)
grep -ac DebugFixtures /tmp/AvelaReleaseBuild/Build/Products/Release-iphonesimulator/Avela.app/Avela
# 0 (the type itself is compiled out entirely, not merely inert)
grep -ac com.example.Avela /tmp/AvelaReleaseBuild/Build/Products/Release-iphonesimulator/Avela.app/Avela
# 2 (confirms this is genuinely the compiled Release binary, not an empty one)
```

**Closing combined verification**, both configurations:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=C214E655-432E-440C-ABFC-4BAF1D6F0373' \
  -derivedDataPath /tmp/AvelaDerivedData -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO test
# ** TEST SUCCEEDED ** — 119 unit tests, 22 UI tests, 0 failures

xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Release \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/AvelaReleaseBuild2 CODE_SIGNING_ALLOWED=NO build
# BUILD SUCCEEDED
```

119 unit tests (up from 112: +7 `WeeklyInsightsCalculatorTests`) and 22 UI
tests (up from 16: +1 archive-cancellation, +5 populated-Insights fixtures)
passed, zero failures. Release builds cleanly with the fixture/store-path
hooks verifiably absent, confirmed by binary inspection above.

## Simulator verification — 2026-10-03 (small UX fixes: F2, F4, F5, F7, F12)

Re-verified the previously reported baseline first: 119 unit tests passed
before any change this pass (the UI-test baseline from the prior entry was
trusted from that same-day run rather than re-executed, given its ~7-minute
cost and that this pass touches none of its underlying logic).

**F4, F2, F7, F12 implementation.** `HabitFormView` gained
`.navigationBarTitleDisplayMode(.inline)`. New
`Avela/Features/Habit/UI/HabitPolarityFormatter.swift` centralizes
polarity-aware completion/status wording, used by `TodayView` and a new
`HabitDetailViewModel.todayStatusLabel` field. `HistoryView` and
`HabitDetailView`'s icon tint both became
`isArchived ? Color.secondary : Color.accentColor`. `HabitDetailViewModel`'s
current-streak zero-text became "No current streak yet." Registered
`HabitPolarityFormatter.swift` and a new `HabitPolarityFormatterTests.swift`
in the Xcode project (verified via `plutil -lint` and the referential-
integrity script — 0 new issues). The first unit test run surfaced one
expected failure: `HabitDetailViewModelTests
.testNoStreakYetWhenNothingCompleted` still asserted the old "No current
streak" string — updated to "No current streak yet." After that fix, all
125 unit tests (up from 119: +6 `HabitPolarityFormatterTests`) passed.

**F5 implementation and a floating-point test-assertion lesson.** Measured
the icon grid's actual cell size via a new UI test before changing anything:
confirmed 36×36pt, below the 44pt minimum — a real violation, not merely
"unmeasurable" as the audit had left it. Fixed with an adaptive
`LazyVGrid` (`GridItem(.adaptive(minimum: 44, maximum: 64))`) and
`minWidth`/`minHeight: 44` per icon button. The first run of
`testIconPickerTouchTargetsAreAtLeast44Points` (reading the real
`XCUIElement.frame`) failed: `43.99999999999994 < 44.0` — SwiftUI's layout
engine reporting a frame fractionally under 44 for a cell whose intended and
visually rendered size is exactly 44pt, pure floating-point representation
noise. Fixed the *test*, not the view: rounded the measured width/height to
the nearest point before comparing, which is the correct way to evaluate a
real UI measurement against an integer-point design requirement. After that
fix, both `testIconPickerTouchTargetsAreAtLeast44Points` and
`testIconPickerTouchTargetsRemainAtLeast44PointsAtLargeDynamicType` (forced
to `UICTContentSizeCategoryAccessibilityXXXL` via the
`-UIPreferredContentSizeCategoryName` launch argument, which does work
reliably on this toolchain) passed.

**Dark mode: a launch-argument approach that didn't work, and the one that
did.** Initially added an `interfaceStyle` parameter to the UI test
launcher, passing `-UIUserInterfaceStyle Dark`/`Light` as launch arguments —
the commonly-cited approach for forcing per-test appearance. Screenshot
evidence disproved it: the app rendered fully light regardless of the
argument (white backgrounds, black text), and no
`.preferredColorScheme`/`overrideUserInterfaceStyle` override exists
anywhere in the app's own code to explain the mismatch — the launch argument
itself simply had no effect on this Xcode 27/iOS 27 toolchain. Removed that
(non-functional) parameter rather than leave misleading dead code. The
*simulator's own* system appearance does work:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcrun simctl ui C214E655-432E-440C-ABFC-4BAF1D6F0373 appearance dark
xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=C214E655-432E-440C-ABFC-4BAF1D6F0373' \
  -derivedDataPath /tmp/AvelaDerivedData -parallel-testing-enabled NO \
  -only-testing:AvelaUITests/AvelaUITests/testVisualAppearanceInDarkMode \
  CODE_SIGNING_ALLOWED=NO test
# ** TEST SUCCEEDED ** — screenshot confirmed true dark backgrounds/white text
xcrun simctl ui C214E655-432E-440C-ABFC-4BAF1D6F0373 appearance light
```

`testVisualAppearanceInDarkMode` and `testVisualAppearanceInLightMode` are
therefore identical in body — each simply runs under whatever appearance the
simulator already has — which is why the dark-mode evidence for this report
required one extra, separate `-only-testing` invocation with the simulator
toggled first, rather than falling out of one hermetic full-suite run. A CI
pipeline wanting both appearances automatically would run `xcodebuild test`
twice, toggling `simctl ui ... appearance` between runs. See
`docs/audit-screenshots/21` through `24` and `29` for the resulting
light/dark/Dynamic-Type evidence, and `docs/DATA_MODEL.md`'s "Accessibility
checks that could not be performed" for the full writeup.

**Closing combined verification**, both configurations (simulator appearance
reset to light beforehand):

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=C214E655-432E-440C-ABFC-4BAF1D6F0373' \
  -derivedDataPath /tmp/AvelaDerivedData -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO test

xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Release \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/AvelaReleaseBuild3 CODE_SIGNING_ALLOWED=NO build
# BUILD SUCCEEDED
```

Release build re-verified free of the DEBUG fixture/store-path hooks by the
same binary-inspection method as before (zero matches for
`AVELA_UI_TEST_SEED_FIXTURE`, `AVELA_UI_TEST_STORE_PATH`, and
`DebugFixtures` in the Release binary; `com.example.Avela` present twice,
confirming it's the genuine compiled binary, not an empty one) — this pass
didn't touch that mechanism, so this re-check simply confirms nothing
regressed it.

## Simulator verification — 2026-10-03 (manual attention tracking slice)

Re-verified the previously reported baseline first: 125 unit tests, 0
failures, before any change this pass.

The simulator UUID was **rediscovered programmatically** rather than reused
from a prior entry's hardcoded value, per this task's explicit instruction:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
python3 - <<'EOF'
import json, subprocess
out = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"])
data = json.loads(out)
candidates = [
    (d["state"] == "Booted", d["name"], d["udid"])
    for runtime, devices in data["devices"].items() if "iOS" in runtime
    for d in devices if d["name"].startswith("iPhone")
]
candidates.sort(key=lambda c: 0 if c[0] else 1)
print(candidates[0])
EOF
# -> (True, 'iPhone 18 Pro', 'C214E655-432E-440C-ABFC-4BAF1D6F0373') — same
# device as prior entries, already booted, but found fresh rather than assumed.
```

**Implementation.** New `Avela/Features/Attention/{Domain,Data,UI}` files
implement manual attention goals and usage logging — see
`docs/DATA_MODEL.md`'s "Phase 1 Attention" section for the full, confirmed
rule set (goal-type scope, budget-snapshot history mechanism, local-day
summing, missing-data-vs-zero handling, today-only correction/deletion,
Today integration, and a `Button`+`.swipeActions` toolchain pitfall).
`AppPersistence.makeContainer` registered three new `@Model` types
(`AttentionGoalRecord`, `AttentionGoalConfigurationSnapshotRecord`,
`AttentionUsageEntryRecord`). All 17 new production Swift files and 3 new
test files were registered in `Avela.xcodeproj/project.pbxproj` by direct
script-assisted edits (new `PBXFileReference`/`PBXBuildFile` entries, three
pre-existing empty `Attention/{Domain,Data,UI}` group definitions populated
with the new file references, and the corresponding Sources build phase
entries for the `Avela` and `AvelaTests` targets) — verified with
`plutil -lint` (passed) and a referential-integrity script confirming every
on-disk `.swift` file under each target's source tree appears in exactly one
group and exactly one Sources build phase: 55/55 for `Avela`, 15/15 for
`AvelaTests`, 1/1 for `AvelaUITests`, no missing or duplicate entries. One
mid-edit mistake was caught and fixed before it reached a build: a
regex-based group-rewrite script accidentally dropped the three Attention
subgroups' own object IDs (leaving `plutil -lint` reporting a parse error at
line 1); fixed by restoring each ID from its `path` field, after which lint
passed clean.

**A real bug found and fixed via UI testing, not inferred.** The attention
goal detail screen's entry rows needed both a tap action (open a correction
sheet) and `.swipeActions` (delete). The first implementation wrapped the
row in a `Button` carrying both. `testAttentionGoalDetailShowsLoggedEntryAndAllowsCorrection`
failed twice in a row — once before, and once after collapsing the screen's
three separate sheet bindings into a single `.sheet(item:)` (a reasonable
first suspect, since the screen had three independent `isPresented` sheets
on one view) — in both cases XCUITest reported a successful tap on the
correct, uniquely-identified button, but the correction sheet's text field
never appeared within 5 seconds, confirmed by inspecting the captured
`.xcresult` accessibility-hierarchy snapshot at the moment of failure (no
second window/sheet content present at all). The same row's swipe-to-delete
worked in a separate, passing test, isolating the cause to `.swipeActions`
intercepting the row's own tap gesture ahead of the nested `Button`. Fixed
by replacing the `Button` with a plain `HStack` + `.contentShape(Rectangle())`
+ `.onTapGesture`, with `.accessibilityAddTraits(.isButton)` so the element
remains reachable via XCUITest's `app.buttons` query. Re-running first the
two affected tests in isolation, then the full UI suite, confirmed the fix.

**Final verification, both configurations:**

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
SIM_ID=C214E655-432E-440C-ABFC-4BAF1D6F0373

xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination "id=$SIM_ID" test -only-testing:AvelaTests
# ** TEST SUCCEEDED ** — 154 unit tests, 0 failures (up from 125: +29 new
# Attention tests across AttentionProgressCalculatorTests,
# SwiftDataAttentionRepositoryTests, AttentionGoalDetailViewModelTests)

xcrun simctl shutdown $SIM_ID; xcrun simctl boot $SIM_ID
xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination "id=$SIM_ID" test -only-testing:AvelaUITests
# ** TEST SUCCEEDED ** — 33 UI tests, 0 failures (up from 28: +5 new
# Attention UI tests covering create/log/status/correct/delete/persist)

xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Release \
  -destination 'generic/platform=iOS Simulator' build
# ** BUILD SUCCEEDED **
```

Release build verified free of DEBUG-only hooks by the same binary-grep
method as every prior entry — zero matches for `AVELA_UI_TEST_SEED_FIXTURE`,
`AVELA_UI_TEST_STORE_PATH`, and `DebugFixtures`; `com.example.Avela` present
8 times, confirming a genuine, non-empty binary. This slice introduced no
new DEBUG-only fixture or test-isolation mechanism of its own (unlike
Insights' `DebugFixtures`, "today" usage logging is directly reachable
through the UI without needing past-dated seed data), so there was nothing
new to verify beyond re-confirming the existing two hooks remain absent.

## Simulator verification — 2026-10-04 (Vivid Tidewater UX pass)

Re-verified the previously reported baseline first: 166 unit tests, 0
failures, before any change this pass (154 Habit/Attention + the Attention
slice's 29 new tests from the previous entry are included in that figure;
see that entry for the breakdown).

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
python3 - <<'EOF'
import json, subprocess
out = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"])
data = json.loads(out)
candidates = [
    (d["state"] == "Booted", d["name"], d["udid"])
    for runtime, devices in data["devices"].items() if "iOS" in runtime
    for d in devices if d["name"].startswith("iPhone")
]
candidates.sort(key=lambda c: 0 if c[0] else 1)
print(candidates[0])
EOF
# -> (True, 'iPhone 18 Pro', 'C214E655-432E-440C-ABFC-4BAF1D6F0373') — same
# device as every prior entry, already booted, rediscovered rather than assumed.
```

**Implementation.** 16 new named colour assets (`AccentColor` + 15 semantic
tokens) in `Resources/Assets.xcassets`, a new `Avela/Core/UI/AppColor.swift`,
a full rebuild of `TodayView.swift` into the "Tidewater Balance" layout
(pillars, collapsible Done group, undo toast, fast attention-logging chips,
recovery context on habit rows), a new `TodayHabitRow.recoveryContext` field
and `recoveryCompletionThreshold` visibility change in
`HabitProgressCalculator`/`TodayViewModel`, `AttentionSummaryViewModel`
additions (`logFixedAmount`/`undoLastQuickLog`), a new
`AttentionStatusFormatter.pillarState`/`pillarLabel` pair, a recurated
`HabitFormView` icon picker, and colour-only retinting of
`AttentionGoalDetailView`, `HabitDetailView`, and `InsightsView`. See
`docs/DATA_MODEL.md`'s "Vivid Tidewater UX pass" section for the complete,
confirmed rule set, including the explicit "never say 'On track'" resolution
of a real contradiction between the design mockup and this project's own
manual-tracking integrity rule.

**A genuine concurrency bug found by UI testing, not environmental
flakiness — this took most of this pass's validation time to isolate.**
Six UI tests that complete a habit and then immediately open its detail
screen started failing: the correct screen pushed (navigation bar, back
button all correct) but stayed on its loading spinner forever. The first
several hours of this pass's UI test runs were dominated by a *separate,
genuine* environmental problem — this machine was concurrently running a
2+ hour video call and dozens of browser tabs, and `top`/`vm_stat` showed
sustained severe memory pressure (as little as 75MB free, a 35+ one-hour
load average) during a full-suite run that took 3.2 hours and produced
`"Timed out while synthesizing event"` failures on completely unrelated,
unmodified buttons — textbook infrastructure flakiness, consistent with
this project's own prior documented precedent for this toolchain. That
confound had to be ruled out first (via a trivial, unmodified sanity test
timed at a now-fast 25 seconds) before the *remaining*, perfectly
reproducible six failures could be trusted as real. Bisection (temporarily
disabling pieces of the new code and re-running 3× for consistency at each
step) traced it to two bare `Task { }` values (the deferred-collapse timer
and the undo toast's auto-dismiss), neither scoped to the view's lifecycle.
One firing later — while the user is already on the pushed
`HabitDetailView` — mutates `TodayView`'s `@State`, forcing its `body` to
re-evaluate and re-invoke the `navigationDestination(for: UUID.self)`
closure, which constructs a **new** `HabitDetailViewModel` for the
already-displayed screen; SwiftUI does not re-run `.task` for what it still
considers the same destination, so the fresh, never-loaded view model is
what's left showing. `.onDisappear` on `TodayView` was the first fix
attempted and did **not** work — confirmed with 3 consecutive runs showing
the identical failure — because it does not reliably fire on this toolchain
when a `NavigationStack` push merely covers the root view. The working fix
cancels both tasks synchronously from each row's own tap gesture, via
`.simultaneousGesture(TapGesture().onEnded(onNavigate))` calling a new
`TodayView.prepareForNavigation()`, before the push can race either task.
Verified with 3 consecutive clean runs of the originally-failing test, then
all 6 affected tests together (0 failures), before trusting a full-suite
run. See `docs/DATA_MODEL.md`'s "Vivid Tidewater UX pass" section for the
complete bisection narrative.

**Final verification, both configurations:**

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
SIM_ID=C214E655-432E-440C-ABFC-4BAF1D6F0373

xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination "id=$SIM_ID" test -only-testing:AvelaTests
# ** TEST SUCCEEDED ** — 166 unit tests, 0 failures (unchanged from baseline;
# this pass added no new domain logic requiring its own test beyond what's
# listed above, which is covered by existing AttentionSummaryViewModel/
# TodayViewModel/AttentionStatusFormatter/HabitPolarityFormatter test files)

xcrun simctl shutdown $SIM_ID; xcrun simctl boot $SIM_ID
xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination "id=$SIM_ID" test -only-testing:AvelaUITests
# ** TEST SUCCEEDED ** — see test count and duration below

xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Release \
  -destination 'generic/platform=iOS Simulator' build
# ** BUILD SUCCEEDED **
```

Release build re-verified free of DEBUG-only hooks by the same
binary-inspection method as every prior entry: zero matches for
`AVELA_UI_TEST_SEED_FIXTURE`, `AVELA_UI_TEST_STORE_PATH`, and
`DebugFixtures`; `com.example.Avela` present 8 times, confirming a genuine,
non-empty binary.

**Screenshots.** Three new UI tests
(`testTidewaterBalancePopulatedScreenshot`,
`testTidewaterBalancePopulatedScreenshotDarkMode`,
`testTidewaterBalanceAccessibilityDynamicTypeScreenshot`) build a richer
scene than the existing light/dark tests — two habits (one done and
settled into the collapsed Done group) plus an attention goal with partial
usage logged — so the captured evidence actually shows the pillar strip,
the Done toggle, the Attention row, and the undo toast together. Dark mode
was captured the same documented way as every prior entry
(`xcrun simctl ui $SIM_ID appearance dark`, restored to `light` afterward,
since `-UIUserInterfaceStyle Dark` has no effect on this toolchain). All
three reviewed directly:

- **Light:** pillars, Done group, and the Instagram attention row with its
  "+5"/"+15"/"Other…" chips and the undo toast all render in the Vivid
  Tidewater teal, exactly as specified.
- **Dark:** the same scene with correct dark-appearance tokens throughout,
  including the toast's documented colour inversion (pale teal background,
  near-black text and Undo pill — matching `vivid.css`'s dark `toastBg`/
  `toastInk` exactly).
- **AX3 (`UICTContentSizeCategoryAccessibilityXXXL`):** habit rows reflow to
  the stacked, full-width "Mark done"/"Done" button layout per
  COMPONENT_SPEC §6, confirming large text adapts by reflowing rather than
  forcing two columns into less width. One minor, non-blocking cosmetic
  issue observed: at this extreme size the undo toast can visually overlap
  the attention row's chips underneath it; the chips remain functional once
  the toast clears 4 seconds later. Recorded as a known limitation, not
  fixed this pass.


## Integrated MVP validation (2026-10-04)

Use simulator **ad-hoc signing** for local StoreKit verification and App Group
access. It needs no developer team or paid account. Earlier unsigned scaffold
commands remain useful for compilation, but `CODE_SIGNING_ALLOWED=NO` caused
Product lookup/verified-entitlement failures in actual StoreKitTest integration.
Do not report a passing purchase test from an unsigned runtime.

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcrun simctl list devices available
xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=<AVAILABLE_SIMULATOR_UUID>' \
  -derivedDataPath /tmp/AvelaCodexMVP -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```

`Avela.storekit` is copied only into the unit-test bundle. Native local purchase,
restore, expiry and refund tests use `SKTestSession`; the scheme does not replace
real product lookup for normal app launches, TestFlight or Release builds. The
configuration's prices are test values. Real distribution requires matching
App Store Connect products and the owner's account configuration.

Both app and widget currently use placeholder App Group
`group.com.example.Avela`. Replace it consistently in both entitlements and
`WidgetSnapshotStore` before signed distribution. The app's ordinary SwiftData
store location is unchanged; widgets consume only an exported JSON projection.
The `avela` URL scheme is in `Avela/Resources/Info.plist`.

Isolated DEBUG UI tests bypass onboarding by default. Set
`AVELA_UI_TEST_ONBOARDING=1` **together with** `AVELA_UI_TEST_STORE_PATH` to test
its actual flow. No DEBUG environment hook grants Premium, and isolated test
records are not exported to the real widget container. Hooks must be absent in
the final Release binary.

See [TestFlight checklist](TESTFLIGHT_CHECKLIST.md) for physical-device,
accessibility, public privacy URL, original artwork, signing and upload gates.


### Final verification evidence — 2026-10-04

Final combined Debug run: **243 unit tests + 49 UI tests, zero failures,
`TEST SUCCEEDED`**, on iPhone 18 Pro / iOS 27.0 with Xcode 27.0.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=C214E655-432E-440C-ABFC-4BAF1D6F0373' \
  -derivedDataPath /tmp/AvelaCodexMVP -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Release \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/AvelaCodexMVP \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build
```

Combined result bundle on this machine:
`/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.04_14-33-21--0600.xcresult`.
Combined log: `/tmp/avela-codex-mvp-complete.log`. Release simulator build:
**BUILD SUCCEEDED** (`/tmp/avela-codex-mvp-release-final.log`). Temporary logs
and result bundles are local evidence, not committed repository artifacts.

Final Release simulator binary inspection finds zero occurrences of
`AVELA_UI_TEST_STORE_PATH`, `AVELA_UI_TEST_SEED_FIXTURE`,
`AVELA_UI_TEST_ONBOARDING` and `DebugFixtures`, with a production product ID
present as the positive control. Both app and widget contain
`PrivacyInfo.xcprivacy`; no `.storekit` file is shipped in the app bundle.
Project/configuration plist lint and `git diff --check` pass.

Simulator ad-hoc signatures do not establish distribution entitlements: the
inspected simulator signatures have empty entitlement dictionaries. Source
entitlements declare the matching placeholder group, but real device signing,
provisioning and shared-container access must be checked separately.

Native Today captures: [light](mvp-validation/today-light.png) and
[accessibility XXXL](mvp-validation/today-accessibility-xxxl.png). They verify
the selected teal accent and neutral text after the native visual corrections,
not real VoiceOver, keyboard or Increase Contrast operation. Earlier failed or
interrupted runs were investigated and superseded by the complete passing run;
the AX3 test-helper correction retained all assertions.

Unsigned Release build against the actual iPhone SDK also **BUILD SUCCEEDED**:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/AvelaCodexMVP CODE_SIGNING_ALLOWED=NO build
```

Log: `/tmp/avela-codex-mvp-device-release.log`. The iPhone Release binary also
passes the same DEBUG-hook, privacy-manifest and test-resource exclusion checks.
This is compilation for iPhone, not a signed archive or an executed device test.

## Illustrated companion verification — 2026-10-04

Original six-pose owl, fox and otter atlases are bundled in both app and widget.
Shared native rendering retains alpha, loads lazily per animal and caches
256-pixel poses. No new persistence schema, dependency or runtime service.

Focused integration run: **247 unit tests + 10 UI tests, 0 failures**.
The UI selection included all `MVPFlowTests` and the three Tidewater populated/
large-text capture tests. Result:
`/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.04_15-05-41--0600.xcresult`.
Log: `/tmp/avela-mascot-final-tests.log`.

After an owl-only spacing correction, this final asset check passed again:
**247 unit tests + 1 companion choice/visibility/relaunch UI test, 0 failures**.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=C214E655-432E-440C-ABFC-4BAF1D6F0373' \
  -derivedDataPath /tmp/AvelaCodexMVP -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- \
  '-only-testing:AvelaTests' \
  '-only-testing:AvelaUITests/MVPFlowTests/testCompanionChoiceAndVisibilitySurviveRelaunch' test
```

Final asset result:
`/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.04_15-18-57--0600.xcresult`;
log `/tmp/avela-mascot-v2-tests.log`. Both final Release builds succeed using the
Release commands above, logged in `/tmp/avela-mascot-v2-release-simulator.log`
and `/tmp/avela-mascot-v2-release-iphone.log`. DEBUG hook strings are absent in
both binaries; app/widget privacy manifests and widget art catalogs are present,
and no `.storekit` test resource ships in either app bundle. Plist lint and
`git diff --check` pass. These focused runs do not repeat all current UI tests.

Native final captures: [light](mvp-validation/companion-light.png),
[actual dark](mvp-validation/companion-dark.png),
[accessibility XXXL](mvp-validation/companion-accessibility-xxxl.png), and
[animal selection](mvp-validation/companion-choices.png). Light/dark/XXXL
captures use a fresh isolated DEBUG store with the populated fixture; XXXL
relaunch omits the seed variable to avoid adding the fixture twice. The test
whose name ends in `DarkMode` does not itself establish dark mode: actual dark
was set with `xcrun simctl ui <device> appearance dark` and visually confirmed.
The simulator appearance was restored to light. No real user store was used.

Physical-device OLED, VoiceOver, Reduce Motion and provisioned widget-container
checks remain release gates. Artwork transitions are pose crossfades with a
small celebration scale change, not skeletal animation. No Dynamic Island
companion/Live Activity has been added.

## Session Live Activity verification — 2026-10-04

The existing `AvelaWidget` extension now includes an ActivityKit configuration.
There is no dedicated new target, dependency, backend, push registration or
SwiftData migration. The app's Info plist has `NSSupportsLiveActivities=true`.

To try it: create a **Phone-free session** goal, start the session, and choose
**Show Session Activity**. Go Home to inspect compact Dynamic Island; long-press
it for the expanded view. Tap to return to Today and open the goal to check in.
**Hide Session Activity** removes the presentation while keeping tracking active.
Only devices/platform settings supporting Live Activities can show it.

Final source verification: **264 unit tests + 1 focused native ActivityKit UI
test, zero failures**. Seventeen added service tests use real in-memory SwiftData
repositories plus a controlled platform adapter, including suspended-dismissal
race regression. The native test creates a real ActivityKit request on the iPhone
18 Pro / iOS 27.0 simulator and verifies Show/Hide/interruption without falsely
certifying success. It was not skipped on the verified runtime.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=C214E655-432E-440C-ABFC-4BAF1D6F0373' \
  -derivedDataPath /tmp/AvelaCodexMVP -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- \
  '-only-testing:AvelaTests' \
  '-only-testing:AvelaUITests/MVPFlowTests/testPhoneFreeLiveActivityIsOptionalAndDoesNotCertifySuccess' test
```

Log: `/tmp/avela-island-complete-tests.log`. Result bundle:
`/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.04_15-50-18--0600.xcresult`.
Native final captures: [compact](mvp-validation/dynamic-island-compact.png) and
[expanded](mvp-validation/dynamic-island-expanded.png). These are actual system
UI screenshots, not browser mockups. Compact capture waits for the Island host
render after Home; the first attempted immediate capture showed an empty shell.
The optional List feedback required scrolling into view in the UI helper.

An earlier integration run also passed all eight `MVPFlowTests` (261 units at
that point), before the final layout/deadline/concurrency refinements. The final
focused run above does not claim a repeat of the entire current UI suite.

Final Release simulator/iPhone SDK builds use the Release commands above; logs:
`/tmp/avela-island-final-release-iphonesimulator.log` and
`/tmp/avela-island-final-release-iphoneos.log`. No signed archive, device testing
or upload has occurred. Confirm source/Info plist/resource integrity before
distribution and run the full release-candidate regression suite.

Isolated tests leave ActivityKit disabled by default. Only the explicit DEBUG
`AVELA_UI_TEST_LIVE_ACTIVITY=1` flag enables native integration for a dedicated
simulator; the test supplies it. The flag is compiled out of Release.

Known platform limits: `staleDate` marks content stale, not ended. If the app is
suspended at the deadline, the system displays elapsed/check-in content and
controls lifetime; foreground reconciliation ends it without writing an outcome.
The maximum supported Live Activity session here is eight hours; longer local
sessions still work. Lock Screen, minimal layout under competing activities,
physical-device authorization/dismissal, VoiceOver and OLED readability remain
signed-device checks rather than claims established by the two screenshots.

Both final Release builds **BUILD SUCCEEDED**. Compiled Info plists enable Live
Activities; all five DEBUG hook names (including the new activity opt-in flag)
are absent in both app binaries, with the production subscription ID present as
a positive control. App/widget privacy manifests and widget artwork catalogs
are included; no local `.storekit` resource is shipped. Project/plist lint, exact
source membership for all six new files and `git diff --check` pass. No commits,
pushes, archive validation or upload were performed.

### Testing reminder actions

Enable a habit's reminder explicitly and allow notifications. When delivered,
press and hold it, choose **Review & log**, then confirm the named habit or
Cancel. Ordinary tapping never logs. Past-day reminders are rejected. Test on
a signed device for lock-screen/unlock behavior; simulator testing alone does
not prove authentication behavior.

Native UI automation can set `AVELA_UI_TEST_REMINDER_DELIVERY=1` together with
an isolated `AVELA_UI_TEST_STORE_PATH`. Saving an authorized enabled reminder
then delivers one real system notification after 8 seconds. This DEBUG-only
hook bypasses neither permission nor the response handler and is absent from
Release. Run these tests on the dedicated Pro Max simulator, not the owner's
working Pro simulator.

## Calendar history and app themes verification — 2026-10-05

Built the native read-only habit calendar and five curated app accents. New
production files: `HabitCalendarCalculator.swift`, `HabitCalendarViewModel.swift`,
`HabitCalendarView.swift`, `AppTheme.swift`, `AppAppearanceRecord.swift`,
`AppThemeViewModel.swift`, `AppThemeView.swift`, and `AppPalette.swift`. New unit
files: `HabitCalendarTests.swift` (17 tests) and `AppThemeTests.swift` (8 tests).
Existing targets and dependencies are unchanged.

**Verified:** 321 unit tests, zero failures; 12 distinct targeted native UI flows,
zero failures, across the feature and regression runs. This is not a re-run of
all existing UI tests. The selected flows cover month navigation/read-only history,
weekly history at AX3, theme selection/relaunch, onboarding, completion and
attention undo, habit editing, History filtering, comparable Insights trends,
archive/reactivate cycles, companion preferences and native reminder cancellation.

Final unit/palette verification and theme/onboarding native checks:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Avela.xcodeproj -scheme Avela \
  -destination 'platform=iOS Simulator,id=2ACFE418-44EC-4A44-9B2A-1B45BDF1EF38' \
  -derivedDataPath /tmp/AvelaCodexMVP -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- \
  -only-testing:AvelaTests \
  -only-testing:AvelaUITests/MVPFlowTests/testAppThemeAppliesImmediatelyAndSurvivesRelaunch \
  -only-testing:AvelaUITests/MVPFlowTests/testOnboardingOptionalStepsCanBeSkippedAndCompletionSurvivesRelaunch test
# TEST SUCCEEDED — 321 unit + 2 UI tests, zero failures
```

Actual evidence:

- `/tmp/avela-theme-native-fill.log`: final unit suite and deep-fill native checks;
  result `Test-Avela-2026.10.05_10-58-41--0600.xcresult` under
  `/tmp/AvelaCodexMVP/Logs/Test/`.
- `/tmp/avela-calendar-theme-final.log`: 321 units and four feature/onboarding
  flows in dark mode; calendar AX3 and month navigation passed.
- `/tmp/avela-calendar-theme-regressions.log`: eight existing native flows passed.
- `/tmp/avela-calendar-themes-light-final.log`: final light-mode theme/month
  navigation passed. System appearance was set with `xcrun simctl ui` on the
  isolated iPhone 18 Pro Max simulator, and restored to light afterwards.
- `/tmp/avela-calendar-theme-release-complete.log`: final unsigned Release device
  build succeeded using `/tmp/AvelaCalendarThemesRelease`. Binary inspection
  found no store-path/seed/reminder-delivery DEBUG marker or DebugFixtures symbol,
  with calendar/theme symbols present as a sanity check.

```bash
xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/AvelaCalendarThemesRelease CODE_SIGNING_ALLOWED=NO build
# BUILD SUCCEEDED
```

`plutil -lint` and project membership checks pass: 145 Swift file references,
including six deliberately shared with the widget target, with no duplicate
membership within any target. `git diff --check` is clean.

A real previous 13-model on-disk store was reopened under the 14-model schema,
preserving its habit/configuration, completion ID/note, skip ID and companion
preferences. No user store reset is required. Calendar navigation uses stored fact
months as bounds, so dates remain reachable after time-zone travel.

Visual review caught native glass toolbar buttons forcing white template icons;
filled controls now use a separate deep accent with white foreground, rather
than pale dark-mode progress accents. All theme pairs/filled controls pass native
opaque-colour contrast checks. The remaining physical glass/OLED/Increase Contrast
and VoiceOver checks have not been performed.

[Native light/dark and large-text previews](verification/calendar-themes/README.md)
are captured from isolated DEBUG stores, not the owner's simulator data. The
owner's iPhone 18 Pro was not reset or otherwise used by these checks. Themes
currently apply to app screens; widgets and Live Activities retain Tidewater.
No commits, pushes, new permissions, secrets or packages are involved.

## Personal habit ordering verification — 2026-10-05

Free personal ordering uses existing `HabitRecord.sortOrder`, without a schema
change/reset, additional permission or dependency. New production files:
`HabitOrderViewModel.swift`, `HabitOrderView.swift`. New unit file:
`HabitOrderViewModelTests.swift` (four tests); six additional repository tests
cover actual disk relaunch, fact/timestamp preservation, invalid/stale orders,
archive/reactivate slots, appends and legacy collisions. Today/Settings entry
points and required repository operation are registered in existing targets.

Final Debug verification: **331 unit tests + four targeted UI flows, zero
failures**, followed by **one native drag UI flow, zero failures**. This is five
distinct UI flows, not a repeat of every existing UI test. The four-flow run
includes ordering Cancel/Save/relaunch/History/undo, Settings ordering at AX3,
existing theme persistence and Done/undo regression. A typo in the new test's
Undo identifier caused the initial run to fail after its ordering assertions;
the corrected final run retains all assertions and passes.

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=2ACFE418-44EC-4A44-9B2A-1B45BDF1EF38' \
  -derivedDataPath /tmp/AvelaCodexMVP -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- \
  -only-testing:AvelaTests \
  -only-testing:AvelaUITests/MVPFlowTests/testHabitOrderCancelSaveAndRelaunchPreserveTracking \
  -only-testing:AvelaUITests/MVPFlowTests/testHabitOrderingFromSettingsAtAccessibilityTextSize \
  -only-testing:AvelaUITests/MVPFlowTests/testAppThemeAppliesImmediatelyAndSurvivesRelaunch \
  -only-testing:AvelaUITests/AvelaUITests/testCompletedHabitRowCollapsesIntoDoneGroupAndCanStillBeUndoneAfterward test
```

Final combined log: `/tmp/avela-order-final-tests.log`; result bundle:
`/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.05_12-24-31--0600.xcresult`.
Native drag uses the same command without those selections and with
`-only-testing:AvelaUITests/MVPFlowTests/testNativeHabitOrderDragHandleChangesDraftOnlyUntilSave`.
Its log is `/tmp/avela-order-drag-test.log`; result bundle:
`/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.05_12-27-42--0600.xcresult`.

Native light and accessibility XXXL screenshots were visually reviewed and
saved under [verification/habit-order](verification/habit-order/README.md).
The isolated Pro Max test simulator was used; the owner's Pro store was untouched.
No ordering change modifies historical facts, schedules or metrics. Physical
VoiceOver custom-action/focus behavior and keyboard/drag ergonomics remain manual
release checks. Save-error restoration is implemented without global rollback;
a real disk-save failure was not artificially injected for a passing test.
Concurrent order edits with identical active IDs are last-save-wins; membership
changes are rejected with an explicit Reload path. No commits or pushes.

Final unsigned iPhone SDK Release build **BUILD SUCCEEDED**:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Avela.xcodeproj -scheme Avela -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/AvelaCalendarThemesRelease CODE_SIGNING_ALLOWED=NO build
```

Log: `/tmp/avela-order-release.log`. Release binary contains HabitOrder production
symbols and zero store-path/fixture/reminder-delivery DEBUG markers. Project lint
and membership checks pass: 148 Swift references, each new file registered once,
no duplicate per-target source membership. `git diff --check` passes. This is an
unsigned device compilation, not an archive, physical-device run or upload.

### Expanded themes and optional lighter schedule — verified 2026-10-05

Final Debug run: **345 unit tests + 5 targeted UI tests, zero failures, TEST
SUCCEEDED**. This adds 12 meaningful adjustment tests, two theme persistence/
legacy tests and three native UI flows; two existing completion/editing flows
were also selected. It does not claim a new full-UI-suite run.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=2ACFE418-44EC-4A44-9B2A-1B45BDF1EF38' \
  -derivedDataPath /tmp/AvelaCodexMVP -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- \
  -only-testing:AvelaTests \
  -only-testing:AvelaUITests/MVPFlowTests/testLighterScheduleCancelConfirmAndRelaunch \
  -only-testing:AvelaUITests/MVPFlowTests/testAdditionalThemesSurviveRelaunch \
  -only-testing:AvelaUITests/MVPFlowTests/testLighterScheduleAtAccessibilityTextSize \
  -only-testing:AvelaUITests/AvelaUITests/testCompletedHabitRowCollapsesIntoDoneGroupAndCanStillBeUndoneAfterward \
  -only-testing:AvelaUITests/AvelaUITests/testEditingHabitFromDetailUpdatesTodayWithoutLosingPriorCompletion test
```

Log: `/tmp/avela-recovery-complete-tests.log`. Result bundle:
`/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.05_13-18-55--0600.xcresult`.
The isolated Pro Max simulator was set to dark via `simctl ui ... appearance
dark`; regular light previews were captured in an earlier run. The owner Pro
simulator/store was untouched. Native screenshots were visually reviewed and
saved in [verification/recovery-themes](verification/recovery-themes/README.md).

Early failures were a test's incorrect Sunday epoch and incorrect schedule-label
expectation, then lazy AX3 rows/off-screen header assertions. Tests now scroll
before querying lazy rows and respect retained detail scroll position. No app
layout reset or font reduction was used to force a pass. The local StoreKit
purchase test also uses its existing bounded authoritative-entitlement polling
rather than assuming the sequence updates immediately after purchase.

No schema change/reset, new permission or dependency. Recovery choices are
explicit editable defaults, not validated adherence outcomes. Physical VoiceOver,
keyboard and Increase Contrast remain manual release checks. No commits/pushes.

Final unsigned iPhone SDK Release compilation: **BUILD SUCCEEDED**.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Avela.xcodeproj -scheme Avela -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/AvelaCalendarThemesRelease CODE_SIGNING_ALLOWED=NO build
```

Log: `/tmp/avela-recovery-release.log`. The final Release binary contains the new
HabitAdjustment/AppTheme production symbols and zero store-path, seed-fixture,
DebugFixtures or reminder-delivery DEBUG markers. Project lint/membership checks
pass: 152 Swift references, four new files registered once and no duplicate
per-target sources. `git diff --check` passes. This is an unsigned compilation,
not a signed archive, physical-device run or TestFlight upload.


## Full-theme and streak presentation verification — 2026-10-05

Page gradients, tinted custom cards, deep progress heroes and connected calendar success ribbons are presentation-only. No schema, metric or permission change was required. Native previews are in [verification/full-themes](verification/full-themes/README.md).

Debug verification used the isolated iPhone 18 Pro Max simulator (`2ACFE418-44EC-4A44-9B2A-1B45BDF1EF38`), `/tmp/AvelaCodexMVP`, ad-hoc signing (`CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`) and parallel testing disabled. The owner simulator/store was untouched. The isolated simulator was restored to light appearance afterward.

- **346 unit tests and four targeted UI tests passed**, zero failures: `/tmp/avela-immersive-theme-tests.log`; result bundle `Test-Avela-2026.10.05_13-55-17--0600.xcresult` under `/tmp/AvelaCodexMVP/Logs/Test/`.
- Targeted flows: immersive theme selection/persistence/read-only streak calendar; month navigation without logging; accessible weekly commitment explanation; completion/Done-group undo.
- Dark-mode rerun: **346 unit tests and two targeted UI tests passed**, zero failures: `/tmp/avela-immersive-dark-tests.log`.
- Final light immersive flow and final dark AX3 weekly flow passed separately after presentation refinements: `/tmp/avela-immersive-light-final.log`, `/tmp/avela-immersive-ax-final.log`.
- Standalone Debug build succeeded: `/tmp/avela-immersive-debug-build.log`.
- Unsigned iPhone SDK Release build succeeded using the preceding Release command: `/tmp/avela-immersive-release.log`. Its binary has zero store-path, seed-fixture, DebugFixtures and reminder-delivery test markers, with AppPalette production symbols present.
- Project plist lint and `git diff --check` pass.

This pass did not rerun the entire UI suite. Native screenshots were reviewed in light, dark and accessibility XXXL; physical-device accessibility remains a release check. No signed archive or TestFlight upload is implied.


## Design quality execution verification — 2026-10-05

Implemented the first code-backed pass from DESIGN_QUALITY_PLAN.md. Journey coverage and remaining evidence are tracked in [QUALITY_EXECUTION.md](QUALITY_EXECUTION.md); native screenshots are in [verification/design-quality](verification/design-quality/README.md).

The final combined Debug run passed **349 unit tests and six quality-focused UI tests, zero failures**, including selected native accessibility audits, largest-text weekday creation/persistence, confirmation dismissal/Done undo, onboarding and a launch measurement. Log: `/tmp/avela-quality-complete.log`; result: `/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.05_16-03-45--0600.xcresult`.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=2ACFE418-44EC-4A44-9B2A-1B45BDF1EF38' \
  -derivedDataPath /tmp/AvelaCodexMVP -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- \
  -only-testing:AvelaTests \
  -only-testing:AvelaUITests/MVPFlowTests/testCoreScreensPassNativeAccessibilityAudit \
  -only-testing:AvelaUITests/MVPFlowTests/testSupportingScreensPassNativeAccessibilityAudit \
  -only-testing:AvelaUITests/MVPFlowTests/testWeekdayFormAtLargestTextHasComfortableTargetsAndPersists \
  -only-testing:AvelaUITests/MVPFlowTests/testDismissConfirmationPreservesLoggingAndDoneUndo \
  -only-testing:AvelaUITests/MVPFlowTests/testOnboardingWelcomePassesNativeAccessibilityAudit \
  -only-testing:AvelaUITests/MVPFlowTests/testApplicationLaunchPerformanceBaseline test
```

Five existing targeted UI regressions passed earlier in `/tmp/avela-quality-verified.log`: quick attention logging/undo, completion toast undo, Done-group undo, and regular/largest-text icon target sizes. That run's supporting-screen audit failed on Settings text clipping; the final combined run above includes the corrected wrapping labels and passes without suppressing audit issues. This pass did **not** rerun the entire UI suite.

Four quality UI checks passed in dark appearance in `/tmp/avela-quality-dark.log`. The subsequently refined inline accessibility-size picker is separately checked in `/tmp/avela-quality-dark-inline.log`. Appearance is set via `xcrun simctl ui <id> appearance dark`, not a launch argument. All runs use isolated UI-test stores on the Pro Max; the owner's Pro simulator/store is untouched. Restore the test simulator to light after capturing previews.

Selected audits cover hit regions, sufficient descriptions, clipped text and traits. They do not establish physical VoiceOver focus, Switch Control operation, every theme's contrast, or an Accessibility Nutrition Label. Visual inspection caught a large-text menu clipping issue missed by the automated audit; inline choices replaced that menu.

Simulator measurements are baselines only: the three-year daily-history calculator averaged about **6 ms** over ten iterations; Debug responsive launch averaged **2.910 s** over five iterations (about 7.3% relative deviation). These are not physical-device release budgets, scroll/memory/energy profiles or evidence of an adherence benefit.

Final unsigned iPhone SDK Release build passed (`/tmp/avela-quality-release-complete.log`) using the existing Release command. Binary inspection found zero store-path, seed-fixture, DebugFixtures and reminder-delivery DEBUG markers, with AppPalette production symbols present. Project plist lint and `git diff --check` pass. No signed archive, TestFlight upload, commit or push occurred.


## Quantity, routine, reflection and Watch expansion — 2026-10-05

The expanded candidate adds a native `AvelaWatch` target, embedded by the existing Avela scheme. There are still no third-party packages or runtime secrets. Watch SDK compilation is available; there is no paired watchOS simulator runtime here. Physical pairing/background delivery remain a release gate.

All **411 unit tests pass** in `/tmp/avela-enrichment-verified.log`. **Nine distinct targeted UI flows pass** across `/tmp/avela-enrichment-final.log` and `/tmp/avela-enrichment-verified.log`: quantity/smaller-action persistence, routines, reflection, manageable-week pause, restart confirmation, phone-free intention/manual outcome separation, largest-text setup, core accessibility/calendar and existing toast Undo. The earlier combined run had a calendar-link query fail because the newly inserted detail actions moved it outside the List's instantiated area; bounded scrolling fixed the test, and the final core audit passed without suppressing accessibility findings. The entire UI suite was not rerun.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=2ACFE418-44EC-4A44-9B2A-1B45BDF1EF38' \
  -derivedDataPath /tmp/AvelaCodexMVP -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- \
  -only-testing:AvelaTests \
  -only-testing:AvelaUITests/MVPFlowTests/testCoreScreensPassNativeAccessibilityAudit \
  -only-testing:AvelaUITests/MVPFlowTests/testManageableWeekRestartRequiresSelectionAndExplicitConfirmation \
  -only-testing:AvelaUITests/MVPFlowTests/testQuantityProgressAndSmallerActionRemainDistinctAcrossRelaunch test
```

Largest-text setup additionally passes in real simulator dark appearance (`/tmp/avela-enrichment-dark.log`); light is restored afterward. Native audit types are hit regions, sufficient description, clipping and traits, not a physical VoiceOver or every-color contrast audit.

Unsigned iPhone SDK Release builds pass, with the embedded Watch executable present and all four existing DEBUG-only store/fixture/reminder markers absent. Project membership checks find 183 Swift source paths correctly assigned, including intentional app/widget and app/Watch shared files. No signed archive, TestFlight upload, commit or push.

See [native enrichment previews](verification/enrichment/README.md). Quantity setup lives in Habit Detail → Progress, Timer & History Corrections; routines/manageable-week review are on Today; reflection is in Settings/Insights; phone-free intentions are in Habit Detail → Make Room. Enable Watch sharing explicitly in Settings.

The expansion uses SwiftData lightweight schema changes and a default-false completion attribute, with no destructive store reset. A native test opens a store without the six new model types, preserves habit/completion IDs and notes, and creates a new quantity configuration. This test does not represent every old binary/schema variant. Hardware Siri, Health permissions, Watch, VoiceOver, energy and distribution signing remain pending.

Final screenshot-driven routine polish uses explicit system secondary text instead of a secondary style inheriting the button's accent. Restart explanatory copy is shorter; the precise counting rules remain in DATA_MODEL.md. Both routine/restart UI regressions pass again in `/tmp/avela-enrichment-routine-polish.log`; final unsigned Release passes in `/tmp/avela-enrichment-release-polish.log`, with DEBUG marker exclusions rechecked.


## Full-suite verification — 2026-10-05

A clean, unrestricted `test` action passed **411 unit tests + 82 UI tests**, with **zero failures and zero skips**, confirmed by `xcresulttool get test-results summary` (493 passed). It includes native reminder actions, Dynamic Island/Live Activity, all older app flows, enrichment, performance and accessibility checks. The owner's Pro simulator/store was untouched.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=2ACFE418-44EC-4A44-9B2A-1B45BDF1EF38' \
  -derivedDataPath /tmp/AvelaCodexMVP -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```

Log: `/tmp/avela-full-suite-verified.log`. Result: `/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.05_19-29-27--0600.xcresult`. An earlier attempt was stopped after an older Archived Habits query failed to scroll; bounded native scrolling fixes the test without removing assertions. The restarted full run passed.

The successful run printed a nonblocking post-run diagnostics collection error because a child `xcrun` resolved the Command Line Tools environment and could not find `simctl`. The test action exited 0, and the result bundle is valid; explicit Xcode `DEVELOPER_DIR` works for normal `simctl` commands. Simulator appearance is restored to light.

Physical VoiceOver, paired Watch, real Health/Siri delivery, energy and distribution signing remain device/release gates. Full simulator coverage does not establish those.

The full run also recorded two SwiftUI publication warnings during reminder-alert dismissal. `AppShellView` now defers clearing the published pending action until after the view update, guarded so a newer reminder is not consumed. After that localized fix, **all 411 unit tests plus the three affected native reminder UI tests passed (414 total, zero failures/skips and zero runtime warnings)**. The entire 82-test UI suite was not repeated after this fix. Follow-up result: `/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.05_20-11-51--0600.xcresult`; log: `/tmp/avela-full-suite-warning-fix.log`.

The latest unsigned iPhone SDK Release build also passes (`/tmp/avela-full-suite-release.log`), with all four DEBUG-only markers independently rechecked as absent.

## Factual weekly reflection — 2026-10-05

Reflection now shows recorded per-habit progress for the selected week alongside private notes. Insights preserves its review week when opening Reflection. Notes are not analyzed; counts describe recorded commitments, not inferred causes. No schema, AI runtime/service, dependency or permission was added.

[Native populated reflection preview](verification/enrichment/reflection-recorded-progress.png) was exported from the passing UI test and visually reviewed. **11 reflection unit tests + 2 native UI tests passed**, zero failures/skips/runtime warnings, in `/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.05_21-27-00--0600.xcresult` (`/tmp/avela-factual-reflection.log`). The final wording polish was rechecked by the populated UI test in `/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.05_21-29-08--0600.xcresult` (`/tmp/avela-factual-reflection-copy.log`). Unsigned iPhone SDK Release builds pass (`/tmp/avela-factual-reflection-release.log`). This is focused verification, not a repeat of the complete suite. Physical VoiceOver and large-text presentation of this addition remain device checks. No commit or push.


## Configure optional iCloud recovery — 2026-10-05

Current placeholder builds deliberately leave backup unavailable. Simulator fake
provider tests prove local flow only, not CloudKit provisioning or real recovery.
No runtime secret is required.

1. Register real app bundle IDs and a developer team. Add iCloud/CloudKit capability
   to the main app with a private container you own. Keep existing App Groups and
   HealthKit capabilities intact; widget/Watch targets do not need cloud access.
2. Merge CloudBackup.entitlements.template into the app's real signing entitlements,
   replacing its container placeholder. Set AVELA_CLOUD_BACKUP_CONTAINER to that
   exact identifier; the Info.plist value reads the setting. The template alone is
   not active signing configuration. CKContainer is never initialized for an
   unset setting, com.example container or isolated UI-test store.
3. In CloudKit Console configure AvelaRecoverySnapshot with payload (Asset),
   snapshotDate (Date), deviceID (String), and the indexes needed for an all-record
   query (including queryable recordName). Verify pagination. Deploy the schema to
   Production before TestFlight; development schema alone is insufficient.
4. On signed devices test actual opt-in/upload, successful server acknowledgement,
   offline/limited quota, iCloud sign-out/account switch and explicit deletion.
   Restore on a separate otherwise empty installation; cancellation writes nothing,
   IDs/history survive restart, reminders remain off and timers are paused. Test
   Health/fitness exclusions and private-note omissions against the real asset.
5. Review archive privacy report, App Store Connect disclosures and published
   privacy policy/contact. Check system-device-backup handling of Health-derived
   local data before release; do not interpret these cloud tests as that check.

Progress Protection is in Settings → Your Data. Automatic copies run only while
Avela can execute after saved changes, at most once per ten minutes. Manual Back
Up Now is available. Turning off does not delete copies; a request already sent
may finish. Quota/connectivity failures leave local history intact. Recovery is
not live sync, and intentionally excluded records are not protected by it.

Debug UI fixture cloudBackupRecovery requires both AVELA_UI_TEST_STORE_PATH and
AVELA_UI_TEST_SEED_FIXTURE. It creates an isolated in-memory fake cloud copy; never
use its screenshots or passing tests as evidence of real CloudKit availability.

Unconfigured Release builds hide the Progress Protection entry. Debug builds
show its unavailable state for development; no CloudKit calls are made.

## Progress enrichment verification — 2026-10-06

Lifetime progress/milestones, personal quick amounts, and the selected-week intention review are implemented. Full native unit suite: **454 tests, zero failures** (31 new tests). Five distinct affected native UI flows pass: lifetime + milestone + relaunch/Undo; populated read-only selected-week review; preset Cancel/Save/log/Undo/relaunch; existing quantity/smaller-action regression; largest-text navigation. Debug simulator and unsigned iPhoneOS Release builds succeed. DEBUG fixture/store hooks are absent from the Release executable, with production symbols checked as a sanity control. Project membership and whitespace checks pass.

Evidence and precise commands: `docs/verification/progress-enrichment/README.md`. The full UI suite was not rerun for this bounded slice. Physical-device VoiceOver/interaction checks remain pending. Presets are device-local convenience preferences, not included in logical iCloud recovery; progress is derived from the existing records. Cloud recovery remains gated by the signing/container/device-verification prerequisites already documented.

Next: a cohesive premium UI/interaction polish pass using real screens. Prioritize action hierarchy, crowded habit-detail navigation, text density, logging controls, and consistent spacing/typography/icon treatment. This pass did not perform that global redesign.

## Cohesive native UI polish — 2026-10-06

Implemented quieter habit recovery counts, grouped detail tools, consistent icon tiles, clearer logging/review hierarchy, Settings grouping and shared spacing/theme refinements across the main iPhone screens. Existing progress, provenance, privacy and purchase behavior is preserved; no schema, permission or dependency was added.

Verification: **454 unit tests and 14 distinct affected UI flows pass**, plus two repeated dark-mode screen-tour/AX3-navigation checks. Debug simulator and unsigned iPhoneOS Release builds succeed; DEBUG fixture/store hooks are absent from Release. Project integrity and whitespace checks pass. The entire UI suite was not rerun. Physical VoiceOver, OLED and private usability checks remain pending; signed cloud/device integration gates are unchanged.

[Native light/dark gallery, exact scope and reproduction commands](verification/ui-polish/README.md).

## Atmospheric themes verification — 2026-10-06

The first coordinated design pass is implemented: neutral reading surfaces, complementary theme atmosphere, original static calendar/picker landscapes, action-focused Today and consistent multicolor habit identity. Existing saved theme values, progress/history, manual provenance and commercial rules remain unchanged; no schema, package or permission was added.

**455 unit tests and seven distinct affected UI flows pass**, with nine UI executions across light/dark. Debug and unsigned iPhoneOS Release builds succeed. DEBUG store/fixture/recovery markers are absent from Release; production scenery symbols are present. Project membership and whitespace checks pass. The entire UI suite was not rerun. Physical VoiceOver, OLED, Increase Contrast and private usability checks remain pending; signed platform/cloud release gates are unchanged.

[Native screenshots, exact scope and reproduction](verification/atmospheric-themes/README.md). The dedicated simulator is restored to light appearance. No commits or pushes.

### Recovery-card DEBUG fixture

`AVELA_UI_TEST_SEED_FIXTURE=recoveryProgress` creates an isolated daily reading habit with two previous successful days after two misses and an optional smaller action. Like all fixtures, it requires `AVELA_UI_TEST_STORE_PATH`, applies only to an empty redirected store and is compiled out of Release. It uses the real current civil day and public repositories, with no production clock override.

### Visual Insights DEBUG fixture

`AVELA_UI_TEST_SEED_FIXTURE=visualInsights` uses public repositories to seed daily and archived flexible-weekly habits plus partial manual attention coverage. The rounded habit score is 68%, below-budget result 33%, coverage 3/7 goal-days. Like other fixtures, it requires an empty isolated `AVELA_UI_TEST_STORE_PATH` store and is compiled out of Release. It never affects an ordinary store or changes the production clock.
