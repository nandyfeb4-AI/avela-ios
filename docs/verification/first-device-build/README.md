# First signed iPhone build — October 21, 2026

## Verified

- Physical iPhone 17 Pro Max, iOS 26.6 (23G71), Developer Mode enabled.
- Apple Developer Program team `HT6JHUV6WP`; Xcode created an Apple Development certificate during provisioning.
- Main app, WidgetKit extension and protection monitor have valid development profiles with `group.com.example.Avela`.
- Inspected signed entitlements: all three use that team/group; HealthKit is app-only; Family Controls is app + monitor only.
- Signed Debug build succeeded, version 0.1.0 (1), display name Rilova, development bundle ID `com.example.Avela`.
- `devicectl` installed the app and launched it successfully without a debugger. A subsequent process query found the app and widget extension running.
- Read-only file metadata confirms the shared App Group is accessible and contains the SwiftData store. No database contents were read or changed for verification. No widget snapshot existed at the first check; the owner subsequently confirmed that the Welcome/setup screen is visible on the iPhone. Widget interaction is still to be confirmed.

The first standard-scheme attempt established three profiles but failed because their App Group lists were empty and no physical Watch was registered. The owner selected the team and shared group in Xcode for Avela, AvelaWidget and AvelaProtectionMonitor; profile inspection then confirmed the matching group in all three.

## iPhone-only build scope

The standard Avela scheme also embeds AvelaWatch. To avoid requiring a registered Watch for this first iPhone install, a **temporary project copy** lives at `/tmp/RilovaPhoneDevice/Avela.xcodeproj`. It removes only the app's Watch target dependency and Embed Watch Content phase. Production app source and the repository's Watch target remain unchanged. The app, WidgetKit/Live Activity extension and protection monitor are still built and signed.

The temporary project uses symlinks to the current workspace source directories, an empty `projectDirPath`, and a unique `RilovaPhone` shared scheme whose BuildableReference container points to that temporary project. Using an absolute `projectDirPath` with the original scheme failed scheme resolution; that abandoned setup was corrected before the successful build. The ordinary repository scheme still includes Watch and requires its separate provisioning before normal full-scheme device builds work.

Build command (replace the device identifier with the selected connected iPhone):

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project /tmp/RilovaPhoneDevice/Avela.xcodeproj -scheme RilovaPhone \
  -configuration Debug -destination 'id=DEVICE_UDID' \
  -derivedDataPath /tmp/RilovaPhoneDeviceBuild DEVELOPMENT_TEAM=HT6JHUV6WP \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
```

Installed product: `/tmp/RilovaPhoneDeviceBuild/Build/Products/Debug-iphoneos/Avela.app`.

## Evidence and limits

Build: `/tmp/rilova-phone-only-build.log` (`BUILD SUCCEEDED`). Install/launch logs: `/tmp/rilova-phone-install.log`, `/tmp/rilova-phone-launch.log`; machine-readable results `/tmp/rilova-phone-install.json`, `/tmp/rilova-phone-launch.json`. App/process and device metadata are under `/tmp/rilova-phone-*.json`; these local artifacts may contain device identifiers and are not copied into the repository.

This verifies development signing, installation, process launch and shared-container accessibility. It does not establish onboarding usability, widget response time, real Health imports, spoken Siri, app restriction expiry, accessibility or Watch behavior. No automated test writes were run against the owner's phone or simulator data. No permission or purchase was triggered by automation, and no cloud integration was enabled. Existing simulator stores were not reset or migrated.

No app-source behavior changed for this setup, so no regression test suite was rerun. Development Family Controls provisioning is **not** distribution approval; both the app and monitor still need that approval for a distribution build. Production identifiers, TestFlight/archive gates and real StoreKit products remain separate release work. No archive, upload, commit or push was performed.

## Owner launch confirmation

The owner confirmed **Welcome / setup screen** on the physical iPhone after installation. This confirms a rendered initial app screen, beyond process launch alone. Completion of onboarding, creation/logging and physical widget latency remain manual checks; no real-device timing result is inferred from the Welcome screen.

## Follow-up: temporary project configuration drift

The owner's enabled Make Room Live Activity did not appear. Inspecting the installed build's local product uncovered four missing Info.plist keys: `NSSupportsLiveActivities` and the Health, microphone and speech recognition purpose strings. The repository's Debug and Release settings were correct; the temporary iPhone project had diverged. Successful compilation/signing and visible onboarding did not validate those settings.

Regenerate the temporary project from the **current complete repository project**, preserving every build configuration, source/resource object and entitlement setting. Remove only the app's Watch dependency and Embed Watch Content reference. Compare the resulting project structurally: only those two arrays on the app target may differ. Before every install, inspect the **built app's** Info.plist for boolean Live Activity support and nonempty purpose strings, rather than relying on source settings or a previous simulator result. Do not reuse a stale temporary project as an independent source of configuration.

The follow-up verification is recorded in [Dynamic Island device packaging](../dynamic-island-device/README.md). Session records and existing user data must remain intact during an in-place update; retry presentation on the existing session rather than creating a replacement or reporting an outcome.
