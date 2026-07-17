# Master Dance

Phase 2 native product foundation for the production Master Dance system.

Master Dance formal product Phase 2 shared workflows. / Master Dance 正式产品第 2 阶段共享工作流。

## What is here

- `packages/MasterDanceCore`: Swift 6 domain models, recurring-session generation, preview data, and repository contracts.
- `apps`: shared SwiftUI workflows plus an XcodeGen specification for MD Desk on macOS and the role-aware Master Dance iPhone app.
- `supabase`: the future cloud adapter boundary; schema work starts in Phase 3.
- `docs`: architecture, product scope, visual baseline, policy log, migration design, QA evidence, and delivery roadmap.

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

The current machine has Command Line Tools rather than full Xcode, so Phase 2 verifies the native source by strict typechecking, rendered SwiftUI evidence, XcodeGen generation, and core smoke tests. Installable macOS and iPhone demo builds remain Phase 6.

## Current boundaries

The MVP supports term enrollment, scheduling, students and guardians, attendance, leave, contract consent, and notification records. Course categories, age groups, rooms, instructors, and course names are user-managed data. Pricing, per-class enrollment, credits, exceptional rule engines, parent course selection, and teacher login are intentionally absent.
