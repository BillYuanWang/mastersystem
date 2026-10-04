# Build and runtime follow-up - 2026-10-03

## Scope

Continue release verification and fix observed defects. No production business
data/schema writes, employee-device updates or public App Store submission.
The original audit's public-release gates remain open.

## Fixes

- Mac 93: seven-day/two-room course blocks allowed the price badge's layout
  priority to collapse the age badge. ViewThatFits now falls back to a single
  age/concise-price line. Both term and drop-in labels are explicit; wide lanes
  retain full metadata and hover retains detailed information.
- iOS 51: after successful admin login, the first remote snapshot could take
  several seconds. Attendance incorrectly displayed a definitive empty day
  during that interval. The view now waits for initial loading/refresh before
  showing an empty state, presents load errors with retry, and never hides
  already-loaded day rows behind the progress state.
- Local Mac bundle: FinderInfo was attached to the Dropbox workspace copy,
  causing strict codesign verification to reject attached metadata. Removed
  only that attribute, preserving other attributes and the existing signature.
  The unchanged distribution ZIP independently passed fresh-extraction checks.

## Verified

- 160 Swift tests in 30 suites passed after the timetable fix.
- macOS 0.9.4 (93) Release archive/export, Developer ID signing, notarization,
  stapling, fresh-extraction codesign and Gatekeeper passed.
- Notary submission: `ca70a89f-d60a-4f76-91ae-13e9a2765644`, Accepted.
- ZIP SHA-256: `cbc3002786ce9ffb0b8360b2fc67c60c2df44c51e64eee3f2a83ba9e92075ea7`.
- Local workspace app replaced with 93; previous local 92 backed up. All eleven
  tabs opened against existing real data without a visible sync-error banner.
  The corrected age/price line was visually inspected in the dual-room grid.
- iOS 0.9.4 (51) Release simulator compilation and signed device archive/export
  passed. Apple reported upload success and processing at 23:01 PDT.
- Existing administrator login succeeded on a production-configured Release
  simulator. No attendance was marked and no school records were edited.
- A disposable empty iPhone simulator visibly showed the new loading state
  after login, instead of claiming no courses existed. It then loaded the real
  course list and enrolled-learner detail. With remember-login disabled, a
  terminate/relaunch returned to sign-in with the switch still disabled.

## Distribution boundaries

- Mac local/new-package gap: 0. Previous package 92 to current 93: +1.
- iOS local/uploaded build: 51. Previous upload 50 to current 51: +1.
- Last documented tester-available baseline: 45, stale, gap +6. Do not claim
  later builds are unavailable merely because this baseline is old.
- App Store Connect browser login expired and requires the owner to finish
  authentication. Processing completion and internal-group installability are
  not verified yet; credentials are not requested in chat or written to files.
- Public account deletion/retention, privacy/support URLs, final agreement,
  Growth-page readiness, review metadata and complete real-device acceptance
  remain outside a claim of build/sign/upload success.

## Evidence logs

Temporary local logs (not committed, may be cleaned later):
`/tmp/md-desk-release-macos93-20261003.log`,
`/tmp/md-desk-release-ios51-20261003.log`,
`/tmp/md-desk-ios51-runtime-build-20261003.log`,
`/tmp/md-desk-runtime-followup-tests-20261003.log`.
