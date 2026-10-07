# Testing Strategy

## Habit starter creation

The catalog is static draft data; critical behavior is verified through the
native creation flow rather than tests that merely mirror its entry count.
UI checks cover editable weekly presets persisting through relaunch, cancellation
without writing a habit, browsing/back navigation preserving draft fields,
cut-down success wording and search at AX3, plus unmodified custom creation.
Selecting an idea never grants permissions or bypasses creation limits.

## Native logging integrations

Shortcut tests exercise idempotent habit logging, due/archive/stale ID validation,
duplicate names with stable IDs, skip replacement, completion provenance and
additive self-reported minutes. Health tests use an injected provider to verify
explicit permission requests, unknown/below-target data, target updates and
concurrent disconnect, skip/manual preservation, exercise targets, persistence,
midnight and error handling. Disk migration is tested against the previous MVP
schema without resetting data.

Native UI checks cover opt-in Health setup and the Siri/Shortcuts guide, with
attachments for visual review. Unit fakes do not prove actual read authorization,
phone/watch aggregation, Siri recognition or system action discovery; perform
those signed-device checks in `TESTFLIGHT_CHECKLIST.md`. No test records audio or
uses a developer account credential.


## Release philosophy

Critical behavior must be testable independently from SwiftUI.

## Unit tests

Required for:
- daily streak calculation
- flexible weekly completion logic
- skip behavior
- recovery calculation
- attention threshold state
- weekly summary metrics
- companion-state derivation
- subscription entitlement interpretation where feasible

## Date/time tests

Must include:
- local midnight boundary
- week boundary
- daylight saving transition
- time zone change
- month/year boundary

## UI tests

Critical flows:
1. first launch / onboarding
2. create daily habit
3. create 3x/week habit
4. log completion
5. undo completion
6. create attention budget
7. manual usage entry
8. weekly review navigation
9. paywall presentation
10. restore purchase path
11. notification permission denial path

## Widget tests

Verify:
- correct snapshot
- no-data state
- logged-in/app-state equivalent is not assumed
- update after completion where supported

## StoreKit testing

Use StoreKit test configuration.

Test:
- successful purchase
- cancelled purchase
- pending purchase
- restore
- expired entitlement
- StoreKit unavailable

## Accessibility checks

Before release:
- VoiceOver labels
- Dynamic Type
- touch target sizes
- Reduce Motion
- dark mode

## Manual release checklist

- airplane-mode core flow works
- no crashes after app relaunch
- data survives restart
- no placeholder copy
- no broken deep links
- privacy disclosures match implementation

### Native reminder-action verification — 2026-10-05

Added 11 reminder-action unit tests and 3 native UI tests. The serialized final
run passed **296 unit tests + 10 targeted UI tests**, zero failures. This is not
a new run of all 59 available UI tests. Native UI covers actual local-notification
delivery/expansion/action routing, named review, Cancel (no history), ordinary
opening (no history), and confirmed persistence after relaunch. Regression
selection also covers shell navigation/relaunch, completion/undo, archive
Cancel, detail refresh, attention quick-log/undo, optional onboarding and the
Shortcuts guide. Notification and confirmation screenshots were reviewed.

Results: `/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.05_09-10-31--0600.xcresult`;
log `/tmp/avela-reminder-verified.log`. The isolated iPhone 18 Pro Max simulator
was used; the owner's Pro simulator was untouched. Release unsigned iPhone
build passes (`/tmp/avela-reminder-release-final.log`); all DEBUG fixture/store/
notification-delivery markers are absent from the binary.

Real-device unlock/Face ID, cold process launch by a notification action,
VoiceOver, and large-text notification presentation remain manual checks.

## Calendar history and appearance tests — 2026-10-05

`HabitCalendarCalculatorTests` and `HabitCalendarViewModelTests` cover daily
outcomes, excused skips, undo, archive boundaries (including next-day reactivation
without a full dormant day), weekly distinct-day targets, open last-day-of-week
behavior, partial-week spans, historical edits, stored keys after travel, previous
and next month navigation after travel, weekday alignment, Buddhist-calendar civil
dates, DST and read-only navigation.

`AppThemeTests` covers no-write defaults, fallback for unknown saved values,
single-row preferences, disk relaunch, independent companion preferences,
previous-schema upgrade preservation, failed reads/writes and all five native
light/dark palettes' text/control/feedback contrast.

Native flows in `MVPFlowTests` verify populated month navigation without logging,
weekly history at accessibility text size, and immediate theme selection retained
after relaunch. Fixture-seeded tests remove their seed launch variable before
relaunch so existing data is not duplicated. Month cells expose combined
accessibility elements (not necessarily `staticTexts`); queries target identifiers
across element types. Detail's lazy List may need scrolling before a large-text
calendar navigation row is materialized.

Physical-device VoiceOver focus order, Increase Contrast and OLED/glass rendering
remain manual release checks. Automated contrast covers opaque colours, not every
system-material compositing result. See SETUP.md for actual run evidence.

## Personal habit ordering

Repository regressions cover disk relaunch and fact/timestamp preservation,
complete active-ID validation, stale creation/archive requests, archived slots,
reactivation/new appends and deterministic legacy collision repair. Feature-state
tests cover cancellable/multiple-row drafts, boundary moves, not-due habits,
Today completion preservation and reload after a changed active set.
Native flows cover drag handles, Cancel, Save, relaunch, unchanged History and completion/undo,
plus the Settings entry point and Move controls at accessibility XXXL. Native
VoiceOver focus and drag ergonomics on a signed device remain release checks.

## Optional schedule adjustment coverage

HabitAdjustmentTests exercise the pure proposal calculator using real local
repository facts, including two closed weekly misses, skips/pending/pauses,
completed recovery, schedule changes and non-eligible habit kinds. View-model
tests cover read-only review, explicit save/history preservation, invalid
frequency, stale day/revision/archive/recovery and repeated confirmation. Native
UI tests exercise cancel/review/confirmation/relaunch and accessibility XXXL.
AppThemeTests include disk reopening for the four additional themes and legacy
raw-value preservation; all-case contrast checks include all nine pairs.

### Full theme contrast and calendar regression

AppThemeTests now measures neutral reading ink on themed page/card endpoints and
white on sampled hero gradients for all nine light/dark themes. Native flows
cover theme persistence, month browsing without logging, accessible weekly/date
history and completion/undo. This styling does not add domain computation.


## Design quality implementation

Native accessibility audits now cover hit regions, descriptions, clipped text and traits on Today, Calendar, onboarding welcome, History, Insights, Settings, the paywall and a largest-text weekday form. No audit issue is suppressed. Regressions exercise confirmation dismissal/Done undo and exact completion IDs across repeated undo and midnight. A measured 1,095-day calculator test establishes a simulator calculation baseline, not a hardware UI performance claim.


## Feature expansion coverage

Activity integration tests cover partial/threshold logging, smaller-action idempotence without streak inflation, quantity-generated completion withdrawal, captured units/revisions, historical target stability, stale fact/configuration review, non-Gregorian calendars, invalid/paused/future days and explicit timer consumption. System action tests verify unmet quantities cannot bypass targets or erase skips. Routine tests cover stale selections, cancellation, fact preservation, ordering and disk reopen; reflection tests cover validation, cancellation, persistence/errors and schema additions. Watch DTO/service tests cover expiry, DST, unavailable phone, schedule/archive/quantity guards and repeated messages.

Native UI flows verify quantity/smaller-action relaunch distinction, routine check-in and reflection Save/Cancel/relaunch. Largest-text configuration and existing core/undo paths are targeted regressions. Actual paired Watch UI, Siri execution, background delivery, real VoiceOver and all UI tests remain separately reported; compiling an embedded Watch app does not establish these behaviors.

Enrichment regression coverage includes captured-date confirmation after reload/midnight, target/polarity conflicts, migration from a schema without the six new models, idempotent smaller actions and Watch requests, named pause cancellation, restart commitment counts, and session/intention separation. The hardware Watch and VoiceOver gates remain pending; simulator accessibility checks do not satisfy them.

## Factual reflection context

WeeklyReflectionTests additionally verifies selected-week isolation, skipped/open commitment exclusion, note-text independence from metrics and Insights-to-Reflection week selection. Native flows cover populated recorded context and existing Save/Cancel/relaunch. No model inference or journal analysis is involved.

## Private recovery tests — 2026-10-05

CloudBackupTests verifies disk reopen/identity retention, histories and all eligible
record families, existing-data/unsaved-change refusal, corrupt/future/duplicate/
dangling-reference rejection, Health-connected and Health-imported exclusions,
notes omitted without changing local records, timers paused/reminders disabled/
unfinished sessions unresolved, upload failure/account-change semantics, explicit
preview/cancel/restore/delete and placeholder-container safety. Native UI tests
exercise the unavailable control and isolated fake-provider recovery after both
Cancel and confirmation, then relaunch. They never access a user's store or cloud.

Real CloudKit upload, schema, signed recovery, quota and account behavior require
the signed-device procedure in SETUP.md; simulator tests cannot close those gates.

Recovery verification: **423 unit tests + 4 targeted UI tests, zero failures**.
Details and native screenshot: [private recovery verification](verification/cloud-recovery/README.md).

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

### Recovery card checks

`TodayViewModelTests` verifies typed two-success recovery, exact third-success Undo, mixed day/week wording and positive-only support eligibility. Existing domain tests remain the authority for skips, pauses and weekly units. `MVPFlowTests.testRecoveryCardToolsKeepSmallerActionsSeparateAndCancellationSafe` verifies cancel, separate effort logging and relaunch. `testRecoveryCompletionUndoAtAccessibilityTextSize` verifies threshold confirmation, five-second Undo availability, exact reversal and relaunch at AX3. Native evidence and remaining physical accessibility gates: [recovery-card](verification/recovery-card/README.md).

### Visual Insights verification

`InsightsViewModelTests` adds coverage for archived habit identity/read-only detail navigation and session-only goals without a phantom budget. `MVPFlowTests` adds populated chart/detail/filtered-History/relaunch coverage and largest-text navigation. Existing Insights UI tests retain empty, insufficient, week-clamp, tie, balanced, valid-trend and incompatible-cohort guarantees. The fixture deliberately includes a usage day exactly at budget; it is excluded from the below-budget rate under existing rules. Native evidence: [visual-insights](verification/visual-insights/README.md).


## Reflection dictation — 2026-10-06

Owner-approved optional dictation is available in each Weekly Reflection editor prompt. Start explicitly requests optional microphone/speech access only where on-device recognition is supported; audio is ephemeral, with no network fallback or saved audio. Review/Edit → Add Text appends to the draft, and Save persists independently of metrics. Seven capture-controller tests cover unsupported/denied access, permission-wait cancellation, late callbacks, errors and append/limit behavior. Eleven existing reflection tests and two targeted UI flows passed (review/cancel/append/explicit save, existing save/cancel/relaunch). UI transcript editing is a review test, not simulated proof of microphone recognition. Hardware speech, locale availability, permissions, interruptions and background capture cleanup remain required device checks.


## Make Room → Do It — 2026-10-06

Habit Detail → Make Room now lets the user create a Focus or Phone-Free goal in place, explicitly start a session and optionally request the mascot/countdown Live Activity. Focus permits phone use; Phone-Free records an intention without blocking or monitoring apps. Existing phone-free history is preserved. Session outcomes and actual habit logging remain independent: Log What I Did opens the existing habit logger without importing elapsed minutes or automatically completing the habit. Active-session review survives relaunch; failed intention-link writes do not replace the newly started session's review destination with an older session.

All 473 unit tests and four affected UI flows pass. Debug and Release build; production binaries contain none of the checked DEBUG store/fixture hooks. This is a full unit run and a targeted UI run, not a full UI-suite or physical-device certification. Native screenshots, exact commands and remaining device checks: [Make Room verification](verification/make-room/README.md).

## Differentiation regression coverage

Momentum tests cover pending unknowns, excused pauses/skips, recovery threshold/undo, weekly units, separate smaller effort, lifetime retention and missing habits. Recovery tests cover current-revision evidence, weekly/due-day eligibility, current successes, skipped/paused time, stale day/action, explicit indefinite pause and no automatic writes. Memory tests cover validation, preserved history, disk reopen/hide, private backup omission and factual weekly starts. Companion tests cover four distinct poses, precedence/provenance, missing data and saved-vs-transient progress. Targeted UI and old-store migration evidence: [verification](verification/differentiation/README.md).


## Quick Log widget — 2026-10-07

Full unit suite: 519 tests, zero failures, including 18 new Quick Log tests for capability guards, idempotency, source, next-day preservation, ordering, accessibility capacity, summary honesty and projection compatibility. Three affected UI regression tests pass. Real SpringBoard background logging (including terminated app), name navigation, quantity route and stale-day refresh were separately verified with temporary drivers, then removed. This is targeted UI coverage, not a full UI suite. Release app/widget binary inspection confirms checked DEBUG hooks absent. Commands and native evidence: [Quick Log verification](verification/quick-log-widget/README.md).


## Rich Tide widgets — October 7, 2026

The Home Screen gallery now offers **Quick Log** and **Routine**, each in small/medium. Approved Rich Tide uses deep theme gradients and contrasting labelled Log buttons. Remove retired Attention/Progress placements and add the replacement. Routine requires a saved routine selected in Edit Widget. Log saves a simple check-in without opening Avela; names and quantity + open the relevant app screen. Native light/dark/largest-text screenshots, 523 passing unit tests, guide UI regression, background logging checks and Release verification are recorded in [widget verification](verification/two-widgets/README.md).
