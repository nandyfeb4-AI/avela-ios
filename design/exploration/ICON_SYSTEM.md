# Avela icon system — functional SF Symbols, app icon, brand art

This document has two halves that follow different rules:

1. **Functional UI icons are SF Symbols only.** Use them through
   `Image(systemName:)`. Don't draw custom glyphs where a symbol exists.
2. **The app icon, companion and brand art are original artwork only.** They
   contain no SF Symbols and nothing confusingly similar to one.

The split is required by Apple's own terms. The HIG SF Symbols page warns
about "the prohibition against using symbols — or images that are
confusingly similar — in app icons, logos, or any other trademarked use"
([HIG: SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols)).

The mockups in `mockups/` use **hand-drawn approximations** of the symbols
named below, because the SF Symbols app isn't installed in this environment.
Before implementation, check every name against the current SF Symbols app.
Apple's pages disagree on its version: the WWDC26 guide says "SF Symbols 8",
while Design Resources ships "SF Symbols 27". Pick symbols that exist at the
app's deployment target.

## 1. Rules for functional symbols

**Rendering**

- **Default to Monochrome**, tinted with semantic tokens: `accent`,
  `inkSecondary`, `recovery`.
- **Hierarchical** is allowed for state glyphs only, such as the companion
  sheet header and empty states.
- **Avoid Multicolor and Palette** in core UI: they bring in Apple's colours,
  not Avela's.

**Weight and scale**

- Match the adjacent text. Use `.font(.body)` or `.imageScale(.medium)` in
  rows.
- Never set a fixed point size, so symbols follow Dynamic Type.

**Fill and outline**

- Use **outline** for actions and navigation: `plus`, `chevron.right`,
  `calendar`, `archivebox`.
- Use **fill** for habit identity and the *done* state: `book.fill`,
  `checkmark.circle.fill`.
- Tab bar: outline when unselected. The system fills selected tab symbols;
  don't fight it.

**Meaning beyond colour**

Every state symbol has a distinct shape, not just a distinct tint:

| State | Shape |
|---|---|
| Done | Filled circle with a checkmark |
| Missed | Hollow ring |
| Skipped | `forward.end` glyph on a tinted fill |
| Today, still open | Dashed ring |

This satisfies the HIG requirement to "convey information with more than
color alone" ([HIG: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)).

**Symbols Avela never uses**

- `flame`, as a streak icon: it reads as loss-aversion, the pattern Streaks
  and Habitify use (COMPETITIVE_RESEARCH).
- `xmark`, to mean a miss.
- `exclamationmark.triangle`, for over budget.
- Any red-tinted symbol for a habit state.

**Animation**

Symbol effects are allowed only where they communicate a state change
(DESIGN_SYSTEM: motion should "communicate state change"):

| Event | Effect |
|---|---|
| Completion | `.contentTransition(.symbolEffect(.replace))` from circle to `checkmark.circle.fill` |
| Recovery threshold reached | One `.bounce` |
| Attention near-limit | Variable colour on `hourglass` (HIG: "use variable color to communicate change") |

- Never use `.breathe` or `.pulse` loops in content.
- Under Reduce Motion, every effect falls back to an instant state change.

## 2. Curated symbol set

### Navigation and chrome

| Role | Symbol | Notes |
|---|---|---|
| Tab · Today | `sun.max` | The system fills it when selected |
| Tab · Insights | `chart.bar.xaxis` | Rather than `chart.line.uptrend.xyaxis`, which implies growth |
| Tab · History | `calendar` | |
| Tab · Settings | `gearshape` | |
| Add habit | `plus` | Glass toolbar button |
| Week back / forward | `chevron.left` / `chevron.right` | Disabled state uses `inkTertiary` |
| Navigation row disclosure | `chevron.right` | Fixes UX_AUDIT F8 ("View History" has no chevron) |
| More | `ellipsis` | Detail toolbar menu |
| Edit | `square.and.pencil` | Use the text label "Edit" in the toolbar; the symbol is for menus |

### Habit states and actions

| Role | Symbol | Notes |
|---|---|---|
| Not done | `circle` | 44pt hit target |
| Done | `checkmark.circle.fill` | Use `.replace` on the transition |
| Skip | `forward.end` | Neutral, not a failure |
| Undo | `arrow.uturn.backward` | Toast and context menu |
| Recovering | `arrow.clockwise` | Recovery tint only; distinct from Undo |
| Archive | `archivebox` | |
| Reactivate | `arrow.up.bin` | Or the text button "Reactivate"; check legibility |
| History entry | `clock` | Completion time in History |
| Reminder | `bell` / `bell.slash` | MVP §5 |

### Habit identity

This set replaces the current 12-icon picker (`HabitFormView.iconChoices`),
grouped by `HabitCategory`. It needs 44pt cells (UX_AUDIT F5).

| Category | Symbols |
|---|---|
| health | `drop.fill`, `pills.fill`, `fork.knife`, `bed.double.fill`, `heart.fill` |
| fitness | `figure.walk`, `figure.run`, `dumbbell.fill`, `figure.yoga`, `bicycle` |
| learning | `book.fill`, `graduationcap.fill`, `character.book.closed.fill`, `music.note` |
| mindfulness | `leaf.fill`, `moon.stars.fill`, `pencil.line`, `sparkles`, `wind` |
| productivity | `checklist`, `laptopcomputer`, `tray.full.fill`, `timer` |
| social | `person.2.fill`, `phone.fill`, `envelope.fill` |
| finance | `banknote.fill`, `chart.pie.fill`, `cart.fill` |
| avoidance (any category) | `iphone.slash`, `nosign`, `cup.and.saucer.fill`, `takeoutbag.and.cup.and.straw.fill` |

Avoid symbols that read as medical (`cross.case`, `stethoscope`), because of
the medical-claims rule in APPLE_COMPLIANCE.

### Attention (Phase 2, future)

| Role | Symbol |
|---|---|
| Budget | `hourglass` |
| Protected window | `clock.badge.checkmark` |
| Phone-free session | `iphone.slash` |
| Log minutes | `plus.circle` |
| Session timer (Live Activity) | `timer` |

### Insights

| Role | Symbol |
|---|---|
| Trend up / down / flat | `arrow.up.right`, `arrow.down.right`, `arrow.right` |
| Went well | No symbol: the habit icon is enough |
| Needs recovery | `arrow.clockwise` in recovery tint |
| Observation | `lightbulb` |
| Empty or insufficient data | `chart.bar` (already used) |

Down-trend copy says "points lower", in `inkSecondary`, never in an alarm
colour.

## 3. App icon requirements

Sources are [HIG: App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
and [HIG: Materials](https://developer.apple.com/design/human-interface-guidelines/materials).

**Construction**

- 1024×1024 px master, built as **layered artwork in Icon Composer**.
- Annotate the Default, Dark, Clear (light and dark) and Tinted (light and
  dark) appearances. The system generates any variants you don't provide;
  supply them all, so the result is never automatic.
- The system applies the corner mask. Don't bake in rounded corners or a
  drop shadow.

**Content**

- No text or wordmark; HIG notes that text in icons doesn't localize.
- No photos, no UI replicas, no SF Symbols and no confusingly similar
  glyphs.
- One idea that reads at 29pt. The Tidewater concept (sun or eye over two
  ripples) is shown at 60, 40 and 29pt on the app-icon board.

**Layers**

- Use 2 or 3 layers at most: background field, primary mark, secondary
  ripple. That gives Liquid Glass specular depth without clutter.

**Brand alignment**

- The icon's dominant hue is the `accent` token family.
- The Tinted variant must survive as a pure luminance mask, so the mark
  must be legible as one light shape on dark.

**Distinctiveness**

- Avoid category clichés: a checkmark, a ring, a flame, a calendar grid, a
  lone leaf. The Almanac concept is flagged as too generic for this reason.

**Companion in the icon?**

- Not recommended for A: it ties the brand to one species before the
  companion design has been validated.
- C explores it. Revisit once companion selection (MVP §8, onboarding step
  4) is final. If users choose among several animals, the icon should not
  privilege one.

**Delivery**

- An Icon Composer `.icon` file plus a flattened 1024 PNG per appearance.
- A one-page construction sheet: grid, safe area, layer stack.
- Commission or design it as original work, and record its provenance
  (who made it and the licence) in the repo before release.

The concept sketches on `mockups/png/board-app-icons.png` are direction
explorations only. They are not deliverable artwork.

## 4. Companion and brand-art requirements

These requirements come from DESIGN_SYSTEM.md ("Companion states"), MVP §8
and UX.md ("Companion UX").

**Character**

- **Species:** a calm, adult-toned animal, *not* a baby-schema mascot.
  Avoid oversized eyes and pastel candy colours (UX.md: "never childish by
  default").
- **Silhouette:** recognizable as a filled silhouette at 29pt, for widgets
  and the Lock Screen.

**States.** Six poses, one per `CompanionState`. Each needs a distinct pose
*and* expression, not just a colour change; the placeholders vary eyes and
colour only, and that is not enough. Every state must pass a "no shame"
review: no tears, slumped defeat, or turned backs.

| State | Meaning (MVP §8) | Pose direction | Tint token |
|---|---|---|---|
| calm | On track | Seated, eyes softly closed | accent |
| focused | Active session or progress | Upright, ears forward, eyes open | accent |
| nearLimit | Attention 70–99% | Alert, a head-tilt glance | recovery |
| overloaded | Budget exceeded | Curled or resting, *tired, not sad* | overBudget |
| recovering | Renewed progress after a miss | Stretching or standing up | recovery |
| celebrating | Meaningful completion | A small hop or tail flick, a single gesture | celebrate |

**Motion**

- At most one subtle loop per state, of 2–4 seconds, such as breathing or an
  ear flick.
- Under Reduce Motion, use a static pose with no loop.
- Nothing loops on the Lock Screen.
- Never animate the companion in a Live Activity beyond the session's own
  progress (APPLE_COMPLIANCE: "avoid permanent mascot residency").

**Formats**

- Vector source.
- Layered exports for SwiftUI: SVG or PDF assets in an asset catalogue, with
  separate eye, ear and body layers so states can be composed.
- No third-party animation runtime without a DEPENDENCIES.md entry; Lottie
  or Rive would each need one. Prefer SwiftUI-native animation of layered
  vectors.

**Rendering**

- Every pose must render in light, dark, and Tinted/Clear Home Screen
  contexts (for widgets).
- Provide a monochrome silhouette version of each pose.

**Copy contract.** The companion speaks only in sentences derived from data:

- "Three of four habits are done."
- "You're close to today's limit."

It never uses:

- first-person neediness ("I missed you", "I'm hungry");
- "us" framing;
- streak-repair or currency language (see the Finch pattern in
  COMPETITIVE_RESEARCH).

**Accessibility**

- Every state has a VoiceOver label that names the state and its meaning,
  for example "Companion: recovering. Two good days since your miss."
- Decorative loops are hidden from accessibility.

**Brand art beyond the companion**

- Use it for empty-state illustrations and the onboarding value screen, in
  the same vector style as the companion.
- At most one illustration per screen.
- Never in the content layer behind text.
