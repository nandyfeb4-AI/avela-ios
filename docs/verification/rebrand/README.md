# Rilova rebrand verification — 2026-10-07

## Result

Public name: **Rilova**. Tagline: **Habits that fit real life.** Original Rich Tide lowercase-r logo now supplies iPhone and Watch app icons, onboarding and Settings identity. Visible app, widget, Watch, Premium, permission, notification, backup and Shortcuts copy uses Rilova.

[Brand kit](../../../design/brand/rilova/README.md) · [Native onboarding screenshot](rilova-onboarding.png)

The Xcode project/scheme/module remain `Avela`. Existing bundle IDs, App Groups, URL schemes, subscription product IDs, CloudKit record types, persistent model identities and defaults are retained. This is intentional continuity, not an unfinished migration. The local StoreKit display names changed; App Store Connect metadata requires a separate manual update.

## Verification

- **546 unit tests**, zero failures, including a new test for the bundled logo/name and preserved integration identifiers. Includes existing disk reopening/migration and data-preservation coverage.
- **7 distinct selected UI tests**, zero failures: onboarding skip/relaunch, welcome native accessibility audit, widget guide, Shortcuts guide, Premium restore/free return, privacy without Premium, and habit relaunch preservation.
- After final vector exports, repeated all 546 unit tests and the two onboarding tests, zero failures.
- Debug simulator, unsigned Release iPhoneOS and standalone Watch simulator builds succeeded. Simulator signing is ad hoc; Release build success does not establish device provisioning or distribution readiness.
- App icon is 1024 × 1024 and opaque. Native welcome screenshot visually reviewed. Vector board reviewed at multiple icon sizes; transparent website marks are clean native vector exports.
- Built app display name is Rilova in Debug/Release; bundle identifier remains `com.example.Avela`. Watch display name is Rilova with its existing bundle ID. Release executable scan found no test-store override, fixture environment hook or DebugFixtures symbol.
- Project/Info plists pass `plutil -lint`; `git diff --check` passes.

## Commands and evidence

Use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` for these commands.

```sh
xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Debug   -destination 'platform=iOS Simulator,id=2ACFE418-44EC-4A44-9B2A-1B45BDF1EF38'   -derivedDataPath /tmp/AvelaCodexMVP -parallel-testing-enabled NO   CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -only-testing:AvelaTests   -only-testing:AvelaUITests/MVPFlowTests/testOnboardingOptionalStepsCanBeSkippedAndCompletionSurvivesRelaunch   -only-testing:AvelaUITests/MVPFlowTests/testOnboardingWelcomePassesNativeAccessibilityAudit test

xcodebuild -project Avela.xcodeproj -scheme Avela -configuration Release   -sdk iphoneos -destination 'generic/platform=iOS'   -derivedDataPath /tmp/AvelaProtectionRelease CODE_SIGNING_ALLOWED=NO build

xcodebuild -project Avela.xcodeproj -target AvelaWatch -configuration Debug   -sdk watchsimulator SYMROOT=/tmp/RilovaWatchBuild CODE_SIGNING_ALLOWED=NO build
```

Final-asset test bundle: `/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.07_20-36-13--0600.xcresult`. Logs: `/tmp/rilova-final-assets-tests.log`, `/tmp/rilova-brand-ui-followup.log`, `/tmp/rilova-install-build.log`, `/tmp/rilova-final-release.log`, `/tmp/rilova-watch-build.log`.

Tests ran on a separate QA simulator. The user's existing simulator was not reset, seeded or uninstalled. Installing the rebuilt app under the same bundle ID preserves its existing data container.

## Limits

No full UI-suite rerun is claimed: this branding change uses focused affected-flow tests. No physical-device validation, App Store upload, trademark clearance, purchase metadata publication or signed integration verification occurred. Existing release-readiness gates remain open. No commit or push was requested for this pass.

## Original artwork refinement

The final approved icon supersedes the earlier vector reconstruction: original gradient and dark artwork extracted from the board. See `design/brand/rilova/extracted-original/README.md` for provenance, exact preservation assertions and the 388px source-resolution limit. The earlier onboarding screenshot above documents the preceding icon, not this final artwork.

### Original-icon verification results

- Extraction assertions passed: all symbol-rectangle pixels unchanged at native resolution; 136,996 original interior pixels preserved per icon. Production exports verified 1024 × 1024, opaque; applied files byte-match inspected exports.
- Debug native test run: 2 AppShell identity tests and 2 onboarding UI tests, zero failures. The welcome/relaunch path and native accessibility audit passed. No full UI/unit-suite rerun is claimed for this asset-only refinement.
- Unsigned Release iPhoneOS build and standalone Watch simulator build succeeded, including asset-catalog compilation.
- Small-size masked previews visually reviewed. The icons are raster extractions/interpolated exports, not true 1024px originals or vector masters. Actual-device Home Screen/tinted rendering remains pending.
- Logs: `/tmp/rilova-original-icon-tests.log`, `/tmp/rilova-original-icon-release.log`, `/tmp/rilova-original-icon-watch.log`. Native result bundle: `/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.07_21-19-15--0600.xcresult`.
- Existing user simulator updated under the same bundle ID without reset, uninstall or fixture seeding. No tracking logic, permissions, storage identifiers or dependencies changed.
