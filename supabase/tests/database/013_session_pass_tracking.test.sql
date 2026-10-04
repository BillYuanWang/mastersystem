begin;

create extension if not exists pgtap with schema extensions;

select plan(18);

select has_table('public', 'session_pass_plans', '有次卡方案资料表');
select has_table('public', 'student_session_passes', '有学员次卡资料表');
select has_table('public', 'session_pass_uses', '有划卡记录资料表');
select has_column('public', 'attendance', 'uses_session_pass', '签到可以标记使用次卡');
select ok(
  (select relrowsecurity from pg_catalog.pg_class where oid = 'public.session_pass_uses'::regclass),
  '划卡记录启用 RLS'
);
select ok(
  has_table_privilege('authenticated', 'public.session_pass_uses', 'SELECT')
    and not has_table_privilege('authenticated', 'public.session_pass_uses', 'INSERT')
    and not has_table_privilege('authenticated', 'public.session_pass_uses', 'DELETE'),
  '客户端只能读取划卡记录'
);
select is(
  (
    select count(*)
    from pg_catalog.pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename in ('session_pass_plans', 'student_session_passes', 'session_pass_uses')
  ),
  3::bigint,
  '次卡三张表都会同步到活跃客户端'
);

insert into public.organizations (id, name, slug, timezone)
values (
  '99000000-0000-0000-0000-000000000001',
  'Session Pass School',
  'session-pass-school',
  'America/Los_Angeles'
);

insert into auth.users (
  id, aud, role, email, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  (
    '99000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated', 'pass-family@example.test', now(),
    '{}'::jsonb, '{}'::jsonb, now(), now()
  ),
  (
    '99000000-0000-0000-0000-000000000003',
    'authenticated', 'authenticated', 'other-family@example.test', now(),
    '{}'::jsonb, '{}'::jsonb, now(), now()
  );

insert into public.profiles (user_id, organization_id, role, display_name)
values
  (
    '99000000-0000-0000-0000-000000000002',
    '99000000-0000-0000-0000-000000000001',
    'guardian',
    'Pass Family'
  ),
  (
    '99000000-0000-0000-0000-000000000003',
    '99000000-0000-0000-0000-000000000001',
    'guardian',
    'Other Family'
  );

insert into public.guardians (id, organization_id, profile_user_id, display_name, email)
values
  (
    '99000000-0000-0000-0000-000000000010',
    '99000000-0000-0000-0000-000000000001',
    '99000000-0000-0000-0000-000000000002',
    'Pass Family',
    'pass-family@example.test'
  ),
  (
    '99000000-0000-0000-0000-000000000011',
    '99000000-0000-0000-0000-000000000001',
    '99000000-0000-0000-0000-000000000003',
    'Other Family',
    'other-family@example.test'
  );

insert into public.students (id, organization_id, guardian_id, display_name, kind)
values
  (
    '99000000-0000-0000-0000-000000000020',
    '99000000-0000-0000-0000-000000000001',
    '99000000-0000-0000-0000-000000000010',
    'Adult Pass Learner',
    'adult'
  ),
  (
    '99000000-0000-0000-0000-000000000021',
    '99000000-0000-0000-0000-000000000001',
    '99000000-0000-0000-0000-000000000010',
    'Child Learner',
    'child'
  ),
  (
    '99000000-0000-0000-0000-000000000022',
    '99000000-0000-0000-0000-000000000001',
    '99000000-0000-0000-0000-000000000011',
    'Other Adult',
    'adult'
  );

insert into public.terms (id, organization_id, name, starts_on, ends_on, status)
values (
  '99000000-0000-0000-0000-000000000030',
  '99000000-0000-0000-0000-000000000001',
  'Fall 2026',
  '2026-08-01',
  '2026-12-31',
  'open'
);

insert into public.term_holidays (id, organization_id, term_id, name, starts_on, ends_on)
values (
  '99000000-0000-0000-0000-000000000031',
  '99000000-0000-0000-0000-000000000001',
  '99000000-0000-0000-0000-000000000030',
  'Thanksgiving',
  '2026-11-23',
  '2026-11-29'
);

insert into public.course_categories (id, organization_id, name)
values ('99000000-0000-0000-0000-000000000032', '99000000-0000-0000-0000-000000000001', 'Dance');
insert into public.course_types (id, organization_id, name, is_private)
values ('99000000-0000-0000-0000-000000000033', '99000000-0000-0000-0000-000000000001', 'Group', false);
insert into public.age_groups (id, organization_id, name)
values ('99000000-0000-0000-0000-000000000034', '99000000-0000-0000-0000-000000000001', 'Adult');
insert into public.rooms (id, organization_id, name)
values ('99000000-0000-0000-0000-000000000035', '99000000-0000-0000-0000-000000000001', 'Room');
insert into public.instructors (id, organization_id, display_name)
values ('99000000-0000-0000-0000-000000000036', '99000000-0000-0000-0000-000000000001', 'Teacher');

insert into public.courses (
  id, organization_id, term_id, name, category_id, age_group_id,
  default_room_id, default_instructor_id, course_type_id, format
)
values (
  '99000000-0000-0000-0000-000000000037',
  '99000000-0000-0000-0000-000000000001',
  '99000000-0000-0000-0000-000000000030',
  'Adult Drop In',
  '99000000-0000-0000-0000-000000000032',
  '99000000-0000-0000-0000-000000000034',
  '99000000-0000-0000-0000-000000000035',
  '99000000-0000-0000-0000-000000000036',
  '99000000-0000-0000-0000-000000000033',
  'group'
);

insert into public.class_sessions (
  id, organization_id, course_id, starts_at, ends_at,
  effective_instructor_id, effective_room_id
)
values (
  '99000000-0000-0000-0000-000000000038',
  '99000000-0000-0000-0000-000000000001',
  '99000000-0000-0000-0000-000000000037',
  '2026-09-01 18:00:00-07',
  '2026-09-01 19:00:00-07',
  '99000000-0000-0000-0000-000000000036',
  '99000000-0000-0000-0000-000000000035'
);

insert into public.session_pass_plans (
  id, organization_id, name, included_sessions, unit_price_cents
)
values (
  '99000000-0000-0000-0000-000000000040',
  '99000000-0000-0000-0000-000000000001',
  'Adult 10 Pass',
  10,
  4000
);

select throws_ok(
  $$
    insert into public.student_session_passes (
      organization_id, student_id, plan_id, included_sessions, unit_price_cents
    ) values (
      '99000000-0000-0000-0000-000000000001',
      '99000000-0000-0000-0000-000000000021',
      '99000000-0000-0000-0000-000000000040',
      10,
      4000
    )
  $$,
  '23514',
  null,
  '少儿学员不能发放成人次卡'
);

select throws_ok(
  $$
    insert into public.student_session_passes (
      organization_id, student_id, plan_id, included_sessions, unit_price_cents
    ) values (
      '99000000-0000-0000-0000-000000000001',
      '99000000-0000-0000-0000-000000000020',
      '99000000-0000-0000-0000-000000000040',
      10,
      4500
    )
  $$,
  '23514',
  null,
  '发卡时不能擅自改变方案单价'
);

insert into public.student_session_passes (
  id, organization_id, student_id, plan_id, issued_at,
  included_sessions, unit_price_cents
)
values
  (
    '99000000-0000-0000-0000-000000000041',
    '99000000-0000-0000-0000-000000000001',
    '99000000-0000-0000-0000-000000000020',
    '99000000-0000-0000-0000-000000000040',
    '2026-08-20 09:00:00-07',
    10,
    4000
  ),
  (
    '99000000-0000-0000-0000-000000000042',
    '99000000-0000-0000-0000-000000000001',
    '99000000-0000-0000-0000-000000000022',
    '99000000-0000-0000-0000-000000000040',
    '2026-08-20 09:00:00-07',
    10,
    4000
  );

select lives_ok(
  $$
    insert into public.attendance (
      id, organization_id, session_id, student_id, uses_session_pass,
      status, recorded_at
    ) values (
      '99000000-0000-0000-0000-000000000050',
      '99000000-0000-0000-0000-000000000001',
      '99000000-0000-0000-0000-000000000038',
      '99000000-0000-0000-0000-000000000020',
      true,
      'present',
      '2026-09-01 18:05:00-07'
    )
  $$,
  '次卡签到可以正常保存'
);

select is(
  (select count(*) from public.session_pass_uses where attendance_id = '99000000-0000-0000-0000-000000000050'),
  1::bigint,
  '次卡签到自动产生一条划卡记录'
);

select is(
  (
    select student_session_pass_id
    from public.session_pass_uses
    where attendance_id = '99000000-0000-0000-0000-000000000050'
  ),
  '99000000-0000-0000-0000-000000000041'::uuid,
  '划卡记录使用学员自己最早的可用卡'
);

select throws_ok(
  $$
    update public.student_session_passes
    set included_sessions = 9
    where id = '99000000-0000-0000-0000-000000000041'
  $$,
  '23514',
  null,
  '已有划卡记录后不能改卡内次数'
);

select throws_ok(
  $$
    delete from public.student_session_passes
    where id = '99000000-0000-0000-0000-000000000041'
  $$,
  '23503',
  null,
  '已有划卡记录的卡不能删除'
);

delete from public.attendance
where id = '99000000-0000-0000-0000-000000000050';

select is(
  (select count(*) from public.session_pass_uses where attendance_id = '99000000-0000-0000-0000-000000000050'),
  0::bigint,
  '取消签到会自动退回一次'
);

insert into public.attendance (
  id, organization_id, session_id, student_id, uses_session_pass,
  status, recorded_at
)
values (
  '99000000-0000-0000-0000-000000000051',
  '99000000-0000-0000-0000-000000000001',
  '99000000-0000-0000-0000-000000000038',
  '99000000-0000-0000-0000-000000000020',
  true,
  'present',
  '2026-09-01 18:06:00-07'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '99000000-0000-0000-0000-000000000002', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"99000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

select is(
  (select count(*) from public.student_session_passes),
  1::bigint,
  '家长只能看到自己家学员的次卡'
);

select is(
  (select count(*) from public.session_pass_uses),
  1::bigint,
  '家长只能看到自己家学员的划卡记录'
);

select is(
  (select count(*) from public.session_pass_plans),
  1::bigint,
  '家长可以读取正在使用的次卡方案名称'
);

select * from finish();

rollback;
