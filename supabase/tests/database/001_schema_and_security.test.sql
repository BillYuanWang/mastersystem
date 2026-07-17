begin;

create extension if not exists pgtap with schema extensions;

select plan(21);

select has_table('public', 'organizations', 'organizations table exists');
select has_table('public', 'terms', 'terms table exists');
select has_table('public', 'courses', 'courses table exists');
select has_table('public', 'class_sessions', 'class sessions table exists');
select has_table('public', 'students', 'students table exists');
select has_table('public', 'enrollments', 'enrollments table exists');
select has_table('public', 'attendance', 'attendance table exists');
select has_table('public', 'leave_requests', 'leave requests table exists');
select has_table('public', 'contract_documents', 'contract documents table exists');
select has_table('public', 'notifications', 'notifications table exists');
select has_table('public', 'audit_events', 'audit events table exists');

select is(
  (
    select count(*)
    from information_schema.tables
    where table_schema = 'public'
      and table_type = 'BASE TABLE'
  ),
  22::bigint,
  'the public schema contains the expected tables'
);

select ok(
  not exists (
    select 1
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('r', 'p')
      and not c.relrowsecurity
  ),
  'RLS is enabled on every public table'
);

select ok(
  not exists (
    select 1
    from information_schema.table_privileges
    where table_schema = 'public'
      and grantee = 'anon'
  ),
  'anonymous users have no public-table privileges'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'private.capture_audit_event()',
    'EXECUTE'
  ),
  'private trigger helpers are not directly executable'
);

select ok(
  to_regprocedure('public.bootstrap_first_administrator(text)') is not null,
  'administrator bootstrap RPC exists'
);

select like(
  pg_get_functiondef('public.bootstrap_first_administrator(text)'::regprocedure),
  '%pg_advisory_xact_lock%',
  'administrator bootstrap serializes concurrent activation attempts'
);

select ok(
  to_regprocedure(
    'public.admin_finalize_invited_member(uuid,text,text,public.app_role,uuid[])'
  ) is not null,
  'trusted member-finalization RPC exists'
);

select is(
  (select count(*) from public.organizations where slug = 'master-dance'),
  1::bigint,
  'production organization is bootstrapped once'
);

select ok(
  exists (
    select 1
    from storage.buckets
    where id = 'contracts'
      and not public
      and file_size_limit = 10485760
      and allowed_mime_types = array['application/pdf']::text[]
  ),
  'contracts use a private PDF-only bucket'
);

select is(
  (
    select count(*)
    from pg_catalog.pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename in (
        'attendance',
        'class_sessions',
        'enrollments',
        'leave_requests',
        'notifications'
      )
  ),
  5::bigint,
  'operational tables are available through Realtime'
);

select * from finish();

rollback;
