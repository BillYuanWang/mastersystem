begin;

create extension if not exists pgtap with schema extensions;

select plan(20);

select ok(
  not has_table_privilege('authenticated', 'public.terms', 'DELETE')
  and not has_table_privilege('authenticated', 'public.term_holidays', 'DELETE')
  and not has_table_privilege('authenticated', 'public.courses', 'DELETE')
  and not has_table_privilege('authenticated', 'public.students', 'DELETE')
  and not has_table_privilege('authenticated', 'public.guardians', 'DELETE')
  and has_table_privilege('authenticated', 'public.enrollments', 'DELETE')
  and has_table_privilege('authenticated', 'public.attendance', 'DELETE'),
  '主数据只能受控删除，报名和签到仍可撤销'
);

insert into public.organizations (id, name, slug, timezone)
values (
  '94000000-0000-0000-0000-000000000001',
  'Dependency School',
  'dependency-school',
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
  '94000000-0000-0000-0000-000000000002',
  'authenticated',
  'authenticated',
  'dependency-admin@example.test',
  now(),
  '{}'::jsonb,
  '{}'::jsonb,
  now(),
  now()
);

insert into public.profiles (user_id, organization_id, role, display_name)
values (
  '94000000-0000-0000-0000-000000000002',
  '94000000-0000-0000-0000-000000000001',
  'administrator',
  'Dependency Admin'
);

select set_config(
  'request.jwt.claim.sub',
  '94000000-0000-0000-0000-000000000002',
  true
);
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', '94000000-0000-0000-0000-000000000002',
    'role', 'authenticated'
  )::text,
  true
);

insert into public.course_categories (id, organization_id, name)
values (
  '94000000-0000-0000-0000-000000000004',
  '94000000-0000-0000-0000-000000000001',
  'System Default'
);

insert into public.course_types (id, organization_id, name, is_private)
values (
  '94000000-0000-0000-0000-000000000005',
  '94000000-0000-0000-0000-000000000001',
  'Group',
  false
);

insert into public.age_groups (id, organization_id, name)
values (
  '94000000-0000-0000-0000-000000000006',
  '94000000-0000-0000-0000-000000000001',
  'All Ages'
);

insert into public.rooms (id, organization_id, name)
values (
  '94000000-0000-0000-0000-000000000007',
  '94000000-0000-0000-0000-000000000001',
  'Studio'
);

insert into public.instructors (id, organization_id, display_name)
values (
  '94000000-0000-0000-0000-000000000008',
  '94000000-0000-0000-0000-000000000001',
  'Teacher'
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
  '94000000-0000-0000-0000-000000000003',
  '94000000-0000-0000-0000-000000000001',
  'Empty Term',
  '2026-08-01',
  '2026-12-31',
  'draft'
);

select throws_ok(
  $course_without_holiday$
    insert into public.courses (
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
      '94000000-0000-0000-0000-000000000001',
      '94000000-0000-0000-0000-000000000003',
      'Too Early',
      '94000000-0000-0000-0000-000000000004',
      '94000000-0000-0000-0000-000000000006',
      '94000000-0000-0000-0000-000000000007',
      '94000000-0000-0000-0000-000000000008',
      '94000000-0000-0000-0000-000000000005',
      'group'
    )
  $course_without_holiday$,
  '23514',
  null,
  '没有假期时不能创建课程'
);

select lives_ok(
  $add_holiday$
    insert into public.term_holidays (
      id,
      organization_id,
      term_id,
      name,
      starts_on,
      ends_on
    )
    values (
      '94000000-0000-0000-0000-000000000009',
      '94000000-0000-0000-0000-000000000001',
      '94000000-0000-0000-0000-000000000003',
      'Break',
      '2026-11-23',
      '2026-11-29'
    )
  $add_holiday$,
  '先有学期即可创建假期'
);

select throws_ok(
  $term_with_holiday$
    select public.admin_delete_record(
      'term',
      '94000000-0000-0000-0000-000000000003'
    )
  $term_with_holiday$,
  '23503',
  null,
  '有假期的学期不能删除'
);

select lives_ok(
  $add_course$
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
      '94000000-0000-0000-0000-000000000010',
      '94000000-0000-0000-0000-000000000001',
      '94000000-0000-0000-0000-000000000003',
      'Technique',
      '94000000-0000-0000-0000-000000000004',
      '94000000-0000-0000-0000-000000000006',
      '94000000-0000-0000-0000-000000000007',
      '94000000-0000-0000-0000-000000000008',
      '94000000-0000-0000-0000-000000000005',
      'group'
    )
  $add_course$,
  '配置假期后可以创建课程'
);

select throws_ok(
  $holiday_with_course$
    select public.admin_delete_record(
      'term_holiday',
      '94000000-0000-0000-0000-000000000009'
    )
  $holiday_with_course$,
  '23503',
  null,
  '学期已有课程时不能删除假期'
);

select lives_ok(
  $add_session$
    insert into public.class_sessions (
      id,
      organization_id,
      course_id,
      starts_at,
      ends_at,
      effective_instructor_id,
      effective_room_id
    )
    values (
      '94000000-0000-0000-0000-000000000011',
      '94000000-0000-0000-0000-000000000001',
      '94000000-0000-0000-0000-000000000010',
      '2026-09-01 16:00:00-07',
      '2026-09-01 17:00:00-07',
      '94000000-0000-0000-0000-000000000008',
      '94000000-0000-0000-0000-000000000007'
    )
  $add_session$,
  '课程可以生成课次'
);

select lives_ok(
  $delete_empty_course$
    select public.admin_delete_record(
      'course',
      '94000000-0000-0000-0000-000000000010'
    )
  $delete_empty_course$,
  '没有业务记录的课程可以连同自动课次撤销'
);

select is(
  (
    select count(*) from public.courses
    where id = '94000000-0000-0000-0000-000000000010'
  ),
  0::bigint,
  '空课程已删除'
);

select is(
  (
    select count(*) from public.class_sessions
    where id = '94000000-0000-0000-0000-000000000011'
  ),
  0::bigint,
  '空课程的派生课次一并删除'
);

select lives_ok(
  $delete_holiday_after_course$
    select public.admin_delete_record(
      'term_holiday',
      '94000000-0000-0000-0000-000000000009'
    )
  $delete_holiday_after_course$,
  '课程撤销后可以删除假期'
);

select lives_ok(
  $delete_term_last$
    select public.admin_delete_record(
      'term',
      '94000000-0000-0000-0000-000000000003'
    )
  $delete_term_last$,
  '下游资料全部撤销后可以删除学期'
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
  '94000000-0000-0000-0000-000000000012',
  '94000000-0000-0000-0000-000000000001',
  'Enrollment Term',
  '2027-01-01',
  '2027-05-31',
  'draft'
);

insert into public.term_holidays (
  id,
  organization_id,
  term_id,
  name,
  starts_on,
  ends_on
)
values (
  '94000000-0000-0000-0000-000000000013',
  '94000000-0000-0000-0000-000000000001',
  '94000000-0000-0000-0000-000000000012',
  'Spring Break',
  '2027-03-22',
  '2027-03-28'
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
  '94000000-0000-0000-0000-000000000014',
  '94000000-0000-0000-0000-000000000001',
  '94000000-0000-0000-0000-000000000012',
  'Enrolled Course',
  '94000000-0000-0000-0000-000000000004',
  '94000000-0000-0000-0000-000000000006',
  '94000000-0000-0000-0000-000000000007',
  '94000000-0000-0000-0000-000000000008',
  '94000000-0000-0000-0000-000000000005',
  'group'
);

insert into public.guardians (id, organization_id, display_name)
values (
  '94000000-0000-0000-0000-000000000015',
  '94000000-0000-0000-0000-000000000001',
  'Family'
);

insert into public.students (
  id,
  organization_id,
  guardian_id,
  display_name,
  kind
)
values (
  '94000000-0000-0000-0000-000000000016',
  '94000000-0000-0000-0000-000000000001',
  '94000000-0000-0000-0000-000000000015',
  'Student',
  'child'
);

insert into public.enrollments (
  id,
  organization_id,
  term_id,
  course_id,
  student_id
)
values (
  '94000000-0000-0000-0000-000000000017',
  '94000000-0000-0000-0000-000000000001',
  '94000000-0000-0000-0000-000000000012',
  '94000000-0000-0000-0000-000000000014',
  '94000000-0000-0000-0000-000000000016'
);

select throws_ok(
  $course_with_enrollment$
    select public.admin_delete_record(
      'course',
      '94000000-0000-0000-0000-000000000014'
    )
  $course_with_enrollment$,
  '23503',
  null,
  '有报名的课程不能删除'
);

select lives_ok(
  $remove_enrollment$
    delete from public.enrollments
    where id = '94000000-0000-0000-0000-000000000017'
  $remove_enrollment$,
  '报名可以撤销'
);

select lives_ok(
  $remove_course_after_enrollment$
    select public.admin_delete_record(
      'course',
      '94000000-0000-0000-0000-000000000014'
    )
  $remove_course_after_enrollment$,
  '报名撤销后课程可以删除'
);

select lives_ok(
  $remove_second_holiday$
    select public.admin_delete_record(
      'term_holiday',
      '94000000-0000-0000-0000-000000000013'
    )
  $remove_second_holiday$,
  '课程删除后假期可以删除'
);

select lives_ok(
  $remove_second_term$
    select public.admin_delete_record(
      'term',
      '94000000-0000-0000-0000-000000000012'
    )
  $remove_second_term$,
  '依赖逆序撤销后学期可以删除'
);

select lives_ok(
  $remove_empty_family$
    select public.admin_delete_guardian_household(
      '94000000-0000-0000-0000-000000000015'
    )
  $remove_empty_family$,
  '没有业务记录的家庭可以连同空学员档案一起删除'
);

select is(
  (
    select count(*)
    from public.students
    where guardian_id = '94000000-0000-0000-0000-000000000015'
  ),
  0::bigint,
  '家庭删除后不残留空学员档案'
);

select is(
  (
    select count(*)
    from public.guardians
    where id = '94000000-0000-0000-0000-000000000015'
  ),
  0::bigint,
  '家庭记录已删除'
);

select * from finish();

rollback;
