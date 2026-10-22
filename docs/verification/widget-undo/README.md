# Explicit widget Undo — October 8, 2026

Quick Log and Routine now show **Log → Undo → Log** for simple current-day check-ins. Undo is an outlined native action in the same hit region, replacing the saved checkmark's status-only refresh. Habit-name and amount/Health review links still open Rilova deliberately. No new permission, dependency, persistent database schema or widget kind.

## Safety and behavior

Undo targets the exact completion UUID exported with the saved row. It never removes “the latest completion” or toggles current state. Repeated requests for a removed UUID cannot delete a new check-in. Current day/time zone, configuration revision, active/due status, skip/quantity rules and stored fact source/day/time are revalidated in the app process. Amount entries and Health imports remain intact. Older snapshots without the new optional UUID offer detail review until refreshed.

Visible widget IDs are presentation-only pins, bounded to four known rows. Routine filters those IDs to its own steps. Both providers request current facts at valid acknowledgment expiry; iOS may defer redraw/reordering. Accessible text uses a larger action width; Undo keeps text and its outline at full palette contrast.

## Files

Production: `WidgetSnapshot.swift`, `WidgetSnapshotExporter.swift`, `QuickLogService.swift`, `QuickLogProjection.swift`, `QuickLogHabitIntent.swift`, `QuickLogWidget.swift`, `WidgetGuideView.swift`. Tests: `QuickLogTests.swift`, widget-guide assertion in `MVPFlowTests.swift`. Documentation: MVP, UX, data model and Apple compliance; verification evidence below. Existing project memberships suffice.

## Verification

- 557 unit tests passed, zero failures (+10 meaningful widget Undo/pin regressions).
- Native Quick Log Log → Undo → Log passed for Reading and Walk, with the app terminated before actions and never foregrounded by them. Button bounds/row position stayed stable. QA canonical database contains exactly two habits and two final completions after the cycles.
- Updated widget-guide UI flow passed. The native pass verifies Quick Log; Routine shares that row/intent and has projection coverage, but no separate native Routine undo journey is claimed.
- Final Debug build passes, including Routine's subsequent fresh-expiry request. Release build passes; all four fixture/store/activity DEBUG markers are absent from app and widget Release executables, with `UndoQuickLogHabitIntent` present as a positive check. Logs: `/tmp/rilova-widget-undo-final-debug.log`, `/tmp/rilova-widget-undo-release.log`. Project plist and whitespace checks pass.
- Initial native verification caught the outline expanding accessibility bounds by 1pt; switching to an inset stroke corrected the actual control bounds. Initial test compilation caught an immutable test-field assignment; corrected before the passing run.

[Saved with Undo](logged-with-undo.png) · [Undone with Log available](undone-log-available.png) · [Logged again](relogged.png). The [QA driver](native-qa-driver.txt) depends on preinstalled native widget placements and is retained outside shipping test source; the original test file is restored with only the guide assertion added.

Passing combined result: `/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.08_16-42-42--0600.xcresult`; log: `/tmp/rilova-widget-undo-verified.log`. Native run took 79.7s for setup and both complete cycles, not a user latency benchmark. No full UI suite rerun is claimed for this change.

Domain checks cover exact Undo/re-log/replay, other habits/dates/duplicate same-day facts, day/time-zone/revision changes, new quantity targets/archive, Health/quantity sources, clock rollback, flexible weeks, legacy snapshots, canonical export and routine pin expiry.

No claim of instant widget redraw. Real-device authentication, VoiceOver and system widget tint remain hardware checks. No owner history is used for testing. The signed final Debug app was installed in place on the owner's simulator and launched with no fixture variables; before/after habit/completion/skip/configuration counts were identical (3/9/0/3). No reset or uninstall. No commit or push.

## Follow-up: owner display and repeated taps

A subsequent user report exposed two distinct issues: the Device Hub window stopped accepting input, and after restoring input the widget continued rendering completed rows despite successfully saved Undo deletions. Privacy-safe Debug diagnostics verified the deletes and idempotent repeated requests; read-only database inspection confirmed two current-day facts removed while older facts remained. No owner facts were changed by automation.

The follow-up prevents repeated Undo from restarting snapshot publication and lets WidgetKit perform its guaranteed post-action timeline reload. A fresh completion UUID also gives the Undo control a fresh identity. The owner widget host was restarted without resetting data or deleting widget placements. Normal app exports retain their cross-widget reload behavior; widget actions rely on the tapped widget's automatic refresh, with other widgets following their timelines.

Before the follow-up, the background-app native flow passed twice, including a diagnostic run with 32 focused unit tests. The original terminated-app result above remains valid; it did not reproduce the owner display/input failure. Final follow-up results are recorded below after verification.

Follow-up verification: **33 focused unit tests and 1 native UI flow passed**, zero failures. The native flow leaves the app running in the background and double-taps Undo for both QA habits, then verifies Log is offered and re-logging succeeds without foregrounding the app. Result: `/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.08_19-15-04--0600.xcresult`; log: `/tmp/rilova-widget-undo-repeat-tests.log`. The retained QA driver now covers this repeated-tap/background variant; temporary shipping test edits were restored.

Follow-up Release build succeeded (`/tmp/rilova-widget-undo-repeat-release.log`); `WidgetCheckIn` is absent from both Release executables and the Undo implementation is present. The signed tested Debug app was installed in place on the owner simulator without fixtures, reset, or uninstall. The owner manual flow still requires confirmation after this install; passing QA automation is not represented as owner acceptance. No full-suite rerun or commit/push is claimed.

## Immediate action feedback follow-up

`QuickLogWidget.swift` now uses a custom-styled native intent Toggle, preserving the fixed Log / exact-record Undo commands. Optimistic accessibility/presentation changes to “Saving…” / “Undoing…” before the saved timeline replaces the entry. Explicit status-text invalidation/pulsing was removed. The native system may still fade or animate updated content, and timeline redraw remains delayed on this simulator; this is an improvement to feedback, not an eliminated redraw latency claim.

**33 focused unit tests and the native feedback/repeated-tap flow passed**, zero failures: `/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.08_19-37-44--0600.xcresult`; `/tmp/rilova-widget-feedback-verified-tests.log`. The test observes pending action labels before the final saved actions, exercises pending taps, and completes Log/Undo/re-log for both QA habits without foregrounding the app. QA ends with two habits and two completions. [Feedback driver](native-feedback-qa-driver.txt); shipping test source restored. Exported attachments are in `/tmp/rilova-widget-feedback-attachments/`; they capture asynchronous system transitions and must not be presented as static, fully settled pending designs.

Trials that asserted a reliably disabled pending Toggle, attempted a fixed optimistic binding assignment, or suppressed native invalidation/animation failed native checks and were discarded. The retained implementation preserves canonical idempotency for repeat taps instead of claiming that WidgetKit prevents all repeated dispatches. Release build passed (`/tmp/rilova-widget-feedback-release.log`); final Debug rebuild passed (`/tmp/rilova-widget-feedback-final-debug.log`). No full-suite rerun, latency guarantee, device result, commit, or push is claimed.

For the feedback build, Release diagnostic verification uses the four complete logging-message markers, all absent from both executables. The string `WidgetCheckIn` alone is no longer a valid check because the production `WidgetCheckInToggleStyle` name contains it. This does not indicate a logging hook in Release.
