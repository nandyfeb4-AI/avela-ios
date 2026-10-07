# Avela design quality execution

This checklist applies DESIGN_QUALITY_PLAN.md to the working product. Status must distinguish implementation from simulator, device and user evidence. It does not add product features or replace TESTFLIGHT_CHECKLIST.md.

## Core journey inventory

| Journey | States to verify | Existing implementation and next evidence |
| --- | --- | --- |
| Onboarding | Welcome, optional setup, skipped setup, failed save, completion | Native flow and heading/target audit; observe first use and VoiceOver step focus on device |
| Habit setup | Custom/idea draft, all schedule kinds, empty weekday selection, cancellation, edit | Native persistence/limit tests; adaptive weekday targets and picker/icon accessibility checks |
| Today | Empty, due/not due, positive/cut-down, completed/collapsed, recovery | Native logging/undo/order tests; contextual spoken values and scalable summaries |
| Undo | Visible confirmation, dismissed/expired, repeated action, midnight, alternative input | Exact current-day fact validation; native dismiss/Done undo; device assistive timing check |
| Calendar | Current/past month, success/miss/skip/pause, pending week, mixed units | Native audit and read-only regression; informational traits; device navigation/comprehension check |
| Attention | Unknown/manual usage, near/exceeded budget, correction/deletion, windows/sessions | Existing domain/UI tests; native chip/undo regression; signed permission/session checks |
| History and Insights | Empty, populated, filters, archived records, ties, incomparable trends | Native audits and historical metric tests; observe interpretation without coaching |
| Settings | Themes, feedback preferences, ordering, archive/reactivate | Native persistence checks and wrapped labels; device keyboard/focus and alternative input |
| Premium | Unavailable, available, purchasing, cancelled/pending, restored/expired | Native paywall audit and StoreKit tests; larger utility actions; actual sandbox/device and store metadata |
| System surfaces | Widget empty/stale/updated, notification review/cancel, session expiry/dismissal | Existing tests; real locked-device privacy, discovery and lifecycle checks still required |

## Findings implemented in the first pass

- Weekday choices now adapt into rows with at least 44-point controls. Accessibility text sizes use inline picker choices instead of cramped segmented or menu controls; standard text retains segmented controls. Screenshot review complements automated clipping checks.
- Icon names spoken to assistive technology are human-readable. Stable identifiers continue to support test queries; no new icon library is needed.
- Today summaries scale with system typography. Detail links include schedule/recovery or manual-attention context, and their content has comfortable touch height.
- Logging confirmation has an explicit Dismiss action. VoiceOver/Switch Control keep confirmation and focused rows stable rather than automatically removing them. Ordinary touch use retains transient confirmation and Done grouping.
- Exact completion IDs prevent stale or repeated Undo from becoming a new log or changing another day's completion. This validation belongs to feature state, not a view.
- Onboarding marks step titles as headings and requests focus after step changes. Reduced transparency uses an opaque bottom action surface.
- Calendar dates explicitly expose static informational traits. Month controls have larger bounds and use directional symbols. Weekly outcome semantics remain unchanged.
- Settings labels wrap; paywall utility actions have larger content bounds. No purchase terms or entitlements changed.

## Private usability session

Use a fresh isolated installation for first-use work; retain the participant's normal test installation. Do not coach until the participant finishes or asks for help. Ask permission before recording; handwritten local notes are enough.

1. Ask the participant what Avela seems to do, then create a small habit of their choosing.
2. Log it, undo the log, then log it again. After the confirmation disappears, ask how they would correct a mistake.
3. Create a flexible weekly habit. Ask what counts as success and whether an unlogged Tuesday is a miss.
4. Create an attention budget, log five minutes and explain what the displayed status does and does not measure.
5. Browse Calendar and Insights. Ask them to explain a skip, pause, weekly target and recovery message.
6. Find a theme, change it, then edit/archive/reactivate a habit. Ask what they expect to happen to history.
7. View Premium and explain the free limits, payment period if products are available, and how to restore. No purchase is required.

For each task record success without help, wrong turns, accidental actions, time to completion, language misunderstood and whether any wording feels judging. Define an issue when someone cannot complete a core action, mistakes a manual value for automatic measurement, cannot discover undo, or misreads a weekly commitment. Owner/spouse findings guide corrections but cannot establish market-wide outcomes. Re-test a corrected task instead of declaring success from preference.

## Pending evidence

- [ ] Physical VoiceOver focus and complete journeys, including confirmation dismissal and changing steps.
- [ ] Switch Control, Voice Control, supported keyboard operation and alternative activation.
- [ ] All nine themes on device with light/dark, largest text, Increase Contrast and Reduce Transparency.
- [ ] Instruments launch/scroll/memory/energy profiling on supported hardware with multi-year data.
- [ ] Signed Health, Siri, notification, widget and Live Activity checks from TESTFLIGHT_CHECKLIST.md.
- [ ] Owner/spouse usability sessions and correction/re-test notes.
- [ ] Localization scope, pluralization audit, right-to-left review and professionally reviewed translations.
- [ ] Final store icon/screenshots/video, public privacy/support information and signed release regression.

Do not publish an Accessibility Nutrition Label until its specific criteria have been evaluated. Do not submit an editorial nomination or publish testing materials as part of this implementation pass.

## Verification evidence

Final run results and preview links are recorded in SETUP.md and verification/design-quality/README.md. Passing selected native audit types is not a certification of every screen or assistive workflow. The performance benchmark measures one calculator with 1,095 recorded days in the simulator, not startup or physical-device UI latency.
