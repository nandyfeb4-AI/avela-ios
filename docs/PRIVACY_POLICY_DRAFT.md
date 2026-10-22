# Rilova privacy policy — owner-review draft

Draft updated: 2026-10-21. This document describes the current native implementation;
it has not been published and is not a guarantee of legal or App Review outcomes.
The owner must review the scope, identify the responsible publisher and supply a
real support/privacy contact before publication. Remove this editorial introduction
and the publication checklist from the public policy.

## Rilova and your information

Rilova is an iOS habit and manual attention tracker. It does not require an Rilova
account. Its core tracking works without an internet connection.

The app stores habit names, icons, categories, schedules, historical
configurations, completions, skips, archive periods, attention goals and their
historical definitions, manually entered usage and check-ins, phone-free sessions,
companion selection and local preferences on your device. These records support
the progress and history shown in the app. Rilova does not transmit these tracking
records to a developer-operated server.

Rilova does not include advertising or analytics SDKs, collect advertising
identifiers, automatically meter Screen Time, or save audio recordings. Ordinary
tracking never restricts apps; optional selected-app protection is described below
and remains disabled in the current Release configuration.
Attention results depend on your manual records; a timer alone cannot establish
that you stayed phone-free.

## Local storage and system backups

Local records are stored using Apple's on-device persistence APIs. Rilova does not
provide its own cloud synchronization or cross-device tracking-record service.
This does not disable Apple's device backup functionality: iOS may include app
data in a device backup under your Apple settings. Backups and restoration are
controlled separately through Apple and your device settings.

Archiving a habit hides it from active tracking while preserving its history.
Corrections and undo remove or change the selected record as shown by the app;
they are not an instruction to erase historical copies in system backups.

## Siri and Apple Shortcuts

Optional Siri and Shortcuts actions let you report a habit success or attention
minutes. Apple handles Siri and its voice processing; Rilova does not capture audio for Siri actions.
Your selected habit and budget names may be shown in Apple's system suggestions
and saved shortcuts. These reports are saved locally like your in-app entries;
they do not verify your behavior or automatically measure phone usage. Actions
open Rilova and may require device authentication. You control saved shortcuts
and automations through Apple's Shortcuts app.

## Optional Apple Health

If you connect a Build Up habit, Rilova requests read access to your chosen steps
or exercise-minute metric. It reads today's available total when you open the
app or refresh, and can log habit success once the chosen target is met. It does
not write to Apple Health, promise continuous background monitoring, or
automatically upload Health data. No accessible data can mean missing samples or restricted access;
manual tracking remains available.

Rilova stores the connection settings and resulting habit completions locally,
not raw Health samples. Disconnecting stops future imports and keeps existing
completions. Undoing an imported completion can be followed by a new import while
the connection remains active. Change Health permissions separately in Apple
Health; disconnecting in Rilova does not revoke Apple's system permission.
Rilova does not use Health information for advertising, sell it, or send it to a
developer-operated external service. This restriction on developer-operated
sharing is separate from a card you explicitly choose to export, described below.
Health-derived local records remain excluded from Rilova's optional cloud recovery.
Apple-controlled device-backup behavior must be checked for the final signed build.

## Optional progress sharing

You can preview a weekly progress card created on your device. It contains the
shown weekly consistency and eligible-habit count. You choose whether week dates
appear; habit names are off by default and appear only if you include them.
Aggregates may reflect habit successes imported from Apple Health. The card
does not include raw Health samples, private habit reasons, reflection notes or
detailed attention/session records.

Opening or editing the preview publishes nothing and sends no tracking data to
a Rilova-operated server. Only an explicit Share opens Apple's share sheet,
where you choose the recipient, app or other destination. The selected destination
then handles the card under its own practices; you can cancel before sending.
Rilova does not publish a public profile or automatically share progress.

## Notifications

Habit reminders are optional local notifications. Rilova requests notification
permission in response to enabling a reminder, not as a condition of using
tracking. You can disable a reminder in the app or change Rilova's notification
permission in iOS Settings. Reminder settings remain local. Notification display
and delivery follow your device's notification and Focus settings.

## Widgets

Rilova writes a local progress snapshot into an App Group container shared with
its own widget extension. The snapshot supports the Quick Log and Routine Home
Screen widgets; it is not uploaded to a developer server. Lock Screen and Dynamic
Island session Live Activities are a separate feature, described below.

Widgets can display progress and, depending on their configuration, habit names.
People who can see your screen may see those details. Choose widget placement and
tracking names with this visibility in mind. Removing a widget hides that surface;
it does not delete the underlying tracking record.

## Optional session Live Activities

After you explicitly choose Show Session Activity, iOS can show a phone-free
session countdown and your selected companion on the Lock Screen and Dynamic
Island where supported. The presentation contains session dates and an optional
animal choice, not your goal name or tracking history. It uses Apple's local
ActivityKit service, with no developer push server. Apple's system settings may
also make supported Live Activity information visible on paired devices.

Anyone who can see these surfaces may see the activity. Hide it without ending
local tracking, or disable Live Activities through iOS Settings. Elapsed time
never verifies phone use or automatically records a successful session.

## Purchases

Apple processes Premium subscription payments using your Apple Account. Rilova
uses verified StoreKit transactions, including product identifiers, entitlement
expiration and revocation information, to determine whether Premium is active.
The app does not receive your payment-card details or maintain a developer
purchase-account server.

Apple's purchase services may require a network connection or Apple Account
authentication. Existing local tracking remains usable when the store is
temporarily unavailable. You can manage or cancel subscriptions in your Apple
Account subscription settings. Deleting Rilova does not cancel a subscription.

## TestFlight beta testing

When you use a TestFlight build, Apple operates the beta distribution and feedback
service. Apple may share usage information, crash reports and submitted feedback
with the application provider. Screenshots or comments you submit can reveal
tracking details, so review them before sending. Rilova does not separately upload
your habit or attention records through an analytics SDK.

See [Apple's TestFlight privacy information](https://www.apple.com/legal/privacy/data/en/test-flight/)
for Apple's description of the service. Apple purchases, backups and TestFlight
are governed by Apple's applicable terms and privacy practices.

## Retention and deletion

Rilova keeps local tracking records until they are removed through the available
app controls or the local installation is deleted. Archiving retains history;
it does not erase it. There is currently no account or developer-server record to
delete.

To remove the local app installation and its app data, use iOS Settings to delete
Avela. Copies in previously created device backups may remain. Manage or delete
those backups separately through Apple's controls; uninstalling does not erase
all historical backup copies. Reinstallation from a backup may restore records.
Optional Rilova iCloud recovery copies also remain after uninstalling. Delete those
copies in Progress Protection before removing the app if you want to remove them.

## Changes and contact

The published policy should be updated when Rilova's practices change. Adding
cloud synchronization, analytics, voice features or other off-device processing
would require a fresh privacy assessment and updated disclosures. Optional private
iCloud recovery is described below and requires a configured signed build.

**Owner publication requirement:** add the responsible application-provider name,
a monitored privacy/support contact and the policy's effective date here. Do not
publish a fabricated email address or an unresolved placeholder.

## Publication and implementation checklist

- [ ] Owner reviews the actual final binary's features and storage behavior.
- [ ] Add publisher identity, monitored contact and effective date.
- [ ] Publish the approved policy at a publicly accessible HTTPS URL.
- [ ] Set the app's `AvelaPrivacyPolicyURL` Info value to that real URL. The native
      `PrivacyView` only offers the link when the configured URL is valid HTTPS.
- [ ] Add the same URL to App Store Connect's privacy-policy field.
- [ ] Reconcile policy, manifest, App Store Connect disclosures and review notes.
- [ ] Review device backup/removal behavior on the signed Release build.
- [ ] Remove owner-review notes before public publication.

Apple requires an accessible in-app privacy-policy link and App Store Connect
metadata link under [Guideline 5.1.1](https://developer.apple.com/app-store/review/guidelines/#privacy).
Local-only data and Apple's own collection are distinguished in
[App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/).


## Optional routines, progress and reflections

If used, Rilova stores manual quantities, elapsed timer state, smaller-action records, routine names/selected habits and weekly reflection answers locally. These can be included in Apple-managed device backups under your settings. They are not sent to an Rilova backend or analytics service. Removing a routine or reflection does not remove habit history.

If you enable Apple Watch quick logging, Rilova sends today's due habit names, icons and completion state to your paired Watch using Apple's WatchConnectivity. Reflection answers and Health samples are not transferred. Disabling sharing clears the Watch's shared snapshot when it reconnects; previously received information can remain until reconnect or expiry. Siri/Shortcuts can add amounts in a habit's configured unit, following explicit user commands and Apple's device authentication controls. Rilova does not capture audio for these Siri/Shortcuts actions.

Habit intentions linked to phone-free sessions are stored locally as identifiers and a creation timestamp. Session results are your manual reports, and never independently confirm a habit or phone-free behaviour. Manageable Week uses existing archive history rather than collecting a new behavioural profile.

## Optional private iCloud recovery

Rilova is local by default. If you explicitly enable Progress Protection in a
configured build, Rilova stores dated recovery copies in your Apple Account's
private CloudKit database. These include eligible habit history, manual attention
tracking, routines and appearance/companion preferences. They do not go to an
Rilova-operated server. Each copy also has a capture time and random installation
marker; this is not an advertising or hardware identifier. This is backup, not live synchronization between devices.

Health connections, whole health/fitness and Health-connected habits, habits with
Health-imported history, completion notes and private reflections are excluded.
Do not enter sensitive health tracking under another category to include it in
cloud recovery. Excluded data is not restored by this feature.

Copies use your iCloud storage and remain until you explicitly delete each copy
in Progress Protection. Deleting or editing local records does not rewrite earlier
copies. Turning off backup stops new requests but retains existing copies; an
upload already sent may finish. Uninstalling does not delete cloud copies.

Automatic uploads run after saved changes while Rilova can execute, up to once
every ten minutes. Offline, quota or account problems can delay them. The displayed
success date records an acknowledged upload, not a promise of continuous backup.
An iCloud account change revokes opt-in; re-enable it for the new account if desired.

Recovery requires explicit confirmation and an otherwise empty tracking
installation. Rilova does not overwrite or merge your existing tracking. Restored
reminders stay off, running timers pause at the snapshot, and unfinished sessions
receive no successful outcome. This feature is separate from Apple's whole-device
backup and does not guarantee recovery of excluded or not-yet-uploaded records.

Publication gate: review the configured Release binary and its off-device storage
against App Store Connect privacy responses; publish the approved policy and
contact before submission. The current placeholder build cannot access CloudKit.

## Local quick amounts and derived progress

Personal quick-log amounts are saved on your device as app preferences, separately for each habit and unit. They are not included in Rilova’s logical iCloud recovery copy; a new installation uses default amounts. Recorded history is separate. Lifetime progress and intention-review summaries are calculated from existing records without AI or analysis of private notes. Timer minutes are elapsed recorded duration, not monitored phone usage.


## Optional on-device reflection dictation — 2026-10-06

Rilova uses Apple Speech and AVFoundation when you explicitly start reflection dictation. Microphone and speech recognition permission are optional. Recognition must be supported on-device; no server fallback is used. Audio is transient and not saved. Only reviewed text added to a draft and explicitly saved becomes a reflection. Saved notes remain excluded from Rilova's logical iCloud recovery copies, while Apple device backups may include them. Earlier statements that Rilova never accesses the microphone are superseded for this feature. Typing remains available without permissions.


## Focus session presentation

Optional session Live Activities now support focus and phone-free sessions. The presentation includes only session timing and the selected companion, not private habit names or journal text. Neither timer monitors apps, verifies concentration, or records habit success.

## Optional private habit reasons

You can save an optional text reason for a habit, hide its reminders, edit it or remove it. The reason stays in local app storage and is excluded from Rilova’s logical iCloud recovery copies and widget, watch and Live Activity data. Apple whole-device backups are separate. No reason text is sent to an AI service or used to infer your mental state. Recommendations use recorded progress and configured actions only.


## Optional calendar planning

If you choose Plan Time in Calendar, Rilova prepares an event containing your habit name and selected start/end times. You review and choose the calendar in Apple's editor before saving. The event may be shared or synced according to that calendar's settings. Rilova does not read your calendar, include your private habit reason or history, retain event identifiers or infer completion from the event. Cancelling creates no Rilova tracking record.


## Optional app protection — development feature

If enabled in the shipping build, you explicitly allow Screen Time access for your own device and choose which distractions to restrict. Rilova uses Apple's opaque app/category/website selections locally; it does not read usage reports, infer behavior or send these choices to a server. Tokens and operational deadlines are excluded from Rilova recovery copies and system backups of those files. A monitor extension shares only minimal session identifiers/deadlines to release Rilova's restrictions. Stop Protection or system Screen Time revocation releases Rilova's control; unrelated limits may remain. Release currently leaves this optional feature unavailable until hardware testing and Apple distribution approval. Final published policy must describe the actual enabled build.
