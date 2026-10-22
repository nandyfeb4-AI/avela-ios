# Widget repeat-tap investigation — October 8, 2026

The owner reported an apparently ignored first Log tap followed by a save and foreground app launch. The installed owner widget executable UUID matched the baseline current build; an old binary alone does not explain this report. Owner history was inspected read-only, never reset or seeded. Native interaction checks used the dedicated QA simulator and its demo habits.

## Confirmed defect and fix

A native baseline tapped the completed checkmark and observed Rilova become foreground. The completed state used a noninteractive image (44pt wide) instead of the original 54 × 44pt Log button, leaving the old tap region to WidgetKit's default app-opening behavior.

The completed state is now a 54 × 44pt background refresh button. It records no additional completion and retains the original rectangular tap area. Its accessibility label names the habit and saved status; its hint explains refresh without opening Rilova. Habit-name links and quantity `+` links retain their deliberate app navigation.

Refresh preserves only an unexpired, current-day/current-time-zone acknowledgment pin whose expiry is within the original 30-second window. It does not extend that expiry. Quick Log requests fresh saved facts at expiry rather than enqueuing a captured snapshot for later replay. WidgetKit can defer that refresh and reordering. Routine still sorts pending steps before saved steps, so its completed step can move to a different row.

Files: `AvelaWidget/QuickLogWidget.swift`, `Avela/Core/Widgets/QuickLogHabitIntent.swift`. No schema, permissions, dependencies, widget kind or persistence identifiers change. MVP's optional background simple-check-in behavior is preserved.

## Verification and limits

All 547 unit tests passed on final source with simulator ad-hoc signing (`CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`). Quantity/smaller-action logging and widget-guide UI regressions also passed. Final native Quick Log verification passed: cold first taps saved Reading and Walk; two subsequent taps per saved control (including the former button edge) did not foreground Rilova. The shared completed-row view is also used by Routine, but this final pass verified Quick Log specifically. Read-only inspection of the QA shared database found two habits and exactly two completions after all repeated taps.

[Reading saved on Home Screen](reading-saved-home.png) · [Both saved on Home Screen](walk-saved-home.png). The [QA-only driver](native-qa-driver.txt) is retained as reproduction evidence, outside the shipping test source. It depends on preinstalled native widget placements and is not an automated test for arbitrary simulator state.

Final native log: `/tmp/rilova-widget-native-signed-final.log`; result: `/tmp/AvelaCodexMVP/Logs/Test/Test-Avela-2026.10.08_15-53-39--0600.xcresult`. Final unit log: `/tmp/rilova-widget-final-units.log`. Release builds successfully (`/tmp/rilova-widget-final-release.log`); app and widget binaries have zero matches for `AVELA_UI_TEST_STORE_PATH`, `AVELA_UI_TEST_SEED_FIXTURE`, `DebugFixtures`, and `AVELA_UI_TEST_LIVE_ACTIVITY`, with production Rilova strings present as a positive check. No full UI-suite rerun is claimed for this focused fix.

The signed update was installed in place on the owner's existing simulator and launched without fixture environment variables. No reset, uninstall or owner history changes.

Cold-process baseline tests saved Reading and Walk once on the first tap without foregrounding Rilova. They took approximately 6–8 seconds including XCTest synchronization and hierarchy queries, not a precise user-visible latency measurement. One widget sometimes displayed the older Log state after the other reflected the saved record; canonical shared facts were already saved. Immediate redraw is not guaranteed or claimed fixed.

Initial verification drivers were corrected to avoid selecting the other widget's duplicate control, to allow Routine's intentional row sorting, and to finish the QA app's optional onboarding. Unsigned native driver attempts could not access the App Group; they are not valid widget runtime evidence. The final verification used the documented Xcode ad-hoc signing command; manual re-signing attempts were discarded. These failed checks are not counted as passes. Temporary QA drivers are removed from the shipping test source after verification.

Apple documents interactive buttons and default widget navigation separately: [widget interactivity](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities), [widget links](https://developer.apple.com/documentation/widgetkit/linking-to-specific-app-scenes-from-your-widget-or-live-activity).

Real-device cold-start, local authentication and actual refresh scheduling remain hardware checks. No claim that every cause of the owner's first-tap delay has been eliminated. No commit or push in this pass.

## Superseded completed control

The owner subsequently approved explicit correction: the status-only refresh control is replaced by **Undo** for eligible simple check-ins. See [widget Undo](../widget-undo/README.md) for current behavior and verification.
