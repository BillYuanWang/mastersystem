begin;

insert into public.organizations (
  id,
  name,
  slug,
  timezone
)
values (
  '00000000-0000-0000-0000-000000000001',
  'Master Dance',
  'master-dance',
  'America/Los_Angeles'
)
on conflict (id) do nothing;

insert into public.terms (
  id,
  organization_id,
  name,
  starts_on,
  ends_on,
  status
)
values (
  '10000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '2026 秋季演示学期',
  '2026-08-17',
  '2026-12-20',
  'open'
)
on conflict (id) do nothing;

insert into public.term_holidays (
  id,
  organization_id,
  term_id,
  name,
  starts_on,
  ends_on
)
values (
  '15000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '感恩节周',
  '2026-11-23',
  '2026-11-29'
)
on conflict (id) do nothing;

insert into public.course_categories (id, organization_id, name)
values
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '芭蕾'),
  ('20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', '中国舞'),
  ('20000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', '基本功')
on conflict (id) do nothing;

insert into public.age_groups (id, organization_id, name)
values
  ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '5-7 岁'),
  ('30000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', '7-12 岁'),
  ('30000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', '成人')
on conflict (id) do nothing;

insert into public.rooms (id, organization_id, name)
values
  ('40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '大教室'),
  ('40000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', '小教室')
on conflict (id) do nothing;

insert into public.instructors (id, organization_id, display_name)
values
  ('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '林老师'),
  ('50000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', '王老师'),
  ('50000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', '陈老师')
on conflict (id) do nothing;

insert into public.course_types (id, organization_id, name, is_private)
values
  ('55000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '大组课', false),
  ('55000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', '小组课', false),
  ('55000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', '私课', true)
on conflict (id) do nothing;

insert into public.courses (
  id,
  organization_id,
  term_id,
  name,
  category_id,
  age_group_id,
  course_type_id,
  default_room_id,
  default_instructor_id,
  format
)
values
  (
    '60000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    '芭蕾基础',
    '20000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000002',
    '55000000-0000-0000-0000-000000000001',
    '40000000-0000-0000-0000-000000000001',
    '50000000-0000-0000-0000-000000000001',
    'group'
  ),
  (
    '60000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    '中国舞初级',
    '20000000-0000-0000-0000-000000000002',
    '30000000-0000-0000-0000-000000000001',
    '55000000-0000-0000-0000-000000000002',
    '40000000-0000-0000-0000-000000000002',
    '50000000-0000-0000-0000-000000000002',
    'group'
  ),
  (
    '60000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    '技巧私教',
    '20000000-0000-0000-0000-000000000003',
    '30000000-0000-0000-0000-000000000002',
    '55000000-0000-0000-0000-000000000003',
    '40000000-0000-0000-0000-000000000002',
    '50000000-0000-0000-0000-000000000003',
    'private_lesson'
  )
on conflict (id) do nothing;

insert into public.class_sessions (
  organization_id,
  course_id,
  starts_at,
  ends_at,
  effective_instructor_id,
  effective_room_id
)
select
  '00000000-0000-0000-0000-000000000001',
  '60000000-0000-0000-0000-000000000001',
  (session_date::date + time '16:00') at time zone 'America/Los_Angeles',
  (session_date::date + time '17:15') at time zone 'America/Los_Angeles',
  '50000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001'
from generate_series(
  date '2026-08-17',
  date '2026-12-14',
  interval '7 days'
) as session_date
on conflict (course_id, starts_at) do nothing;

insert into public.class_sessions (
  organization_id,
  course_id,
  starts_at,
  ends_at,
  effective_instructor_id,
  effective_room_id
)
select
  '00000000-0000-0000-0000-000000000001',
  '60000000-0000-0000-0000-000000000002',
  (session_date::date + time '16:15') at time zone 'America/Los_Angeles',
  (session_date::date + time '17:15') at time zone 'America/Los_Angeles',
  '50000000-0000-0000-0000-000000000002',
  '40000000-0000-0000-0000-000000000002'
from generate_series(
  date '2026-08-17',
  date '2026-12-14',
  interval '7 days'
) as session_date
on conflict (course_id, starts_at) do nothing;

insert into public.class_sessions (
  organization_id,
  course_id,
  starts_at,
  ends_at,
  effective_instructor_id,
  effective_room_id
)
select
  '00000000-0000-0000-0000-000000000001',
  '60000000-0000-0000-0000-000000000003',
  (session_date::date + time '17:30') at time zone 'America/Los_Angeles',
  (session_date::date + time '18:30') at time zone 'America/Los_Angeles',
  '50000000-0000-0000-0000-000000000003',
  '40000000-0000-0000-0000-000000000002'
from generate_series(
  date '2026-08-20',
  date '2026-12-17',
  interval '7 days'
) as session_date
on conflict (course_id, starts_at) do nothing;

insert into public.guardians (
  id,
  organization_id,
  display_name,
  email
)
values
  (
    '80000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    '演示家长',
    'guardian@example.com'
  )
on conflict (id) do nothing;

insert into public.students (
  id,
  organization_id,
  guardian_id,
  display_name,
  kind
)
values
  (
    '70000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    '80000000-0000-0000-0000-000000000001',
    '演示学生一',
    'child'
  ),
  (
    '70000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000001',
    '80000000-0000-0000-0000-000000000001',
    '演示学生二',
    'child'
  ),
  (
    '70000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000001',
    '80000000-0000-0000-0000-000000000001',
    '演示成人学员',
    'adult'
  )
on conflict (id) do nothing;

insert into public.enrollments (
  id,
  organization_id,
  term_id,
  course_id,
  student_id,
  registration_mode,
  enrolled_at
)
values
  (
    '90000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    '60000000-0000-0000-0000-000000000001',
    '70000000-0000-0000-0000-000000000001',
    'full_term',
    '2026-08-01T12:00:00Z'
  ),
  (
    '90000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    '60000000-0000-0000-0000-000000000002',
    '70000000-0000-0000-0000-000000000002',
    'full_term',
    '2026-08-01T12:00:00Z'
  ),
  (
    '90000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    '60000000-0000-0000-0000-000000000003',
    '70000000-0000-0000-0000-000000000003',
    'per_session',
    '2026-08-01T12:00:00Z'
  )
on conflict (id) do nothing;

insert into public.enrollment_session_selections (
  organization_id,
  enrollment_id,
  course_id,
  session_id
)
select
  '00000000-0000-0000-0000-000000000001',
  '90000000-0000-0000-0000-000000000003',
  '60000000-0000-0000-0000-000000000003',
  session.id
from public.class_sessions session
where session.course_id = '60000000-0000-0000-0000-000000000003'
  and session.status <> 'cancelled'
on conflict (enrollment_id, session_id) do nothing;

insert into public.contract_documents (
  id,
  organization_id,
  term_id,
  version,
  title,
  storage_path,
  body_text,
  status
)
values (
  'a0000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '2026-fall-draft',
  '2026 秋季课程协议（演示草稿）',
  '00000000-0000-0000-0000-000000000001/10000000-0000-0000-0000-000000000001/2026-fall-draft.pdf',
  '这是用于本地 Supabase 测试的演示合同正文，不会发布给真实学员或监护人。',
  'draft'
)
on conflict (id) do nothing;

commit;
