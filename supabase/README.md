# Supabase Backend

This directory is the production backend source of truth for Master Dance.

## Contents

- `migrations`: ordered Postgres schema, RLS, account linking, Storage, audit, and Realtime changes.
- `functions`: authenticated trusted workflows. The service-role credential exists only inside Supabase.
- `tests/database`: pgTAP coverage for schema, scheduling constraints, and family/organization isolation.
- `seed.sql`: synthetic local-development data only. It is never included in a normal remote `db push`.
- `config.toml`: local stack settings and remotely managed Auth configuration.

Production migrations create the Master Dance organization only. Course names, categories, age groups, rooms, and instructors remain empty user-managed tables.

## Local verification

A Docker-compatible runtime is required for the database suite:

```sh
supabase db start
supabase db lint --local --fail-on error
supabase test db --local
deno fmt --check supabase/functions
deno check supabase/functions/admin-invite-member/index.ts
```

GitHub Actions runs the same checks on Supabase changes.

## Remote release

```sh
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push --linked --dry-run
supabase db push --linked
supabase config push
supabase db lint --linked --fail-on error
supabase test db --linked
supabase functions deploy admin-invite-member --use-api
```

Do not add `--include-seed` in production. Never commit a database password, access token, secret key, service-role key, backup, student CSV, or recording.

## First administrator

Create the first Auth user through an owner-controlled Supabase workflow, sign
in, then call `bootstrap_first_administrator(display_name)` once. Every later
administrator is invited through `admin-invite-member`; public registration can
never create an administrator profile.

Email registration is available to guardian accounts. A newly registered Auth
user has no profile and no school-data access until
`claim_guardian_link_code(claim_code)` consumes a valid one-time code. Adult
learners and children can share the same guardian account and family record.

Native callback schemes are `masterdance-desk://auth-callback` and `masterdance://auth-callback`; the macOS and iOS targets must register them when Auth is connected.
