# Avela visual directions — A Tidewater, B Almanac, C Dusk

These are three original directions, each mocked up on the same data:

- **Today:** Saturday, October 3.
- **Weekly Insights:** the week of Sep 21–27.
- **Habit detail:** Journal, a daily habit that is mid-recovery.

The mockups are real files under [`mockups/png/`](mockups/png/). Rebuild
them with `python3 design/exploration/mockups/build.py`.

They build on the colour-only sketches in `docs/UX_AUDIT.md` Part 2. Those
sketches are revised here, not replaced:

- **Calm Sage becomes A.** It is extended with a structural point of view.
- **Indigo becomes C.** The structural change is the companion stage.
- **Terracotta is replaced by B.** B tests typography instead of hue.

In UX_AUDIT the three options differed only in colour. Here each one takes a
different position on two questions: **how present the companion is**, and
**how much Avela reads versus shows**.

| | A · Tidewater (recommended) | B · Almanac | C · Dusk |
|---|---|---|---|
| One-line | Native, calm, card-based; the companion is a status line | Editorial; Avela *writes* to you | Immersive and dark-first; the companion is a presence |
| Companion presence | Low: a 58pt glyph in a status card | Low–medium: a marginal line drawing plus a quoted sentence | High: a 124pt stage, about 30% of Today |
| Primary type | SF Pro; SF Pro Rounded for numerals | New York serif for headlines and sentences; SF Pro for controls | SF Pro; SF Pro Rounded for numerals |
| Progress primitive | Capsule pips, 14-day ledger, one bar | Dot tallies (●●○), square ledger, hairline meter | Rings everywhere |
| Completion control | Trailing 44pt circle | Leading rounded-square checkbox | Tap the whole tile; the ring fills |
| Accent (light / dark) | Tide teal `#2C6B63` / `#6EBFB1` | Moss `#4C6330` / `#A9C07E` | Indigo `#4F58C9` / periwinkle `#A4AEFF` |
| Recovery / near-limit | Amber `#9A6414` / `#E2A955` | Ochre `#9A5F14` / `#E0A85A` | Amber `#965F12` / `#F2B866` |
| Over budget (never red) | Clay `#9C5136` / `#DC8A6C` | Clay `#9A4B2E` / `#D9896A` | Clay `#A14F35` / `#EE9A7E` |

## Mockup index

| Artifact | File |
|---|---|
| A: Today, Detail, Insights (light, annotated) | [`board-A-tidewater-light.png`](mockups/png/board-A-tidewater-light.png) |
| A: same three screens, dark | [`board-A-tidewater-dark.png`](mockups/png/board-A-tidewater-dark.png) |
| A: Today at AX3 Dynamic Type, light and dark, with rules | [`board-A-tidewater-accessibility.png`](mockups/png/board-A-tidewater-accessibility.png) |
| A: component and interaction states | [`board-A-components.png`](mockups/png/board-A-components.png) |
| B: three screens light, plus Today dark and an assessment | [`board-B-almanac.png`](mockups/png/board-B-almanac.png) |
| C: three screens dark, plus Today light and an assessment | [`board-C-dusk.png`](mockups/png/board-C-dusk.png) |
| App icon concepts (all three) and Tidewater variants | [`board-app-icons.png`](mockups/png/board-app-icons.png) |
| Single phone screens, for side-by-side comparison | `mockups/png/screen-*.png` (16 files) |

**What the mockups are:**

- HTML/CSS/SVG, rendered by headless Chrome at 2× on a 393×852pt canvas
  (iPhone 18 Pro class).
- Text uses the real system fonts from macOS: SF Pro, SF Pro Rounded and New
  York.
- System chrome is drawn in the iOS 26+ Liquid Glass style: a floating
  capsule tab bar and glass toolbar buttons.

**What they are not:**

- **Not Figma.** The Figma connector needs authorization, which this session
  couldn't do.
- **Not SwiftUI.** No app code was touched.
- **Not real SF Symbols.** Icons are hand-drawn approximations, each labelled
  with the real symbol name in [`ICON_SYSTEM.md`](ICON_SYSTEM.md).
- **Not final companion art.** The companion is placeholder geometry: a
  rounded body, two ears, and an eye shape for each state.

**Future surfaces.** Anything not yet built is drawn with a dashed purple
**FUTURE** outline, so each layout reserves room for it:

- the attention budget (Phase 2),
- the weekday pattern (MVP §7 "where enough data exists"),
- the attention summary in Insights.

## Shared fixture

The same numbers appear in every direction, so a reviewer compares only
design, not data. All values follow the documented rules:

- **Journal, last 14 days (Sep 20 – Oct 3):**
  - 10 done, 2 missed (Wed Sep 23, Wed Sep 30), 1 skipped (Sat Sep 26).
  - Today is still open.
  - Consistency: 10 of 12 resolved days = **83%**. The skip and today are
    excluded (DATA_MODEL "Skips are excused" and "the still-open current
    period is never a miss").
  - Current streak 2 days; recovering, 2 of 3 good days (the 3-success
    threshold).
- **Week of Sep 21–27:**

  | Habit | Result | Consistency |
  |---|---|---|
  | Walk | 7 of 7 days | 100% |
  | Read | 3 of 3 sessions | 100% |
  | Water | 6 of 7 days | 86% |
  | Journal | 5 of 6 days (1 skip excused) | 83% |
  | No phone in bed | 3 of 7 nights | 43% |

  - Overall = mean of the per-habit percentages = **82%** (the confirmed
    denominator rule).
  - "Went well" names *both* Walk and Read, because they tie and the tie
    rule says to name every tied habit.
  - "Needs recovery" is the lowest habit among those with a miss.
  - The trend is shown in points and labels the cohort ("same 5 habits on
    unchanged schedules"). This presupposes the fix in UX_AUDIT Part 0
    Rule 1.

## Direction A — Tidewater (recommended)

**Idea:** still water. It is the most native of the three and adds only
three things to iOS: warm paper neutrals, one deep teal accent, and a
companion that speaks in a single sentence.

- **Hierarchy (Today).** Rows, top to bottom:
  1. date eyebrow,
  2. large title,
  3. companion status card (state sentence plus one supporting metric),
  4. **To do** card,
  5. **Done** card,
  6. Attention card (future).

  This follows UX.md's priority order (what to do now → how today is going
  → what needs recovery → attention state). It also fills the empty space
  noted in UX_AUDIT F1 with the companion, as F1 suggested, instead of an ad
  hoc summary.
- **Habit detail.** The **recovery card comes first** when recovery is
  active. It shows 3 pips toward the documented threshold, then two stat
  tiles (streak, consistency), then the 14-day ledger, then navigation
  rows. Best streak is a footnote, so it never competes with the current
  run.
- **Insights.** One hero number, then *Went well*, *Needs recovery* and one
  observation, then the attention budget. This is UX.md's weekly-review
  order, minus anything that needs data the app doesn't have.
- **Colour logic.** Teal means *done / healthy*, amber means *recovering /
  near limit*, clay means *over budget*. There is no red anywhere, and no
  state relies on hue alone (see the Contrast section below).
- **Dark mode.** Elevation comes from surface lightness, not shadow. The
  accent lightens, and the ink on the accent fill flips to dark.
- **Large type.** At accessibility sizes, rows restack vertically and the
  completion control becomes a full-width labelled button. See the
  accessibility board and COMPONENT_SPEC §6.

**Why recommended:**

1. It has the strongest fit with VISION ("calm, not punitive"), UX.md ("one
   primary state, one next action") and DESIGN_SYSTEM ("native-feeling
   controls").
2. It is the lowest-risk build. It is the current SwiftUI structure plus
   tokens and three new components.
3. It scales: it works with 2 habits or 12, and from xSmall to AX5.
4. The companion's small footprint keeps it honest. It earns its space by
   reporting real state, and that space can grow later (a tap opens a
   companion sheet) without a redesign.

**Weaknesses:**

- It is the least distinctive at a glance; a warm-neutral native app can
  read as "tasteful default".
- Its distinctiveness has to come from the app icon, the companion art, and
  the writing voice. That is why the plan borrows B's sentence-style
  Insights copy.

## Direction B — Almanac

**Idea:** a dated page in a journal. New York serif headlines and quoted
companion lines, hairline lists, Things-style leading checkboxes, and
Insights written as short paragraphs.

- **Strongest at** voice and calm. Insights reads like a note, not a report,
  which matches UX.md's "should read like a useful summary, not a
  spreadsheet" most literally.
- **Risks:**
  - The serif headlines and Liquid Glass chrome can look like two different
    design languages.
  - Long serif paragraphs get very tall at AX5.
  - A text-first list is slower to scan with many habits.
  - Suggestion copy ("a gentler target?") needs governance to stay
    non-prescriptive.
- **Keep:** the written Insights sentences, and the dot tallies as a
  text-equivalent of progress at large sizes.

## Direction C — Dusk

**Idea:** the companion is a lit presence. A dark-first stage, ring tiles,
and mint for done.

- **Strongest at:** emotional engagement and future system surfaces. A
  glowing creature on the Lock Screen widget or in a phone-free Live
  Activity reads instantly.
- **Risks:**
  - It is closest to Finch and to the visual language of activity rings.
  - The stage costs about 250pt of the first screen.
  - The light mode is weak.
  - Rings can imply "incomplete = failing".
  - It needs the most Reduce Motion and Reduce Transparency work.
  - It is the closest of the three to a "pet with thin utility"
    (APPLE_COMPLIANCE).
- **Keep for later:** the stage, as a *companion detail sheet*, and the
  halo colour as state for widgets.

## Scoring

Scores are 1–5, where 5 is best. Each criterion is taken from Avela's own
docs.

| Criterion (source) | A | B | C |
|---|---|---|---|
| Calm, non-punitive (VISION) | 5 | 5 | 3 |
| One state, one next action (UX.md) | 5 | 4 | 3 |
| Native feel, Liquid Glass coherence (DESIGN_SYSTEM) | 5 | 3 | 4 |
| Dynamic Type at AX sizes (UX.md accessibility) | 5 | 3 | 2 |
| Light and dark parity | 5 | 4 | 2 |
| Distinctiveness, "not a reskinned template" (APPLE_COMPLIANCE) | 3 | 4 | 5 |
| Companion as a stateful layer without dependency (DESIGN_SYSTEM) | 4 | 4 | 3 |
| Readiness for widgets and Live Activity | 4 | 3 | 5 |
| Implementation risk (inverted; 5 = lowest) | 5 | 3 | 2 |
| **Total** | **41** | **33** | **29** |

**Recommendation: A (Tidewater), with two borrowed elements:**

- from B, sentence-style Insights copy;
- from C, the halo-as-state treatment for future widgets and the companion
  sheet.

## Token proposal (Direction A)

These would become colour assets in a future slice. They are not added now.

| Token | Light | Dark | Use |
|---|---|---|---|
| `background` | `#F5F3EE` | `#0F1312` | Screen background (warm paper, not pure white or black) |
| `surface` | `#FFFFFF` | `#191F1D` | Cards |
| `surfaceSecondary` | `#EEEBE4` | `#222A27` | Tracks, skipped fill, selected tab |
| `ink` | `#1D2321` | `#ECEFEC` | Primary text |
| `inkSecondary` | `#56605C` | `#A8B2AD` | Context text |
| `inkTertiary` | `#636C67` | `#78837E` | Eyebrows, legends |
| `accent` (AccentColor) | `#2C6B63` | `#6EBFB1` | Done, healthy, links, selected |
| `onAccent` | `#FFFFFF` | `#0B1F1C` | Checkmark on a filled control |
| `accentSoft` | `#DCEAE5` | `#1E3834` | Icon tiles, trend chip |
| `recovery` | `#9A6414` | `#E2A955` | Recovering, near-limit (attention 70–99%) |
| `overBudget` | `#9C5136` | `#DC8A6C` | Attention ≥100%, overloaded companion |
| `celebrate` | `#B48A1E` | `#E0C060` | Celebrating companion only |

Each token needs an Increase Contrast variant. Implementation should start
by darkening `inkTertiary` and `accent` one step in light mode, then
re-measure.

### Contrast (measured)

Values are WCAG 2.x relative-luminance ratios computed from the hex tokens
by a script during this pass. HIG targets are 4.5:1 for text up to 17pt and
3:1 for larger or bold text.

| Pair | A light | A dark | B light | B dark | C light | C dark |
|---|---|---|---|---|---|---|
| ink / background | 14.4 | 16.2 | 15.9 | 15.1 | 15.0 | 16.9 |
| inkSecondary / surface | 6.5 | 7.7 | 7.0 | 7.6 | 6.9 | 8.4 |
| inkTertiary / surface | 5.4 | 4.3 † | 4.9 | 4.2 † | 4.9 | 4.6 |
| inkTertiary / background | 4.9 | 4.8 | 4.7 | 4.6 | 4.4 † | 5.1 |
| accent / surface | 6.2 | 7.8 | 6.6 | 8.6 | 5.9 | 8.3 |
| onAccent / accent | 6.2 | 7.9 | 6.7 | 8.3 | 5.9 | 8.8 |
| recovery / surface | 5.0 | 8.0 | 5.1 | 8.1 | 5.3 | 9.7 |
| overBudget / surface | 5.8 | 6.3 | 6.0 | 6.3 | 5.7 | 7.8 |

**Notes on these figures:**

- **† Below 4.5:1.** Dark `inkTertiary` on `surface` (A and B) and C's light
  `inkTertiary` on `background` fall below 4.5:1. Either restrict them to
  text of 15pt semibold or larger (legends, eyebrows), or lighten or darken
  them one step. This is listed as an open item.
- **Light `inkTertiary`** was darkened during this pass after an initial
  measurement of 3.3–3.5:1.
- **All values are final.** Every figure above was recomputed from the
  final tokens in `mockups/build.py`.

## Open questions for review

1. Is Tidewater's restraint the right brand bet, or should distinctiveness
   be pulled forward? If so, prototype B's serif headlines on Insights only.
2. Which companion species? The silhouette is deliberately unspecific. See
   ICON_SYSTEM §4 for the requirements a species must meet.
3. Should Today split "To do" and "Done", or keep a single sorted list?
   Splitting makes the next action obvious, but rows move on completion,
   which needs the motion rules in COMPONENT_SPEC §3.
4. Should the 14-day ledger align to weeks (Sun–Sat rows, as mocked)? If so,
   the detail screen's "Last 14 days" window should be documented as
   week-aligned. DATA_MODEL currently defines it as the 14 most recent days,
   which only lines up with the grid on a Saturday.
