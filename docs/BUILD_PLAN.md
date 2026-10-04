# Build Plan

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
