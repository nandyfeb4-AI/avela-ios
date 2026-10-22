# Calendar planning and native capture integrations

October 7, 2026. Owner-approved integration deepening; no third-party dependencies or canonical schema changes.

## Implemented

- Habit Detail → Make Room → Plan Time in Calendar: future start and 1–180 elapsed minutes, Apple's native event editor, explicit Save/Cancel. No calendar reading or automatic session/completion. Private reasons/history are excluded; the selected calendar can sync/share the reviewed habit title according to its existing settings.
- Siri / Shortcuts → Make Room for a Habit: explicitly selected active habit and existing timed-session goal; uses the canonical start/link flow. Already-running goal is rejected; partial link failure is disclosed. Intent opens Avela, requires local authentication, and does not log success or shield apps.
- Apple Watch: success/already-logged replies produce inline confirmation instead of an extra dismissible alert. Errors retain their alerts. Quantity rows show the iPhone progress destination and cannot be logged as simple check-ins.

## Native screenshots

[Plan time](calendar-plan.png) · [Apple's event editor](calendar-editor.png) · [Shortcuts guide](shortcuts-guide.png) · [Saved plan](calendar-saved.png)

## Verification

- 528 unit tests pass, zero failures. Five new Calendar tests cover title/timing, invalid/past plans, invalid suggested targets, cancellation and truthful saved feedback. Existing intention/session tests cover duplicate/invalid selection, link failure and separation from completions.
- Calendar editor Save and Cancel UI tests pass, preserving an uncompleted habit and starting no session. Native Save is labelled Done on this toolchain.
- Existing Make Room focus/Live Activity/independent logging flow and the expanded Shortcuts guide UI test pass in targeted runs.
- Debug builds through simulator tests. Release device build and separate Watch simulator target build succeed. App/widget Release binaries exclude the checked DEBUG store/fixture hooks.
- Project membership: 220 Swift sources, zero issues. No full UI-suite run or signed-device delivery is claimed.

Initial Calendar UI failures referenced a nonexistent completion button and an offscreen progress row; assertions now check the real status with bounded scrolling. Calendar controls were moved below the primary session controls so planning doesn't displace the existing start action. The initial Live Activity test failure after layout expansion was resolved by restoring that hierarchy and checking the switch state before starting; the existing flow passes.

## Remaining work

Real-device Siri invocation/automation, calendar sync/time zones/shared calendars, Watch connectivity/confirmation/VoiceOver and signing remain hardware checks. Screen Time shielding is **not implemented or enabled**. Its approval and reliable expiry/unblocking plan is in [SCREEN_TIME_INTEGRATION_PLAN.md](../../SCREEN_TIME_INTEGRATION_PLAN.md). There is no shield toggle or misleading protection claim in the app.

The latest Debug app is installed and launched on the owner simulator without uninstalling or resetting data. These changes have not been committed or pushed.
