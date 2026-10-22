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


[Implemented features and UX inventory](FEATURES_AND_UX_REVIEW.md) is a shareable product-review document, including verification gaps and proposed differentiation hypotheses.

## Connected differentiation

[Native screenshots and verification](verification/differentiation/README.md) document optional reasons, explainable Momentum, confirmed recovery choices, factual Make Room connections and companion states.


## Calendar and native capture integrations — October 7, 2026

Make Room now offers optional, user-reviewed Calendar planning and an App Shortcut for explicit linked session starts. Watch successful replies use inline confirmation. No completion is inferred from planning, timers or app use. [Implementation and verification](verification/calendar-integrations/README.md). Screen Time shielding remains unimplemented pending the separate entitlement and lifecycle gates; current sessions never block apps.


## Optional app protection — October 7, 2026

Native development shielding and AvelaProtectionMonitor are implemented; Release availability remains off until signed-device lifecycle tests and Apple distribution approval. Simulator setup is informational only; current ordinary sessions/Shortcuts do not block. [Implementation and validation](verification/app-protection/README.md) · [Signing and hardware gates](SCREEN_TIME_INTEGRATION_PLAN.md).


## Account-independent readiness — October 7, 2026

Account-independent release checks, native screenshots and the resolved largest-text audits are recorded in [release-readiness verification](verification/release-readiness/README.md).

## Rilova brand identity — 2026-10-07

See [Rilova rebrand verification](verification/rebrand/README.md) and [brand assets](../design/brand/rilova/README.md). Historical verification reports may still use the former visible name; internal project identifiers remain Avela.

[Scoped Rilova brand polish](verification/brand-polish/README.md): onboarding and Today presentation, contrast and native screenshots.

Final Rilova presentation continuity and screenshots: [brand completion verification](verification/brand-completion/README.md).

- [Full simulator regression — October 8, 2026](verification/full-regression/README.md)
