# Master Dance

Phase 1 engineering foundation for the production Master Dance system.

Master Dance formal product Phase 1 engineering skeleton. / Master Dance 正式产品第 1 阶段工程骨架。

## What is here

- `packages/MasterDanceCore`: Swift 6 domain models and repository contracts.
- `apps`: an XcodeGen specification for the MD Desk macOS admin app and role-aware Master Dance iOS app.
- `supabase`: the future cloud adapter boundary; schema work starts in Phase 3.
- `docs`: architecture, product scope, and delivery roadmap.

Existing `web`, `macos-app`, and `product-research` directories are migration inputs. This skeleton does not replace or remove them.

## Verify the core

With Apple Command Line Tools only:

```sh
./scripts/smoke-test-core.sh
```

With full Xcode, run the complete suite:

```sh
swift test
```

The apps require full Xcode. When Xcode and XcodeGen are installed, generate the project from the repository root:

```sh
xcodegen generate --spec apps/project.yml
```

No Xcode app build is claimed by Phase 1 in a Command Line Tools-only environment.

## Current boundaries

The MVP supports term enrollment, scheduling, students and guardians, attendance, leave, contract consent, and notification records. Course categories, age groups, rooms, instructors, and course names are user-managed data. Pricing, per-class enrollment, credits, exceptional rule engines, parent course selection, and teacher login are intentionally absent.
