# Working Agreement

## Scope

- Preserve `web`, `macos-app`, and `product-research`; treat them as migration inputs.
- Keep production domain logic in `packages/MasterDanceCore` and UI composition in `apps`.
- Keep source and repository documentation primarily in English and ASCII.

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
