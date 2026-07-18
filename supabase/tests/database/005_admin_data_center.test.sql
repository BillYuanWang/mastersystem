begin;

create extension if not exists pgtap with schema extensions;

select plan(19);

select has_table('public', 'course_types', '有课程种类资料表');
select has_table('public', 'term_holidays', '有学期假期资料表');
select has_column('public', 'students', 'guardian_id', '学员必须保存监护人主键');
select has_column('public', 'courses', 'course_type_id', '课程必须保存课程种类主键');
select has_column('public', 'courses', 'is_active', '课程可以停用');
select ok(
  to_regprocedure('public.admin_delete_record(text,uuid)') is not null,
  '有受控删除函数'
);
select ok(
  not has_table_privilege('authenticated', 'public.guardian_students', 'INSERT'),
  '客户端不能绕过受控流程直接新增家庭关系'
);
select has_column('public', 'enrollments', 'student_id', '报名关联到学员');
select hasnt_column('public', 'enrollments', 'guardian_id', '报名不关联到监护人');

insert into public.organizations (id, name, slug, timezone)
values (
  '93000000-0000-0000-0000-000000000001',
  'Data Center School',
  'data-center-school',
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
values (
  '93000000-0000-0000-0000-000000000002',
  'authenticated',
  'authenticated',
  'admin-data-center@example.test',
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
values (
  '93000000-0000-0000-0000-000000000002',
  '93000000-0000-0000-0000-000000000001',
  'administrator',
  'Data Center Admin'
);

insert into public.terms (
  id,
  organization_id,
  name,
  starts_on,
  ends_on,
  status
)
values (
  '93000000-0000-0000-0000-000000000003',
  '93000000-0000-0000-0000-000000000001',
  'Fall 2026',
  '2026-08-01',
  '2026-12-31',
  'open'
);

insert into public.course_categories (id, organization_id, name)
values (
  '93000000-0000-0000-0000-000000000004',
  '93000000-0000-0000-0000-000000000001',
  'Ballet'
);

insert into public.course_types (id, organization_id, name, is_private)
values
  (
    '93000000-0000-0000-0000-000000000005',
    '93000000-0000-0000-0000-000000000001',
    'Large Group',
    false
  ),
  (
    '93000000-0000-0000-0000-000000000006',
    '93000000-0000-0000-0000-000000000001',
    'Unused Type',
    false
  );

insert into public.age_groups (id, organization_id, name)
values (
  '93000000-0000-0000-0000-000000000007',
  '93000000-0000-0000-0000-000000000001',
  'Children'
);

insert into public.rooms (id, organization_id, name)
values (
  '93000000-0000-0000-0000-000000000008',
  '93000000-0000-0000-0000-000000000001',
  'Large Room'
);

insert into public.instructors (id, organization_id, display_name)
values (
  '93000000-0000-0000-0000-000000000009',
  '93000000-0000-0000-0000-000000000001',
  'Teacher'
);

insert into public.guardians (id, organization_id, display_name)
values
  (
    '93000000-0000-0000-0000-000000000010',
    '93000000-0000-0000-0000-000000000001',
    'First Family'
  ),
  (
    '93000000-0000-0000-0000-000000000011',
    '93000000-0000-0000-0000-000000000001',
    'Second Family'
  );

insert into public.students (
  id,
  organization_id,
  guardian_id,
  display_name,
  kind
)
values (
  '93000000-0000-0000-0000-000000000012',
  '93000000-0000-0000-0000-000000000001',
  '93000000-0000-0000-0000-000000000010',
  'Learner',
  'child'
);

insert into public.courses (
  id,
  organization_id,
  term_id,
  name,
  category_id,
  age_group_id,
  default_room_id,
  default_instructor_id,
  course_type_id,
  format
)
values (
  '93000000-0000-0000-0000-000000000013',
  '93000000-0000-0000-0000-000000000001',
  '93000000-0000-0000-0000-000000000003',
  'Technique',
  '93000000-0000-0000-0000-000000000004',
  '93000000-0000-0000-0000-000000000007',
  '93000000-0000-0000-0000-000000000008',
  '93000000-0000-0000-0000-000000000009',
  '93000000-0000-0000-0000-000000000005',
  'group'
);

select lives_ok(
  $$
    insert into public.term_holidays (
      id,
      organization_id,
      term_id,
      name,
      starts_on,
      ends_on
    )
    values (
      '93000000-0000-0000-0000-000000000014',
      '93000000-0000-0000-0000-000000000001',
      '93000000-0000-0000-0000-000000000003',
      'Thanksgiving',
      '2026-11-23',
      '2026-11-29'
    )
  $$,
  '学期内可以新增假期'
);

select throws_ok(
  $$
    insert into public.term_holidays (
      organization_id,
      term_id,
      name,
      starts_on,
      ends_on
    )
    values (
      '93000000-0000-0000-0000-000000000001',
      '93000000-0000-0000-0000-000000000003',
      'Outside',
      '2026-12-20',
      '2027-01-03'
    )
  $$,
  '23514',
  null,
  '假期不能超出学期'
);

select throws_ok(
  $$
    update public.terms
    set ends_on = '2026-11-01'
    where id = '93000000-0000-0000-0000-000000000003'
  $$,
  '23514',
  null,
  '修改学期不能排除已有假期'
);

update public.course_types
set is_private = true
where id = '93000000-0000-0000-0000-000000000005';

select is(
  (
    select format::text
    from public.courses
    where id = '93000000-0000-0000-0000-000000000013'
  ),
  'private_lesson',
  '课程种类改为私课后课程同步更新'
);

select throws_ok(
  $second_guardian$
    insert into public.guardian_students (
      organization_id,
      guardian_id,
      student_id,
      is_primary
    )
    values (
      '93000000-0000-0000-0000-000000000001',
      '93000000-0000-0000-0000-000000000011',
      '93000000-0000-0000-0000-000000000012',
      true
    )
  $second_guardian$,
  '23505',
  null,
  '一个学员不能同时属于两个监护人'
);

select is(
  (
    select count(*)
    from public.guardian_students
    where student_id = '93000000-0000-0000-0000-000000000012'
  ),
  1::bigint,
  '每个学员只有一条监护人关系'
);

select throws_ok(
  $missing_guardian$
    insert into public.students (
      id,
      organization_id,
      display_name,
      kind
    )
    values (
      '93000000-0000-0000-0000-000000000015',
      '93000000-0000-0000-0000-000000000001',
      'No Family',
      'child'
    )
  $missing_guardian$,
  '23502',
  null,
  '学员不能脱离监护人建立'
);

select set_config(
  'request.jwt.claim.sub',
  '93000000-0000-0000-0000-000000000002',
  true
);
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', '93000000-0000-0000-0000-000000000002',
    'role', 'authenticated'
  )::text,
  true
);

select throws_ok(
  $used_type$
    select public.admin_delete_record(
      'course_type',
      '93000000-0000-0000-0000-000000000005'
    )
  $used_type$,
  '23503',
  null,
  '已被课程使用的课程种类不能删除'
);

select lives_ok(
  $unused_type$
    select public.admin_delete_record(
      'course_type',
      '93000000-0000-0000-0000-000000000006'
    )
  $unused_type$,
  '未被使用的课程种类可以删除'
);

select is(
  (
    select count(*)
    from public.course_types
    where id = '93000000-0000-0000-0000-000000000006'
  ),
  0::bigint,
  '受控删除确实移除未关联资料'
);

select * from finish();

rollback;
