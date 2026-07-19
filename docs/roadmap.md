# Roadmap

## Phase 1: Foundation - complete

- Establish the repository, privacy rules, product scope, and Swift 6 core.
- Define replaceable repositories, preview data, tests, and native app shells.
- Preserve the working legacy web and macOS versions as migration inputs.

## Phase 2: Product design and shared workflows - complete

- Design the compact native navigation and schedule experience.
- Build reusable SwiftUI flows for terms, custom course reference data, sessions, students, and enrollments.
- Confirm the remaining-session, leave-deadline, reminder, and contract-scope rules before encoding policies.
- Design additive CSV migration with validation and a dry-run report.
- Verify the selected Option 3 layout with Option 2 dark colors in matched-size native screenshots.

## Phase 3: Supabase backend - complete

- Design Postgres schema, constraints, indexes, and Row Level Security.
- Implement Auth roles, profiles, and guardian-student relationships.
- Add Storage for versioned contracts and Edge Functions for trusted workflows.
- Create seed data, migration rehearsal, observability, backups, and recovery checks.

## Phase 4: MD Desk macOS MVP - implementation complete

- Deliver the administration schedule, course setup, student table, total enrollment, attendance, leave, contracts, and notifications.
- Connect the macOS app to Supabase while keeping preview mode for tests.
- Validate printing, light/dark/system appearance, keyboard and pointer workflows.

## Phase 5: Master Dance iPhone MVP - implementation complete

- Deliver attendance-focused administration plus guardian and adult-student experiences.
- Provide course and next-session views, leave requests, contract consent, notifications, and appearance controls.
- Keep parent and adult accounts view-first; no self-enrollment in the MVP.

## Phase 6: Integration and demo build

- Import approved legacy data without publishing private CSV or recordings.
- Verify end-to-end authorization, enrollment, attendance, leave, consent, and notification flows.
- Produce first installable macOS and iPhone demo builds and document release prerequisites.

## Later

- Evaluate website content synchronization after the website platform decision.
- Evaluate additional delivery channels and an instructor role only after product approval.
- Evaluate AI capabilities through the existing extension point, with privacy and human review.
- Revisit financial and flexible-enrollment concepts as separate bounded domains.
