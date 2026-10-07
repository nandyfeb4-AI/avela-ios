# Avela

A native, local-first iOS habit and attention-management app built around flexible
commitments, supportive recovery, weekly insights, and a calm animal companion.
Core tracking works offline without an account, backend, or third-party runtime
packages.

The current repository contains the implemented MVP and simulator verification
material. Signed-device validation, production configuration, and distribution
review remain required before TestFlight or App Store release.

## What is built

- **Habit ideas:** eight optional, editable starting points for movement,
  learning and attention. Browse from New Habit; nothing is added until Save.
- **Habits:** create, edit, archive, and reactivate positive or avoidance habits;
  daily, selected-weekday, and flexible weekly schedules; one-tap completion,
  skip and undo; current/best streaks, consistency, and recovery progress.
- **Calendar history:** per-habit month views with connected daily successes,
  excused skips and pauses; separate weekly-target outcomes and large-text date
  lists. Open from habit detail. Browsing never changes a completion.
- **App themes:** nine free, persistent light/dark themes with page gradients and custom card surfaces from Settings
  → App Theme. Warning colours retain their meaning. See the
  [calendar previews](docs/verification/calendar-themes/README.md) and
  [expanded themes/recovery previews](docs/verification/recovery-themes/README.md).
- **Manual attention tracking:** daily duration budgets with quick logging and
  today-only entry corrections; protected and phone-free windows with manual
  check-ins; persistent phone-free sessions. Missing reports remain unknown,
  and elapsed time never certifies success. Detailed check-in timing rules are
  documented as awaiting product confirmation in the data-model notes.
- **Today:** Vivid Tidewater Balance styling, habit/attention summaries, recovery
  context, a collapsible Done group, undo feedback, and companion status.
- **History and Insights:** read-only 30-day habit and manual duration history;
  completed-week habit consistency, comparable-cohort trends, tied rankings,
  logged attention-budget success with coverage, and eligible weekday patterns.
- **Onboarding and Settings:** account-free setup with optional steps, archived
  habits, companion and haptic preferences, privacy information, and Premium.
- **Siri and Shortcuts:** log a habit idempotently or add self-reported attention
  minutes; Settings includes setup guidance. Native actions open the app and
  require local authentication. In-app voice remains deferred.
- **Apple Health:** opt-in steps/exercise-minute targets for Build Up habits,
  checked on foreground refresh. Existing completions/skips are preserved;
  missing access/data never becomes a failure. No Health writes or uploads.
- **Reminders:** optional per-habit local notifications; permission is requested
  on explicit enablement, and denial preserves tracking without repeated prompts.
- **Companions:** original owl, fox, and otter artwork with six deterministic
  states, saved selection/visibility, and transitions respecting Reduce Motion.
- **Subscriptions:** StoreKit 2 monthly/annual purchase, restore, and verified
  entitlement handling. Free supports three active habits and one attention goal;
  Premium removes creation limits. Existing tracking and history remain available
  after expiry.
- **Widgets:** small, medium, and Lock Screen habit/attention summaries using
  read-only App Group snapshots; Home Screen companion artwork. Medium habit
  completion links open the app for a validated, idempotent write.
- **Live Activities:** explicit Show/Hide controls for real phone-free sessions,
  with companion and countdown on supported Dynamic Island and Lock Screen
  surfaces. Hiding presentation leaves the local session active. Activities
  support sessions up to eight hours; longer sessions remain usable in-app.

Automatic Screen Time metering, app blocking, cloud sync, accounts, and AI coaching
are not part of the current implementation. See [MVP scope](docs/MVP.md).

## Getting started

1. Open `Avela.xcodeproj` in Xcode and select the shared **Avela** scheme.
2. Choose an available iOS simulator and run the app.
3. For a device build, configure your developer team and matching app/widget
   signing and App Group entitlements; enable HealthKit for the app target.

The project targets **iOS 17.0+** and uses **Swift 5 language mode**. Recorded
validation used Xcode 27.0 and an iPhone 18 Pro / iOS 27.0 simulator. No package
installation or runtime secrets are required.

See [development setup](docs/SETUP.md) for exact build/test commands, isolated
DEBUG UI-test stores, StoreKit test configuration, and development-store notes.
StoreKit simulator integration tests use ad-hoc signing; unsigned compilation
alone does not establish purchase behavior. Local `.storekit` prices are test
values and are not shipped as production pricing.

The native logging enrichment passed 285 unit tests and targeted simulator UI
flows; both setup screens were visually reviewed. Spoken Siri and real Apple
Health authorization/data still require a signed-device check. Full details and
remaining release gates are in [the checklist](docs/TESTFLIGHT_CHECKLIST.md).

## Architecture and repository layout

```text
Avela/
  App/          App startup, composition, tab navigation, DEBUG fixtures
  Core/         Persistence, calendar utilities, shared UI, widget snapshots,
                and shared Live Activity attributes
  Features/     Habit, Attention, History, Insights, Companion, Onboarding,
                Notifications, Subscription, LiveActivity, Shortcuts, Health, and Settings
  Resources/    Color/art catalogs, app icon, Info plist, privacy manifest
AvelaWidget/    WidgetKit extension and session Live Activity presentation
AvelaTests/     Domain, repository, feature-state, and platform-service tests
AvelaUITests/   Native navigation, tracking, onboarding, and integration flows
docs/          Product contracts, architecture, verification, release checklist
design/        Artwork provenance, design exploration, prototypes, and captures
```

Views consume feature state; view models compose pure Foundation domain logic
with repository protocols. `AppShellView` resolves SwiftData repositories and
shares platform services. Notifications, StoreKit, WidgetKit, and ActivityKit
remain behind focused service/adapter boundaries.

SwiftData stores habits, historical configurations, completions, skips, archive
periods, attention goals/usage/check-ins/sessions, reminders, and companion
preferences. Schedule and target edits append configuration snapshots; archived
periods remain available for accurate progress calculations. Civil-day keys are
persisted in the recording time zone, and week calculations use explicit calendar
rules. SwiftData cloud sync is disabled; optional private CloudKit recovery
requires real signing/container setup. Widgets read exported JSON and never open SwiftData.

See [architecture](docs/ARCHITECTURE.md) and [data-model semantics](docs/DATA_MODEL.md).

## Recorded verification

The following results are documented for **2026-10-04**; they are separate runs,
not a claim that the full UI suite was repeated after every subsequent change.

| Validation | Recorded result |
| --- | --- |
| Full MVP baseline | 243 unit tests + 49 UI tests, zero failures |
| Illustrated companion integration | 247 unit tests + 10 focused UI tests, zero failures |
| Latest session Live Activity integration | 264 unit tests + 1 native ActivityKit UI test, zero failures |
| Final Release compilation | Simulator and unsigned iPhone SDK builds succeeded |

Coverage includes persistence/relaunch, local day/week boundaries, DST/time-zone
behavior, historical edits, progress/recovery, attention thresholds/windows/sessions,
subscription purchase/expiry/refund, widget validation, and Live Activity lifecycle
and rapid Hide/Show regression.

Exact commands and result provenance are in [setup and verification](docs/SETUP.md).
Native captures include [Today](docs/mvp-validation/today-light.png),
[companion dark mode](docs/mvp-validation/companion-dark.png),
[large text](docs/mvp-validation/companion-accessibility-xxxl.png), and
[compact](docs/mvp-validation/dynamic-island-compact.png) /
[expanded](docs/mvp-validation/dynamic-island-expanded.png) Dynamic Island.

## Release gates

Before distribution, complete the [TestFlight checklist](docs/TESTFLIGHT_CHECKLIST.md):

- Replace development bundle identifiers and `group.com.example.Avela` consistently,
  then verify signed app/widget provisioning and shared-container access.
- Configure matching monthly/annual products in App Store Connect and verify
  sandbox purchases, restore, and expiry on a signed device.
- Publish approved privacy/support information and configure the in-app public
  privacy-policy URL; review the archive privacy report and disclosures.
- Approve bundled companion/app-icon artwork and verify real-device appearance,
  VoiceOver, Dynamic Type, Reduce Motion, widgets, reminders, and Live Activities.
- Run the complete release-candidate regression suite, create and validate a signed
  archive, and complete the distribution workflow. No upload is recorded yet.

## Working in this repository

Read [AGENTS.md](AGENTS.md), [docs/AGENTS.md](docs/AGENTS.md), and every Markdown
file under `docs/` before implementation changes. [MVP.md](docs/MVP.md) defines
V1 scope, [ARCHITECTURE.md](docs/ARCHITECTURE.md) defines code boundaries, and
[APPLE_COMPLIANCE.md](docs/APPLE_COMPLIANCE.md) defines platform constraints.
Older milestone notes in the docs preserve implementation history; use their
latest integration/verification sections for current status.

Artwork provenance is in [PRODUCTION_ART.md](design/companion-concepts/PRODUCTION_ART.md).
The [privacy policy](docs/PRIVACY_POLICY_DRAFT.md) remains an owner-review draft.

Native habit reminders now offer **Review & log**: unlock/open Avela, confirm
the named habit, and save success. Opening a notification alone never logs;
old or duplicate reminder actions do not change history.

Personal habit ordering: Today → Order or Settings → Habit Order. Drag or use
Move Up/Down, then Save; Cancel leaves the original order untouched. The order
survives relaunch, while due-day filtering and Done grouping remain in place.

[Native habit-order previews](docs/verification/habit-order/README.md).

Additional enrichment: Settings now offers nine free app accent themes. Habit
detail optionally offers Make It Easier for eligible Build Up habits: review an
adjustable lighter weekly frequency and explicitly confirm, with prior facts
retained. No automatic changes or new permissions. See docs/DATA_MODEL.md for
eligibility, date and history semantics, and docs/SETUP.md for native verification.

Native full-theme and streak previews: [light, dark and large-text gallery](docs/verification/full-themes/README.md).

Design quality: [research and acceptance gates](docs/DESIGN_QUALITY_PLAN.md), [implementation and pending evidence](docs/QUALITY_EXECUTION.md).


### Progress, routines and private reflections

Habit detail now offers **Progress, Timer & History Corrections**: optional count/pages/glasses/minutes targets, quick additive logging, explicit timers, separate smaller actions and confirmed dated corrections. Today offers **Routines & Restart Plans**, including user-selected 3/7-day focus groups. **Weekly Reflection** is available from Insights and Settings. Siri adds **Log Habit Progress**. Settings optionally connects the new Apple Watch companion for current-day snapshots and check-in logging.

The Watch target builds with the app, but paired-device behavior needs verification. Restart groups do not automatically pause/reschedule habits; no microphone, external service or backend is added. See SETUP.md for final native build/test evidence and release checks.


The latest expansion adds optional quantity targets and elapsed-minute timers, smaller-action check-ins, reviewed past-day corrections, ordered routines and 3/7-day restart groups, private weekly reflection, and an opt-in Apple Watch companion. Today → Routines also offers Make This Week Manageable; Habit Detail → Make Room connects a phone-free session to an intention without auto-completing the habit. Siri/Shortcuts includes additive Log Habit Progress. Native preview screenshots and verification are in [enrichment verification](docs/verification/enrichment/README.md).


### Optional progress protection

Settings includes opt-in private iCloud recovery for eligible tracking. It preserves
historical identities on restore and refuses to overwrite existing tracking.
Health/fitness and Health-connected habits, Health-imported history and private
notes are excluded. Current placeholder signing leaves cloud backup unavailable;
see docs/SETUP.md for container setup and signed-device release checks. Local
tracking remains available offline. This is dated backup, not live cloud sync.

Unconfigured Release builds hide the Progress Protection entry. Debug builds
show its unavailable state for development; no CloudKit calls are made.

Recovery verification: **423 unit tests + 4 targeted UI tests, zero failures**.
Details and native screenshot: [private recovery verification](docs/verification/cloud-recovery/README.md).

### Progress enrichment

- Habit Detail → **Lifetime Progress**: accumulated successful check-in days, milestones and quantity totals separated by unit.
- Habit Detail → **Progress, Timer & History Corrections** → **Edit Quick Amounts**: personal today-only quantity buttons with exact-entry Undo.
- Insights → **What I Made Room For**: selected-week linked session reports, elapsed timer minutes and independent habit check-ins.

These features add no schema, dependency or permission. Presets are local preferences, not part of logical cloud recovery. A cohesive native UI polish pass is now implemented.

### Native UI polish

Today recovery rows, habit tools, logging, Insights, History, Settings and supporting iPhone screens now share clearer hierarchy, consistent icons and restrained theme surfaces. [Review native light/dark screenshots and verification](docs/verification/ui-polish/README.md). Full units (454) and 14 affected UI flows pass; physical accessibility checks remain pending.

### Atmospheric themes

Nine existing themes now coordinate neutral cards, sky atmosphere, colorful controls and original illustrated calendar/theme headers. Today leads with habit actions and uses consistent habit icon colors. [Native light/dark gallery and verification](docs/verification/atmospheric-themes/README.md). 455 units and seven affected UI flows pass; physical accessibility/usability checks remain pending.

Latest recovery UI evidence: [Build Momentum card and accessible Undo](docs/verification/recovery-card/README.md).

Visual weekly review evidence: [Insights rings, habit bars and manual coverage](docs/verification/visual-insights/README.md).
