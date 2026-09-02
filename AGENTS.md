# Working Agreement

## Scope

- Preserve `web` and `product-research` as migration inputs. Treat `macos-app`
  as retired reference source only: never build, launch, or restore its old app
  bundle; its compatibility script must redirect to the current root app.
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

- Update `README.md` and `HISTORY.md` for each user-visible release.
- Treat `TUTORIAL.md` and `MD_DESK_EMPLOYEE_GUIDE.md` as employee handoff
  artifacts. Update them only when the user asks for a current staff package,
  then regenerate their matching PDFs from the Markdown sources. Do not spend
  release time regenerating either guide for every small product iteration.
- Keep `TUTORIAL.md` as the single editable source for `TUTORIAL.pdf`; regenerate
  it with `./script/build_tutorial_pdf.sh` and never edit the PDF by hand.
- Write the administrator tutorial in plain Chinese, organize it by the macOS
  tabs, and update cross-tab workflows when a change affects more than one tab.
- For documentation-only releases, use the current product version plus the
  next letter suffix. Do not change app build numbers or the database solely for
  a documentation release.

## Release reporting

- After every macOS or iOS app change, report all three version tracks to the
  user: the current local macOS version/build, the latest distributed notarized
  macOS package, and the current local iOS version/build versus the latest
  accepted TestFlight build.
- State the build-number distance for each platform, whether a new package was
  actually distributed, and a short user-facing feature delta from the latest
  distributed build to the current local build.
- Never describe a local build as distributed. Update the distributed baseline
  in `docs/DISTRIBUTION.md` only after the notarized Mac artifact or TestFlight
  upload has been verified.
