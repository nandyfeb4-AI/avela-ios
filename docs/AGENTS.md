# Coding Agent Instructions

This repository is designed to be implemented with tools such as Codex or Claude Code.

## Read order

Before implementation, read:
1. `VISION.md`
2. `MVP.md`
3. `ARCHITECTURE.md`
4. `DATA_MODEL.md`
5. `UX.md`
6. `TECH_STACK.md`
7. `DEPENDENCIES.md`
8. `APPLE_COMPLIANCE.md`
9. `TESTING.md`
10. `BUILD_PLAN.md`

## Product authority

- `MVP.md` is the V1 scope contract.
- `VISION.md` defines product direction.
- `ARCHITECTURE.md` defines architectural boundaries.
- `APPLE_COMPLIANCE.md` defines non-negotiable platform constraints.

Do not silently invent major product behavior.

## Engineering rules

- Prefer Apple-native APIs.
- Keep V1 local-first.
- Do not add a backend unless requested by a documented requirement.
- Do not add third-party packages without updating `DEPENDENCIES.md`.
- Keep domain logic independent from SwiftUI where practical.
- Hide platform-specific attention APIs behind adapters.
- Preserve historical facts when users edit goals.
- Treat dates/time zones explicitly.
- Avoid unnecessary abstraction.
- Avoid premature micro-packages/modules.

## Change discipline

For any change that modifies user-visible behavior:
- update or confirm `MVP.md`
- update tests
- update data model docs if schema semantics change
- update compliance notes if permissions/data handling change

## Coding style

- favor readable Swift over clever Swift
- small focused types
- descriptive names
- explicit domain enums
- no giant view models
- no hidden global mutable state

## Testing rule

Do not mark a feature complete until:
- domain behavior has appropriate tests
- critical UI flow works manually
- no known crash exists in happy path

## Dependency rule

Before adding a package, answer:
1. What problem does it solve?
2. Why are Apple APIs insufficient?
3. What privacy/security implications exist?
4. How hard is removal later?

If those answers are weak, do not add it.

## Scope rule

Do not implement POST-MVP features simply because they are technically easy.

## Compliance rule

Never implement:
- manipulative permission prompts
- misleading subscription UX
- fake system dialogs
- medical claims
- hidden data collection

## Completion reporting

When finishing a task, report:
- files changed
- behavior added
- tests added/updated
- any known limitation
- whether docs need updates
