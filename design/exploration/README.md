# design/exploration — competitive research and visual-direction proposals

Status: **proposal for review**. Created 2026-10-03.

Nothing in this folder is wired into the app:

- No app code, tests, project configuration or existing docs were changed.
- No dependencies were added.
- Nothing was committed.

App code was treated as read-only and may have changed since this was
written.

## Contents

| File | What it is |
|---|---|
| [COMPETITIVE_RESEARCH.md](COMPETITIVE_RESEARCH.md) | Sourced comparison of Streaks, Habitify, Opal, Finch, Structured and Things 3, plus annotated references, popularity evidence and lessons for Avela. Observed facts are kept separate from inference. |
| [VISUAL_DIRECTIONS.md](VISUAL_DIRECTIONS.md) | The three directions (A Tidewater, B Almanac, C Dusk), the shared fixture, scoring, a token proposal with measured contrast, and open questions |
| [ICON_SYSTEM.md](ICON_SYSTEM.md) | Curated SF Symbols for functional UI, plus app-icon and companion/brand-art requirements |
| [COMPONENT_SPEC.md](COMPONENT_SPEC.md) | Components, states, motion, haptics, copy, Dynamic Type and VoiceOver behaviour for Direction A |
| [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) | Phased recommendation, R0–R4 |
| [mockups/png/](mockups/png/) | Rendered mockups: 7 annotated boards and 16 single screens |
| [mockups/html/](mockups/html/) | The HTML each PNG was rendered from |
| [mockups/build.py](mockups/build.py) | Generator for all mockups (Python 3 plus local Google Chrome) |

**Start with:**

1. `mockups/png/board-A-tidewater-light.png`, the recommended direction.
2. Its dark and accessibility boards.
3. The B and C boards, for comparison.

## Rebuilding the mockups

```sh
python3 design/exploration/mockups/build.py          # HTML + PNG
python3 design/exploration/mockups/build.py --html   # HTML only
```

**Requirements**

- macOS, because fonts load from `/System/Library/Fonts`. Fonts are never
  copied into the repo.
- Google Chrome at the default `/Applications` path, used headless.

## Honesty notes

- **Not Figma.** The Figma connector needs authorization, which wasn't
  available in this non-interactive session. The mockups are standalone
  HTML/SVG rendered to PNG.
- **Icons are approximations.** They are hand-drawn SVG approximations of SF
  Symbols, labelled by real symbol name in ICON_SYSTEM.md.
- **The companion is placeholder geometry.** App icons are concept sketches,
  not deliverable art.
- **Competitor screenshots are not committed.** They were viewed from the
  live App Store listings and described in text, with links to the listings.
- **Dashed "FUTURE" outlines** mark attention and weekday-pattern surfaces
  that aren't built yet.
- **Nothing was tested on a device.** No simulator or device verification
  was done, by instruction. Accessibility behaviour is specified, not
  verified.

## Round 2: Today concepts and evidence trace (added 2026-10-03)

Round 1 files above are unchanged. Round 2 added only new files:

| File | What it is |
|---|---|
| [EVIDENCE_TRACE.md](EVIDENCE_TRACE.md) | Each recommendation traced to specific competitor screens and docs. Observation is kept separate from inference; recommendations with no competitor evidence are listed separately; Avela's distinct points are summarized. |
| [TODAY_CONCEPTS.md](TODAY_CONCEPTS.md) | Action-first, Balance and Quiet-companion Today concepts compared with Tidewater on six criteria, plus the recommendation (Tidewater Balance) and corrections to round 1 |
| [USER_TEST_TODAY.md](USER_TEST_TODAY.md) | A short side-by-side comprehension and preference test, with decision rules |
| `mockups/build_today_concepts.py` | Generator for round 2. It imports `build.py` without changing it. |
| `mockups/png/board-today-*.png` | 5 boards: comparison light and dark, interactions, Balance states, Balance scale |
| `mockups/png/screen-today-*.png` | 7 single screens, with "not built" labels |
| `mockups/png/today-test-*.png` | 6 untagged test stimuli |

**Start with:** `board-today-compare-light.png`, then
`board-today-interactions.png`.

## Round 3: interactive prototype (added 2026-10-03)

[`prototype/`](prototype/) is a standalone browser prototype of Tidewater
Balance's Today and habit detail. It has no dependencies; open
`prototype/index.html` to run it. Its README covers launch, presets, the
interaction-risk mitigations and its limits, and
[`prototype/USABILITY_SCRIPT.md`](prototype/USABILITY_SCRIPT.md) has the
test script.

This is a design artifact only. It does not validate native VoiceOver,
Dynamic Type, haptics or SwiftUI rendering. Round 1 and 2 files are
unchanged.

## Round 4: Vivid Tidewater variant (added 2026-10-03)

[`prototype-vivid/`](prototype-vivid/) is a colour and emphasis variant of
the Balance prototype. It reuses that prototype's markup, scripts and data
unchanged, and adds one override stylesheet. Open
`prototype-vivid/compare.html` to see the two side by side; its README
explains what each change is for.

The change list, measured contrast ([`prototype-vivid/CONTRAST.md`](prototype-vivid/CONTRAST.md):
Balance 5 failures, Vivid 0), and before/after completion renders in light
and dark are all in that folder. It makes no claim that colour affects
adherence. The `prototype/` folder and earlier rounds are unchanged.
