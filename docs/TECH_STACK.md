# Technical Stack

## Platform

- iOS
- Swift
- SwiftUI

## First-party Apple frameworks

Core:
- SwiftUI
- SwiftData
- Foundation

System capabilities:
- UserNotifications
- StoreKit 2
- WidgetKit
- ActivityKit
- AppIntents (Siri and Apple Shortcuts)
- HealthKit (optional steps/exercise reads; app entitlement required)

Future / optional:
- FamilyControls
- DeviceActivity
- ManagedSettings
- CloudKit

## Persistence

V1:
- SwiftData

Future:
- CloudKit/iCloud or Supabase only if product needs justify them

## Networking

V1 should not require a general-purpose networking layer for core flows.

If networking is introduced:
- prefer `URLSession`
- avoid third-party HTTP frameworks unless a real requirement appears

## Dependency policy

Default: zero third-party runtime dependencies for V1 unless they clearly reduce risk or complexity.

Do not add:
- analytics SDKs
- networking frameworks
- dependency-injection frameworks
- design-system frameworks
- animation frameworks

without documenting the reason in `DEPENDENCIES.md`.

## Subscription implementation

Prefer StoreKit 2 directly for V1.

RevenueCat may be introduced later if subscription analytics, entitlement management, experiments, or cross-platform subscription infrastructure justify it.

## Testing

Use Apple-native test tooling first:
- XCTest
- XCUITest / UI testing
- StoreKit configuration files

Adopt newer Swift testing APIs only if project/toolchain choice is explicitly standardized.

## Toolchain

Use the current stable Xcode version available to the development environment.

The project must declare:
- minimum iOS deployment target
- Swift language mode
- signing requirements
- required app capabilities

in the Xcode project and document them in `SETUP.md`.


## Optional recovery — 2026-10-05

Native CloudKit private-database snapshots protect eligible tracking after opt-in.
CryptoKit computes payload integrity checks. Local SwiftData uses .none for
CloudKit and remains the primary store. This is logical backup, not SwiftData
cloud synchronization; no uniqueness constraints are removed.


## Optional on-device reflection dictation — 2026-10-06

Avela uses Apple Speech and AVFoundation when you explicitly start reflection dictation. Microphone and speech recognition permission are optional. Recognition must be supported on-device; no server fallback is used. Audio is transient and not saved. Only reviewed text added to a draft and explicitly saved becomes a reflection. Saved notes remain excluded from Avela's logical iCloud recovery copies, while Apple device backups may include them. Earlier statements that Avela never accesses the microphone are superseded for this feature. Typing remains available without permissions.
