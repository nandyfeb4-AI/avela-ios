# Native feature enrichment previews

Real iPhone 18 Pro Max simulator captures, 2026-10-05. These are implemented SwiftUI screens using Avela's existing theme, system typography and SF Symbols, rather than browser mockups.

| Flow | Entry point | Native preview |
| --- | --- | --- |
| Quantity target and timer | Habit Detail → Progress, Timer & History Corrections | [Progress](enrichment-quantity-progress.png) |
| Smaller action | Progress & History → A smaller action | [Separate check-in](enrichment-smaller-action.png) |
| Routine | Today → Routines | [Runner](enrichment-routine.png) |
| Private reflection | Settings or Insights → Weekly Reflection | [Saved reflection](enrichment-private-reflection.png) |
| Manageable week | Today → Routines → Make This Week Manageable | [Named pause](enrichment-manageable-week.png) |
| Gentle restart | Manageable Week → Select focus habits → Review restart | [Runner](enrichment-gentle-restart.png) |
| Habit intention | Habit Detail → Make Room with a Phone-Free Session | [Manual session result](enrichment-phone-free-intention.png) |
| Largest text setup | Progress Setup with Accessibility XXXL | [Light](enrichment-large-text-setup.png) / [Dark](enrichment-large-text-setup-dark.png) |

The Watch companion builds and is embedded in the iPhone application. A paired Watch runtime/device is unavailable here; no Watch screenshot or pairing pass is claimed. Hardware VoiceOver, energy and real Siri delivery remain device checks. No user research or adherence benefit has been established by these simulator runs.

The owner’s simulator and its store were left untouched. Test captures use isolated persistent stores on the dedicated Pro Max.

Verification: the subsequent **full suite passed 411 unit tests and 82 UI tests (493 total), with zero failures and zero skips**, including native reminders and the Live Activity/Dynamic Island flow. Earlier targeted passes and the real dark largest-text pass remain useful supplemental checks. Debug and unsigned iPhone SDK Release builds pass, including embedded Watch content. Release contains none of the four DEBUG-only fixture/store/reminder markers.

Full result bundle: `/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.05_19-29-27--0600.xcresult`; log: `/tmp/avela-full-suite-verified.log`. Older UI queries now reveal lazily materialized offscreen controls before tapping or asserting.

The full run also recorded two SwiftUI publication warnings during reminder-alert dismissal. `AppShellView` now defers clearing the published pending action until after the view update, guarded so a newer reminder is not consumed. After that localized fix, **all 411 unit tests plus the three affected native reminder UI tests passed (414 total, zero failures/skips and zero runtime warnings)**. The entire 82-test UI suite was not repeated after this fix. Follow-up result: `/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.05_20-11-51--0600.xcresult`; log: `/tmp/avela-full-suite-warning-fix.log`.

The latest unsigned iPhone SDK Release build also passes (`/tmp/avela-full-suite-release.log`), with all four DEBUG-only markers independently rechecked as absent.

## Factual weekly reflection — 2026-10-05

Reflection now shows recorded per-habit progress for the selected week alongside private notes. Insights preserves its review week when opening Reflection. Notes are not analyzed; counts describe recorded commitments, not inferred causes. No schema, AI runtime/service, dependency or permission was added.

[Native populated reflection preview](reflection-recorded-progress.png) was exported from the passing UI test and visually reviewed. **11 reflection unit tests + 2 native UI tests passed**, zero failures/skips/runtime warnings, in `/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.05_21-27-00--0600.xcresult` (`/tmp/avela-factual-reflection.log`). The final wording polish was rechecked by the populated UI test in `/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.05_21-29-08--0600.xcresult` (`/tmp/avela-factual-reflection-copy.log`). Unsigned iPhone SDK Release builds pass (`/tmp/avela-factual-reflection-release.log`). This is focused verification, not a repeat of the complete suite. Physical VoiceOver and large-text presentation of this addition remain device checks. No commit or push.
