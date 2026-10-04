# Avela TestFlight readiness checklist

Prepared 2026-10-04. This is a release gate, not a declaration that Avela has
shipped, been approved, or completed physical-device verification. Leave items
unchecked until evidence exists for the actual Release candidate.

## Implementation and configuration distinction

Native code now covers local habits, manual attention budgets/windows/sessions,
history and weekly review, reminders, companion state/preferences, onboarding,
widgets and StoreKit subscription management. Source implementation alone does
not prove those flows on a signed device or through App Store Connect. The final
combined test result and remaining implementation exceptions belong in
`BUILD_PLAN.md` and `SETUP.md`; this checklist does not invent a passing result.

Original companion artwork and the distribution app icon require review before
being represented as finished. No permanent Dynamic Island mascot is planned;
The optional session Live Activity is now implemented; any distribution claim
must match the verified signed binary.

## Developer account and signing

- [ ] Active Apple Developer Program membership and App Store Connect access.
- [ ] Choose production app and widget bundle identifiers; replace development
      `com.example.Avela` identifiers consistently.
- [ ] Register a production App Group and replace `group.com.example.Avela` in
      both entitlements and `WidgetSnapshotStore.appGroupID` together.
- [ ] Enable App Groups for both app and widget; signed provisioning profiles
      contain the same group entitlement.
- [ ] Confirm the app embeds the widget extension with the same team.
- [ ] Verify a signed device build can read/write the shared widget container.
- [ ] Set user-facing version and a unique monotonically increasing build number.
- [ ] Review developer/seller information visible to testers and customers before
      publication; the owner wishes to keep personal promotion private.
- [ ] Create the App Store Connect app record for the registered bundle ID.

Apple describes membership and the Xcode distribution workflow in
[Distributing your app](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases).

## StoreKit and subscriptions

Current native identifiers are `com.avela.premium.monthly` and
`com.avela.premium.annual`. Free permits three active habits and one attention
goal; Premium permits unlimited new habits and attention goals. Existing tracking
and history remain usable after entitlement expiry. App Store Connect must match
these IDs and the implemented packaging, or code/configuration must change
together before testing.

- [ ] Complete applicable paid-app agreements, banking and tax setup.
- [ ] Create both auto-renewable products in one subscription group, with correct
      periods, storefront availability, prices, localizations and review details.
- [ ] Check localized price and billing period come from StoreKit, with explicit
      recurring-payment terms and accurate benefit copy.
- [ ] Confirm purchase cancellation, pending approval, verified success, restore,
      expiration/revocation and unavailable-store responses.
- [ ] Check both UI limit entry points and final writes, including onboarding;
      existing habit editing/logging and history must never be locked by expiry.
- [ ] Keep Billing Grace Period disabled until verified grace-period entitlement
      support is implemented and tested; current policy requires an unexpired transaction.
- [ ] Test renewal and restore on a signed device with sandbox products, beyond
      the local `.storekit` configuration and fake-service tests.
- [ ] Restore is user initiated. App startup must not trigger Apple Account
      authentication or depend on a network response before showing local data.
- [ ] Verify subscription access on another device using the same Apple Account;
      do not imply local habit data sync exists.
- [ ] Confirm the archive uses real StoreKit product lookup, not local test prices.

Apple requires clear subscription value, coherent upgrades/downgrades and usable
purchase flows; see [App Review Guidelines §§3.1.1–3.1.2](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase)
and [sandbox testing](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox).

## Privacy manifest and policy

`Avela/Resources/PrivacyInfo.xcprivacy` declares no tracking, no tracking domains
and no app-collected data. Local SwiftData records and shared-container widget
snapshots stay on device. StoreKit uses Apple's service; no custom networking,
analytics SDK, advertising SDK or mandatory user account was found in the
production source review. This is an implementation assessment, not a completed
App Store Connect disclosure review. Apple's definition treats solely on-device
processing differently from off-device collection, and distinguishes Apple's own
collection from the developer's practices. See
[App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/).

The required-reason API array is currently empty **because no direct covered API
call was found**, not because local-first apps are exempt. The reviewed production
calls to `FileManager` obtain an App Group directory, create a directory and test
file existence; JSON is read/written without reading file timestamps or disk
capacity. No `UserDefaults`, `@AppStorage`, boot-time, disk-space or file-timestamp
API call was found. Tests' temporary files are outside shipped targets.

- [ ] Register the manifest in the app's Resources build phase; include the same
      declaration in the widget bundle if its target shares these storage types.
- [ ] Re-run the source audit after all integration changes. Declare only actual
      covered APIs using Apple's approved reasons; do not add speculative reason
      codes for framework implementation details.
- [ ] Generate/review the archive privacy report and resolve validation warnings.
- [ ] Complete App Store Connect privacy responses from the actual final build;
      reassess if support forms, analytics, cloud features or other collection
      are introduced.
- [ ] Publish a real, publicly accessible privacy-policy URL and expose its link
      inside the app. Current in-app explanatory text alone is insufficient.
- [ ] Include local persistence, system device-backup behavior, deletion/retention,
      optional notifications, widget visibility and Apple purchases in that policy.
- [ ] Provide working support contact information and Terms of Use link.
- [ ] Explain TestFlight feedback/crash reports separately from app analytics;
      screenshots submitted by testers can contain personal tracking content.

Use Apple's [privacy manifest documentation](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
and [required-reason API guidance](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api).
Policy-link requirements are in [Guideline 5.1.1](https://developer.apple.com/app-store/review/guidelines/#privacy).
Apple describes beta feedback handling in [TestFlight & Privacy](https://www.apple.com/legal/privacy/data/en/test-flight/).

## Physical-device release verification

Record device, OS, build, steps and result for each check. Simulator screenshots
and accessibility-tree assertions cannot substitute for actual VoiceOver use.

- [ ] Fresh installation completes onboarding, including optional skips, first
      habit/attention creation, companion selection and reminder setup.
- [ ] Existing installation upgrades without erasing history or preferences;
      schema changes either migrate successfully or fail safely without deleting
      records. Never prescribe production data reset as an upgrade strategy.
- [ ] Airplane-mode launch, creation, completion/undo, usage/check-in/session
      logging, edits, archive/reactivation and history work; relaunch preserves them.
- [ ] Logging then immediately opening detail never stalls; background/foreground
      and tab navigation preserve screen identity and refresh data.
- [ ] Reminders prompt only on explicit enablement, denial causes no repeated
      nags, disabling/archiving cancels delivery, reactivation restores saved
      preferences, and permission changes in Settings are respected.
- [ ] Check local midnight, weekday/week boundaries, travel/time-zone changes and
      DST behavior against documented semantics; no unlogged attention becomes
      measured zero or a verified healthy status.
- [ ] Phone-free session finish is manually confirmed; elapsed time alone never
      certifies that the user avoided their phone.
- [ ] Add habit and attention widgets; verify empty/populated data, no stale
      claimed-good state, shared-container access and update after app mutations.
- [ ] Explicitly show a session Live Activity: inspect compact/minimal/expanded
      Dynamic Island and Lock Screen, disabled authorization, dismissal, privacy,
      companion-off fallback and foreground reconciliation after expiry. Check
      background stale content never certifies success and longer-than-eight-hour
      sessions remain usable without a Live Activity.
- [ ] Check Lock Screen widget readability and sensitive-information exposure.
- [ ] Light/dark and Increase Contrast remain legible; largest Dynamic Type fits
      without inaccessible actions or toast overlap.
- [ ] VoiceOver labels, focus order, activation and undo are usable; keyboard
      activation works for gesture-based entry rows.
- [ ] Reduce Motion disables unnecessary movement, and haptics-off preference
      suppresses completion feedback.
- [ ] Confirm iOS 17 fallbacks and supported iPad layout, not only the newest SDK.
- [ ] Original icon/companion art is approved, licensed and legible on device;
      no placeholder imagery or unsupported marketing claim remains.

## Archive and final quality gates

- [ ] Debug and Release builds succeed for the final source state.
- [ ] Appropriate unit/UI suites pass; attach exact commands and result bundle.
- [ ] No known high-severity defect: crashes, data loss, incorrect core progress,
      broken logging/undo/navigation, unusable purchases or inaccessible core flows.
- [ ] Release binary has no DEBUG-only store, seed or onboarding environment hooks.
- [ ] Inspect entitlements, privacy files, extension contents, icon and resource
      membership in a signed Release archive.
- [ ] Validate archive with Xcode Organizer; resolve signing/privacy failures.
- [ ] Answer export-compliance questions from actual cryptography/framework use;
      do not choose answers solely because no custom network layer exists.
- [ ] Owner approves the specific build and tester group before upload/invitation.

## Beta metadata and reviewer notes draft

Provide actual contact information, a description, features to test and any known
limitations. Invite the owner and spouse privately; a public tester link is not
necessary. Internal testers require eligible App Store Connect roles; external
testers use the external-testing workflow and Beta App Review. See
[TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
and [Apple's TestFlight page](https://developer.apple.com/testflight/).

Suggested reviewer notes, to adjust against the submitted build:

> Avela is a local-first habit and manual attention tracker. No account or server
> is required. Onboarding can be skipped. Create a habit from Today and complete
> or undo it with its row control. Create an attention goal from Today; duration
> budgets use manual minute entries, while protected windows and phone-free
> sessions use manual check-ins. The app does not monitor Screen Time or block
> other apps. Habit detail offers optional local reminders; declining notification
> permission preserves all tracking. Settings provides archived habits,
> companion preferences and the Premium purchase/restore screen. Free includes
> three active habits and one attention goal; verified StoreKit Premium unlocks
> unlimited new items. Existing data remains available when Premium ends.

Describe Live Activity only as an optional manual session timer; do not include
voice logging, Screen Time metering, sync,
medical outcomes or other post-MVP claims in metadata. Record the actual first
TestFlight upload/review result here only after it happens.
