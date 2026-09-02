# Master Dance

Current local revision: `v0.9.0-beta.1p`. macOS is app version 0.9.0 build 89,
which is also the latest Developer ID signed and Apple-notarized distribution.
The local iOS app is version 0.9.0 build 49; that build was uploaded
successfully to App Store Connect and is processing for internal TestFlight.
Build 45 remains the latest confirmed accepted TestFlight baseline until Apple
finishes processing build 49.

On macOS, guardian email and phone remain required during normal family entry
and editing. A family deliberately inserted through the trusted Codex/SDK/MCP
exception may temporarily keep either value null; the family table and detail
panel mark each missing item in red so staff can open the editor and complete
it. Invitation codes stay disabled until both contact fields are valid. The
exception is not exposed by the native form and never invents placeholder data.

Native MD Desk macOS app, Master Dance iPhone app, and Supabase backend.

Master Dance formal product backend. / Master Dance 正式产品云端后端。

Both apps keep news covers, news body images, advertisement thumbnails, and
advertisement posters in a version-aware hard-drive cache under Application
Support. Previously loaded media appears immediately after relaunch or while
offline; a changed cloud revision downloads once and replaces the prior image.
The image cache does not retain a second in-memory copy. Files remain fresh for
180 days, with stale current media retained as a fallback while refreshing.

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
- `integrations/master-dance-admin`: local TypeScript Admin SDK, localhost API,
  and STDIO MCP server for protected non-UI administration.
- `docs`: architecture, product scope, visual baseline, policy log, migration design, QA evidence, and delivery roadmap.

## Documentation

- [Administrator tutorial (Markdown)](TUTORIAL.md): the editable, searchable
  Chinese guide for MD Desk administrators.
- [Administrator tutorial (PDF)](TUTORIAL.pdf): the printable and shareable
  edition, with bookmarks and a linked table of contents.
- [Release history](HISTORY.md): user-visible changes by version.
- [Installation and distribution](docs/DISTRIBUTION.md): Developer ID,
  notarization, internal TestFlight, employee installation, and update flow.

`TUTORIAL.md` is the source of truth for the PDF. The tutorial and employee
acceptance guide are staff handoff documents: update and regenerate them when a
current employee package is requested, rather than for every small iteration.
To regenerate the administrator tutorial:

```sh
./script/build_tutorial_pdf.sh
```

Product-facing tutorial text is in plain Chinese; engineering documents under
`docs` may remain in English.

The `web` and `product-research` directories remain migration inputs. The
`macos-app` directory contains retired reference source only; its old English/CSV
app bundle has been removed and its build command redirects to the supported
native app.

Every column in the macOS operational tables now supports sorting and filtering.
Each tab retains its search, filters, sort column, direction, and applicable
term/date scope when the administrator moves to another tab and returns.
In the course table, unresolved values such as `未设置`, `未排课`, `待定`,
and `待复核` use strong red text so staff can scan unfinished setup quickly.
Inactive courses use a light red whole-row background. Valid `免费` and
private-lesson `不适用` values remain neutral rather than becoming false alerts.

The macOS navigation icons run across the top of the window, preserving the
hover labels, appearance/account menus, and exactly one selected tab for
VoiceOver. Schedule uses the full window width; selected-course information,
the complete learner roster, and attendance counts sit in a resizable bottom
detail area above the unchanged school status bar. Its height and collapsed
state remain stable when switching tabs. The roster and hover card use the
same attendance presentation, including trial, makeup, and guardian leave.
Course names still adapt to narrow room columns and long titles.
Schedule blocks and their print preview now use age-group colors rather than
instructor colors. The mapping uses age identities across the full reference
list, so week/room selection, row reordering, and renaming do not change it.
Teacher names and the group/private badge remain visible; no extra course
texture or second color code is added to the compact blocks.
Clicking a date header now expands that day to one quarter of the timetable
while keeping all seven days and both selected rooms visible. The other six
days switch to compact course-name and group/private summaries; clicking the
focused date again restores equal widths. The focused day survives tab changes,
while printed schedules remain equal-width weekly overviews.

Every issued invoice and payment receipt now produces two narrow PNG documents:
a Chinese-primary bilingual edition and an English edition. The invoice belongs
to one guardian and one term, while the administrator selects one or more
learner profiles in that family. One learner produces an individual invoice;
multiple selected learners produce a combined family invoice. Each exact learner
selection has its own immutable version history. Only the selected learners'
enrollments are required and loaded. Full-term tuition, per-session tuition,
other charges, adjustments, and explicit unpaid/paid/waived states remain
grouped. Paid charges stay visible but do not contribute to the highlighted
amount due now. A waived charge keeps its normal course price visible while
recording that no payment is required; the waived value is reported separately
so accounting can reconcile the original price and final balance. Both language
files are registered together in Supabase and saved together under MD Desk Docs.
In billing history, every immutable invoice version is presented as one four-slot
document set: bilingual and English invoices side by side, with that same
version's bilingual and English payment receipt directly below. An unpaid
receipt slot is red, a partially paid slot is orange, and a paid-in-full slot is
green. Multiple payment ledger entries remain immutable, while the latest
visible receipt pair summarizes cumulative payment for that invoice version.

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

Adult learners may also hold one or more N-session cards without enrolling in a
fixed course or term. Administrators define reusable card plans in Data Center,
issue a card from the learner detail panel, and check the learner in from the
dedicated session-card area in Attendance. Each check-in consumes the oldest
active card with remaining sessions; cancelling that attendance restores the
use. Guardians and adult learners can see their remaining count and immutable
use history on iPhone, while pricing and issuance remain administrator-only.

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

## Admin SDK, API, and MCP

The optional local automation layer can query and update Master Dance through
the same authenticated Admin scope and Supabase rules as MD Desk. It does not
use a service-role key and cannot rewrite issued billing or signed legal
history. Build and test it with:

```sh
cd integrations/master-dance-admin
npm install
npm run check
npm run build
npm test
```

On an authorized administrator Mac, store credentials once with
`./script/setup_master_dance_admin_credentials.sh`, register the local STDIO
server with `codex mcp add`, then restart Codex so the `master_dance` MCP entry
is loaded. This Mac is already registered. See
[`integrations/master-dance-admin/README.md`](integrations/master-dance-admin/README.md)
for the tool catalog, SDK example, localhost API, and security boundary.

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
one-time account linking, course enrollment, adult N-session cards, attendance, leave handling,
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
or selected sessions. Once a group course has a confirmed full-term unit rate,
its per-session rate is derived automatically as that rate plus USD 5; pending
prices are left untouched. Private lessons remain independently priced and are
always enrolled by selected session.
