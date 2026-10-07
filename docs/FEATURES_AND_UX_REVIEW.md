# Avela — implemented features and UX review

Updated: October 6, 2026. This is a product review inventory, not a claim that every integration has been verified on hardware or that the app is ready for App Store submission. It describes implementation in this repository; configuration-dependent capabilities and proposed work are separated below.

## Product intent

Avela combines habit tracking, intentional use of attention, and recovery after interruptions. Its proposed promise is: **Build habits that survive real life—and protect the time to do them.** This positioning is a proposal, not validated market differentiation.

The app is native Swift/SwiftUI/SwiftData, local-first, with Apple frameworks and no third-party runtime dependencies, analytics SDK, advertising SDK, generative AI or Avela-operated backend. Apple speech recognition uses machine learning; that is distinct from an LLM interpreting or advising on your notes.

## 1. Today and navigation

- Four main tabs: Today, Insights, History, Settings.
- Today shows compact habit and attention summaries, actionable habit rows, a compact optional companion near the daily overview, recovery support, attention goals, and routines.
- Habits have separate completion/log controls and detail navigation: opening details never logs success.
- Completed habits move into a collapsible Done group after a short delay, rather than disappearing immediately under the user's finger.
- Logging confirmation offers Undo tied to the actual recorded entry; accessibility conditions keep that action available until explicit dismissal/navigation or another action.
- Attention budgets have +5/+15-minute controls plus a custom amount. These represent manual logging, not automatic app usage measurement.
- Creation controls are native toolbar buttons. Some features still require scrolling or opening a detail screen; discoverability is an ongoing UX concern.

## 2. Habit creation and management

- Create, edit, archive and reactivate habits.
- Names, curated SF Symbol icons, categories and Build Up/Cut Down polarity.
- Daily, selected weekdays, and flexible times-per-week schedules.
- Starter-habit library, reviewed before creating an actual habit; templates never manufacture history.
- Optional private text reason on create/edit; recovery and Make Room reminders, persistent Hide, and removal by blanking.
- User-controlled ordering of active habits, with draft Save/Cancel and persistent order.
- Cosmetic edits retain historical records. Schedule/polarity edits append configuration snapshots.
- Snapshot revisions make multiple same-day edits deterministic, including identical timestamps.
- Archive/reactivate cycles retain recorded pause periods. Paused time creates no misses, streak extension or progress reset.
- Archived-habit management lives in Settings; archived identity is explicitly labeled, not conveyed by color alone.

## 3. Habit logging and quantities

- Explicit completion and undo for check-in habits.
- Optional quantity targets and additive progress in configured units, with personal quick-log amounts.
- Partial quantity progress stays distinct from full success. Reaching a target can create the corresponding success; removing progress below the target withdraws that derived success.
- Optional smaller actions record separate effort rather than pretending the full habit was completed.
- Habit activity timer with explicit controls and logging of whole minutes; elapsed time alone never marks a habit complete.
- Confirmation for dated history corrections: success, skip and clearing a record.
- Correction validation rejects invalid dates/paused or unscheduled days and checks quantity requirements. Historical corrections may change calculated metrics.
- Habit success, attention usage, session outcomes and reflection text remain separate facts.

## 4. Streaks, recovery and lifetime progress

- Habit Detail → Momentum combines explainable recent consistency, recovery and lasting effort as separate facts, without a weighted score.
- Current and best streaks, with schedule-aware day/week/commitment language.
- Duplicate same-day completions do not inflate calculated day success.
- Excused skips neither extend nor break streaks and are excluded from consistency denominators.
- A still-open period is not counted as a miss. Archive boundaries do not manufacture misses for time after tracking stopped.
- Recovery uses the existing three-consecutive-successful-commitment threshold after a miss; underlying streaks continue beyond recovery.
- Today's Build Momentum card groups relevant recovery support, with factual counts and links to existing smaller-action/lighter-schedule tools.
- Make It Easier proposes a schedule adjustment for eligible habits and requires explicit confirmation/revalidation. It never silently changes all habits.
- Lifetime progress and milestone views emphasize accumulated recorded success rather than only an unbroken streak.
- No currency, mascot-care obligation, streak-loss penalty or generated motivational advice.

## 5. Calendar and History

- Per-habit calendar reached through Habit Detail → Calendar; no standalone calendar tab.
- Month navigation, current/best streak presentation, themed hero/scenery and clear daily status treatments.
- Success, skip, miss, pending/unknown and paused contexts remain distinguishable; flexible weekly commitments are not painted as invented daily successes.
- Calendar reads history without recording or correcting it automatically.
- History presents recent records grouped by their stored local-day keys, preserving grouping after travel/time-zone changes.
- Habit filtering, archived-habit inclusion, distinct completed/skipped entries and historical schedule context.
- Duplicate records may remain visible as independent facts even though metric calculations deduplicate successful days.
- Today/detail navigation can open filtered History; cross-screen returns refresh real data.
- History's existing recent-range/filter behavior is bounded; it is not an unlimited forensic event explorer.

## 6. Weekly Insights

- Review completed weeks with previous/next-week navigation; the current unfinished week is not presented as a completed review.
- Overall habit consistency is an equal-weight average of eligible habit percentages, not pooled daily/weekly opportunities.
- Exact successful/resolved commitment counts and per-habit bars alongside the overall ring.
- Strongest and needing-attention callouts use actual weekly results and list ties. Balanced/single-habit results receive a neutral summary rather than contradictory rankings.
- Trends use comparable habits/schedules across the two weeks, not unrelated cohorts. Insufficient comparability is disclosed.
- Attention budget results use historical manual entries and budget snapshots. Missing logs are unknown, not assumed zero usage.
- Below-budget ratio and logging coverage are separate: at the budget limit is not counted as below it.
- Direct habit-detail and filtered-History navigation from Insights.
- Read-only intention-session review, described below; reflection entry point selects the week being reviewed.
- No invented trend series, causal conclusions, predicted adherence or AI analysis of journal text.

## 7. Attention goals and sessions

- Daily maximum-duration budgets, manually logged in minutes.
- Manual protected windows and phone-free windows, including overnight-local-time handling.
- Phone-free sessions: a stated intention to stay off the phone, not blocking or monitoring.
- Focus sessions: concentration on an activity, with phone use explicitly allowed.
- Saved goals retain their original type; adding Focus does not relabel old phone-free records.
- Session durations and captured start/end boundaries are preserved. A timer ending does not certify success.
- Explicit outcome reporting, with success unavailable before the target end and interruption reporting available earlier.
- Correct/delete today's manual budget entries and edit targets while retaining historical budget snapshots.
- Clear manual provenance, Healthy/Near Limit/Exceeded or not-logged wording; no claim that Avela automatically measured other apps.
- Automatic Screen Time reading/blocking is **not implemented**.

## 8. Make Room → Do It

Entry point: **Today → habit details → Make Room**.

1. Create a reusable session goal directly here, or select an existing focus/phone-free goal.
2. Read the distinction: focus permits phone use; phone-free expresses an intention to take a break. Neither monitors apps.
3. Optionally enable mascot/timer presentation in Dynamic Island and on the Lock Screen.
4. Explicitly start the session, which records its habit intention separately.
5. Open Session & Check In to report the session outcome.
6. Use Log What I Did to open the habit's existing check-in/quantity logger. This is a separate, explicit write.

Goal creation respects the same plan limits as Today. Opening Make Room or saving a session goal never starts a timer. A failed intention-link write discloses the already-started session rather than inviting duplicate starts. Linked history remains available after relaunch.

The review **What I Made Room For** presents recorded linked sessions, ended timer duration and independent habit-success days for the selected week. It does not assert that sessions caused completions or that timer minutes equal screen minutes avoided. Focus and phone-free results are explicit self-reports.

## 9. Routines and manageable weeks

- Group existing habits into user-selected routines, with their normal logging tools.
- Short restart plans with a review date, rather than resetting historical progress.
- Manageable Week review with explicit individual choices: keep a habit, open a configured smaller action, confirm a pause or choose a restart group.
- Start Small changes focus rather than silently lowering everybody's targets.
- Saved intentions/routines do not automatically complete their member habits.
- A single highly discoverable Today “My day changed” flow remains proposed; the underlying tools already exist.

## 10. Private reflections and dictation

- Weekly reflection prompts: What Helped? / What Got in the Way?
- Either prompt can be left blank; an explicit Save is required, with a 500-character limit per answer.
- Edit, Cancel, Delete and relaunch persistence. Deleting a note does not delete habit history.
- Recorded weekly commitments provide factual context; journal wording is not analyzed or used to change metrics.
- Each editor prompt offers optional Dictate → Start → Stop → review/edit → Add Text.
- Reviewed transcript appends to typed text; the reflection must then be saved separately.
- Apple-native on-device recognition is required. Unsupported devices/languages or denied permissions keep typing available; no cloud fallback.
- Microphone/speech permission requested only after explicit Start. Capture is bounded to 55 seconds and stopped on dismissal/background/interruption/error.
- Transient audio buffers only: no saved audio-note files, LLM, continuous microphone, sentiment analysis or automatic voice habit logging.
- Physical-device transcription is still a verification gate; simulator transcript editing tests validate review behavior, not microphone accuracy.

## 11. Companion, feedback and Dynamic Island

- Original owl, fox and otter companion assets, selectable in Settings/onboarding.
- Optional companion visibility and feedback preferences, persisted across relaunch.
- Deterministic state selection from recorded app state, with brief factual/non-shaming messages.
- Compact Today placement near the daily overview; companion does not dominate actionable rows.
- Brief state transitions and Reduce Motion handling; no continuous attention-seeking animation loop.
- Optional session Live Activities show selected mascot and a countdown on supported Dynamic Island/Lock Screen.
- Compact, minimal and expanded layouts. Long-press expands the system presentation; tapping returns to Avela.
- Make Room exposes presentation at session start; the existing session detail also offers Show/Hide Session Activity.
- Focus sessions identify themselves as focus, not phone-free. Existing phone-free activities retain their meaning.
- Activity contains no private habit name/history and never certifies focus or phone use. It is not a permanent idle mascot when no session is active.

## 12. Apple-native integrations

| Integration | What is implemented | Verification boundary |
|---|---|---|
| Siri / Shortcuts | Log habit success, add configured-unit habit progress, log manual attention minutes; guide and App Intents | Real-device discovery/spoken execution still needs verification; no in-app voice-command parser |
| Apple Health | Optional reads of chosen steps/exercise minutes for connected Build Up habits; explicit configuration and locally recorded resulting success | Refresh/open-driven, not unrestricted background automation; real permission/data delivery needs device testing |
| Notifications | Opt-in habit reminders, native permission handling and explicit notification actions | Real delivery, denial and schedule/time-zone behavior need device checks |
| Widgets | Native progress presentation, shared local snapshot, deep links and explicit supported logging actions | Refresh timing and signed App Group provisioning need hardware/distribution checks |
| Live Activities | Explicit session mascot/countdown request, update/reconcile and hide/end | Native simulator render captured; supported-device/settings/distribution validation still needed |
| Apple Watch | Opt-in due-habit snapshot, supported explicit quick logging and local timer, phone-side checks | Reachable paired iPhone required for writes; no offline logging queue; signed paired-device checks pending |
| StoreKit 2 | Native product loading, verified entitlement handling, purchase/restore/manage-subscription flows and StoreKit tests | Real product setup, account agreements and signed sandbox/TestFlight validation remain external prerequisites |
| Private iCloud recovery | Optional dated logical backup, restore into an empty installation, explicit deletion/opt-out, validation and rollback handling | Current placeholder signing/container configuration must be activated; not a working production cloud service merely because code exists |

## 13. Data protection and commercial access

- SwiftData local persistence with historical configurations, pause periods and stored local-day identities.
- Logical backup validation and explicit restoration flow avoid overwriting existing tracking.
- Optional private Apple iCloud backup is a recovery-copy mechanism, not live sync or an Avela-operated account/database.
- Health/fitness/Health-connected history, reflection notes, completion notes and private habit reasons are excluded from app-managed logical cloud recovery. Apple whole-device backups are separate.
- Restore requires an empty tracking installation; timers do not restore as manufactured completed outcomes.
- Free creation limits currently: three active habits and one attention goal. Premium increases creation capacity.
- Existing records, logging, history, edits and recovery remain accessible when Premium expires; no deletion of historical progress.
- Privacy explanation, policy URL configuration, native subscription management and App Store privacy/release documentation exist. Publishing/configuration is not automatically complete.

## 14. Visual design and interaction work

- Vivid Tidewater brand foundation and nine themes: Tidewater, Sapphire, Plum, Ember, Rose, Indigo, Forest, Coral, Gold.
- Themes vary atmosphere/backgrounds, gradients, heroes, controls and progress treatments, with original static scenery; not only text/icon colors.
- Neutral light/dark reading surfaces preserve legibility and allow curated habit identity colors.
- Themed calendar hero and streak/status treatments, rather than a generic plain list.
- Consistent SF Symbols, scalable system typography, native navigation/forms/dialogs and semantic colors.
- Habit Detail groups identity/progress, Explore Progress and Support Your Habit; Settings and secondary screens use consistent icon/section hierarchy.
- Accessible touch-target work, adaptive icon grids, large-text stacking, VoiceOver descriptions, Reduce Motion/Reduced Transparency treatment and explicit archive labels.
- Completion feedback avoids immediate row movement; Undo is an explicit action, not merely color feedback.
- Native cancelable archive alert, inline modal titles, polarity-aware “Log success” copy for Cut Down habits.
- Visual Insights rings/bars communicate exact available facts, with missing-data and comparability explanations.
- Screenshot evidence exists under docs/verification/. Browser research/mockups under design/exploration/ are design artifacts, not proof of native behavior or user preference.
- Physical VoiceOver, keyboard/focus order, small-device/OLED, Increase Contrast, energy and broad real-user usability checks remain incomplete. No Apple Design Award readiness or win is claimed.

## 15. Verification and limits

- Connected differentiation: 501 unit tests and four affected UI flows pass across runs; Debug/Release build and old populated-store migration checked. [Screenshots and evidence](verification/differentiation/README.md).

- Earlier visual-insights verification: 460 unit tests and nine targeted Insights UI flows passed; it was not a new full UI-suite run.
- Dictation slice: 18 relevant unit tests plus two targeted UI flows passed; actual microphone recognition remains unverified on hardware.
- Make Room → Do It: all 473 unit tests and four affected UI flows passed, with Debug and Release builds. Native screenshots, commands and physical-device limits are in [Make Room verification](verification/make-room/README.md). This was a full unit run and a targeted UI run, not a full UI-suite run.
- Debug/Release compilation and simulator evidence do not establish signed device entitlements, App Store product availability, CloudKit provisioning or absence of all bugs.
- This inventory contains no private user tracking, secrets, receipts or financial account details.

## 16. Differentiation hypotheses to evaluate

These are proposals, not claims that competitors lack these features:

1. **A coherent make-time-to-action loop:** habit → focus/phone-free intention → companion timer → actual independent habit logging → factual weekly review.
2. **Recovery that respects life:** smaller actions, recorded pauses, restart groups and lifetime progress without erasing past effort or creating mascot guilt.
3. **Honest personal patterns:** descriptive comparisons using adequate samples, explicit denominators and unknown-data treatment; never imply causality. This advanced comparison engine is not yet implemented.
4. **Low-friction capture:** quantities, quick amounts, Siri, opt-in Health, Watch and dictated reflections working together. Broader in-app voice logging remains proposed.
5. **Adaptive presentation without silent changes:** optional lighter-day choices and progressive disclosure; never automatic schedule rewriting.

## 17. Questions for an independent product/UX review

- Which one user/job should Avela target first? Are these capabilities coherent for that person?
- Which existing features are hard to find or understand, and should be simplified before adding more?
- Is Make Room valuable enough to become a primary Today action? What needs observed user evidence?
- Does charging for a second attention goal undermine the habits-plus-focus promise? Consider the business model alongside UX.
- Which proposed differentiator would remain useful after novelty wears off?
- Which capabilities duplicate competitor baseline expectations versus create a meaningfully better journey?
- What exact competitor evidence supports each comparison? Use current primary sources; don't infer uniqueness from a marketing omission.
- Which integrations are genuinely worth setup/permission friction? Which should remain optional or hidden until relevant?
- What should be removed, postponed or consolidated to protect clarity, reliability and privacy?

## Suggested prompt to share with ChatGPT or Claude

> Review this implementation inventory critically. Separate implemented features, configuration-dependent integrations, verification gaps and proposed ideas. Identify a focused target user and three defensible differentiation hypotheses. Compare against current leading habit/focus apps using cited primary sources; label observations and inferences. Recommend a prioritized plan that improves activation, discoverability and repeated usefulness without feature sprawl, causal claims, privacy compromises or shame mechanics. Do not assume every implemented integration is production-ready. Include concrete user journeys and measurable evaluation criteria; make no award or market-share guarantees.

## 18. Connected differentiation enrichment

- Optional 240-character “Why this matters” text on habit create/edit; persistent Hide, removal by blanking, recovery and pre-Make Room reminders. Text stays out of app-managed logical cloud recovery and shared extension data. No photo memory yet.
- Habit Detail → Momentum: recent resolved-commitment consistency, three-success recovery and lifetime effort, explained separately. Unknown is distinct from measured zero; quantities retain captured units. No opaque score or AI.
- Today → A smaller step: repeated resolved misses on the exact current schedule provide explainable evidence; open the configured smaller-action logger without saving, or confirm an indefinite pause. Paused history stays intact; manually reactivate in Settings. No fake scheduled resume.
- Make Room and its review show “You made room for [habit] N times this week,” explicitly counting recorded linked starts, separate from outcomes/check-ins and any causal claim.
- Four app-facing companion states with distinct existing poses and factual labels: steady, building momentum, recovering, logged budget exceeded. Optional visibility and Reduce Motion remain supported.

This sharpens the product promise around protected attention, retained progress and personal motivation; market differentiation and behavior change have not been validated with users.

## 19. Optional Quick Log widget

Small/medium Home Screen option: dedicated circle for a saved simple check-in without opening the app, name link for details, plus link for quantity logging. Pending rows follow habit order; successful rows remain in place briefly. Older/stale snapshots, midnight, timezone changes, edited schedules, quantity targets and skipped days cannot silently write. App-owned persistence, no new permission, no mascot or stats dashboard. After midnight, Refresh habits updates the app-owned projection without opening Avela or recording a completion. The optional Settings guide explains one-time placement and privacy. Device/provisioning validation remains distinct from simulator verification.


## 20. Simplified Home Screen logging

Two Home Screen widget types: Quick Log (today’s habits) and Routine (explicit saved-routine selection), both small/medium. Clear labelled Log buttons save individual simple check-ins without opening UI. Quantity + and names still open their distinct destinations. Pending routine steps follow saved order; completed/skip/weekly-met facts never become new required successes. Native routine configuration reads only app-exported names/IDs/order. Existing Progress/Attention registrations are retired; active-session Dynamic Island stays separate.


### Approved widget presentation

Quick Log and Routine use Rich Tide: selected-theme deep gradients, clear pale Log buttons, small/medium sizes and reduced row counts at accessibility sizes. Simple check-ins save without opening Avela. Names open details; quantity + opens the amount logger. Native screenshots and remaining device checks: [verification](verification/two-widgets/README.md).
