# Tidewater Balance — interactive Today prototype

This is a **design artifact.** It is a standalone browser prototype of the
Today screen recommended in [`../TODAY_CONCEPTS.md`](../TODAY_CONCEPTS.md),
together with habit detail. **Avela remains a native SwiftUI app.** This code
is not production code, is not part of the Xcode project, and must not be
ported line by line.

> **What a browser can't tell you:** native VoiceOver, Dynamic Type, haptics
> or SwiftUI rendering. The text sizes approximate the HIG Dynamic Type
> table. Haptics are only *described* in the event log. ARIA labels
> approximate VoiceOver wording, but browser screen readers behave
> differently from VoiceOver on iOS. Liquid Glass is imitated with CSS
> blur. Verify all of these on a device once the native redesign exists.

## Launch

No build step, no server, no network, no dependencies.

```sh
open design/exploration/prototype/index.html
```

You can also double-click `index.html`. It has been tested in desktop Chrome.
It uses only standard HTML, CSS and JavaScript (classic scripts, so `file://`
works), and should run in current Safari too.

For touch testing on a phone, serve the folder from your Mac on the local
network and open it in mobile Safari:

```sh
python3 -m http.server 8000 --directory design/exploration/prototype
```

Remember to stop the server afterwards.

### Preset links

Add these query parameters to `index.html`. The **Copy link to this setup**
button in the panel does the same.

| Parameter | Values | Default |
|---|---|---|
| `state` | `empty`, `populated`, `many` | `populated` |
| `theme` | `light`, `dark` | follows system |
| `text` | `default` (body 17), `xl` (xxxLarge, body 23), `ax3` (body 40, stacked) | `default` |
| `motion` | `system`, `reduce`, `full` | `system` |
| `regroup` | `deferred`, `immediate` | `deferred` |
| `guard` | `off` to disable the repeat-tap guard | on |
| `deferred` | `show` to outline future Attention and companion surfaces | hidden |
| `symbols` | `show` to label every icon with its intended SF Symbol name | hidden |

Example: `index.html?state=many&theme=dark&text=ax3&motion=reduce`

## What is prototyped

| Feature | Behaviour |
|---|---|
| Completion and undo | One tap on the trailing control. An undo toast appears for 5 s; tapping the filled control again also undoes. |
| To do / Done grouping | Done rows collapse into "Done · N". The group expands and collapses (`aria-expanded`). |
| Habit detail | The row body pushes detail (it slides in, or cross-fades under Reduce Motion). Detail is **read-only** for today's status, as in the app. Back, Escape or the Today tab returns. |
| States | Empty, populated (5 habits), many (11 habits). |
| Appearance | Light and dark, using Tidewater tokens. |
| Text sizes | Default, xxxLarge, and AX3 with the stacked row layout and a full-width labelled button. |
| Motion | Follows the system's Reduce Motion setting, or can be forced either way. |

**Not prototyped.** These show a purple "Not prototyped" note rather than
doing nothing:

- Add / Create a habit
- Edit
- View history
- Archive
- The Insights, History and Settings tabs

**Deferred:**

- **Attention (Phase 2) and the companion (Phase 4)** are hidden by default.
  The `deferred=show` setting draws them as dashed, non-interactive outlines
  for context only.
- **Skip on Today** is not shown at all, because Today has no skip UI.

## Sample data

Every value is **sample data**, labelled under the phone frame:

- **Date:** Saturday, October 3, 9:41 AM.
- **Habits:** the same five as in TODAY_CONCEPTS, plus six more in the many
  state. They are defined in [`data.js`](data.js) as 14-day ledgers.

Streaks, recovery ("Rebuilding · 2 of 3 good days") and weekly counts are
recomputed live with **simplified versions** of the rules in
`docs/DATA_MODEL.md`, so logging Journal really ends its recovery, and
logging Read really meets its weekly goal. This is not a port of
`HabitProgressCalculator`.

Completion wording mirrors the implemented `HabitPolarityFormatter`:

| Polarity | Labels |
|---|---|
| Build up | "Mark X complete" / "Undo completion for X" |
| Cut down | "Log success for X" / "Undo success for X" |

Nothing is saved. Reload, or use **Reset sample data**.

## Interaction risks and what the prototype does about each

| Risk | Mitigation in the prototype | How to observe it |
|---|---|---|
| **Rows moving under the pointer** | **Deferred regroup.** A completed row stays where it is ("· moving to Done") until there has been **1.8 s with no pointer or key activity in the list**, *and* any mouse pointer has left the list. Only then does it move. Rows animate (FLIP) unless Reduce Motion is on. | Complete two habits in a row quickly; neither shifts. Switch to **Immediate regroup** to feel the risky baseline, where the next row slides under your cursor. |
| **Accidental double completion** | **Repeat-tap guard.** A second tap on the same control within 600 ms is ignored, and the control flashes purple. Because rows don't move while you're tapping, a fast second tap can't land on a *different* habit. | Double-click a control. The log says "Repeat tap … ignored". Turn the guard off to compare. |
| **Undo discoverability** | Two paths: (1) the toast's **Undo** button (5 s, paused while hovered or focused, 44 pt tall); (2) tapping the filled control again, in To do while settling or in the expanded Done group. When the toast expires, the log says where undo still lives. | Complete a habit, wait for the toast to expire, then try to undo it. That's usability-script task 3. |
| **Focus preservation** | The toast never takes focus; it is announced through a polite live region. If the focused row moves to a *visible* place, focus stays on it. If it moves into the *collapsed* Done group, focus goes to the "Done · N" toggle and the move is announced. Undo from the toast returns focus to that habit's control. Opening detail focuses its title; Back restores focus to the row you came from. | Use only the keyboard (Tab, Space, Enter, Escape). Watch the focus ring and the event log. |
| **Feedback covering controls** | The toast sits above the tab bar. While it is open, the list gets extra bottom padding. If the control you just used would be under the toast, the list scrolls it clear. At AX3 the toast wraps to two lines and its Undo button grows. | Many state: scroll to the bottom and complete the last to-do habit. |

## Files

| File | Purpose |
|---|---|
| `index.html` | Page shell: phone frame and reviewer panel |
| `styles.css` | Tidewater tokens, text-size classes, Reduce Motion rules |
| `app.js` | State, rendering, regroup and guard logic, focus handling, event log |
| `data.js` | Labelled sample data |
| `icons.js` | Local SVG approximations, keyed by intended SF Symbol name |
| [`USABILITY_SCRIPT.md`](USABILITY_SCRIPT.md) | Short moderated test script |

## How it was checked

A scripted run in headless Chrome passed 27 of 27 checks. The run used a
throwaway copy of these files outside the repo, with an injected test script
and virtual time. It confirmed that:

- a row stays in place while settling, then regroups;
- a repeat tap within 600 ms is ignored;
- the toast doesn't steal focus;
- focus moves to the Done toggle when its row is hidden;
- toast Undo restores the row and returns focus to it;
- Journal's recovery ends on the third good day;
- the weekly goal-met copy appears;
- cut-down labels match `HabitPolarityFormatter`;
- detail focus and back-focus restoration work;
- immediate mode moves rows at once;
- the many and empty states render.

Visual checks were screenshots of: default, AX3 in dark, many-habit,
mid-settle with the toast, and detail. The phone-width layout was also
rendered at a true 393 px width inside an iframe; it fills the viewport and
all controls are visible.

**Not checked:**

- mobile Safari on a real device;
- browser screen readers;
- touch timing.

## Known prototype limits

- **Touch hover.** Touch has no hover, so on phones the "pointer has left
  the list" condition doesn't apply. The 1.8 s quiet period still does.
- **Simplified progress rules.** History beyond 14 days isn't modelled: "Best
  streak" uses a value from the sample data.
- **No persistence.** Nothing is saved, there is no date change, and there
  are no reminders.
- **No real data.** The prototype doesn't read anything from the app.
