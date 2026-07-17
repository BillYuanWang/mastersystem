# Working Agreement

## Scope

- Preserve `web`, `macos-app`, and `product-research`; treat them as migration inputs.
- Keep production domain logic in `packages/MasterDanceCore` and UI composition in `apps`.
- Keep source and repository documentation primarily in English and ASCII.

## Product constraints

- Phase 1 models term-based enrollment only.
- Do not add pricing, balances, credits, per-class billing, or exceptional settlement rules.
- Do not add parent-selected courses or an independent teacher login role.
- Keep instructors as user-managed course data.
- Keep course category, age group, room, instructor, and course name user-managed rather than closed enums.
- Preserve system, light, and dark appearance choices.
- AI integrations must remain behind `AIExtension`; do not ship an implementation in Phase 1.

## Engineering constraints

- Keep `MasterDanceCore` free of third-party dependencies.
- Repository implementations must be replaceable without changing domain models or feature callers.
- Run `swift test` from the repository root after core changes.
- Generate app projects from `apps/project.yml`; do not commit generated build output.
- Never commit secrets, recordings, production CSV data, app bundles, or local data folders.
