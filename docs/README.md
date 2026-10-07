# Attention Habit iOS

A native iOS habit and attention-management app focused on flexible behavior change, information-consumption budgets, recovery-oriented progress, weekly insights, and a calm spirit-animal companion.

## Product thesis

This is not a generic habit tracker with a mascot. The product combines:

- strong habit-tracker parity
- flexible weekly goals
- attention / information budgets
- recovery-oriented progress instead of punitive streak loss
- weekly behavioral insights
- a native iOS spirit-animal companion
- widgets and time-bound Live Activities
- local-first privacy

## Source of truth

Read these documents before changing implementation:

1. `VISION.md`
2. `MVP.md`
3. `UX.md`
4. `ARCHITECTURE.md`
5. `DATA_MODEL.md`
6. `TECH_STACK.md`
7. `DEPENDENCIES.md`
8. `APPLE_COMPLIANCE.md`
9. `DESIGN_SYSTEM.md`
10. `TESTING.md`
11. `BUILD_PLAN.md`
12. `AGENTS.md`

If documents conflict, `MVP.md` defines V1 product scope, `ARCHITECTURE.md` defines code boundaries, and `APPLE_COMPLIANCE.md` defines non-negotiable platform constraints.

## V1 principle

The app must work fully offline for its core experience. A backend is not required for V1.

## Design quality

- [Apple criteria and Avela quality plan](DESIGN_QUALITY_PLAN.md)
- [Journey inventory, implementation and private usability checklist](QUALITY_EXECUTION.md)

Native progress/routines/reflection/recovery/Watch expansion previews: [enrichment verification](verification/enrichment/README.md).

Progress enrichment verification: [native checks and screenshots](verification/progress-enrichment/README.md).

Native UI polish: [light/dark screenshots and verification](verification/ui-polish/README.md).

Atmospheric themes: [native light/dark gallery and verification](verification/atmospheric-themes/README.md).

- [Recovery progress card verification](verification/recovery-card/README.md): native light/dark and accessibility-size support/Undo flows.

- [Visual Insights verification](verification/visual-insights/README.md): native completed-week analytics, manual coverage, archived history and large-text navigation.
