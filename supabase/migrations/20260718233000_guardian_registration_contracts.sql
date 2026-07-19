begin;

create table public.contract_consent_signatures (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  contract_consent_id uuid not null unique
    references public.contract_consents(id) on delete cascade,
  signature_png bytea not null,
  signature_mime_type text not null default 'image/png'
    check (signature_mime_type = 'image/png'),
  contract_sha256 text not null
    check (contract_sha256 ~ '^[0-9a-f]{64}$'),
  source text not null default 'ios_registration'
    check (source in ('ios_registration')),
  signed_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint contract_consent_signatures_size_check check (
    octet_length(signature_png) between 128 and 524288
  )
);

create index contract_consent_signatures_organization_idx
  on public.contract_consent_signatures (organization_id, signed_at desc);

comment on table public.contract_consent_signatures is
  'Private signature evidence tied to an immutable contract version and file hash.';

create table private.guardian_registration_acceptances (
  link_code_id uuid primary key
    references private.guardian_link_codes(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  guardian_id uuid not null,
  contract_document_id uuid not null
    references public.contract_documents(id) on delete restrict,
  signer_display_name text not null
    check (length(btrim(signer_display_name)) between 1 and 120),
  signature_png bytea not null,
  signature_mime_type text not null default 'image/png'
    check (signature_mime_type = 'image/png'),
  contract_sha256 text not null
    check (contract_sha256 ~ '^[0-9a-f]{64}$'),
  accepted_at timestamptz not null default now(),
  constraint guardian_registration_acceptances_guardian_fk
    foreign key (guardian_id, organization_id)
    references public.guardians(id, organization_id) on delete cascade,
  constraint guardian_registration_acceptances_size_check check (
    octet_length(signature_png) between 128 and 524288
  )
);

comment on table private.guardian_registration_acceptances is
  'Pre-auth registration signatures, keyed by a one-time guardian invitation until claim.';

revoke all on table private.guardian_registration_acceptances
  from public, anon, authenticated;

create or replace function private.current_registration_contract(
  target_organization_id uuid
)
returns public.contract_documents
language sql
stable
security definer
set search_path = ''
as $$
  select d
  from public.contract_documents d
  join public.terms t
    on t.id = d.term_id
   and t.organization_id = d.organization_id
  where d.organization_id = target_organization_id
    and d.status = 'published'::public.contract_document_status
  order by
    case t.status
      when 'open'::public.term_status then 0
      when 'draft'::public.term_status then 1
      else 2
    end,
    case
      when current_date between t.starts_on and t.ends_on then 0
      when t.starts_on > current_date then 1
      else 2
    end,
    t.starts_on desc,
    d.published_at desc,
    d.created_at desc
  limit 1
$$;

revoke execute on function private.current_registration_contract(uuid)
  from public, anon, authenticated;

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
  organization_id_value uuid;
  guardian_email_value text;
  guardian_name_value text;
  expiry_value timestamptz;
  contract_value public.contract_documents;
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

  select code.organization_id, g.email, g.display_name, code.expires_at
  into
    organization_id_value,
    guardian_email_value,
    guardian_name_value,
    expiry_value
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

  contract_value := private.current_registration_contract(organization_id_value);
  if contract_value.id is null then
    raise exception 'Guardian registration contract is unavailable'
      using errcode = 'P0001';
  end if;

  return jsonb_build_object(
    'email', guardian_email_value,
    'guardian_name', guardian_name_value,
    'expires_at', expiry_value,
    'contract', jsonb_build_object(
      'id', contract_value.id,
      'title', contract_value.title,
      'version', contract_value.version
    )
  );
end;
$$;

create or replace function public.guardian_registration_contract_manifest(
  claim_code text,
  target_document_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  normalized_code text;
  organization_id_value uuid;
  contract_value public.contract_documents;
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

  select code.organization_id
  into organization_id_value
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

  contract_value := private.current_registration_contract(organization_id_value);
  if contract_value.id is null
     or contract_value.id is distinct from target_document_id then
    raise exception 'Registration contract changed'
      using errcode = 'P0001';
  end if;

  return jsonb_build_object(
    'id', contract_value.id,
    'title', contract_value.title,
    'version', contract_value.version,
    'storage_path', contract_value.storage_path
  );
end;
$$;

create or replace function public.record_guardian_registration_acceptance(
  claim_code text,
  target_document_id uuid,
  signature_base64 text,
  contract_sha256 text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_code text;
  code_id_value uuid;
  organization_id_value uuid;
  guardian_id_value uuid;
  guardian_name_value text;
  contract_value public.contract_documents;
  signature_value bytea;
  normalized_hash text := lower(btrim(coalesce(contract_sha256, '')));
  accepted_at_value timestamptz := now();
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

  if normalized_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'Invalid registration contract hash'
      using errcode = '22023';
  end if;

  begin
    signature_value := decode(coalesce(signature_base64, ''), 'base64');
  exception when others then
    raise exception 'Invalid registration signature'
      using errcode = '22023';
  end;

  if octet_length(signature_value) not between 128 and 524288
     or substring(signature_value from 1 for 8)
        <> decode('89504e470d0a1a0a', 'hex') then
    raise exception 'Invalid registration signature'
      using errcode = '22023';
  end if;

  select code.id, code.organization_id, code.guardian_id, g.display_name
  into
    code_id_value,
    organization_id_value,
    guardian_id_value,
    guardian_name_value
  from private.guardian_link_codes code
  join public.guardians g
    on g.id = code.guardian_id
   and g.organization_id = code.organization_id
  where code.code_hash = extensions.digest(normalized_code, 'sha256')
    and code.consumed_at is null
    and code.revoked_at is null
    and code.expires_at > now()
    and g.profile_user_id is null
  for update of code, g;

  if not found then
    raise exception 'Invalid or expired guardian link code'
      using errcode = 'P0001';
  end if;

  contract_value := private.current_registration_contract(organization_id_value);
  if contract_value.id is null
     or contract_value.id is distinct from target_document_id then
    raise exception 'Registration contract changed'
      using errcode = 'P0001';
  end if;

  insert into private.guardian_registration_acceptances (
    link_code_id,
    organization_id,
    guardian_id,
    contract_document_id,
    signer_display_name,
    signature_png,
    signature_mime_type,
    contract_sha256,
    accepted_at
  )
  values (
    code_id_value,
    organization_id_value,
    guardian_id_value,
    contract_value.id,
    guardian_name_value,
    signature_value,
    'image/png',
    normalized_hash,
    accepted_at_value
  )
  on conflict (link_code_id) do update
  set
    contract_document_id = excluded.contract_document_id,
    signer_display_name = excluded.signer_display_name,
    signature_png = excluded.signature_png,
    signature_mime_type = excluded.signature_mime_type,
    contract_sha256 = excluded.contract_sha256,
    accepted_at = excluded.accepted_at;

  return jsonb_build_object(
    'contract_document_id', contract_value.id,
    'accepted_at', accepted_at_value
  );
end;
$$;

create or replace function private.validate_contract_consent()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  document_status public.contract_document_status;
begin
  select status into document_status
  from public.contract_documents
  where id = new.contract_document_id;

  if document_status is distinct from 'published'::public.contract_document_status
     and not exists (
       select 1
       from private.guardian_registration_acceptances acceptance
       where acceptance.organization_id = new.organization_id
         and acceptance.contract_document_id = new.contract_document_id
         and acceptance.signer_display_name = new.signer_display_name
     ) then
    raise exception 'Consent can only be recorded for a published contract'
      using errcode = '23514';
  end if;

  return new;
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
  acceptance_value private.guardian_registration_acceptances;
  contract_term_id_value uuid;
  consent_id_value uuid;
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

  select acceptance.*
  into acceptance_value
  from private.guardian_registration_acceptances acceptance
  where acceptance.link_code_id = code_id_value
    and acceptance.organization_id = organization_id_value
    and acceptance.guardian_id = guardian_id_value
  for update;

  if not found then
    raise exception 'Guardian registration contract acceptance required'
      using errcode = '23514';
  end if;

  select d.term_id
  into contract_term_id_value
  from public.contract_documents d
  where d.id = acceptance_value.contract_document_id
    and d.organization_id = organization_id_value;

  if not found then
    raise exception 'Registration contract changed'
      using errcode = 'P0001';
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

  insert into public.contract_consents (
    organization_id,
    contract_document_id,
    term_id,
    enrollment_id,
    scope,
    signer_user_id,
    signer_kind,
    signer_display_name,
    consented_at
  )
  values (
    organization_id_value,
    acceptance_value.contract_document_id,
    contract_term_id_value,
    null,
    'term',
    current_user_id,
    'guardian',
    acceptance_value.signer_display_name,
    acceptance_value.accepted_at
  )
  returning id into consent_id_value;

  insert into public.contract_consent_signatures (
    organization_id,
    contract_consent_id,
    signature_png,
    signature_mime_type,
    contract_sha256,
    source,
    signed_at
  )
  values (
    organization_id_value,
    consent_id_value,
    acceptance_value.signature_png,
    acceptance_value.signature_mime_type,
    acceptance_value.contract_sha256,
    'ios_registration',
    acceptance_value.accepted_at
  );

  delete from private.guardian_registration_acceptances
  where link_code_id = code_id_value;

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

create or replace function private.cleanup_revoked_guardian_registration_acceptance()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.revoked_at is not null and old.revoked_at is null then
    delete from private.guardian_registration_acceptances
    where link_code_id = new.id;
  end if;
  return new;
end;
$$;

create trigger guardian_link_codes_cleanup_registration_acceptance
after update of revoked_at on private.guardian_link_codes
for each row execute function private.cleanup_revoked_guardian_registration_acceptance();

create or replace function private.prevent_pending_contract_deletion()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if exists (
    select 1
    from private.guardian_registration_acceptances acceptance
    where acceptance.contract_document_id = old.id
  ) then
    raise exception '这份合同已有待完成的注册签名，不能删除；可以将它停用。'
      using errcode = '23503';
  end if;
  return old;
end;
$$;

create trigger contract_documents_prevent_pending_registration_delete
before delete on public.contract_documents
for each row execute function private.prevent_pending_contract_deletion();

create trigger contract_consent_signatures_audit
after insert or update or delete on public.contract_consent_signatures
for each row execute function private.capture_audit_event();

alter table public.contract_consent_signatures enable row level security;

revoke all on public.contract_consent_signatures
  from public, anon, authenticated;
grant select on public.contract_consent_signatures to authenticated;

create policy contract_consent_signatures_member_select
on public.contract_consent_signatures
for select
to authenticated
using (
  organization_id = private.current_user_organization_id()
  and (
    private.is_admin()
    or exists (
      select 1
      from public.contract_consents consent
      where consent.id = contract_consent_id
        and consent.signer_user_id = (select auth.uid())
    )
  )
);

revoke all on function public.preview_guardian_registration(text)
  from public, anon, authenticated, service_role;
grant execute on function public.preview_guardian_registration(text)
  to anon, authenticated;

revoke all on function public.guardian_registration_contract_manifest(text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.guardian_registration_contract_manifest(text, uuid)
  to service_role;

revoke all on function public.record_guardian_registration_acceptance(
  text,
  uuid,
  text,
  text
) from public, anon, authenticated, service_role;
grant execute on function public.record_guardian_registration_acceptance(
  text,
  uuid,
  text,
  text
) to service_role;

revoke all on function public.claim_guardian_link_code(text)
  from public, anon, authenticated, service_role;
grant execute on function public.claim_guardian_link_code(text)
  to authenticated;

commit;
