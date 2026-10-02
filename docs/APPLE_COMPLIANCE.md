# Apple Compliance

This file is a product and engineering checklist, not legal advice.

## Core review posture

The app must have real, differentiated functionality.

Positioning:
- not a generic streak tracker
- not a reskinned template
- not a virtual pet with thin utility

Differentiating workflows:
- attention budgets
- flexible weekly habits
- recovery-oriented progress
- weekly insights
- stateful companion tied to actual behavior

## Minimum functionality

Before App Store submission:
- no dead buttons
- no placeholder screens
- no broken widgets
- no major "coming soon" surfaces
- no demo-only flows presented as complete
- subscription purchase and restore must work

## Privacy

Principles:
- collect the minimum data needed
- local-first by default
- no hidden data sharing
- permissions requested in context
- app remains useful when optional permissions are denied

If third-party analytics or AI is added later:
- document every data category transmitted
- update privacy disclosures
- avoid sending habit content unless necessary

## Notifications

- request permission in context
- no repeated nags after denial
- notifications must be user-configurable

## Screen Time

Future integration may require Apple capabilities / entitlements.

Do not block V1 on Screen Time access.

Architecture must isolate Screen Time-specific APIs behind an adapter.

Do not imply capabilities that Apple has not granted.

## Live Activities / Dynamic Island

Use only for genuine active, time-bound experiences.

Appropriate:
- active phone-free session
- focus session with a known end condition

Avoid:
- permanent mascot residency
- fake ongoing activity

## Subscription rules

Must:
- clearly communicate price and billing period
- clearly explain premium value
- support restore purchases
- avoid manipulative scarcity
- avoid obscuring free functionality

## Health / medical claims

Do not claim:
- treatment
- diagnosis
- improved mental health outcomes
- clinically validated behavior change

Use lifestyle/productivity language.

## App Review notes

Prepare reviewer notes explaining:
- core product purpose
- attention-budget workflow
- how manual attention logging works
- why the app is differentiated from a generic habit tracker
- any optional capabilities and how to test them
- subscription test path if required

## Feature compliance template

For every new significant feature record:

```text
Feature:
User value:
Data used:
Data leaves device?:
Permission required:
Apple capability / entitlement:
Review risk:
Mitigation:
Reviewer test steps:
```
