# Product Scope

## Phase 1 MVP

- Create terms, courses, and concrete class sessions.
- Maintain user-defined age groups, rooms, instructors, course types, and course names.
- Keep the legacy course-category relation hidden for migration compatibility.
- Mark courses as group or private while keeping the rest of course classification user-defined.
- Assign default instructors and rooms per course, with per-session overrides.
- Maintain students, guardians, and adult students.
- Enroll students in group courses for a complete term or selected class dates.
- Enroll private-lesson students only for explicitly selected class dates.
- Record attendance after a session; trial attendance does not create enrollment.
- Submit leave from iOS or on behalf of a user from administration.
- Record versioned contract consent.
- Record reminders and workflow notifications.
- Set separate full-term and per-session rates for group courses and a per-session-only rate for private lessons.
- Adjust one enrollment discount, trial fee, billing start date, and price snapshot.
- Issue immutable, versioned family invoices and record partial or full payments.
- Produce private invoice and receipt PNGs while keeping all billing controls on macOS.
- Offer system, light, and dark appearance modes.

## Roles

- Administrator: manages terms, course data, enrollment, leave, attendance, and contracts.
- Guardian: views linked child information, submits leave, and consents to contracts.
- Adult student: views personal information, submits leave, and consents to contracts.

An instructor is course data, not an authentication role in the MVP. The authorization design can grow later without creating a teacher account now.

## Deferred

- Tax calculation, refunds, and automated payment reminders.
- Automated credit, carry-over, injury-transfer, or exceptional settlement rules.
- Flexible multi-class packages.
- Exceptional pricing, attendance, leave, or settlement rule engines.
- Parent or adult-student course selection.
- Independent instructor accounts.
- Final remaining-session calculation until attendance, leave, and makeup rules are confirmed.
- Marketing content generation or other AI behavior.

## Open decisions

- Exact remaining-session calculation for present, excused, absent, and makeup states.
- Tax policy and any future refund workflow.
- Leave deadline defaults and whether courses can override them.
- Reminder timing and delivery channels.
- Whether contract consent scopes the term or a specific enrollment.
- Production rules for multiple guardians and children.
