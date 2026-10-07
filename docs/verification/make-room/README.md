# Make Room → Do It verification

October 6, 2026. Native iPhone 18 Pro Max simulator evidence, using an isolated test store. These are real app screenshots, not browser mockups.

## Behavior

- Habit Detail → Make Room → Create Session Goal creates a named Focus or Phone-Free goal without starting a timer or completing the habit.
- Focus permits phone use. Phone-Free is an intention; neither mode blocks or monitors other apps.
- Start explicitly creates a session and links its intention to the habit. The optional Dynamic Island toggle requests a mascot/countdown Live Activity where supported.
- The session can be reviewed after relaunch. A reported result never completes the habit.
- Log What I Did opens the existing habit logger. Quantity/timer entries are not prefilled from session duration.
- Existing phone-free records remain phone-free. The goal type uses existing persisted raw values; no new database table or destructive reset is required.
- Creation enforces the existing plan limit. The free tier still allows one active attention goal; reviewing that limit is a product decision, not silently changed here.

## Screenshots

[Focus setup](focus-setup.png) · [Expanded Dynamic Island with mascot and timer](focus-dynamic-island.png)

The gallery is from the final passing focused flow, including the session-mode picker label and larger Start control. The final focused flow passed again after that last control-size refinement.

## Results

- All **473 unit tests pass**, including focus creation, independent habit logging, plan enforcement, relaunch/history, logical-backup recovery and failed-link destination preservation.
- **Four affected UI flows pass**, including the new create → Focus → Island → relaunch → independent habit logging flow and three existing phone-free/review flows.
- Debug test build and Release device build succeed.
- Release app binary contains zero occurrences of `AVELA_UI_TEST_STORE_PATH`, `AVELA_UI_TEST_SEED_FIXTURE`, or `DebugFixtures`.
- Project membership: 202 Swift source files, zero issues. Project/Info plists validate and `git diff --check` is clean.
- No full UI-suite run or physical-device certification is claimed.

## Reproduction

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug \
  -destination 'platform=iOS Simulator,id=2ACFE418-44EC-4A44-9B2A-1B45BDF1EF38' \
  -derivedDataPath /tmp/AvelaCodexMVP -parallel-testing-enabled NO \
  -only-testing:AvelaTests \
  -only-testing:AvelaUITests/MVPFlowTests/testMakeRoomCreatesFocusSessionAndRequiresSeparateHabitLogging \
  -only-testing:AvelaUITests/MVPFlowTests/testPhoneFreeIntentionStaysSeparateFromHabitCompletion \
  -only-testing:AvelaUITests/MVPFlowTests/testMadeRoomReviewShowsOnlyRecordedFactsForSelectedWeek \
  -only-testing:AvelaUITests/MVPFlowTests/testPhoneFreeLiveActivityIsOptionalAndDoesNotCertifySuccess \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test

xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/AvelaDictationRelease \
  CODE_SIGNING_ALLOWED=NO build
```

Use an available simulator UUID from `xcrun simctl list devices available` on another machine. Local test result: `/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.06_22-25-55--0600.xcresult`. Logs: `/tmp/avela-make-room-final.log`, `/tmp/avela-make-room-release-final.log`.

## Remaining checks

Signed-device Live Activity authorization, Lock Screen/system settings, small-device/Dynamic Type and VoiceOver checks remain device gates. A timer cannot prove concentration or phone-free behavior. Personal Patterns and a new Flexible Day entry point are review proposals, not implemented in this slice.

Final focused-flow result: `/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.06_22-30-48--0600.xcresult`; log `/tmp/avela-make-room-large-control.log`.
