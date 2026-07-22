begin;

create extension if not exists pgtap with schema extensions;

select plan(12);

select has_column(
  'public',
  'courses',
  'drop_in_unit_price_cents',
  'courses have a separate per-session enrollment price'
);

select has_column(
  'public',
  'enrollments',
  'registration_mode',
  'enrollments record their registration mode'
);

select has_table(
  'public',
  'enrollment_session_selections',
  'per-session enrollment selections table exists'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_enum e
    join pg_catalog.pg_type t on t.oid = e.enumtypid
    join pg_catalog.pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'enrollment_registration_mode'
      and e.enumlabel = 'per_session'
  ),
  'registration mode supports per-session enrollment'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.enrollment_session_selections'::regclass
      and conname = 'enrollment_session_selections_enrollment_fk'
  ),
  'selected sessions remain tied to their enrollment course'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.enrollment_session_selections'::regclass
      and conname = 'enrollment_session_selections_session_fk'
  ),
  'selected sessions must belong to the same course'
);

select ok(
  to_regprocedure(
    'public.admin_save_enrollment(uuid,uuid,uuid,uuid,timestamptz,text,text,text,date,integer,integer,text,text,integer,text,uuid[])'
  ) is not null,
  'atomic enrollment save RPC exists'
);

select ok(
  not has_table_privilege('authenticated', 'public.enrollments', 'INSERT')
    and not has_table_privilege('authenticated', 'public.enrollments', 'UPDATE'),
  'clients cannot bypass the atomic enrollment save RPC'
);

select ok(
  has_table_privilege('authenticated', 'public.enrollment_session_selections', 'SELECT')
    and not has_table_privilege('authenticated', 'public.enrollment_session_selections', 'INSERT'),
  'clients can read but cannot directly mutate session selections'
);

select ok(
  (select relrowsecurity from pg_catalog.pg_class where oid = 'public.enrollment_session_selections'::regclass),
  'session selections have RLS enabled'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_trigger
    where tgrelid = 'public.enrollment_session_selections'::regclass
      and tgname = 'enrollment_session_selections_audit'
      and not tgisinternal
  ),
  'session selection changes are audited'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'enrollment_session_selections'
  ),
  'session selections participate in active-client synchronization'
);

select * from finish();

rollback;
