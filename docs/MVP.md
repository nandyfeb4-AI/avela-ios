# V1 / MVP Product Contract

This file defines the V1 release boundary.

Every feature must be classified as:
- MUST SHIP
- POST-MVP
- EXPLICITLY OUT OF V1

No new feature may delay V1 unless this file is intentionally updated.

---

# MUST SHIP

## 1. Habit creation and lifecycle

Users can:
- create a habit
- edit a habit
- archive a habit
- reactivate an archived habit
- choose a name
- choose an icon
- choose a category
- choose habit polarity:
  - positive habit
  - avoidance habit

### Acceptance criteria
- New habit appears immediately in Today view when applicable.
- Editing a habit does not corrupt historical completion records.
- Archived habits disappear from active views but retain history.
- Historical records retain the habit configuration that applied at the time where necessary for accurate interpretation.

---

## 2. Scheduling

Supported schedule types:

### Daily
Example:
- Read every day

### Specific weekdays
Example:
- Exercise Monday, Wednesday, Friday

### Flexible weekly frequency
Example:
- Read 3 times per week

### Acceptance criteria
- Flexible weekly habits do not require weekday selection.
- Dashboard can show `2 / 3 this week`.
- Third valid completion satisfies the weekly target.
- Additional completions remain visible.
- Missing an individual day does not break a weekly-frequency commitment.
- Week boundaries use the user's local calendar/time zone.

---

## 3. Completion and history

Users can:
- complete a habit
- undo a completion
- skip when allowed
- view completion history

### Acceptance criteria
- Logging is one tap from Today view.
- Undo is available immediately after accidental logging.
- Completion timestamps are stored.
- History remains available after habit edits.
- Skip is distinct from failure.

---

## 4. Streaks and recovery

Track:
- current streak
- best streak
- consistency percentage
- recovery streak or recovery state

Recovery is a first-class concept.

Example:
- 11 of last 14 successful days
- 79% consistency
- 3-day recovery run

### Product rule
One miss should not make the product feel like all progress is lost.

### Acceptance criteria
- Daily habits calculate streaks correctly across local date boundaries.
- Flexible weekly habits use weekly success rather than arbitrary daily streak logic.
- Recovery messaging is neutral and encouraging.
- No shaming language.

---

## 5. Reminders

Users can:
- enable reminders per habit
- select reminder time
- disable reminders

### Acceptance criteria
- App requests notification permission only when user enables a reminder or from a clear onboarding step.
- App remains usable if permission is denied.
- Denial does not trigger repeated nagging.

---

## 6. Attention habits

V1 supports manually tracked attention goals.

Supported examples:
- Instagram <= 30 minutes/day
- YouTube <= 45 minutes/day
- News only after 6 PM
- No social media before 9 AM
- Phone-free first 30 minutes after waking

Supported goal families:

### Maximum duration
Example:
- Social media <= 30 minutes/day

### Protected time window
Example:
- No news before 9 AM

### Phone-free session / window
Example:
- Stay phone-free until 9 AM

### Data source
V1 must support:
- `manual`

Architecture must support future:
- `screenTime`

### Acceptance criteria
- User can enter usage manually.
- Daily attention goal state updates immediately.
- Historical entries retain actual usage.
- Changing today's goal does not rewrite previous historical goals.
- UI can represent healthy / near-limit / exceeded.

---

## 7. Weekly review

V1 weekly review includes:
- consistency percentage
- strongest habit
- weakest habit or habit needing recovery
- attention-budget success rate
- basic trend versus prior week
- most consistent day / weakest day where enough data exists

### Acceptance criteria
- Insights are derived from real local data.
- Do not fabricate correlations from insufficient data.
- Use plain language.
- Do not present causal claims.

---

## 8. Spirit-animal companion

V1 supports a limited companion system.

States:
- calm
- focused
- nearLimit
- overloaded
- recovering
- celebrating

Surfaces:
- Today dashboard
- Home Screen widget
- Lock Screen widget where practical

### Behavior
The companion reflects app state. It is not purely decorative.

Examples:
- calm when habits and attention are on track
- nearLimit when attention budget is approaching threshold
- overloaded when budget is exceeded
- recovering after a recent miss followed by renewed progress
- celebrating for meaningful completion events

### Acceptance criteria
- Companion state derives deterministically from user data.
- Companion never uses manipulative guilt.
- Animations respect Reduce Motion.

---

## 9. Widgets

V1 includes at least:
- compact habit progress widget
- attention-budget status widget

Target interactions:
- glanceable progress
- one-tap habit completion where supported by platform APIs

### Acceptance criteria
- Widget state is consistent with app state.
- Widget does not expose sensitive details unnecessarily.
- Empty states are intentional.

---

## 10. Live Activity

V1 may include Live Activity only for a real active session:
- phone-free until a specified time
- focus / protected-attention session

### Current V1 implementation
The optional Live Activity is included for explicitly started phone-free sessions.
A second, explicit "Show Session Activity" action opts into system presentation.
It displays the selected companion and timer on supported Dynamic Island and
Lock Screen surfaces. It never monitors phone use or records a result from time
elapsed. Protected recurring windows do not automatically create activities.

### Acceptance criteria
- Live Activity is time-bound.
- It is not used as a permanent virtual-pet surface.
- Ending the session updates the main app.

---

## 11. Onboarding

Required sequence:
1. Explain core value
2. Create first habit
3. Create first attention goal
4. Select companion
5. Offer reminder setup
6. Enter main dashboard

### Acceptance criteria
- User can complete onboarding without creating an account.
- User can skip nonessential steps.
- App becomes useful within a few minutes.

---

## 12. Monetization

V1 includes:
- free tier
- monthly subscription
- annual subscription
- StoreKit 2
- restore purchases
- premium entitlement checks

### Premium value candidates
Premium may unlock:
- unlimited habits
- advanced weekly insights
- expanded companion themes / states
- multiple attention budgets
- advanced widgets

Exact paywall packaging may evolve, but V1 must clearly explain what is free and what is paid.

### Acceptance criteria
- Purchase state is correctly restored.
- Core app does not become unusable if StoreKit is temporarily unavailable.
- No dark patterns.

---

## 13. Local-first persistence

Core functionality must work without network connectivity.

Persist:
- habits
- schedules
- completions
- skips
- attention budgets
- manual usage entries
- companion selection
- local preferences
- weekly derived metrics or data needed to recompute them

---

## Owner-approved enrichment — 2026-10-04

The owner requests useful competitor parity and native integrations that reduce
manual logging. Siri and Apple Shortcuts are approved for the current candidate;
in-app microphone/voice recognition remains later work. App-target actions log a
selected habit for today or add explicit self-reported minutes to a daily budget.
They open Avela, respect device authentication, preserve existing tracking rules,
and never infer successful phone-free behavior. No paid entitlement is required
for logging existing records. Settings explains setup and additive usage semantics.

Apple Health is approved for this enrichment: opt-in steps and exercise-minute
targets for active Build Up habits, with contextual read permission and foreground
refresh. No sleep/mindfulness interpretation or background-delivery guarantee.
HealthKit's earlier POST-MVP classification is superseded by this authorization; automatic Screen Time,
cloud sync and external services remain deferred. Missing or inaccessible Health
data must never be called measured zero, failure, or a verified success.

This authorization does not make every competitor feature a release requirement.

## Setup enrichment — 2026-10-05

The owner's ongoing enrichment request includes faster, approachable setup.
New-habit creation offers an optional local starter library with editable names,
icons, categories, polarity and schedules. Choosing an idea fills the existing
form; it neither saves a habit nor connects Health/enables reminders. Saving
uses the normal creation path and free-tier limits. Custom creation remains
available immediately. Existing-habit editing offers no template replacement.
Examples are lifestyle suggestions, not prescribed targets or medical advice.

## Reminder-action enrichment — 2026-10-05

Owner-approved ongoing enrichment includes a native **Review & log** habit
notification action. It requires device unlock and opens Avela to identify the
habit before explicit success confirmation. Notification previews remain
generic; ordinary opening, dismissal, review, or cancellation never logs.
Only an active habit due on the current local day can be logged. Yesterday's
reminders and repeated actions cannot manufacture or toggle check-ins. No
Snooze, inferred completion, new permission, or remote notification service.

## Owner-approved calendar and themes enrichment — 2026-10-05

- Read-only per-habit month calendar showing recorded successes, excused skips,
  pending/finished daily commitments and pauses. Flexible weekly targets appear
  as weekly outcomes, never fabricated daily misses. Numeric streaks share the
  same engine; historical dates and schedules remain intact.
- Nine free app accent themes in Settings: Tidewater, Sapphire, Plum, Ember and
  Rose, Indigo, Forest, Coral and Gold. Preferences persist locally and follow system light/dark appearance;
  attention/recovery colours retain their meaning. Widgets and Live Activities
  keep Tidewater in this slice.
- No arbitrary palette editor or per-screen themes. Dated correction is authorized in the later progress/recovery expansion.

## Personal habit order enrichment — 2026-10-05

Ongoing owner-approved enrichment includes a free, locally persisted order for
active habits. Today → Order and Settings → Habit Order open a cancellable draft
with native drag handles and Move Up/Down controls. Explicit Save is required.
All active habits are included, even when not due today. Today still filters due
habits and groups completed ones under Done, retaining the chosen relative order
within each group. New habits append; archived habits retain their saved slot and
return there when reactivated. Ordering changes no check-in, schedule or metric.
No automatic priority recommendation, routine engine or new permission is added.

---

## Optional lighter-schedule enrichment — 2026-10-05

Owner-approved enrichment includes four more free themes (Indigo, Forest, Coral,
Gold) and a deterministic **Make It Easier** option in habit detail. Active Build
Up habits with repeated recent resolved misses and ongoing recovery can review
an adjustable lower flexible-weekly frequency. Opening, cancelling or dismissing
never edits. Explicit confirmation changes the schedule effective today through
the existing append-only configuration history. Check-ins and earlier finished
periods remain intact; this week's progress may change. Apple Health targets,
Cut Down habits and attention budgets are not adjusted. No AI coaching, automatic
changes, diagnosis, new permission or claim of improved adherence.

# POST-MVP

- automatic Screen Time metering
- iCloud / CloudKit sync
- Supabase backend
- cross-platform sync
- richer behavioral correlations
- optional AI-generated coaching
- social / community features
- shared habits
- Android
- web app
- large companion environments
- advanced gamification
- remote feature flags if truly needed

---

# EXPLICITLY OUT OF V1

- medical advice
- mental-health diagnosis
- therapy claims
- parental surveillance
- hidden app blocking
- background data collection unrelated to product function
- ad network integration
- mandatory user accounts

## Full theme and streak styling refinement — 2026-10-05

The owner requested themes beyond accent colours and more prominent calendar
streaks. Nine existing choices now style page gradients, custom card surfaces,
Today's Habits summary and calendar hero/ribbons. Scalable current/best totals,
read-only date history, weekly commitment distinctions and excused pauses/skips
retain their existing meaning. Static gradients simplify under Increase Contrast.
No new tracking, permission, schema, dependencies or animations.


## Design quality implementation

The owner requested applying the design quality plan to existing V1 journeys. Adaptive controls, readable accessibility context, stable assistive-navigation feedback and exact current-day Undo validation refine existing behavior; no new goal type, automatic logging, schema or dependency is introduced. Physical/user validation remains a release gate.


## Owner approved progress and recovery expansion — 2026-10-05

The owner requests the proposed feature set now, superseding the earlier no-backdated-logging boundary. Manual quantity targets (count/pages/glasses/minutes) apply per scheduled day; flexible weekly frequency counts days reaching the target. Targets are optional for Build Up habits without a connected Health target. Their configuration history is append-only. Timers measure elapsed time, survive relaunch, and require explicit logging of whole minutes. Generic success actions cannot bypass an unmet quantity target.

Users may define an optional smaller action, recorded separately without completing the full target or extending its streak. Ordered routine groups and explicit 3/7-day restart plans reference existing habits; they do not bulk complete, pause other habits or change schedules. A restart's review date is informational. Existing Make It Easier remains the explicit schedule-change tool.

Progress & History in habit detail supports explicit, confirmed dated success/skip/clear corrections. Future, pre-creation, unscheduled and paused days are rejected. Quantity success requires recorded progress; corrections can alter historical metrics. Optional private weekly reflection notes are separate from calculated Insights. All these additions are free and local-first.

An opt-in Apple Watch companion provides Today snapshots, explicit quick logging for check-in habits and a local elapsed timer. Writes require a reachable paired iPhone with protected data available. No offline logging queue, automatic success, Watch quantity logger, microphone or external service is added. Paired-device verification remains a release gate. Siri/Shortcuts adds an amount in the configured unit through Log Habit Progress; each invocation is additive. Existing Health steps/exercise integration remains available and separate.

In-app speech recognition, automatic Screen Time, third-party fitness/cloud integrations and automatic multi-habit rescheduling remain deferred. A Manageable Week review supports confirmed, individual pauses and selected restart groups; it never silently changes other habits. Make Room explicitly links a started phone-free session to a chosen habit intention; session results never complete the habit.

## Factual reflection enrichment — 2026-10-05

Owner-approved deepening keeps all guidance deterministic and based on recorded facts. Weekly Reflection now displays each eligible habit's successful/resolved commitments for the selected civil week, including archived habits. Current-week pending commitments, excused skips and dormant time remain excluded by the existing calculator. Daily commitments and flexible weekly commitments are disclosed as different units; no pooled percentage is introduced. Opening Reflection from Insights selects the reviewed week, while Settings defaults to the current week. Notes are not analyzed and cannot establish causes or change metrics. No AI model, remote inference, new permission, schema or dependency is added. The later owner-approved cloud-recovery and progress-enrichment sections supersede the earlier deferral of backup/restore and dedicated lifetime milestones.


## Owner-approved progress protection — 2026-10-05

Optional private iCloud recovery copies are approved for this release, overriding
the earlier deferral of cloud backup only. Live cross-device sync remains deferred.
No Avela account, paid tier or third-party service is required. Health-linked and
health/fitness habits and private notes are excluded for privacy/compliance. Local
tracking remains the default. Restore never replaces an installation's existing
tracking. Signed CloudKit setup and recovery verification are release gates.

## Owner-approved progress enrichment — 2026-10-06

Lifetime Progress, personal quick amounts, and the selected-week “What I Made Room For” review are now in scope. Lifetime totals and milestones are derived from surviving records, separate from streaks; a miss or pause never resets them. Undo/corrections may reduce totals. Quantities remain grouped by captured unit and smaller actions remain distinct from full successes. Quick amounts are optional, today-only local convenience preferences, with exact-entry Undo. The weekly review shows linked, self-reported session outcomes and elapsed timer minutes, alongside independent habit check-ins; it does not claim saved time or causation. UI polish remains a separate follow-up.

## Cohesive native UI polish — 2026-10-06

Owner-requested visual refinement keeps all recorded-progress rules, permissions and actions intact. Today now uses softly tinted icon tiles, more readable row metadata and a quiet recovery count (for example, “1 of 3 good days”) instead of the repeated “Rebuilding” prefix and warning tint. Recovery still appears only until the existing three-success threshold; quantity progress stays visible and VoiceOver retains factual context.

Habit Detail leads with identity and recorded progress, then groups related tools under Explore Progress and Support Your Habit. Visual action names are shortened to Log Progress and Make Room, with concise supporting text; stable accessibility IDs and the original spoken action descriptions are retained. Activity and lifetime screens have clearer typography and less repeated explanation. Insights, History, Settings and intention review use consistent section/icon/card hierarchy. Attention goals/session headers, calendar month navigation, reflection and onboarding also receive restrained native refinements.

Shared theme canvases use a lighter accent wash (see THEMES.md), 52-point minimum native list rows and consistent section spacing. Text scales with Dynamic Type; decorative icon tiles cap symbol size while labels retain scaling. System typography/SF Symbols remain the foundation. No dependency, domain calculation, storage schema, permission, purchase rule or new animation is introduced.

This is implementation and simulator evidence, not user-validated premium quality or award readiness. Physical VoiceOver/device checks and private usability observation remain pending. Existing signed CloudKit/platform release prerequisites remain unchanged.

## Owner-approved atmospheric UI refinement — 2026-10-06

This presentation pass changes neither MVP feature scope nor recorded metrics. Existing themes receive static original scenery and neutral reading cards; Today prioritizes logging, and the calendar retains factual read-only daily/weekly distinctions. Recovery/feedback/review/companion capabilities already implemented remain intact; no new recommendation engine or mascot-care mechanic is introduced. See DESIGN_SYSTEM.md and THEMES.md.

## Owner-approved recovery card — 2026-10-06

Today consolidates recovery for active habits scheduled today into a single Build Momentum card after the habit actions. Typed progress uses the existing three-success threshold; daily and flexible weekly recovery retain their units, while a run containing both is described as commitments. Excused skips and recorded archive periods remain neutral. Row captions return to schedule/quantity context, with recovery retained in spoken context.

The card opens existing progress, smaller-action and lighter-schedule tools. Smaller actions appear only for positive habits with a configured action and remain separate effort records. Make It Easier uses existing proposal eligibility and revalidates before saving; cancelling never edits a schedule. Completing the third commitment from Today gives a calm confirmation with exact-record Undo. Accessibility text sizes, VoiceOver and Switch Control keep Undo available until dismissal/navigation or a subsequent action. No domain rule, data schema, permission, dependency or purchase gate changes.

## Owner-approved visual weekly analytics — 2026-10-06

Insights now visualizes its existing completed-week results with an equal-weight consistency ring, exact per-habit success/resolved commitment bars, neutral highlights and a comparable-cohort trend explanation. Per-habit links open existing detail/support tools and retain View History navigation. Archived habits remain included when eligible, with current identity and an explicit archive label. Daily and flexible weekly commitment units are disclosed rather than pooled into a misleading total.

Manual attention remains separate: reported below-budget results and logging coverage use different bars. Missing reports remain unknown; reaching the budget is excluded from the below-budget count under the existing threshold rule. Session-only goals do not generate a phantom budget card. No AI, causal claim, invented trend series, new metric definition, permission, schema or dependency. Charts are read-only; full-success logging still uses existing explicit actions.
