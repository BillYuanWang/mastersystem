-- Align the 2026 Fall timetable with the schedules sent by Hua Hua on WeChat.
--
-- Source-of-truth rules for this migration:
-- - apply only changes that are unambiguous in the new images;
-- - preserve all existing prices until the school confirms a separate price import;
-- - keep ambiguous adult 15-week dates and the conflicting Sunday child times
--   out of class_sessions until an administrator confirms them.

begin;

do $$
declare
  organization_id_value constant uuid := '00000000-0000-0000-0000-000000000001'::uuid;
  term_id_value uuid;
  age_6_9_id uuid;
  age_6_8_id uuid;
  adult_age_id uuid;
  big_room_id uuid;
  small_room_id uuid;
  cai_jing_id uuid;
  wang_yating_id uuid;
  lin_fan_id uuid;
  category_id_value uuid;
  group_course_type_id uuid;
  timezone_value text;
  saturday_performance_course_id constant uuid := md5(
    'master-dance:2026-fall:course:sat-small-performance-6-8-1100'
  )::uuid;
  candidate_count integer;
begin
  perform pg_advisory_xact_lock(hashtext('master-dance:2026-fall:wechat-timetable'));

  select term.id, organization.timezone
  into term_id_value, timezone_value
  from public.terms term
  join public.organizations organization
    on organization.id = term.organization_id
  where term.organization_id = organization_id_value
    and term.name = '2026年秋季学期';

  select id into age_6_9_id
  from public.age_groups
  where organization_id = organization_id_value and name = '6-9 岁';

  select id into age_6_8_id
  from public.age_groups
  where organization_id = organization_id_value and name = '6-8 岁';

  select id into adult_age_id
  from public.age_groups
  where organization_id = organization_id_value and name = '成人';

  select id into big_room_id
  from public.rooms
  where organization_id = organization_id_value and name = '大教室';

  select id into small_room_id
  from public.rooms
  where organization_id = organization_id_value and name = '小教室';

  select id into cai_jing_id
  from public.instructors
  where organization_id = organization_id_value and display_name = '蔡京';

  select id into wang_yating_id
  from public.instructors
  where organization_id = organization_id_value and display_name = '王雅婷';

  select id into lin_fan_id
  from public.instructors
  where organization_id = organization_id_value and display_name = '林凡';

  select id into category_id_value
  from public.course_categories
  where organization_id = organization_id_value and name = '系统默认';

  select id into group_course_type_id
  from public.course_types
  where organization_id = organization_id_value and name = '大组课';

  if term_id_value is null
     or timezone_value is null
     or age_6_9_id is null
     or age_6_8_id is null
     or adult_age_id is null
     or big_room_id is null
     or small_room_id is null
     or cai_jing_id is null
     or wang_yating_id is null
     or lin_fan_id is null
     or category_id_value is null
     or group_course_type_id is null then
    raise notice 'WeChat timetable alignment skipped: this database does not contain the production term and reference data';
    return;
  end if;

  if (
    select count(*)
    from public.courses
    where organization_id = organization_id_value
      and term_id = term_id_value
      and id in (
        'AF0684BF-C3EC-4D1C-A4A9-29BF9DDB4A67'::uuid,
        '27439BC0-797A-4DDA-9CC2-D417F247240B'::uuid,
        '32FFECC5-A4DD-359D-AAF5-F663658003A1'::uuid,
        'B80FD74B-127B-E8F8-7CCF-23C6B7499A78'::uuid,
        'CA4A920A-4188-E855-6FA9-6E4EA1F0A7DA'::uuid,
        '579424AF-1A2D-7A22-926E-4CF229561AD0'::uuid
      )
  ) <> 6 then
    raise exception 'WeChat timetable alignment stopped: expected child courses are missing';
  end if;

  if exists (
    select 1
    from public.enrollments enrollment
    where enrollment.organization_id = organization_id_value
      and enrollment.course_id in (
        '32FFECC5-A4DD-359D-AAF5-F663658003A1'::uuid,
        'B80FD74B-127B-E8F8-7CCF-23C6B7499A78'::uuid,
        '579424AF-1A2D-7A22-926E-4CF229561AD0'::uuid
      )
  ) then
    raise exception 'WeChat timetable alignment stopped: a removed course now has enrollment data';
  end if;

  -- Wednesday classes moved from the generic 7-9 label to the explicit 6-9
  -- advanced-class labels shown in the new child timetable.
  update public.courses
  set name = '中国舞基本功课提高班',
      age_group_id = age_6_9_id,
      notes = concat_ws(
        E'\n',
        nullif(notes, ''),
        '按 2026-08-22 微信新版课表校正：周三 4:00-5:00，6-9 岁。'
      )
  where id = 'AF0684BF-C3EC-4D1C-A4A9-29BF9DDB4A67'::uuid
    and organization_id = organization_id_value;

  update public.courses
  set name = '中国舞技术技巧提高班',
      age_group_id = age_6_9_id,
      notes = concat_ws(
        E'\n',
        nullif(notes, ''),
        '按 2026-08-22 微信新版课表校正：周三 5:00-6:00，6-9 岁。'
      )
  where id = '27439BC0-797A-4DDA-9CC2-D417F247240B'::uuid
    and organization_id = organization_id_value;

  -- These three courses no longer appear in the new child timetable. Keep the
  -- records for audit/history, but hide the courses and cancel their sessions.
  update public.courses
  set is_active = false,
      notes = concat_ws(
        E'\n',
        nullif(notes, ''),
        '2026-08-22 微信新版课表中已撤下；保留历史记录。'
      )
  where organization_id = organization_id_value
    and id in (
      '32FFECC5-A4DD-359D-AAF5-F663658003A1'::uuid,
      'B80FD74B-127B-E8F8-7CCF-23C6B7499A78'::uuid,
      '579424AF-1A2D-7A22-926E-4CF229561AD0'::uuid
    );

  update public.class_sessions
  set status = 'cancelled'::public.class_session_status
  where organization_id = organization_id_value
    and course_id in (
      '32FFECC5-A4DD-359D-AAF5-F663658003A1'::uuid,
      'B80FD74B-127B-E8F8-7CCF-23C6B7499A78'::uuid,
      '579424AF-1A2D-7A22-926E-4CF229561AD0'::uuid
    )
    and status <> 'cancelled'::public.class_session_status;

  -- Saturday small-room basic class is now 10:00-11:00 instead of 10:30-11:30.
  update public.class_sessions
  set starts_at = starts_at - interval '30 minutes',
      ends_at = ends_at - interval '30 minutes'
  where organization_id = organization_id_value
    and course_id = 'CA4A920A-4188-E855-6FA9-6E4EA1F0A7DA'::uuid
    and status <> 'cancelled'::public.class_session_status;

  update public.courses
  set notes = concat_ws(
    E'\n',
    nullif(notes, ''),
    '按 2026-08-22 微信新版课表校正：周六小教室 10:00-11:00。'
  )
  where id = 'CA4A920A-4188-E855-6FA9-6E4EA1F0A7DA'::uuid
    and organization_id = organization_id_value;

  -- Add the newly listed Saturday small-room performance class. Its first
  -- three meetings move to the following Sundays in the big room.
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
  values (
    saturday_performance_course_id,
    organization_id_value,
    term_id_value,
    '中国舞表演课',
    category_id_value,
    age_6_8_id,
    small_room_id,
    cai_jing_id,
    'group'::public.course_format,
    '来自 2026-08-22 微信新版课表。常规为周六小教室 11:00-12:00；前三节临时调整到周日上午大教室。价格待确认。',
    group_course_type_id,
    true,
    'pending'::public.course_pricing_status,
    null,
    null
  )
  on conflict (id) do update
  set name = excluded.name,
      age_group_id = excluded.age_group_id,
      default_room_id = excluded.default_room_id,
      default_instructor_id = excluded.default_instructor_id,
      course_type_id = excluded.course_type_id,
      is_active = true,
      notes = excluded.notes;

  insert into public.class_sessions (
    id,
    organization_id,
    course_id,
    starts_at,
    ends_at,
    room_override_id,
    effective_instructor_id,
    effective_room_id,
    status
  )
  select
    md5(
      'master-dance:2026-fall:session:sat-small-performance-6-8-1100:'
      || saturday_date::date::text
    )::uuid,
    organization_id_value,
    saturday_performance_course_id,
    (
      case
        when saturday_date::date in ('2026-08-22'::date, '2026-08-29'::date, '2026-09-05'::date)
          then saturday_date::date + 1
        else saturday_date::date
      end
      + time '11:00'
    ) at time zone timezone_value,
    (
      case
        when saturday_date::date in ('2026-08-22'::date, '2026-08-29'::date, '2026-09-05'::date)
          then saturday_date::date + 1
        else saturday_date::date
      end
      + time '12:00'
    ) at time zone timezone_value,
    case
      when saturday_date::date in ('2026-08-22'::date, '2026-08-29'::date, '2026-09-05'::date)
        then big_room_id
      else null
    end,
    cai_jing_id,
    case
      when saturday_date::date in ('2026-08-22'::date, '2026-08-29'::date, '2026-09-05'::date)
        then big_room_id
      else small_room_id
    end,
    'scheduled'::public.class_session_status
  from public.terms term
  cross join lateral generate_series(
    term.starts_on::timestamp,
    term.ends_on::timestamp,
    interval '1 day'
  ) saturday_date
  where term.id = term_id_value
    and extract(isodow from saturday_date)::integer = 6
    and not exists (
      select 1
      from public.term_holidays holiday
      where holiday.term_id = term.id
        and saturday_date::date between holiday.starts_on and holiday.ends_on
    )
  on conflict (course_id, starts_at) do nothing;

  select count(*) into candidate_count
  from public.class_sessions
  where course_id = saturday_performance_course_id
    and status = 'scheduled'::public.class_session_status;

  if candidate_count <> 17 then
    raise exception 'Expected 17 Saturday performance sessions, found %', candidate_count;
  end if;

  if (
    select count(*)
    from public.class_sessions
    where course_id = saturday_performance_course_id
      and room_override_id = big_room_id
  ) <> 3 then
    raise exception 'Expected exactly three temporary Sunday room overrides';
  end if;

  -- Adult courses newly supplied in the separate WeChat timetable. Prices are
  -- intentionally left pending. The three 15-week courses are created without
  -- sessions because the image does not identify which three calendar weeks
  -- are omitted.
  create temporary table md_wechat_adult_courses (
    source_key text primary key,
    course_name text not null,
    iso_weekday integer not null,
    starts_local time not null,
    ends_local time not null,
    instructor_id uuid not null,
    expected_sessions integer not null,
    session_policy text not null,
    course_notes text not null
  ) on commit drop;

  insert into md_wechat_adult_courses (
    source_key,
    course_name,
    iso_weekday,
    starts_local,
    ends_local,
    instructor_id,
    expected_sessions,
    session_policy,
    course_notes
  )
  values
    (
      'adult-mon-1900', '成人舞蹈', 1, '19:00', '20:30', wang_yating_id, 15, 'pending_dates',
      '微信课表列出 15 周；具体上课日期待确认。剧目：《折枝花满衣》《你的眼神》《舞娘》《女儿心如水》《喜欢你》《家乡》。价格待确认。'
    ),
    (
      'adult-tue-1900', '成人舞蹈剧目表演课', 2, '19:00', '20:30', wang_yating_id, 15, 'pending_dates',
      '微信课表列出 15 周；具体上课日期待确认。古典舞剧目：《清风徐来》。价格待确认。'
    ),
    (
      'adult-wed-1000', '成人舞蹈剧目表演课', 3, '10:00', '11:30', cai_jing_id, 18, 'all_term_weekdays',
      '来自 2026-08-22 微信成人课表，共 18 周。剧目：《迷途的羔羊》《人间共鸣》《喜玛拉雅·热》。价格待确认。'
    ),
    (
      'adult-wed-1900', '成人舞蹈', 3, '19:00', '20:30', wang_yating_id, 15, 'pending_dates',
      '微信课表列出 15 周；具体上课日期待确认。内容：基本功＋扶把组合。价格待确认。'
    ),
    (
      'adult-fri-1000', '成人舞蹈课', 5, '10:00', '11:30', cai_jing_id, 17, 'excluding_holidays',
      '来自 2026-08-22 微信成人课表，共 17 周。内容：《古典舞身韵》；6 人开班。价格待确认。'
    ),
    (
      'adult-sun-1300', '成人舞蹈剧目表演课', 7, '13:00', '14:30', cai_jing_id, 17, 'excluding_holidays',
      '来自 2026-08-22 微信成人课表，共 17 周。剧目：《芙蓉似锦润成花》。价格待确认。'
    ),
    (
      'adult-sun-1900', '成人现代舞剧目', 7, '19:00', '20:30', lin_fan_id, 17, 'excluding_holidays',
      '来自 2026-08-22 微信成人课表，共 17 周。价格待确认。'
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
    format,
    notes,
    course_type_id,
    is_active,
    pricing_status,
    unit_price_cents,
    drop_in_unit_price_cents
  )
  select
    md5('master-dance:2026-fall:course:' || adult.source_key)::uuid,
    organization_id_value,
    term_id_value,
    adult.course_name,
    category_id_value,
    adult_age_id,
    big_room_id,
    adult.instructor_id,
    'group'::public.course_format,
    adult.course_notes,
    group_course_type_id,
    true,
    'pending'::public.course_pricing_status,
    null,
    null
  from md_wechat_adult_courses adult
  on conflict (id) do update
  set name = excluded.name,
      age_group_id = excluded.age_group_id,
      default_room_id = excluded.default_room_id,
      default_instructor_id = excluded.default_instructor_id,
      course_type_id = excluded.course_type_id,
      is_active = true,
      notes = excluded.notes;

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
      || adult.source_key
      || ':'
      || session_date::date::text
    )::uuid,
    organization_id_value,
    md5('master-dance:2026-fall:course:' || adult.source_key)::uuid,
    (session_date::date + adult.starts_local) at time zone timezone_value,
    (session_date::date + adult.ends_local) at time zone timezone_value,
    adult.instructor_id,
    big_room_id,
    'scheduled'::public.class_session_status
  from md_wechat_adult_courses adult
  join public.terms term on term.id = term_id_value
  cross join lateral generate_series(
    term.starts_on::timestamp,
    term.ends_on::timestamp,
    interval '1 day'
  ) session_date
  where adult.session_policy <> 'pending_dates'
    and extract(isodow from session_date)::integer = adult.iso_weekday
    and (
      adult.session_policy = 'all_term_weekdays'
      or not exists (
        select 1
        from public.term_holidays holiday
        where holiday.term_id = term.id
          and session_date::date between holiday.starts_on and holiday.ends_on
      )
    )
  on conflict (course_id, starts_at) do nothing;

  if exists (
    select 1
    from md_wechat_adult_courses adult
    left join lateral (
      select count(*)::integer as session_count
      from public.class_sessions session
      where session.course_id = md5('master-dance:2026-fall:course:' || adult.source_key)::uuid
        and session.status = 'scheduled'::public.class_session_status
    ) counts on true
    where (
      adult.session_policy = 'pending_dates'
      and counts.session_count <> 0
    ) or (
      adult.session_policy <> 'pending_dates'
      and counts.session_count <> adult.expected_sessions
    )
  ) then
    raise exception 'Adult WeChat timetable session verification failed';
  end if;

  -- The Sunday child timetable shows overlapping 5:10-6:10 and 6:00-7:00
  -- courses for the same room and teacher. Existing 2:30/4:00/5:00/6:00
  -- sessions remain unchanged until the school confirms the intended boundary.
end
$$;

commit;
