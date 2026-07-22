begin;

create extension if not exists pgtap with schema extensions;

select plan(7);

select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.courses'::regclass
      and conname = 'courses_pricing_state_consistency'
  ),
  'course pricing distinguishes group and private lesson prices'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_trigger
    where tgrelid = 'public.enrollments'::regclass
      and tgname = 'enrollments_private_lesson_mode_guard'
      and not tgisinternal
  ),
  'private lesson enrollment mode is enforced by a database trigger'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_trigger
    where tgrelid = 'public.courses'::regclass
      and tgname = 'courses_private_lesson_transition_guard'
      and not tgisinternal
  ),
  'course conversion cannot leave full-term private enrollments behind'
);

insert into public.organizations (id, name, slug, timezone)
values (
  '91000000-0000-0000-0000-000000000001',
  'Private Lesson Test School',
  'private-lesson-test-school',
  'America/Los_Angeles'
);

insert into public.terms (id, organization_id, name, starts_on, ends_on, status)
values (
  '91000000-0000-0000-0000-000000000002',
  '91000000-0000-0000-0000-000000000001',
  'Private Lesson Test Term',
  '2026-08-01',
  '2026-12-31',
  'open'
);

insert into public.term_holidays (organization_id, term_id, name, starts_on, ends_on)
values (
  '91000000-0000-0000-0000-000000000001',
  '91000000-0000-0000-0000-000000000002',
  'Test Break',
  '2026-11-23',
  '2026-11-29'
);

insert into public.course_categories (id, organization_id, name)
values (
  '91000000-0000-0000-0000-000000000003',
  '91000000-0000-0000-0000-000000000001',
  'Test Category'
);

insert into public.age_groups (id, organization_id, name)
values (
  '91000000-0000-0000-0000-000000000004',
  '91000000-0000-0000-0000-000000000001',
  'Test Age Group'
);

insert into public.rooms (id, organization_id, name)
values (
  '91000000-0000-0000-0000-000000000005',
  '91000000-0000-0000-0000-000000000001',
  'Test Room'
);

insert into public.instructors (id, organization_id, display_name)
values (
  '91000000-0000-0000-0000-000000000006',
  '91000000-0000-0000-0000-000000000001',
  'Test Teacher'
);

insert into public.course_types (id, organization_id, name, is_private)
values
  (
    '91000000-0000-0000-0000-000000000007',
    '91000000-0000-0000-0000-000000000001',
    'Private Lesson',
    true
  ),
  (
    '91000000-0000-0000-0000-000000000008',
    '91000000-0000-0000-0000-000000000001',
    'Group Lesson',
    false
  );

select lives_ok(
  $$
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
      format,
      pricing_status,
      unit_price_cents,
      drop_in_unit_price_cents
    ) values (
      '91000000-0000-0000-0000-000000000009',
      '91000000-0000-0000-0000-000000000001',
      '91000000-0000-0000-0000-000000000002',
      'Priced Private Lesson',
      '91000000-0000-0000-0000-000000000003',
      '91000000-0000-0000-0000-000000000004',
      '91000000-0000-0000-0000-000000000005',
      '91000000-0000-0000-0000-000000000006',
      '91000000-0000-0000-0000-000000000007',
      'private_lesson',
      'priced',
      null,
      8000
    )
  $$,
  'a private lesson is priced only by its per-session price'
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
) values (
  '91000000-0000-0000-0000-000000000010',
  '91000000-0000-0000-0000-000000000001',
  '91000000-0000-0000-0000-000000000002',
  'Group Lesson',
  '91000000-0000-0000-0000-000000000003',
  '91000000-0000-0000-0000-000000000004',
  '91000000-0000-0000-0000-000000000005',
  '91000000-0000-0000-0000-000000000006',
  '91000000-0000-0000-0000-000000000008',
  'group'
);

insert into public.class_sessions (id, organization_id, course_id, starts_at, ends_at)
values (
  '91000000-0000-0000-0000-000000000011',
  '91000000-0000-0000-0000-000000000001',
  '91000000-0000-0000-0000-000000000009',
  '2026-09-01 16:00:00-07',
  '2026-09-01 17:00:00-07'
);

insert into public.guardians (id, organization_id, display_name)
values (
  '91000000-0000-0000-0000-000000000012',
  '91000000-0000-0000-0000-000000000001',
  'Test Family'
);

insert into public.students (id, organization_id, guardian_id, display_name, kind)
values (
  '91000000-0000-0000-0000-000000000013',
  '91000000-0000-0000-0000-000000000001',
  '91000000-0000-0000-0000-000000000012',
  'Test Student',
  'child'
);

select throws_ok(
  $$
    insert into public.enrollments (
      organization_id,
      term_id,
      course_id,
      student_id,
      registration_mode
    ) values (
      '91000000-0000-0000-0000-000000000001',
      '91000000-0000-0000-0000-000000000002',
      '91000000-0000-0000-0000-000000000009',
      '91000000-0000-0000-0000-000000000013',
      'full_term'
    )
  $$,
  '23514',
  null,
  'a private lesson rejects full-term enrollment'
);

select lives_ok(
  $$
    do $block$
    begin
      insert into public.enrollments (
        id,
        organization_id,
        term_id,
        course_id,
        student_id,
        registration_mode
      ) values (
        '91000000-0000-0000-0000-000000000014',
        '91000000-0000-0000-0000-000000000001',
        '91000000-0000-0000-0000-000000000002',
        '91000000-0000-0000-0000-000000000009',
        '91000000-0000-0000-0000-000000000013',
        'per_session'
      );

      insert into public.enrollment_session_selections (
        organization_id,
        enrollment_id,
        course_id,
        session_id
      ) values (
        '91000000-0000-0000-0000-000000000001',
        '91000000-0000-0000-0000-000000000014',
        '91000000-0000-0000-0000-000000000009',
        '91000000-0000-0000-0000-000000000011'
      );
    end
    $block$
  $$,
  'a private lesson accepts selected per-session enrollment'
);

select lives_ok(
  $$
    insert into public.enrollments (
      organization_id,
      term_id,
      course_id,
      student_id,
      registration_mode
    ) values (
      '91000000-0000-0000-0000-000000000001',
      '91000000-0000-0000-0000-000000000002',
      '91000000-0000-0000-0000-000000000010',
      '91000000-0000-0000-0000-000000000013',
      'full_term'
    )
  $$,
  'group courses continue to support full-term enrollment'
);

select * from finish();

rollback;
