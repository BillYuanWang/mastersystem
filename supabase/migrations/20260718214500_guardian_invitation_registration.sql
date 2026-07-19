begin;

create or replace function public.preview_guardian_registration(
  claim_code text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  normalized_code text;
  guardian_email_value text;
  guardian_name_value text;
  expiry_value timestamptz;
begin
  normalized_code := regexp_replace(
    upper(coalesce(claim_code, '')),
    '[^A-Z0-9]',
    '',
    'g'
  );

  if normalized_code !~ '^MD[0-9A-F]{20}$' then
    raise exception 'Invalid or expired guardian link code'
      using errcode = 'P0001';
  end if;

  select g.email, g.display_name, code.expires_at
  into guardian_email_value, guardian_name_value, expiry_value
  from private.guardian_link_codes code
  join public.guardians g
    on g.id = code.guardian_id
   and g.organization_id = code.organization_id
  where code.code_hash = extensions.digest(normalized_code, 'sha256')
    and code.consumed_at is null
    and code.revoked_at is null
    and code.expires_at > now()
    and g.profile_user_id is null;

  if not found then
    raise exception 'Invalid or expired guardian link code'
      using errcode = 'P0001';
  end if;

  guardian_email_value := lower(btrim(coalesce(guardian_email_value, '')));
  if guardian_email_value !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'Guardian invitation email is unavailable'
      using errcode = '23514';
  end if;

  return jsonb_build_object(
    'email', guardian_email_value,
    'guardian_name', guardian_name_value,
    'expires_at', expiry_value
  );
end;
$$;

create or replace function public.claim_guardian_link_code(
  claim_code text
)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
  normalized_code text;
  code_id_value uuid;
  organization_id_value uuid;
  guardian_id_value uuid;
  guardian_name_value text;
  guardian_email_value text;
  authenticated_email_value text;
  linked_user_id_value uuid;
  resulting_profile public.profiles;
begin
  if current_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if exists (select 1 from public.profiles p where p.user_id = current_user_id) then
    raise exception 'This account is already attached to a school profile'
      using errcode = '23514';
  end if;

  normalized_code := regexp_replace(
    upper(coalesce(claim_code, '')),
    '[^A-Z0-9]',
    '',
    'g'
  );

  if normalized_code !~ '^MD[0-9A-F]{20}$' then
    raise exception 'Invalid or expired guardian link code'
      using errcode = 'P0001';
  end if;

  select code.id, code.organization_id, code.guardian_id
  into code_id_value, organization_id_value, guardian_id_value
  from private.guardian_link_codes code
  where code.code_hash = extensions.digest(normalized_code, 'sha256')
    and code.consumed_at is null
    and code.revoked_at is null
    and code.expires_at > now()
  for update;

  if not found then
    raise exception 'Invalid or expired guardian link code'
      using errcode = 'P0001';
  end if;

  select g.display_name, g.email, g.profile_user_id
  into guardian_name_value, guardian_email_value, linked_user_id_value
  from public.guardians g
  where g.id = guardian_id_value
    and g.organization_id = organization_id_value
  for update;

  if not found or linked_user_id_value is not null then
    raise exception 'Guardian is already linked to an account'
      using errcode = '23514';
  end if;

  select u.email
  into authenticated_email_value
  from auth.users u
  where u.id = current_user_id;

  guardian_email_value := lower(btrim(coalesce(guardian_email_value, '')));
  authenticated_email_value := lower(btrim(coalesce(authenticated_email_value, '')));

  if guardian_email_value !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'Guardian invitation email is unavailable'
      using errcode = '23514';
  end if;

  if guardian_email_value is distinct from authenticated_email_value then
    raise exception 'Guardian invitation email does not match authenticated account'
      using errcode = '23514';
  end if;

  insert into public.profiles (
    user_id,
    organization_id,
    role,
    display_name
  )
  values (
    current_user_id,
    organization_id_value,
    'guardian',
    guardian_name_value
  )
  returning * into resulting_profile;

  update public.guardians
  set profile_user_id = current_user_id
  where id = guardian_id_value
    and organization_id = organization_id_value;

  update private.guardian_link_codes
  set
    consumed_at = now(),
    consumed_by_user_id = current_user_id
  where id = code_id_value;

  update private.guardian_link_codes
  set revoked_at = now()
  where guardian_id = guardian_id_value
    and id <> code_id_value
    and consumed_at is null
    and revoked_at is null;

  return resulting_profile;
end;
$$;

revoke all on function public.preview_guardian_registration(text)
  from public, anon, authenticated;
grant execute on function public.preview_guardian_registration(text)
  to anon, authenticated;

revoke all on function public.claim_guardian_link_code(text)
  from public, anon, authenticated;
grant execute on function public.claim_guardian_link_code(text)
  to authenticated;

commit;
