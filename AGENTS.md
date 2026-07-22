# Working Agreement

## Scope

- Preserve `web`, `macos-app`, and `product-research`; treat them as migration inputs.
- Keep production domain logic in `packages/MasterDanceCore` and UI composition in `apps`.
- Keep engineering documentation primarily in English and ASCII. Product-facing
  operator documentation may use Chinese when that is the clearest language for
  the intended user.

## Product constraints

- Billing uses integer USD cents, enrollment price snapshots, and actual scheduled sessions.
- Issued invoices and receipts are immutable; corrections create a new version.
- Keep tax, refunds, payment reminders, and exceptional settlement rule engines out of the current release.
- Keep pricing controls in macOS administration; iOS may only display private billing PNGs in a later release.
- Do not add parent-selected courses or an independent teacher login role.
- Keep instructors as user-managed course data.
- Keep age group, room, instructor, course type, and course name user-managed rather than closed enums.
- Keep the legacy course-category field hidden as compatibility data; do not expose category management in the app.
- Preserve system, light, and dark appearance choices.
- AI integrations must remain behind `AIExtension`; do not ship an implementation in the current release.

## Engineering constraints

- Keep `MasterDanceCore` free of third-party dependencies.
- Repository implementations must be replaceable without changing domain models or feature callers.
- Run `swift test` from the repository root after core changes.
- Generate app projects from `apps/project.yml`; do not commit generated build output.
- Never commit secrets, recordings, production CSV data, app bundles, or local data folders.

## Release documentation

- Every user-visible feature, workflow, rule, limitation, or release change must
  update all four root artifacts before the release is considered complete:
  `README.md`, `HISTORY.md`, `TUTORIAL.md`, and the regenerated `TUTORIAL.pdf`.
- Keep `TUTORIAL.md` as the single editable source for the PDF. Regenerate the
  PDF with `./script/build_tutorial_pdf.sh`; never edit the PDF by hand.
- Write the administrator tutorial in plain Chinese, organize it by the macOS
  tabs, and update cross-tab workflows when a change affects more than one tab.
- For documentation-only releases, use the current product version plus the
  next letter suffix. Do not change app build numbers or the database solely for
  a documentation release.
