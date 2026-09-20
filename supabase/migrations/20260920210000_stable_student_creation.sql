begin;

-- Keep the original RPC for older clients. Local-first clients supply their
-- existing UUID so enrollment and billing references survive synchronization.
create function public.admin_create_student_for_guardian_v2(
  target_student_id uuid,
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
  if not private.is_admin() or organization_id_value is null then
    raise exception 'Administrator access required' using errcode = '42501';
  end if;
  if target_student_id is null then
    raise exception 'Student ID is required' using errcode = '22023';
  end if;
  if length(btrim(coalesce(target_display_name, ''))) not between 1 and 120 then
    raise exception 'Student name must contain 1 to 120 characters' using errcode = '22023';
  end if;

  perform 1 from public.guardians g
  where g.id = target_guardian_id
    and g.organization_id = organization_id_value
  for update;
  if not found then
    raise exception 'Guardian is unavailable' using errcode = '23503';
  end if;

  -- A lost network response may cause the durable queue to retry creation.
  -- Never overwrite a profile that may already have been edited elsewhere.
  select * into resulting_student from public.students s
  where s.id = target_student_id;
  if found then
    if resulting_student.organization_id <> organization_id_value
       or resulting_student.guardian_id is distinct from target_guardian_id then
      raise exception 'Student ID belongs to a different family' using errcode = '23514';
    end if;
    return resulting_student;
  end if;

  insert into public.students (
    id, organization_id, guardian_id, display_name, legal_name, birth_date, kind
  ) values (
    target_student_id, organization_id_value, target_guardian_id,
    btrim(target_display_name), nullif(btrim(coalesce(target_legal_name, '')), ''),
    target_birth_date, target_kind
  ) returning * into resulting_student;
  return resulting_student;
end;
$$;

revoke all on function public.admin_create_student_for_guardian_v2(
  uuid, uuid, text, text, public.student_kind, date
) from public, anon, authenticated, service_role;
grant execute on function public.admin_create_student_for_guardian_v2(
  uuid, uuid, text, text, public.student_kind, date
) to authenticated;

notify pgrst, 'reload schema';
commit;
