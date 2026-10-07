# Curated app themes

Owner-approved enrichment, 2026-10-05. Nine free app themes are available from
Settings → App Theme: Tidewater (default), Sapphire, Plum, Ember, Rose, Indigo,
Forest, Coral and Gold.
Choosing one saves immediately and changes full-page gradient canvases, tinted
reading cards, gradient hero panels, navigation, logging controls, habit icons,
progress, quick-log chips and completion feedback. It changes no
tracking behavior, entitlement, companion selection or haptics preference.

The app continues to follow the iPhone's light/dark appearance. Typography stays neutral; reading cards receive a restrained theme tint. Attention Healthy/Near Limit/Exceeded and recovery
retain their semantic colors across themes; a brand preference does not redefine
what a warning means. Text, shapes and state labels also communicate outcomes.
Widgets and session Live Activities retain the original Tidewater palette in this
slice. There is no per-screen palette, custom color picker or gradient editor.

| Theme | Light accent | Dark accent |
| --- | --- | --- |
| Tidewater | `#0E7468` | `#3CC9B4` |
| Sapphire | `#275DA8` | `#8BBBFF` |
| Plum | `#754EB1` | `#CAB0FF` |
| Ember | `#A44816` | `#FFB186` |
| Rose | `#9D3F67` | `#F6A7C7` |
| Indigo | `#4B4BB7` | `#B0B4FF` |
| Forest | `#2B683D` | `#92D5A0` |
| Coral | `#AD463D` | `#FFB0A5` |
| Gold | `#84600E` | `#F3CF72` |

The additional accents use the same native palette contract. Indigo adds a
blue-violet option distinct from Sapphire's blue and Plum's purple; Forest is
leaf green rather than Tidewater's teal; Coral offers a pink-orange warmth;
Gold uses a deep ochre in light mode and a pale honey accent in dark mode.
The light colours stay deep enough for white prominent-control icons, while
dark accents brighten progress and ordinary controls alongside the themed reading
surfaces. Existing saved theme raw values and Tidewater's default are unchanged.
No persistence model or migration is added by expanding the enum.

## Architecture and storage

`AppTheme` and `AppearanceRepository` are Foundation-only. One new SwiftData
entity, `AppAppearanceRecord`, stores `preferencesID = primary` and `themeRaw`.
It leaves the existing companion-profile schema and records untouched. Missing
or unknown values use Tidewater; reading a fallback does not overwrite a future
value. Only explicit selection writes/upserts the record. AppPersistence now
contains 14 models; the default requires no seed or store reset.

`AppShellView` composes the repository, owns the selected theme and injects an
immutable `AppPalette` environment value, with matching native `.tint`. Views
read the injected palette. There is no mutable global or UserDefaults storage.
UIKit dynamic colors resolve the paired appearances, including presented sheets.
Stable semantic assets continue to supply attention/recovery states.

The picker publishes the new selection and refreshes the root only after a
successful save. A failed load disables selection until preferences are read;
a failed save shows a safe message and preserves the previous displayed choice.

## Verification

`AppThemeTests` covers default/read-only fallback, unknown persisted values,
single-record upserts, disk relaunch for every new theme, preservation of saved
original selections, preserving companion preferences in both
directions, opening an actual previous 13-model store without a reset, failed
read/write behavior and resolved light/dark contrast. The contrast test checks
every accent against Background/Surface/SurfaceSecondary and OnAccent at 4.5:1,
toast text/Undo at 4.5:1 and its icon at 3:1. These checks measure opaque native
colors; they do not validate Apple's glass compositing on physical hardware.

Build/test results are recorded by the integrating pass in SETUP.md. Physical
device Increase Contrast, OLED presentation and VoiceOver focus/activation are
still release checks. No network, package, entitlement or permission is added.

Native screenshot review caught iOS's automatic white template icons on pale
accent-filled controls in dark mode. The glass toolbar ignores label-colour
overrides. Native prominent controls therefore use a separate deep theme fill
(the light accent in both modes) and white foreground, checked at 4.5:1; solid
custom completion marks still use OnAccent against the dynamic accent. Progress,
icons and ordinary accents keep the lighter dark-mode colour. Actual screenshots
are reviewed after this correction; physical glass/material checks remain open.

## Full theme treatment and streak presentation

Page gradients blend the selected accent into the existing opaque background:
10% at the light top / 2.5% at the bottom, 12% at the dark top / 3.5% at the bottom (refined in the 2026-10-06 UI polish pass).
Reading cards use 2.5% accent over the light Surface / 6.5% over dark Surface;
secondary surfaces use 4% / 8%. No transparency over arbitrary content is needed.
Hero panels use the deep light accent in both appearances, shading toward 72%
of its RGB values, with solid white ink. Gradients are static, not animated.
Increase Contrast substitutes a solid bottom canvas for the page gradient.

Today uses a gradient Habits summary; Calendar History uses a large, scalable
streak count, personal best, a themed calendar card and deep gradient success
ribbons. Current/best totals still mean through today, including when browsing
older months. Weekly check-ins do not become fabricated daily successes. The
existing month data/progress engine is unchanged. Large text still uses the
accessible date list; the decorative headline number alone can shrink to fit
long values. Body text and controls retain their selected Dynamic Type size.

The shared canvas applies to main tabs, habit/attention detail and logging forms,
and the Premium screen. Custom Today, calendar, Insights and companion cards
use theme surfaces; native form/list cells retain system presentation. Widgets
and Live Activities remain Tidewater. No new persistence/preferences schema.

Contrast coverage measures all page/card endpoints with Ink and InkSecondary
at 4.5:1, accent on reading cards at 4.5:1 and 11 hero-ramp samples with white
at 4.5:1, for every theme in light/dark. Native compositing and physical-device
accessibility remain separate checks.

Competitor evidence: [Streaks' official site](https://streaksapp.com/) includes an
official statistics image with prominent streak totals and a strong fuchsia
identity; its [App Store listing](https://apps.apple.com/us/app/streaks/id963034692)
advertises 78 colour themes. The exact gradients and layouts here are Avela's
design choices, not copied assets or evidence that gradients improve adherence.

## Atmospheric themes and action-focused Today — 2026-10-06

The owner approved a coordinated visual pass informed by published competitor examples. Avela now separates neutral reading surfaces from colorful actions and habit identity. All nine existing saved themes retain their values and controls, and add a complementary sky wash plus a static landscape preview. Original SwiftUI Canvas scenery uses clouds, a sun/moon and layered coastlines, mountains, hills or forest silhouettes. No competitor art, runtime image generation, external library, network request or idle animation is used.

Calendar History places scenery in a separate 96-point band below the factual streak summary, never behind dates or reading text. It keeps the existing connected daily-success ribbons and separate weekly commitments; browsing remains read-only. Accessibility text sizes omit the scenery to prioritize text and outcomes. Increase Contrast hides decorative scenery and retains solid preview fills/page backgrounds. Decorative content is hidden from accessibility and cannot intercept taps.

Today places compact habit/attention summaries and actionable habits before routines and the smaller companion. Attention retains manual provenance. Habit symbols use stable curated identity colors across Today, detail, History, archived habits and the form; archive labels and muted icons remain explicit. This color is selected from the symbol rather than private names or inferred behavior, and never replaces completion/status labels.

This supersedes the earlier uniformly accent-tinted reading-card guidance. Reading surfaces are white/charcoal; themes vary atmosphere, controls, progress, heroes and scenery together. Existing completion, recovery, Undo, permission, subscription and persistence rules are unchanged. Companion art, widgets, Watch and Dynamic Island retain their existing system-surface treatment.

Current shared reading surfaces: `#FFFFFF` / `#202329`; secondary surfaces: `#F0EFEC` / `#2A2D34`. Page endpoints: `#F1F3F5` to `#F7F5F0` in light, `#131720` to `#101216` in dark; the middle sky wash varies by theme in AppPalette. Text/hero/accent contrast checks include the new surfaces and sky stops. Scenery has no informational text. Identity-symbol contrast checks cover its composited 10% tile tint on custom and native surfaces.
