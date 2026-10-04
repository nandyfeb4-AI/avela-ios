# Evidence trace — which competitor screens back which recommendation

Round 2 · 2026-10-03.

This document traces each recommendation in [VISUAL_DIRECTIONS.md](VISUAL_DIRECTIONS.md),
[COMPONENT_SPEC.md](COMPONENT_SPEC.md) and the new [TODAY_CONCEPTS.md](TODAY_CONCEPTS.md)
back to the specific competitor screen, interaction or official document it
rests on. It reuses the sources gathered in [COMPETITIVE_RESEARCH.md](COMPETITIVE_RESEARCH.md);
no new web research was done in this pass.

## Evidence labels

| Label | Meaning |
|---|---|
| **Obs-shot** | Seen in a current App Store screenshot. Cited as *app · screenshot n (subject)*: the listing's screenshot order on 2026-10-03 and what it shows. Copies were viewed in a scratch folder and are not committed. |
| **Obs-doc** | Stated in an official help page, blog, release note or listing text (URL given). |
| **Inference** | Our interpretation. Not validated. |
| **Avela-doc** | Comes from Avela's own product docs, not from competitors. |

## What this evidence can and cannot show

- **"A successful app does X" shows only that X exists in a popular product.**
  It does not show that X *causes* the popularity, or that X suits Avela's
  users. Ratings measure the whole app, not one screen.
- **Stills show no motion.** Every interaction claim below is either taken
  from an official document or marked unverified.
- **Some recommendations come from Avela's docs, not competitors.** They are
  listed separately at the end so nobody mistakes them for market evidence.

## A. Recommendations backed by competitor evidence

### A1 · Count weekly-frequency goals per week, shown as "2 of 3 this week" pips

| Source | Evidence | Type |
|---|---|---|
| Streaks 5 release notes | "If you miss a task but still have enough days in the week to meet your goal, the task will show a 'missed' indicator, but your streak will not be broken." [crunchybagel.com/streaks-5-now-available](https://crunchybagel.com/streaks-5-now-available/) | Obs-doc |
| Habitify help | "Even if you mark a day as failed, as long as you complete the goal of the week, your streak is still counted up." [intercom.help/habitify-app/…/6113621](https://intercom.help/habitify-app/en/articles/6113621-learn-about-streak-in-habitify) | Obs-doc |
| Habitify · screenshot 1 (marketing collage) | Widget cards read "3/8 times" and "35/150 mins this week". | Obs-shot |

**Inference.** Two established trackers both protect weekly goals from a
single missed day. That suggests users push back on day-level failure for
weekly goals, but it is not proof.

**Where Avela differs**

- The weekly unit is the *only* framing. Both competitors still show a
  "missed" or "failed" day marker inside the week; Avela shows no per-day
  miss for `timesPerWeek` habits at all.
- This is already domain behavior (DATA_MODEL "Phase 1 progress metrics").

### A2 · Make recovery and skips neutral, first-class states

| Source | Evidence | Type |
|---|---|---|
| Habitify help | Skip "tells the app, 'I am not doing this habit today, but I am not failing it either.'" Off Mode: "Nothing will be marked as skipped or failed while Off Mode is active." [intercom.help/…/11597864](https://intercom.help/habitify-app/en/articles/11597864-3-ways-to-pause-or-cut-off-your-habits) | Obs-doc |
| Habitify · screenshot 2 (Progress) | A 28-day calendar marks Off Mode days with a palm-tree glyph. | Obs-shot |
| Structured blog | "Replan… lets you decide on how to deal with them" (Reschedule / Move to Inbox / Check Off / Delete). [structured.app/blog/replan](https://structured.app/blog/replan) | Obs-doc |
| Finch help | Pause Mode: "your streak is paused and preserved." [help.finchcare.com/…/37936144770701](https://help.finchcare.com/hc/en-us/articles/37936144770701) | Obs-doc |

**Inference.** Three of the six apps invest in a rest or replan path. We
read that as a common response to guilt. None of them publishes evidence
that it works.

**Where Avela differs**

- Recovery is a **computed, forward-looking state**: "2 of 3 good days since
  your miss", ending after 3 successes (DATA_MODEL). The competitors offer
  *pauses*; none of them shows progress *back* from a miss.
- Avela has no Off Mode equivalent. Archive covers long pauses.
- There are no paid streak repairs (Finch: "You can use Rainbow Stones to
  repair your streak", [help.finchcare.com/…/37780736136205](https://help.finchcare.com/hc/en-us/articles/37780736136205)).

### A3 · Avoid loss-aversion cues: no flame, no "Fail", no reset-to-zero copy

This one is negative evidence: what *not* to copy.

| Source | Evidence | Type |
|---|---|---|
| Streaks website | "Don't break the chain, or your streak will reset to zero days." [streaks.app](https://streaks.app) | Obs-doc |
| Streaks · screenshot 4 (widgets) | A dot calendar marks a miss with ×. | Obs-shot |
| Habitify · screenshot 1 | Flame plus streak count ("🔥 33"). | Obs-shot |
| Habitify help | Daily habits: "if you don't check in or check in as 'Fail,' the streak will end." | Obs-doc |
| Opal · screenshot 4 (home) | Streak flame "20" in the header. | Obs-shot |
| Finch help | A streak counts "each day you open the Finch app". | Obs-doc |

**Inference.** These cues are widespread among highly rated apps, so
avoiding them is a deliberate differentiation bet, not market consensus.
The rule itself comes from Avela's UX.md ("Do not show: 'Streak ruined',
'Back to zero'").

**Where Avela differs**

- Misses are hollow rings, never ×.
- No flame symbol (ICON_SYSTEM §1).
- Streaks never depend on opening the app.

### A4 · One hero number, compared with the user's own recent past

| Source | Evidence | Type |
|---|---|---|
| Opal · screenshot 1 (weekly dial) | "1h 23m LESS THAN USUAL", with "Usually 4h 04m a day / This week 2h 41m a day". | Obs-shot |
| Habitify · screenshot 2 | "Average Daily Score 72.3% ↑15%". | Obs-shot |

**Inference.** A self-baseline reads as feedback, not judgement.

**Where Avela differs**

- The trend is stated in *points*, not percent.
- It is computed only over a **comparable cohort** of habits. That rule is
  now implemented (DATA_MODEL "Trend comparable-cohort rules").
- Neither competitor states such a rule. Habitify's "↑15%" has no visible
  definition.

### A5 · One restrained accent, hairline separators, colour only for state

| Source | Evidence | Type |
|---|---|---|
| Things · screenshots 1–2 (Home, Today) | White canvas, hairline section separators. Colour appears only in list glyphs, the blue accent and red deadline flags. | Obs-shot |
| Things listing | Editors' Choice. Apple Design Awards 2009 and 2017 ([2009](https://culturedcode.com/things/blog/2009/06/things-wins-apple-design-award-2009/), [2017](https://culturedcode.com/things/blog/2017/06/back-from-wwdc/)). | Obs-doc |
| Structured · screenshot 2 (timeline) | Counter-example: a different colour per task plus dot clusters. | Obs-shot |

**Inference.** Things' restraint reads as premium. The awards are evidence
of craft overall, not of this one choice.

**Where Avela differs.** Avela's semantic colours carry *state*
(teal = done, amber = recovering or near limit, clay = over budget). Things'
colours carry *category*.

### A6 · Small per-item progress glyphs instead of big rings or charts

| Source | Evidence | Type |
|---|---|---|
| Things · screenshots 1 and 5 | A small pie per project fills with progress. | Obs-shot |
| Streaks · screenshot 1 (Today) | Counter-example: large rings are the entire screen. | Obs-shot |

**Where Avela differs.** Pips count *distinct days* toward a weekly target.
A pie shows share of tasks done. Different unit, same visual economy.

### A7 · Trailing circular completion control, one tap, immediate undo

| Source | Evidence | Type |
|---|---|---|
| Structured · screenshot 2 | A hollow ring on the right of each timeline item. | Obs-shot |
| Habitify · screenshot 3 (Today in ChatGPT) | Trailing "✓ Done / +1 / Log" buttons. | Obs-shot |
| Little Streaks guide (sibling app, *not* Streaks itself) | "tap-hold the task to fill the outer ring", "shake to undo". [crunchybagel.com/getting-started-with-little-streaks](https://crunchybagel.com/getting-started-with-little-streaks/) | Obs-doc |
| Things · screenshots 2 and 5 | Counter-example: a *leading* rounded-square checkbox. | Obs-shot |

**Inference.** There is no evidence that a trailing control beats a leading
one. Avela keeps trailing because the current app already uses it
(`TodayView`), and a one-tap control is an MVP requirement ("Logging is one
tap from Today view").

**Unverified.** Streaks' own hold-to-complete behavior. Its help is in-app
only.

**Where Avela differs.** One tap plus an undo toast (not built), instead of
tap-and-hold. This trades accidental-tap protection for speed. The user test
probes it.

### A8 · Type-specific logging controls, such as "+5 min" chips (new in Today concept 2)

| Source | Evidence | Type |
|---|---|---|
| Habitify · screenshot 3 | The row action adapts to habit type: "Done", "+1", "Log". | Obs-shot |
| Opal · screenshot 5 (timer) | A "− 30m +" stepper and a single "Start Timer" CTA. | Obs-shot |

**Inference.** Quantity logging in one tap is feasible and established.
Nobody we studied logs *attention minutes* inside a habit list.

**Where Avela differs.** Attention budgets with healthy, near-limit and
over states sit in the same Today as habits. In this set, attention appears
only in Opal, and Opal is block-first, not log-first.

### A9 · Live Activities only for user-started, time-bound sessions

| Source | Evidence | Type |
|---|---|---|
| Opal help | A Live Activity appears after you unblock an app or start a timer and lock the device. [help.opalapp.com/…/live-activities](https://help.opalapp.com/article/how-do-i-enable-live-activities-for-opal) | Obs-doc |
| Structured help | Live Activities need an active Focus timer. [help.structured.app/…/330626](https://help.structured.app/en/articles/330626) | Obs-doc |
| Streaks · screenshot 5 | Lock Screen Live Activity for a timed task ("PRACTICE GUITAR 18:56"). | Obs-shot |
| Apple HIG | "defined beginning and end… don't exceed eight hours" ([Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities)) | Obs-doc |

**Where Avela differs.** Nothing here is distinct. This is platform
convention, already required by APPLE_COMPLIANCE.

### A10 · A companion that is small, derived from real state, and free of dependency cues

| Source | Evidence | Type |
|---|---|---|
| Finch · screenshot 2 (forest scene) | The scene covers about 55% of the screen above the goals. | Obs-shot |
| Finch · screenshot 3 (valentines) | The pet speaks in first-person plural: "Let's remind them that they're special to us!" | Obs-shot |
| Finch · screenshot 4 (adventuring) | "3 goals left today!" and "5⚡" energy per goal. | Obs-shot |
| Finch listing | 4.9 from 758,981 ratings; Editors' Choice. | Obs-doc |
| Opal help | No character; a selectable "Gem" as the identity element. [help.opalapp.com/…/gem](https://help.opalapp.com/article/how-to-choose-your-gem) | Obs-doc |

**Inference.** Finch's scale shows a character *can* carry a self-care
product. It does not show that the cute, dependency-framed version is
required. That is the bet Avela is making.

**Where Avela differs**

- The companion reflects **habit and attention state** deterministically
  (MVP §8).
- No currency, no care obligation, no "us".
- No researched app ties a character to attention budgets.

### A11 · Done items grouped and de-emphasized, not struck through

| Source | Evidence | Type |
|---|---|---|
| Habitify · screenshots 3 and 5 | Done items collapse into a "Success" section and are struck through. | Obs-shot |
| Things · screenshot 2 | A separate "This Evening" section, showing that grouping by context is accepted. | Obs-shot |

**Inference.** Collapsing done items is established. The no-strikethrough
choice is ours, for legibility and to avoid a "crossed out" reading.

**Where Avela differs.** Concept 2 collapses done items into a "Done · 2"
row with icon avatars. Habitify keeps them as a struck-through list.

### A12 · Self-authored intent as gentle friction (future attention surfaces)

| Source | Evidence | Type |
|---|---|---|
| Opal · screenshot 2 (block screen) | "You set this rule yesterday. Past you was right." | Obs-shot |
| Opal help | An opt-in "Brutal Insults" block-screen pack, and a "Deep Focus" mode that "can't bypass or cancel". | Obs-doc |

**Inference.** Quoting the user's own earlier intent is respectful. Harsh
packs and uncancellable modes are not, and Avela rejects them.

**Where Avela differs.** Avela never blocks in V1 (manual logging only). The
pattern is reserved for near-limit copy such as "You set 30 minutes for
today."

### A13 · Eyebrow date plus large title

| Source | Evidence | Type |
|---|---|---|
| Habitify · screenshot 5 | "TODAY" eyebrow over a "My Journal" large title. | Obs-shot |

**Where Avela differs.** Nothing here is distinct; it is a common iOS
pattern. Low stakes.

## B. Recommendations NOT backed by competitor evidence

These come from Avela's own docs or are design judgment. Don't cite the
market for them.

| Recommendation | Actual basis |
|---|---|
| Amber and clay instead of red for recovery and over-budget | Avela-doc: VISION "Calm, not punitive"; DESIGN_SYSTEM "avoid guilt colors". No competitor was observed avoiding red as a rule; Things uses red for deadlines. |
| Warm paper neutrals instead of white | Design judgment. Untested. |
| SF Pro Rounded for numerals | Design judgment. Opal and Streaks use heavy numerals but different faces. |
| 14-day ledger with distinct shapes per state | Avela-doc (UX.md) plus the HIG "more than color alone" guidance. Streaks' dot calendar is a partial precedent. |
| Attention thresholds at 70% and 100% | Avela-doc: UX.md "Attention states". |
| Companion sentence copy rules | Avela-doc: UX.md "Companion UX", DESIGN_SYSTEM. |
| Pillar tiles, Habits and Attention (concept 2) | Product-thesis judgment from VISION's "core promise". No competitor precedent; that absence is the point. |

## C. Where Avela's experience is distinct, in one place

1. **Habits and attention budgets in one daily surface.** Opal does
   attention without habits. Streaks and Habitify do habits, with "minutes"
   only as a habit quantity. None of the six shows a near-limit attention
   state next to habit progress.
2. **Recovery as visible progress back.** The competitors offer pauses,
   skips and replanning. None shows "2 of 3 good days since your miss".
3. **Honest weekly review rules, visible in the UI.** The cohort-matched
   trend, ties named, and "not enough data" instead of 0%. None of these is
   documented by any competitor.
4. **A calm, adult companion with no economy.** The only companion product
   in the set (Finch) is effort and currency driven.
5. **No loss-aversion mechanics at all.** Every habit app here uses at least
   one: a flame, reset-to-zero, a "Fail" state, or app-open streaks.

None of these differences is validated with users yet. See
[USER_TEST_TODAY.md](USER_TEST_TODAY.md).
