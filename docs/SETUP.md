# Development Setup

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
- The app saves one temporary `ScaffoldRecord` on first initialization instead of
  seeding a habit. This deliberately keeps Phase 0 outside the canonical product
  schema. Reopening a disk store is covered by a unit test.

### Build and test

Open the project in Xcode, select **Avela**, and choose an installed iPhone
simulator. Run with Cmd-R and test with Cmd-U. The shared scheme includes both test
bundles and builds the embedded widget through the app's target dependency.

From the repository root:

```sh
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

Unit tests check shell destinations, SwiftData initialization, and disk persistence
across container recreation without duplicate seeds. The UI smoke test checks all
four tabs and a clean app relaunch. No product flow tests exist yet because no
product behavior has been implemented.

For manual scaffold verification, launch, visit each tab, relaunch, and check light
and dark appearance and larger Dynamic Type sizes. Add the Avela Scaffold widget
to the simulator Home Screen to inspect the intentional development placeholder.

### Initial validation environment

The scaffold was created on a machine with Command Line Tools (Swift 6.3.1) but no
full Xcode or simulator runtime. Project/plist validation and Swift parsing can be
performed here; iOS compilation, XCTest, and UI verification require full Xcode.
Do not interpret these static checks as a passing iOS build or test run.
