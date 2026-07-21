begin;

create extension if not exists pgtap with schema extensions;

select plan(10);

select has_table('public', 'advertisements', 'advertisements table exists');

select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where conname = 'advertisements_slot_schedule_excl'
      and conrelid = 'public.advertisements'::regclass
  ),
  'published campaigns cannot overlap in the same slot'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where conname = 'advertisements_thumbnail_metadata_check'
      and conrelid = 'public.advertisements'::regclass
  ),
  'square thumbnail metadata is constrained'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where conname = 'advertisements_poster_metadata_check'
      and conrelid = 'public.advertisements'::regclass
  ),
  'poster metadata is constrained'
);

select ok(
  position(
    '1024' in coalesce((
      select pg_get_constraintdef(oid)
      from pg_catalog.pg_constraint
      where conname = 'advertisements_copy_text_check'
        and conrelid = 'public.advertisements'::regclass
    ), '')
  ) > 0,
  'advertisement detail copy accepts up to 1024 characters'
);

select ok(
  position(
    '0.8' in coalesce((
      select pg_get_constraintdef(oid)
      from pg_catalog.pg_constraint
      where conname = 'advertisements_poster_metadata_check'
        and conrelid = 'public.advertisements'::regclass
    ), '')
  ) = 0,
  'advertisement posters do not require a fixed aspect ratio'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_policies
    where schemaname = 'public'
      and tablename = 'advertisements'
      and policyname = 'advertisements_member_select'
  ),
  'members receive a read-only published-ad policy'
);

select ok(
  exists (
    select 1
    from storage.buckets
    where id = 'advertisement-media'
      and not public
      and file_size_limit = 8388608
  ),
  'advertisement images use a private 8 MB bucket'
);

select ok(
  has_function_privilege(
    'authenticated',
    'private.can_access_advertisement_object(text)',
    'EXECUTE'
  ),
  'authenticated users can evaluate advertisement object access'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'advertisements'
  ),
  'advertisements are available through Realtime'
);

select * from finish();

rollback;
