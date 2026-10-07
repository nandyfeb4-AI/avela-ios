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
