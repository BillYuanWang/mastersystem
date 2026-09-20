-- Apply the school-confirmed Sunday child timetable without any conflict-rule
-- exception. The first three courses run consecutively in the big room; the
-- 6:10-7:10 private lesson uses the small room while the adult class starts in
-- the big room at 7:00.

begin;

do $$
declare
  organization_id_value constant uuid := '00000000-0000-0000-0000-000000000001'::uuid;
  term_id_value uuid;
  big_room_id uuid;
  small_room_id uuid;
  timezone_value text;
  scheduled_session_count integer;
begin
  perform pg_advisory_xact_lock(hashtext('master-dance:2026-fall:sunday-child-times'));

  select term.id, organization.timezone
  into term_id_value, timezone_value
  from public.terms term
  join public.organizations organization
    on organization.id = term.organization_id
  where term.organization_id = organization_id_value
    and term.name = '2026年秋季学期';

  select id into big_room_id
  from public.rooms
  where organization_id = organization_id_value
    and name = '大教室';

  select id into small_room_id
  from public.rooms
  where organization_id = organization_id_value
    and name = '小教室';

  if term_id_value is null
     or timezone_value is null
     or big_room_id is null
     or small_room_id is null then
    raise notice 'Sunday timetable correction skipped: this database does not contain the production term and rooms';
    return;
  end if;

  if (
    select count(*)
    from public.courses
    where organization_id = organization_id_value
      and term_id = term_id_value
      and id in (
        'E94C6200-B526-4919-8AFF-343E943D3236'::uuid,
        'FCEF7CFB-CC99-ADA9-D445-2AFFBACABC88'::uuid,
        'B60C064C-68DF-77FC-2029-B63E4777D91E'::uuid,
        'D88B4EDA-356C-3C27-0898-DA0A3CCCE539'::uuid
      )
  ) <> 4 then
    raise exception 'Sunday timetable correction stopped: expected child courses are missing';
  end if;

  if exists (
    select 1
    from public.class_sessions session
    where session.organization_id = organization_id_value
      and session.course_id in (
        'E94C6200-B526-4919-8AFF-343E943D3236'::uuid,
        'FCEF7CFB-CC99-ADA9-D445-2AFFBACABC88'::uuid,
        'B60C064C-68DF-77FC-2029-B63E4777D91E'::uuid,
        'D88B4EDA-356C-3C27-0898-DA0A3CCCE539'::uuid
      )
      and session.room_override_id is not null
  ) then
    raise exception 'Sunday timetable correction stopped: a target session has a manual room override';
  end if;

  -- Keep the first three courses in the big room. The existing propagation
  -- trigger updates effective room values while retaining stable session IDs
  -- and relationships.
  update public.courses
  set default_room_id = big_room_id
  where organization_id = organization_id_value
    and term_id = term_id_value
    and id in (
      'E94C6200-B526-4919-8AFF-343E943D3236'::uuid,
      'FCEF7CFB-CC99-ADA9-D445-2AFFBACABC88'::uuid,
      'B60C064C-68DF-77FC-2029-B63E4777D91E'::uuid
    );

  -- The final private lesson uses the small room, avoiding the 7:00 adult
  -- class in the big room without changing any conflict rule.
  update public.courses
  set default_room_id = small_room_id
  where organization_id = organization_id_value
    and term_id = term_id_value
    and id = 'D88B4EDA-356C-3C27-0898-DA0A3CCCE539'::uuid;

  -- Update from the last class backwards so every intermediate state also
  -- satisfies the existing room and instructor exclusion constraints.
  update public.class_sessions
  set starts_at = (
        (starts_at at time zone timezone_value)::date + time '18:10'
      ) at time zone timezone_value,
      ends_at = (
        (starts_at at time zone timezone_value)::date + time '19:10'
      ) at time zone timezone_value
  where organization_id = organization_id_value
    and course_id = 'D88B4EDA-356C-3C27-0898-DA0A3CCCE539'::uuid
    and status <> 'cancelled'::public.class_session_status;

  update public.class_sessions
  set starts_at = (
        (starts_at at time zone timezone_value)::date + time '17:10'
      ) at time zone timezone_value,
      ends_at = (
        (starts_at at time zone timezone_value)::date + time '18:10'
      ) at time zone timezone_value
  where organization_id = organization_id_value
    and course_id = 'B60C064C-68DF-77FC-2029-B63E4777D91E'::uuid
    and status <> 'cancelled'::public.class_session_status;

  update public.class_sessions
  set starts_at = (
        (starts_at at time zone timezone_value)::date + time '16:10'
      ) at time zone timezone_value,
      ends_at = (
        (starts_at at time zone timezone_value)::date + time '17:10'
      ) at time zone timezone_value
  where organization_id = organization_id_value
    and course_id = 'FCEF7CFB-CC99-ADA9-D445-2AFFBACABC88'::uuid
    and status <> 'cancelled'::public.class_session_status;

  update public.class_sessions
  set starts_at = (
        (starts_at at time zone timezone_value)::date + time '14:40'
      ) at time zone timezone_value,
      ends_at = (
        (starts_at at time zone timezone_value)::date + time '16:10'
      ) at time zone timezone_value
  where organization_id = organization_id_value
    and course_id = 'E94C6200-B526-4919-8AFF-343E943D3236'::uuid
    and status <> 'cancelled'::public.class_session_status;

  update public.courses
  set notes = concat_ws(
    E'\n',
    nullif(notes, ''),
    case id
      when 'E94C6200-B526-4919-8AFF-343E943D3236'::uuid
        then '按 2026-08-23 教务确认：周日大教室 2:40-4:10。'
      when 'FCEF7CFB-CC99-ADA9-D445-2AFFBACABC88'::uuid
        then '按 2026-08-23 教务确认：周日大教室 4:10-5:10。'
      when 'B60C064C-68DF-77FC-2029-B63E4777D91E'::uuid
        then '按 2026-08-23 教务确认：周日大教室 5:10-6:10。'
      when 'D88B4EDA-356C-3C27-0898-DA0A3CCCE539'::uuid
        then '按 2026-08-23 教务确认：周日小教室 6:10-7:10；无需冲突特例。'
    end
  )
  where organization_id = organization_id_value
    and term_id = term_id_value
    and id in (
      'E94C6200-B526-4919-8AFF-343E943D3236'::uuid,
      'FCEF7CFB-CC99-ADA9-D445-2AFFBACABC88'::uuid,
      'B60C064C-68DF-77FC-2029-B63E4777D91E'::uuid,
      'D88B4EDA-356C-3C27-0898-DA0A3CCCE539'::uuid
    );

  select count(*) into scheduled_session_count
  from public.class_sessions session
  where session.organization_id = organization_id_value
    and session.course_id in (
      'E94C6200-B526-4919-8AFF-343E943D3236'::uuid,
      'FCEF7CFB-CC99-ADA9-D445-2AFFBACABC88'::uuid,
      'B60C064C-68DF-77FC-2029-B63E4777D91E'::uuid,
      'D88B4EDA-356C-3C27-0898-DA0A3CCCE539'::uuid
    )
    and session.status = 'scheduled'::public.class_session_status;

  if scheduled_session_count <> 68 then
    raise exception 'Expected 68 scheduled Sunday child sessions, found %', scheduled_session_count;
  end if;

  if exists (
    select 1
    from public.class_sessions session
    cross join lateral (
      values
        ('E94C6200-B526-4919-8AFF-343E943D3236'::uuid, time '14:40', time '16:10', big_room_id),
        ('FCEF7CFB-CC99-ADA9-D445-2AFFBACABC88'::uuid, time '16:10', time '17:10', big_room_id),
        ('B60C064C-68DF-77FC-2029-B63E4777D91E'::uuid, time '17:10', time '18:10', big_room_id),
        ('D88B4EDA-356C-3C27-0898-DA0A3CCCE539'::uuid, time '18:10', time '19:10', small_room_id)
    ) expected(course_id, starts_local, ends_local, room_id)
    where session.organization_id = organization_id_value
      and session.course_id = expected.course_id
      and session.status = 'scheduled'::public.class_session_status
      and (
        (session.starts_at at time zone timezone_value)::time <> expected.starts_local
        or (session.ends_at at time zone timezone_value)::time <> expected.ends_local
        or session.effective_room_id <> expected.room_id
      )
  ) then
    raise exception 'Sunday timetable correction verification failed';
  end if;
end
$$;

commit;
