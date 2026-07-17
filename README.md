# Master Dance

Phase 4 native MD Desk macOS app and Supabase backend for the production Master Dance system.

Master Dance formal product backend. / Master Dance 正式产品云端后端。

## What is here

- `packages/MasterDanceCore`: Swift 6 domain models, recurring-session generation, preview data, and repository contracts.
- `apps`: the production MD Desk macOS source, shared SwiftUI workflows, and the deferred iPhone shell.
- `supabase`: production Postgres schema, RLS, Storage, Realtime, Edge Function, seed, and pgTAP tests.
- `docs`: architecture, product scope, visual baseline, policy log, migration design, QA evidence, and delivery roadmap.

Existing `web`, `macos-app`, and `product-research` directories are migration inputs. This skeleton does not replace or remove them.

## Run MD Desk

Build, package, and open the native app with Apple Command Line Tools:

```sh
./script/build_and_run.sh
```

The script creates `MD Desk.app` at the repository root. The same command is
available as the Codex `Run` action. Optional modes are `--verify`, `--debug`,
`--logs`, and `--telemetry`.

MD Desk accepts administrator accounts only. The first Auth user completes the
one-time school activation after signing in; after that, additional
administrators are invited from the account menu inside MD Desk. There is no
public administrator registration path.

## Verify Swift

Run the complete suite:

```sh
./script/test.sh
```

Generate the formal Xcode project when Xcode is available:

```sh
cd apps
xcodegen generate --spec project.yml
```

The macOS app is buildable and runnable without full Xcode. Full Xcode remains
required for Apple signing, notarization, and later iPhone device builds.

## Verify the backend

With Supabase CLI and a Docker-compatible runtime:

```sh
supabase db start
supabase db lint --local --fail-on error
supabase test db --local
```

See `supabase/README.md` and `docs/backend-operations.md` for deployment and recovery procedures.

## Current boundaries

The MVP supports term enrollment, scheduling, students and guardians,
attendance, leave handling, contract-consent records, and notification records.
Course categories, age groups, rooms, instructors, and course names are
user-managed data. Pricing, per-class enrollment, credits, exceptional rule
engines, parent course selection, and teacher login are intentionally absent.
