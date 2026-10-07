# Two focused widgets — Rich Tide

October 7, 2026. Quick Log and user-selected Routine replace the previous Progress/Attention gallery registrations. Small and medium are sizes of these two types. Existing active-session Dynamic Island is unchanged. The owner approved B · Rich Tide from the [design proposals](../../../design/exploration/widget-refinement/README.md); the native implementation is installed on the owner's simulator without resetting or uninstalling the app.

## Native screenshots

[Quick Log medium — light](rich-quick-log-medium-light.png) · [Quick Log small — light](rich-quick-log-small-light.png) · [Routine medium — light](rich-routine-medium-light.png) · [Routine small — light](rich-routine-small-light.png)

[Quick Log medium — dark/largest text](rich-quick-log-medium-dark-largest.png) · [Quick Log small — dark/largest text](rich-quick-log-small-dark-largest.png) · [Routine medium — dark/largest text](rich-routine-medium-dark-largest.png) · [Routine small — dark/largest text](rich-routine-small-dark-largest.png)

[Routine saved without opening the app](rich-routine-logged-light.png). Earlier unprefixed neutral screenshots are historical functional evidence, not final styling.

## Verification

- 523 unit tests passed, zero failures. Includes 21 functional Quick Log/routine tests and one all-theme contrast regression. Primary/secondary text and Log ink meet 4.5:1 against both gradient endpoints; action boundaries meet 3:1. Increase Contrast/Reduce Transparency uses a solid deep surface.
- Updated widget guide UI test passed, including routine setup instructions.
- Native isolated-simulator runs passed in light/default text and dark/largest accessibility text. Both small and medium widgets were captured and visually reviewed. Routine Log saved a Reading check-in and advanced its summary without Avela becoming foreground. Earlier direct Quick Log and native Edit Widget routine selection also passed.
- Debug tests build; Release build succeeds. App and widget Release binaries contain zero matches for `AVELA_UI_TEST_STORE_PATH`, `AVELA_UI_TEST_SEED_FIXTURE`, and `DebugFixtures`.
- Temporary SpringBoard screenshot/logging drivers were removed after verification. They operated only on isolated demo data. The owner's simulator was updated in place after validation; no reset, uninstall or seeded fixtures.
- Project integrity: 217 Swift sources, zero issues; `git diff --check` clean.

## Setup

Remove any retired Attention/Progress placement, then add **Quick Log** or **Routine** from Avela's widget gallery. For Routine, first save a routine in Avela, then touch and hold the widget → Edit Widget → choose it. Tap **Log** to save a simple check-in here. Habit names open details; quantity **+** opens the amount logger. No bulk completion or fabricated quantities.

Routine export reads saved ordered IDs and intersects with canonical Today rows; quantity, skip, archive, time-zone and revision guards are preserved. No schema, permission or dependency change. Successful routine saves/deletes invalidate projections only after commit.

Physical-device background routing, local authentication, VoiceOver, system widget tinting, long arbitrary names and actual refresh scheduling remain device verification. No full UI-suite run is claimed for this styling pass. No commit or push.

## Cold logging / blinking follow-up

The owner reported blinking before save and an initial foreground launch. Inspection found `invalidatableContent()` on the complete Log button; Apple's waiting-content rendering could affect its label and filled background. It now applies only to the status caption; Log and Refresh controls retain their appearance while saved data is refreshed. No optimistic completion is fabricated.

The shell's persistence notification no longer publishes an unpinned widget snapshot while its scene is inactive: the background widget intent publishes its final pinned snapshot after saving. Foreground app edits still publish immediately. This removes a redundant background export that could compete with the final display projection. Permission, schema and data ownership are unchanged; MVP direct-check-in behavior remains the same.

A native cold-process driver terminated Avela before each Reading/Walk Log tap. Both saves passed, removed the corresponding Log control, and left Avela out of the foreground. The earlier baseline also passed without opening UI: the reported foreground launch was **not reproduced**, and is not claimed fixed. Names and unhandled background regions still intentionally open Avela. A question was sent to identify which region was tapped.

After the changes: all 523 unit tests pass; the native cold-process flow passes; Release builds and excludes DEBUG fixture/store markers. The driver is removed and the update installed on the owner's simulator without resetting data. [Saved Reading](cold-widget-saved-reading.png) · [Saved Walk](cold-widget-saved-walk.png).

Cold checks took about 6.6 seconds including XCTest tap synchronization and hierarchy queries; this is not a precise user-visible latency benchmark or a claim of instant saving. WidgetKit app-process startup and refresh scheduling remain system-controlled. Physical-device first-use behavior still needs verification.
