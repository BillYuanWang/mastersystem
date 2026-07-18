begin;

create extension if not exists pgcrypto with schema extensions;

create table private.guardian_link_codes (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  guardian_id uuid not null,
  code_hash bytea not null,
  code_hint text not null check (code_hint ~ '^[0-9A-F]{4}$'),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  consumed_by_user_id uuid references auth.users(id) on delete set null,
  revoked_at timestamptz,
  created_by_user_id uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint guardian_link_codes_guardian_fk
    foreign key (guardian_id, organization_id)
    references public.guardians(id, organization_id) on delete cascade,
  constraint guardian_link_codes_expiry_check check (expires_at > created_at),
  constraint guardian_link_codes_consumption_check check (
    (consumed_at is null and consumed_by_user_id is null)
    or (consumed_at is not null and consumed_by_user_id is not null)
  )
);

create unique index guardian_link_codes_hash_key
  on private.guardian_link_codes (code_hash);

create unique index guardian_link_codes_one_active_per_guardian
  on private.guardian_link_codes (guardian_id)
  where consumed_at is null and revoked_at is null;

create index guardian_link_codes_expiry_idx
  on private.guardian_link_codes (expires_at)
  where consumed_at is null and revoked_at is null;

comment on table private.guardian_link_codes is
  'Hashed, expiring, one-time codes used to attach an Auth account to a guardian record.';

revoke all on table private.guardian_link_codes from public, anon, authenticated;

create or replace function private.protect_guardian_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  is_controlled_self_claim boolean :=
    (select auth.uid()) is not null
    and old.profile_user_id is null
    and new.profile_user_id = (select auth.uid())
    and new.id is not distinct from old.id
    and new.organization_id is not distinct from old.organization_id
    and new.created_at is not distinct from old.created_at;
begin
  if not private.is_admin()
     and (
       new.id is distinct from old.id
       or new.organization_id is distinct from old.organization_id
       or new.profile_user_id is distinct from old.profile_user_id
       or new.created_at is distinct from old.created_at
     )
     and not is_controlled_self_claim then
    raise exception 'Only administrators may change guardian identity links'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create or replace function public.admin_issue_guardian_link_code(
  target_guardian_id uuid,
  validity_days integer default 30
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  organization_id_value uuid := private.current_user_organization_id();
  linked_user_id_value uuid;
  random_part text;
  normalized_code text;
  display_code text;
  expiry_value timestamptz;
begin
  if not private.is_admin() then
    raise exception 'Administrator access required' using errcode = '42501';
  end if;

  if validity_days is null or validity_days not between 1 and 90 then
    raise exception 'Guardian link codes must remain valid for 1 to 90 days'
      using errcode = '22023';
  end if;

  select g.profile_user_id into linked_user_id_value
  from public.guardians g
  where g.id = target_guardian_id
    and g.organization_id = organization_id_value
  for update;

  if not found then
    raise exception 'Guardian not found in this organization'
      using errcode = 'P0002';
  end if;

  if linked_user_id_value is not null then
    raise exception 'Guardian is already linked to an account'
      using errcode = '23514';
  end if;

  update private.guardian_link_codes
  set revoked_at = now()
  where guardian_id = target_guardian_id
    and consumed_at is null
    and revoked_at is null;

  random_part := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 20));
  normalized_code := 'MD' || random_part;
  display_code := 'MD-'
    || substr(random_part, 1, 4) || '-'
    || substr(random_part, 5, 4) || '-'
    || substr(random_part, 9, 4) || '-'
    || substr(random_part, 13, 4) || '-'
    || substr(random_part, 17, 4);
  expiry_value := now() + make_interval(days => validity_days);

  insert into private.guardian_link_codes (
    organization_id,
    guardian_id,
    code_hash,
    code_hint,
    expires_at,
    created_by_user_id
  )
  values (
    organization_id_value,
    target_guardian_id,
    extensions.digest(normalized_code, 'sha256'),
    right(random_part, 4),
    expiry_value,
    (select auth.uid())
  );

  return jsonb_build_object(
    'guardian_id', target_guardian_id,
    'link_code', display_code,
    'expires_at', expiry_value
  );
end;
$$;

create or replace function public.admin_list_guardian_link_statuses()
returns table (
  guardian_id uuid,
  linked_user_id uuid,
  active_code_hint text,
  active_code_expires_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.is_admin() then
    raise exception 'Administrator access required' using errcode = '42501';
  end if;

  return query
  select
    g.id,
    g.profile_user_id,
    c.code_hint,
    c.expires_at
  from public.guardians g
  left join lateral (
    select code.code_hint, code.expires_at
    from private.guardian_link_codes code
    where code.guardian_id = g.id
      and code.consumed_at is null
      and code.revoked_at is null
      and code.expires_at > now()
    order by code.created_at desc
    limit 1
  ) c on true
  where g.organization_id = private.current_user_organization_id()
  order by g.display_name;
end;
$$;

create or replace function public.admin_create_student_for_guardian(
  target_guardian_id uuid,
  target_display_name text,
  target_legal_name text default null,
  target_kind public.student_kind default 'child'
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
    raise exception 'Administrator access required' using errcode = '42501';
  end if;

  if length(btrim(coalesce(target_display_name, ''))) not between 1 and 120 then
    raise exception 'Student display name must contain 1 to 120 characters'
      using errcode = '22023';
  end if;

  if target_kind is null then
    raise exception 'Student kind is required' using errcode = '22023';
  end if;

  perform 1
  from public.guardians g
  where g.id = target_guardian_id
    and g.organization_id = organization_id_value
  for update;

  if not found then
    raise exception 'Guardian not found in this organization'
      using errcode = 'P0002';
  end if;

  insert into public.students (
    organization_id,
    display_name,
    legal_name,
    kind
  )
  values (
    organization_id_value,
    btrim(target_display_name),
    nullif(btrim(coalesce(target_legal_name, '')), ''),
    target_kind
  )
  returning * into resulting_student;

  insert into public.guardian_students (
    organization_id,
    guardian_id,
    student_id,
    relationship_label,
    is_primary
  )
  values (
    organization_id_value,
    target_guardian_id,
    resulting_student.id,
    case target_kind when 'adult' then 'self' else 'child' end,
    true
  );

  return resulting_student;
end;
$$;

create or replace function public.admin_link_student_to_guardian(
  target_guardian_id uuid,
  target_student_id uuid
)
returns public.guardian_students
language plpgsql
security definer
set search_path = ''
as $$
declare
  organization_id_value uuid := private.current_user_organization_id();
  student_kind_value public.student_kind;
  resulting_link public.guardian_students;
begin
  if not private.is_admin() then
    raise exception 'Administrator access required' using errcode = '42501';
  end if;

  perform 1
  from public.guardians g
  where g.id = target_guardian_id
    and g.organization_id = organization_id_value
  for update;

  if not found then
    raise exception 'Guardian not found in this organization'
      using errcode = 'P0002';
  end if;

  select s.kind into student_kind_value
  from public.students s
  where s.id = target_student_id
    and s.organization_id = organization_id_value
    and s.is_active
  for update;

  if not found then
    raise exception 'Student not found in this organization'
      using errcode = 'P0002';
  end if;

  insert into public.guardian_students (
    organization_id,
    guardian_id,
    student_id,
    relationship_label,
    is_primary
  )
  values (
    organization_id_value,
    target_guardian_id,
    target_student_id,
    case student_kind_value when 'adult' then 'self' else 'child' end,
    not exists (
      select 1
      from public.guardian_students gs
      where gs.student_id = target_student_id
        and gs.is_primary
    )
  )
  on conflict (guardian_id, student_id) do update
  set relationship_label = excluded.relationship_label
  returning * into resulting_link;

  return resulting_link;
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

  select g.display_name, g.profile_user_id
  into guardian_name_value, linked_user_id_value
  from public.guardians g
  where g.id = guardian_id_value
    and g.organization_id = organization_id_value
  for update;

  if not found or linked_user_id_value is not null then
    raise exception 'Guardian is already linked to an account'
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

revoke all on function public.admin_issue_guardian_link_code(uuid, integer)
  from public, anon, authenticated;
revoke all on function public.admin_list_guardian_link_statuses()
  from public, anon, authenticated;
revoke all on function public.admin_create_student_for_guardian(
  uuid,
  text,
  text,
  public.student_kind
) from public, anon, authenticated;
revoke all on function public.admin_link_student_to_guardian(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.claim_guardian_link_code(text)
  from public, anon, authenticated;

grant execute on function public.admin_issue_guardian_link_code(uuid, integer)
  to authenticated;
grant execute on function public.admin_list_guardian_link_statuses()
  to authenticated;
grant execute on function public.admin_create_student_for_guardian(
  uuid,
  text,
  text,
  public.student_kind
) to authenticated;
grant execute on function public.admin_link_student_to_guardian(uuid, uuid)
  to authenticated;
grant execute on function public.claim_guardian_link_code(text)
  to authenticated;

commit;
