# Master Dance Release History

This file records user-visible changes. The administrator workflow details live
in [TUTORIAL.md](TUTORIAL.md), with a printable copy in
[TUTORIAL.pdf](TUTORIAL.pdf).

## Documentation rule

Update `README.md` and `HISTORY.md` for each user-visible release. Update the
administrator tutorial and employee acceptance guide only when a current staff
handoff package is requested, then regenerate each PDF from its Markdown source.

## Current release

### v0.9.0-beta.1k - 2026-09-01

- Added a third billing line settlement state, "waived", beside unpaid and
  paid. Waived courses keep their standard price for accounting but contribute
  zero to the current amount due.
- Replaced the paid checkbox in the macOS billing composer with a compact
  unpaid, paid, or waived selector. Billing history and both PNG languages now
  identify waived lines and report the waived total separately.
- Applied an additive, backward-compatible Supabase migration. Existing rows
  retain their prior paid/unpaid meaning, old clients remain usable, and no
  issued invoice, payment, amount, or PNG was rewritten.
- Local macOS is build 84 versus notarized build 79, a distance of five. iOS
  remains local build 47 versus accepted TestFlight build 45, a distance of
  two. No notarized package or TestFlight upload was made in this revision.
- All 128 Swift tests passed; the linked Supabase migration and remote schema
  lint also passed.

### v0.9.0-beta.1j - 2026-08-31

- Restored the established black Master Dance receipt/invoice logo and the
  faint pink water-sleeve dancer background without changing billing layout,
  amounts, payment state, or production records.
- Fixed resource resolution so SwiftPM previews and the ad-hoc macOS app use
  the same packaged brand assets instead of falling back to a system figure.
- Re-rendered and replaced the eight local Mila and Zimeng Li invoice/receipt
  PNGs under MD Desk Docs with the corrected visual assets.
- Local macOS is build 83 versus notarized build 79, a distance of four. iOS
  remains local build 47 versus accepted TestFlight build 45, a distance of
  two. No notarized package or TestFlight upload was made in this revision.
- All 125 Swift tests passed.

### v0.9.0-beta.1i - 2026-08-31

- Extended the version-aware news and advertisement image cache to macOS and
  made the hard-drive copy under Application Support the source of truth on
  both platforms. Removed the separate image-byte dictionaries from AppModel.
- Previously loaded images now survive app restarts and remain available
  offline for 180 days on both Mac and iPhone; stale images stay visible while
  a changed cloud revision is refreshed.
- Issued and fully paid the requested Fall 2026 invoices for Mila and Zimeng Li
  in production. Each invoice has bilingual and English invoice/receipt PNGs,
  Zelle payment records, and a zero outstanding balance.
- Local macOS is build 82 versus notarized build 79, a distance of three. Local
  iOS is build 47 versus accepted TestFlight build 45, a distance of two. No
  notarized package or TestFlight upload was made in this revision.
- All 124 Swift tests passed.

### v0.9.0-beta.1h - 2026-08-31

- Kept macOS guardian creation and editing strict: email and phone remain
  required. Families deliberately inserted through the trusted Codex/SDK/MCP
  exception now show each missing contact field in red and remain editable.
- Stored unavailable contact values as null rather than fake placeholders and
  blocked guardian invitation-code creation until both a valid email and phone
  are present.
- Added the same deliberate exception to the TypeScript SDK, MCP tools, and
  localhost API as `allowIncompleteGuardianContact` or
  `allow_incomplete_guardian_contact`; ordinary calls remain strict by default.
- Used the explicit exception once for the requested unlinked production
  guardian, preserving null email and phone rather than fake data. No database
  migration was required.
- This is local macOS build 81 versus notarized build 79, a distance of two.
  iOS remains local build 46 versus accepted TestFlight build 45. No notarized
  package or TestFlight upload was made in this revision.

### v0.9.0-beta.1g - 2026-08-31

- Added a local TypeScript Master Dance Admin SDK, a bearer-protected localhost
  HTTP API with an OpenAPI 3.1 contract, and a project-scoped STDIO MCP server.
- Exposed focused tools for current resource CRUD, course pricing, enrollment,
  attendance, leave, family links, guardian invitation codes, contract
  revisions, media, immutable invoice versions, and immutable payments.
- Kept authentication on the ordinary Admin account and existing Supabase RLS,
  validation, dependency-aware deletion, and audit path. Secrets are read from
  macOS Keychain and are not stored in Codex configuration or source control.
- Preserved hidden course-category compatibility and immutable billing/legal
  history. The package passed strict TypeScript checks and five automated tests,
  including a real MCP initialization/list-tools protocol smoke test.
- This is a local integration and documentation revision only. macOS remains
  local build 80 versus notarized build 79; iOS remains local build 46 versus
  accepted TestFlight build 45. No native app build, Supabase schema, or
  production data changed.

### v0.9.0-beta.1f - 2026-08-31

- Local iOS revision, app version 0.9.0 build 46. The accepted TestFlight build
  remains 45; macOS remains local build 80 and notarized build 79.
- Added a version-aware persistent disk cache for news covers, news body images,
  advertisement thumbnails, and advertisement posters on iPhone.
- Previously loaded media now appears immediately after relaunch and remains
  available offline. Changed cloud media downloads once, then replaces the old
  image without clearing the visible fallback first.
- Current media remains refreshable after 180 days, concurrent views share one
  download, and expired unreferenced versions are cleaned up separately.
- All 123 Swift tests and an unsigned iPhone Simulator SDK build passed. No
  Supabase schema or production data changed in this revision.

### v0.9.0-beta.1e - 2026-08-31

- Local macOS UI revision, app version 0.9.0 build 80. The latest notarized
  employee package remains build 79, and iOS/TestFlight remain build 45.
- Added a focused-day timetable layout: clicking a date gives that day one
  quarter of the available schedule width while all seven days and both rooms
  remain visible.
- Nonfocused days preserve every course in its time position but simplify each
  block to its course name, age-group color, and group/private badge. The
  focused day keeps the full teacher, age, time, and price presentation.
- Clicking the focused date restores equal widths. The choice persists across
  tab changes, does not reflow on hover, and does not alter the equal-width
  print layout.
- All 119 Swift tests passed. No Supabase schema, production data, or iOS code
  changed in this revision.

### v0.9.0-beta.1d - 2026-08-31

- Released macOS app version 0.9.0 build 79 as a Developer ID signed and Apple
  notarized employee ZIP. The iOS app and accepted TestFlight build remain 45.
- Kept invoices owned by the guardian and term, but added an explicit learner
  scope. Administrators can select one learner for an individual invoice or
  several learners from the same family for one combined invoice.
- Gave every exact guardian, term, and learner selection its own immutable
  invoice version history, preventing one sibling's invoice from overwriting or
  merging into another sibling's series.
- Added learner checkboxes, select-all and clear actions, selected-learner course
  loading, scoped invoice previews, learner-aware history labels, and filenames.
- Migrated existing Supabase invoices in place without deleting production data,
  retained compatibility for the previously distributed app, and added atomic
  dual-language issuance for the new learner-scoped workflow.
- All 114 Swift tests, the Release build, Supabase schema lint, Apple notarization,
  stapling, Gatekeeper assessment, and ZIP integrity checks passed.

### v0.9.0-beta.1c - 2026-08-31

- Local macOS billing revision, app version 0.9.0 build 78; distributed packages
  remain unchanged.
- Replaced the old “included in amount due” control with explicit paid/unpaid
  line states. Paid charges remain visible and are subtracted from the amount
  due now; discounts and credits remain direct adjustments.
- Required every active enrollment for the selected family and term to appear
  before an invoice can be issued. Reloading enrollments preserves manually
  entered registration, merchandise, competition, balance, and other charges.
- Generates Chinese-primary bilingual and English editions for every invoice
  and receipt, previews the two narrow documents side by side, saves both to
  MD Desk Docs, and registers both cloud files in one database transaction.
- Grouped long-form documents into full-term enrollment, per-session
  enrollment, other charges, and discounts/credits. Updated the visual system
  to pink-magenta with a faint water-sleeve dancer watermark.
- Added a backward-compatible Supabase RPC migration; existing invoices,
  payments, artifacts, and production school data are not rewritten.
- No iOS app code or iOS build number changed.

### v0.9.0-beta.1b - 2026-08-27

- Local macOS UI revision, app version 0.9.0 build 77; distributed packages
  remain unchanged.
- Changed timetable block colors from instructor to age group, including the
  shared print preview. Row reordering, renaming, and deactivation keep each
  existing age identity's palette position within the reference list.
- Preserved opaque light/dark fills, instructor text, age labels, group/private
  badges, selection outlines, and conflict warnings. No second visual code was
  added to the already compact course blocks.
- No iOS code, Supabase schema, or production cloud data changed.

### v0.9.0-beta.1a - 2026-08-27

- Local macOS UI revision, app version 0.9.0 build 76. The distributed macOS
  build 75 and iOS TestFlight build 45 are unchanged until explicitly republished.
- Moved the administrator icon navigation to the top, preserving its hover
  animation, Chinese labels, selected state, and account/appearance controls.
- Gave the seven-day schedule the full window width by moving the selected
  course inspector below it, above the unchanged school enrollment status bar.
- Arranged course information, the complete learner roster, and attendance
  summary horizontally. Details can be resized or collapsed, with their state
  retained alongside the existing week, room, zoom, and tab selections.
- Reused the hover-card roster for bottom details so trial, makeup, and guardian
  leave appear consistently without a seven-learner truncation.
- No iOS code, Supabase schema, or production cloud data changed.

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
