# Luminous Tide — October 21, 2026

This pass implements the owner-approved coordinated redesign and the First/Next
items in the [competitive research](../../../design/exploration/expressive-refresh/RESEARCH.md).
That survey distinguishes official screenshots, publisher descriptions and our
design judgments across 14 habit/routine products and three adjacent products.
It does not establish sales, retention or measured usability.

## Implemented journeys

- **Today:** an illuminated selected-theme header, current-day progress, an
  immediately accessible week calendar, a full month/day review, clear Log and
  Undo controls, saved quantity increments, one optional pinned habit, My
  Routines and My Day Changed. Browsing dates never logs or changes Today's date.
- **Creation:** 40 editable habit ideas, eight groups and four collections;
  check-in, amount or timed setup; a captured-unit target and optional smaller
  action in the first deliberate Save. Health remains a contextual opt-in after
  creation, rather than a permission requested by browsing an idea.
- **Routines:** four cancellable starter drafts using a few existing active
  habits. Saving a group is separate from starting it or logging its habits.
- **Detail and calendar:** primary logging and Make Room actions appear early;
  dates lead the calendar, followed by compact streak facts and original theme
  scenery. Flexible-weekly outcomes, skips, pauses and unknown dates retain
  their distinct meanings. Historical corrections show their selected date.
- **Make Room:** a session composer with honest Focus/Phone-Free descriptions,
  reviewed 15/25/45-minute drafts, optional protection and Live Activity controls
  next to Start, and feedback for the requested operation. Planning, starting,
  reporting an outcome and logging the linked habit remain separate actions.
- **Insights:** Week, Rhythm and Activity lenses; twelve completed-week
  snapshots, resolved-opportunity weekday bars, captured-unit quantities,
  self-reported session outcomes and an annual/monthly recorded-activity map.
  The existing comparable-cohort trend is unchanged. Names default off in the
  optional local share preview; an explicit Share opens the system sheet.
- **Onboarding:** six illustrated native stages, scalable display type, crisp
  existing companion artwork, reachable Continue and optional skips. No new
  account, permission prompt, subscription requirement or pet-care obligation.
- **Shared polish:** selected-theme gradients, original still ribbon contours,
  readable opaque cards, bounded press/progress transitions, consistent action
  hierarchy and matching History, Settings, attention detail and entry forms.

The reading surfaces stay stable. Decorative artwork is hidden from
accessibility; Reduce Motion, Reduce Transparency, Increase Contrast and large
text have deliberate alternatives. Native minimum hit regions are checked
without suppressing calendar-arrow findings.

## Data and privacy boundaries

There is no new schema, backend, third-party package, permission or generative
AI. New reports derive from canonical facts. Partial quantities and smaller
actions are recorded effort, never fabricated full success. A quick-amount Undo
identifies its exact entry; stale day/target/configuration guards prevent a
displayed shortcut from writing against changed facts. Habit creation saves its
initial existing activity-configuration model with the habit in one operation.

Opening a share preview uploads nothing. Sharing can deliberately disclose
selected aggregate progress, including an aggregate derived from connected
Health habits; the local privacy screen explains this. Reasons, reflection
text, Health samples and detailed attention/session records are excluded.

## Verification record

The rebuilt **full unit suite passes 627 tests**. All **119 distinct native UI
tests have passing executions** across the unfiltered sweep and subsequent
focused repairs. This is not a claim that one final unfiltered command passed.
The [machine-readable run record](test-results.json) retains initial failures,
subsequent executions and the latest result for every UI case.

The first sweep passed 622 unit tests and 108 of 118 UI tests. It exposed real
hit-region, accessibility/reflow and first-screen action-placement problems,
alongside stale test navigation through the expanded form. Repairs retained
the behavior assertions and unsuppressed native audits. Five further unit
regressions cover first-day correction context and stale simple controls; an
additional UI case covers first-day and historical correction review without
saving. The final affected/new light sweep passed 29 of 31 cases, followed by
passing calendar and quantity-logging reruns for its two remaining failures.
Six actual-dark flows subsequently passed with zero failures.

Native review also found overlapping chart-axis dates at accessibility text
sizes. Long-range plots now use readable recorded-value alternatives at those
sizes; normal-size plots and factual calculations are unchanged. Both report
flows pass again in dark mode, including an assertion for that alternative;
the final normal report flow also passes in light mode. The repaired chart
captures replace earlier overlapping-axis/framing captures in the gallery.

The dedicated QA device is an iPhone 18 Pro Max simulator, iOS 27.0, using
Xcode 27.0 (`27A266a`). UI stores are uniquely redirected DEBUG stores. No run
resets, seeds or tests against the owner's simulator or iPhone progress.

### Findings fixed during verification

- Calendar arrows now expose their complete 44-point hit regions. Calendar
  metric labels and values form one readable accessible element rather than
  clipping scaled numerals.
- Onboarding captions and creation headings grow vertically. Schedule controls
  reflow before crowded intermediate text sizes, retaining weekday selection.
- All four recovery actions are available to native accessibility queries;
  the nested lazy grid that omitted its second row was replaced by an eager
  small grid. Labels own their full hit regions.
- The companion sits before the week strip and habit list, with logging still
  reachable in the initial populated viewport.
- A birth-day calendar review uses the habit's first civil day, rather than
  rejecting midnight as earlier than its creation instant.
- Stale Log/Undo controls recheck the current day, active schedule, captured
  configuration and exact record. They cannot delete a replacement or another
  day's fact. Quantity Undo retains independent entries and survives relaunch.

### Native previews

Open the [screenshot gallery](index.html), which offers light/dark filters and
full-size links, or browse the [screenshot index](screenshots.json). Captures use
fictional verification data. Their native PNG pixels and proportions are
unchanged; the gallery only scales their display. Dates and visible amounts are
test facts, not production-user data. Motion and haptics require hands-on use.
There are 44 selected captures: 25 light and 19 dark, including large-text views.
A self-contained copy is on the local Desktop in **Rilova Luminous Tide Preview**.

Local result bundles and logs use the `/tmp/rilova-luminous-` prefix. The run
record identifies the unfiltered regression, rebuilt units/audit, form reflow,
final light, calendar follow-up, logging follow-up and actual-dark runs. Recreate
the full sweep with the command in [SETUP](../../SETUP.md#luminous-tide-candidate--october-21-2026).

### Release and connected iPhone

- The complete repository scheme builds in unsigned iPhoneOS **Release**,
  including Watch, widget and protection-monitor targets. The
  [binary inspection](release-inspection.json) finds zero matches for the UI-test
  environment prefix, fixture/store hooks, `DebugFixtures`, fake-cloud provider
  or `premiumReports` in all four executables. Release app protection remains
  disabled (`AvelaAppProtectionEnabled = NO`), as required by its existing gates.
- A fresh temporary iPhone-only harness preserves the current project settings,
  source references, widget and protection monitor; only Watch embedding and its
  dependency are omitted for the phone without a registered Watch. It builds
  successfully against the connected iPhone 17 Pro Max on iOS 26.6. This does not
  change the repository project or production identifiers.
- Signed app/widget/monitor binaries pass deep strict signature verification.
  [Capability inspection](device-build-inspection.json) confirms matching team
  and App Group, app/monitor development Family Controls, app HealthKit, Live
  Activity support and microphone/speech/Health purpose strings.
- `devicectl` confirms the update installed **in place**, without uninstalling,
  resetting or seeding the phone. Automatic foreground launch was denied because
  the phone was locked. Unlock it and open **Rilova** to review the update.
  Existing users retain completed onboarding; the new first-run sequence is
  included in the preview gallery rather than forced on update.
- Project lint and [membership/resource integrity](project-integrity.json) pass:
  235 Swift files, all expected target memberships, 25 asset JSON files and eight
  referenced asset filenames; `git diff --check` is clean.

Local build logs are `/tmp/rilova-luminous-release-build.log` and
`/tmp/rilova-luminous-phone-build.log`. The corresponding app output is under
`/tmp/RilovaLuminousPhoneBuild/Build/Products/Debug-iphoneos/Avela.app`.

## Remaining release gates

Simulator layout and accessibility audits do not establish physical VoiceOver
focus, haptics, OLED appearance, Always-On behaviour, device performance or
real integration authorization. Existing signed Health, notification, Siri,
Screen Time, StoreKit, Watch and CloudKit distribution/device checks remain in
the release checklist. App Store submission and distribution entitlements are
separate from a successful local build.

Every-N-days/monthly schedules and upper-limit quantity goals are explicitly a
separate domain slice in the research; this visual and creation pass does not
claim those scheduling semantics.
