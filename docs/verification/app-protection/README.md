# Optional app protection verification

October 7, 2026. Owner-approved native development implementation; no third-party dependency or canonical model migration.

## Added

`Features/AppProtection`: Foundation lease/validation, coordinated private operational store, observable lifecycle orchestration, native FamilyControls/ManagedSettings/DeviceActivity adapter, explicit selection/setup and Stop controls. `AvelaProtectionMonitor` is an embedded native Device Activity Monitor extension. Main app/extension capabilities, Make Room start validation, session/Settings Stop entry points and root reconciliation are wired.

Default Debug exposes development setup. Simulator shows an unavailable explanation through an adapter that never accesses shared protection state. Release runtime availability is disabled until device verification; the embedded entitlement still requires Apple's distribution approval before TestFlight.

## Tests and limits

AppProtectionTests cover duration/permission/selection guards, unavailable/denied authorization, captured session identity, Stop without outcomes, overlap refusal, monitor-registration failure, exact expiry, revocation, unavailable/ended session, clock rollback, disk reopen/backup exclusion, corrupt state repair, stale callback identity, pre-save validation and post-save partial failure through the real Make Room repositories.

Native UI coverage verifies simulator availability without a permission/chooser action and preservation of ordinary Make Room/Calendar flows. Actual FamilyActivityPicker selection, restrictions, background monitor delivery, reboot and system revocation require a signed iPhone and remain unverified. No full app UI suite is claimed.

## Results

- 545 unit tests passed, zero failures.
- Three targeted UI tests passed: unavailable simulator setup, Make Room with separate habit logging, and Calendar cancellation with no session/completion mutation.
- Debug simulator and Release iPhoneOS builds succeeded. Final UI-copy changes were rebuilt separately.
- Project integrity: 227 Swift sources, zero issues. Project/extension plist validation and `git diff --check` passed.
- Release availability key is `NO`; Debug is `YES`. Store-path/fixture environment hooks and `DebugFixtures` are absent from Release app/widget/monitor binaries.

[Simulator setup screenshot](simulator-setup.png) shows the honest unavailable state. It is not evidence of functioning device shielding.

Device release gates: native selection, shield application, timed release with app terminated, reboot, permission revocation, keeping Avela accessible, and signed App Group provisioning. No actual app restrictions were exercised in the simulator. Release's runtime flag does not remove embedded restricted entitlements: Apple distribution approval is required for both app and monitor before TestFlight, or those capabilities/extension must be omitted from the shipping configuration.

This work has not been committed or pushed.
