# Master Dance Release History

This file records user-visible changes. The administrator workflow details live
in [TUTORIAL.md](TUTORIAL.md), with a printable copy in
[TUTORIAL.pdf](TUTORIAL.pdf).

## Documentation rule

Every user-visible feature, workflow, rule, limitation, or release change must
update these four root artifacts together:

1. `README.md` for the current product boundary and release number.
2. `HISTORY.md` for what changed.
3. `TUTORIAL.md` for how an administrator uses the changed behavior.
4. `TUTORIAL.pdf`, regenerated from the Markdown source.

Run `./script/build_tutorial_pdf.sh` after editing the tutorial.

## Current release

### v0.9.0-beta.1 - 2026-08-26

- Unified the macOS and iPhone beta version at 0.9.0: macOS build 75 and iOS
  build 45.
- Kept the six frequent macOS workspaces warm in memory and optimized course
  conflict scans so switching Tabs remains responsive with the full timetable.
- Made long schedule course names shrink further before truncation in narrow
  room columns, and corrected the sidebar VoiceOver selected state.
- Updated macOS logo rendering, schedule printing, and billing PNGs with the
  approved school identity, legal name, EIN, public address, and established
  receipt color system.
- Fixed nullable enrollment billing fields in Supabase RPC encoding and added
  regression coverage without changing the production database schema or data.
- Added the Apple privacy manifest, repeatable release preflight, Developer ID
  notarization workflow, and internal-only iPhone TestFlight workflow.
- No Supabase schema or production cloud data changed in this release.

### v0.1.24c - 2026-08-24

- Prepared both native apps for repeatable Apple distribution: macOS 0.1.24
  build 74 and iOS 0.1.22 build 44.
- Added an Apple privacy manifest covering app-only UserDefaults use, first-party
  operational data collection, and the explicit no-tracking declaration.
- Added one-command release preflight, Developer ID signing and notarization,
  and internal-only TestFlight archive/upload workflows.
- Documented employee installation, replacement updates, certificate setup,
  and the remaining boundary before a public App Store submission.
- No Supabase schema or production cloud data changed in this release.

### v0.1.24b - 2026-07-24

- Preloaded the six most frequently used macOS workspaces into RAM: Schedule,
  Courses, Families, Enrollments, Attendance, and Leave.
- Kept Schedule first and interactive, then warmed the other five workspaces
  silently and one at a time so startup does not trade tab delay for one large
  main-thread pause.
- Left Billing, News, Advertisements, Contracts, and Data Center on-demand to
  keep the memory budget deliberate.
- No Supabase schema or production cloud data changed in this release.

### v0.1.24a - 2026-07-24

- Removed the subtle hesitation between macOS tabs after the production
  timetable grew to 527 sessions.
- Kept each visited tab alive for the current window, including its current
  selection, filters, scroll position, and in-progress local UI state.
- Changed course conflict detection from comparing every pair of sessions to a
  chronological active-window scan, so the Courses tab no longer does
  unnecessary whole-term work when it first opens.
- No Supabase schema or production cloud data changed in this release.

### v0.1.24 - 2026-07-24

- Imported the approved 2026 Fall timetable into production Supabase while
  preserving 11 courses that were already present.
- Added 20 missing courses and 340 sessions, bringing the term to 31 courses
  and 527 sessions; every course has 17 sessions after Thanksgiving week is
  excluded.
- Skipped both weekend courses marked as temporary adjustments and left every
  newly imported price unset. Existing manually entered prices were preserved.
- Added the `未设置` technical age group for the three private lessons whose
  source timetable did not specify an age range.
- Added an idempotent, conflict-checked import record at
  `supabase/imports/20260724_2026_fall_courses.sql`.
- Prevented ad-hoc local rebuilds from hanging on an obsolete Keychain access
  prompt by using a per-user, permission-restricted session file. The local
  build requires one fresh login after this upgrade; later rebuilds retain it.
  Formally signed builds continue to use Keychain.
- Supabase production data changed; the database schema did not change.

### v0.1.23d - 2026-07-23

- Replaced the retired black-and-white icon with the approved full-color Master
  Dance logo on macOS and iPhone.
- Added source-controlled full and compact logo assets for authentication,
  navigation, schedule printing, invoices, and receipts.
- Added a repeatable asset generator that preserves the approved colors and
  derives platform-specific crops from one original PNG.
- No Supabase schema or production cloud data changed in this release.

### v0.1.23c - 2026-07-22

- Added column sorting and filtering to every macOS operational table: courses,
  families, enrollments, attendance rosters, leave requests, news,
  advertisements, contracts, terms, holidays, and reference data.
- Preserved each tab's search, column filters, sort column, sort direction, and
  applicable term/date scope when switching away and returning.
- Kept Data Center manual drag ordering while adding remembered temporary column
  sorting and filtering.
- No Supabase schema or production cloud data changed in this release.

### v0.1.23b - 2026-07-22

- Removed the retired English/CSV schedule prototype app bundle from
  `macos-app` while preserving its five-course CSV as a read-only backup.
- Redirected the legacy build script and nested Codex Run action to the current
  root MD Desk app so the old prototype cannot be rebuilt accidentally.
- Updated the current build script to close stale legacy `MDDesk` and
  `MasterDanceReserve` processes before opening the supported app.
- No Supabase schema or production cloud data changed in this release.

### v0.1.23a - 2026-07-22

- Added the first complete Chinese MD Desk administrator manual, organized by
  all 11 macOS tabs and the most common cross-tab workflows.
- Added a repeatable Markdown-to-PDF generator with PDF bookmarks, linked
  navigation, page numbers, embedded Chinese fonts, and source revision metadata.
- Made synchronized updates to `README.md`, `HISTORY.md`, `TUTORIAL.md`, and
  `TUTORIAL.pdf` a required part of every future user-visible release.
- No app binary, Supabase schema, or production data changed in this release.

## Product releases

### v0.1.23 - 2026-07-22

- Added a remembered term selector to Courses, including an all-terms view for
  finding and duplicating historical courses.
- Added same-room and same-teacher schedule conflict warnings to both conflicting
  course rows.
- Grouped billing history by family and term, with immutable version history and
  a new-version correction flow.
- Recovered stale course synchronization failures caused by deleted local records.

### v0.1.22a - 2026-07-22

- Added course prices to schedule blocks and schedule details.

### v0.1.22 - 2026-07-22

- Made private lessons session-only for pricing and enrollment.
- Migrated existing private-lesson enrollments to explicit selected sessions.

### v0.1.21a - 2026-07-21

- Made course table columns adapt to their contents and available window width.

### v0.1.21 - 2026-07-21

- Added selected-session enrollment for group courses with a configured drop-in
  price.
- Added separate full-term and drop-in unit prices while preserving enrollment
  price snapshots.

### v0.1.20 - 2026-07-21

- Added course pricing, trial fees, one course discount, registration and balance
  lines, family invoices, payments, card fees, versioned billing, and PNG output.

### v0.1.19 - 2026-07-21

- Refined the guardian iPhone home, news, advertisement, contract, and account
  experiences and aligned media behavior across platforms.

### v0.1.18 - v0.1.18b - 2026-07-21

- Added perfect-attendance calculation and guardian contact controls.
- Fixed upcoming-term status handling and recovery from stale synchronization
  failures.

### v0.1.17 - 2026-07-21

- Added five managed advertising slots, date-range scheduling, $99 monthly
  estimates, media optimization, and guardian iPhone delivery.

### v0.1.15 - v0.1.16 - 2026-07-20

- Added parent leave visibility, local receipt PNG generation, and atomic family
  deletion safeguards.

### v0.1.13 - v0.1.14 - 2026-07-20

- Added Supabase-backed news publishing and signed-contract display on iPhone.
- Restored and expanded Supabase CI coverage.

### v0.1.10 - v0.1.12 - 2026-07-20

- Added complete guardian down-sync, refined the native family table, and filled
  out day-to-day administration workflows.

### v0.1.9 - v0.1.9d - 2026-07-19 to 2026-07-20

- Added versioned in-app agreements and signature capture.
- Fixed invitation registration completion, family claiming, cross-device refresh,
  and native family-table layout.

### v0.1.8 - v0.1.8h - 2026-07-19

- Enforced dependency-aware deletion and seven-day schedule display.
- Added narrow course-block layout, course filters and sorting, responsive cloud
  interaction, appearance fixes, 180-day login retention, and wheel-style date
  navigation on iPhone attendance.

### v0.1.7 - v0.1.7a - 2026-07-19

- Added guardian contract registration and made attendance states reversible.

### v0.1.6 - 2026-07-18

- Added the local-first iPhone family and administrator workflows.

### v0.1.5 - v0.1.5e - 2026-07-18

- Added trial and makeup attendance, schedule hover previews, schedule font scale,
  global font commands, improved schedule grids, and cloud activity feedback.

### v0.1.4 - v0.1.4g - 2026-07-18

- Added the administrator data center, guardian-owned learner profiles, required
  contact details, full course editing, reference ordering, nonblocking background
  sync, batch enrollment, generic schedule controls, and correct system appearance.
- Hid the legacy course-category field from the product UI.

### v0.1.3 - 2026-07-18

- Added guardian accounts and the guardian-first family structure.

### v0.1.0 - 2026-07-17

- Released the first native MD Desk macOS administrator app with the Supabase
  product foundation.
