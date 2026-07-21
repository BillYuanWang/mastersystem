begin;

alter table public.leave_requests
  alter column status set default 'approved'::public.leave_request_status;

update public.leave_requests
set
  status = 'approved'::public.leave_request_status,
  resolved_at = null,
  resolved_by = null
where status <> 'approved'::public.leave_request_status
   or resolved_at is not null
   or resolved_by is not null;

create or replace function private.normalize_leave_request_status()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.status := 'approved'::public.leave_request_status;
  new.resolved_at := null;
  new.resolved_by := null;
  return new;
end;
$$;

drop trigger if exists leave_requests_normalize_status on public.leave_requests;
create trigger leave_requests_normalize_status
before insert or update on public.leave_requests
for each row execute function private.normalize_leave_request_status();

create or replace function public.submit_leave_request(
  target_session_id uuid,
  target_student_id uuid,
  request_note text default null
)
returns public.leave_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  organization_id_value uuid := private.current_user_organization_id();
  role_value public.app_role := private.current_user_role();
  enrollment_id_value uuid;
  session_starts_at timestamptz;
  request_already_exists boolean;
  resulting_request public.leave_requests;
begin
  if not private.can_request_leave(target_session_id, target_student_id) then
    raise exception 'Student is not eligible for this leave request'
      using errcode = '42501';
  end if;

  select s.starts_at
  into session_starts_at
  from public.class_sessions s
  where s.id = target_session_id
    and s.organization_id = organization_id_value;

  if session_starts_at is null then
    raise exception 'Class session was not found'
      using errcode = '22023';
  end if;

  select exists (
    select 1
    from public.leave_requests lr
    where lr.session_id = target_session_id
      and lr.student_id = target_student_id
      and lr.organization_id = organization_id_value
  ) into request_already_exists;

  if role_value is distinct from 'administrator'::public.app_role
     and not request_already_exists
     and now() > session_starts_at - interval '12 hours' then
    raise exception '线上请假须在课程开始前至少 12 小时提交。请联系教务老师协助登记。'
      using
        errcode = '22023',
        detail = format(
          'class_starts_at=%s, leave_deadline=%s',
          session_starts_at,
          session_starts_at - interval '12 hours'
        ),
        hint = '请联系教务老师，由教务老师代为登记请假。';
  end if;

  select e.id into enrollment_id_value
  from public.class_sessions s
  join public.enrollments e
    on e.course_id = s.course_id
   and e.student_id = target_student_id
   and e.organization_id = s.organization_id
  where s.id = target_session_id
    and e.status = 'active'::public.enrollment_status
  limit 1;

  insert into public.leave_requests (
    organization_id,
    session_id,
    student_id,
    enrollment_id,
    source,
    status,
    submitted_by,
    note
  )
  values (
    organization_id_value,
    target_session_id,
    target_student_id,
    enrollment_id_value,
    'app',
    'approved',
    (select auth.uid()),
    nullif(btrim(request_note), '')
  )
  on conflict (session_id, student_id) do update
  set
    status = 'approved',
    resolved_at = null,
    resolved_by = null,
    note = excluded.note
  returning * into resulting_request;

  return resulting_request;
end;
$$;

revoke execute on function private.normalize_leave_request_status()
from public, anon, authenticated;

comment on function public.submit_leave_request(uuid, uuid, text) is
  'Records guardian leave at least 12 hours before class; administrators may record leave at any time.';

commit;
