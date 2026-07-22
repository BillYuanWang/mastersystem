# Product Design Baseline

## Selected direction

Phase 2 uses the third approved concept, `Context Split`, with the second concept's Ayu dark palette.

- A 58-point icon rail keeps the six administration destinations stable.
- The schedule is the primary canvas rather than a dashboard.
- Selection opens an integrated 294-point inspector instead of a modal card.
- Course setup groups courses, terms, and user-managed reference data in one destination.
- Student records use a sheet-like table. The student inspector only adds or removes course enrollments; it does not expose inline profile editing.

## Appearance

The app stores one of three explicit preferences: system, light, or dark.

- Dark: Ayu-inspired `#0A0E14` background, `#0F1419` surface, cyan `#39BAE6`, coral `#F07178`, saffron `#FFB454`, green `#AAD94C`, and violet `#D2A6FF`.
- Light: Raycast-inspired `#F7F7F8` background, white surfaces, charcoal text, cool gray dividers, and restrained coral-red emphasis.
- The dark option is the first-launch preview default. Users can change it from the bottom of the rail, including returning to system behavior.

## Type and density

- English navigation and microcopy use the system monospaced design at 11 points.
- Chinese interface text uses two primary sizes: 13 points for working text and 11 points for compact metadata.
- Course blocks may scale compact text down to 8-10 points to keep course name, category, instructor, and time visible.
- Letter spacing remains zero. Controls use a maximum 7-point corner radius.

## Schedule behavior

- The normal view covers all seven days from 9:30 AM to 8:30 PM.
- Users choose up to two user-managed room lanes at a time.
- Session placement and height are proportional to start time and duration.
- The zoom slider changes the timeline scale. The default scale fits the working window without vertical scrolling.
- Course blocks always show course name, age group, instructor, time, and a circled `组` or `私` marker.
- Roster, session count, room, attendance, and other details remain in hover help or the inspector.
- Course-type and age-group filtering use compact controls; no large filter pool occupies the timetable.

## Scope guardrails

Pricing, invoice, payment, credit, and receipt controls belong to macOS administration. iOS does not expose course prices or billing controls in this release. Per-class enrollment, parent course selection, teacher login, and AI implementation remain out of scope.
