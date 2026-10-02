# Build Plan

## Phase 0 — Repo scaffold

Create:
- Xcode project
- app target
- widget extension
- Live Activity extension if included in V1
- test targets
- documentation folder
- base navigation
- SwiftData container
- shared models / domain folder structure

## Phase 1 — Habit engine

Build:
- entities
- scheduling
- completion
- history
- streaks
- flexible weekly logic
- recovery

Exit criteria:
- unit tests pass
- Today screen can render real persisted habits

## Phase 2 — Attention engine

Build:
- attention goals
- manual usage
- threshold states
- protected windows
- phone-free session model

Exit criteria:
- manual goal can be created, tracked, and reviewed historically

## Phase 3 — Core UX

Build:
- onboarding
- Today screen
- history
- insights shell
- settings
- empty states

## Phase 4 — Companion

Build:
- animal selection
- companion state engine
- core animations
- dashboard integration

## Phase 5 — Native system surfaces

Build:
- reminders
- widgets
- Live Activity for phone-free session if included

## Phase 6 — Insights

Build:
- weekly metrics
- strongest / weakest patterns
- recovery insight
- attention summary

## Phase 7 — Monetization

Build:
- StoreKit products
- entitlement manager
- paywall
- restore purchases

## Phase 8 — Compliance and release quality

Complete:
- accessibility
- dark mode
- privacy copy
- App Store metadata draft
- reviewer notes
- TestFlight build
- regression testing

## Scope firewall

Do not pull post-MVP items into the active build unless:
1. V1 requirement cannot work without it, or
2. `MVP.md` is explicitly changed.
