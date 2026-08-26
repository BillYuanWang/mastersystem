# Master Dance

Current beta release candidate: `v0.9.0-beta.1` (macOS app version 0.9.0,
build 75; iOS app version 0.9.0, build 45).

Native MD Desk macOS app, Master Dance iPhone app, and Supabase backend.

Master Dance formal product backend. / Master Dance 正式产品云端后端。

The production 2026 Fall term currently contains 31 confirmed courses and 527
sessions. The two weekend temporary-adjustment courses and all unconfirmed
prices were intentionally excluded from the July 24 timetable import.

MD Desk first renders the schedule, then quietly preloads Courses, Families,
Enrollments, Attendance, and Leave into RAM one workspace at a time. Those six
frequent workspaces stay ready in the current window, so switching among them
does not rebuild rows and controls. Billing, News, Advertisements, Contracts,
and Data Center remain on-demand. Course conflict checks scan only sessions
whose time windows can overlap, keeping the first course-table load responsive
as the timetable grows.

The ad-hoc local macOS build stores its remembered Supabase session in a
per-user `0600` Application Support file so rebuilding the app does not trigger
repeated Keychain authorization. Formally signed builds continue to use
Keychain.

## What is here

- `packages/MasterDanceCore`: Swift 6 domain models, recurring-session generation, preview data, and repository contracts.
- `apps`: the production MD Desk macOS source, the Master Dance iPhone source, and shared SwiftUI workflows.
- `brand`: the approved full-color Master Dance logo source and derivative rules.
- `supabase`: production Postgres schema, RLS, Storage, Realtime, Edge Function, seed, and pgTAP tests.
- `docs`: architecture, product scope, visual baseline, policy log, migration design, QA evidence, and delivery roadmap.

## Documentation

- [Administrator tutorial (Markdown)](TUTORIAL.md): the editable, searchable
  Chinese guide for MD Desk administrators.
- [Administrator tutorial (PDF)](TUTORIAL.pdf): the printable and shareable
  edition, with bookmarks and a linked table of contents.
- [Release history](HISTORY.md): user-visible changes by version.
- [Installation and distribution](docs/DISTRIBUTION.md): Developer ID,
  notarization, internal TestFlight, employee installation, and update flow.

`TUTORIAL.md` is the source of truth for the PDF. Regenerate the PDF after every
user-visible change:

```sh
./script/build_tutorial_pdf.sh
```

A release is not complete until `README.md`, `HISTORY.md`, `TUTORIAL.md`, and
`TUTORIAL.pdf` describe the same behavior. Product-facing tutorial text is in
plain Chinese; engineering documents under `docs` may remain in English.

The `web` and `product-research` directories remain migration inputs. The
`macos-app` directory contains retired reference source only; its old English/CSV
app bundle has been removed and its build command redirects to the supported
native app.

Every column in the macOS operational tables now supports sorting and filtering.
Each tab retains its search, filters, sort column, direction, and applicable
term/date scope when the administrator moves to another tab and returns.

Schedule course names shrink further when a narrow room column or long title
needs more space. The macOS sidebar also exposes exactly one selected tab to
VoiceOver while preserving the existing icon hover labels.

Both apps now use the approved full-color Xiaohongshu Master Dance logo. The
same source image supplies the macOS and iPhone icons, compact in-app mark,
schedule print header, and billing documents; generated assets must not be
recolored or replaced independently.

## Run MD Desk

Build, package, and open the native app with Apple Command Line Tools:

```sh
./script/build_and_run.sh
```

The script creates `MD Desk.app` at the repository root. The same command is
available as the Codex `Run` action. Optional modes are `--verify`, `--debug`,
`--logs`, and `--telemetry`.

This root bundle is the only supported macOS app. Do not launch or recreate the
retired `macos-app/MD Desk.app`; its CSV is retained only as a read-only
historical backup.

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

## Distribute to employees

Run the unsigned release, privacy-manifest, and test preflight:

```sh
./script/release_preflight.sh
```

After Xcode is signed in to the Agentech Developer team and the appropriate
certificates are installed:

```sh
TEAM_ID=YOUR_TEAM_ID ./script/release_macos.sh
TEAM_ID=YOUR_TEAM_ID ./script/release_ios_testflight.sh
```

The first command produces a Developer ID signed, Apple-notarized Mac ZIP under
`dist/macos/`. The second uploads an internal-only TestFlight build. Credentials
stay in Xcode or Keychain and are never stored in the repository. See
[Distribution guide](docs/DISTRIBUTION.md) for setup and employee steps.

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
month with a square thumbnail and a flexible-ratio advertisement poster; guardians see only
published campaigns active on the current date.
MD Desk calculates tuition from the per-session rate and actual scheduled
sessions, supports one enrollment discount, trial fees, annual registration
fees, family credits or balances, and versioned family invoices. Issued invoice
and receipt PNGs are stored privately in Supabase and also saved under
`~/Documents/MD Desk Docs/<family>/` for copying into messaging apps. The iPhone
app has no pricing controls in this release.
Guardian leave must be recorded at least 12 hours before class; administrators
can record it at any time, and leave records do not use an approval workflow.
Age groups, rooms, instructors, course types, and course names are user-managed
data. The legacy course-category field remains hidden for database compatibility.
Tax, refunds, exceptional rule engines, parent course selection, and teacher
login are intentionally absent. Group courses may be enrolled for the full term
or selected sessions when a drop-in price is configured; private lessons are
always enrolled by selected session.
