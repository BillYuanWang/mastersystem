# Backend Architecture

## Boundary

Supabase provides Auth, Postgres, Row Level Security, private contract Storage, Realtime, and one trusted invitation Edge Function. Native apps receive only the project URL and publishable key. Service-role and database credentials never ship in an app.

The database is the authority once Phase 4 connects the macOS client. The old CSV and local app remain migration inputs, not a second writable production store.

## Roles

| Role | Scope |
| --- | --- |
| `administrator` | Manage scheduling, students, term enrollments, attendance, leave, contracts, notifications, and invitations inside Master Dance. |
| `guardian` | Read linked children, courses, sessions, attendance, leave, contracts, and notifications; update own contact data; submit leave and consent through RPCs. |
| `adult_student` | Read the attached adult-student record and the same self-service information; submit leave and consent through RPCs. |

There is no instructor account in this release. An inactive profile has no organization or role access.

## Data map

- Tenant and identity: `organizations`, `profiles`.
- User-managed setup: `terms`, `course_categories`, `age_groups`, `rooms`, `instructors`.
- Schedule: `courses`, generated `class_sessions`, optional room/instructor overrides, cancellation status.
- People: `students`, `guardians`, `guardian_students`.
- Operations: term-only `enrollments`, `attendance`, `leave_requests`.
- Documents: versioned `contract_documents`, immutable `contract_consents`, private `contracts` bucket.
- Delivery and support: `notifications`, `device_push_tokens`, metadata-only `audit_events`.
- Legacy import control: `migration_runs`, `migration_row_mappings`.

Pricing, payments, credits, packages, per-class enrollment, AI, rule-builder exceptions, and parent self-enrollment are intentionally absent.

## Invariants

- Every business row belongs to an organization and cross-organization foreign keys are rejected.
- Active sessions cannot overlap in the same room or for the same instructor.
- Session time must remain inside its term; a cancelled week is a cancelled generated session.
- An enrollment is unique by term, course, and student.
- Attendance and leave can reference only the enrollment for that session's course.
- Course names, categories, age groups, rooms, and instructors are records, never hardcoded option enums.
- Contract files are private PDF objects, limited to 10 MiB and rooted by organization ID.

## Trusted workflows

RLS handles ordinary reads and administrator writes. Security-definer RPCs handle first-admin bootstrap, member finalization, leave submission, contract consent, profile activation, and marking notifications read. The invitation Edge Function verifies the caller as an active administrator, creates the Auth invitation with the server client, and atomically finalizes role/student links through an RPC.

The unresolved policy choices in `docs/policy-decisions.md` remain data/UI decisions. The backend deliberately does not invent leave deadlines, makeup credit calculations, reminder timing, or contract scope defaults.
