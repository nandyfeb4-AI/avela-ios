# UX Specification

## Navigation

Recommended primary structure:

- Today
- Insights
- History
- Settings

Habit creation can be presented modally.

## Habit setup

New Habit offers Browse Habit Ideas alongside immediate custom entry. The local
catalog groups eight starting points into Move, Learn and Make Space, with
native search. Selecting an idea fills the editable form and returns to it;
explicit Save is required. Browsing/back navigation does not change the draft,
and Cancel adds nothing. Existing habits use the normal edit form without an
idea-replacement control. Health/reminder setup remains separate and optional.

Rows scale and wrap at accessibility text sizes. Introductory copy stays short
and disappears during filtering so results take priority over the keyboard.

## Today screen

Must show:
- companion
- today's habit list
- flexible weekly progress
- attention goal status
- fast logging actions

Priority order:
1. What should I do now?
2. How am I doing today?
3. What needs recovery?
4. What is my attention state?

## Information hierarchy

Avoid dashboards that look like analytics software.

Prefer:
- one primary state
- one next action
- one or two supporting metrics

## Habit card behavior

Each card should support:
- name
- icon
- current progress
- completion affordance
- schedule context where useful

Examples:
- `Read — 2/3 this week`
- `Walk — 4-day streak`
- `Instagram — 18/30 min`

## Attention states

Suggested thresholds for maximum-duration goals:
- healthy: < 70%
- near limit: 70% to < 100%
- exceeded: >= 100%

Thresholds should be centralized and configurable.

## Recovery UX

Do not show:
- "You failed"
- "Streak ruined"
- "Back to zero"

Prefer:
- "You’re rebuilding momentum"
- "3 good days since your miss"
- "11 of the last 14 days"

## Weekly review

Should read like a useful summary, not a spreadsheet.

Structure:
1. overall week
2. what went well
3. what needs recovery
4. attention-budget result
5. one practical observation

## Companion UX

Tone:
- calm
- warm
- intelligent
- never childish by default
- never sarcastic
- never guilt-based

Companion may offer brief prompts such as:
- "You’re close to today’s limit."
- "Three of four habits are done."
- "Sunday has been your hardest day lately."

Avoid fake human dependency cues.

## Accessibility

Must support:
- Dynamic Type
- VoiceOver labels
- sufficient touch targets
- Reduce Motion
- high contrast compatibility
- dark mode

## Empty states

Every empty state should explain:
- what this section is
- why it helps
- one clear next action

## Error states

Do not expose raw technical errors.

Store internal diagnostics separately from user-facing messaging.

### Reminder actions

Long-press a reminder → Review & log → identify the named habit in Avela →
Log success or Cancel. Keep lock-screen notification text generic. This extra
confirmation prevents logging an unidentified habit from a private preview.
Opening/dismissing the reminder or cancelling review leaves data unchanged.
Old/unavailable/already-logged reminders explain why nothing was changed.
Successful confirmation returns to Today, where normal undo remains available.

## Calendar history and colour preference — 2026-10-05

Habit Detail → Calendar History is read-only. Navigate recorded months without
logging or undoing anything. Current/best totals remain through today, explicitly
independent of the displayed month. Skips, pauses and unscheduled dates are neutral;
weekly targets are reviewed as weekly commitments rather than daily misses.
Stored civil-date facts remain visible after travel. Accessibility text sizes use
a dated list with full date/outcome labels.

Settings → App Theme changes the app accent immediately after a successful save.
Five curated options are free and persist locally; system light/dark mode,
companion/haptics preferences and semantic warning colours are preserved.

Accessibility month lists show tracked/recorded dates, omit unrecorded upcoming
and pre-creation dates with an explicit explanation, and place weekly commitments
before the date list so large-text users need not scroll through a whole month
to find the target outcome. The regular grid still shows every civil date.

## Personal habit order

Today → Order, or Settings → Habit Order, lets users arrange every active habit.
Drag native handles or use Move Up/Down; Save applies the draft, Cancel discards
it. The sheet shows names, schedule context and positions, including habits due
on other days. Completed habits still collapse into Done in the chosen relative
order. Archived habits keep their position for reactivation; new habits append.
This is a personal preference, not an inferred recommendation about importance.

## Optional lighter-schedule review

Habit detail may show Make It Easier during repeated recent misses and ongoing
recovery for Build Up habits. It offers space to choose a lighter frequency,
never an automatic prompt or a judgment about effort. Show current and proposed
schedules, editable frequency, an explanation that the change starts today and
can change this week's progress, and both cancellation and explicit confirmation.
Keep Current Schedule and dismissal do nothing. A stale review must reload before
confirmation. Apple Health quantity targets stay unchanged.

### Visually prominent streaks and full themes

Use a large current-streak total and personal best on a deep theme panel; label
totals through today even when browsing an older month. Daily success ribbons
reflect existing facts only. Weekly check-ins remain separate from weekly target
outcomes. A themed page gradient/custom cards establish identity without altering
warning semantics, adding punitive red gaps or animations. Large text continues
to expose dated list rows and labelled outcomes; colour is supplementary.


## Design quality implementation

Logging confirmation has an explicit Dismiss action. With VoiceOver or Switch Control, confirmation and a newly completed row stay in place until an explicit action/navigation instead of expiring or moving automatically. Undo targets its captured completion and verifies current-day eligibility. Habit setup adapts weekday controls and picker layout at large text; icon accessibility labels use readable names.


## Progress and restart journeys

Habit Detail → Progress, Timer & History Corrections configures optional quantities and smaller actions. Today shows a plus affordance for incomplete quantity habits, with Log progress spoken wording; this opens the quantity logger instead of implying a binary tick. Quick increments are additive and have explicit units. Partial amounts and smaller actions remain separate from full success. Timers require Pause then Log whole minutes; leaving the app does not complete a habit.

Today → Routines & Restart Plans groups existing habits in user-selected order. A 3/7-day restart is a focus group with a review date, not an automatic reset or pause. Each row opens the normal logger. Insights/Settings → Weekly Reflection offers two optional prompts and explicit Save/Cancel; text never replaces computed results. History correction names its date, warns metrics may change and rejects stale review state. Native scalable text, theme surfaces and accessible controls remain the UI foundation.


### Manageable Week and Make Room — 2026-10-05

Today → Routines → Make This Week Manageable is a voluntary review: keep a habit by doing nothing, open its configured smaller action, confirm a named pause, or select a short restart group. Never infer a need to pause from a bad week. Start Small changes focus rather than silently lowering everyone’s targets.

Habit Detail → Make Room with a Phone-Free Session links a deliberate intention to a session. Opening is read-only; Start is explicit. Session check-ins and optional Dynamic Island presentation stay in the normal session screen. The habit still requires its own check-in.

## Reflection beside recorded progress

Reflection shows Recorded This Week above the private note, with per-habit successful/resolved commitment counts and an explicit in-progress explanation for the current week. Archived rows are labelled. No eligible facts produces an honest empty state, not a zero percentage. Progress errors clear stale rows and leave note editing available. Opening from Insights preserves its selected week. Reflection text is never interpreted as evidence for automated causal advice.

## Progress enrichment navigation — 2026-10-06

Habit Detail → Lifetime Progress shows accumulated successful days and milestones with clear non-streak copy. Habit Detail → Progress, Timer & History Corrections → Edit Quick Amounts customizes today’s quantity buttons; Undo remains tied to the exact latest quick entry. Insights → What I Made Room For reviews linked intentions in the selected completed week. Today gains no additional dashboard block. Native controls, semantic themes and scalable text are used. A broader premium UI/interaction polish pass remains planned; these additions do not claim user-tested usability.

## Cohesive native UI polish — 2026-10-06

Owner-requested visual refinement keeps all recorded-progress rules, permissions and actions intact. Today now uses softly tinted icon tiles, more readable row metadata and a quiet recovery count (for example, “1 of 3 good days”) instead of the repeated “Rebuilding” prefix and warning tint. Recovery still appears only until the existing three-success threshold; quantity progress stays visible and VoiceOver retains factual context.

Habit Detail leads with identity and recorded progress, then groups related tools under Explore Progress and Support Your Habit. Visual action names are shortened to Log Progress and Make Room, with concise supporting text; stable accessibility IDs and the original spoken action descriptions are retained. Activity and lifetime screens have clearer typography and less repeated explanation. Insights, History, Settings and intention review use consistent section/icon/card hierarchy. Attention goals/session headers, calendar month navigation, reflection and onboarding also receive restrained native refinements.

Shared theme canvases use a lighter accent wash (see THEMES.md), 52-point minimum native list rows and consistent section spacing. Text scales with Dynamic Type; decorative icon tiles cap symbol size while labels retain scaling. System typography/SF Symbols remain the foundation. No dependency, domain calculation, storage schema, permission, purchase rule or new animation is introduced.

This is implementation and simulator evidence, not user-validated premium quality or award readiness. Physical VoiceOver/device checks and private usability observation remain pending. Existing signed CloudKit/platform release prerequisites remain unchanged.

## Atmospheric themes and action-focused Today — 2026-10-06

The owner approved a coordinated visual pass informed by published competitor examples. Avela now separates neutral reading surfaces from colorful actions and habit identity. All nine existing saved themes retain their values and controls, and add a complementary sky wash plus a static landscape preview. Original SwiftUI Canvas scenery uses clouds, a sun/moon and layered coastlines, mountains, hills or forest silhouettes. No competitor art, runtime image generation, external library, network request or idle animation is used.

Calendar History places scenery in a separate 96-point band below the factual streak summary, never behind dates or reading text. It keeps the existing connected daily-success ribbons and separate weekly commitments; browsing remains read-only. Accessibility text sizes omit the scenery to prioritize text and outcomes. Increase Contrast hides decorative scenery and retains solid preview fills/page backgrounds. Decorative content is hidden from accessibility and cannot intercept taps.

Today places compact habit/attention summaries and actionable habits before routines and the smaller companion. Attention retains manual provenance. Habit symbols use stable curated identity colors across Today, detail, History, archived habits and the form; archive labels and muted icons remain explicit. This color is selected from the symbol rather than private names or inferred behavior, and never replaces completion/status labels.

This supersedes the earlier uniformly accent-tinted reading-card guidance. Reading surfaces are white/charcoal; themes vary atmosphere, controls, progress, heroes and scenery together. Existing completion, recovery, Undo, permission, subscription and persistence rules are unchanged. Companion art, widgets, Watch and Dynamic Island retain their existing system-surface treatment.

### Recovery card and accessible feedback

Recovery on Today is grouped after the immediately actionable habit list, before attention. Each due habit has its real count and three quiet segments; the count remains the authoritative accessible description. Daily/weekly schedule transitions use commitment wording rather than calling a prior day a week. Links are at least 44 points tall and stack at accessibility sizes. Optional smaller actions never imply full completion.

The end of a recovery run uses the existing logging confirmation, without confetti or an additional animation. At accessibility sizes its action row keeps Undo and Dismiss together, and the confirmation does not expire automatically. Opening a support tool cancels presentation timers; dismissing it reloads stored facts. Physical VoiceOver focus testing remains pending.

### Visual weekly analytics

The completed-week review moves from one dense textual card to distinct layers: overall consistency, factual highlights, habit-by-habit counts, manually reported attention and private intention review. Strongest/attention rankings keep their existing tie and balanced-week semantics, with neutral “Most consistent”/“Room to grow” headings. Trends explain that their comparable cohort may be smaller than the overall habit group. A bar is never presented without its real count; archived identity is explicit. Missing reports cannot imply verified zero attention usage.

Per-habit rows navigate to existing details/support and History, without recording success on navigation. Large text uses a stacked summary and scrollable rows. Native accessibility labels state exact values and the destination. Charts remain static, with no additional motion or haptic noise.
