# Testing Strategy

## Release philosophy

Critical behavior must be testable independently from SwiftUI.

## Unit tests

Required for:
- daily streak calculation
- flexible weekly completion logic
- skip behavior
- recovery calculation
- attention threshold state
- weekly summary metrics
- companion-state derivation
- subscription entitlement interpretation where feasible

## Date/time tests

Must include:
- local midnight boundary
- week boundary
- daylight saving transition
- time zone change
- month/year boundary

## UI tests

Critical flows:
1. first launch / onboarding
2. create daily habit
3. create 3x/week habit
4. log completion
5. undo completion
6. create attention budget
7. manual usage entry
8. weekly review navigation
9. paywall presentation
10. restore purchase path
11. notification permission denial path

## Widget tests

Verify:
- correct snapshot
- no-data state
- logged-in/app-state equivalent is not assumed
- update after completion where supported

## StoreKit testing

Use StoreKit test configuration.

Test:
- successful purchase
- cancelled purchase
- pending purchase
- restore
- expired entitlement
- StoreKit unavailable

## Accessibility checks

Before release:
- VoiceOver labels
- Dynamic Type
- touch target sizes
- Reduce Motion
- dark mode

## Manual release checklist

- airplane-mode core flow works
- no crashes after app relaunch
- data survives restart
- no placeholder copy
- no broken deep links
- privacy disclosures match implementation
