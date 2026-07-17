# Design QA

## Visual Truth

- Reference: selected Option 3 `Context Split` concept.
- User override: apply Option 2's Ayu dark palette while retaining Raycast light and system appearance.
- Reference viewport: 1487 x 1058.
- Implementation viewport: 1487 x 1058.
- Compared state: schedule, Monday-Friday, both rooms, dark appearance, selected Thursday session.

## Evidence

- Full comparison: `docs/design-qa/design-qa-comparison.jpg`
- Dark schedule: `docs/design-qa/admin-reference-size.png`
- Light schedule: `docs/design-qa/admin-light.png`
- Course recurrence editor: `docs/design-qa/course-editor.png`
- Setup, students, enrollment, attendance, and requests: `docs/design-qa/workspaces-qa.png`

## Fidelity Review

- Typography: compact monospaced English and two primary Chinese sizes; course text scales down without hiding required fields.
- Layout: 58-point rail, primary schedule canvas, stable right inspector, 9:30 AM-8:30 PM timeline, and paired room lanes match the approved direction.
- Color: Ayu dark and Raycast light are implemented as explicit themes.
- Assets: the supplied Master Dance logo and generated `.icns` are bundled at native resolution.
- Copy: no pricing, credits, per-session enrollment, parent self-enrollment, teacher login, or AI controls appear.
- Interaction: rail destinations, filters, zoom, selection, recurrence exclusions, enrollment add/remove, attendance, printing, and appearance controls are wired.

## Comparison History

- Pass 1 found two P2 issues: compressed blocks wrapped the time label, and the default selection did not match the populated inspector.
- Fixes applied: single-line shrinking metadata, today-first selection, and realistic roster/attendance preview records.
- Pass 2 found no active P0, P1, or P2 issue.
- Accepted P3 difference: the generated concept used a decorative connector line; the native build uses a selected cyan outline and fixed inspector divider for clarity.

## Final Result

passed
