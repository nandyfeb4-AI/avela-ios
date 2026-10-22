# Action feedback audit and fixes — October 21, 2026

The owner reported that Show Session Activity worked but appeared unresponsive, shortly after the same issue was fixed for Companion preferences. Source review across the existing app found inconsistent acknowledgment on some actions that leave the current screen open. This is not evidence of a shared failure of SwiftUI Button or every action in the app.

## Findings and changes

| Area | Confirmed gap | Resulting feedback |
| --- | --- | --- |
| Session presentation | Show/Hide text never changed; result was below the controls and could be outside the viewport | The tapped control shows Activity Requested or Activity Hidden; asynchronous Hide shows work in progress. Errors offer labelled retry. A delayed result cannot be attached to a different session. |
| Make Room | Start could remain visually identical while its new review/result section was farther down | The tapped Start control shows Session Started after the actual session/link flow and prevents a duplicate start from that acknowledged control. |
| Reminder | Success was below Save and persisted after unsaved Enable/time edits | Saving → checkmarked Saved in the control; edits/load/new attempts clear old success. Denied-permission copy no longer claims an unsaved draft was saved. |
| Apple Health | Save/update and refresh could return to unchanged controls; disconnect hid its own result | Action-local work and saved/checked states; draft edits clear success; disconnect confirmation survives removal of the connection controls. Checked means the read completed, including unknown/no accessible samples, never verified permission or target success. |
| iCloud recovery | Work/result below the long page; empty successful check had no acknowledgment | Backup/check controls show work and acknowledged completion; result sits by its control, including explicit empty results. Only a completed provider upload can say Backed Up. |
| Progress & History | Saved acknowledgment at form bottom, surviving date/configuration changes or failed later actions | Existing feedback is pinned in a bottom safe-area reading strip; new context/attempt/failure clears it. Exact-entry Undo and quantity/history writes remain unchanged. |
| Calendar planning | Added confirmation could survive revised date/duration or an invalid new review | An unsaved revised/reviewed draft cannot retain prior save acknowledgment; invalid review clears an earlier editor draft. |
| App protection | Shared status hid Stop errors/results; access request had unchanged disabled text; successful authorization retry retained old denial | Shared status renders the existing result/error, authorization shows pending work, and retry clears the earlier denial. No restriction is started by authorization alone. |
| Apple Watch | Tapped logging row stayed Log today while the phone request was pending | Tapped row says Logging; logged success still waits for the iPhone reply. |

Normal habit/attention/reflection/routine editors already dismiss after save and update visible records. Theme choices already change selection and appearance. Subscription actions already provide progress/result text and StoreKit UI; Siri returns explicit dialogs. Those controls do not receive redundant confirmations. Companion's same-control Saved feedback from the preceding fix is retained.

## Scope and safety of the change

No tracking schema, backup format, permission policy, purchase enforcement, reminder scheduling, session outcome or habit success rule changes. No extra success vibrations, custom animation, timer, backend or AI feature is introduced. Session activity feedback acknowledges a request accepted by ActivityKit, not proof of a visible system surface. System dismissal and hidden presentation cannot finish the local session. Accessible labels and announcements distinguish work, completion and failure.

Source changes are in existing Attention views, Reminder view/model, Health view/service, CloudBackup view/model, HabitActivity view/model, Calendar planning model, AppProtection view/model and the Watch dashboard view. Existing test sources cover the state transitions, delayed completion, failure/retry, unchanged history and independent session/habit logging. No new source-file registration is required.

## Verification limits

All automated test mutations use the dedicated QA simulator and isolated test stores or in-memory/fake-provider fixtures. No test fixture, scripted permission choice, explicit test Health import/cloud upload, session outcome or habit mutation is applied to the owner's iPhone. A normal app launch retains its existing startup rules for any integrations the owner already enabled. Physical VoiceOver, Health authorization/data, actual iCloud service, paired Watch response, and every supported device/text-size combination are not established by source audit or focused simulator checks. This is not a full-app hardware audit or a full regression-suite claim.

## Focused results

**138 unit tests passed, zero failures** in the final run: AppProtection, AppShell, CloudBackup, Companion, HabitActivity view model, Calendar planning, quick-log presets, reminders, Health integration/settings, intention-session view model and Live Activity service. Sixteen new tests cover acknowledgment context, delayed completion, failed retries, unchanged stored history and validation failures; authorization retry coverage extends its existing test.

**Ten distinct UI flows have passing results across the focused runs:** Calendar save, explicit Health setup, Make Room focus/independent logging, quick amounts/save/cancel/Undo/relaunch, native phone-free Show/Hide without outcome inference, reminder draft acknowledgment/reset, largest-text Show/Hide acknowledgment, cloud unavailable state, cloud restore/review/cancel/relaunch and unavailable app-protection setup.

The initial run passed 124/125 units and six of seven UI tests. One new unit assertion incorrectly required the target field to be the literal string `30` rather than the unchanged valid `30.0`; it now checks the numeric value. The largest-text UI test passed its actual feedback/visibility assertions but its cleanup searched downward for an earlier Interrupted row. Bounded reverse scrolling corrected that test helper. Neither finding was attributed to environmental flakiness or hidden by skipping a test.

Final review also added a session-ID check before delayed Hide feedback can update a different session, and cleared an old authorization denial before retry. The final run includes all 138 unit tests and four UI tests (the corrected largest-text flow plus the cloud/protection follow-ups), **all green**. The other six UI flows passed in the initial run. The standard Debug test build compiled the Watch dashboard change; no paired Watch behavior is inferred from compilation. No Release build or full-app suite was run for this bounded pass.

Native screenshots were visually inspected:

- [Show Session Activity acknowledged inside its control, largest accessibility text](session-activity-requested-largest-text.png)
- [Progress correction acknowledged in the safe-area strip](progress-acknowledgment.png)

Initial result: `/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.21_18-16-20--0600.xcresult`; final result: `/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.21_18-24-43--0600.xcresult`. Logs are `/tmp/rilova-action-feedback-tests.log` and `/tmp/rilova-action-feedback-final-tests.log`. The correct unit selector is `AvelaTests/IntentionSessionViewModelTests`; the initial selection used an incorrect shorter class name and those 13 tests were included in the final 138-test run.

Use the existing signed simulator command from SETUP.md with scheme `Avela`, the dedicated QA destination, `CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`, and the affected XCTest class/method selectors above. Test mutations never use the owner's normal simulator store. `git diff --check` and project plist lint pass.

## iPhone delivery

The signed Debug iPhone build succeeded. The temporary phone project's configurations were compared against the repository again; only Watch dependency/embedding differs. Before installation, the actual product's boolean Live Activity support, three privacy-purpose strings, deep signature and common team/App Group entitlements were checked. The app was installed **in place**, with no uninstall, data reset or fixture seeding. Physical response to the new controls is for the owner to confirm.

Automatic reopening was refused because the iPhone was locked; installation succeeded. Unlock and open Rilova manually, then try Show Session Activity on a running session. No successful post-update launch or real-device interaction is claimed. The phone-only build still excludes Watch installation; its UI source compiled in the standard simulator build.

Local delivery evidence: `/tmp/rilova-action-feedback-device-build.log`, `/tmp/rilova-action-feedback-install.*`, and `/tmp/rilova-action-feedback-launch.*`. Device identifiers remain in local artifacts. No commit, push, archive or upload was performed. Docs updated: MVP action-feedback acceptance, UX patterns, transient data-model state, compliance confirmation and SETUP verification link.
