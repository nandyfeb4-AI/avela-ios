# Scoped Rilova brand polish

Owner-approved first pass on **Onboarding and Today**. The approved gradient icon informs a quiet welcome card and deep teal habit-summary card; it is not copied behind every reading surface.

## Changes

- `AppPalette.swift`: scoped welcome and Today summary endpoints; other saved themes retain their palette.
- `OnboardingView.swift`: icon/name/category grouping, padded welcome gradient, stable ink, full-width native Continue button. All steps, optional skips, stable IDs and permission behavior are retained.
- `TodayView.swift`: coordinated summary height/padding, larger count and deep branded gradient. Habit rows, semantic attention status, companion placement, controls and tracking remain unchanged.
- `AppThemeTests.swift`: sampled gradient contrast across all themes in both appearances.
- `MVPFlowTests.swift`: large-text welcome check verifies a usable 44pt-or-larger Continue action and progression to habit setup.

No schema, package, integration identifier, entitlement, subscription or progress change. No new animation, haptic or external service.

## Verification

Results and native screenshots are recorded below after completion. Tests use the dedicated QA simulator, not the user's persistent simulator. Full UI-suite, physical VoiceOver, OLED/glass appearance and user preference validation are separate checks.

### Verified results

- **547 unit tests, zero failures**, including gradient-ramp text contrast across all nine themes in light/dark.
- **6 distinct focused UI flows passed**: welcome native audit, optional onboarding/relaunch, large-text welcome action, core Today/calendar audit, theme change/read-only calendar, and large-text Today logging/Undo. Dark-mode core/welcome audits were repeated after changing the QA device's system appearance with `simctl ui ... appearance dark`.
- Visual review caught welcome footer show-through at large text. The final implementation uses an opaque welcome footer through the bottom safe area and omits the optional category subtitle at accessibility sizes. Final welcome large-text and normal audits were repeated after this fix.
- Release iPhoneOS build succeeded. No physical-device accessibility/glass/OLED or user preference validation is claimed; no full UI-suite rerun is claimed.
- `git diff --check` passes. No domain/data model, permissions, dependencies or saved theme identity changed.

Native captures: [welcome light](onboarding-light.png), [welcome dark](onboarding-dark.png), [Today light](today-light.png), [Today dark](today-dark.png), [welcome large text](onboarding-large-text-dark.png), [Today large text](today-large-text-dark.png), [saved Indigo theme](today-indigo.png). Large text uses scrolling rather than shrinking body copy. Native accessibility audits cover geometry, descriptions, traits and clipping; real VoiceOver focus/navigation remains a device check.

Logs: `/tmp/rilova-scoped-polish-tests.log`, `/tmp/rilova-scoped-polish-dark-tests.log`, `/tmp/rilova-scoped-final-welcome-tests.log`, `/tmp/rilova-scoped-final-light-tests.log`, `/tmp/rilova-scoped-final-release.log`. All tests used the separate QA simulator, without resetting, uninstalling or seeding the user's simulator.

## Calendar and Insights continuation

- `HabitCalendarView.swift`: coordinated deep summary gradient, rounded habit heading, solid increased-contrast fallback. Existing scenic band, daily success ribbons, weekly evaluation, accessible date list and month navigation are retained.
- `InsightsView.swift`: padded soft week header, calendar label and monospaced summary digits. Charts, factual values, manual-usage provenance, cohort rules and navigation are retained on neutral cards.
- `AppPalette.swift`: existing contrast-tested endpoints reused; no new palette values.
- `MVPFlowTests.swift`: current-month capture added to the existing read-only navigation/relaunch regression.

Completed verification is recorded below. This is presentation only, with no progress, storage, permissions, dependencies or identifiers changed.

### Calendar / Insights verification

- **13 palette unit tests and 7 focused UI test executions, zero failures** (five distinct UI flows, with Calendar and populated Insights repeated in dark mode). Reused endpoint tests cover text contrast across all nine themes in both appearances.
- Verified read-only month browsing/relaunch, persisted Indigo selection, exact 68% fixture result, archived-habit breakdown, manual-usage coverage, large-text chart navigation and accessible weekly-calendar scrolling.
- Native light/dark and large-text captures were visually reviewed. At the largest accessibility setting, headings and explanations wrap and require scrolling; they are not shrunk to fit.
- Release iPhoneOS build passes; no full-suite rerun or physical-device accessibility verification is claimed for this presentation-only continuation.

Captures: [Calendar light](calendar-light.png), [Calendar dark](calendar-dark.png), [Calendar history](calendar-history-light.png), [Indigo Calendar](calendar-indigo.png), [Insights light](insights-light.png), [Insights dark](insights-dark.png), [Insights large text](insights-large-text-light.png), [Calendar large text](calendar-large-text-dark.png), [habit breakdown](insights-breakdown-light.png).

Logs: `/tmp/rilova-calendar-insights-light.log`, `/tmp/rilova-calendar-insights-dark.log`, `/tmp/rilova-calendar-insights-release.log`. Tests used the dedicated QA simulator.
