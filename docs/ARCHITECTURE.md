# Architecture

## Architecture goals

- native iOS
- local-first
- offline-capable
- simple enough for a small product
- modular enough to add Screen Time and sync later
- deterministic domain logic
- UI independent from persistence details

## Layering

Recommended:

```text
SwiftUI Views
    ↓
View Models / Feature State
    ↓
Domain Services / Use Cases
    ↓
Repository Protocols
    ↓
SwiftData Repositories
```

Platform adapters sit beside domain logic:

```text
NotificationAdapter
StoreKitAdapter
WidgetDataAdapter
LiveActivityAdapter
AttentionUsageProvider
```

## Modules / feature boundaries

```text
App
├── Habit
│   ├── Domain
│   ├── Data
│   └── UI
├── Attention
│   ├── Domain
│   ├── Data
│   └── UI
├── Insights
├── Companion
├── Notifications
├── Subscription
├── Widgets
├── LiveActivity
├── Settings
└── Shared
```

A single Xcode target plus extensions is acceptable for V1. Separate Swift packages are not required unless complexity justifies them.

## Repository protocols

Suggested interfaces:
- `HabitRepository`
- `CompletionRepository`
- `AttentionRepository`
- `SettingsRepository`

The UI must not directly perform SwiftData queries except simple read-only cases intentionally approved by architecture.

## Attention usage abstraction

```text
AttentionUsageProvider
├── ManualAttentionUsageProvider   # V1
└── ScreenTimeAttentionUsageProvider  # future
```

Domain logic consumes normalized usage data rather than Screen Time framework types.

## Persistence

SwiftData is the canonical V1 store.

No backend dependency for core user journeys.

## Derived metrics

Prefer recomputable derived values over storing redundant aggregates.

Examples:
- current streak
- best streak
- weekly consistency

Cache only if profiling proves necessary.

## Date/time rules

All behavior must be explicit about:
- local calendar day
- local week
- time zone changes
- daylight saving transitions

Persist timestamps in a stable representation and derive display/calendar grouping using current business rules.

## Side effects

Domain logic should not directly:
- schedule notifications
- call StoreKit
- update widgets
- start Live Activities

Use adapters/services.

## Sync future-proofing

Do not design V1 as if cloud sync already exists.

Use stable identifiers and update timestamps so sync can be added later.

Recommended entity metadata:
- UUID
- createdAt
- updatedAt
- archivedAt where relevant

## Dependency direction

Domain must not depend on:
- SwiftUI
- StoreKit UI
- WidgetKit
- ActivityKit
- Supabase SDK

Platform adapters may depend on domain interfaces.
