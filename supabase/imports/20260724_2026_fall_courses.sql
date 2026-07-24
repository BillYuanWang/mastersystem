-- Master Dance 2026 Fall approved timetable import.
--
-- Confirmed import rules:
-- - preserve courses already present at the same room, weekday, and time;
-- - skip the two weekend courses marked as temporary adjustments;
-- - do not import any prices;
-- - use the technical "未设置" age group when the source has no age range;
-- - generate 17 weekly sessions per new course, excluding term holidays.
--
-- This script is idempotent. It aborts and rolls back on missing reference data,
-- room/instructor conflicts, or an unexpected session count.

begin;

create temp table md_course_import_source (
  source_key text primary key,
  course_name text not null,
  iso_weekday integer not null check (iso_weekday between 1 and 7),
  starts_local time not null,
  ends_local time not null,
  room_name text not null,
  instructor_name text not null,
  age_group_name text,
  course_type_name text not null
) on commit drop;

insert into md_course_import_source (
  source_key,
  course_name,
  iso_weekday,
  starts_local,
  ends_local,
  room_name,
  instructor_name,
  age_group_name,
  course_type_name
)
values
  ('mon-basic-1530', '中国舞基本功', 1, '15:30', '16:30', '大教室', '蔡京', '7-9 岁', '大组课'),
  ('mon-modern-1600', '青少年现代舞基础', 1, '16:00', '17:30', '小教室', '林凡', '8 岁以上', '大组课'),
  ('mon-team-1630', '比赛 Team 专属排舞课', 1, '16:30', '17:30', '大教室', '蔡京', '7-9 岁', '大组课'),
  ('mon-acro-1730', '舞蹈空翻课', 1, '17:30', '18:30', '小教室', '贾斯蒂斯', null, '大组课'),
  ('tue-basic-1610', '中国舞基本功', 2, '16:10', '17:40', '大教室', '蔡京', '8-11 岁', '大组课'),
  ('tue-performance-1740', '中国舞表演课', 2, '17:40', '18:40', '大教室', '蔡京', '8-11 岁', '大组课'),
  ('wed-basic-1600', '中国舞基本功', 3, '16:00', '17:00', '大教室', '蔡京', '7-9 岁', '大组课'),
  ('wed-technique-1700', '中国舞技术技巧', 3, '17:00', '18:00', '大教室', '蔡京', '7-9 岁', '大组课'),
  ('wed-team-1800', '比赛 Team 专属排舞课', 3, '18:00', '19:00', '大教室', '蔡京', '7-9 岁', '大组课'),
  ('thu-basic-1610', '中国舞基本功', 4, '16:10', '17:10', '大教室', '蔡京', '8-11 岁', '大组课'),
  ('thu-technique-1710', '中国舞技术技巧', 4, '17:10', '18:10', '大教室', '蔡京', '8-11 岁', '大组课'),
  ('thu-team-1810', '比赛 Team 专属排舞课', 4, '18:10', '19:10', '大教室', '蔡京', '8-11 岁', '大组课'),
  ('fri-basic-advanced-1600', '中国舞基本功课提高班', 5, '16:00', '17:00', '大教室', '蔡京', '6-9 岁', '大组课'),
  ('fri-technique-advanced-1700', '中国舞技术技巧提高班', 5, '17:00', '18:00', '大教室', '蔡京', '6-9 岁', '大组课'),
  ('sat-intro-0930', '中国舞启蒙班', 6, '09:30', '10:30', '大教室', '王雅婷', '3-5岁', '大组课'),
  ('sat-basic-5-7-1030', '中国舞基本功课', 6, '10:30', '11:30', '大教室', '王雅婷', '5-7 岁', '大组课'),
  ('sat-performance-5-7-1130', '中国舞表演课', 6, '11:30', '12:30', '大教室', '王雅婷', '5-7 岁', '大组课'),
  ('sat-basic-7-9-1330', '中国舞基本功', 6, '13:30', '14:30', '大教室', '蔡京', '7-9 岁', '大组课'),
  ('sat-performance-7-9-1430', '中国舞表演课', 6, '14:30', '15:30', '大教室', '蔡京', '7-9 岁', '大组课'),
  ('sat-team-8-11-1545', '比赛 Team 专属排舞课', 6, '15:45', '16:45', '大教室', '蔡京', '8-11 岁', '大组课'),
  ('sat-basic-9-12-1745', '中国舞基本功', 6, '17:45', '18:45', '大教室', '蔡京', '9-12 岁', '大组课'),
  ('sat-small-basic-6-8-1030', '中国舞基本功', 6, '10:30', '11:30', '小教室', '蔡京', '6-8 岁', '大组课'),
  ('sat-ballet-7-9-1530', '芭蕾集训', 6, '15:30', '16:30', '小教室', '伊丽莎白', '7-9 岁', '大组课'),
  ('sat-ballet-8-11-1645', '芭蕾集训', 6, '16:45', '17:45', '小教室', '伊丽莎白', '8-11 岁', '大组课'),
  ('sat-ballet-private-1745', '芭蕾私课', 6, '17:45', '18:45', '小教室', '伊丽莎白', null, '单人私课'),
  ('sat-ballet-private-1845', '芭蕾私课', 6, '18:45', '19:45', '小教室', '伊丽莎白', null, '单人私课'),
  ('sun-basic-6-8-1000', '中国舞基本功', 7, '10:00', '11:00', '大教室', '蔡京', '6-8 岁', '大组课'),
  ('sun-private-1430', '私课', 7, '14:30', '16:00', '大教室', '蔡京', null, '单人私课'),
  ('sun-basic-12-15-1600', '中国舞基本功', 7, '16:00', '17:00', '大教室', '蔡京', '12-15 岁', '大组课'),
  ('sun-performance-12-15-1700', '中国舞表演课', 7, '17:00', '18:00', '大教室', '蔡京', '12-15 岁', '大组课'),
  ('sun-private-1800', '私课', 7, '18:00', '19:00', '大教室', '蔡京', null, '单人私课');

insert into public.age_groups (
  organization_id,
  name,
  notes
)
select
  '00000000-0000-0000-0000-000000000001'::uuid,
  '未设置',
  '原始课表未注明年龄段；待教务老师确认后补充。'
where not exists (
  select 1
  from public.age_groups
  where organization_id = '00000000-0000-0000-0000-000000000001'::uuid
    and lower(name) = lower('未设置')
);

create temp table md_course_import_resolved on commit drop as
select
  src.*,
  org.id as organization_id,
  org.timezone,
  term.id as term_id,
  term.starts_on as term_starts_on,
  term.ends_on as term_ends_on,
  category.id as category_id,
  age_group.id as age_group_id,
  room.id as room_id,
  instructor.id as instructor_id,
  course_type.id as course_type_id,
  course_type.is_private,
  md5('master-dance:2026-fall:course:' || src.source_key)::uuid as import_course_id
from md_course_import_source src
cross join public.organizations org
join public.terms term
  on term.organization_id = org.id
 and term.name = '2026年秋季学期'
join public.course_categories category
  on category.organization_id = org.id
 and category.name = '系统默认'
join public.age_groups age_group
  on age_group.organization_id = org.id
 and age_group.name = coalesce(src.age_group_name, '未设置')
join public.rooms room
  on room.organization_id = org.id
 and room.name = src.room_name
join public.instructors instructor
  on instructor.organization_id = org.id
 and instructor.display_name = src.instructor_name
join public.course_types course_type
  on course_type.organization_id = org.id
 and course_type.name = src.course_type_name
where org.id = '00000000-0000-0000-0000-000000000001'::uuid;

do $$
declare
  source_count integer;
  resolved_count integer;
begin
  select count(*) into source_count from md_course_import_source;
  select count(*) into resolved_count from md_course_import_resolved;

  if source_count <> 31 then
    raise exception 'Expected 31 source courses, found %', source_count;
  end if;

  if resolved_count <> source_count then
    raise exception 'Only % of % courses resolved to reference data', resolved_count, source_count;
  end if;
end
$$;

create temp table md_course_import_existing on commit drop as
select distinct on (candidate.source_key)
  candidate.source_key,
  existing_course.id as existing_course_id,
  existing_course.name as existing_course_name
from md_course_import_resolved candidate
join public.class_sessions existing_session
  on existing_session.organization_id = candidate.organization_id
 and existing_session.effective_room_id = candidate.room_id
 and extract(isodow from existing_session.starts_at at time zone candidate.timezone)::integer = candidate.iso_weekday
 and (existing_session.starts_at at time zone candidate.timezone)::time = candidate.starts_local
 and (existing_session.ends_at at time zone candidate.timezone)::time = candidate.ends_local
join public.courses existing_course
  on existing_course.id = existing_session.course_id
 and existing_course.term_id = candidate.term_id
order by candidate.source_key, existing_course.created_at;

do $$
begin
  if exists (
    select 1
    from md_course_import_resolved candidate
    join public.class_sessions existing_session
      on existing_session.organization_id = candidate.organization_id
     and extract(isodow from existing_session.starts_at at time zone candidate.timezone)::integer = candidate.iso_weekday
     and (existing_session.starts_at at time zone candidate.timezone)::time < candidate.ends_local
     and (existing_session.ends_at at time zone candidate.timezone)::time > candidate.starts_local
    join public.courses existing_course
      on existing_course.id = existing_session.course_id
     and existing_course.term_id = candidate.term_id
    left join md_course_import_existing exact_match
      on exact_match.source_key = candidate.source_key
    where exact_match.source_key is null
      and (
        existing_session.effective_room_id = candidate.room_id
        or existing_session.effective_instructor_id = candidate.instructor_id
      )
  ) then
    raise exception 'Import stopped: at least one new course overlaps an existing room or instructor schedule';
  end if;

  if exists (
    select 1
    from md_course_import_resolved left_course
    join md_course_import_resolved right_course
      on left_course.source_key < right_course.source_key
     and left_course.iso_weekday = right_course.iso_weekday
     and left_course.starts_local < right_course.ends_local
     and left_course.ends_local > right_course.starts_local
     and (
       left_course.room_id = right_course.room_id
       or left_course.instructor_id = right_course.instructor_id
     )
  ) then
    raise exception 'Import stopped: source timetable contains a room or instructor overlap';
  end if;
end
$$;

create temp table md_course_import_new on commit drop as
select candidate.*
from md_course_import_resolved candidate
left join md_course_import_existing existing
  on existing.source_key = candidate.source_key
where existing.source_key is null;

insert into public.courses (
  id,
  organization_id,
  term_id,
  name,
  category_id,
  age_group_id,
  default_room_id,
  default_instructor_id,
  format,
  notes,
  course_type_id,
  is_active,
  pricing_status,
  unit_price_cents,
  drop_in_unit_price_cents
)
select
  import_course_id,
  organization_id,
  term_id,
  course_name,
  category_id,
  age_group_id,
  room_id,
  instructor_id,
  case when is_private then 'private_lesson' else 'group' end::public.course_format,
  '从《临时课表》导入；价格待确认。',
  course_type_id,
  true,
  'pending'::public.course_pricing_status,
  null,
  null
from md_course_import_new
on conflict (id) do nothing;

insert into public.class_sessions (
  id,
  organization_id,
  course_id,
  starts_at,
  ends_at,
  effective_instructor_id,
  effective_room_id,
  status
)
select
  md5(
    'master-dance:2026-fall:session:'
    || candidate.source_key
    || ':'
    || session_date::date::text
  )::uuid,
  candidate.organization_id,
  candidate.import_course_id,
  (session_date::date + candidate.starts_local) at time zone candidate.timezone,
  (session_date::date + candidate.ends_local) at time zone candidate.timezone,
  candidate.instructor_id,
  candidate.room_id,
  'scheduled'::public.class_session_status
from md_course_import_new candidate
cross join lateral generate_series(
  candidate.term_starts_on::timestamp,
  candidate.term_ends_on::timestamp,
  interval '1 day'
) session_date
where extract(isodow from session_date)::integer = candidate.iso_weekday
  and not exists (
    select 1
    from public.term_holidays holiday
    where holiday.term_id = candidate.term_id
      and session_date::date between holiday.starts_on and holiday.ends_on
  )
  and exists (
    select 1
    from public.courses inserted_course
    where inserted_course.id = candidate.import_course_id
  )
on conflict (course_id, starts_at) do nothing;

do $$
begin
  if exists (
    select 1
    from md_course_import_new candidate
    left join public.courses course
      on course.id = candidate.import_course_id
    left join lateral (
      select count(*)::integer as session_count
      from public.class_sessions session
      where session.course_id = candidate.import_course_id
    ) counts on true
    where course.id is null
       or counts.session_count <> 17
  ) then
    raise exception 'Import verification failed: every new course must have exactly 17 sessions';
  end if;
end
$$;

select jsonb_build_object(
  'source_courses', (select count(*) from md_course_import_source),
  'preserved_existing_courses', (select count(*) from md_course_import_existing),
  'inserted_courses', (select count(*) from md_course_import_new),
  'inserted_sessions', (
    select count(*)
    from public.class_sessions session
    join md_course_import_new candidate
      on candidate.import_course_id = session.course_id
  ),
  'unpriced_new_courses', (
    select count(*)
    from public.courses course
    join md_course_import_new candidate
      on candidate.import_course_id = course.id
    where course.pricing_status = 'pending'
      and course.unit_price_cents is null
      and course.drop_in_unit_price_cents is null
  )
) as import_result;

commit;
