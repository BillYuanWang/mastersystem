begin;

alter table public.attendance
  add column makeup_for_session_id uuid;

alter table public.attendance
  add constraint attendance_makeup_source_session_fk
    foreign key (makeup_for_session_id, organization_id)
    references public.class_sessions(id, organization_id)
    on delete set null (makeup_for_session_id);

alter table public.attendance
  add constraint attendance_makeup_source_status_check
  check (
    status::text = 'makeup'
    or makeup_for_session_id is null
  );

alter table public.attendance
  add constraint attendance_makeup_source_not_self_check
  check (makeup_for_session_id is null or makeup_for_session_id <> session_id);

create unique index attendance_student_makeup_source_key
  on public.attendance (student_id, makeup_for_session_id)
  where makeup_for_session_id is not null;

create or replace function private.validate_makeup_source()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.makeup_for_session_id is null then
    return new;
  end if;

  if new.status::text <> 'makeup' then
    raise exception 'Only makeup attendance can reference a source session'
      using errcode = '23514';
  end if;

  if not exists (
    select 1
    from public.class_sessions source_session
    join public.enrollments source_enrollment
      on source_enrollment.course_id = source_session.course_id
     and source_enrollment.student_id = new.student_id
     and source_enrollment.organization_id = new.organization_id
    where source_session.id = new.makeup_for_session_id
      and source_session.organization_id = new.organization_id
      and (
        exists (
          select 1
          from public.leave_requests leave_request
          where leave_request.session_id = source_session.id
            and leave_request.student_id = new.student_id
            and leave_request.organization_id = new.organization_id
            and leave_request.status::text <> 'denied'
        )
        or exists (
          select 1
          from public.attendance source_attendance
          where source_attendance.session_id = source_session.id
            and source_attendance.student_id = new.student_id
            and source_attendance.organization_id = new.organization_id
            and source_attendance.status::text in ('absent', 'excused')
        )
      )
  ) then
    raise exception 'Makeup source must be a leave or absence for the same student'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger attendance_validate_makeup_source
before insert or update on public.attendance
for each row execute function private.validate_makeup_source();

comment on column public.attendance.makeup_for_session_id is
  'The enrolled leave or absence session fulfilled by this makeup visit.';

commit;
