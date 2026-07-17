# Additive CSV Migration Design

## Goal

Legacy CSV is a migration input and optional export format, not the production database. Migration must add validated records to Supabase without silently deleting or overwriting source data.

## Workflow

1. Copy selected source files into a timestamped local staging folder outside git.
2. Record a SHA-256 fingerprint for every source file.
3. Parse CSV with a real CSV parser that supports quoted fields, embedded commas, Unicode, and line endings.
4. Normalize whitespace and dates while preserving every original row and row number.
5. Resolve user-managed reference values before courses: terms, categories, age groups, rooms, and instructors.
6. Validate foreign keys, duplicate identities, date ranges, time ranges, weekday recurrence, and enrollment uniqueness.
7. Produce `MigrationDryRunReport` with per-entity inserts, updates, skips, warnings, and errors.
8. Allow apply only when the source fingerprint still matches and the report has no errors.
9. Write in one dependency-ordered transaction or resumable batch with a migration-run ID.
10. Export an apply report that maps each source row to the resulting stable ID.

## Required validation

- Headers and encoding are recognized before row parsing.
- Course references are never replaced with closed enums or guessed defaults.
- Course start precedes end, and generated sessions remain inside the term.
- Session end time is later than start time.
- Excluded weeks remove only concrete sessions.
- Student identity collisions are reported for review rather than merged by name alone.
- Enrollment uniqueness is checked by term, course, and student.
- Unknown rooms, instructors, categories, age groups, and courses are errors until mapped or explicitly created.
- Pricing columns from legacy files are ignored and reported as out of current scope.

## Idempotency And Recovery

- A migration-run table stores source fingerprints and row mappings.
- Re-running the same approved source proposes zero duplicate inserts.
- Updates require an explicit approved mapping; missing destination records are never interpreted as permission to delete.
- Every apply run has an inverse manifest for records created by that run, subject to foreign-key safety.

## Privacy

Production CSV, recordings, reports containing names, local data folders, and credentials must not be committed. Repository fixtures use synthetic names only.
