# Dependencies

## Principle

V1 should minimize third-party dependencies.

This app can be built almost entirely with Apple frameworks.

## Required runtime frameworks

No external package installation required for:

- SwiftUI
- Charts (native read-only report plots)
- SwiftData
- Foundation
- Speech (optional on-device reflection dictation)
- AVFoundation (explicit reflection microphone capture)
- UserNotifications
- StoreKit 2
- WidgetKit
- ActivityKit
- AppIntents
- HealthKit (optional steps/exercise reads; app entitlement required)

These ship with Apple's SDKs.

## Future Apple capabilities

These also do not require package-manager installation, but may require capabilities / entitlements:

- FamilyControls
- DeviceActivity
- ManagedSettings
- CloudKit

## Third-party dependencies

### V1 default
None.

### RevenueCat
Status: OPTIONAL / POST-MVP unless deliberately pulled forward.

Use only if we need:
- subscription analytics
- entitlement abstraction
- easier paywall experiments
- cross-platform subscription support

If introduced:
- document package version
- why it is needed
- which layer owns it
- how to remove or replace it

### Supabase
Status: POST-MVP.

Use only if product requirements require:
- user accounts
- non-Apple sync
- server-side features
- Android/web interoperability
- shared/social data

Do not add Supabase solely because "apps need a backend."

## Dependency approval rule

Before adding any package, update this file with:

```text
Package:
Purpose:
Why Apple-native APIs are insufficient:
Owning module:
Data/privacy implications:
Removal strategy:
```

## Prohibited without explicit approval

- generic networking frameworks
- generic DI containers
- analytics/ad SDKs
- attribution SDKs
- remote-config SDKs
- crash tools that collect unnecessary user data
- UI component kits that compromise native design consistency


## Optional recovery — 2026-10-05

CloudKit (private Apple iCloud database) and CryptoKit (SHA-256 integrity check)
are native frameworks used by owner-approved recovery. No third-party dependency,
backend, analytics, generative AI or network framework is introduced. A real signed
CloudKit container is required; placeholder builds remain local-only.


## Reflection dictation frameworks — 2026-10-06

Apple Speech and AVFoundation are runtime SDK frameworks for optional on-device reflection transcription and microphone capture. No third-party library or package is introduced. On-device capability is mandatory, with no cloud recognition fallback. Both remain behind the reflection platform adapter and can be removed without changing persisted reflections.


## Calendar planning — 2026-10-07

EventKit and EventKitUI are Apple-native runtime frameworks for optional event creation through the system editor. No third-party package, calendar-fetching SDK, OAuth account or backend is added. The app doesn't request calendar read access. FamilyControls, ManagedSettings and DeviceActivity remain unimplemented future runtime capabilities, subject to the documented shielding release gates.


## Optional app protection — 2026-10-07

FamilyControls, ManagedSettings and DeviceActivity are now used by the owner-approved development integration. Native frameworks only; no package/backend. The app and Device Activity Monitor extension need Family Controls and shared-group provisioning. Automatic Screen Time metering remains unimplemented. See SCREEN_TIME_INTEGRATION_PLAN.md for permission/privacy boundaries and release gates.

## Expressive World artwork and motion — 2026-10-21

The illustrated coast and focus sanctuary are bundled local image assets,
generated during development with the built-in image tool. Prompts, asset paths
and the dark-coast reference relationship are recorded in
[the provenance JSON](../design/brand/rilova/world/provenance.json). No competitor
assets or new character-art runtime are introduced.

Reports use Apple's Charts framework; transitions and short triggered keyframes
use SwiftUI, with Reduce Motion alternatives. These require no package manager
or third-party animation runtime. This pass adds no package, backend, runtime AI,
remote art service, analytics SDK, permission or entitlement. The existing native
framework and integration requirements above remain unchanged. Build, native UI
and hardware results are recorded separately; this dependency note claims none.
