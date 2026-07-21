# Master Dance

Current local test release: `v0.1.18b` (app version 0.1.18; macOS build 57, iOS build 34).

Native MD Desk macOS app, Master Dance iPhone app, and Supabase backend.

Master Dance formal product backend. / Master Dance 正式产品云端后端。

## What is here

- `packages/MasterDanceCore`: Swift 6 domain models, recurring-session generation, preview data, and repository contracts.
- `apps`: the production MD Desk macOS source, the Master Dance iPhone source, and shared SwiftUI workflows.
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
one-time school activation after signing in; additional administrators are
invited from the account menu. There is no public administrator registration
path.

Administrators create a guardian first, add one or more child or adult learner
profiles inside that family, then issue a hashed, expiring, one-time guardian
invitation. On iPhone, the parent validates that invitation first, receives the
locked guardian email, reads and signs the current in-app agreement, and creates
only a password. The resulting account can access only its linked family. When
an administrator publishes revised agreement text, every guardian must read and
sign that new version before returning to the app.

## Run the iPhone app

Open `apps/MasterDance.xcodeproj`, select the `MasterDanceMobile` scheme and an
iPhone simulator, then Run. The iPhone app supports administrator attendance,
guardian and adult-student accounts; it does not target iPad in this release.
For command-line simulator builds, keep Xcode's local `Sign to Run Locally`
signature enabled; disabling code signing also removes simulator Keychain access.

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

The macOS app is buildable and runnable without full Xcode. Full Xcode is
required for iPhone simulator/device builds and Apple distribution workflows.

## Verify the backend

With Supabase CLI and a Docker-compatible runtime:

```sh
supabase db start
supabase db lint --local --fail-on error
supabase test db --local
```

See `supabase/README.md` and `docs/backend-operations.md` for deployment and recovery procedures.

## Current boundaries

The MVP supports term enrollment, scheduling, guardian-first learner profiles,
one-time account linking, course enrollment, attendance, leave handling,
contract-consent records, advertising campaigns, and notification records.
Administrators can schedule up to five concurrent advertising slots at $99 per
month with a square thumbnail and a 4:5 iPhone poster; guardians see only
published campaigns active on the current date.
MD Desk also creates local PNG receipts under
`~/Documents/MD Desk Docs/<learner>/`; receipt drafts and files are not uploaded
to Supabase.
Guardian leave must be recorded at least 12 hours before class; administrators
can record it at any time, and leave records do not use an approval workflow.
Course categories, age groups, rooms, instructors, and course names are
user-managed data. Pricing, per-class enrollment, credits, exceptional rule
engines, parent course selection, and teacher login are intentionally absent.
