# Today concepts, round 2 — Action-first, Balance, Quiet companion vs Tidewater

Round 2 · 2026-10-03. These are proposals. No app code was changed.

All four Today screens use **Tidewater's tokens and components**, so the
comparison is about information architecture and interaction, not colour.
Every phone shows **identical data**:

| Item | Value |
|---|---|
| Time | Saturday, October 3, 9:41 AM |
| Habits | 5: Drink water, Read (2 of 3 this week), Journal (recovering, 2 of 3), Morning walk (done), No phone in bed (cut down, success logged) |
| Attention goals | Social media 18 of 30 min · News protected until 6 PM · Phone-free first 30 min done at 7:12 AM |
| Many-habit variant | The same plus 6 more habits, 11 in total (3 done) |

The habit copy follows the **implemented** `HabitPolarityFormatter` wording
("Log success" / "success logged"). That supersedes the "Avoided" wording
proposed in COMPONENT_SPEC §4 (see "Corrections" below).

## Mockups

| Board | What it shows |
|---|---|
| [`board-today-compare-light.png`](mockups/png/board-today-compare-light.png) | Tidewater and concepts 1–3, side by side, annotated |
| [`board-today-compare-dark.png`](mockups/png/board-today-compare-dark.png) | The same four, dark |
| [`board-today-interactions.png`](mockups/png/board-today-interactions.png) | One logging action per concept, before → after |
| [`board-today-balance-states.png`](mockups/png/board-today-balance-states.png) | Concept 2: empty, populated light/dark, interim (before Phase 2) |
| [`board-today-balance-scale.png`](mockups/png/board-today-balance-scale.png) | Concept 2: 11 habits (top and scrolled), AX3 light and dark |
| `mockups/png/screen-today-*.png` | 7 single screens |

Rebuild with `python3 design/exploration/mockups/build_today_concepts.py`.
It reuses `build.py` without modifying it, and writes only `today-*` files.

**What is drawn but does not exist yet.** A **purple dashed outline** marks
anything unimplemented, and its label names the dependency:

| Label | Dependency |
|---|---|
| `PHASE 2 · ATTENTION` | The attention engine (all attention goals, chips, pillar) |
| `NOT BUILT · NEXT-UP RULE` | A rule choosing the single "next" habit. This is **new product behavior**, not in MVP.md. |
| `NOT BUILT · SKIP ON TODAY` | The skip domain exists, but Today has no skip control |
| `NOT BUILT · UNDO TOAST` | Today, undo is tapping the filled control again |
| `PHASE 4 · COMPANION` | Companion art and the state engine |

## The three concepts

### 1 · Action-first ("Next up")

**Structure**

- A hero card holds one suggested habit, a one-line reason, and a 52pt
  primary button.
- Below it, a "Later today" list of compact rows, then a collapsed "Done · 2"
  row.
- Attention shrinks to three read-only chips.

**Interaction.** Completing the hero *advances* it to the next suggestion
(see the interactions board).

**Proposed next-up rule** (needs a product decision): recovering habits due
today first, then daily or weekday habits by sort order, then weekly habits
with remaining slots.

**Reference.** Structured's "in 15 min · Designing" widget surfaces a single
"next" item (Structured · screenshot 4, Obs-shot). No researched habit app
makes a hero of one habit.

### 2 · Habit and attention balance ("Two pillars")

**Structure**

- Two equal pillar tiles, **Habits** "2 of 5" and **Attention** "On track",
  each with one number or state.
- Then a Habits card: to-do rows plus a collapsed "Done · 2".
- Then an Attention card with type-specific controls:

| Goal type | Control |
|---|---|
| Budget | Bar plus **+5 / +15 / Other…** chips (one-tap logging) |
| Protected window | Status pill ("On track") |
| Phone-free session | Done check |

**Interaction.**

- Tapping a pillar scrolls to its section.
- A chip logs time instantly with an undo toast. The bar and the pillar
  update together, for example crossing to "Near limit" at 70%.

**Scale and degradation.**

- With many habits, the strip condenses into a sticky inline summary.
- **Before Phase 2, the Attention pillar is absent**, not a placeholder.
  The interim build is Tidewater without the companion card.

**Reference.** Habitify's type-adaptive "+1 / Log" actions and Opal's
stepper (EVIDENCE_TRACE A8). No precedent for the two-pillar IA (EVIDENCE_TRACE C1).

### 3 · Quiet companion-led

**Structure**

- No large title. A tinted band holds the companion (84pt) and a single
  sentence derived from state.
- One **offer** with Not now: "Two done. Journal keeps your rebuild going."
  plus [Log Journal].
- Then a thin metrics line, then the full habit list.

**Interaction.** After logging, the sentence and pose update, and the offer
*disappears* rather than nagging with the next one.

**Dependencies.** It relies on companion art and copy (Phase 4) and on the
same next-up rule as concept 1.

**Reference.** Finch puts the character above the goals (Finch ·
screenshots 2 and 4). This concept keeps the character at about a third of
that footprint and gives it no economy (EVIDENCE_TRACE A10).

## Comparison against Tidewater

### Measured from the mockups (393×852pt canvas)

Positions are approximate: centres of controls, read off the rendered
boards.

| Measure | Tidewater | 1 · Action-first | 2 · Balance | 3 · Companion |
|---|---|---|---|---|
| Taps to log the suggested/top habit (Journal) | 1, but it's the 3rd row (≈ y 470) | **1, hero button (≈ y 357)** | 1, 3rd row (≈ y 473) | **1, offer chip (≈ y 213)** |
| Taps to log a non-suggested habit (Read) | 1 | 1, small 30pt visual ring (44pt hit area) | 1 | 1 |
| Taps to log 5 min of social media | Opens a sheet: about 3 (tap, enter, save) | About 3: chips are read-only | **1 (+5 chip, visible above the fold, ≈ y 684)** | About 3: the clause has no control |
| Undo a completion once the toast is gone | 1 (Done rows visible) | 2 (expand Done, tap) | 2 (expand Done, tap) | 1 |
| Distinct regions above the fold | 4 | 4 | 4 | 3 |
| Attention visible without scrolling | No | Yes, glance only | Yes, with controls | One clause |
| Elements that move after logging | Row moves to Done | **Hero content swaps under the thumb** | Row collapses into Done | Sentence, offer, row order |

### Criterion by criterion

Ratings are 1–5 (5 = best) and are judgments, not validation.

| Criterion | Tidewater | 1 · Action | 2 · Balance | 3 · Companion | Basis |
|---|---|---|---|---|---|
| Logging effort | 4 | 4 | **5** | 4 | The tap counts above. Concept 2 is the only one where attention logging is 1 tap. Concept 1's hero is fast but its swap risks a mistaken second tap. |
| Scanning | 4 | 3 | 4 | 3 | Concept 1 hides the rest of the day behind the hero. Concept 3 spends about 240pt on the band before the list. Concept 2 has one predictable place per pillar. With many habits, concept 2 pushes Attention below the fold; the sticky summary is the mitigation. |
| Clarity of state and next action | 3 | **5** (next) / 3 (overall) | 4 | 4 | Concept 1 answers UX.md's first question ("What should I do now?") best but buries the rest. Concept 2 answers questions 2 and 4 at a glance. Tidewater's companion sentence is pleasant but carries no action. |
| Accessibility (AX sizes, VoiceOver, motion) | 4 | 3 | **4** | 3 | Concept 1's big button is good, but its content swap is hard to follow with VoiceOver and Reduce Motion. Concept 2's pillar tiles restack cleanly (AX3 board). Concept 3's sentence plus offer fills most of the first screen at AX3. |
| Distinctiveness | 3 | 2 | **4** | **4** | Concept 2 shows the product thesis (habits + attention, EVIDENCE_TRACE C1). Concept 3 shows the companion (C4) but sits near Finch. Concept 1 resembles a generic "next task" pattern. |
| Implementation complexity (5 = simplest) | 5 | 2 | 4 now, 3 at Phase 2 | 1 | Concept 1 needs a new next-up rule (an MVP decision plus tests) and swap motion. Concept 2's habit half is Tidewater-level; the attention half arrives with Phase 2 anyway. Concept 3 needs companion art, a copy engine and the next-up rule. |

## Recommendation

**Adopt concept 2 (Balance) as Today's information architecture, built in
Tidewater's visual system.** Call it "Tidewater Balance". It is one style,
not a mix: the same tokens, rows, cards and toast as Tidewater, with a
different arrangement.

**What changes from Tidewater**

1. The pillar strip replaces the companion status card at the top of Today.
2. Done rows collapse into "Done · N". This is the main trade-off: 2 taps to
   undo after the toast expires. Test it (see USER_TEST_TODAY task 4).
3. Attention gets type-specific inline controls: +5 / +15 / Other chips.

**What stays from Tidewater:** all row, ledger, Detail and Insights work.

**Timing**

- Ship the Habits half now. It is the "interim" frame, with no placeholder.
- The Attention pillar and section arrive with Phase 2.

**Where the companion goes.** When Phase 4 lands, it enters as one quiet
sentence at the top of the pillar strip, concept 3's *voice* without its
band or action offer. A tap opens the companion sheet. This keeps
concept 3's identity value without a second layout.

**Not adopted**

- **Concept 1's hero card.** It needs new product behavior (next-up ranking)
  that MVP.md doesn't define, swaps content under the thumb, and hides the
  rest of the day.
- **Concept 3's action offer.** Same ranking dependency, and the band costs
  the first screen at large sizes.

Revisit either one only if the user test shows people can't find their next
action in concept 2.

**Before committing.** Run [USER_TEST_TODAY.md](USER_TEST_TODAY.md). The
scores above are reasoning aids. If participants misread the pillar tiles
(for example, reading "On track" as covering habits too), or strongly prefer
the companion-led screen *and* understand it equally well, revisit before
building.

## Corrections to earlier artifacts

These are recorded here; the earlier files are preserved unchanged.

- **COMPONENT_SPEC §2 and §4.** "Avoided" is superseded by the implemented
  `HabitPolarityFormatter` ("Log success" / "Undo success"). The
  implementation's reason is that cut-down habits may mean reduction, not
  abstinence. The Insights wording "Avoided 3 of 7 nights" (VISUAL_DIRECTIONS)
  should become a "success logged" phrasing, to be decided.
- **VISUAL_DIRECTIONS fixture note.** The trend "presupposes the fix in
  UX_AUDIT Part 0 Rule 1". That fix has since landed (DATA_MODEL "Trend
  comparable-cohort rules", `isBalancedWeek`), so the Insights hero design is
  no longer blocked on it.
- **COMPONENT_SPEC §2 HabitRow (Done state).** Under the recommendation, done
  rows collapse into a group on Today. The individual done-row visual still
  applies inside the expanded group and in History.
