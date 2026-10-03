# MD Desk release audit - 2026-10-03

## Decision

Internal-test candidate: macOS 0.9.3 (92), iOS 0.9.3 (50).
Not approved for public App Store submission. Passing the checks below does not
prove that every UI path or production workflow is defect-free.

## Findings and repairs

1. Session persistence used legacy token names, while Supabase 2.46.0 uses
   `sb-<project>-auth-token`. The remember-login switch therefore did not guard
   the actual stored token. The configuration now shares an explicit key with
   its storage adapter, without invalidating existing remembered logins.
2. Latest GitHub database CI failed. Two pgTAP calls resolved to the wrong
   overload; the integration SQL also assumed an existing admin and course and
   did not emit TAP. Assertions now include descriptions and the integration
   test creates isolated, rolled-back fixtures with fixed session dates.
3. Background synchronization logged reflected server errors as public data.
   These details now use private log interpolation.
4. Parent Account tab opened a page titled My. Its title now matches Account.
5. iOS omitted the export-compliance key. Current code uses system HTTPS and
   Keychain plus hashing, not proprietary encryption. The bundle declares
   exempt encryption and preflight verifies the built value. Reassess this
   declaration if encryption implementations or dependencies change.

## Verified evidence

- Xcode 26.6 (17F113).
- Initial baseline: 157 Swift tests, macOS/iOS unsigned Release builds passed.
- After fixes: 160 Swift tests in 30 suites passed; 10 Admin SDK/API/MCP tests
  passed. No live writes are part of these tests.
- Forty local Supabase migrations match the linked project through
  `20260920210000`; linked database lint reports no schema errors.
- A read-only cloud query found one published contract, v1, with a test-version
  title. Its body was not copied into logs and no agreement was published.
- Supabase security advisors: zero ERROR findings and 30 WARN findings:
  one anonymous registration-preview RPC, 27 authenticated SECURITY DEFINER
  RPCs, disabled leaked-password protection, and insufficient MFA options.
  Public registration preview is intentional and guarded by an invitation;
  admin RPCs must keep their internal role and organization checks. These
  warnings are not automatically safe merely because lint passes. The existing
  authorization tests remain release gates. MFA/password settings were not
  silently changed, as this could alter existing user login behavior.
- Release app entrypoints use production authentication. Preview-role bypasses
  are DEBUG-only. No sample data was imported into production.
- A tracked-file scan found no secret Supabase keys, private-key blocks, or
  GitHub token patterns. This limited scan is not a full historical secret audit.
- Production data and schema were not modified. SDK credential access was
  unavailable; cloud inspection used the existing linked CLI in read-only mode.

## Public App Store gates

- [ ] In-app account deletion initiation and complete server-side handling.
  Decide retention/anonymization of school billing, attendance, learner and
  signed-contract records before implementing destructive behavior. Removing
  an app login is not the same as deleting a family/learner operational record.
  An email-only support instruction or deactivation alone is insufficient.
- [ ] Owner-approved public privacy-policy/support URLs, an accessible in-app
  privacy link, and accurate App Store Connect data-collection declarations.
- [ ] Replace the published test agreement with the approved final agreement
  through the normal revision/signature flow. Never alter prior signed copies.
- [ ] Resolve the Growth tab, which is currently an unconditional placeholder,
  before representing it as a working public feature.
- [ ] Final store screenshots, description, age rating, territories, reviewer
  account and instructions. Do not grant reviewers a real family account.
- [ ] Real-device admin and guardian acceptance: invitation and signature,
  password reset deep link, login retention, offline queue recovery, two-way
  attendance/leave sync, private receipt access, news/ad cache and appearance.
- [ ] Export a non-internal-only build when ready for public review. The current
  script intentionally keeps TestFlight internal-only.

## Distribution and live verification

See `docs/DISTRIBUTION.md` for verified package hashes, notarization, upload and
tester availability. A successful upload is not Apple processing approval or
proof that a tester can install. A fresh package does not update staff Macs.
The Mac was locked during the initial UI/App Store Connect verification attempt;
do not infer visual or tester acceptance from CLI build results.

## Primary references

- [Apple account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- [Apple privacy requirements](https://developer.apple.com/app-store/review/guidelines/#privacy)
- [Apple review completeness](https://developer.apple.com/app-store/review/)
- [Apple encryption declaration](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption)
- [Apple system encryption guidance](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations)
