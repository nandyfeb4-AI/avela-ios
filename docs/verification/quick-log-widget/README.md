# Quick Log Home Screen widget

October 7, 2026. A separate optional widget focused on logging, alongside existing Habit Progress, Attention Budget and Live Activity widgets.

## Interaction

- Add once: Home Screen → touch and hold → Edit → Add Widget → Avela → Avela Quick Log. Settings → Home Screen Widgets explains placement and use.
- Circle: log a simple check-in in the background. Name: open that habit's detail. Quantity +: open the existing amount/duration logger without recording success.
- Small shows two habits; medium shows four in a row-major grid. Pending habits lead in saved habit order. Completed rows remain in place briefly, then move behind pending rows. Summary counts include hidden habits.
- Larger accessibility text sizes show fewer rows, without shrinking text or targets. No mascot, chart, extra tab or mandatory daily app visit.
- After midnight, Refresh habits reads today's canonical state in the background. Stale snapshots never silently log a new day's success. Undo and skipped-day changes require explicit review in Avela.

## Screenshots

| Native Home Screen | Light | Dark, largest Dynamic Type |
| --- | --- | --- |
| Small | [Small](small-light.png) | [Small, largest text](small-dark-largest-text.png) |
| Medium | [Medium](medium-light.png) | [Medium, largest text](medium-dark-largest-text.png) |

[Refresh prompt](refresh-prompt.png) · [Name opens detail](name-opens-details.png) · [Quantity opens logger](quantity-opens-logger.png)

Screenshots use isolated simulator data. Light captures show a new day's pending habits; prior-day background logging records remain saved. No owner's simulator data was reset.

## Persistence and failure behavior

The widget consumes the existing App Group JSON projection. Shared App Intents execute in the app process using Apple's documented LiveActivityIntent routing; they do not start a Live Activity. Only the app writes SwiftData. Checks include day/timezone, archive/due state, configuration revision, quantity requirements, skips and already-recorded completion. Repeated taps are idempotent. Save happens before projection export and widget reload; failed writes cannot display optimistic success. A failed save removes only its own inserted completion so it cannot later autosave accidentally.

No schema migration, third-party library, runtime secret, microphone access or new entitlement is introduced. Existing private reasons are not exported. Test-store overrides cannot populate the real widget group.

## Verification

- Full unit suite: 519 tests, zero failures, including 18 Quick Log tests.
- Final affected UI regression: 3 tests pass, zero failures—optional guide, shell/relaunch, and quantity/smaller-action separation. Combined xcodebuild test reports TEST SUCCEEDED.
- Real SpringBoard verification on an isolated iPhone simulator: background check-in with app running and terminated, correct name navigation, medium layout, quantity logger, and stale-day refresh without foregrounding Avela. Temporary native verification drivers were removed after capturing evidence.
- Light and dark/largest-text screenshots were inspected. Native widget interaction and resize runs passed.
- Debug test build and Release device build pass. Release app and widget binaries contain zero occurrences of the four checked DEBUG store/fixture hooks; QuickLogHabitIntent is present as a positive control. Widget binary has no AppPersistence or SwiftDataHabitRepository references.
- Latest Debug app installed on the owner's iPhone 18 Pro simulator without uninstalling or resetting data.
- Project membership: 217 Swift source files, zero issues; project plist and whitespace checks pass.

This is full unit and targeted UI coverage, not a full UI-suite run or device certification. Signed physical-device background intents, unlock behavior, VoiceOver focus and widget refresh scheduling remain device checks. Widgets are optional and users must place them; Avela cannot add a Home Screen widget automatically.

## Reproduction

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=2ACFE418-44EC-4A44-9B2A-1B45BDF1EF38' \
  -derivedDataPath /tmp/AvelaCodexMVP -parallel-testing-enabled NO \
  -only-testing:AvelaTests \
  -only-testing:AvelaUITests/MVPFlowTests/testWidgetGuideIsOptionalAndExplainsSeparateControls \
  -only-testing:AvelaUITests/AvelaUITests/testShellNavigationAndRelaunch \
  -only-testing:AvelaUITests/MVPFlowTests/testQuantityProgressAndSmallerActionRemainDistinctAcrossRelaunch \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test

xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/AvelaQuickLogRelease \
  CODE_SIGNING_ALLOWED=NO build
```

Apple's process-routing and interaction guidance: [Adding interactivity to widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities).
