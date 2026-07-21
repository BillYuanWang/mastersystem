begin;

create or replace function public.admin_delete_guardian_household(
  target_guardian_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  organization_id_value uuid := private.current_user_organization_id();
  guardian_profile_user_id uuid;
begin
  if not private.is_admin() then
    raise exception '需要教务管理员权限。' using errcode = '42501';
  end if;

  select g.profile_user_id
  into guardian_profile_user_id
  from public.guardians g
  where g.id = target_guardian_id
    and g.organization_id = organization_id_value
  for update;

  if not found then
    return;
  end if;

  if guardian_profile_user_id is not null then
    raise exception '这个监护人已连接帐号，不能删除。'
      using errcode = '23503';
  end if;

  if exists (
    select 1
    from public.students s
    where s.guardian_id = target_guardian_id
      and s.organization_id = organization_id_value
      and s.profile_user_id is not null
  ) then
    raise exception '这个家庭有已连接帐号的学员，不能删除。'
      using errcode = '23503';
  end if;

  if exists (
    select 1
    from public.enrollments e
    join public.students s
      on s.id = e.student_id
     and s.organization_id = e.organization_id
    where s.guardian_id = target_guardian_id
      and s.organization_id = organization_id_value
  ) then
    raise exception '这个家庭仍有学员报名，不能删除；请先撤销报名。'
      using errcode = '23503';
  end if;

  if exists (
    select 1
    from public.attendance a
    join public.students s
      on s.id = a.student_id
     and s.organization_id = a.organization_id
    where s.guardian_id = target_guardian_id
      and s.organization_id = organization_id_value
  ) then
    raise exception '这个家庭已有签到记录，不能删除；可以停用学员档案。'
      using errcode = '23503';
  end if;

  if exists (
    select 1
    from public.leave_requests l
    join public.students s
      on s.id = l.student_id
     and s.organization_id = l.organization_id
    where s.guardian_id = target_guardian_id
      and s.organization_id = organization_id_value
  ) then
    raise exception '这个家庭已有请假记录，不能删除；可以停用学员档案。'
      using errcode = '23503';
  end if;

  if exists (
    select 1
    from private.guardian_registration_acceptances a
    where a.guardian_id = target_guardian_id
      and a.organization_id = organization_id_value
  ) then
    raise exception '这个监护人已有合同签字记录，不能删除。'
      using errcode = '23503';
  end if;

  delete from public.students
  where guardian_id = target_guardian_id
    and organization_id = organization_id_value;

  delete from public.guardians
  where id = target_guardian_id
    and organization_id = organization_id_value;
end;
$$;

revoke all on function public.admin_delete_guardian_household(uuid)
from public, anon, authenticated;
grant execute on function public.admin_delete_guardian_household(uuid)
to authenticated;

comment on function public.admin_delete_guardian_household(uuid) is
  'Atomically deletes an unclaimed guardian and empty learner profiles, while preserving linked accounts and operational history.';

commit;
