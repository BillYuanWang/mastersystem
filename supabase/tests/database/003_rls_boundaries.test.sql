begin;

create extension if not exists pgtap with schema extensions;

select plan(13);

select ok(
  to_regprocedure('public.current_sync_revision()') is not null,
  'member sync revision RPC exists'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.current_sync_revision()',
    'EXECUTE'
  ),
  'authenticated members may read their organization sync revision'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.current_sync_revision()',
    'EXECUTE'
  ),
  'anonymous callers cannot read a sync revision'
);

insert into public.organizations (id, name, slug, timezone)
values
  (
    '91000000-0000-0000-0000-000000000001',
    'RLS School A',
    'rls-school-a',
    'America/Los_Angeles'
  ),
  (
    '91000000-0000-0000-0000-000000000002',
    'RLS School B',
    'rls-school-b',
    'America/Los_Angeles'
  );

insert into auth.users (
  id,
  aud,
  role,
  email,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
values
  (
    '91000000-0000-0000-0000-000000000010',
    'authenticated',
    'authenticated',
    'admin-a@example.test',
    now(),
    '{}'::jsonb,
    '{}'::jsonb,
    now(),
    now()
  ),
  (
    '91000000-0000-0000-0000-000000000011',
    'authenticated',
    'authenticated',
    'guardian-a@example.test',
    now(),
    '{}'::jsonb,
    '{}'::jsonb,
    now(),
    now()
  ),
  (
    '91000000-0000-0000-0000-000000000012',
    'authenticated',
    'authenticated',
    'guardian-b@example.test',
    now(),
    '{}'::jsonb,
    '{}'::jsonb,
    now(),
    now()
  );

insert into public.profiles (
  user_id,
  organization_id,
  role,
  display_name
)
values
  (
    '91000000-0000-0000-0000-000000000010',
    '91000000-0000-0000-0000-000000000001',
    'administrator',
    'Admin A'
  ),
  (
    '91000000-0000-0000-0000-000000000011',
    '91000000-0000-0000-0000-000000000001',
    'guardian',
    'Guardian A'
  ),
  (
    '91000000-0000-0000-0000-000000000012',
    '91000000-0000-0000-0000-000000000002',
    'guardian',
    'Guardian B'
  );

insert into public.guardians (
  id,
  organization_id,
  profile_user_id,
  display_name,
  email
)
values
  (
    '91000000-0000-0000-0000-000000000030',
    '91000000-0000-0000-0000-000000000001',
    '91000000-0000-0000-0000-000000000011',
    'Guardian A',
    'guardian-a@example.test'
  ),
  (
    '91000000-0000-0000-0000-000000000031',
    '91000000-0000-0000-0000-000000000002',
    '91000000-0000-0000-0000-000000000012',
    'Guardian B',
    'guardian-b@example.test'
  ),
  (
    '91000000-0000-0000-0000-000000000032',
    '91000000-0000-0000-0000-000000000001',
    null,
    'Unlinked Family A',
    null
  );

insert into public.students (
  id,
  organization_id,
  guardian_id,
  display_name,
  kind
)
values
  (
    '91000000-0000-0000-0000-000000000020',
    '91000000-0000-0000-0000-000000000001',
    '91000000-0000-0000-0000-000000000030',
    'Linked Child A',
    'child'
  ),
  (
    '91000000-0000-0000-0000-000000000021',
    '91000000-0000-0000-0000-000000000001',
    '91000000-0000-0000-0000-000000000032',
    'Unlinked Child A',
    'child'
  ),
  (
    '91000000-0000-0000-0000-000000000022',
    '91000000-0000-0000-0000-000000000002',
    '91000000-0000-0000-0000-000000000031',
    'Linked Child B',
    'child'
  );

create temporary table expected_sync_revisions (
  organization_id uuid primary key,
  change_sequence bigint not null
) on commit drop;

insert into expected_sync_revisions (organization_id, change_sequence)
select
  organization.id,
  coalesce(max(audit.id), 0)::bigint
from (
  values
    ('91000000-0000-0000-0000-000000000001'::uuid),
    ('91000000-0000-0000-0000-000000000002'::uuid)
) as organization(id)
left join public.audit_events audit
  on audit.organization_id = organization.id
group by organization.id;

grant select on expected_sync_revisions to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-0000-0000-000000000011',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"91000000-0000-0000-0000-000000000011","role":"authenticated"}',
  true
);

select is(
  (select count(*) from public.students),
  1::bigint,
  'a guardian sees only linked students'
);

select is(
  (select change_sequence from public.current_sync_revision()),
  (
    select change_sequence
    from expected_sync_revisions
    where organization_id = '91000000-0000-0000-0000-000000000001'
  ),
  'a guardian receives the first school sync revision'
);

select throws_ok(
  $$
    insert into public.students (organization_id, guardian_id, display_name, kind)
    values (
      '91000000-0000-0000-0000-000000000001',
      '91000000-0000-0000-0000-000000000030',
      'Forbidden Student',
      'child'
    )
  $$,
  '42501',
  null,
  'guardians cannot create students'
);

select lives_ok(
  $$
    update public.guardians
    set phone = '949-555-0100'
    where profile_user_id = '91000000-0000-0000-0000-000000000011'
  $$,
  'guardians can maintain their own contact details'
);

select throws_ok(
  $$
    update public.profiles
    set role = 'administrator'
    where user_id = '91000000-0000-0000-0000-000000000011'
  $$,
  '42501',
  null,
  'guardians cannot elevate their role'
);

select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-0000-0000-000000000012',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"91000000-0000-0000-0000-000000000012","role":"authenticated"}',
  true
);

select is(
  (select array_agg(display_name order by display_name) from public.students),
  array['Linked Child B']::text[],
  'a second family cannot see the first family'
);

select is(
  (select change_sequence from public.current_sync_revision()),
  (
    select change_sequence
    from expected_sync_revisions
    where organization_id = '91000000-0000-0000-0000-000000000002'
  ),
  'a second guardian receives only the second school sync revision'
);

select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-0000-0000-000000000010',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"91000000-0000-0000-0000-000000000010","role":"authenticated"}',
  true
);

select is(
  (select count(*) from public.students),
  2::bigint,
  'an administrator sees students in their organization'
);

select is(
  (
    select count(*)
    from public.students
    where organization_id = '91000000-0000-0000-0000-000000000002'
  ),
  0::bigint,
  'an administrator cannot cross the organization boundary'
);

select lives_ok(
  $$
    insert into public.course_categories (organization_id, name)
    values (
      '91000000-0000-0000-0000-000000000001',
      'Administrator Custom Category'
    )
  $$,
  'administrators can create their own course reference data'
);

select * from finish();

rollback;
