# Native design quality previews

Real iPhone 18 Pro Max simulator captures from isolated fixtures, 2026-10-05. These are SwiftUI screens, not browser mockups. The owner simulator/store was untouched. The largest-text form is scrolled to its schedule choices.

| Screen | Light | Dark |
| --- | --- | --- |
| Today | [Preview](today.png) | [Preview](today-dark.png) |
| Calendar | [Preview](calendar.png) | [Preview](calendar-dark.png) |
| History | [Preview](history.png) | [Preview](history-dark.png) |
| Insights | [Preview](insights.png) | [Preview](insights-dark.png) |
| Settings | [Preview](settings.png) | [Preview](settings-dark.png) |
| Onboarding | [Preview](onboarding.png) | [Preview](onboarding-dark.png) |
| Largest-text weekday form | [Preview](weekdays-large-text.png) | [Preview](weekdays-large-text-dark.png) |

Final combined verification: **349 unit tests and six quality-focused UI tests passed**, zero failures. Five earlier existing UI regressions also passed; the entire UI suite was not rerun. Selected native accessibility audits cover targets, descriptions, clipping and traits without ignoring issues. Screenshot review prompted replacing the accessibility-size menu picker with inline choices; the final form preserves selection on relaunch. Debug tests and unsigned iPhone SDK Release build pass.

The normal-size dark screens were captured before the final large-text-only picker refinement; they are unaffected by that change. Latest form captures show the inline choices in both appearances. All screenshot data is isolated test data. Paywall actions were audited, but purchase availability is not represented by these previews.

See [SETUP.md](../../SETUP.md) for exact commands/results and [QUALITY_EXECUTION.md](../../QUALITY_EXECUTION.md) for the private usability script and pending device, alternative-input, localization, performance and store evidence. Passing these checks does not certify award readiness or all accessibility workflows.
