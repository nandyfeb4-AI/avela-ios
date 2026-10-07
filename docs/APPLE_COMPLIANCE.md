# Apple Compliance

## Optional habit ideas — 2026-10-05

The local starter catalog offers editable lifestyle examples, without medical
claims, prescribed Health targets or hidden permission requests. Selection
changes only an unsaved creation draft. Saving uses the existing creation limits;
no remote recommendations or third-party data service is used. Native symbols
are used inside the UI, not as application icons.

## Siri and Shortcuts — 2026-10-04

Optional AppIntents actions offer explicit, self-reported logging. They execute
in the foreground app with local authentication, existing repositories and no
microphone permission. Apple handles Siri voice processing; selected habit/budget
names may appear in system suggestions or saved shortcuts. Avela's generic
success dialogs do not speak those names. No health/Screen Time measurement is
implied, and session success remains manually confirmed inside the app.
Reviewer steps: create a habit/daily budget, find Avela in Apple Shortcuts, select
the matching action and record, run it, then inspect Today/History. Repeat habit
logging to verify no toggle/duplicate; repeat minute logging to verify additive
entries. Signed-device Siri recognition, lock/authentication and system discovery
remain release checks.

## Optional Apple Health — 2026-10-04

The app target has the HealthKit entitlement and `NSHealthShareUsageDescription`.
Only steps/exercise minutes are requested, only after explicit connection from an
active Build Up habit. There are no write types, microphone permissions,
background-delivery claims, medical claims, ad/analytics uses or off-device Health
transmission. SwiftData stores configuration and derived habit success, not raw
Health samples. Widget/Live Activity extensions do not request Health access.

Apple deliberately does not expose whether read access was denied: request flow
completion is not a grant, and no accessible samples remain unknown rather than
measured zero. Manual completion/skip always remains usable. Users disconnect
future imports in Avela and manage system permissions separately in Apple Health.

Reviewer steps: create a Build Up walking habit, open detail → Apple Health,
choose steps/target and connect. Grant/deny read access in the native prompt,
refresh with real samples, verify one completion/day at target and preservation
of a skip/manual completion. Disconnect and confirm history remains. Repeat with
exercise minutes, permission revocation, relaunch and local midnight. Signed-device
permissions/aggregation and developer provisioning are still unverified gates.
See [Apple Health authorization](https://developer.apple.com/documentation/HealthKit/authorizing-access-to-health-data).

This file is a product and engineering checklist, not legal advice.

## Core review posture

The app must have real, differentiated functionality.

Positioning:
- not a generic streak tracker
- not a reskinned template
- not a virtual pet with thin utility

Differentiating workflows:
- attention budgets
- flexible weekly habits
- recovery-oriented progress
- weekly insights
- stateful companion tied to actual behavior

## Minimum functionality

Before App Store submission:
- no dead buttons
- no placeholder screens
- no broken widgets
- no major "coming soon" surfaces
- no demo-only flows presented as complete
- subscription purchase and restore must work

## Privacy

Principles:
- collect the minimum data needed
- local-first by default
- no hidden data sharing
- permissions requested in context
- app remains useful when optional permissions are denied

If third-party analytics or AI is added later:
- document every data category transmitted
- update privacy disclosures
- avoid sending habit content unless necessary

## Notifications

- request permission in context
- no repeated nags after denial
- notifications must be user-configurable

## Screen Time

Future integration may require Apple capabilities / entitlements.

Do not block V1 on Screen Time access.

Architecture must isolate Screen Time-specific APIs behind an adapter.

Do not imply capabilities that Apple has not granted.

## Live Activities / Dynamic Island

Use only for genuine active, time-bound experiences.

Appropriate:
- active phone-free session
- focus session with a known end condition

Avoid:
- permanent mascot residency
- fake ongoing activity

## Subscription rules

Must:
- clearly communicate price and billing period
- clearly explain premium value
- support restore purchases
- avoid manipulative scarcity
- avoid obscuring free functionality

## Health / medical claims

Do not claim:
- treatment
- diagnosis
- improved mental health outcomes
- clinically validated behavior change

Use lifestyle/productivity language.

## App Review notes

Prepare reviewer notes explaining:
- core product purpose
- attention-budget workflow
- how manual attention logging works
- why the app is differentiated from a generic habit tracker
- any optional capabilities and how to test them
- subscription test path if required

## Feature compliance template

For every new significant feature record:

```text
Feature:
User value:
Data used:
Data leaves device?:
Permission required:
Apple capability / entitlement:
Review risk:
Mitigation:
Reviewer test steps:
```

## Phone-free Live Activity implementation — 2026-10-04

The user explicitly requests system presentation from an active phone-free
session. ActivityKit authorization is respected; denial/request failure never
blocks or ends local tracking. No remote push, backend, notification-permission
prompt, frequent-update entitlement or permanent pet surface is used.

The extension shows captured start/end dates and an optional companion, not goal
names or history. Tapping returns to Today. Check-in remains inside the app.
Timer expiry never asserts kept/healthy or modifies a session outcome.
Reconciliation ends expired/interrupted activities when the app can execute and
never recreates a dismissed activity. Background suspension prevents guaranteeing
exact scheduled termination; `staleDate` marks expired content neutrally while
iOS controls presentation lifetime (maximum eight active hours). Longer local
sessions remain supported, with a clear unsupported Live Activity message.

See [Apple ActivityKit](https://developer.apple.com/documentation/activitykit)
and [Live Activity lifetime](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities).
Signed-device privacy, authorization and dismissal checks remain release gates.

### Actionable local reminders

Native UNNotificationCategory/UNNotificationAction uses foreground review and
authenticationRequired. No background/automatic completion, new permission or
remote push service. Categories register at startup without requesting access;
permission still requires explicit reminder enablement. Previews remain generic
(no habit name); current habit identity is shown only inside the unlocked app
before confirming success. An archived or non-due habit cannot be logged; simply opening any reminder
never logs. Real-device lock-screen/Face ID checks remain required.


## Progress and Watch expansion — 2026-10-05

Manual quantities and elapsed timers are user reports, not verified activity or medical targets. Smaller actions do not imply full completion. Restart plans require explicit habit selection and do not automatically change other commitments. Historical corrections require named date confirmation and disclose metric changes.

WatchConnectivity sends only due active habit IDs/names/icons/completion state and day/expiry metadata after the phone-side toggle is enabled. No reflection, Health samples, attention entries or private notes are transferred. Protected-data availability gates paired writes; no per-action biometric guarantee is claimed. Disabled consent sends an empty context; a disconnected Watch may retain an earlier snapshot until reconnect or expiry. Messages are not queued as offline completions. Watch UI and background delivery must be verified on a signed paired device. No new microphone, network service, analytics SDK or permission prompt.

Make Room links a habit intention to an explicitly started session without inferring habit success or automatically starting its Live Activity. Manageable Week pauses only a named habit after confirmation; restarts never manufacture check-ins or hide earlier misses.

## Factual reflection context

Avela performs no generative AI, journal-text analysis or off-device inference. Recorded counts are computed locally from the same tracking records used by Insights. They describe check-ins rather than verified real-world behavior or causation. Notes do not influence suggestions. Apple may use its own voice-processing technology for optional Siri; that is distinct from an Avela AI feature. No new permission, entitlement or transmission is added.


## Optional private iCloud recovery — 2026-10-05

Owner approved optional automatic backup; this does not enable live sync or a
third-party backend. Core tracking remains local and usable without iCloud.
Explicit opt-in is bound to the current Apple cloud account and revoked on
account change. Only a successful acknowledged upload sets the success date.
Uploads use CloudKit's private database, never a public database.

[App Review Guideline 5.1.3](https://developer.apple.com/app-store/review/guidelines/#health-and-health-research)
prohibits personal health information in iCloud. The recovery serializer excludes
Health connections, whole health/fitness habits, every habit with Health-imported
history, completion notes and private reflections. Downloaded snapshots are
validated against these same restrictions. Do not categorize sensitive health
tracking as an ordinary eligible habit to bypass these exclusions. No health
classification by AI or inspection of private text is performed. Exclusions are
explained before opt-in and restore; this is not a backup of all app data.

CA92.1 declares access to app-owned UserDefaults (including Watch preferences);
it does not authorize unrelated access. App and Watch bundle resource membership
is configured. Archive privacy-report validation remains required. Private
CloudKit storage must be assessed in the actual App Store Connect privacy
responses; a private database is not a blanket exemption from disclosure.

Release gates: real container and signed provisioning, development/production
schema deployment, signed-device upload/offline/quota/account-change/recovery
checks, and review of Apple's device-backup handling for Health-derived local
records. The current placeholder build does not initialize CloudKit. Publish a
working policy/contact and supply reviewer instructions before submission.
No acceptance guarantee is implied by passing simulator tests.

Reviewer steps: enable Progress Protection in Settings on a configured signed
build, save an eligible habit and manually Back Up Now, inspect the success date
and Recovery Points. Confirm Health exclusions, disable without deleting copies,
then restore only on an otherwise empty test installation. Review/Cancel must
write nothing. Confirm preserves IDs/history, leaves reminders off, pauses timers
and never fabricates session success. Delete a selected cloud copy explicitly.

## Progress enrichment compliance — 2026-10-06

Lifetime totals, quick amounts and the intention review use existing local records and app-owned preferences. No AI, analytics, SDK, permission or background monitoring is added. Timer duration and reported kept outcomes are explicitly unverified; no phone-free/saved-time or behavior-change claim is inferred. Notes are not analyzed. Presets use the existing UserDefaults required-reason declaration (CA92.1). Existing Health exclusions, opt-in cloud recovery and release-configuration gates continue to apply.

## Native UI polish — 2026-10-06

This pass changes presentation only. Manual/self-reported attention and session provenance remain explicit, with no claim of saved or verified phone-free time. Purchase/restore controls, consent and privacy disclosures remain accessible. No SDK, tracking, permission or data handling change is introduced. Physical accessibility verification remains a release gate rather than an inferred claim from simulator checks.

## Static atmospheric scenery — 2026-10-06

Original code-drawn scenery is decorative and local. No copied competitor assets, AI runtime, collection, transmission, permission, entitlement or dependency is added. Manual attention/session labels remain explicit. Existing physical accessibility and signed-integration release gates remain open; artistic styling makes no health/adherence claim.

### Recovery card presentation — 2026-10-06

This slice reuses recorded progress and existing support tools. No new data collection, permission, remote processing, subscription gate or Live Activity behavior. Smaller-action effort is explicitly separate from success. Native accessibility controls and persistent Undo at accessibility text sizes complement, but do not replace, physical accessibility verification.

### Visual Insights presentation — 2026-10-06

Charts visualize existing recorded data locally. Manual attention is explicitly reported, with missing days unknown; habit consistency and usage coverage are separate. No causal/medical claims, AI, collection, permission or commercial gate is added. This is native simulator implementation evidence; physical accessibility verification remains pending.


## Optional reflection dictation — 2026-10-06

Owner-approved microphone capture is limited to explicit Start Dictation in the reflection editor. NSMicrophoneUsageDescription and NSSpeechRecognitionUsageDescription explain editable reflection transcription. Permission denial never prevents typed reflections or habit tracking. No prompt occurs simply by opening the editor or dictation preview. Check SFSpeechRecognizer.supportsOnDeviceRecognition and isAvailable before authorization/capture and set requiresOnDeviceRecognition=true on every request. Unsupported device/language fails closed; do not fall back to Apple's server recognition. Audio buffers are transient, with no file/analytics/LLM upload. Stop removes the audio tap, cancels recognition and deactivates the audio session on Stop, Cancel, dismissal, background, interruption, errors and a 55-second limit. Cancellation during permission waits invalidates the capture token. Late results cannot change review text. Saved text is private reflection data under existing backup exclusions. Earlier no-microphone statements describe the earlier build or other integrations and are superseded for this optional feature.

Primary references: [on-device capability](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition), [required on-device request](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition), [microphone permission](https://developer.apple.com/documentation/avfaudio/avaudioapplication/requestrecordpermission(completionhandler:)). No change to current tracking/collection privacy manifest declarations: audio/text are not sent off-device by this feature. Actual locale support, denied/granted permission, interruptions and hardware microphone delivery remain physical-device gates; simulator UI review tests do not prove transcription.


## Focus session presentation — 2026-10-06

The owner-approved Focus Session permits other app use and uses the existing locally recorded, manually reported session lifecycle. It requests no Screen Time/Family Controls capability and makes no concentration verification claim. Live Activity presentation is explicitly selected and identifies focus versus phone-free without exposing the habit name. Duration/system availability limits remain unchanged. Timers never grant habit completion or mark other apps blocked. New session-goal creation uses the same subscription creation policy, without deleting or restricting existing history on expiry. No new permissions, remote service, tracking or audio capability is introduced by this flow.

## Differentiation privacy and truthful presentation

Private habit reasons are local optional text, excluded from Avela logical cloud recovery and shared watch/widget/Live Activity data. This enrichment requests no new permission and adds no third-party service. Momentum and recovery suggestions are deterministic projections of persisted tracking, not health advice or AI inference. Timer starts are identified as starts, never verified focus or habit success. No automatic resumption date is promised. Photo memory remains unimplemented.

## Interactive Quick Log widget

Uses native WidgetKit Button(intent:), App Intents and existing App Group JSON only; no added entitlement, microphone, tracking, analytics or dependency. The app owns all database writes. LiveActivityIntent selects app-process execution without opening UI or creating a Live Activity; see [Apple's WidgetKit interactivity documentation](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities). Actions require local device authentication; locked-device behavior remains under iOS control. Habit names/progress are marked privacy-sensitive and the optional setup guide explains Home Screen visibility. Artwork/private habit memories are not added to Quick Log. Provisioned device/App Group checks remain necessary before distribution.


## Two focused widgets — 2026-10-07

Routine names/IDs/order join the existing app-exported shared widget projection for explicit Home Screen selection. AppEntity queries read only JSON, never SwiftData in the extension. No reason/photo/Health sample/reflection export, new permission, entitlement, SDK or remote processing. Native configurable widgets and app-process logging retain local-device authentication and canonical capability guards. Individual logging is explicit; no routine bulk success or false attention measurement. Existing Live Activity behavior remains time-bound and unchanged.
