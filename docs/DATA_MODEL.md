# Data Model

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
