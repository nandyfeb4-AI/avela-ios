# Avela privacy policy — owner-review draft

Draft date: 2026-10-04. This document describes the current native implementation;
it has not been published and is not a guarantee of legal or App Review outcomes.
The owner must review the scope, identify the responsible publisher and supply a
real support/privacy contact before publication. Remove this editorial introduction
and the publication checklist from the public policy.

## Avela and your information

Avela is an iOS habit and manual attention tracker. It does not require an Avela
account. Its core tracking works without an internet connection.

The app stores habit names, icons, categories, schedules, historical
configurations, completions, skips, archive periods, attention goals and their
historical definitions, manually entered usage and check-ins, phone-free sessions,
companion selection and local preferences on your device. These records support
the progress and history shown in the app. Avela does not transmit these tracking
records to a developer-operated server.

Avela does not include advertising or analytics SDKs, collect advertising
identifiers, automatically meter Screen Time, block other apps, or record audio.
Attention results depend on your manual records; a timer alone cannot establish
that you stayed phone-free.

## Local storage and system backups

Local records are stored using Apple's on-device persistence APIs. Avela does not
provide its own cloud synchronization or cross-device tracking-record service.
This does not disable Apple's device backup functionality: iOS may include app
data in a device backup under your Apple settings. Backups and restoration are
controlled separately through Apple and your device settings.

Archiving a habit hides it from active tracking while preserving its history.
Corrections and undo remove or change the selected record as shown by the app;
they are not an instruction to erase historical copies in system backups.

## Notifications

Habit reminders are optional local notifications. Avela requests notification
permission in response to enabling a reminder, not as a condition of using
tracking. You can disable a reminder in the app or change Avela's notification
permission in iOS Settings. Reminder settings remain local. Notification display
and delivery follow your device's notification and Focus settings.

## Widgets

Avela writes a local progress snapshot into an App Group container shared with
its own widget extension. The snapshot supports Home Screen and Lock Screen
widgets; it is not uploaded to a developer server.

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

Apple processes Premium subscription payments using your Apple Account. Avela
uses verified StoreKit transactions, including product identifiers, entitlement
expiration and revocation information, to determine whether Premium is active.
The app does not receive your payment-card details or maintain a developer
purchase-account server.

Apple's purchase services may require a network connection or Apple Account
authentication. Existing local tracking remains usable when the store is
temporarily unavailable. You can manage or cancel subscriptions in your Apple
Account subscription settings. Deleting Avela does not cancel a subscription.

## TestFlight beta testing

When you use a TestFlight build, Apple operates the beta distribution and feedback
service. Apple may share usage information, crash reports and submitted feedback
with the application provider. Screenshots or comments you submit can reveal
tracking details, so review them before sending. Avela does not separately upload
your habit or attention records through an analytics SDK.

See [Apple's TestFlight privacy information](https://www.apple.com/legal/privacy/data/en/test-flight/)
for Apple's description of the service. Apple purchases, backups and TestFlight
are governed by Apple's applicable terms and privacy practices.

## Retention and deletion

Avela keeps local tracking records until they are removed through the available
app controls or the local installation is deleted. Archiving retains history;
it does not erase it. There is currently no account or developer-server record to
delete.

To remove the local app installation and its app data, use iOS Settings to delete
Avela. Copies in previously created device backups may remain. Manage or delete
those backups separately through Apple's controls; uninstalling does not erase
all historical backup copies. Reinstallation from a backup may restore records.

## Changes and contact

The published policy should be updated when Avela's practices change. Adding
cloud synchronization, analytics, voice features or other off-device processing
would require a fresh privacy assessment and updated disclosures; none of those
features is described as currently active here.

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
