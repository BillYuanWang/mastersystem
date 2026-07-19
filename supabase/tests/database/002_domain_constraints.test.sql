begin;

create extension if not exists pgtap with schema extensions;

select plan(6);

insert into public.organizations (id, name, slug, timezone)
values (
  '90000000-0000-0000-0000-000000000001',
  'Constraint Test School',
  'constraint-test-school',
  'America/Los_Angeles'
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
  '90000000-0000-0000-0000-000000000002',
  '90000000-0000-0000-0000-000000000001',
  'Test Term',
  '2026-08-01',
  '2026-12-31',
  'open'
);

insert into public.term_holidays (
  organization_id,
  term_id,
  name,
  starts_on,
  ends_on
)
values (
  '90000000-0000-0000-0000-000000000001',
  '90000000-0000-0000-0000-000000000002',
  'Test Break',
  '2026-11-23',
  '2026-11-29'
);

select lives_ok(
  $$
    insert into public.course_categories (id, organization_id, name)
    values
      (
        '90000000-0000-0000-0000-000000000003',
        '90000000-0000-0000-0000-000000000001',
        'Any Custom Category'
      ),
      (
        '90000000-0000-0000-0000-000000000004',
        '90000000-0000-0000-0000-000000000001',
        'Another Custom Category'
      )
  $$,
  'course categories are user-defined records'
);

insert into public.age_groups (id, organization_id, name)
values (
  '90000000-0000-0000-0000-000000000005',
  '90000000-0000-0000-0000-000000000001',
  'Any Custom Age Group'
);

insert into public.rooms (id, organization_id, name)
values
  (
    '90000000-0000-0000-0000-000000000006',
    '90000000-0000-0000-0000-000000000001',
    'Room A'
  ),
  (
    '90000000-0000-0000-0000-000000000007',
    '90000000-0000-0000-0000-000000000001',
    'Room B'
  );

insert into public.instructors (id, organization_id, display_name)
values
  (
    '90000000-0000-0000-0000-000000000008',
    '90000000-0000-0000-0000-000000000001',
    'Teacher A'
  ),
  (
    '90000000-0000-0000-0000-000000000009',
    '90000000-0000-0000-0000-000000000001',
    'Teacher B'
  );

insert into public.course_types (id, organization_id, name, is_private)
values (
  '90000000-0000-0000-0000-000000000013',
  '90000000-0000-0000-0000-000000000001',
  'Custom Group',
  false
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
  '90000000-0000-0000-0000-000000000010',
  '90000000-0000-0000-0000-000000000001',
  '90000000-0000-0000-0000-000000000002',
  'Constraint Test Course',
  '90000000-0000-0000-0000-000000000003',
  '90000000-0000-0000-0000-000000000005',
  '90000000-0000-0000-0000-000000000006',
  '90000000-0000-0000-0000-000000000008',
  '90000000-0000-0000-0000-000000000013',
  'group'
);

insert into public.class_sessions (
  id,
  organization_id,
  course_id,
  starts_at,
  ends_at
)
values (
  '90000000-0000-0000-0000-000000000011',
  '90000000-0000-0000-0000-000000000001',
  '90000000-0000-0000-0000-000000000010',
  '2026-09-01 16:00:00-07',
  '2026-09-01 17:00:00-07'
);

select throws_ok(
  $$
    insert into public.class_sessions (
      organization_id,
      course_id,
      starts_at,
      ends_at,
      instructor_override_id
    )
    values (
      '90000000-0000-0000-0000-000000000001',
      '90000000-0000-0000-0000-000000000010',
      '2026-09-01 16:30:00-07',
      '2026-09-01 17:30:00-07',
      '90000000-0000-0000-0000-000000000009'
    )
  $$,
  '23P01',
  null,
  'overlapping sessions cannot use the same room'
);

select throws_ok(
  $$
    insert into public.class_sessions (
      organization_id,
      course_id,
      starts_at,
      ends_at,
      room_override_id
    )
    values (
      '90000000-0000-0000-0000-000000000001',
      '90000000-0000-0000-0000-000000000010',
      '2026-09-01 16:30:00-07',
      '2026-09-01 17:30:00-07',
      '90000000-0000-0000-0000-000000000007'
    )
  $$,
  '23P01',
  null,
  'an instructor cannot teach overlapping sessions'
);

select throws_ok(
  $$
    insert into public.class_sessions (
      organization_id,
      course_id,
      starts_at,
      ends_at
    )
    values (
      '90000000-0000-0000-0000-000000000001',
      '90000000-0000-0000-0000-000000000010',
      '2027-01-05 16:00:00-08',
      '2027-01-05 17:00:00-08'
    )
  $$,
  '23514',
  null,
  'sessions must stay inside their term'
);

insert into public.guardians (id, organization_id, display_name)
values (
  '90000000-0000-0000-0000-000000000014',
  '90000000-0000-0000-0000-000000000001',
  'Test Family'
);

insert into public.students (
  id,
  organization_id,
  guardian_id,
  display_name,
  kind
)
values (
  '90000000-0000-0000-0000-000000000012',
  '90000000-0000-0000-0000-000000000001',
  '90000000-0000-0000-0000-000000000014',
  'Test Student',
  'child'
);

insert into public.enrollments (
  organization_id,
  term_id,
  course_id,
  student_id
)
values (
  '90000000-0000-0000-0000-000000000001',
  '90000000-0000-0000-0000-000000000002',
  '90000000-0000-0000-0000-000000000010',
  '90000000-0000-0000-0000-000000000012'
);

select throws_ok(
  $$
    insert into public.enrollments (
      organization_id,
      term_id,
      course_id,
      student_id
    )
    values (
      '90000000-0000-0000-0000-000000000001',
      '90000000-0000-0000-0000-000000000002',
      '90000000-0000-0000-0000-000000000010',
      '90000000-0000-0000-0000-000000000012'
    )
  $$,
  '23505',
  null,
  'a student cannot be enrolled in one course twice'
);

select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and column_name ~ '(price|payment|credit|package)'
  ),
  'pricing and flexible-registration fields are outside this release'
);

select * from finish();

rollback;
