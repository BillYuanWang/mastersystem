# Master Dance

Phase 3 native product foundation and Supabase backend for the production Master Dance system.

Master Dance formal product backend. / Master Dance 正式产品云端后端。

## What is here

- `packages/MasterDanceCore`: Swift 6 domain models, recurring-session generation, preview data, and repository contracts.
- `apps`: shared SwiftUI workflows plus an XcodeGen specification for MD Desk on macOS and the role-aware Master Dance iPhone app.
- `supabase`: production Postgres schema, RLS, Storage, Realtime, Edge Function, seed, and pgTAP tests.
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

The current machine has Command Line Tools rather than full Xcode, so the native source is verified by strict typechecking, rendered SwiftUI evidence, XcodeGen generation, and core smoke tests. Installable macOS and iPhone demo builds remain Phase 6.

## Verify the backend

With Supabase CLI and a Docker-compatible runtime:

```sh
supabase db start
supabase db lint --local --fail-on error
supabase test db --local
```

See `supabase/README.md` and `docs/backend-operations.md` for deployment and recovery procedures.

## Current boundaries

The MVP supports term enrollment, scheduling, students and guardians, attendance, leave, contract consent, and notification records. Course categories, age groups, rooms, instructors, and course names are user-managed data. Pricing, per-class enrollment, credits, exceptional rule engines, parent course selection, and teacher login are intentionally absent.
