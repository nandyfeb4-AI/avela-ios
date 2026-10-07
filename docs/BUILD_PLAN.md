# Build Plan

## Habit setup enrichment — 2026-10-05

Added an optional eight-idea starter library in the shared new-habit form.
Selection pre-fills editable fields; saving and free-tier checks remain in the
existing creation flow. Editing existing habits does not expose replacement.
Local search, native symbols and scalable rows require no new dependency,
entitlement or schema. The same form is used by Today and onboarding.

Native tests exercise customization/save/relaunch/edit, cancellation without
creation and avoidance wording at AX3. Large-text testing caught the long intro
pushing a result behind the search keyboard; the intro was shortened, omitted
while filtering, and interactive keyboard dismissal enabled. See `SETUP.md`
for final validation evidence: 285 units + 4 targeted UI checks pass, and
unsigned iPhone SDK Release compilation succeeds. Real-device VoiceOver remains
a release check.

## Owner-approved logging enrichment — 2026-10-04

Added Siri/Shortcuts logging (8 service tests, native guide UI) and opt-in Apple
Health steps/exercise targets (13 provider/persistence tests, native setup UI).
Existing tracking remains available on Free; no backend or external dependency.
Health configuration adds one optional model and preserves a prior MVP disk store.

Current evidence: **285 unit tests, zero failures**; **10 MVP UI flow tests,
zero failures**, plus focused completion/undo and attention quick-log regression
checks. This is targeted UI coverage, not a rerun of the entire earlier UI suite.
Debug tests and unsigned iPhone SDK Release compilation pass; DEBUG hooks are
absent in Release, read-purpose copy is bundled, and App Intents metadata is
extracted. Exact logs/commands are in `SETUP.md`. Native setup screenshots were
reviewed. Spoken Siri, system action discovery and real Health read authorization/
source aggregation remain signed-device release gates. In-app microphone voice,
sleep/mindfulness interpretation and automatic Screen Time remain deferred.

## Current implementation status — 2026-10-04

The sections below retain the earlier slice history. Current code additionally
implements skip/undo UI, protected attention windows and persistent phone-free
sessions, manual duration usage in History and weekly review, weekday patterns,
local reminders, account-free onboarding, companion state/preferences, StoreKit
2 purchase/restore/free-tier enforcement, and habit/attention widgets.

Implementation is not equivalent to TestFlight readiness: final artwork/device review,
public privacy/support information, App Store Connect products, signing/App
Groups and physical-device verification remain required. Original owl/fox/otter six-pose artwork is now bundled in the app and
Home Screen widgets, with subtle native state transitions and Reduce Motion
support; review the actual device presentation before release. The optional Live Activity now presents a real phone-free session with its
selected companion in Dynamic Island and Lock Screen, following explicit opt-in.
See [release checklist](TESTFLIGHT_CHECKLIST.md).

Final combined simulator validation: **243 unit + 49 UI tests, zero failures**.
Debug tests, Release simulator and unsigned iPhone SDK builds succeed; DEBUG hooks are absent from
Release. Native captures additionally caught and corrected the previously
unselected teal accent and large-text icon overflow. Exact commands and
evidence are in [SETUP.md](SETUP.md#final-verification-evidence--2026-10-04).
No signed-device run, distribution archive validation or upload has occurred.



## Phase 0 — Repo scaffold

Create:
- Xcode project
- app target
- widget extension
- Live Activity extension if included in V1
- test targets
- documentation folder
- base navigation
- SwiftData container
- shared models / domain folder structure

## Phase 1 — Habit engine

Build:
- entities
- scheduling
- completion
- history
- streaks
- flexible weekly logic
- recovery

Exit criteria:
- unit tests pass
- Today screen can render real persisted habits

Status: both exit criteria met, and the habit lifecycle (not just creation) now
has UI. Canonical `Habit`/`Completion`/`Skip`/`HabitConfigurationSnapshot`/
`HabitArchivePeriod` entities, daily/weekdays/timesPerWeek scheduling,
`HabitRepository`/`SwiftDataHabitRepository`, `HabitScheduleEvaluator`
(due-day and weekly-progress logic), and `HabitProgressCalculator`
(current/best streak, consistency over an explicit range, and recovery
progress, including archive/reactivate and schedule-kind transitions). The
Today screen (`TodayView`/`TodayViewModel`) renders real persisted habits due
today, flexible-weekly progress, one-tap completion with immediate undo, and
habit creation. A habit detail screen (`HabitDetailView`/
`HabitDetailViewModel`), opened from Today without triggering completion,
shows current/best streak, recovery messaging, and a clearly-labeled
consistency window, and supports editing and archiving. Settings gained a
minimal real screen with an Archived Habits list and reactivation
(`SettingsView`/`ArchivedHabitsView`/`ArchivedHabitsViewModel`). Insights and
History were placeholders at this point in the build (both have since been
implemented; see below). Verified on 2026-10-02 with Xcode 27.0 and an
iPhone 18 Pro (iOS 27.0) simulator: 77 unit tests and 10 UI tests pass. See
docs/SETUP.md for commands and validation details, and docs/DATA_MODEL.md's
"Phase 1 progress metrics," "Phase 1 Today UI," and "Phase 1 habit lifecycle
UI" sections for the concrete rules and architecture these slices encode.

Streak/recovery/consistency values are shown on the habit detail screen (not
as a Today-screen dashboard — Today stays calm, per UX.md) and, as of the
Insights slice below, as an aggregated weekly review.

History is implemented as a focused, read-only slice: `HistoryView`/
`HistoryViewModel` show every completion and skip from the last 30 local
calendar days, grouped by each record's stored `localDateKey` (never
recomputed under the current time zone), with an archived-habits-included
habit filter and navigation from habit detail. No logging, editing,
backdating, deletion, charts, exports, or calendar UI was added — see
docs/DATA_MODEL.md's "Phase 1 History" section for the concrete rules.
Verified on 2026-10-03 with Xcode 27.0 and an iPhone 18 Pro (iOS 27.0)
simulator: 90 unit tests and 14 UI tests pass.

Insights is implemented as a focused, read-only, habit-only weekly review:
`WeeklyInsightsCalculator` (pure domain), `InsightsViewModel`, and
`InsightsView` show overall consistency (average of each eligible habit's own
weekly percentage — an explicitly confirmed denominator choice, not pooled),
the trend versus the preceding completed week in percentage points, the
strongest habit(s), and habit(s) needing attention based on misses in the
selected week only — never today's recovery state. Defaults to the last
*completed* local calendar week with simple Previous/Next navigation between
completed weeks; attention-budget results and weekday patterns remain
deferred, per MVP.md's "Weekly review" section. See docs/DATA_MODEL.md's
"Phase 1 Insights" section for the concrete rules, confirmed denominators,
and eligibility/tie-handling logic. Verified on 2026-10-03 with the same
toolchain: 112 unit tests and 16 UI tests pass. See docs/SETUP.md for
commands and validation details.

A same-day UX audit (`docs/UX_AUDIT.md`) reviewed Insights' trend and
ranking logic against three agreed rules and found two genuine gaps (the
trend compared incompatible habit cohorts across weeks; a single habit with
a partial week was named both "strongest" and "needing attention"
simultaneously), plus a Critical defect in the archive-confirmation dialog
found via live-app screenshots. All three were fixed in a dedicated
correctness pass the same day — see `docs/DATA_MODEL.md`'s "Audit-driven
correctness fixes," "Trend comparable-cohort rules," and
"Populated-Insights DEBUG fixtures" sections. No visual/layout changes, no
brand palette, and no new features were introduced in that pass — it was
correctness and verification only, with the three proposed visual directions
in `docs/UX_AUDIT.md` left for a future prototyping pass. Verified on
2026-10-03 (same day) in both Debug and Release configurations: 119 unit
tests and 22 UI tests pass.

A same-day small-UX-fixes pass (F2, F4, F5, F7, F12 from `docs/UX_AUDIT.md`'s
Part 6 Phase 2) applied five low-risk, non-visual-redesign fixes — see
`docs/DATA_MODEL.md`'s "Phase 1 small UX fixes" section. Verified in both
Debug and Release: 125 unit tests and 28 UI tests pass.

## Phase 2 — Attention engine

Build:
- attention goals
- manual usage
- threshold states
- protected windows
- phone-free session model

Exit criteria:
- manual goal can be created, tracked, and reviewed historically

Status: exit criterion partially met for this slice's declared scope —
manual goals can be created, usage logged/corrected/deleted, and today's
state reviewed; protected windows and the phone-free session model are not
implemented (see below). `AttentionGoal`/`AttentionGoalConfigurationSnapshot`/
`AttentionUsageEntry` entities, `AttentionGoalEvaluator` (historical budget
resolution, mirroring `HabitScheduleEvaluator`), `AttentionProgressCalculator`
(daily summing, missing-data-vs-zero `DailyProgress`, centralized
healthy/near-limit/exceeded thresholds), and `AttentionRepository`/
`SwiftDataAttentionRepository` implement only the `maxDurationPerDay` goal
family — the only one with a natural "log a quantity against a budget"
interaction, which is this slice's explicit scope. `noUseBeforeTime`,
`phoneFreeUntilTime`, and `phoneFreeSession` (protected windows / phone-free
session) are deferred in prose, not partial code. Today gained a second,
independent list section (`AttentionSummaryViewModel`) showing each goal's
manually-labeled status with a fast one-tap quick-log action, alongside the
unmodified habit section; a new goal detail screen
(`AttentionGoalDetailView`/`AttentionGoalDetailViewModel`) shows today's
entries with correction and deletion, both scoped to today only. See
`docs/DATA_MODEL.md`'s "Phase 1 Attention" section for the full set of
confirmed decisions (goal-type scope, budget-snapshot mechanism, local-day
summing, missing-data handling, today-only correction/deletion, Today
integration, and a SwiftUI `Button`+`.swipeActions` toolchain pitfall found
and fixed along the way). Verified on 2026-10-03 with Xcode 27.0 and an
iPhone 18 Pro (iOS 27.0) simulator, in both Debug and Release: 154 unit
tests and 33 UI tests pass. See docs/SETUP.md for commands and validation
details.

## Phase 3 — Core UX

Build:
- onboarding
- Today screen
- history
- insights shell
- settings
- empty states

Status: Today's visual direction and information architecture landed — a
Vivid Tidewater reskin (real semantic colour assets, from
`design/exploration/prototype-vivid/vivid.css`) of the "Tidewater Balance"
layout recommended in `design/exploration/TODAY_CONCEPTS.md`: a Habits/
Attention pillar strip, a collapsible "Done" group with a deferred regroup
and a branded undo toast, and fast inline attention logging — built on real
habit and manual-attention data, not the design exploration's deferred/
placeholder treatment. Forms, detail screens, History, Insights and Settings
received the same semantic colour tokens (state colours — recovery amber,
over-budget clay — plus the automatic brand-teal `AccentColor`) without an
information-architecture change; see `docs/DATA_MODEL.md`'s "Vivid Tidewater
UX pass" section for the full set of decisions, deliberate simplifications
versus the HTML prototype, and open items (onboarding, a full accessibility
device pass, and Insights'/History's own hero-card redesign are still not
done). No new product behavior beyond what that section documents, no
attention goal families, mascot, or system surfaces were added. A real
concurrency bug surfaced and fixed during this pass's own validation (two
un-cancelled background `Task`s racing a detail-screen navigation) is
documented in the same section. Verified on 2026-10-04 with Xcode 27.0 and
an iPhone 18 Pro (iOS 27.0) simulator, in both Debug and Release: 166 unit
tests and 40 UI tests pass.

## Phase 4 — Companion

Build:
- animal selection
- companion state engine
- core animations
- dashboard integration

## Phase 5 — Native system surfaces

Build:
- reminders
- widgets
- Live Activity for phone-free session if included

## Phase 6 — Insights

Build:
- weekly metrics
- strongest / weakest patterns
- recovery insight
- attention summary

## Phase 7 — Monetization

Build:
- StoreKit products
- entitlement manager
- paywall
- restore purchases

## Phase 8 — Compliance and release quality

Complete:
- accessibility
- dark mode
- privacy copy
- App Store metadata draft
- reviewer notes
- TestFlight build
- regression testing

## Scope firewall

Do not pull post-MVP items into the active build unless:
1. V1 requirement cannot work without it, or
2. `MVP.md` is explicitly changed.

## Optional session Live Activity — 2026-10-04

Included for this candidate after owner authorization: explicit Show/Hide controls
for existing phone-free sessions, selected mascot plus countdown in compact,
minimal and expanded Dynamic Island and Lock Screen layouts, and foreground
reconciliation through a native adapter. No outcome inferred from expiry, no
permanent pet, no new target/dependency/schema. Final source: 264 units and the
native ActivityKit UI flow pass; see SETUP.md for exact evidence and remaining
real-device/Lock Screen/minimal-layout checks.

### Owner-approved reminder enrichment — 2026-10-05

Implemented native Review & log actions, with generic notification previews and
an unlocked, named habit confirmation. Domain guards reject stale/non-due/
archived/unknown requests and preserve existing completions on repeated taps.
Ordinary opening and Cancel are read-only. Completion provenance is persisted
as `notification`; successful confirmation returns to Today for normal undo.
No new dependency, entitlement, permission, model table or remote service.

Verification: 296 unit tests + 10 targeted UI tests pass; Release unsigned
iPhone build passes and DEBUG hooks are absent. Native OS notification action
and confirmation screenshots reviewed. Signed-device authentication/cold-launch
and accessibility checks remain; this does not claim the full UI suite or
TestFlight readiness.

Competitor cue: Habitify describes completing a reading habit from its reminder
([official example](https://habitify.me/blog/develop-reading-habit-with-habitify-reading-habit-tracker)).
Avela adds identity confirmation because its existing notification text is
generic for privacy. Native action behavior follows Apple's
[notification-action guidance](https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions).

### Calendar and colour themes enrichment — 2026-10-05

Implemented owner-approved, read-only per-habit month history, connected daily
successes, separate flexible-weekly commitment outcomes, accessible date lists and
five free local app themes. Historical facts and scheduling still come from the
existing repository/progress engine; no backend or dependency is added. Theme
storage adds one appearance entity without altering companion-profile fields.

Regression work corrected unfinished-week closure and adjacent-day archive
boundary handling, and preserves access to stored dates across travel/month
boundaries. Native verification evidence is recorded in SETUP.md. Signed-device
accessibility, production signing/configuration and release readiness remain
separate work; this addition is not a TestFlight upload or App Store approval.

### Personal habit ordering enrichment — 2026-10-05

Free active-habit ordering is implemented via a cancellable native sheet, with
Save/Cancel, drag handles, Move Up/Down, large-text reflow and entry points from
Today and Settings. The existing sortOrder field is used; no schema, permission,
dependency or tracking change. Stale drafts are rejected and reloaded explicitly.
Verification results belong in SETUP.md; physical-device accessibility remains
part of the release checklist rather than a simulator-derived claim.

### Additional themes and lighter-schedule review — 2026-10-05

Implemented four more free app accents (Indigo, Forest, Coral, Gold), for nine
choices, and a small optional Make It Easier flow in habit detail. A pure domain
calculator offers an adjustable lower flexible-weekly frequency during repeated
misses/ongoing recovery; a dedicated view model revalidates the review before
explicit confirmation. Normal configuration snapshots preserve prior facts.
There is no automatic schedule edit, AI coaching or new permission/schema.
Native verification results and previews are recorded in SETUP.md. Signed-device
accessibility and distribution remain independent release gates.

### Full themes and streak styling refinement — 2026-10-05

Expanded the nine existing choices from accents into shared page gradients,
custom reading surfaces and deep hero styling. Today and Calendar History have
stronger themed progress hierarchy; other main screens and logging forms share
the canvas. No domain engine or persistence change. Native verification and
previews are recorded in SETUP.md; signed-device accessibility remains open.


## Design quality implementation

Applied the quality plan to core V1 journeys: adaptive weekday/picker controls, readable icon labels and progress context, scalable summaries, stable assistive-navigation confirmation, exact current-day Undo, informational calendar traits, reduced-transparency onboarding and wrapping Settings labels. Native audits and calculator/launch benchmarks are part of verification, not proof of complete device accessibility or award eligibility. See QUALITY_EXECUTION.md and SETUP.md for evidence and remaining gates.


## Owner approved feature expansion — 2026-10-05

Implemented optional manual quantity targets, additive quick increments, explicit elapsed-minute timers, separate smaller-action records, dated correction review, routine groups/3–7-day restart plans, private weekly reflection and a native Apple Watch target/WatchConnectivity adapter. Siri adds Log Habit Progress. These extend the candidate beyond the original MVP boundary under the owner's explicit request.

A Manageable Week review adds named, individually confirmed pauses and restart selection. Make Room links a phone-free session to a habit intention; its manually reported result remains separate from habit success. Neither implements automatic difficult-week rescheduling. Voice remains Siri/Shortcuts; external services, automatic Screen Time and cloud sync remain deferred. Native verification and paired Watch limitations are recorded in SETUP.md.

Enrichment verification completed: 411 unit tests and nine distinct targeted UI flows pass; largest-text setup additionally passes in dark appearance. Final Debug and unsigned iPhone/Watch Release builds pass. Native captures are in `docs/verification/enrichment/`; paired Watch and physical accessibility remain pending, and the full UI suite was not rerun.

## Factual reflection deepening — 2026-10-05

Implemented recorded per-habit weekly results beside private reflection notes, with skips/pending/pauses excluded through the existing calculator. Insights opens the selected review week instead of today. Notes are never analyzed, and no AI runtime/service, dependency or schema is introduced. That pass deferred backup/restore and dedicated lifetime milestones; subsequent cloud-recovery and progress-enrichment sections below record their implementation. A more unified recovery journey remains a separate design follow-up.


## Progress protection status — 2026-10-05

Optional private iCloud backup and explicit empty-install recovery implemented.
Health-related tracking and private notes are deliberately excluded. Native
CloudKit provisioning, production schema and signed-device recovery remain release
gates. This does not claim shipping readiness or enable cross-device live sync.

Unconfigured Release builds hide the Progress Protection entry. Debug builds
show its unavailable state for development; no CloudKit calls are made.

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

### Recovery presentation slice — 2026-10-06

Implemented typed Today recovery projection and one Build Momentum card, existing support-tool entry points, threshold confirmation and accessible exact-record Undo. No new progress engine, storage, dependency or permission. Verification/screenshots: [recovery-card](verification/recovery-card/README.md). Weekly-review composition and optional companion expansion remain separate later design work.

### Visual Insights slice — 2026-10-06

Completed-week presentation rebuilt around an equal-weight ring, exact per-habit bars and separate manual-attention performance/coverage. Existing metric, tie, historical and trend rules are preserved. Habit detail/History navigation stays functional, and session-only goals no longer show an absent budget card. Native evidence and verification: [visual-insights](verification/visual-insights/README.md).


## Reflection dictation — 2026-10-06

Owner-approved optional dictation is available in each Weekly Reflection editor prompt. Start explicitly requests optional microphone/speech access only where on-device recognition is supported; audio is ephemeral, with no network fallback or saved audio. Review/Edit → Add Text appends to the draft, and Save persists independently of metrics. Seven capture-controller tests cover unsupported/denied access, permission-wait cancellation, late callbacks, errors and append/limit behavior. Eleven existing reflection tests and two targeted UI flows passed (review/cancel/append/explicit save, existing save/cancel/relaunch). UI transcript editing is a review test, not simulated proof of microphone recognition. Hardware speech, locale availability, permissions, interruptions and background capture cleanup remain required device checks.


## Make Room → Do It — 2026-10-06

Habit Detail → Make Room now lets the user create a Focus or Phone-Free goal in place, explicitly start a session and optionally request the mascot/countdown Live Activity. Focus permits phone use; Phone-Free records an intention without blocking or monitoring apps. Existing phone-free history is preserved. Session outcomes and actual habit logging remain independent: Log What I Did opens the existing habit logger without importing elapsed minutes or automatically completing the habit. Active-session review survives relaunch; failed intention-link writes do not replace the newly started session's review destination with an older session.

All 473 unit tests and four affected UI flows pass. Debug and Release build; production binaries contain none of the checked DEBUG store/fixture hooks. This is a full unit run and a targeted UI run, not a full UI-suite or physical-device certification. Native screenshots, exact commands and remaining device checks: [Make Room verification](verification/make-room/README.md).

## Differentiation enrichment — implemented

Optional text reasons and contextual Hide; explainable Momentum; confirmed recovery choices; current-week Make Room connection; four app-facing companion states. Historical schedule/recovery math, pause history and logical-backup exclusions are preserved. Verification is recorded in `verification/differentiation/README.md`. Photos, numeric combined Momentum, automatic dated pause and inferred focus remain outside this implementation.


## Quick Log widget — 2026-10-07

Owner-approved optional small/medium Quick Log widget is implemented alongside existing widgets. One-tap simple check-ins run in the app process without opening UI; quantity/name routes stay explicit. Stale-day Refresh habits rebuilds the projection without writing a completion. Full unit suite (519) and three affected UI tests pass; real SpringBoard background, terminated-app, navigation, quantity and refresh flows were verified on an isolated simulator. Debug and Release build. Screenshots and device gaps: [Quick Log verification](verification/quick-log-widget/README.md).


## Rich Tide widgets — October 7, 2026

The Home Screen gallery now offers **Quick Log** and **Routine**, each in small/medium. Approved Rich Tide uses deep theme gradients and contrasting labelled Log buttons. Remove retired Attention/Progress placements and add the replacement. Routine requires a saved routine selected in Edit Widget. Log saves a simple check-in without opening Avela; names and quantity + open the relevant app screen. Native light/dark/largest-text screenshots, 523 passing unit tests, guide UI regression, background logging checks and Release verification are recorded in [widget verification](verification/two-widgets/README.md).
