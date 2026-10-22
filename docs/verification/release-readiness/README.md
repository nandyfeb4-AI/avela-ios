# Account-independent release readiness — October 7, 2026

This pass verifies work that can proceed while Developer Program enrollment is pending. It is not TestFlight certification, App Review approval or physical-device verification.

## Changes

The in-app Privacy screen now explains user-reviewed Calendar planning, calendar-specific sharing/sync and the separation from habit logging. Its removal section explicitly says uninstalling does not delete optional iCloud recovery copies, and identifies Progress Protection as the deletion control. The policy draft's introduction no longer contradicts optional development app protection. No tracking schema, permissions, subscription terms, dependency or theme changed.

The App Protection Settings entry now uses the same wrapping label, icon treatment and minimum row height as the other Settings entries; the native audit initially reported its old system-labelled button text as clipped. This finding passes after the change. Scrolling the habit form immediately dismisses the keyboard so schedule controls have room; the saved name/reason remain in the draft.

The existing privacy UI regression now verifies both disclosures are reachable without Premium. Native accessibility audits and persistence/recovery regressions are rerun against the current implementation. Actual results are recorded below.

## Remaining release gates

| Gate | Can progress before membership? | Required evidence/configuration |
| --- | --- | --- |
| Core local logging, Undo, relaunch and migration | Yes | Native unit/simulator regressions; device upgrade check later |
| Visual and accessibility quality | Partly | Simulator audit/screenshots now; physical VoiceOver, alternative input, OLED and usability checks later |
| Public privacy/support information | Yes | Owner-approved publisher/contact and working HTTPS URLs; draft alone is insufficient |
| Production signing and App Groups | No | Activated team, final bundle/group IDs and matching profiles for embedded targets |
| Selected-app protection | Code/simulator only | Signed iPhone authorization, selection, expiry/termination/reboot/revocation; distribution approval for app and monitor |
| Health, Siri, Watch, notifications, widgets, Live Activities, Calendar | Partly | Actual signed-device permissions, pairing/background/locked behavior and delivery |
| Private iCloud recovery | Code/fake-provider only | Real container, Production schema and signed upload/restore/deletion tests |
| StoreKit | Local StoreKit configuration only | Products, agreements, sandbox purchase/renewal/restore and TestFlight checks |
| Archive and submission | Preparation only | Final Release archive, privacy report, metadata and reviewer instructions |

App protection remains disabled at runtime in Release. The Family Controls entitlement and monitor are still embedded: hiding UI does not remove the distribution approval requirement. If approval is unavailable when shipping, omit the capability and extension from that shipping configuration and validate it separately.

Existing progress must never be reset to solve an upgrade problem. Recovery tests use isolated stores and a fake provider; they do not access the owner's data or Apple account. The owner's simulator is never uninstalled/reset/seeded.

Full authority and detailed steps remain in [TestFlight checklist](../../TESTFLIGHT_CHECKLIST.md) and [quality checklist](../../QUALITY_EXECUTION.md). No award/accessibility-label claim follows from passing automated audits.

## Native previews

[Settings](settings.png) · [Calendar disclosure](privacy-calendar.png) · [Recovery-copy deletion disclosure](privacy-deletion.png). Images use isolated test data, not the owner's tracking.

## Results — form audit resolved

- Full native unit baseline: **545 tests, zero failures** (`/tmp/avela-readiness-tests.log`). This presentation fix changes no domain, schema or persistence behavior; that unit suite was not rerun for the layout-only change.
- The earlier eight selected passing flows remain recorded in `/tmp/avela-readiness-tests.log` and `/tmp/avela-readiness-followup.log`.
- The final affected UI run passes **three tests, zero failures** (`/tmp/avela-reason-complete.log`): largest-text weekday creation/validation/targets/persistence, largest-text private-reason editor/audit/hide/save/relaunch, and reason/Momentum/relaunch. Together with the earlier runs, ten distinct selected flows have passed. This is **not** a full UI-suite run.
- Both largest-text screens pass native hit-region, description, text-clipping and trait audits with **no issue suppressed**. The weekday audit also passed in two preceding runs; the populated reason-editor audit and persistence passed independently in `/tmp/avela-reason-readable-retry.log` before the final combined run.
- The original unlocated clipping finding is resolved by changing the optional-memory presentation: a wrapping navigation row after core setup opens a separate editor; short explanatory rows replace one oversized paragraph; the visibility label is shorter; weekday labels can grow vertically. The editor has a native keyboard Done control. Saved text, visibility, the 240-character validation and privacy exclusions are preserved.
- Temporary layout trials are historical diagnostic evidence, not shipped layouts. No OS-defect claim was established. Early attempts also encountered simulator launch failures before interaction; largest-text tests now configure their launch once rather than immediately terminating and relaunching to set the text size.

[Largest-text reason editor](reason-largest-text.png) · [Largest-text weekday setup](weekday-largest-text.png). Images use isolated data. Existing owner progress was never reset, uninstalled or seeded.

MVP scope is confirmed unchanged: this refines existing disclosures and presentation. Physical VoiceOver/alternative-input checks, signed integrations, public policy/support URLs, Apple account/configuration and actual StoreKit/CloudKit verification remain release gates. No commit/push was performed.

Final combined result bundle: `/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.07_17-38-40--0600.xcresult`.

## Final build and packaging

The final Debug simulator test build and unsigned Release iPhoneOS build succeed. Logs: `/tmp/avela-reason-complete.log` and `/tmp/avela-reason-release.log`. Release app/widget/monitor binaries exclude the checked store-path, seed-fixture, DebugFixtures and DebugCloudBackupProvider markers; the protection availability key is still NO. Project membership: 227 Swift sources, zero issues. Project/privacy-manifest plist lint and whitespace checks pass.

[Original automated audit failure capture](audit-failure.png) shows the empty viewport associated with the unlocated issue; it is not a normal user-facing screen or proof of the root cause. The optional reason remains implemented; this capture is retained as historical evidence, not an open finding.
