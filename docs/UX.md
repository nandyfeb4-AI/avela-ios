# UX Specification

## Guided first use — October 22, 2026

Six stages serve six decisions: welcome, direction, optional obstacle, one habit,
optional companion, and readiness. The artwork and brief entrance responses stay;
the task changes from configuring every feature to finding one useful beginning.
A top-level Explore first action opens Today immediately. Back retains answers
and the explicitly selected idea, including when earlier answers change the
suggestions. A selected idea remains visible. Continue and the secondary Skip
have separate native touch regions; the fixed progress header stays below the
toolbar. Both actions remain reachable with scrolling at
accessibility text sizes. Choice rows announce selection without relying on colour.

Goals are build a routine, start again, or protect focus. Obstacles are forgetting,
limited time, distractions, or a step feeling too big. These optional answers
only rank existing catalog drafts and select relevant explanatory support. They
are held in memory for this setup, with no inferred diagnosis or progress state.
There is no arbitrary time-to-pages/glasses conversion. An idea shows its actual
schedule and tracking unit. Review Habit opens the editable New Habit form,
including amounts/minutes and the smaller action; Cancel writes nothing. Custom
creation and browsing all ideas remain available. Save is the only creation action.

The ready stage identifies the saved habit honestly, including schedules that
are not due today. Forgetting exposes optional reminder setup without requesting
access merely by opening it. Focus/distractions explain Habit → Make Room;
limited-time/large-step answers explain Log Progress and smaller actions. Neither
route starts a timer, logs effort or prompts for permission automatically. A
companion change is accepted with Continue; Keep current preference discards
unaccepted changes. Explore first uses the last accepted profile. Existing completed
onboarding and all recorded facts are preserved.

Research basis: [Apple onboarding guidance](https://developer.apple.com/design/human-interface-guidelines/onboarding)
supports postponing nonessential setup; [HabitKit's first-habit guide](https://habitkit.app/help/getting-started/install-habitkit-and-create-your-first-habit)
shows a direct editable first action; [Finch's documented setup](https://help.finchcare.com/hc/en-us/articles/37779580853005-Creating-Your-Birb)
shows character/personalization choices. These inform Rilova's design rather than
establishing a universal competitor questionnaire or measured retention benefit.

## Expressive Rilova worlds — October 21, 2026

This owner-approved presentation pass supersedes the earlier still-landscape-only
and repeated-banner guidance. The product keeps its existing navigation and
explicit actions while using original bundled environments, stronger display
type, varied compositions and brief responses to real interaction. The intended
quality is expressive and carefully readable. Native screenshot and
accessibility evidence is recorded in the
[Expressive World verification](verification/expressive-world/verification.json);
physical-device accessibility and performance remain separate checks.

Today uses one coast scene with the saved, enabled companion in its actual
deterministic pose. The separate `CompanionView(showsPortrait: false)` supplies
the state and sentence without a second portrait or scenic container. The week
strip and logging controls remain directly below this overview. Decorative art
does not establish a completed habit or a measured attention state.

Onboarding retains six stages, optional skips and its existing creation and
permission boundaries. Coast and sanctuary settings, grounded characters and
native symbolic miniatures give each stage its own composition. Entry movement
is finite and scene-specific; Continue remains pinned while content scrolls,
with a distinct gap before Skip. Make Room uses a sanctuary clock stage and the
saved companion only when enabled. Before Start it labels the suggested/saved
minute target; an active selected linked session can show a countdown from its
captured start and target. That timer never proves concentration, phone-free
behaviour or habit success. Optional protection and activity consent remain
separate from its illustration and explicit Start.

Larger text substitutes compact scenery and readable stacked values for crowded
compositions. Reduce Motion removes entry/scale choreography; Increase Contrast
and Reduce Transparency replace atmospheric layers with opaque surfaces.
Environmental art is hidden from accessibility and cannot intercept input.
Motion has no endless background or companion-care loop, and visual clock
updates pause when the app is inactive. This is presentation over existing
facts: no new runtime AI service, schema, progress write or permission is added.

## Navigation

Recommended primary structure:

- Today
- Insights
- History
- Settings

Habit creation can be presented modally.

## Habit setup

New Habit offers Browse Habit Ideas alongside immediate custom entry. The local
catalog offers 40 editable ideas in eight groups and four collections, with
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


## Today companion placement — 2026-10-06

The owner-requested compact companion status card now sits immediately below the daily summary and before habit actions, rather than after routines at the bottom of Today. This supersedes the earlier bottom-placement guidance. The companion remains optional, reflects real state, and retains its existing Reduce Motion and scalable-text behavior. No progress, persistence, permissions or feature scope changes.


## Dictated reflections — 2026-10-06

Settings → Weekly Reflection (or Insights → reflection) → Write/Edit Reflection exposes a labeled Dictate microphone button for each prompt. The preview explains on-device audio handling before Start. A visible Listening state and Stop Recording control precede editable review and Add Text. Add Text appends to the answer; Save remains separate. Cancel never alters the answer. Record Again explicitly replaces only the current unsaved transcript preview. Unsupported recognition/permission denial keeps typing available. Recording stops automatically at 55 seconds, on background/interruption or dismissal; there is no idle microphone or background recording. Existing length feedback handles long transcripts without silent truncation.


## Make Room → Do It — 2026-10-06

Habit Detail → Make Room now explains Focus (phone permitted) versus Phone-free (intention to step away; no blocking/monitoring). Empty-state creation is in this screen, defaults to a Focus goal named for the habit and remains editable. Existing goals use a compact picker. A labeled optional Dynamic Island/Lock Screen toggle precedes explicit Start. Session outcome reporting and Log What I Did are separate actions, with no inferred completion or imported timer quantity. Existing phone-free wording/history remains specific. The chronological weekly intention review includes both session types without causal claims.

## Differentiation experience

Habit Detail → Momentum brings Recent Rhythm, Coming Back and Lasting Effort together as explainable facts. No single score ranks the user. Optional reasons use their own words and appear during recovery or before Make Room, with a persistent Hide action and Edit Habit restoration. Recovery support is a deliberate “A smaller step” entry in Today; the user reviews evidence and chooses an existing smaller action or confirms a pause. A pause preserves history and explains manual reactivation. Linked-session language always distinguishes recorded starts, self-reported outcomes and independent habit check-ins. Companion states acknowledge saved facts, never diagnose the person or create care obligations.

## Optional Home Screen quick logging

Settings → Home Screen Widgets explains one-time, user-controlled installation. Quick Log separates the logging circle from the name/detail link and quantity/logger link. Saved rows stay put briefly to prevent a second habit appearing under the same finger. 'Left today' counts all due exported habits, not just visible rows. Empty and stale states open Avela; failure copy provides retry/review without diagnostics. Undo and excused-skip replacement remain deliberate in-app actions.

Quick Log's stale-day state offers a user-initiated 'Refresh habits' App Intent that reads the app-owned canonical repositories and exports today's facts without foregrounding Avela. It does not create a completion, auto-reset progress, or evaluate history inside the extension. If refreshing cannot succeed, the stale prompt and explicit Open Avela recovery link remain; the date on old facts is never advanced to fake freshness. WidgetKit controls refresh timing.


## Two focused widgets — 2026-10-07

One-time setup offers Quick Log or Routine. Quick Log needs no selection. Routine requires an existing routine and native Edit Widget selection; no implicit first-routine selection. Log saves a single simple due check-in in the background, while names open details and + opens the quantity logger. Routines advance through due pending steps without changing schedules or completing every member. Routine completion is scoped to today’s exported steps; no-due is distinct from all logged. Older Progress/Attention Home Screen widgets are retired; users with an old placement should remove it and add Quick Log or Routine.


## Optional restriction flow — 2026-10-07

Make Room offers Restrict selected distractions only on an available development iPhone build. Choose Apps & Websites opens contextual permission then native selection with explicit Save/Cancel. Protection is per-session and off by default. Invalid/unprepared protection prevents starting; a later platform failure discloses a saved unprotected timer. Settings, Make Room and session detail surface Stop Protection for an active interval. Stop changes neither timer/outcome nor habit success. Simulator setup explains its limits without requesting access; Release hides this feature until signed validation. Keep exact selected/optional wording; no claim that all apps are blocked or that other Screen Time rules are removed.

## Private-reason form refinement — October 7, 2026

Habit creation/editing keeps name, icon, category, polarity and schedule together. “Why this matters” follows those core controls and opens an optional editor with a short private-status summary rather than exposing the full saved reason in the setup list. The editor provides keyboard Done, a character count, reminder visibility and separate wrapping explanation rows for purpose, storage and removal. Parent Save/Cancel continues to commit/discard the same draft; no new tab or persistence semantics are introduced. Largest-text form and editor audits pass without suppressing findings; physical assistive-technology verification remains pending.

## Widget correction — 2026-10-08

Use explicit **Log / Undo** labels, with “Logged today” as saved status. Undo is a quiet outlined action in the same touch area; Log is filled. Never make the checkmark a silent toggle or perform a status-only refresh on repeat taps. The invoking widget's displayed rows stay briefly pinned to avoid moving the correction under the user's finger. Accessibility labels name the habit and correction. Amount-based/Health progress opens detail for review. Accessible text sizes enlarge the action width. Native WidgetKit waiting/refresh timing is system-controlled; status reflects saved facts rather than optimistic success.

### Immediate widget action feedback

Quick Log and Routine use a custom-styled native `Toggle(isOn:intent:)` for eligible simple check-ins while preserving the explicit Log and exact-record Undo intents. The Toggle's optimistic presentation shows “Saving…” or “Undoing…” immediately. This describes work in flight; the snapshot's counts and “Logged today” label remain saved facts until the system reloads. Amount/Health/skip review links remain unchanged.

The next saved Log/Undo action becomes available when WidgetKit replaces the timeline; no instant reversal or guaranteed redraw deadline is promised. WidgetKit can still dispatch repeated taps during optimistic presentation, so the canonical idempotent intents remain the safety boundary. The pending control uses the same contrast tokens and a 44pt hit area; WidgetKit may apply transient system fading during reload. Status text no longer uses `invalidatableContent` pulsing, since the action label now communicates the wait. There is no added looping animation, local database writer, permission, or dependency. See [Apple's optimistic Toggle behavior](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities).

### Companion preference save acknowledgment — October 21, 2026

Settings → Companion & Feedback keeps the editor open after Save Preferences and changes that same button to a persistent, checkmarked “Saved” state (spoken as “Preferences saved”). Keeping confirmation in the action avoids inserting feedback below the visible viewport at large text sizes. Only a successful repository save displays/announces that confirmation. Changing the animal, visibility, or Haptics clears it; failed saves retain the draft and existing generic error alert. VoiceOver receives a success announcement. No timer, navigation change, extra vibration, or animation is added; disabled haptics remain respected.

### Action acknowledgment consistency — October 21, 2026

An action that leaves its editor open must make its result visible where it was invoked. Show Session Activity changes to a checkmarked Activity Requested only after ActivityKit accepts the request; it does not promise that the OS is displaying it. Hide shows Hiding Activity during dismissal, then Activity Hidden. Failures leave a labelled retry control and explanatory text; Show/Hide never finish the local session. Make Room's successful Start changes the tapped control to Session Started and prevents a duplicate start from that acknowledged control. The existing explicit session-review route remains.

Reminder and Apple Health settings show work and successful configuration saves in the same Save control. Edits clear that acknowledgment. A denied notification permission never claims delivery, and a saved Health connection never claims readable data or a met target. Health Checked means a query completed, including an unknown/no-accessible-data result; failed or canceled reads cannot show it. Disconnect feedback remains visible after its controls disappear.

Back Up Now and Check iCloud Backups show work/result at their controls. Only an acknowledged upload can say Backed Up; an empty successful check explicitly reports that no recovery points were found. Existing consent, restore and deletion confirmations remain unchanged. Progress & History keeps its saved-result text in a bottom safe-area strip, cleared by a day/configuration change, new write attempt or failure. Calendar's earlier Added confirmation clears when a revised plan has not been saved. Shared app-protection status exposes Stop errors/results; authorization shows work in progress. Watch's tapped habit says Logging while waiting for its iPhone reply.

These are acknowledgments of existing explicit actions, not additional dialogs, celebratory haptics, automatic permission requests or new tracking behavior. Native navigation, dismissed editors, visible selection changes and updated records already provide feedback and do not receive redundant Saved states.

## Luminous Tide: connected everyday journeys — October 21, 2026

Long-range Rhythm, amount and session plots use readable recorded-value
alternatives at accessibility text sizes, avoiding overlapping scaled axes.
Weekly date/value rows stack vertically there; normal-size plots keep selection
and the same periods, units and summaries.

This owner-approved implementation supersedes the earlier restrained-header and
calendar-scenery composition. Deep selected-theme gradients, pearl illumination,
original native ribbon contours and rounded display typography give introductory
and action surfaces a shared identity. Recorded data stays on opaque readable
surfaces. Existing theme choices and semantic attention/recovery colours remain;
background art is decorative and never encodes adherence, readiness or pet care.

Today places a compact current-day summary, optional companion and seven-day
calendar strip before habit actions. The strip opens a read-only day review or
an expandable month; selecting a date never redirects Today's logging to that
date. A separate Review or Correct action opens the normal logger with the
reviewed date explicitly selected. Future, paused and weekly periods retain
their meaning. A dot/count represents distinct habits with a saved check-in,
partial quantity or smaller-action entry, not completed targets. Day review
states when activity was recorded without marking the target complete; multiple
entries for one habit still contribute only one habit to that date's count.
The compact companion stays beside the overview before the habit actions; the
week strip keeps today visible when large type requires horizontal scrolling.
Calendar dates lead, with a small original theme landscape after the grid rather
than a large decorative header. Narrow layouts use readable dated rows.
An optional Keep in View choice pins one due habit ahead of the
remaining saved order; Follow My Habit Order removes that presentation choice.
My routines and My day changed expose the existing deliberate grouping/recovery
tools without automatically changing schedules or progress.

Habit rows expose quantity/unit progress and a direct saved-preset amount where
eligible; check-ins, amount entry, detail navigation and exact-record Undo are
separate controls. Detail leads with identity/status and Log Progress/Make Room,
then Calendar History and factual rhythm. The month calendar leads with dates;
compact current/personal-best totals follow, with a readable calendar key and
separate flexible-weekly outcomes. Streak totals remain through today, even when
browsing another month. Attention budgets keep manually logged provenance and
place Log Usage beside today's status. New-entry amount choices fill a draft;
Save remains the explicit additive action, while correction replaces its exact
entry's amount.

Each calendar streak metric is spoken once with its name, value and unit. Its
accessibility bounds cover that full metric; display numerals retain intrinsic
height and breathing room rather than carrying a sentence on the digit alone.

Creation offers editable collections and a larger local idea library alongside
immediate custom entry. Check-in, amount and timed tracking describe how the
habit logs; timed tracking uses a minute quantity and the existing explicit
activity timer. A target and optional smaller action can be reviewed before the
first Save. Connected Health setup remains a distinct contextual opt-in after
saving. Four routine starters suggest a few existing active habits by their selected
categories; people review, remove, reorder and Save the group. Browsing ideas,
collections or routines never creates habits, completes them or changes a plan.

Make Room is a session composer with the habit, type and actual saved minute
target visible together. Focus permits phone use; phone-free is a self-reported
intention. New 15/25/45-minute starters open an editable goal draft, and require
Save before a separate Start. Existing session configurations are not silently
rewritten. Optional activity presentation and selected-app restriction controls
stay near Start; required consent/manual meaning remains visible, with longer
mechanics in a disclosure. Protection belonging to another session is labelled
as such. Session Started and Activity Requested remain acknowledgments of their
specific operations, not promises of habit completion or verified focus.

Insights keeps the canonical completed-week review and adds Rhythm and Activity
lenses within the existing destination. Twelve-week bars are independent weekly
snapshots of that week's eligible habits; they are explicitly distinguished from
the comparable-cohort trend. Quantity visuals retain their unit, weekday charts
state resolved opportunity counts, and session charts distinguish recorded starts,
self-reported outcomes and ended timer minutes. The annual activity grid is a
record of check-ins/effort rather than adherence; monthly navigation and labelled
value alternatives keep small cells understandable. Optional sharing first shows
a preview: habit names are off by default, week dates can be omitted, and only an
explicit Share opens Apple's share sheet. Private reasons, reflections, Health
samples and detailed attention records are outside this card.

Onboarding preserves its six stages, account-free path and optional skips. Each
stage has a compact original illustration, a scalable heading and contextual
setup/readiness content. The bottom Continue action stays reachable while long
content scrolls; changing stages returns to the heading. Selecting a companion
changes its choice appearance immediately; persistence remains the existing
Continue/Save operation. The finish illustration respects a hidden-companion
choice. No permission, account, subscription or goal creation is introduced by
an illustration or by opening a stage.

Motion is bounded to press/state/entry responses; there is no idle animation or
new haptic loop. Reduce Motion removes scale/translation, Reduce Transparency
and Increase Contrast simplify decorative layers, and charts retain textual
values. Larger text reflows actions, companion choices, session selectors and
calendars; decorative scenes become smaller rather than shrinking readable text.
Existing success/error acknowledgments, exact-record Undo, VoiceOver context and
save confirmations remain part of the interaction contract. Native screenshots,
functional checks and physical accessibility/performance validation must be
reported separately; this section makes no test, usability or award claim.
