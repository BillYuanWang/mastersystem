begin;

create or replace function public.bootstrap_first_administrator(
  display_name text
)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
  target_organization_id uuid;
  created_profile public.profiles;
begin
  if current_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if length(btrim(coalesce(display_name, ''))) not between 1 and 120 then
    raise exception 'Display name must contain 1 to 120 characters'
      using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(651239001);

  if exists (select 1 from public.profiles) then
    raise exception 'Administrator bootstrap has already been completed'
      using errcode = '42501';
  end if;

  select id into target_organization_id
  from public.organizations
  order by created_at
  limit 1;

  if target_organization_id is null then
    raise exception 'No organization is available for bootstrap'
      using errcode = '23503';
  end if;

  insert into public.profiles (
    user_id,
    organization_id,
    role,
    display_name
  )
  values (
    current_user_id,
    target_organization_id,
    'administrator',
    btrim(display_name)
  )
  returning * into created_profile;

  return created_profile;
end;
$$;

revoke all on function public.bootstrap_first_administrator(text) from public, anon;
grant execute on function public.bootstrap_first_administrator(text) to authenticated;

commit;
