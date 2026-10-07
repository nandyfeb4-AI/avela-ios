# Data Model

## Habit starter library — 2026-10-05

`HabitStarter` is a bundled, Foundation-only catalog of eight editable ideas.
Catalog IDs identify menu entries, never persisted habit UUIDs. Selecting one
fills the existing creation form's draft fields; only explicit Save reaches the
normal repository via Today/onboarding and its existing free-tier checks. Back
navigation preserves the current draft, and cancelling the creation sheet writes
nothing. Existing-habit editing does not offer catalog replacement.

Ideas cover movement, learning, quiet pauses and reduced scrolling. Daily and
flexible-weekly schedules are editable defaults, not medical prescriptions.
Cut-down ideas retain avoidance polarity and the existing “Log success” wording.
Optional Health connections and reminders are separate, explicit actions. No
schema change, starter metadata, tracking event, network fetch or auto-creation
is introduced. Selection is input collection; business/persistence logic stays
in the current feature state and repositories. The library uses native search,
SF Symbols, scalable text, full-row 44pt minimum targets and semantic colors.

## Siri and Shortcuts enrichment — 2026-10-04

Siri actions introduce no schema change. App-target App Intents and entity queries share
`AppPersistence.liveContainer` with app launch. All writes use the same main
context on the main actor; no separate extension or shared SwiftData writer.
The DEBUG test-path override moved into that container resolver and remains
compiled out of Release. Entity queries return stable UUIDs, not a first matching
name, so duplicate names never silently choose a record.

Log Habit Success checks current-day due state, creation and archive status,
replaces an excused skip just like Today, and is idempotent. Existing completions
retain their source; new shortcut records use the existing persisted raw value
`shortcutFuture` to avoid changing older decoding. That legacy tag now represents
actual shortcuts. Log Attention Minutes accepts finite values in (0, 1440], only
for existing daily duration budgets, and adds a manual entry per invocation.
Explicit voice reports remain manual, not automatically measured screen usage.
Existing correction, history and metrics consume these same records.

Intents open the app and require local device authentication. Selected entity
names are exposed to Apple's Siri/Shortcuts system; success dialogs omit names.
Avela neither records audio nor invokes an AI/network service. Entity queries
retrieve active habits and duration budgets; execution revalidates stale IDs.
Repository errors become safe user messages with private diagnostics. Dedicated
post-write notification refreshes visible projections in an already-active app.

## Apple Health enrichment — 2026-10-04

One new SwiftData model, `HealthHabitConnectionRecord`, stores one optional
connection per habit: unique habit UUID, connection UUID, metric (`steps` or
`exerciseMinutes`), positive bounded target, and connection timestamp. Updating a
connection replaces its UUID, preventing a suspended query for an old target from
writing after reconfiguration. No raw Health samples or totals are persisted.
These settings are prospective import rules, not historical schedule snapshots;
changing/disconnecting them never changes recorded completions or habit metrics.

Imports create ordinary `Completion` records with the new `healthKit` source.
The timestamp/day key represents when Avela detected success, not a fabricated
sample time. Existing source raw values remain unchanged. A disk-backed regression
opens the previous 12-model schema with this additional model without a reset,
verifying habit preservation. That integration schema had 13 model types; the appearance enrichment below adds a fourteenth.

Only explicitly connected, active Build Up habits can import. Refresh reads the
current local day through the refresh instant using HealthKit cumulative
statistics, when the app opens/returns active or the user taps Refresh. Existing
activity earlier that same day can meet a newly connected target. Habit progress still measures recorded commitments; a day with no foreground
check is not retroactively inferred as a target success. No backfill,
raw phone/watch sample summing (see [Apple DTS guidance](https://developer.apple.com/forums/thread/759709)), background-delivery entitlement, automatic
permission prompt on launch, Health writes, upload or external service exists.
Skips and existing completions are authoritative; imports never replace either.
Due-day evaluation still uses the historical habit configuration. Flexible weekly
habits count at most one imported completion per local day.

The permission request completing does not establish granted read access.
Missing/inaccessible samples remain unknown; zero/below-target values never create
failures. Disconnect and configuration identity are rechecked after async reads,
as are archive/polarity and the current local day. A query completing after local
midnight cannot retroactively log yesterday. Unknown access and provider errors
leave manual tracking available. Connections survive habit archival but do not
read/import while archived; reactivation resumes prospective checks.

Undoing a Health completion while still connected may import again at the next
refresh if the target remains met. The setup screen explains disconnecting to
stop this; disconnecting itself retains imported history. Reopening the app is
required for suspended-app updates; signed-device Health data and permission
checks remain release gates, independent from fake-provider unit tests.

The model below is conceptual. Exact SwiftData declarations may evolve without changing domain semantics.

## Habit

Fields:
- id: UUID
- name: String
- iconName: String
- category: HabitCategory
- polarity: HabitPolarity
- schedule: HabitSchedule
- createdAt: Date
- updatedAt: Date
- archivedAt: Date?
- reminderSettings: ReminderSettings?
- sortOrder: Int

## HabitPolarity

- positive
- avoidance

## HabitSchedule

Cases:
- daily
- weekdays(Set<Weekday>)
- timesPerWeek(Int)

Future:
- custom intervals only if required

## Completion

Fields:
- id: UUID
- habitID: UUID
- occurredAt: Date
- localDateKey: String
- source: CompletionSource
- note: String?

CompletionSource:
- app
- widget
- shortcutFuture

## Skip

Fields:
- id: UUID
- habitID: UUID
- localDateKey: String
- reason: SkipReason?
- createdAt: Date

## AttentionGoal

Fields:
- id: UUID
- name: String
- appOrCategoryLabel: String?
- type: AttentionGoalType
- targetValue: Double?
- unit: AttentionUnit?
- protectedWindowStart: TimeOfDay?
- protectedWindowEnd: TimeOfDay?
- createdAt: Date
- updatedAt: Date
- archivedAt: Date?

## AttentionGoalType

- maxDurationPerDay
- noUseBeforeTime
- phoneFreeUntilTime
- phoneFreeSession

## AttentionUsageEntry

Fields:
- id: UUID
- attentionGoalID: UUID
- amount: Double
- unit: AttentionUnit
- recordedAt: Date
- localDateKey: String
- source: AttentionUsageSource

AttentionUsageSource:
- manual
- screenTime

## HistoricalTargetSnapshot

Needed where goal edits could make past data ambiguous.

Fields:
- id: UUID
- ownerID: UUID
- effectiveLocalDateKey: String
- serializedTargetDefinition or normalized target fields

Prefer normalized fields where practical.

## CompanionProfile

Fields:
- selectedAnimal: CompanionAnimal
- theme: CompanionTheme
- createdAt: Date
- updatedAt: Date

## CompanionState

Derived, not authoritative.

States:
- calm
- focused
- nearLimit
- overloaded
- recovering
- celebrating

## Settings

- weekStartPreference if exposed
- hapticsEnabled
- companionEnabled
- analyticsConsent if analytics are ever added
- onboardingCompleted
- appearancePreference if needed

## SubscriptionState

Do not persist as sole authority.

StoreKit transaction state remains authoritative.

Cached fields may include:
- lastKnownEntitlement
- lastVerifiedAt

## Modeling rules

- Use stable UUIDs.
- Preserve historical facts.
- Avoid overwriting past targets.
- Prefer derived metrics over redundant stored aggregates.
- Treat dates and local calendar semantics explicitly.

## Phase 1 implementation notes

Concrete choices made while implementing the Habit/Completion/Skip slice, where
this document intentionally left the exact shape open:

- **HabitCategory cases**: `health`, `fitness`, `learning`, `mindfulness`,
  `productivity`, `social`, `finance`, `other`. Reasonable V1 default set; not
  exhaustive, can grow without a migration since it is stored as a raw string.
- **SkipReason cases**: `planned`, `illness`, `travel`, `other`.
- **Historical configuration mechanism**: `HabitConfigurationSnapshot`
  (`id`, `habitID`, `polarity`, `schedule`, `effectiveLocalDateKey`, `revision`,
  `createdAt`) is the concrete implementation of "historical configuration" for
  habits, analogous to `HistoricalTargetSnapshot` for attention goals above. One
  snapshot is written on habit creation and one more each time an edit changes
  `schedule` or `polarity`; cosmetic edits (name/icon/category) update the habit
  record in place without appending a snapshot. Evaluating a past date always
  resolves the snapshot effective on that date, never the habit's current
  configuration.

  If a habit is edited more than once on the same local day, every edit still
  gets its own snapshot, all sharing that day's `effectiveLocalDateKey`.
  Resolution among same-day snapshots is ordered by `revision` — a per-habit,
  zero-based, strictly increasing counter the repository assigns at write time
  (0 for the creation snapshot) — not by `createdAt`. `createdAt` is kept as
  descriptive metadata but is not used for ordering, because it can collide: two
  edits can share a `Date()` captured once and reused, or two snapshots can be
  constructed with the same injected timestamp in a test, and a `createdAt`-based
  comparison would then resolve to whichever snapshot happened to come first in
  an arbitrary array or SwiftData fetch order. `revision` cannot collide, because
  synchronous repository calls are isolated to the main actor, and each value is
  computed from already-persisted rows before the next snapshot is inserted. The
  current single-store writer therefore serializes revision assignment, so the
  most recent same-day edit is always what later reads as
  "active," regardless of timestamp precision or fetch order.
- **reminderSettings**: omitted from the Phase 1 `Habit` type. Notifications are
  out of scope for this slice; the field will be added when the Notifications
  feature is implemented rather than carried as unused optional state now.
- **Local day/week default**: repositories and evaluators take an explicit
  `Calendar` (default `.current`) rather than assuming a fixed time zone or week
  start. `Settings.weekStartPreference` is not implemented yet, so week
  boundaries currently follow the injected calendar's `firstWeekday`.
- **Scaffold-to-canonical store transition**: see SETUP.md's "Phase 1 store
  transition" section. No `SchemaMigrationPlan` was written; existing dev/
  simulator installs must be reset once.

## Phase 1 progress metrics (streak / consistency / recovery)

`HabitProgressCalculator` (`Avela/Features/Habit/Domain/`) computes current
streak, best streak, consistency over an explicit date range, and recovery
progress, purely from a habit's configuration history, completions, skips, and
archive-period history — no stored aggregates. MVP.md and UX.md establish that
these are first-class, non-punitive concepts but do not pin down exact
computation rules. The following were presented to the product owner as
recommendations and explicitly confirmed (not inferred or defaulted):

- **Skips are excused.** A skipped day is removed from both the streak (it
  neither breaks nor extends a run) and consistency (removed from both
  numerator and denominator), distinct from an unresolved miss.
- **Archiving freezes evaluation at the archive timestamp**, preserves every
  miss that happened before it, and leaves the period touching the archive
  date pending rather than forcing it to a miss. This generalizes to every
  past pause, not just a currently-open one — see "Archive-period history"
  below.
- **Recovery ends after 3 consecutive successful commitments following a
  miss.** `RecoveryProgress.isRecovering` is `true` from the miss until
  `consecutiveSuccessesSinceMiss` reaches 3, then becomes `false` — the streak
  itself keeps counting normally past that point; only the "recovering" UI
  framing should stop. `lastMissedLocalDateKey` remains set as a historical
  fact even after recovery ends. The 3 counted commitments are whatever unit
  is active at each point (a day for `daily`/`weekdays`, a week for
  `timesPerWeek`); a schedule-kind change or an archive/reactivate cycle
  during recovery does not reset or restart the count, for the same reason
  pauses and transitions don't affect the underlying streak (see below).

Other rules, which are implementation defaults rather than items presented for
confirmation:

- **The still-open current period (today's day, or the in-progress week for a
  `timesPerWeek` habit) is never a miss.** If it has already succeeded
  (completed today, or this week's target already met) it counts immediately;
  otherwise it is excluded ("pending") until the period ends.
- **Duplicate completions on the same local day never inflate a count.** A
  day's success is "at least one completion," not a tally; a `timesPerWeek`
  target is met by distinct days with a completion, not raw completion count.
  Completion records are never deleted or merged — only this derived
  calculation treats same-day duplicates as one. (`HabitScheduleEvaluator
  .weeklyProgress`, the pre-existing `N/target this week` helper, was updated
  to the same distinct-day rule for consistency between the two.)
- **Mixed-schedule-kind history is resolved day-by-day**, not by what the
  habit's *current* schedule is. A schedule-kind change (e.g. `daily` to
  `timesPerWeek`) mid-calendar-week closes the old kind's unit on the day of
  the change and starts a fresh partial period for the new kind from that
  point — periods are never double-counted or silently dropped across a
  transition, but a `timesPerWeek` target that takes effect mid-week applies
  to the remainder of that week only, not a full 7 days.
- **Consistency ranges are half-open** (`[range.start, range.end)`), computed
  directly rather than via `DateInterval.contains(_:)` — `DateInterval` is a
  *closed* interval, so a naturally-constructed "this week" range
  (`start: weekStart, end: weekStart + 7 days`) would otherwise also match the
  first day of the *next* week.

### Archive-period history

Before this slice, `Habit.archivedAt` was the *only* record of archive state:
reactivating a habit set it back to `nil`, permanently losing the fact that a
pause ever happened. That was fine for a single archive/reactivate cycle (the
habit's whole post-reactivation lifetime still looked continuous, and nothing
needed to know about a pause that was still open), but a **second** cycle on
the same habit would have been invisible to metrics: the dormant gap between
the first archive and its reactivation would be walked as if the habit were
live, generating misses or broken weeks for time the user explicitly paused.

Fixed with `HabitArchivePeriod` (`id`, `habitID`, `archivedAt`,
`reactivatedAt: Date?`) — an append-only log, same pattern as
`HabitConfigurationSnapshot`. `archiveHabit` opens one; `reactivateHabit`
closes the currently-open one. Re-archiving an already-archived habit is a
no-op for period purposes (it does not open a second concurrent period).

`HabitProgressCalculator` treats every day strictly between a closed period's
archive day and its reactivation day as if it didn't exist: no unit is
emitted, so it cannot generate a miss, extend a streak, or reset one. The
archive day itself and the reactivation day remain live:
- The archive day still resolves normally, with the same "pending, not a
  manufactured miss" leniency the current/final day already gets — generalized
  so it applies at *every* pause, not only the one currently in effect.
- A `timesPerWeek` period interrupted by archiving closes exactly like a
  schedule-kind change interrupts one: pending if the target wasn't met yet,
  success if it already was, never a manufactured miss. Reactivation starts a
  fresh partial period rather than resuming the interrupted one, so a single
  natural calendar week can produce more than one unit if a pause falls inside
  it.
- The currently-open period (a habit archived right now) is still handled by
  the pre-existing `Habit.archivedAt` clamp, unchanged; `HabitArchivePeriod`
  only adds the missing *past* half of the picture.

## Phase 1 Today UI

The first real screen (`Avela/Features/Habit/UI/`) follows SwiftUI View →
`TodayViewModel` (feature state) → `HabitRepository` (domain protocol) →
SwiftData, per ARCHITECTURE.md. `TodayViewModel` is the only place that
composes repository reads with `HabitScheduleEvaluator` to decide what's due
today and what a flexible-weekly habit's progress is; `TodayView` only renders
`TodayHabitRow` values it's handed. Errors from the repository are caught in
the view model, logged privately via `OSLog`, and surfaced to the user as a
single generic message — never `error.localizedDescription` or other raw
diagnostics, per UX.md.

**UI-test store isolation.** `AvelaApp` reads an `AVELA_UI_TEST_STORE_PATH`
environment variable and, if present, opens that path instead of the default
on-disk store (`AvelaApp.makeContainer()`). `AvelaUITests` sets this to a fresh
temporary file per test method via `XCUIApplication.launchEnvironment`. Without
this, every UI test would read and write the same real app store: "empty on
first launch" assertions would fail once any prior test had created a habit,
and habits created by one test would leak into another.

This check is wrapped in `#if DEBUG`, so it is compiled out of Release builds
entirely rather than merely left unset at runtime. The original version (first
Today-UI slice) checked the environment variable unconditionally in every
configuration — a real correctness/security gap: any process able to set
environment variables for a shipped (TestFlight or App Store) build could have
redirected where the app reads and writes the user's entire store. Verified by
building both configurations and inspecting the resulting binary: in a Debug
build, the string `AVELA_UI_TEST_STORE_PATH` is present in the compiled code
(in the `Avela.debug.dylib` the Debug build actually runs, not the thin stub
executable); in a Release build of the same scheme, it is absent from the
binary entirely. `xcodebuild test` builds Debug by default, so UI tests are
unaffected; a Release/Archive build never evaluates the override. A real
device/user build never sets this variable regardless, so default behavior —
and the existing guarantee that no launch argument can erase the normal app
store — is unchanged; this only adds a debug-only way to *redirect* to an
isolated store, never to touch the real one, and only in a build configuration
that can't reach the App Store.

## Phase 1 habit lifecycle UI

`HabitDetailView`/`HabitDetailViewModel` (opened from a Today row, via a
`NavigationLink` that is a *sibling* of the row's completion button, not a
wrapper around it — nesting a `Button` inside a `NavigationLink`'s label would
make the button unreachable) show a habit's name, icon, category, polarity,
schedule, current progress, current/best streak, recovery messaging, and
consistency, then support editing and archiving. `ArchivedHabitsView`/
`ArchivedHabitsViewModel`, reached from a new (otherwise still minimal)
`SettingsView`, list archived habits and support reactivation. All four
follow the same layering as Today: view → view model → `HabitRepository`/
`HabitProgressCalculator` → SwiftData, with no business logic or persistence
access in the views themselves.

- **Editing and archiving reuse existing repository operations verbatim**
  (`updateHabit`, `archiveHabit`, `reactivateHabit`) — this slice added no new
  repository behavior, only UI around what Phase 1's domain/data layer already
  guarantees (historical configuration preserved on edit; completions/skips
  untouched; archive periods recorded). `HabitFormView` (renamed from
  `CreateHabitView`, which it replaces) now serves both creation and editing by
  accepting an optional `initialDraft`.
- **Opening detail never completes or undoes a habit.** The screen is
  read-only with respect to today's completion status; the only way to log or
  undo a completion remains Today's own row control.
- **Archiving shows its consequence before asking for confirmation**: the
  confirmation dialog states that the habit disappears from Today but its
  history is kept and it can be reactivated from Settings, matching MVP.md's
  "Archived habits disappear from active views but retain history." Confirming
  archives the habit and dismisses back to Today immediately.
- **Streak unit labeling matches the confirmed rule**: "N-day streak" for
  `daily`/`weekdays` schedules, "N-week streak" for `timesPerWeek`, derived
  from `StreakResult.unit`, never hardcoded.
- **Recovery copy follows UX.md's own examples** ("You're rebuilding
  momentum," "N good days since your miss") and disappears entirely once
  `RecoveryProgress.isRecovering` is `false` — whether because no miss ever
  happened or because the 3-success threshold was reached. No separate "fully
  recovered" message is shown; the habit simply reads as a plain streak again.
- **Consistency uses one fixed, clearly labeled window: "Last 14 Days"** (the
  14 most recent calendar days, including today), for every schedule kind.
  This is a simplification worth noting: for a `timesPerWeek` habit, a 14-day
  window can include a partial week at either edge, whose single resolved unit
  (success/miss) is still counted correctly by the calculator's existing
  half-open range semantics, but a week-aligned window (e.g. "Last 4 Weeks")
  would avoid that partial-week edge entirely. Not implemented in this slice
  since the existing range semantics already produce an honest, non-fabricated
  result either way — revisit only if product feedback asks for it.
- **Insufficient data is represented honestly**: when `scheduledUnits == 0`
  (nothing has resolved to success or miss yet, e.g. a brand-new habit), the
  consistency section reads "Not enough data yet" rather than "0%".
- **Cross-screen refresh** uses two mechanisms, not one shared observable
  store: Today's own mutations and its pushed detail screen both reload Today
  directly (the detail screen via `.onDisappear`, so a back-navigation after
  editing or archiving always refreshes Today); reactivating a habit from
  Settings cannot reach Today's view model directly (different tab, no
  navigation relationship), so `AppShellView` reloads Today whenever the
  selected tab changes *to* Today, regardless of what changed elsewhere.
  History extends this same tab-change mechanism (it reloads whenever the
  selected tab changes to History) since it has no mutation path of its own
  that could reload it directly.

## Phase 1 History

History (`Avela/Features/History/`) is read-only: no logging, editing,
backdating, or deletion happens here, only display of completions and skips
already recorded elsewhere. `HistoryViewModel` composes two new
`HabitRepository` methods — `completions(in:)` and `skips(in:)`, overloads of
the existing per-habit `completions(for:in:)`/`skips(for:in:)` that query
across every habit at once — with `HabitScheduleEvaluator` for historical
schedule context, then shapes the result for display. One habits fetch, one
cross-habit completions fetch, one cross-habit skips fetch, and one
configuration-history fetch per *distinct* habit referenced by those records
(not per row, and not per habit in general — only habits that actually have
activity in the window) per `load()` call.

- **Grouping uses each record's stored `localDateKey` directly**, never a key
  recomputed from `occurredAt` under whichever calendar happens to be current.
  A completion or skip's day in History cannot move after the fact just
  because the device's time zone changed — the same guarantee `LocalDay` and
  `HabitConfigurationSnapshot` already provide elsewhere, now extended to the
  read side.
- **The displayed range is fixed for this slice: "Last 30 Days"** (the 30 most
  recent local calendar days, including today), computed the same
  `[start, end)` half-open way as the habit detail screen's 14-day consistency
  window. Always visible, clearly labeled, and not yet adjustable — consistent
  with "do not add... a complex calendar interface."
- **Archived habits are included, not filtered out**, both in the record list
  and in the habit filter picker (labeled "{name} (Archived)"), since their
  history remains real history. This is the same stance as `HabitArchivePeriod`
  and `fetchHabits(includeArchived: true)` elsewhere: archiving hides a habit
  from *active* views, never from its own record of what happened.
- **Habit name and icon shown are the habit's current ones**, not a historical
  snapshot — this is the existing documented policy (`HabitConfigurationSnapshot`
  only ever captured `schedule`/`polarity`; `DATA_MODEL.md`'s "Phase 1
  implementation notes" already states name/icon were never historically
  tracked). History does not invent a historical name/icon that was never
  stored; it reuses whatever the habit is called *now*.
- **Historical schedule context is resolved per record**, via a new
  `HabitScheduleEvaluator.activeConfiguration(from:onKey:)` overload that
  takes an already-stored `localDateKey` directly rather than a `Date`.
  Reconstructing a `Date` from a stored key and then re-deriving a key from it
  under the *current* calendar would risk landing on a different day than the
  one actually stored — exactly the kind of time-zone-induced drift historical
  records must never be subject to. A row's schedule context always reflects
  what was configured on that record's day, never the habit's schedule today.
- **A skip's `createdAt` is never shown as a time.** `detailText` for a skip is
  its reason (if any) only; only completions, which have a real precise
  instant (`occurredAt`), show a time of day.
- **Undone completions are simply never fetched** — `undoCompletion` deletes
  the `CompletionRecord` outright, so there is nothing History-specific to
  exclude; the repository already has nothing to return.
- **Duplicate same-day completions are never deduplicated.** Progress
  calculations treat multiple completions on one day as a single success, but
  History shows every actual `Completion` record as its own row — logging
  twice does not make an entry disappear, it makes two entries. Within a day,
  rows are ordered by habit name, then completions before skips, then by time
  for same-habit same-day entries.
- **Navigation from habit detail** ("View History") dismisses the detail
  screen and asks `AppShellView` to set `HistoryViewModel.selectedHabitID` and
  switch tabs, the same cross-tab callback pattern already used for
  Settings → Today refresh, just inverted in direction.

### Pre-Insights focused review

Before building Insights, two existing guarantees this slice depends on were
re-confirmed with regression tests rather than assumed:

- **History's range selection and stored-key grouping agree at date
  boundaries.** `completions(in:)` filters by precise instant;
  `skips(in:)` filters by comparing stored local-day keys (skips only ever
  carry a day, never an instant) — two different mechanisms computing
  membership in the *same* range. `HistoryViewModelTests
  .testCompletionAndSkipRangeBoundariesAgree` records a completion and a skip
  at the exact same inclusive-start and exclusive-end instants and confirms
  both mechanisms agree at both edges. No bug was found; this closes a gap in
  existing coverage, which previously tested each mechanism's boundary in
  isolation (`testHalfOpenDateRangeBoundaries` for completions,
  `SwiftDataHabitRepositoryTests.testSkipsAcrossHabitsRespectsHalfOpenRange`
  for skips) but never both together through the same `HistoryViewModel`-
  computed range.
- **`HabitProgressCalculator.consistency` evaluates a completed historical
  week using only that week's own facts.** It has no way to "forget" data
  recorded after the reviewed week — callers always pass a habit's full
  completion/configuration history — so correctness depends entirely on `in:
  range` filtering by each unit's own `periodStart` and on per-day schedule
  resolution always looking up the snapshot effective *that day*, never the
  latest one. `HabitProgressCalculatorTests
  .testConsistencyForACompletedWeekIsUnaffectedByLaterCompletionsOrConfigurationChanges`
  confirms this directly: a week's consistency is bit-for-bit identical
  whether or not later completions and a later schedule change are present in
  the data passed in. No bug was found; this is the regression test that lets
  Insights safely reuse `consistency` for historical weeks without
  re-deriving or filtering the input data itself.

## Phase 1 Insights

Insights (`Avela/Features/Insights/`) is a read-only, habit-only weekly
review: no logging, editing, or backdating happens here. `InsightsViewModel`
composes `WeeklyInsightsCalculator` (a new pure domain calculator,
`Avela/Features/Insights/Domain/`) with existing `HabitRepository` reads — no
new repository methods were needed. Per load: one `fetchHabits
(includeArchived: true)`, one cross-habit `completions(in:)` and one
cross-habit `skips(in:)` scoped to a single range covering both the
displayed week and the preceding one (reusing the cross-habit methods added
for History), and one `configurationHistory(for:)`/`archivePeriods(for:)`
pair per habit (not per week, not per row). `WeeklyInsightsCalculator` itself
calls `HabitProgressCalculator.consistency` once per habit per week and does
only aggregation across habits — no new per-day scheduling logic.

Attention-budget results and strongest/weakest-weekday patterns are
explicitly **deferred**, per MVP.md's "Weekly review" section — this slice
implements only the habit-consistency portion of that section. Insights has
no controls, dead or otherwise, for the deferred pieces.

### Confirmed product rules

The following were presented to the product owner as recommendations (or, in
one case, specified directly) and explicitly confirmed — not inferred or
defaulted, matching how Phase 1's progress metrics were originally confirmed:

- **Overall weekly consistency is the average of each eligible habit's own
  consistency percentage for that week**, not a pooled successful/resolved
  count across all habits. A daily habit can resolve up to 7 units in a week;
  a `timesPerWeek` habit resolves exactly 1 — pooling would let
  higher-frequency habits dominate the number silently. Averaging treats
  every eligible habit equally regardless of its schedule's frequency.
- **A habit is "eligible" for a given week** — counted in that week's overall
  average, and eligible to be named strongest or needing attention — only if
  `HabitProgressCalculator.ConsistencyResult.scheduledUnits > 0` for that
  week, i.e. it has at least one resolved (success or miss) unit. A habit
  created after the week ended, or archived before it began, is excluded
  entirely — never counted as a measured 0%, which would misrepresent "no
  data yet" as "measured and failing." This is the same "missing data is not
  a zero" principle `ConsistencyResult.percentage` already applies at the
  single-habit level, now applied to a week's eligibility.
- **"Habit needing attention" is based on misses in the selected week only**
  — never on today's (or any other week's) recovery state. A historical
  week's review must not describe itself using information from outside that
  week, so this slot does not use `HabitProgressCalculator.recoveryProgress`
  at all (that function reports status "as of" a single instant, which would
  mean "as of today" unless deliberately re-anchored, and re-anchoring it to
  the reviewed week's own last instant was judged more complexity than this
  slot needs). Among eligible habits with at least one miss that week, the
  one(s) with the *lowest* consistency percentage are named — symmetric with
  how "strongest" is chosen, both being the extremes of the same per-habit
  percentage distribution — rather than raw miss count, which would unfairly
  favor flagging daily/weekdays habits just because they generate more
  opportunities to miss than a `timesPerWeek` habit does in the same week. If
  no eligible habit has any miss, this slot is omitted entirely rather than
  naming a habit with nothing wrong.
- **"Strongest habit" requires a positive percentage.** Among eligible
  habits, the one(s) with the highest percentage are named, but only if that
  percentage is greater than 0% — if every eligible habit missed every
  resolved unit, there is no "strongest" performer to call out, and the slot
  is omitted.
- **The minimum data bar for being named strongest/needing-attention is the
  same as the bar for counting toward the overall average** (`scheduledUnits
  > 0`) — no separate, stricter threshold. A single resolved unit is enough
  to be named, kept simple rather than introducing a second, harder-to-
  justify constant.
- **Ties are never broken arbitrarily.** If multiple habits share the exact
  maximum (strongest) or exact minimum-among-misses (needing attention)
  percentage, every tied habit is named (sorted by name for a stable, legible
  order), never one chosen by incidental array/fetch order.
- **When every eligible habit has the exact same percentage this week —
  including the common case of exactly one eligible habit —
  `WeeklyInsights.isBalancedWeek` is `true` and both `strongestHabitNames`
  and `habitsNeedingAttentionNames` are empty.** Added in a later correctness
  pass (see "Audit-driven correctness fixes" below) after the original
  independent min/max selection was found to name the *same* habit as both
  "Strongest" and "Needing Attention" for any single habit with a partial
  week — the single most common scenario for a new user, not an edge case.
  `eligibleHabits` still carries every habit's real `successfulUnits`/
  `scheduledUnits` regardless, so the UI can show a neutral summary built
  from real counts instead of a ranking.
- **The week-over-week trend only compares a "comparable cohort" of habits —
  see "Trend comparable-cohort rules" below — never the full eligible set of
  either week.** If the comparable cohort is empty, the trend is `nil` ("not
  enough comparable data") rather than comparing unrelated habits,
  incompatible schedules, or interrupted tracking periods against each
  other. The trend is expressed in **percentage points**
  (`(thisWeek's cohort average - lastWeek's cohort average) * 100`), e.g.
  "Up 8 percentage points," never phrased as a second percentage that could
  be misread as a ratio. The selected week's own "Overall Consistency"
  number is unaffected by this — it always reflects every eligible habit for
  that week, per the bullet above, regardless of which (if any) are part of
  the comparable cohort.

### Trend comparable-cohort rules

Added in the same correctness pass referenced above, after the original
trend was found to compare any two weeks that each independently had *some*
eligible habit — even when they shared no habit in common, or shared a habit
whose schedule had changed between the two weeks. A habit is included in the
trend's comparable cohort only if **all** of the following hold, checked
against the full two-week span (the preceding completed week's start through
the selected week's end):

1. It is eligible (`scheduledUnits > 0`, independently) in *both* weeks.
2. Its `HabitSchedule` did not change at any point across that span. A
   snapshot appended for a polarity-only edit does **not** count as a change
   — the schedule value itself is compared, not merely "was a new snapshot
   appended," since polarity doesn't affect what's being measured (per
   `Habit.swift`'s "polarity only changes how UI should phrase progress").
3. It was not archived/reactivated at any point during that span — it was
   continuously active on both sides, not paused for part of either week.
4. Its `scheduledUnits` for *each* week individually equals the full
   expected count for a schedule of its kind — 7 for `daily`,
   `weekdays(set).count` for `weekdays`, 1 for `timesPerWeek` — catching a
   habit created or archived partway through either week, which rules 2–3
   alone would not catch (the schedule never changed and no archive period
   exists for "not created yet," but the week it's measuring is still a
   smaller opportunity than a normal week).

All four are implemented in `WeeklyInsightsCalculator`'s private
`trendInPercentagePoints(...)`, exercised by
`WeeklyInsightsCalculatorTests`' "Trend comparable-cohort rules" section
(schedule change mid-span, a pause mid-span, a truncated week from mid-week
creation, a mixed cohort where only the comparable habit affects the trend
while the overall summary still reflects both, and a polarity-only edit that
correctly does *not* disqualify a habit).

### Audit-driven correctness fixes

`docs/UX_AUDIT.md`'s "Part 0" reviewed the original Insights implementation
against three agreed rules and found two genuine, previously-untested gaps —
reported there with concrete reproductions, not fixed at the time (that
pass was audit-only). Both were fixed in a dedicated follow-up pass, together
with one more defect the same audit's live-app screenshots surfaced:

- **Trend cohort/schedule comparability** (the "Trend comparable-cohort
  rules" section above) — previously, the trend only checked that each week
  independently had *some* eligible habit, never that it was the *same*
  habit with a compatible schedule and tracking period.
- **Balanced-week handling** (`isBalancedWeek`, above) — previously, any
  single habit with a partial (neither 0% nor 100%) week was named *both*
  "Strongest" and "Needing Attention" simultaneously, since the two rankings
  were computed independently. This was the most common early-user scenario,
  not an edge case.
- **The archive confirmation dialog's missing Cancel action**
  (`HabitDetailView`) — the audit's screenshot evidence of this was captured
  by an external, unsynchronized `simctl` screenshot poller with no
  knowledge of XCUITest's own element tree, so it could not distinguish "the
  dialog hadn't finished presenting yet" from "the Cancel button never
  exists at all." A UI test added in the follow-up pass
  (`testArchiveConfirmationCanBeCancelledLeavingTheHabitActive`) waits for
  the dialog's own elements (`app.buttons["Archive"]`,
  `app.buttons["Cancel"]`) before asserting anything, removing that
  ambiguity — and confirmed the Cancel button genuinely never appeared in
  the accessibility tree at all, within a 5-second wait, when presented via
  `.confirmationDialog` from a row inside a `List` on this toolchain. This
  was a real functional defect, not merely a discoverability issue: with no
  reachable Cancel element, VoiceOver and Full Keyboard Access users had no
  announced way back from the dialog. Fixed by switching to a plain
  `.alert`, SwiftUI's standard native two-button confirm/cancel presentation
  — no custom overlay — which has none of `.confirmationDialog`'s
  List-anchored popover behavior and reliably presents both actions. The
  same UI test now passes and additionally verifies cancelling leaves the
  habit active with no archive period recorded (confirmed via Settings'
  Archived Habits remaining empty).

### Populated-Insights DEBUG fixtures

Added alongside the fixes above, to let a UI test (and manual QA) actually
see populated Insights states — `WeeklyInsightsCalculatorTests` and
`InsightsViewModelTests` already proved the math with past-dated fixtures
directly through the repository, but no UI-reachable state could show a
real, non-empty weekly summary, since Insights never displays the
in-progress current week and nothing a UI test does "today" can land in an
already-completed one.

`Avela/App/DebugFixtures.swift` (new, `#if DEBUG`-gated, absent from Release
binaries — verified the same way as `AVELA_UI_TEST_STORE_PATH`: `grep` for
the override's name, the fixture enum's name, and the store-path variable
name in the compiled Release binary all return zero matches, while all three
are present in the Debug binary) defines five named fixtures
(`DebugFixtures.Fixture`: `populated`, `balancedIdentical`, `tiedExtremes`,
`validTrend`, `noComparableData`), each seeding a small, deterministic set of
habits/completions into the current store using nothing but the existing
public `HabitRepository` API (`createHabit`, `recordCompletion`,
`updateHabit`) — the same calls any real use of the app would make, so no
production type carries any fixture-specific logic. `AvelaApp.init()` seeds
the named fixture (via the new `AVELA_UI_TEST_SEED_FIXTURE` environment
variable) only when `AVELA_UI_TEST_STORE_PATH` is *also* set — so even in a
Debug build, this can only ever write into the already-isolated,
per-test-method store that override redirects to, never the ordinary app
store. `AvelaUITests` sets both together via a new `launchApp(seedFixture:)`
overload. Five new UI tests
(`testInsightsShowsPopulatedSummaryWithStrongestAndNeedsAttention`,
`testInsightsShowsBalancedSummaryForIdenticalResults`,
`testInsightsListsAllTiedHabitsForStrongestAndNeedsAttention`,
`testInsightsShowsAValidTrendForAComparableHabit`,
`testInsightsShowsNotEnoughComparableDataWhenScheduleChangedBetweenWeeks`)
each launch with one fixture and assert on the real rendered summary, strong/
needs-attention names, trend text, or the balanced-summary copy, attaching a
screenshot once the relevant elements are confirmed present (never
immediately after a tab switch, which would race the view's own load).

### Other implementation choices

- **Default and navigable range: the last completed local calendar week.**
  `InsightsViewModel` never shows the in-progress current week — only weeks
  that have fully elapsed — computed via `Calendar`'s own `.weekOfYear`
  arithmetic plus `LocalDay.weekInterval` (both DST-safe, reusing the same
  guarantee `LocalDayTests` already establishes for `LocalDay` itself,
  re-verified end-to-end through `InsightsViewModel` in
  `InsightsViewModelTests
  .testWeekContainingADaylightSavingTransitionStillCountsSevenLocalDays`).
  "Previous"/"Next" step one completed week at a time via simple toolbar
  buttons (no date picker or calendar UI); "Next" is disabled at the most
  recent completed week and there is no lower bound on going further into the
  past. The selected week is session-only view-model state, not persisted —
  every fresh load (including after a relaunch) starts back at the most
  recent completed week, a deliberate simplification consistent with keeping
  navigation simple.
- **Unlike History, Insights always recomputes its week boundaries from the
  *current* calendar at load time** rather than displaying anything grouped
  by a previously-stored key. There is no "stored day moving after a time
  zone change" risk analogous to History's, because Insights never persists
  or redisplays a prior grouping — "last completed week" is defined fresh,
  relative to whatever "now" is, every time.
- **Habit name shown is the habit's current name**, not a historical
  snapshot — consistent with History's and the rest of Phase 1's documented
  name/icon policy.
- **Archived habits are included** in a week's eligibility and rankings if
  they had resolved activity during that week (consistent with
  `HabitArchivePeriod` and History's stance: archiving hides a habit from
  active views, never from its own record of what happened). A habit
  archived entirely before a given week began is naturally excluded by the
  `scheduledUnits > 0` eligibility gate, with no special-casing needed.
- **Insufficient-data states are distinct from "no habits yet."**
  `InsightsViewModel.hasAnyHabits` (from `fetchHabits`) drives a "No Habits
  Yet" empty state; habits existing but none eligible for the displayed week
  drives a separate "Not Enough Data This Week" state. Both are honest,
  neither is a fabricated 0%.
- **Refresh follows the same tab-change mechanism as History**:
  `AppShellView` reloads Insights whenever the selected tab changes *to*
  Insights, since — like History — it has no mutation path of its own that
  could reload it directly; its own week-navigation buttons already reload
  themselves.

## Phase 1 small UX fixes (F2, F4, F5, F7, F12)

Five low-risk, non-visual-redesign fixes from `docs/UX_AUDIT.md`'s Part 6
Phase 2, implemented together since none depends on choosing a visual
direction (still not applied — see `design/exploration/`, owned by a
separate, concurrent session, not touched here).

- **F4 — compact modal title.** `HabitFormView` now sets
  `.navigationBarTitleDisplayMode(.inline)`, matching the standard iOS
  convention for quick-entry sheets (Reminders' "New List," Mail's "New
  Message") instead of the large, left-aligned title it shared with tab
  roots. No behavior change, no new accessibility identifier needed.
- **F2 — polarity-aware completion wording.** New
  `Avela/Features/Habit/UI/HabitPolarityFormatter.swift` (pure text
  formatting, no logic) provides `completionActionLabel`, `undoActionLabel`,
  and `statusLabel`, each branching on `HabitPolarity`. For `positive`
  habits the wording is unchanged ("Mark {name} complete" / "Undo completion
  for {name}" / "Completed"/"Not completed yet"). For `avoidance` habits it
  is "Log success for {name}" / "Undo success for {name}" / "Logged"/"Not
  logged yet" — deliberately **not** "Mark avoided" or "Didn't do it," which
  would assume the habit means total abstinence. An avoidance habit like
  "Cut down on late snacking" can be satisfied by a reduced amount, not only
  "zero snacks," and "Log success" stays correct either way. Used by
  `TodayView`'s completion button's accessibility label and by
  `HabitDetailViewModel`'s new `todayStatusLabel` field (replacing an inline
  `isCompletedToday ? "Completed" : "Not completed yet"` that previously
  ignored polarity entirely). All existing UI tests use the default
  `positive` polarity and were unaffected, since that wording didn't change.
- **F12 — consistent active-habit icon tinting.** `HistoryView`'s row icon
  and `HabitDetailView`'s header icon now both use
  `isArchived/isHabitArchived ? Color.secondary : Color.accentColor`,
  matching `TodayView` (which only ever shows active habits, already
  accent-tinted) and `ArchivedHabitsView` (which only ever shows archived
  habits, already `.secondary`). Previously `HabitDetailView` always tinted
  regardless of archived state, and `HistoryView` always used `.secondary`
  regardless — meaning the *same* active habit could read as accent-tinted
  on Today/Detail but gray in History, which risked being misread as "this
  must be archived" (the signal `ArchivedHabitsView` actually uses). The
  text "Archived" badge in History remains the authoritative signal either
  way; tinting now simply agrees with it everywhere instead of contradicting
  it on one screen. Icon tint color is not queryable through XCUITest's
  accessibility tree (no API exposes a rendered color on an `XCUIElement`),
  so this is verified by screenshot evidence only, not an automated
  assertion — see `testArchivedAndActiveHabitIconsAppearTogetherInHistoryForVisualTintComparison`,
  which does automate the one behavioral part (the text badge's presence)
  and attaches a screenshot for the tint itself.
- **F7 — consistent "nothing yet" phrasing, distinctions preserved.** Three
  of `HabitDetailViewModel`'s four empty-state strings already ended in
  "yet" ("Not completed yet," "No streak yet," "Not enough data yet"); only
  the current-streak zero-text ("No current streak") broke that pattern.
  Changed to "No current streak yet" — purely a wording fix, the distinct
  *meanings* are unchanged and still intentionally separate: "Not completed
  yet"/"Not logged yet" (today's own resolution), "No current streak yet"
  (no streak presently in progress), "No streak yet" (no streak has ever
  been achieved, a lifetime fact), "Not enough data yet" (the 14-day
  consistency window has no resolved units at all). Merging any of these
  into one message was never the ask or the fix — only their phrasing
  pattern needed to agree.
- **F5 — icon-picker touch targets.** The icon grid's cells were measured at
  36×36pt, below the 44×44pt minimum UX.md requires. Fixed by replacing the
  fixed 6-column `LazyVGrid` with `GridItem(.adaptive(minimum: 44, maximum:
  64))`, and each icon button's frame from a fixed `36×36` to `minWidth: 44,
  minHeight: 44` — the grid now recomputes how many columns fit (reflowing
  to fewer, larger columns as Dynamic Type grows the icons themselves,
  satisfying "adapt the grid at larger Dynamic Type sizes") rather than
  shrinking cells to keep a fixed column count. Verified with a UI test that
  reads each icon button's actual rendered `frame` (not just the SwiftUI
  source values) at both the default and
  `UICTContentSizeCategoryAccessibilityXXXL` Dynamic Type sizes — the latter
  forced via the `-UIPreferredContentSizeCategoryName` launch argument,
  which does reliably work on this toolchain (unlike the dark-mode launch
  argument below). The first run of the default-size test failed with
  `43.99999999999994 < 44.0` — genuine SwiftUI layout floating-point
  rounding noise around an intended-and-visually-exact 44pt target, not an
  actually undersized element — fixed by rounding the measured frame to the
  nearest point before comparing, which is how a real compliance check
  should treat a UI measurement in the first place.

### Accessibility checks that could not be performed

- **Forcing dark mode per-test via launch argument does not work on this
  Xcode 27/iOS 27 toolchain.** `-UIUserInterfaceStyle Dark` was added to
  the UI test launcher and measured by screenshot: the app still rendered
  fully light (white backgrounds, black text) regardless. No
  `.preferredColorScheme`/`overrideUserInterfaceStyle` override exists
  anywhere in the app to explain this — the launch argument itself simply
  didn't take effect. The *simulator's own* system appearance
  (`xcrun simctl ui <device> appearance dark`) does work, but must be set
  before `xcodebuild test` launches the app, from outside the test target —
  XCUITest code cannot shell out to `simctl`. `testVisualAppearanceInDarkMode`
  and `testVisualAppearanceInLightMode` are therefore identical in body and
  both simply run under whatever appearance the simulator already has; dark
  screenshots for this fix were captured by toggling the simulator's
  appearance externally before a `-only-testing` run targeting just that one
  test (see `docs/SETUP.md` for the exact commands and results), not by a
  fully hermetic single `xcodebuild test` invocation. A CI pipeline wanting
  both appearances automatically would need to invoke `xcodebuild test`
  twice, toggling `simctl ui ... appearance` between runs.
- **VoiceOver focus order and Full Keyboard Access were not exercised.**
  XCUITest can read accessibility labels/identifiers/frames (as this pass's
  touch-target test does) but does not drive the actual VoiceOver swipe-
  navigation order or Full Keyboard Access tab order — both require a live
  Accessibility Inspector or on-device session to verify directly.
- **Actual on-device Dynamic Type text wrapping/truncation beyond the icon
  grid** (e.g. whether `HabitDetailView`'s long labels clip at
  `UICTContentSizeCategoryAccessibilityXXXL`) was not separately audited in
  this pass — only the icon grid's touch targets were in scope per F5.

## Phase 1 Attention (manual tracking and logging)

Implements MVP.md §6's manual attention goals and usage logging. Scope and
decisions below narrow the conceptual shapes declared earlier in this
document (`AttentionGoal`, `AttentionGoalType`, `AttentionUsageEntry`,
`HistoricalTargetSnapshot`) to what this slice actually builds; the earlier
sections remain the long-term conceptual target.

### Goal type scope

Only `AttentionGoalType.maxDurationPerDay` is implemented. The other three
documented cases (`noUseBeforeTime`, `phoneFreeUntilTime`,
`phoneFreeSession`) are time-window/compliance goals with a fundamentally
different interaction model — no quantity to sum, no "budget" to log a
reduction against — and this slice's scope is explicitly "recording usage...
against the defined budget." They are deferred in prose only (see
`AttentionGoal.swift`'s doc comment), not declared as unimplemented enum
cases, mirroring the precedent `HabitSchedule` already set by omitting
"custom intervals" entirely rather than declaring a case nothing handles.
`AttentionUsageSource.screenTime`, by contrast, *is* declared now despite
being unimplemented — it is a cheap provenance tag that changes no behavior
today, the same role `CompletionSource.widget`/`.shortcutFuture` already
play, and ARCHITECTURE.md explicitly requires the architecture (not
necessarily this slice) to support a future Screen Time source.

### Budget storage: `AttentionGoalConfigurationSnapshot`, not an `AttentionGoal` field

`targetValue`/`unit` are **not** stored on `AttentionGoal` itself, despite
appearing in that struct's conceptual shape above. They live exclusively on
a new append-only `AttentionGoalConfigurationSnapshot` (id, attentionGoalID,
targetValue, unit, effectiveLocalDateKey, revision, createdAt) — the exact
`HabitConfigurationSnapshot` pattern, for the exact same reason: MVP.md
requires "changing today's goal does not rewrite previous historical
goals," so a budget edit must append a new snapshot, never overwrite a
mutable "current target" field. `AttentionGoalEvaluator.activeConfiguration`
resolves the snapshot in effect for a given local day exactly like
`HabitScheduleEvaluator.activeConfiguration` — latest snapshot with
`effectiveLocalDateKey <= key`, ties broken by `revision` (not `createdAt`,
which can collide on same-day edits sharing one captured `Date()`).

### Local-day and summing semantics

- `AttentionUsageEntry.localDateKey` is computed once via `LocalDay.key`
  at write time and persisted as-is, identically to `Completion`/`Skip`.
- Unlike `Completion` (one fact per habit per day, toggled), usage entries
  are **additive**: a day's total is the sum of every entry recorded that
  day, not a single yes/no state. MVP.md's manual-logging flow is "log 15
  minutes now, log 10 more later," not a daily toggle.
- `AttentionProgressCalculator.DailyProgress` sums a pre-filtered list of
  entries (goal + day already selected by the caller) into `totalAmount`,
  and separately exposes `hasLoggedUsage`/`entryCount`.

### Missing data vs. a measured zero

`DailyProgress.percentOfTarget` and `.state` are `nil`, not `0`/`.healthy`,
whenever `hasLoggedUsage` is `false`. This is a direct, explicit task
requirement ("no entries must not imply verified zero usage or an
automatically measured 'On track' status") and mirrors the same
missing-data-vs-zero distinction already established for Habit consistency
eligibility and Insights' "not enough data" handling. `AttentionStatusFormatter`
enforces the same rule in prose: a day with no entries reads as "No usage
logged yet today," never as a percentage or threshold word, and any day
with usage is always labeled "logged manually," per the task's explicit
"label usage as manually recorded" requirement.

### Thresholds

Centralized in `AttentionProgressCalculator.ThresholdState`, per UX.md's
explicit instruction ("thresholds should be centralized and configurable"):
healthy `<70%`, near limit `70%–<100%`, exceeded `>=100%` of the active
budget. A zero-or-negative target (not reachable through the form's
validation, but defensively handled) treats any logged usage as exceeded
rather than dividing by zero.

### Correction and deletion scope: today only

`AttentionGoalDetailViewModel` only ever loads the current local day's
entries, so correcting (`updateUsageEntry`) or deleting
(`deleteUsageEntry`) an entry is only reachable for today's own entries —
there is no UI path to a past entry. This mirrors the existing rule that
habit completions can only be toggled/undone for *today* from Today's row;
historical records are read-only facts elsewhere (History). This slice adds
no History integration for attention usage; MVP.md's "historical entries
retain actual usage" is satisfied by persistence alone (entries are never
deleted or overwritten by a later budget edit), not by a new History UI.

### Today integration

A new, independent `AttentionSummaryViewModel` (not a merge into
`TodayViewModel`) powers a second List section on Today, titled
"Attention," shown whenever at least one attention goal exists. Today's
top-level empty state (`today.emptyState.title`, "No Habits Yet") is now
gated on *both* `TodayViewModel.rows` and `AttentionSummaryViewModel.rows`
being empty, so it still appears on a genuinely fresh install and is
otherwise unaffected — no existing Habit-only UI test creates an attention
goal, so none of them exercise the changed condition. Each attention row
shows name, category label (if any), and status text, with a trailing
"fast" quick-log button (`today.logUsageButton.<id>`) opening a one-field
amount sheet directly from Today, per UX.md's "fast logging actions"
requirement — tapping the row itself navigates to the goal's detail screen
instead. A new `AttentionGoalNavigationID` wrapper type (not a bare `UUID`)
is pushed for attention rows' `NavigationLink`, since Today already pushes
bare `UUID` values for habit rows via `.navigationDestination(for:
UUID.self)`; without the wrapper, an attention-goal ID could collide with a
habit ID's navigation destination.

### A SwiftUI toolchain pitfall: `Button` + `.swipeActions` on the same row

`AttentionGoalDetailView`'s entry rows need both a tap action (opens a
correction sheet) and a swipe action (delete). The first implementation
wrapped the row in a `Button` and attached `.swipeActions` to that same
`Button`. A UI test waiting for the correction sheet to appear after
tapping the row consistently failed — XCUITest reported a successful tap
synthesis on the correct element, but the sheet never presented — while the
same row's swipe-to-delete worked every time. Collapsing the screen's three
separate `isPresented` sheet bindings into one `.sheet(item:)` did not fix
it either, isolating the cause to `.swipeActions` claiming the row's tap/pan
gesture ahead of the nested `Button`. The fix: drop the `Button` wrapper for
a plain `HStack` with `.contentShape(Rectangle())` + `.onTapGesture`, and
accessibility traits/identifier applied directly
(`.accessibilityAddTraits(.isButton)` so XCUITest's `app.buttons` query
still finds it). `.swipeActions` attached to a plain tappable view, rather
than to a `Button`, worked immediately. Keep this in mind for any future
List row that needs both a primary tap action and `.swipeActions`.

## Vivid Tidewater UX pass

Implements `design/exploration/prototype-vivid/` ("Vivid Tidewater") as the
working visual direction, applied to Today in the "Tidewater Balance"
layout `design/exploration/TODAY_CONCEPTS.md` recommends, and applies the
same colour tokens (not a layout change) to every other screen. Scope and
decisions below are this slice's; the design-exploration documents remain
the long-term proposal and were not edited.

### Colour tokens

Sixteen named colour assets in `Resources/Assets.xcassets` (`AccentColor`
plus 15 semantic tokens: `Background`, `Surface`, `SurfaceSecondary`, `Ink`,
`InkSecondary`, `InkTertiary`, `OnAccent`, `AccentSoft`, `Recovery`,
`RecoverySoft`, `OverBudget`, `DoneWash`, `ToastBackground`, `ToastInk`,
`ToastIcon`), each with a light and dark appearance, values taken directly
from `design/exploration/prototype-vivid/vivid.css` (the Vivid overrides)
falling back to `design/exploration/prototype/styles.css` (Balance's base
tokens) for the handful Vivid doesn't touch (`recovery`, `recoverySoft`) and
to `VISUAL_DIRECTIONS.md`'s original token table for `overBudget` (clay),
which neither prototype implements since attention wasn't built when they
were written. `Avela/Core/UI/AppColor.swift` exposes each as a typed
`Color` static (`Color.appSurface`, etc.); `AccentColor` itself is used via
the ordinary `Color.accentColor`/`.tint` APIs, not re-wrapped, so it can
never drift from what the system resolves automatically. Every value
already clears CONTRAST.md's 4.5:1 text / 3:1 non-text targets in both
appearances (Vivid measured 0 of 28 failures there, versus Balance's 5) —
no separate Increase Contrast asset variant was added this slice; see
"Known limitations" below.

`toastUndoBg`/`toastUndoInk` from `vivid.css` were not given their own
assets: in both appearances they are exactly `toastInk`/`toastBackground`
swapped, so the toast's Undo pill reuses those two tokens inverted rather
than duplicating them under new names. `track` (the unfilled-pip/ledger
outline token) was likewise not given its own asset: it is identical to
`InkTertiary` in both appearances, so call sites just use `InkTertiary`
directly.

### Today → "Tidewater Balance"

Adopts `TODAY_CONCEPTS.md`'s recommended concept 2 ("Habit and attention
balance") on real data, not the deferred/placeholder treatment the concept
doc describes (Phase 2 attention tracking already existed going into this
slice):

- **Pillar strip.** A Habits pillar ("N of M done", teal value, per-habit
  pips when there are ≤12) and an Attention pillar, shown only when at least
  one attention goal exists (absent, not a placeholder, mirroring the
  already-established rule for the pre-Phase-2 attention section).
- **Attention pillar wording never says "On track."** The prototype's own
  mockup literally reads "On track," which directly contradicts this
  project's own manual-tracking integrity rule (no entries must not imply a
  verified/automatic status — see "Missing data vs. a measured zero" above).
  `AttentionStatusFormatter.pillarState`/`pillarLabel` instead reduce every
  goal's status to the worst case using the *same* vocabulary already
  shown per-goal (`Healthy` / `Near Limit` / `Exceeded`), or `Not logged yet`
  when not a single goal has any usage recorded today — never a claimed-good
  word for data that doesn't exist. Unit-tested directly
  (`AttentionStatusFormatterTests`) including an explicit assertion that the
  label is never `"On track"`.
- **Done group.** Completed habits collapse into a "Done · N" disclosure
  row. A short deferred-collapse window (1.5s, a `Task.sleep` per habit ID
  inside `TodayView`, not a view-model concern) keeps a just-completed row
  in place briefly so it doesn't disappear out from under the thumb that
  completed it — skipped under Reduce Motion only in that the move itself is
  unanimated; the delay is the same either way. Expanding "Done" always
  reaches the exact same completion control, with the exact same
  accessibility label (`HabitPolarityFormatter.undoActionLabel`), as before
  this slice — the task's own requirement that collapsing Done must not cost
  an obvious, accessible undo route.
- **Undo toast.** A branded (`ToastBackground`/`ToastInk`/`ToastIcon`) toast
  appears on every habit completion and every attention quick-log, with a
  single Undo action, auto-dismissing after 4 seconds
  (`design/exploration/COMPONENT_SPEC.md`'s stated duration — the HTML
  prototype's own `app.js` actually uses 5000ms; this slice follows the
  written spec, not the prototype's implementation, where the two
  disagree). The toast is one `TodayToast` view-local value, generic over
  both sources (`TodayToastKind.habitCompletion`/`.attentionQuickLog`) via a
  lazy, ID-based lookup at undo time rather than a captured closure — a
  closure capturing the row directly would still hold its *pre-toggle*
  `todaysCompletionID == nil`, and calling `toggleCompletion` with that stale
  snapshot would record a second completion instead of undoing the first.
- **A real bug this introduced, found by UI testing, not inferred.** The
  deferred-collapse `Task` and the toast's auto-dismiss `Task` are both bare
  `Task { }` values, not `.task` view modifiers — nothing cancels them when
  Today is navigated away from. Six UI tests that complete a habit and then
  immediately open its detail (well within the toast's 4-second window)
  started failing consistently: the pushed `HabitDetailView` rendered (the
  correct screen, with the correct navigation bar) but stayed on its loading
  spinner forever. Root cause, confirmed by bisection (disabling each
  pending task in turn): either task firing later — while the user is on the
  detail screen — mutates this view's `@State`, which forces `TodayView`'s
  `body` to re-evaluate, which re-invokes the `navigationDestination(for:
  UUID.self)` closure and constructs a **new** `HabitDetailViewModel` for the
  already-displayed screen. SwiftUI does not re-run `.task` for what it
  still considers the same destination, so the new, never-loaded view model
  is left showing instead of the one whose `load()` had already run — stuck
  on `display == nil` permanently. `.onDisappear` on `TodayView` was tried
  first and did **not** fix it: on this toolchain it does not reliably fire
  when a `NavigationStack` push merely covers the root view rather than
  removing it. The actual fix cancels both tasks (and resolves
  `pendingDoneIDs`/hides the toast) **synchronously from the row's own tap
  gesture**, via `.simultaneousGesture(TapGesture().onEnded(onNavigate))`
  alongside each `NavigationLink`, calling `TodayView.prepareForNavigation()`
  before the push can race either task. Verified with 3 consecutive clean
  runs of the originally-failing test, then all 6 affected tests together,
  after the fix. Lesson for any future bare `Task { }` scheduled from a
  SwiftUI action in a view that can be navigated away from: scope and
  cancel it explicitly at the point of navigation — `.onDisappear` is not a
  reliable backstop for a same-stack push on this toolchain.
- **Fast attention logging.** Each attention row gets "+5"/"+15" chips that
  call `AttentionSummaryViewModel.logFixedAmount` directly — no sheet — plus
  an "Other…" chip that keeps the prior slice's exact sheet flow and exact
  accessibility label (`"Log usage for {name}"`) unchanged, so neither
  existing test nor the logging-correction/deletion flow in the goal detail
  screen needed to change. `logFixedAmount`/`undoLastQuickLog` track only
  the single most-recently-chip-logged entry (`lastQuickLoggedEntryID`) —
  enough for one undo action, not a general-purpose history.
- **Recovery context on Today.** `TodayHabitRow.recoveryContext` is new:
  `TodayViewModel` now also computes `HabitProgressCalculator.recoveryProgress`
  (and, only when recovering, `streak` for its unit noun) per habit and
  renders "Rebuilding · {n} of {threshold} good days/weeks" in place of the
  normal schedule context line — reusing the *exact* existing recovery rule
  already established and tested for the habit detail screen, not a new,
  Today-specific approximation, and not restricted to daily schedules or
  positive polarity the way the HTML prototype's simplified mockup is
  (that restriction is explicitly a prototype simplification, not a rule
  this app follows elsewhere). `HabitProgressCalculator.recoveryCompletionThreshold`
  was changed from `private` to internal so this wording can read the
  threshold directly rather than duplicating the literal `3`. This answers
  UX.md's Today priority #3 ("What needs recovery?"), which Today previously
  answered nowhere — only the detail screen did.
- **AX sizes.** The pillar strip and each attention row's chip row switch
  from `HStackLayout` to `VStackLayout` via `AnyLayout` when
  `dynamicTypeSize.isAccessibilitySize`; habit rows switch to a stacked
  layout with a full-width `"Mark done"`/`"Done"` (or `"Log success"`/
  `"Logged"` for avoidance habits) bordered-prominent button, per
  COMPONENT_SPEC §6's stacked-row pattern — adapting to large text by
  reflowing, never by forcing two columns into less width.
- **iOS 26 Liquid Glass, with a fallback.** Today's two "Add" toolbar
  buttons use `.buttonStyle(.glassProminent)` tinted with `AccentColor`
  behind `if #available(iOS 26, *)`, falling back to `.buttonStyle(.borderedProminent)`
  on the same tint for the 17.0 deployment target — the one place this
  slice reaches for newer-than-deployment-target styling, guarded exactly as
  the task required.

### What changed everywhere else

Habit/attention forms, the habit and attention-goal detail screens, History,
Insights and Settings kept their existing structure and only adopted the
new *state* colours where a state already existed in the UI: recovery amber
on the habit detail screen's recovery message and Insights' "Needs
Attention" callout icon, teal on Insights' "Strongest" callout icon
(previously both were plain `.secondary`), and clay (`OverBudget`) on the
attention goal detail screen's status text and Today's attention-row icon
when a goal is over budget (previously literal `Color.red` — a direct
violation of `ICON_SYSTEM.md`'s "no red-tinted symbol for a habit state"
rule, found and fixed in this pass). `AccentColor` itself required no code
changes anywhere: every existing `Color.accentColor`/`.tint` reference
picks up the new Vivid teal automatically, since it is the same named
asset. Deliberately **not** changed: List/Form screens' own system grouped
background and `.secondary`/`.tertiary` text colours, which stay as system
semantic colours rather than being repainted with the warm-palette `Ink`
tokens — mixing a warm-neutral text colour against a cool system-gray List
background would be a visual regression, not an improvement, and only
Today (now a custom `ScrollView`, not a `List`) actually needed the full
warm `Background`/`Surface` treatment this slice built.

`HabitFormView`'s icon picker was also recurated per `ICON_SYSTEM.md` §2,
replacing the old flat 12-icon list with per-`HabitCategory` sets (plus
`ICON_SYSTEM`'s cross-cutting avoidance-only icons, shown in addition to a
category's own set whenever `polarity == .avoidance`). `ICON_SYSTEM.md` has
no entry for `.other`; this pass gives it a small general-purpose set that
deliberately still includes `"book.fill"` first, so the icon picker's
existing touch-target UI tests (which open the form at its default category
and look for exactly that icon) needed no changes.

### Deliberate simplifications versus the HTML prototype

The browser prototype's `app.js` implements several interaction details
this native pass does not reproduce literally, by design:

- **No FLIP pixel-reordering animation.** Rows moving between "to do" and
  "Done" use plain `withAnimation`/List diffing, not the prototype's
  measure-then-transform FLIP technique — the native idiomatic equivalent
  for this toolchain, not a missing feature.
- **No repeat-tap guard.** The prototype ignores a second tap on the same
  control within 600ms. SwiftUI's own button handling was judged sufficient
  for this slice; adding an artificial ignore-window risks rejecting a
  legitimate fast correction (tap to complete, immediately tap to undo) more
  often than it prevents an accidental double-fire.
- **No toast hover-pause.** The prototype pauses its countdown while a mouse
  pointer hovers the toast or focus is inside it — both signals that don't
  exist the same way on a touch device. The toast uses a single fixed
  4-second timer regardless of VoiceOver focus.
- **"Regroup immediately when leaving Today" ended up needed after all, for
  a different reason than expected.** The plan going in was to rely on the
  deferred timer alone (since any realistic navigation round trip outlasts
  1.5s anyway, the end state looks the same either way). That held for the
  row grouping itself, but the same "leaving Today" moment turned out to be
  load-bearing for a real bug — see "A real bug this introduced" above:
  `TodayView.prepareForNavigation()` now runs synchronously on every row's
  tap, resolving `pendingDoneIDs` and cancelling both pending `Task`s before
  the push. So Today *does* now have an explicit "regroup (and clean up) on
  leaving" path, just added for correctness rather than for the row-position
  cosmetics it was originally considered for. Several existing UI tests that
  complete a habit and then navigate away and back also needed a one-line
  fix to expand "Done" before looking for the row again, independent of the
  above; see `AvelaUITests.swift`'s `expandDoneGroupIfNeeded(for:in:)`.

### Known limitations

- **No Increase Contrast–specific asset variants.** Not needed this slice —
  every Vivid token already clears the relevant WCAG target at its default
  value (see "Colour tokens" above) — but a dedicated high-contrast
  appearance was not authored, so the system's own automatic contrast
  boost (if any) is what Increase Contrast would currently apply.
- **No on-device VoiceOver, Dynamic Type, or Reduce Motion verification.**
  Everything above was built to the written rules and exercised through
  XCUITest (which reads accessibility labels/identifiers/frames, but does
  not drive VoiceOver's actual swipe-navigation order) and the simulator's
  Dynamic Type / Reduce Motion settings, never a physical device or the
  Accessibility Inspector. Do not read this section as a completed
  accessibility audit.
- **Insights and History keep their existing card/list structure.** Only
  colour tokens changed; `InsightsHeroCard`'s sentence-style states and
  `DayLedger`'s week-aligned-or-not question (`VISUAL_DIRECTIONS.md`'s open
  question 4) are untouched, per this task's own scope ("apply shared
  tokens consistently," not a second layout pass).
- **No onboarding, companion, widgets, or Live Activity work.** Unchanged;
  still out of scope per BUILD_PLAN's phasing.


## MVP integration — 2026-10-04

The earlier slice notes describe their scope at the time. The current schema
also includes `HabitReminderRecord`, `CompanionProfileRecord`,
`AttentionCheckInRecord` and `AttentionSessionRecord`.

### Optional reminders and onboarding

Reminders are one saved local wall-clock preference per habit. The domain
planner produces native notification requests for daily/weekly-flexible or
selected-weekday schedules; flexible weekly reminders are daily nudges, not
proof of missed commitments. Permission is requested only after explicitly
saving an enabled reminder. Denial never prompts repeatedly; disabling and
archiving cancel delivery while retaining the preference for reactivation.
Foreground/edit/reactivation synchronization never requests permission.

Companion selection, enabled/haptics preferences and onboarding completion
live in SwiftData. Onboarding is six account-free steps with optional skips;
creation writes share the same free-tier policy as Today. The companion state
engine consumes known facts, prioritizing duration over-budget/near-limit,
recovery, meaningful completion, active session and calm. Unreported usage is
never treated as a measured healthy state. Animal concepts precede final art;
no placeholder mascot is silently substituted. Haptics obey the saved setting.

### Manual protected windows and sessions

Goal family is immutable after creation. Budget/window edits append snapshots;
wall-clock bounds are local minute-of-day values, including overnight windows.
Missing DST times use the next valid time; repeated times use the first
occurrence. Phone-free sessions capture absolute start/end and target duration
at start, surviving relaunch and later goal edits.

Proposed reporting rule awaiting product confirmation: explicit kept/interrupted
check-ins; a kept report requires the window or session to have ended, an
interrupted report can occur after its start, and missing reports remain unknown.
Elapsed time never generates a success. Protected-window reports have their
own wording and never count as an exceeded duration budget. Multiple reports
for a window append revision history; completed session outcomes are currently
final. These rules must not be called user-confirmed before the pending answer.

Minute targets must be finite and in (0, 1440]; each manual usage entry must be
finite and in [0, 1440]. Invalid edits are rejected before mutation. Formatting
also safely handles legacy extreme values, avoiding trapping Double-to-Int
conversion.

### History, Insights and presentation lifecycle

All Activity History now includes manual duration entries grouped by stored
local date keys and interpreted with historical budgets. Habit filtering is
unchanged. Closed-week attention review counts successful logged goal-days over
logged goal-days with explicit coverage; unlogged days remain unknown. Window
reports/session outcomes are not pooled into duration-budget results. Weekday
patterns compare daily/weekday habits only, requiring two resolved commitments
per compared weekday and two eligible weekdays; ties are named and balanced
results omit rankings.

Navigation destinations own stable view-model state. Undo feedback uses a safe
area inset instead of covering controls; quick-log chips have 44pt minimum
height. Foreground, significant clock changes and midnight refresh projections.

### Premium and widgets

Free creation permits 3 active habits and 1 attention goal. Verified unexpired,
nonrevoked StoreKit entitlements unlock unlimited creation. Existing tracking,
edits and history remain usable after expiry; StoreKit availability never blocks
local startup. Products `com.avela.premium.monthly` and `.annual` are placeholders
until App Store Connect matches them. Local `.storekit` prices are tests only.

Widget snapshots are read-only, atomically written JSON in
`group.com.example.Avela`; app and extension must use matching signed
entitlements. App-owned repositories remain the single SwiftData writer. Widgets
clear stale-day snapshots; named medium content is privacy sensitive, and Lock
Screen content is aggregate. Medium completion links open the app through a
strict `avela` URL parser; the app checks day, identity, archive and due state,
then writes idempotently with source `.widget`. Repeated links never undo.
Successful writes notify app composition to export updated snapshots. Isolated
DEBUG UI-test stores never export their fixtures into the real widget group.

`AVELA_UI_TEST_ONBOARDING=1` exercises onboarding in isolated DEBUG UI tests;
otherwise an isolated test-store launch bypasses onboarding. All hooks remain
compiled out of Release. No hook grants Premium.


### Integration review corrections

Protected check-ins attest to captured start/end bounds. A report for 07:00–09:00
cannot certify a same-day edit ending at noon. Overnight commitments resolve the
start-day's historical snapshot in both display and recording; selected days are
clamped to goal creation. Active sessions display their captured target even when
future targets are edited. Presentation refreshes at start/end/midnight boundaries
and reschedules on foreground or clock changes; elapsed time never writes results.
Reminder cancellation requests another synchronization pass if an older plan is
in flight, preventing an archived reminder from being restored by that pass.

Civil-day keys are now always Gregorian `yyyy-MM-dd` in the injected local time
zone. User-calendar week boundaries remain injected. This prevents Buddhist,
Japanese or Islamic calendar identifiers from changing persisted ordering or
History weekdays. History parses keys explicitly as Gregorian, then localizes
presentation. Normal Gregorian development stores need no reset. An unreleased
development store that actually contains old non-Gregorian day keys is not safely
migratable without calendar provenance; preserve it for inspection or explicitly
reset that development installation. No automatic store deletion was added.

Reactivating an archived habit checks the active-habit quota, preventing an
archive/create/reactivate bypass. Expiry never archives existing active records.
History remains accessible, and an archived habit can be reactivated after making
space or upgrading. Attention budget widgets intentionally include duration goals
only; window/session reports are not misrepresented as logged usage.

Settings and the paywall share `PrivacyView`; the optional public-policy link comes
from an HTTPS `AvelaPrivacyPolicyURL` Info value after owner publication. Bundled
explanation and the policy draft do not satisfy the public URL release gate alone.
An original native-rendered 1024px RGB app icon is bundled for beta review; final
branding and companion artwork remain separate owner design decisions.


### Final native visual verification

The app target now explicitly selects `AccentColor` through
`ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` in Debug and Release. The named
asset existed previously, but without that project setting SwiftUI system
controls fell back to blue. Today link labels use `appInk`/`appInkSecondary`
explicitly so secondary text does not inherit a low-contrast tinted link style.
At accessibility text sizes, habit and attention icon slots use their natural
width rather than a fixed 32-point width that allowed enlarged symbols to
overflow their cards. These are presentation fixes only.

The AX3 UI-test helper scrolls the frontmost hittable Form/List using a gesture
above the keyboard and its prediction bar. Full-frame swipes previously landed
on the keyboard and failed to reveal the duration field; no assertions were
removed. Native captures are in `docs/mvp-validation/`; the large-text screenshot
is taken during the short-lived undo toast, and its scrolled position differs
from the normal-size capture. Physical-device accessibility remains a gate.


### Illustrated companion integration — 2026-10-04

The authorized companion artwork pass replaces the text-only presentation with
original owl/fox/otter PNG atlases, six state-specific poses per animal. Existing
`CompanionProfile` fields, animal defaults and deterministic state priorities are
unchanged; no SwiftData migration is needed. `CompanionArtwork` is shared app/
widget presentation code, crops by documented row-major state order, and lazily
caches only each requested animal at 256-pixel cell resolution. Unknown animal
or state strings safely render no art. The source atlases remain untouched.

Today renders a brief crossfade and small celebration-scale transition; both
are disabled under Reduce Motion. There are no recurring idle animations.
The card stacks vertically at accessibility text sizes. Images are decorative
for VoiceOver; the combined card includes the existing truthful message and a
plain-language state description. Settings and onboarding show actual calm-pose
animal previews, retain all three choices and persist visibility preferences.

Widget schema version 1 gains optional `companionAnimal`/`companionState` strings.
Synthesis decodes older JSON without either key as nil; those snapshots show no
art rather than inventing a preference. The app exporter reads the persisted
profile, respects `companionEnabled`, and derives state with the same engine/
normalized inputs as Today. `meaningfulCompletion` is false in durable exports:
a stored completion is not a new transient celebration event. Home Screen
widgets render art only for valid current snapshots and mark it privacy-sensitive.
Lock Screen summaries remain text because an illustration is not practical at
the existing compact size. Widgets still never open SwiftData.

No network, permission, runtime AI service, dependency or medical claim is added.
Generation provenance, final prompt set and atlas contract are in
`design/companion-concepts/PRODUCTION_ART.md`. Physical-device visual/accessibility
and signed App Group verification remain release checks.

## Phone-free session Live Activity — 2026-10-04

No SwiftData schema change. `PhoneFreeActivityAttributes` is an ActivityKit
presentation contract shared with the existing widget extension: immutable
`sessionID`, `startedAt`, `expectedEnd`; mutable optional `animal` raw value.
No goal name, usage/history or outcome is copied into it. A focused pose represents
a real active session; stale content uses a calm pose and asks for confirmation.
Disabled companions use an hourglass. No animation loops or sound.

`SessionLiveActivityService` composes persisted Attention and Companion repository
facts with a `SessionLiveActivityAdapter`; `ActivityKitSessionAdapter` owns all
Apple API calls. Domain repositories do not import ActivityKit or start activities.
Only explicit Show requests can start a presentation. Duplicate requests reuse
the current session; explicitly showing a different session replaces the previous
presentation after successful creation without stopping either local session.
Hide removes the chosen session presentation without finishing its local session.

Foreground/mutation reconciliation reads existing OS activities, updates animal
preferences and ends missing, finished, expired or unauthorized presentations.
It never requests one on launch, so system dismissal is respected. The composition
root sleeps to the next activity deadline while executing; iOS background
suspension means exact background termination is not promised. The system
countdown and `staleDate` provide honest elapsed UI until the app reconciles or
the OS ends the presentation. Nothing auto-records Kept. Original session bounds
remain authoritative after goal edits or local time-zone changes.

Live Activities support at most eight-hour sessions here; longer sessions remain
valid in-app. No remote push tokens are requested. Existing widget/App Group
snapshot storage remains independent.

UI-test isolated stores do not access native ActivityKit unless the DEBUG-only
`AVELA_UI_TEST_LIVE_ACTIVITY=1` flag is explicitly supplied. Use only a dedicated
test simulator: reconciliation intentionally ends orphaned Avela activities.
That flag is compiled out of Release together with all other UI-test hooks.

Presentation changes are guarded during asynchronous update/dismissal. Show and
Hide cannot report success while an earlier dismissal is in flight; the controls
disable until it finishes. The regression uses a deliberately suspended platform
`end()` to prove rapid Hide → Show and duplicate Hide are rejected without ending
the local session. Companion preference saves explicitly refresh both Live Activity
and Home Screen widget adapters. Optional activity controls sit below the primary
Kept/Interrupted controls rather than displacing them.

### Native reminder review actions — 2026-10-05

`CompletionSource.notification` marks an explicitly confirmed reminder check-in.
The SwiftData completion still stores a source raw string; no model/schema
change or migration is needed. `HabitReminderAction` accepts only the owned
category/action, matching habit UUID and a planner-owned daily/weekday request
identifier. Default opening/dismissal is ignored. The response uses the actual
notification delivery timestamp, not a repeating request's creation date.

A retained UIApplication/notification delegate queues review on the main actor.
The app shell uses its existing repository/context to show the current habit
name and confirm. Before review and again at confirmation, the domain handler
checks current-calendar local day, delivery not in the future, habit existence,
creation date, archive status, due schedule and existing completion. Repeated
actions preserve the existing entry/source; explicit success replaces an excused
skip just like Today/Shortcuts. Avoidance means self-reported success, not
abstinence. There is no free-tier restriction on logging existing habits.
A successful confirmation returns to Today's root so progress/undo are reachable.

Native system testing caught a crash in UIKit snapshot/state-restoration work
when the async notification-response delegate bridge completed on a cooperative
executor. The completion-handler form now queues the response **and calls its
completion on the main actor**. UI tests exercise real native delivery and the
foreground action, rather than injecting a pretend notification response.

A DEBUG-only `AVELA_UI_TEST_REMINDER_DELIVERY=1` hook additionally requires
`AVELA_UI_TEST_STORE_PATH`: an explicitly enabled/authorized reminder gets one
8-second, nonrepeating trigger in that isolated run. Categories, content, OS
permission, delegate routing, review and persistence remain production code.
Normal requests still repeat at local wall-clock times. The hook never requests
permission itself and is absent from Release.

The review observer uses the payload delivered by `@Published`, rather than
rereading the publisher's property inside `onReceive` (publication occurs
before the property's assignment). Native UI tests caught the missed warm-app
review caused by that ordering. The confirmation captures the reviewed action
so another notification cannot change the identity being confirmed.

## Calendar history and appearance enrichment — 2026-10-05

Owner-authorized addition: read-only month history for each habit and five free
app accent themes. Neither adds new habit facts, backdating, permissions or
entitlement gates.

`HabitProgressCalculator.periods` exposes the same evaluated period sequence
used by streak, recovery and consistency. Each period carries its outcome, daily
or weekly unit, half-open evaluated span, distinct completed-day count and target.
Partial weekly spans stop at schedule edits or archive boundaries. Calendar
presentation never treats a flexible weekly habit's unlogged day as a daily miss;
weekly targets and outcomes appear separately below the dated check-ins.

Two existing engine boundary defects were found while adding regression tests:
an unfinished weekly target on the last day of a natural week was prematurely
closed as a miss, and archive/reactivate cycles on adjacent days lost the archive
boundary when there was no full dormant day. The engine now leaves the still-open
last day pending and honors every closed archive boundary independently of the
size of its dormant gap. Same-day pause cycles retain the existing civil-day
resolution: one daily outcome, and no duplicate success unit for a single day.
Pauses and skips remain neutral; no new misses or streak extension are invented.

The month calculator uses Gregorian civil dates and the user's locale, time zone
and first weekday. Completions/skips are grouped by their persisted `localDateKey`,
not a re-derived timestamp. The view model fetches the full fact set before month
projection so travel cannot drop a boundary record. Navigation bounds include the
months of stored facts, including a fact dated in the next local month after
travel; unrecorded future dates remain upcoming. Configuration history governs
past schedules. Current/best totals are through today regardless of selected
month; mixed daily/weekly histories are labeled successful commitments rather
than falsely presenting a homogeneous number of days or weeks.

Habit Detail → Calendar History shows linked daily successes, explicit symbols
and accessible outcome labels, excused skips, pending/missing daily check-ins,
unscheduled dates and pauses. Calendar dates are read-only accessibility elements;
there are no undersized day buttons. Accessibility text sizes use a vertical dated
list instead of compressing seven columns. No manual historical editing is added.

Appearance uses one separate `AppAppearanceRecord` added to the existing schema;
it leaves companion-profile fields untouched and requires no store reset. See
[THEMES.md](THEMES.md) for tokens, environment composition, failure handling,
upgrade preservation and contrast checks. App themes do not change widget or Live
Activity palettes in this slice.

Accessibility month lists show tracked/recorded dates, omit unrecorded upcoming
and pre-creation dates with an explicit explanation, and place weekly commitments
before the date list so large-text users need not scroll through a whole month
to find the target outcome. The regular grid still shows every civil date.

## Personal habit ordering — 2026-10-05

`HabitOrderViewModel` owns an unsaved list of every active habit. Cancel or sheet
dismissal writes nothing; Save calls the required `HabitRepository.reorderHabits`
operation with the complete ordered ID set. Missing/duplicate/archived/unknown IDs
or a changed active set are rejected before mutation; the screen explains that
Reload is needed when its draft became stale.

The repository reuses existing active `HabitRecord.sortOrder` slots. Archived
rows and all tracking facts, timestamps, snapshots and pauses remain unchanged;
reactivation restores the retained slot, and new creation appends as before.
Duplicate legacy active slots are repaired using nonnegative slots excluding
archived slots. Fetch ties use stable UUID ordering. A save failure restores only
the changed order fields, never rolls back unrelated context edits. No schema or
migration is introduced. Normal persistence notifications refresh app projections
and widget exports; the screen never directly writes SwiftData or widget data.

Today retains its due-date filter and To do / Done grouping. The new ordering
sheet has native drag handles, explicit 44pt Move Up/Down buttons, VoiceOver
custom actions, inline modal navigation and an accessibility-size stacked layout.
Settings offers the same sheet when no habits happen to be due today.

## Optional lighter-schedule review — 2026-10-05

`HabitAdjustmentCalculator` is a pure Foundation projection of the existing
progress-period engine. An active positive habit qualifies only while recovering
(fewer than three consecutive successes since the latest miss), with at least
two resolved misses under the same schedule/polarity in the recent window. The
window starts 14 local calendar days before today for daily/weekday schedules
and 28 before today for flexible-weekly schedules. Only periods starting within
that window and ending by evaluation time count; unfinished, excused and paused
periods never manufacture misses. Once-weekly schedules have no lower proposal.

Daily suggests an adjustable 3 times/week, with choices 1–6. A weekday schedule
with N days or a weekly target N suggests N−1, with choices 1 through N−1. These
are explicitly editable defaults, not evidence-backed prescriptions. Conversion
to flexible-weekly frequency removes fixed weekdays, which the current/proposed
schedule review makes visible. Cut Down habits, attention goals and Apple Health
quantity targets are never changed by this feature.

`HabitAdjustmentViewModel` fetches facts through HabitRepository. Loading or
dismissing is read-only. Before confirmation it rechecks the local day, active
positive status, ongoing recovery/eligibility, schedule and configuration
revision. A stale review requires Reload; it never silently applies a replacement.
The saved draft uses the latest cosmetic fields and normal updateHabit, appending
a snapshot effective today. Repeat confirmation cannot append another edit.
Earlier finished periods and all completion/skip/archive facts are retained; an
in-progress week may become a partial period under the existing schedule-change
semantics. No separate recommendation table or dismissal-history record.

The existing updateHabit write now obtains its revision before mutating, and
restores only the edited habit fields/removes its newly inserted snapshot if
save throws. It does not roll back unrelated context work. A real disk-save
failure was not injected during this pass.

Four additional theme enum values reuse the existing appearance record. Legacy
raw values and unknown-value fallback are unchanged; no schema migration, store
reset, permission, package, analytics or runtime AI service is introduced.


### Full-theme calendar presentation — 2026-10-05

The richer page/card palette and streak hero are presentation-only. Current/best totals, success ribbons, weekly logged/pending states, archive periods and configuration revisions still come from the existing calculator/view-model facts. No model, migration, repository or evaluation rule changed. Theme preference persistence is unchanged. Calendar totals are through today, not recomputed as totals ending in the browsed month. Native previews and verification are linked from SETUP.md.


### Exact current-day confirmation Undo

A logging confirmation captures the completion ID. TodayViewModel validates that the habit is active and that this exact fact belongs to the current local day before removing it. A stale/duplicate confirmation is read-only; it never toggles a refreshed row or creates a new completion. No schema change is required. UI accessibility timing and styling are independent of historical metric rules.


## Quantity activity, corrections, routines and reflections — 2026-10-05

`HabitActivityConfigurationRecord` stores a habit ID, stable ID, Gregorian local effective day key, per-habit revision, optional positive integer target/unit and optional 160-character smaller-action description. Effective `(dayKey, revision)` resolution preserves prior targets. Quantity targets are 1–10,000 count/pages/glasses/minutes for positive habits without a Health connection; connecting Health is blocked while a manual quantity target is active. Removing a target is another snapshot, not deletion. Changing a habit to Cut Down is rejected while its current manual quantity target remains enabled; turn the target off explicitly first. No failed edit changes historical snapshots. Same-day configuration changes affect subsequent logging; they never retroactively manufacture success.

`HabitActivityEntryRecord` stores a stable fact ID, habit/configuration IDs, captured day key, logging timestamp, amount/unit, kind and captured description. Quantities in the currently applicable unit add together for that day, including earlier same-day revisions in the same unit. A unit change does not reinterpret old amounts. Crossing the target records one canonical Completion; extra amounts remain visible. Removing quantity below target withdraws quantity-derived success while preserving independently recorded check-ins. Smaller-action entries are idempotent per day and never create Completion or excused Skip. They remain visible in Progress & History; the existing aggregate History continues showing canonical completion/skip facts.

`CompletionRecord.isQuantityDerived` defaults false for older records. Generic app/system completions made against an active quantity target retain their actual source and set this flag; reconciliation can withdraw those too. The new quantity source identifies directly generated quantity success, and watch identifies a paired Watch check-in. HabitRepository's validation boundary is checked before shortcut/reminder/widget skip removal, preventing an invalid attempt from erasing an excused skip. Widgets with unmet targets open Today rather than tick them. Quantity creation and reconciliation share a transaction in a private autosave-disabled context; failures roll back only this feature. Existing repositories see persisted facts through their own reads.

`HabitTimerRecord` stores one current habit/day timer with optional start timestamp and accumulated seconds, bounded to one day. It is an elapsed-time aid, not proof of reading or phone-free behavior. Date/time arithmetic includes background elapsed time; clock rollback cannot add negative duration. Timers are day-scoped, require an active minute target, and never auto-log. Paused whole-minute logging inserts the quantity, reconciles completion and deletes the timer atomically, so a retry cannot duplicate a successfully consumed timer. Logging whole minutes discards the remaining sub-minute seconds and resets the timer.

Dated corrections compare captured completion/skip IDs plus activity/schedule configuration IDs before writing. Dates use historical schedules and archive periods, reject future civil days, pre-tracking days, pauses and unscheduled days, and keep the selected Gregorian day key. Today timestamps are capped to the current instant. Success/skip/clear replaces only canonical facts; quantity/smaller-action entries are retained. A quantity correction requires its target and remains quantity-derived. Deleted facts cannot be restored through a transient Undo toggle; a further explicit correction is required.

`RoutineRecord` references ordered stable habit IDs and an optional 3/7-day restart duration. Save validates selected active IDs and an 80-character name; cancellation persists nothing. Archived references remain stored but disappear from the runner. Deleting a routine leaves habits/history untouched. Restart review dates use calendar-day arithmetic; neither creation nor expiry changes a schedule, pauses a habit or completes anything.

`WeeklyReflectionRecord` uses a unique captured civil start/end week key, boundary dates/timezone metadata, two optional 500-character answers and creation/update timestamps. At least one nonblank answer is needed to save. Explicit Save/Cancel/Delete operate independently of calculated metrics. No reflection content enters widgets, companion, Watch, analytics or network services. Private contexts isolate rollback in routines and reflections.

The expanded schema adds six model types and the default-false completion attribute. SwiftData's lightweight transition is used; no destructive reset is requested. Tests cover prior schema model additions/disk reopen, not a universal migration guarantee across every development build. Back up valuable test data before installing candidate builds; never silently delete a store that fails to open.


### Manageable Week and linked phone-free intentions

Manageable Week is read-only until the user confirms an individually named pause or creates a selected 3/7-day restart group. Pause uses existing archive-period history; other habits are untouched, and reminders are synchronized. Restart progress counts successful commitments whose period starts on or after the plan's civil start day; earlier same-day successes count, while a flexible week's prior start does not. Smaller actions remain distinct. The review date is informational, never a automatic target or schedule change.

`IntentionSessionLinkRecord` is the sixth new schema model in this expansion. It stores stable ID, habit ID, unique session ID and creation timestamp. Associations are immutable; retrying the same association is idempotent. Make Room starts an existing phone-free goal explicitly, then persists the link in its own autosave-disabled context. This is two writes: link failure discloses that the session already started and preserves its detail destination. Session elapsed time/manual results never create habit completion. The existing session detail controls optional Live Activity presentation separately.

Progress view models bind loaded facts to a captured local day. Date changes require reload, and backdate confirmation captures the reviewed date; a midnight reload cannot redirect the confirmed write to another day. Corrections also validate historical schedule/configuration revisions and existing fact IDs.

## Factual reflection context — 2026-10-05

No schema changes. ReflectionViewModel reads the selected week's completion/skip records and each habit's configuration/archive history through HabitRepository. HabitProgressCalculator.consistency remains the only per-habit metric authority. Results are derived, not saved; filtering by habit ID prevents cross-habit attribution. Notes remain independent WeeklyReflection records, with no text analysis. Progress and note errors are independent; failed progress refresh clears results rather than showing a prior week's facts. Insights creates the reflection model with its selected week's start and injected calendar.


## Optional iCloud recovery snapshots — 2026-10-05

No stored model properties or schema constraints were changed. BackupPayload has
explicit Codable rows for all 20 current model types, with lossless restore
initializers. Capture reads committed rows with a fresh ModelContext. Archive v1
has a UUID, capture date, exclusion count, sorted JSON payload and SHA-256 checksum
(for corruption detection, not encryption or authenticity). Limits: 40 MiB payload,
80 MiB envelope and 200,000 rows; duplicate IDs, invalid dates/day keys/scalars and
dangling references are rejected before writes.

Before serialization, remove Health connections and whole habits categorized
health/fitness, currently connected to Health, or with any Health-imported success.
Remove their histories, reminders, activity/timers and intention links; filter
routine membership and omit empty routines. Remove all reflection records and
completion notes. The same restrictions are enforced when decoding. Eligible
tracking and profile/theme preferences retain original IDs/dates/revisions.

Restore is restricted to zero tracking rows across all tracking types; existing
profile/theme defaults can be replaced then. Pending local edits block it. One
save commits the validated graph, with rollback on failure. Reminders are restored
disabled; running habit timers pause at the captured elapsed duration. Unfinished
phone-free sessions end at capture time with no outcome. No completion is inferred.

Cloud records are immutable UUID-addressed AvelaRecoverySnapshot rows in the
private database. Keep every dated snapshot until explicit user deletion; quotas
can stop uploads. Local consent/device ID/last-success live in app-owned defaults.
Account changes revoke consent and invalidate previews. Automatic uploads debounce
15 seconds and throttle to 10 minutes while the app can execute; foreground/save
or manual action retries errors. No continuous background guarantee or live sync.
The existing isolated test hooks can select cloudBackupRecovery only in Debug;
its fake provider uses an in-memory source and never contacts CloudKit. Release
contains neither that provider nor its fixture selector.

## Lifetime progress, quick amounts and intention review — 2026-10-06

No SwiftData model/schema changes or stored aggregate counters are introduced. `HabitLifetimeCalculator` counts distinct surviving `Completion.localDateKey` values for the habit through the as-of instant. Milestones are 10, 25, 50, 100, 250, 500 and 1,000 successful check-in days; these are days, not streaks or successful weekly commitments. Misses/pauses do not erase totals, while Undo/corrections recompute them honestly. Activity entries are deduplicated by ID, filtered by their actual write timestamp, and quantity totals are grouped by captured unit. Smaller-action days stay separate. Reads include all stored civil keys so changing time zones cannot hide the first or latest logged day.

`HabitActivityRepository.entries(for:in:)` returns stored civil days intersecting a half-open interval. Midnight end excludes that day; a partial end includes its intersecting day. Membership uses captured day keys, not entry write timestamps, so backdated entries remain in their recorded day. Lifetime reads all keys and applies its as-of write cutoff separately.

`HabitQuickLogPresets` stores one to three unique integers (1–10,000) per habit UUID and unit in app-owned UserDefaults. Defaults: count/glasses 1/2/3, pages 1/5/10, minutes 5/10/20. Save validates the currently reviewed configuration and day; Cancel never writes. Quick logging uses the existing repository validation, and Undo removes only the newly inserted entry ID, preserving prior entries and independent successes. Midnight, stale configuration and historical days cannot silently accept a quick action. These preferences do not alter targets or reinterpret history, and are not part of the logical iCloud recovery payload; a new installation uses unit defaults while recovered progress remains intact.

`MadeRoomReviewCalculator` attributes each linked session once by session ID, only when its start is inside the selected completed local week. Kept/interrupted counts require an ended session with that recorded self-report; unfinished/unreported sessions stay neutral. Timer minutes sum ended elapsed durations, never verified phone-free time or reclaimed time. Invalid durations (negative, non-finite or over seven days), missing sessions, conflicting copies/owners are omitted with a partial-data message. Sessions ending after the week are attributed to their start week. Linked habits may be archived; current names and separate stored-key successful check-in days are shown. The view model pads timestamp completion reads by two days before applying captured civil-key membership for travel. Opening/refreshing a review never starts a session, logs a habit, or analyzes private notes. Insights passes its selected week to a stable navigation destination.

A new DEBUG-only `progressEnrichment` fixture uses public repositories to exercise lifetime milestones and populated linked-session review in an isolated test store. It shares the existing two-variable gating and is absent from Release.

## UI polish display projection — 2026-10-06

Today’s recovery projection removes the “Rebuilding ·” prefix; the successful-count, unit and existing three-success cutoff are unchanged. Quantity progress remains primary when present. This is copy/layout refinement only: no new model, aggregate, revision, persistence rule or migration. Historical state, excused skips, pauses, manual usage labels, independent session/check-in semantics and Undo guards remain unchanged. Stable screen/action IDs are retained for native regression tests.

## Atmospheric theme presentation — 2026-10-06

No schema, revision, date key, record or derived progress rule changes. Theme raw values are unchanged. HabitIconBadge maps existing SF Symbol names to curated identity colors only; editing names/icons still follows the existing cosmetic/history behavior. The calendar renderer remains read-only. No artwork is selected from private habit text, calendar success or reflection content.

### Recovery-card presentation (2026-10-06)

No schema changes. `TodayRecoveryDisplay` composes recovery count, historical period units and adjustment eligibility from existing calculators. Successful periods since the latest miss are compared with the currently active streak unit; mixed runs are labeled commitments. Only active habits due today enter the card, matching Today's existing row scope. Configured smaller actions for positive habits open the existing activity screen with that section prioritized, never logging on navigation. Their effort records do not affect the recovery count.

Threshold feedback compares the pre/post logging projection. Undo retains the exact completion ID and existing civil-day guard; removing the third success naturally brings the two-success card back. The DEBUG-only `recoveryProgress` fixture uses public repositories for two prior successes following two misses and a configured smaller action. Existing isolated-store guards apply; it is not available in Release.

### Visual Insights projection — 2026-10-06

No schema or calculator changes. The ring renders `overallConsistency` unchanged; per-habit bars render each `eligibleHabits` percentage with successful/resolved counts. The overall score remains an equal-weight average, not pooled commitments. Icons come from currently persisted habit identity, never fabricated historical identity. State-owned detail destinations survive parent refreshes; their View History callback is wired to the existing filtered History tab.

Manual attention's two bars visualize existing successful/logged and logged/eligible ratios separately. Threshold behavior remains healthy <70%, near limit <100%, exceeded >=100%; the correct review label is **below budget**, not “at or below.” Session-only goals retain the review shell/intention review but do not display an absent budget summary. The `visualInsights` DEBUG-only fixture includes daily and archived flexible-weekly habits plus three manual usage days (one below budget, one over, one exactly at budget), giving a 68% rounded habit average and 33% below-budget result with 3/7 coverage. Existing redirected-store guards apply; no production clock or fixture hook is added.


## Reflection dictation — 2026-10-06

No schema or metric changes. ReflectionDictationModel keeps an ephemeral transcript separate from ReflectionViewModel.draft and the repository. AppleReflectionSpeechCapture is a platform adapter; only an explicit Add Text appends the edited transcript to the chosen prompt. Existing Save is the only persistence action. Cancel discards the preview; typed draft text remains intact. Session IDs reject late callbacks and capture after permission cancellation. On-device support is required; there are no audio files or voice-command-derived completion writes. Reflection limits and private backup exclusions remain unchanged. Native recognition uses Apple's speech models, not a generative LLM or Avela-operated inference service.


## Focus sessions and Make Room flow — 2026-10-06

AttentionGoalType adds the raw value focusSession; existing typeRaw string columns, AttentionSession and IntentionSessionLink records are reused without a new schema/table. isTimedSession covers focusSession/phoneFreeSession consistently in start/report, summaries, intention history, factual review and Live Activity reconciliation. Old raw values and history are unchanged. Focus session outcomes are manual and constrained by the same captured start/end boundaries; no habit writes occur until the user opens and acts in the existing logger.

SessionLiveActivityDescriptor adds an isFocusSession presentation flag. Shared ActivityKit ContentState adds optional isFocusSession (nil decodes as old phone-free presentation). No private habit name or text is exported. Backup goal raw-value validation accepts the new enum; older app versions that do not recognize focusSession should reject that backup rather than silently reinterpret it. Inline goal creation rechecks the active habit and current plan limit; opening/saving the form does not start a session. Failed link writes keep the already-started session review path and never create a false habit completion.

## Differentiation: memory, Momentum and recovery choices

`HabitRecord.whyItMatters: String?` and `whyMemoryHidden: Bool?` are optional additive columns. Legacy nil decodes to no reason / visible preference. Domain and drafts expose `whyItMatters` and `isWhyMemoryHidden` with defaults. Repository writes trim whitespace and reject reasons above 240 characters before mutation. Hide preserves text; blank removes it. Reason-only edits append no configuration snapshot. Habit edits and Make It Easier preserve the reason.

Reasons and visibility are deliberately absent from `BackupPayload.HabitRecordRow`; logical restore initializes them nil. They never enter widget/watch snapshots, Live Activity attributes, telemetry or recommendation inputs. Apple device backups are separate from Avela logical recovery. A text memory appears only in recovery detail and before Make Room, subject to the persistent Hide preference.

`HabitMomentumCalculator` composes existing historical progress and lifetime calculators. Recent Rhythm is the half-open last-14-local-day window including today: successful / resolved commitments. Zero resolved units produces unknown, not 0%. Skips and pauses are excused; open periods stay pending; a flexible-weekly target is one commitment. Coming Back retains the three-success threshold, with mixed day/week recovery called commitments. Lasting Effort shows distinct stored success days, separate smaller-action days, and quantity totals by captured unit. There is no weighted score. Misses and pauses do not erase lifetime facts; undo/correction updates surviving records.

`HabitRecoverySuggestionCalculator` offers support only for an active positive habit, on a pending scheduled period, while recovering, after at least two closed misses on the exact current configuration revision within 14 days (daily/weekdays) or 28 days (flexible-weekly). Old configurations, skipped/paused/unscheduled days and today's logged smaller effort do not supply this trigger. Review is revalidated at action time against day, configuration, progress and configured action. Opening a logger does not save. Pause requires a named native confirmation, uses existing archive history and reminder synchronization, and has no automatic resume: Settings → Archived Habits is explicit. Sheet handoff waits for dismissal before opening the existing logger.

Make Room shows distinct linked session starts in the current half-open calendar week. The weekly review pairs the same factual session count with separately recorded habit check-ins. Starts are not successful sessions, verified focus or causal evidence of habit completion.

Companion app presentation uses steady, building momentum, recovering, and needs space (labelled “Logged budget exceeded”). Priority: recorded exceeded budget, active recovery, recorded habit check-ins, steady. Unknown usage or a running timer never implies achievement/overload. Existing six-state artwork/widget keys remain compatible; no storage schema changes. State labels and distinct existing poses accompany color; Reduce Motion disables crossfades.

## Quick Log widget boundary

No SwiftData schema or store location changes. WidgetSnapshot version 1 gains optional capability metadata per habit (configuration revision, quantity requirement, skipped state, polarity-aware action label), snapshot timezone, light/dark accent RGB values, temporary pinned row IDs/deadline and a generic retry message. Older snapshots decode but cannot enable an interactive write without all required metadata. Private reasons, notes and recordings remain excluded.

QuickLogProjection performs only display ordering/counts. Pending rows precede settled rows, preserving canonical user order within each group. A successful action pins the four currently leading IDs for 30 seconds; a scheduled timeline entry restores pending-first order afterwards. This is a display preference, never a completion fact. 'All logged today' requires every exported due row to have a saved completion; skipped-only or mixed settled states say 'No check-ins left today.' Flexible-weekly context remains explicitly weekly.

QuickLogHabitIntent is shared by app and widget, conforms to Apple's LiveActivityIntent app-process execution marker, and has openAppWhenRun=false. It starts no Live Activity. The widget compilation branch cannot access SwiftData. App execution shares AppPersistence.liveContainer.mainContext; a synchronous MainActor QuickLogService validates current civil day, timezone, configuration revision, existing habit, archive state, due schedule, absence of quantity target, saved completion and skips before recording source=widget. Repeated taps are idempotent. Skips require in-app review; there is no widget Skip/Undo/Delete/Archive action. Canonical completion insertions are discarded if their save fails, without rolling back unrelated edits.

Snapshot refresh occurs after the save. No optimistic checkmark or rollback of a successful user-data write on export failure. Failures retain prior display facts and expose a generic open-app recovery message. A stale or changed-zone snapshot renders a refresh prompt. Name/logger deep links never write. The main app composes their modal destinations with stable view-model identity.

Quick Log also settles a flexible-weekly row when its exported weekly target is met; the row shows 'Weekly goal met' and opens details rather than inviting another required check-in. Additional voluntary check-ins remain available in the app. Removing the whole-widget widgetURL from Quick Log is intentional: in simulator verification it overrode the small widget's per-row name link. Explicit Link controls now own navigation; unused background areas retain the system's default app-opening behavior. Background refresh includes the existing companion profile so other widget options retain their presentation.

Quick Log's stale-day state offers a user-initiated 'Refresh habits' App Intent that reads the app-owned canonical repositories and exports today's facts without foregrounding Avela. It does not create a completion, auto-reset progress, or evaluate history inside the extension. If refreshing cannot succeed, the stale prompt and explicit Open Avela recovery link remain; the date on old facts is never advanced to fake freshness. WidgetKit controls refresh timing.


## Two focused widgets — 2026-10-07

WidgetSnapshot v1 gains an optional routines array (ID, display name, ordered habit IDs); older snapshots decode without it. The canonical app exporter includes routines on foreground, successful routine mutation and background log/refresh. The extension reads only JSON. Routine configuration uses an AppEntity/EntityQuery over that projection. Deleted/non-due/archived members cannot create phantom steps; projection intersects the saved sequence with canonical Today rows and retains quantity/skip/revision guards. Successful routine save/delete now posts the existing persistence-change notification after commit. No SwiftData schema change; private reasons and reflection content are not exported.

### Widget pending presentation follow-up — 2026-10-07

Only each row's status caption uses `invalidatableContent`; Log and Refresh buttons keep stable labels/fills during pending system work. Saved completion remains the sole source of completed state. The shell publishes on persistence notifications only while active, leaving background widget intents to publish the final pinned snapshot after canonical save rather than racing it with an unpinned projection. Foreground edits and foreground refresh retain their existing exports. No schema or permission changes. Cold-process logging and limitations are recorded in [verification](verification/two-widgets/README.md).
