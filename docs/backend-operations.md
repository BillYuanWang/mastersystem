# Backend Operations

## Release gate

1. Review pending migrations with `supabase db push --linked --dry-run`.
2. Apply migrations without seed data and push `config.toml`.
3. Run linked lint and pgTAP tests.
4. Deploy the authenticated Edge Function with API bundling.
5. Verify the private `contracts` bucket, Realtime publication, and zero unexpected anonymous grants.

Migrations are forward-only. Never edit a migration after it has reached a shared project; add a new timestamped migration.

## Monitoring

- Use Supabase database and Edge Function logs for failures and latency.
- Review `audit_events` for who changed operational records; it stores identifiers and actions, not row snapshots.
- Keep names, email addresses, student details, contract text, and push tokens out of application logs.
- Investigate repeated `42501`, scheduling exclusion (`23P01`), invitation cleanup, and failed notification events.
- Run `supabase db lint --linked --fail-on error` after every production migration.

## Backup and recovery

- Until the project has managed daily backups, create encrypted off-repository logical dumps. Never commit a data dump to this public repository.
- Back up roles, schema, and data separately with `supabase db dump`; contract Storage objects require a separate export.
- Rehearse restore into a disposable Supabase project before relying on a backup.
- After a restore, redeploy Edge Functions, push Auth configuration, verify Storage policies, and confirm Realtime publications.
- For an accidental change, stop writes, record the incident window, restore to a new project when practical, validate counts and authorization, then switch clients deliberately.

## Legacy CSV rehearsal

1. Copy the approved source into an ignored local working directory.
2. Compute and record a source fingerprint in `migration_runs`.
3. Parse with the documented column mapping; normalize, but do not silently invent reference values.
4. Dry-run every row and store validation counts only.
5. Apply additively in one controlled run and preserve source-to-target IDs in `migration_row_mappings`.
6. Reconcile course, session, student, guardian, and enrollment counts before approving the run.

The import path never becomes a recurring synchronization channel. Production edits happen through the app and Postgres.

## Incident rules

- Revoke or rotate a leaked secret immediately; publishable keys may be public, secret/service keys may not.
- Deactivate a compromised profile before repairing its linked records.
- Do not delete audit events during incident response.
- A database restore is incomplete until Auth, Storage, Realtime, Edge Functions, and native sign-in have all been checked.
