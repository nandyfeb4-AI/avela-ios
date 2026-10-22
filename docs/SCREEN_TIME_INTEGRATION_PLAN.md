# Optional app protection — implementation and release gates

Owner-approved October 7, 2026. Native code is implemented for development, including the monitor extension. **Real blocking/background unblocking has not been verified on a signed iPhone. Release availability defaults to off.** This does not enable automatic Screen Time usage measurement.

## Experience

Make Room → Restrict selected distractions → Choose Apps & Websites → explicitly allow individual Screen Time access → select and Save → Start. Selected app/category/website restrictions are separate from the session timer, outcomes and habit logging. Protection is optional and free; ordinary sessions work without it. Settings → App Protection and session/Make Room screens offer Stop Protection. Stop releases Avela's named store without finishing a timer or logging success. Other Screen Time/app restrictions may still apply.

Only one protected session runs at once. This implementation accepts 15 minutes–8 hours; it doesn't round up a short habit session. An invalid/unprepared request is rejected before a session is saved. If registration fails after the canonical session save, the UI explicitly describes the saved session as unprotected and keeps its review path, rather than retrying or duplicating it. Shortcuts and ordinary Attention session starts remain unprotected; they never reuse authorization to silently restrict apps.

## Apple configuration

- Main app and **AvelaProtectionMonitor** have Family Controls and the existing App Group entitlement. Widget/Watch do not gain Screen Time entitlements.
- App/monitor placeholder IDs: `com.example.Avela`, `com.example.Avela.protectionmonitor`; shared group `group.com.example.Avela`. Replace all consistently for physical signing; the group constant appears in `ProtectionLeaseStore` and the existing widget store.
- Development requires active Apple Developer Program membership and valid development profiles. Apple's separate distribution approval is not required for direct Xcode development installs. [Apple configuration](https://developer.apple.com/documentation/xcode/configuring-family-controls).
- Request distribution approval for **both app and monitor extension**, with approved profiles, before TestFlight/App Store. The embedded extension/entitlements still require distribution approval even when a runtime switch hides the UI. If distributing without protection approval, omit the capability and monitor target from that shipping configuration; hiding the switch alone is insufficient. [Apple entitlement requirements](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement).
- `AVELA_APP_PROTECTION_ENABLED` is YES in Debug and NO in Release, expanded into the app Info.plist. Enable Release only after hardware lifecycle validation and distribution approval. Simulator uses an unavailable adapter with a truthful setup explanation; it never requests authorization or touches shared protection state.

## Lifecycle and privacy

FamilyActivityPicker owns private opaque tokens. Avela persists selected tokens only in its app-private, backup-excluded support directory. They do not enter SwiftData, logical recovery, widgets, Watch, Live Activities, analytics or a backend. Individual authorization never requires parental/family enrollment. No DeviceActivity events or usage reports are registered.

One minimal shared `ProtectionLease` holds random lease/session/goal IDs and captured start/end instants. A backup-excluded file coordinated with NSFileCoordinator serializes app/extension writes. The named ManagedSettings store is `avela.makeRoom`; it does not alter Apple's own limits or another application's stores.

The driver registers a nonrepeating DeviceActivity schedule before applying any shield. Date components capture Gregorian UTC instants so local midnight, travel/DST do not intentionally extend the session. Native scheduling errors fail without shields. The monitor clears only the matching current lease; late callbacks cannot clear a newer interval. It does not read SwiftData or record outcomes.

Foreground, saved-session changes, authorization changes and in-process deadlines reconcile expired/ended/missing sessions and absent monitors. Reconciliation never reapplies a restriction. Corrupt/unreadable operational metadata releases the named store instead of guessing. Explicit Stop remains available from setup even when metadata cannot be read; system Settings → Screen Time revocation provides an independent recovery path. Protection cannot establish verified focus/phone-free behavior.

## Hardware release gate

On a separate test installation with real entitlements:

- [ ] Individual allow/deny/revoke, empty/cancelled selection, explicit app/category/website Save.
- [ ] Chosen distractions blocked; unselected apps remain available; no usage collection.
- [ ] Keep Avela accessible for Stop; verify system permission revocation as fallback.
- [ ] 15-minute minimum, 8-hour maximum, unsupported short sessions and native registration failures.
- [ ] Timer expiry with Avela foreground, background, terminated and after device reboot/lock.
- [ ] Manual Stop, interrupted session, stale monitor callback, corrupted/absent lease, relaunch.
- [ ] Midnight/DST/travel/system-clock change; no extension callback delay leaves an expired shield active.
- [ ] Other Screen Time rules remain intact; protection never changes habit successes or self-reports.
- [ ] Signed Release/provisioning and Apple distribution approval for all relevant IDs.

**Simulator/fake-driver tests cannot close these gates or guarantee callback delivery.** The native adapter and UI are a development implementation, not certified production protection. If any expired restriction persists on hardware, keep Release disabled and fix the lifecycle before shipping.
