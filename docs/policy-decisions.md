# Policy Decision Log

Phase 2 deliberately separates confirmed product boundaries from policies that still need client approval. Open policies are not encoded as silent defaults.

## Confirmed

- Only administrators manage courses, enrollments, and attendance in the MVP.
- Administrator accounts can use every school-management workflow, including managing student records, but do not enter the student-facing experience.
- Student-facing accounts are initially limited to upcoming classes, notifications, and leave requests; detailed rules will be approved incrementally.
- Instructors remain user-managed course data and do not receive independent login accounts.
- Enrollment covers a complete term. Per-session enrollment is out of scope.
- Parents and adult students cannot select or add courses themselves.
- Pricing, balances, credits, and exceptional settlement logic are absent.
- Trial or temporary attendance does not create an enrollment.
- Course names, categories, age groups, rooms, and instructors remain user-managed entities.
- Appearance supports system, light, and dark.

## Open Before Phase 4 Or 5

| Policy | Current implementation boundary |
| --- | --- |
| Remaining-session calculation | Store sessions, enrollment, attendance, and leave independently; show no calculated balance. |
| Leave deadline | Store submission and resolution timestamps; enforce no cutoff yet. |
| Reminder timing and channels | Store schedulable notification records; schedule no automatic delivery yet. |
| Contract consent scope | Model supports term-level or enrollment-level consent; choose neither automatically. |
| Multiple guardians and shared children | Domain supports multiple links; production authorization awaits confirmation. |

These decisions should be confirmed in one short client review before implementing Phase 4 attendance policy and Phase 5 member workflows.
