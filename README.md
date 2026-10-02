# Avela

Native, local-first iOS habit and attention-management app. This repository
currently contains **Phase 0 scaffolding only**, not the MVP implementation.

Open `Avela.xcodeproj` and select the shared **Avela** scheme. See
[development setup](docs/SETUP.md) for toolchain, signing, build, and test commands.
No packages, backend, accounts, or runtime secrets are needed.

## Targets

- `Avela`: SwiftUI app with Today, Insights, History, and Settings placeholders.
- `AvelaTests`: XCTest navigation-contract and SwiftData persistence tests.
- `AvelaUITests`: tab navigation and application relaunch smoke test.
- `AvelaWidget`: embedded WidgetKit development placeholder.

The widget is intentionally static and has no access to the app's store. Live
Activity UI can be added to this widget extension when a real session feature
exists; no separate Live Activity target is required for this scaffold.

## Architecture

`App/` owns composition and navigation. `Features/` preserves the documented
feature boundaries, including Habit and Attention Domain/Data/UI directories.
Empty directories are tracked with `.gitkeep`; they do not represent implemented
services. Shared placeholder UI lives in `Features/Shared/` until feature screens
replace it. `Core/Persistence/` owns SwiftData setup and `Core/Models/` contains only
the temporary `ScaffoldRecord` model. `Resources/` holds the asset catalog.

There are no product repositories, adapters, view models, or business rules yet.
Add the documented repository interfaces and platform adapters when their first
consumers exist. Feature domain code must remain independent of UI and platform
frameworks as described in [ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Temporary persistence

On first store initialization, `AppPersistence` saves one `ScaffoldRecord` with a
UUID and creation timestamp. Later launches preserve that record. Views neither
query nor write SwiftData. Tests use isolated in-memory and temporary disk stores;
no launch argument can erase the normal app store. CloudKit is explicitly disabled.

This is a schema probe, not a habit, analytics event, or canonical product entity.
Replace it with the canonical models during Phase 1 and decide how to reset or
migrate development stores then. No production migration policy is implied.
Persistence failure shows a plain recovery message and logs a private diagnostic;
the app does not silently substitute an empty in-memory store.

## Scope and next step

The scaffold uses system colors, system typography, native controls, and automatic
light/dark appearance. It includes no mascot, purchases, notifications, Screen
Time, production widgets, backend, or third-party dependencies. The app icon asset
is an empty development slot; branded artwork is needed before distribution.

Read [AGENTS.md](AGENTS.md) and every Markdown file in `docs/` before changes.
The recommended next task is Phase 1: implement canonical Habit, Completion, Skip,
and historical configuration models, then deterministic scheduling and repository
behavior with date/time tests. Do not treat the placeholder screens as finished
release functionality.
