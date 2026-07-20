begin;

drop function public.admin_create_student_for_guardian(
  uuid,
  text,
  text,
  public.student_kind
);

create function public.admin_create_student_for_guardian(
  target_guardian_id uuid,
  target_display_name text,
  target_legal_name text default null,
  target_kind public.student_kind default 'child',
  target_birth_date date default null
)
returns public.students
language plpgsql
security definer
set search_path = ''
as $$
declare
  organization_id_value uuid := private.current_user_organization_id();
  resulting_student public.students;
begin
  if not private.is_admin() then
    raise exception '需要教务管理员权限。' using errcode = '42501';
  end if;

  if length(btrim(coalesce(target_display_name, ''))) not between 1 and 120 then
    raise exception '学员姓名需要填写 1 到 120 个字符。' using errcode = '22023';
  end if;

  perform 1
  from public.guardians g
  where g.id = target_guardian_id
    and g.organization_id = organization_id_value;

  if not found then
    raise exception '找不到这个监护人。' using errcode = 'P0002';
  end if;

  insert into public.students (
    organization_id,
    guardian_id,
    display_name,
    legal_name,
    birth_date,
    kind
  )
  values (
    organization_id_value,
    target_guardian_id,
    btrim(target_display_name),
    nullif(btrim(coalesce(target_legal_name, '')), ''),
    target_birth_date,
    target_kind
  )
  returning * into resulting_student;

  return resulting_student;
end;
$$;

revoke all on function public.admin_create_student_for_guardian(
  uuid,
  text,
  text,
  public.student_kind,
  date
)
from public, anon, authenticated, service_role;

grant execute on function public.admin_create_student_for_guardian(
  uuid,
  text,
  text,
  public.student_kind,
  date
)
to authenticated;

comment on function public.admin_create_student_for_guardian(
  uuid,
  text,
  text,
  public.student_kind,
  date
) is 'Atomically creates a learner profile, including its optional birth date, under one guardian.';

notify pgrst, 'reload schema';

commit;
