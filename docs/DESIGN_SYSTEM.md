# Design System

## Design intent

Premium, calm, native, emotionally engaging.

Avoid:
- childish visual language
- excessive gamification
- neon productivity dashboards
- guilt colors and alarm-heavy states

## Companion role

The companion is:
- a guide
- a status indicator
- a retention layer
- a brand asset

The companion is not:
- a guilt mechanism
- a dependency cue
- a substitute for product utility

## Visual principles

- generous spacing
- clear hierarchy
- limited simultaneous information
- native-feeling controls
- subtle depth and motion
- strong dark-mode support

## Typography

Use system typography by default.

Respect Dynamic Type.

## Motion

Motion should:
- communicate state change
- reward meaningful progress
- remain subtle

Must respect Reduce Motion.

## Haptics

Use sparingly:
- completion
- meaningful milestone
- session start/end

Avoid haptic spam.

## Companion states

Each state should have:
- pose
- expression
- optional subtle loop animation
- semantic meaning

No state should imply shame.

## Components

Core components:
- HabitCard
- AttentionBudgetCard
- ProgressRing / ProgressBar
- WeeklySummaryCard
- CompanionView
- EmptyStateView
- PaywallFeatureRow
- SettingsRow

Prefer reusable components over duplicated styling.

## Curated accents and month history — 2026-10-05

Vivid Tidewater remains the default. Settings → App Theme offers Tidewater,
Sapphire, Plum, Ember and Rose, each with paired system light/dark colours.
[THEMES.md](THEMES.md) records exact values and native contrast checks. The selected
accent applies consistently to app navigation, habit controls, icons and progress;
reading surfaces stay neutral and recovery/attention warnings retain stable
semantic colours. Widgets and Live Activities retain Tidewater for now.

Habit Calendar History uses a month grid with connected daily success ribbons.
Weekly check-ins are not drawn as a daily streak: the evaluated weekly commitments
and targets appear separately. State symbols and VoiceOver labels accompany
colour. At accessibility text sizes, dates reflow to a vertical list. Month arrows
have at least 44-point targets; calendar dates are informational, not small buttons.

Accessibility month lists show tracked/recorded dates, omit unrecorded upcoming
and pre-creation dates with an explicit explanation, and place weekly commitments
before the date list so large-text users need not scroll through a whole month
to find the target outcome. The regular grid still shows every civil date.

### Expanded app accents

The free theme picker now includes nine curated light/dark pairs; see THEMES.md
for exact tokens. The four additional accents are Indigo, Forest, Coral and
Gold. They use the existing semantic palette and prominent-fill treatment;
warning/recovery meanings, neutral reading surfaces and widget/Live Activity
Tidewater styling remain consistent. No per-screen palette editor or gradients
were introduced in this pass.

## Full theme treatment — 2026-10-05

Owner-requested styling now includes a softly coloured full-page gradient,
restrained theme-tinted custom cards and a deep gradient hero on Today/Calendar.
This supersedes the earlier accent-only/neutral-surface guidance. Reading ink
remains stable; warnings/recovery retain semantic meaning. Calendar current
streak uses a large rounded numeral, personal best and visible success ribbons,
without invented goal percentages or punitive missing-day colours. No animated
background, new mascot art or haptic loop. Increase Contrast simplifies the page
canvas; Dynamic Type/date-list fallbacks remain. Exact formulas and contrast
checks are in THEMES.md.


## Design quality implementation

Today summary typography uses scalable system styles. Interactive content has adequate bounds, weekday options reflow, and long Settings labels wrap. Informational calendar dates expose static traits. Reduced transparency gives onboarding actions an opaque surface; Reduce Motion suppresses completion symbol transitions. These changes preserve the selected theme.

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

### Recovery progress card

Use neutral reading surfaces, the selected theme's accent for three restrained progress segments, and stable habit icon identities. Separate habit identity/count from optional support actions. Keep schedule/quantity metadata in the primary habit row; avoid repeating recovery captions beneath every name. The card follows the logging list so decoration/support never displaces the first action. At accessibility text sizes, stack support actions and keep logging-confirmation Undo/Dismiss in one row. Segments are decorative to accessibility; the real count is spoken.

### Visual weekly review

Use a neutral card hierarchy over the selected atmospheric canvas: completed-week header, consistency ring, factual highlights, per-habit bars, then separate manual attention and intention review. The selected accent carries progress; stable habit icon identities and explicit archived text preserve context. Use explicit InkSecondary for card/link metadata so secondary labels do not inherit a faint accent tint. Bar tracks have visible outlines.

At accessibility text sizes, stack ring and explanation, retain full count labels and reveal content by scrolling instead of squeezing an entire dashboard into one viewport. Chart geometry is decorative to assistive tools; actual percentages, counts, provenance and navigation labels carry meaning. No chart animation or new haptics. Never plot fabricated intermediate trend points.


## Today companion placement — 2026-10-06

The owner-requested compact companion status card now sits immediately below the daily summary and before habit actions, rather than after routines at the bottom of Today. This supersedes the earlier bottom-placement guidance. The companion remains optional, reflects real state, and retains its existing Reduce Motion and scalable-text behavior. No progress, persistence, permissions or feature scope changes.

## Differentiation presentation

Momentum uses native, adaptive fact cards on the selected theme canvas; semantic color emphasizes counts without being the sole signal. Optional memory and recovery choices use existing native form/list and alert patterns. The compact companion uses four labelled presentation states and distinct existing poses, with a restrained crossfade disabled under Reduce Motion. No idle loops, reward economy or extra navigation tabs.

## Quick Log widget

Neutral native widget background, system typography, selected theme accent for controls (exported RGB tokens, no duplicated theme mapping). This exception applies to Quick Log; earlier progress/budget widgets and Live Activities retain their existing treatment. No decorative mascot or analytics. A separate 44pt control logs; name/body opens details. Completed rows use a static checkmark plus 'Logged today', quantities a plus and in-app route, skips an explicit text state. Medium uses a row-major 2×2 grid in habit order. At the first accessibility text size, small shows one row and medium two in one column; at larger accessibility sizes both show one row. Text is not forcibly scaled down. There are no bespoke animations.


## Two focused widgets — Rich Tide, 2026-10-07

Quick Log and Routine are the two Home Screen choices. The approved Rich Tide treatment uses a deep selected-theme gradient, off-white text and pale solid 44pt-high Log buttons with deep contrasting ink. Surfaces derive from the exported light accent; there is no second registry of theme colors. A restrained lower tonal arc adds depth without decorative art behind reading text. Increase Contrast or Reduce Transparency uses a solid deep surface instead. Static styling adds no animation or permission.

Quick Log shows two small/four medium rows; Routine shows one small/two medium steps in a vertical sequence. Accessibility sizes reduce capacity and allow names to wrap. Completed/skipped/weekly-met states retain explicit text. Quantity + is a distinct softly tinted in-app action; Log saves a simple check-in without opening the app. Setup, empty and stale states use the same surface. No decorative mascot or mandatory app-opening action.

The palette regression verifies primary/secondary text and Log ink at 4.5:1, and action boundaries at 3:1, for both gradient endpoints in every theme and appearance. Native evidence and remaining device checks are in [two-widget verification](verification/two-widgets/README.md). System tinted rendering is controlled by iOS and remains a physical-device check.

Widget pending feedback is confined to the status caption, following [Apple's guidance to use invalidatable content judiciously](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities). Do not invalidate the complete Log button or show completed state before its save. Cold background startup may still take time; stable action styling does not promise instant execution.
