# Avela design quality and Apple award research

Research checked on 2026-10-05. This document translates Apple's published design guidance into proposed, testable quality gates for Avela. It separates official award descriptions, general editorial guidance and our own recommendations. It does not change MVP scope or certify award eligibility.

## Published award criteria

Apple's current award page identifies six categories. These are qualitative descriptions, not a published numerical scoring rubric or a checklist that guarantees selection.

| Category | Published emphasis in our words | Proposed application to Avela |
| --- | --- | --- |
| Delight and Fun | Enjoyable, memorable experiences supported by Apple technology | Satisfying logging and undo, original companion responses, optional restrained feedback |
| Inclusivity | Experiences that welcome different abilities, languages and backgrounds | Accessible complete workflows, adaptable presentation, considerate language |
| Innovation | Distinctive experiences through novel use of Apple technology | Demonstrate how system integrations remove real logging effort |
| Interaction | Effortless, intuitive controls suited to the platform | Easy setup, discoverable actions, predictable navigation and recovery from mistakes |
| Social Impact | Meaningful benefit to people's lives and important issues | Investigate whether recovery-oriented habits genuinely help users; make no unsupported outcome claims |
| Visuals and Graphics | Strong imagery, crafted interfaces, cohesive identity and animation | Original art, coherent typography, themes, information design and purposeful motion |

These category descriptions are sourced from [Apple Design Awards](https://developer.apple.com/design/awards/). The Avela column is our design recommendation.

Relevant 2026 examples: Apple highlights Guitar Wiz's assistive features, Moonlitt's onboarding/platform integration and Tide Guide's clear charts and coherent visual identity. Our inference is that quality must hold across real workflows, rather than in isolated screenshots. These examples do not imply that their platform count or individual APIs are mandatory. [Apple's winner descriptions](https://developer.apple.com/design/awards/).

## Selection and nomination

The official pages reviewed did not expose a separate public Apple Design Award application, fixed entry deadline, minimum download count, required revenue level or complete eligibility rules. Record these as **unpublished or unverified**, not as requirements we have passed. Recheck the next award cycle before making a submission plan.

App Store featuring has a documented nomination process. It is editorial consideration, not a Design Award entry or guaranteed nomination. Apple lists usability, visual quality, innovation, originality, accessibility, localization and store presentation as considerations, and explicitly says featuring has no requirements checklist. [Featuring guidance](https://developer.apple.com/app-store/getting-featured/).

An authorized App Store Connect team member can create a featuring nomination for a launch or update, describe what is distinctive, and supply supporting links. Apple's help recommends at least three weeks of lead time. These are featuring instructions, not award deadlines. Do not submit or expose a public TestFlight link without the owner's instruction. [Nomination process](https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring/).

## Recommended focus

Our primary design direction should be **Interaction and Inclusivity**, supported by a distinctive visual identity and quiet delight. This is a strategic judgment, not an assessment from Apple. Avela already has a coherent potential story: fast habits and attention logging, forgiving recovery, truthful progress and a companion without care obligations.

Apple-native frameworks and system integrations are useful foundations, but their presence alone is not evidence of innovation. Nine themes are a preference feature, not a complete design achievement. Premium dependencies are optional implementation choices; require a specific advantage and follow DEPENDENCIES.md before adopting one.

## Current Avela evidence and gaps

This assessment uses the repository's implementation and verification documentation; no new device audit or build was performed for this research task. Implemented features remain subject to their recorded limitations.

| Area | Existing evidence | Evidence still needed |
| --- | --- | --- |
| Cohesive appearance | Nine paired themes, gradients, custom cards, original companion art, native screenshots | End-to-end review of every modal and state, icon/art finish, small physical screens and system materials |
| Fast interaction | One-tap completion, undo, attention chips, ordering, Shortcuts | First-use observation, Voice Control operation, undo discoverability and accidental-action review |
| Accessible presentation | Dynamic Type fallbacks, contrast tests, labels and Reduce Motion support | Full VoiceOver journeys, focus after sheets/toasts, Increase Contrast, Reduce Transparency and non-colour interpretation on device |
| Trustworthy progress | Historical revisions, archive periods, neutral skips, weekly semantics and comparable trends | Users can explain weekly commitments, unknown/manual attention data and recovery without coaching |
| Platform integration | Health, notifications, widgets, session Live Activities and App Intents | Signed-device authorization, lock-screen privacy, Siri discovery, widget refresh and session expiry |
| Reliability | Last recorded pass: 346 units plus four targeted UI flows; Debug and unsigned Release builds pass | Full release regression, upgrade preservation, long histories, oldest supported hardware, Instruments profiling |
| Inclusive reach | Calendar/time-zone tests and English copy | Localization strategy, plural handling, right-to-left layouts and professionally reviewed translations |
| Editorial presentation | Research, prototypes and screenshot galleries | Final icon, honest store screenshots/video, support/privacy URLs, reviewer demo and a concise product story |

Sources for current status: [SETUP.md](SETUP.md), [TESTING.md](TESTING.md), [release checklist](TESTFLIGHT_CHECKLIST.md), [full-theme previews](verification/full-themes/README.md), [UX audit](UX_AUDIT.md). No percentage or award readiness score is assigned.

## Proposed quality gates

The following gates are Avela's internal targets, not Apple's award rules. They should guide implementation and evaluation without adding new product scope automatically.

### Usability

- Observe a new user create a habit and log it without coaching. Record wrong turns and questions rather than preference alone.
- Require completion and attention quick logging to give immediate, understandable feedback. Undo remains reachable after transient feedback disappears.
- Require users to distinguish a daily success, a weekly target, an excused skip and a pause. They must understand that manually logged attention is not automatically measured usage.
- Check empty, loading, denied-permission, unavailable-product, error, restored and long-content states. Every state needs a clear next step or explanation.
- Start with the owner and spouse privately. Their sessions catch issues but do not represent independent market validation. Broader testing can remain private and opt-in later.

### Accessibility

Complete create, log, undo, edit, archive/reactivate, calendar, attention and purchase/restore journeys with VoiceOver; separately evaluate Voice Control and supported keyboard operation. Test largest supported text, light/dark, Increase Contrast, Reduce Motion and Reduce Transparency. Feedback must remain understandable without colour, audio or haptics. Record results per feature and device.

Apple recommends auditing accessibility and contrast in both appearances, conveying information through more than one channel and adapting motion to user settings. See [Accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility). Before publishing accessibility support claims, evaluate Apple's specific [Accessibility Nutrition Label criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/); labels are not established by a few passing screenshots.

### Visual and interaction craft

Review consistent spacing, typography, icon weights, corner treatment and contrast across every screen. Keep reading content legible over gradients and materials. Animate meaningful state transitions, avoid controls moving under a finger, and honor reduced motion. Companion states must match real facts and must not imply shame. An award target does not justify distracting animation or another theme collection.

### Performance and reliability

Profile launch, logging, calendar browsing and Insights with short and multi-year histories using Instruments on supported physical hardware. Establish measured baseline budgets before setting numerical targets. Require no known data-loss, purchase-enforcement or critical-flow crash defects; test updates without a reset. Simulator test-run stalls are not measurements of app performance. Validate session behavior after backgrounding, termination, midnight and travel.

### Privacy and commercial clarity

Keep optional permissions contextual and denial usable. Check unlocked/locked system surfaces for unintended disclosure. Match privacy statements to actual data handling. Verify real localized subscription price/period, free access, cancellation, pending purchase and restore through Apple's supported test environments. Publish support and privacy information before distribution.

## Work sequence

1. **Inventory and baseline:** map every core journey and its states to screenshots, existing tests and remaining manual checks. Review the first launch, Today and calendar before choosing more visual changes.
2. **Accessibility and usability:** run the private sessions, accessibility audits and on-device checks; prioritize blocking or confusing interactions. Use bounded prototypes for alternatives, then implement the strongest design.
3. **Craft and performance:** refine the shared components, art, motion and feedback; profile real hardware and realistic histories. Recheck after each meaningful change.
4. **Release and editorial evidence:** finish signed integration tests and release regression; prepare final store assets and a factual demo. Draft a featuring nomination only after claims are supported and distribution planning is clear.

The next implementation task should be the inventory and actionable accessibility/usability audit, not an indiscriminate feature expansion. Device-dependent checks remain pending until hardware/signing is available; simulator and code audits can progress independently.

For each finding, record the screen/state, reproduction, user impact, proposed fix, evidence and verification result. Mark checks as documented, implemented, simulator-verified, device-verified or user-validated. Do not collapse these into one green checkmark.


## Implementation evidence

The first implementation pass applies these gates to the existing app rather than expanding feature scope. Improvements include scalable Today summaries, contextual spoken detail links, larger adaptive weekday choices, readable icon names, large-text picker layout, explicit confirmation dismissal, assistive-navigation timing, reduced-transparency onboarding and informational calendar traits. Undo now verifies the exact current-day completion instead of toggling a refreshed row.

Automated native audits and the three-year calculation benchmark provide bounded evidence. Full physical-device accessibility, Voice Control/keyboard operation, real integration behavior, hardware profiling, translations and usability observations remain separate open gates. Follow [the quality execution checklist](QUALITY_EXECUTION.md) and the existing TestFlight checklist. No award score or accessibility label is asserted.
