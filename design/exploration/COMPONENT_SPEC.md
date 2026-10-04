# Component and interaction specification — Direction A (Tidewater)

This spec is the bridge from the mockups to SwiftUI. It is a proposal: none
of it is implemented. Component names follow `docs/DESIGN_SYSTEM.md`'s list
and UX_AUDIT Part 4's inventory.

The rendered states are on [`board-A-components.png`](mockups/png/board-A-components.png).

**Platform citations used throughout:**

- [Materials](https://developer.apple.com/design/human-interface-guidelines/materials):
  Liquid Glass is for the navigation and control layer; "don't use Liquid
  Glass in the content layer".
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility):
  44×44pt is the default control size and 28×28pt the minimum. **Avela
  adopts 44pt as its own floor.**
- [Typography](https://developer.apple.com/design/human-interface-guidelines/typography):
  Dynamic Type body sizes are 17pt at the default Large setting, and 28, 33,
  40, 47 and 53pt at AX1–AX5.
- [Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics):
  "Avoid overusing haptics", "Make haptics optional".

## 1. Layout foundations

| Token | Value | Notes |
|---|---|---|
| Screen margin | 16pt | System default list inset |
| Card radius | 22pt continuous | `RoundedRectangle(cornerRadius: 22, style: .continuous)` |
| Icon tile | 40pt square, 12pt radius | `@ScaledMetric(relativeTo: .body)` |
| Row min height | 68pt | Grows with type; never fixed |
| Row separator | 0.5pt `separator`, inset to the text column (66pt) | |
| Section header | `.subheadline.weight(.semibold)`, `inkSecondary`, 20pt above, 8pt below | Trailing count in `inkTertiary` |
| Card shadow (light only) | 0/1/2 @5% + 0/6/18 @5% | None in dark mode; elevation comes from the surface colour |

**Type roles.** Use only system text styles:

| Role | Style |
|---|---|
| Large title | `.largeTitle.bold()` |
| Row title | `.body.weight(.semibold)` |
| Row context | `.subheadline` |
| Eyebrow | `.footnote.weight(.semibold).uppercase`, tracked 0.04em |
| Hero numeral | `.system(size: 56, weight: .bold, design: .rounded)` scaled with `@ScaledMetric(relativeTo: .largeTitle)`, capped at about 1.6× |
| Stat numeral | `.title.bold()` with `design: .rounded` |
| All numerals | `.monospacedDigit()` |

**Layers**

- The tab bar, toolbar buttons and week navigator are system Liquid Glass
  components.
- Cards are opaque `surface`.
- No custom glass anywhere.

## 2. Components

### CompanionStatusCard (Today)

**Content**

- `CompanionView` at 58pt, plus a headline sentence and a context line.
- The headline comes from a pure `CompanionMessage` function of
  `CompanionState` plus today's counts. That keeps it testable, matching
  TESTING.md's "companion-state derivation".

**States.** The six `CompanionState` values, plus `companionDisabled`
(Settings `companionEnabled = false`). When disabled, the card becomes a
plain "2 of 5 done" summary line.

**Copy rules**

- One sentence of state, then at most one supporting metric.
- No exclamation marks except for `celebrating`.

**Interaction**

- **Before V1 Phase 4:** not tappable. No dead buttons (APPLE_COMPLIANCE).
- **Later:** opens the companion sheet.

**VoiceOver.** One element, label "Companion, calm. A steady morning. 2 of 5
done."

### HabitRow (Today)

**Anatomy**

1. Icon tile.
2. Title.
3. Context line, with an optional leading progress glyph.
4. Trailing completion control: 44×44pt hit area, 44pt visual.

**Context-line variants.** Choose by schedule and recovery state:

| Case | Example |
|---|---|
| `daily` / `weekdays` | "Every day · 4-day streak" (the streak unit comes from `StreakResult.unit`) |
| `timesPerWeek` | Capsule pips (filled = distinct days done this week) plus "2 of 3 this week" |
| Recovering | `arrow.clockwise` in recovery tint, plus "Rebuilding · 2 of 3 good days" |
| Avoidance, done | "Cut down · avoided last night"; "Avoided" replaces "Done" (UX_AUDIT F2) |
| Skipped | Neutral fill with `forward.end`, plus "Skipped today · {reason}" |

**States.** The rendered states on the components board:

| # | State | Visual |
|---|---|---|
| 1 | Default | Hollow 2.5pt ring, `inkTertiary` |
| 2 | Pressed | Accent ring with `accentSoft` fill, scaled to 0.92 |
| 3 | Done | Accent fill with an `onAccent` checkmark. Title moves to `inkSecondary`; no strikethrough, which hurts legibility and reads as "crossed out". |
| 4 | Undo toast | See UndoToast below |
| 5 | Skipped | `surfaceSecondary` fill with the skip glyph |
| 6 | Avoidance, pending | Default ring; context text says what is being confirmed |

**Tap targets.** The row body and the control are **sibling** hit targets:

- The row body pushes `HabitDetailView`. This preserves the
  NavigationLink/Button sibling structure documented in DATA_MODEL "Phase 1
  habit lifecycle UI".
- The control only toggles completion.

**Context menu (long press)**

- Skip today…
- Open details
- Edit habit
- Undo completion (only when done)

### UndoToast

**Appearance**

- Inverted capsule (`ink` background, `background` text), 52pt tall.
- Floats 12pt above the tab bar.
- Content: "{Habit} done" (or "{Habit} avoided"), plus an **Undo** button.

**Lifetime**

- Visible for 4 seconds, and stays while VoiceOver focus is on it.
- A new completion replaces the current toast; toasts never stack.

**Relation to the row control.** Undo also stays available on the row
itself, because tapping a done control undoes it. The toast is a
convenience, not the only path (MVP §3: "Undo is available immediately").

**Accessibility.** Post `AccessibilityNotification.Announcement("Drink water
done. Undo available.")`.

### ProgressPips (weekly)

- Size: target capsules of 18×6pt, with 3pt gaps.
- More than 7 targets: switch to text only.
- Extra completions beyond the target are shown in text ("4 this week · goal
  met"), never as overflowing pips (MVP §2: "Additional completions remain
  visible").
- At accessibility sizes the pips are hidden, and the text carries the
  meaning.

### DayLedger (14-day)

**Layout**

- 2 rows × 7 columns, week-aligned, with day-letter headers.
- Cells are 34pt circles with 7pt gaps.
- A legend sits below.

**Cell states.** The states differ by shape, not only colour:

| State | Visual |
|---|---|
| Done | Accent fill, check |
| Missed | Hollow `inkTertiary` ring at 70% opacity |
| Skipped | `surfaceSecondary` fill, skip glyph |
| Open today | Dashed accent ring |
| Before the habit existed, or archived | Blank |

**VoiceOver**

- The ledger is one element, with a summary: "Last 14 days: 10 done, 2
  missed, 1 skipped, today open."
- An adjustable action steps through the days.

### RecoveryCard (Habit detail)

**When it shows.** Only while `RecoveryProgress.isRecovering` is true. It
disappears silently when recovery ends; there is no "fully recovered"
banner, matching current behaviour.

**Content**

- Eyebrow "REBUILDING MOMENTUM" in recovery tint.
- Sentence: "{n} good days since your miss on {weekday}."
- Next step: "One more and you're back on a steady run."
- Three threshold pips.

**Wording rules**

- Use the weekday name for misses within the last 7 days, otherwise a short
  date.
- Never "streak broken".

### StatTile

- Label, a rounded numeral with its unit, and a footnote.
- At most two tiles per row; they stack vertically at AX sizes.

### InsightsHeroCard

**Content**

- Overall percentage.
- An "average consistency across N habits" caption.
- Trend chip: an arrow plus "{n} points vs. {prior week}".
- A cohort note: "Compared across the same N habits on unchanged schedules."

**States**

| State | Display |
|---|---|
| Populated | As above |
| Trend unavailable | No chip; the line reads "Not enough data from the prior week to compare." |
| Balanced week, all habits identical (UX_AUDIT Part 0 Rule 2) | One sentence replaces both callout sections: "All 3 habits were equally consistent this week (82%)." |
| Insufficient data | Existing ContentUnavailableView |
| No habits | Existing ContentUnavailableView |

**Trend direction**

- Down: `arrow.down.right` and "points lower", in `inkSecondary`.
- Flat: "Same as the prior week".

### InsightResultRow

- Icon tile, name, factual context, and a trailing percentage.
- Avoidance copy reads "Avoided 3 of 7 nights".
- The "Needs recovery" percentage uses the recovery tint. It is never the
  only cue, because the section header carries the meaning.

### AttentionBudgetCard (future, Phase 2)

**Content**

- Hourglass tile, name, and "18 / 30 min" as a rounded numeral.
- A 6pt bar.
- A trailing "Log" action, added when manual entry exists.

**Thresholds.** Taken from UX.md and centralized:

| Range | Label | Colour |
|---|---|---|
| < 70% | Healthy | Accent |
| 70–99% | Near limit | Recovery |
| ≥ 100% | Over budget | overBudget clay |

**Text label.** The bar always comes with the text state ("Near limit")
under VoiceOver and at AX sizes. No red, no shake, no badge count.

## 3. Interaction and motion

| Event | Motion | Haptic | Reduce Motion |
|---|---|---|---|
| Press completion control | Scale to 0.92 over 0.12s, spring back | None on touch-down | No scale; opacity 0.7 |
| Commit completion | Ring fills; `.symbolEffect(.replace)` circle → checkmark; 0.25s | `.sensoryFeedback(.success, trigger:)` once | Instant swap, same haptic |
| Row moves "To do" → "Done" | After 0.6s, matched-geometry move; list animates | None | Cross-fade, no travel |
| Undo | Reverse the replace effect; the row returns to To do | `.sensoryFeedback(.impact(weight: .light))` | Instant |
| Skip | Control cross-fades to the skip glyph | None | Same |
| Weekly target met (3rd of 3) | One `.bounce` on the last pip | `.success` (replaces the completion haptic, not added to it) | No bounce |
| Recovery ends (3rd success) | Recovery card collapses on the next detail visit; no celebration | None | Same |
| Companion state change | Pose cross-fade over 0.35s | None | Instant |
| Celebrating | One gesture, ≤1.2s, then back to calm | Part of the commit haptic | Static celebrating pose |

**Rules**

- At most one haptic per user action.
- Respect the `hapticsEnabled` setting (DATA_MODEL Settings).
- Never play a haptic for a passive state change, such as an attention
  threshold crossed while the app is in the background.
- Haptics come only from `sensoryFeedback`, an iOS 17+ SwiftUI API, with no
  custom engine.

## 4. Copy patterns

This consolidates UX_AUDIT F7 ("four different nothing-yet phrasings").

| Situation | Pattern |
|---|---|
| No data yet, any metric | "Not enough data yet" |
| No current streak | "Starts with your next check-in" |
| Missed (in History or the ledger) | "Missed" (neutral verb; never "Failed") |
| Skip | "Skipped · {reason}" |
| Recovery | "Rebuilding · {n} of 3 good days" |
| Avoidance success | "Avoided" |
| Over budget | "Over today's budget by {n} min" (never "exceeded" in a headline) |

## 5. Archive confirmation (UX_AUDIT F9)

Whatever the cause of the missing Cancel turns out to be, the spec is:

- The dialog states the consequence ("Archived habits disappear from Today.
  History is kept, and you can reactivate anytime from Settings.").
- **Archive** button.
- **Cancel** button, visible.

If the system popover presentation hides Cancel, present the dialog from a
toolbar menu item rather than an inline List row.

## 6. Dynamic Type and accessibility behaviour

| Size range | HabitRow | Stat tiles | Insights hero | Companion card |
|---|---|---|---|---|
| xSmall–xxxLarge | Horizontal row | 2 per row | 56pt numeral | Horizontal |
| AX1–AX2 | Horizontal; context wraps; pips become text | 1 per row | Capped numeral | Glyph above text |
| AX3–AX5 | **Stacked**: icon, title, context, then a full-width 64pt "Mark done" button | 1 per row | Capped numeral; caption below | Glyph above text; context line dropped |

**Implementation**

- Branch on `@Environment(\.dynamicTypeSize).isAccessibilitySize`, with
  `ViewThatFits` as a safety net.
- Scale every fixed dimension with `@ScaledMetric`.
- Never truncate habit names. Set `.lineLimit(nil)` and remove any
  `.lineLimit(1)` at AX sizes.

**VoiceOver**

- Each HabitRow is one element, with
  `.accessibilityElement(children: .combine)` on the body.
- Label: "{name}, {context}". Value: "done" or "not done".
- Custom actions: Mark done / Undo, Skip, Open details.
- Existing accessibility identifiers are kept for UI tests.

**Other settings**

- **Increase Contrast:** use the `inkTertiary` and accent contrast variants
  from the token table, and ring stroke 3pt.
- **Reduce Transparency:** system glass handles itself. The custom toast is
  already opaque.
- **Bold Text:** verify the rounded numerals don't overflow tiles.

**Verification still owed** (UX_AUDIT F17): a device pass at AX5, with
Accessibility Inspector, in both appearances. None of this has been checked
on a device.

## 7. Future surfaces (context, not V1 scope changes)

**Widgets (MVP §9)**

- **Small:** companion glyph plus "2 of 5".
- **Medium:** three next habits, with interactive completion via App
  Intents. Verify the API availability for the deployment target.
- **Accessory (Lock Screen):** monochrome companion silhouette plus a count.

Widgets must not show habit names on the Lock Screen by default ("does not
expose sensitive details unnecessarily").

**Live Activity (MVP §10)**

- Only for a user-started phone-free or focus session with an end time (HIG:
  "defined beginning and end… don't exceed eight hours").
- Shows the time remaining and a static companion `focused` pose.
- No looping animation, and nothing after the session ends.

**Companion sheet**

- Opened from the status card in Phase 4.
- It is the right home for Direction C's "stage" treatment.
