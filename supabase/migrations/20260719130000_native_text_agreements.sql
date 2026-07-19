begin;

alter table public.contract_documents
  add column if not exists body_text text;

update public.contract_documents
set body_text = $agreement$
重要提示

本协议仅用于 Master Dance 系统功能测试，不是最终法律文件。学校正式启用前，应由负责人审核并替换全部内容。

1. 课程安排

学校会根据学期计划安排课程、教室与授课老师。必要时，学校可以提前通知后调整课程时间、教室或授课老师。

2. 学员出勤

监护人应协助学员按时到课。迟到、缺席、请假、补课与试课记录以学校教务系统中的记录为准。

3. 请假与补课

请假应通过学校认可的方式提交。补课资格、可选课程和有效期限由学校当期规则决定。

4. 健康与安全

监护人应如实告知可能影响训练的健康情况，并确保学员遵守课堂安全要求和教师指导。

5. 通知与联系

学校可以通过 App、电子邮件、电话或其他已约定方式发送课程变动、签到和教务通知。

6. 电子签署

监护人在 App 中完成手写签名并点击“同意”后，表示已经阅读并接受当前显示版本。协议内容更新后，需要重新阅读并签署新版本。

7. 测试声明

当前文字为占位内容。请教务老师在正式使用前完成修改、审核和发布。
$agreement$
where body_text is null or length(btrim(body_text)) < 20;

alter table public.contract_documents
  alter column body_text set default '',
  alter column body_text set not null,
  alter column storage_path set default '';

alter table public.contract_documents
  drop constraint if exists contract_documents_storage_path_key;

create unique index if not exists contract_documents_nonempty_storage_path_key
  on public.contract_documents (storage_path)
  where storage_path <> '';

alter table public.contract_documents
  drop constraint if exists contract_documents_body_text_check;
alter table public.contract_documents
  add constraint contract_documents_body_text_check
  check (length(btrim(body_text)) between 20 and 50000) not valid;
alter table public.contract_documents
  validate constraint contract_documents_body_text_check;

with ranked_terms as (
  select
    t.*,
    row_number() over (
      partition by t.organization_id
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
        t.starts_on desc
    ) as organization_rank
  from public.terms t
)
insert into public.contract_documents (
  organization_id,
  term_id,
  version,
  title,
  body_text,
  storage_path,
  status,
  published_at
)
select
  term.organization_id,
  term.id,
  'v' || (
    coalesce(
      (
        select max(substring(document.version from 2)::integer)
        from public.contract_documents document
        where document.term_id = term.id
          and document.version ~ '^v[0-9]+$'
      ),
      0
    ) + 1
  )::text,
  'Master Dance 学员服务协议（测试版）',
  $agreement$
重要提示

本协议仅用于 Master Dance 系统功能测试，不是最终法律文件。学校正式启用前，应由负责人审核并替换全部内容。

1. 课程安排

学校会根据学期计划安排课程、教室与授课老师。必要时，学校可以提前通知后调整课程时间、教室或授课老师。

2. 学员出勤

监护人应协助学员按时到课。迟到、缺席、请假、补课与试课记录以学校教务系统中的记录为准。

3. 请假与补课

请假应通过学校认可的方式提交。补课资格、可选课程和有效期限由学校当期规则决定。

4. 健康与安全

监护人应如实告知可能影响训练的健康情况，并确保学员遵守课堂安全要求和教师指导。

5. 通知与联系

学校可以通过 App、电子邮件、电话或其他已约定方式发送课程变动、签到和教务通知。

6. 电子签署

监护人在 App 中完成手写签名并点击“同意”后，表示已经阅读并接受当前显示版本。协议内容更新后，需要重新阅读并签署新版本。

7. 测试声明

当前文字为占位内容。请教务老师在正式使用前完成修改、审核和发布。
$agreement$,
  '',
  'published'::public.contract_document_status,
  now()
from ranked_terms term
where term.organization_rank = 1
  and not exists (
    select 1
    from public.contract_documents document
    where document.organization_id = term.organization_id
      and document.status = 'published'::public.contract_document_status
  );

create or replace function private.contract_content_sha256(
  target_document_id uuid
)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select encode(
    extensions.digest(
      convert_to(d.title || E'\n' || d.version || E'\n' || d.body_text, 'UTF8'),
      'sha256'
    ),
    'hex'
  )
  from public.contract_documents d
  where d.id = target_document_id
$$;

revoke execute on function private.contract_content_sha256(uuid)
  from public, anon, authenticated;

create or replace function public.admin_publish_contract_revision(
  target_term_id uuid,
  document_title text,
  document_body_text text
)
returns public.contract_documents
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
  organization_id_value uuid := private.current_user_organization_id();
  normalized_title text := btrim(coalesce(document_title, ''));
  normalized_body text := btrim(coalesce(document_body_text, ''));
  next_version_number integer;
  resulting_document public.contract_documents;
begin
  if current_user_id is null or not private.is_admin() then
    raise exception 'Administrator access required' using errcode = '42501';
  end if;

  if length(normalized_title) not between 1 and 160 then
    raise exception 'Agreement title is required' using errcode = '23514';
  end if;

  if length(normalized_body) not between 20 and 50000 then
    raise exception 'Agreement body must contain 20 to 50000 characters'
      using errcode = '23514';
  end if;

  perform 1
  from public.terms term
  where term.id = target_term_id
    and term.organization_id = organization_id_value
  for update;

  if not found then
    raise exception 'Term not found' using errcode = 'P0002';
  end if;

  select coalesce(max(substring(document.version from 2)::integer), 0) + 1
  into next_version_number
  from public.contract_documents document
  where document.term_id = target_term_id
    and document.version ~ '^v[0-9]+$';

  update public.contract_documents
  set status = 'retired'::public.contract_document_status
  where organization_id = organization_id_value
    and term_id = target_term_id
    and status = 'published'::public.contract_document_status;

  insert into public.contract_documents (
    organization_id,
    term_id,
    version,
    title,
    body_text,
    storage_path,
    status,
    published_at,
    created_by
  )
  values (
    organization_id_value,
    target_term_id,
    'v' || next_version_number::text,
    normalized_title,
    normalized_body,
    '',
    'published'::public.contract_document_status,
    now(),
    current_user_id
  )
  returning * into resulting_document;

  return resulting_document;
end;
$$;

revoke all on function public.admin_publish_contract_revision(uuid, text, text)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_publish_contract_revision(uuid, text, text)
  to authenticated;

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
    'body_text', contract_value.body_text,
    'content_sha256', private.contract_content_sha256(contract_value.id)
  );
end;
$$;

create or replace function public.record_guardian_registration_agreement_acceptance(
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
  normalized_hash text := lower(btrim(coalesce(contract_sha256, '')));
  expected_hash text;
  resulting_acceptance jsonb;
begin
  expected_hash := private.contract_content_sha256(target_document_id);
  if expected_hash is null or normalized_hash is distinct from expected_hash then
    raise exception 'Registration contract changed'
      using errcode = 'P0001';
  end if;

  select public.record_guardian_registration_acceptance(
    claim_code,
    target_document_id,
    signature_base64,
    normalized_hash
  ) into resulting_acceptance;

  return resulting_acceptance;
end;
$$;

alter table public.contract_consent_signatures
  drop constraint if exists contract_consent_signatures_source_check;
alter table public.contract_consent_signatures
  add constraint contract_consent_signatures_source_check
  check (source in ('ios_registration', 'ios_agreement'));

create or replace function public.current_guardian_agreement()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
  organization_id_value uuid := private.current_user_organization_id();
  contract_value public.contract_documents;
  content_hash_value text;
  accepted_at_value timestamptz;
begin
  if current_user_id is null
     or private.current_user_role() is distinct from 'guardian'::public.app_role then
    raise exception 'Guardian access required' using errcode = '42501';
  end if;

  contract_value := private.current_registration_contract(organization_id_value);
  if contract_value.id is null then
    return jsonb_build_object('agreement', null);
  end if;

  content_hash_value := private.contract_content_sha256(contract_value.id);

  select consent.consented_at
  into accepted_at_value
  from public.contract_consents consent
  join public.contract_consent_signatures signature
    on signature.contract_consent_id = consent.id
   and signature.contract_sha256 = content_hash_value
  where consent.contract_document_id = contract_value.id
    and consent.signer_user_id = current_user_id
    and consent.enrollment_id is null
  order by consent.consented_at desc
  limit 1;

  return jsonb_build_object(
    'agreement', jsonb_build_object(
      'id', contract_value.id,
      'term_id', contract_value.term_id,
      'title', contract_value.title,
      'version', contract_value.version,
      'body_text', contract_value.body_text,
      'sha256', content_hash_value,
      'requires_acceptance', accepted_at_value is null,
      'accepted_at', accepted_at_value
    )
  );
end;
$$;

create or replace function public.accept_guardian_agreement(
  target_document_id uuid,
  displayed_contract_sha256 text,
  signature_base64 text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
  organization_id_value uuid := private.current_user_organization_id();
  contract_value public.contract_documents;
  expected_hash text;
  normalized_hash text := lower(btrim(coalesce(displayed_contract_sha256, '')));
  signature_value bytea;
  signer_name_value text;
  consent_id_value uuid;
  accepted_at_value timestamptz := now();
begin
  if current_user_id is null
     or private.current_user_role() is distinct from 'guardian'::public.app_role then
    raise exception 'Guardian access required' using errcode = '42501';
  end if;

  contract_value := private.current_registration_contract(organization_id_value);
  if contract_value.id is null
     or contract_value.id is distinct from target_document_id then
    raise exception 'Agreement changed' using errcode = 'P0001';
  end if;

  expected_hash := private.contract_content_sha256(contract_value.id);
  if expected_hash is null or normalized_hash is distinct from expected_hash then
    raise exception 'Agreement changed' using errcode = 'P0001';
  end if;

  begin
    signature_value := decode(coalesce(signature_base64, ''), 'base64');
  exception when others then
    raise exception 'Invalid agreement signature' using errcode = '22023';
  end;

  if octet_length(signature_value) not between 128 and 524288
     or substring(signature_value from 1 for 8)
        <> decode('89504e470d0a1a0a', 'hex') then
    raise exception 'Invalid agreement signature' using errcode = '22023';
  end if;

  select p.display_name
  into signer_name_value
  from public.profiles p
  where p.user_id = current_user_id
    and p.organization_id = organization_id_value
    and p.is_active;

  if signer_name_value is null then
    raise exception 'Guardian profile is unavailable' using errcode = '42501';
  end if;

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
    contract_value.id,
    contract_value.term_id,
    null,
    'term'::public.contract_consent_scope,
    current_user_id,
    'guardian'::public.consent_signer_kind,
    signer_name_value,
    accepted_at_value
  )
  on conflict (contract_document_id, signer_user_id)
    where enrollment_id is null
  do update set
    signer_display_name = excluded.signer_display_name,
    consented_at = excluded.consented_at
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
    signature_value,
    'image/png',
    expected_hash,
    'ios_agreement',
    accepted_at_value
  )
  on conflict (contract_consent_id) do update set
    signature_png = excluded.signature_png,
    signature_mime_type = excluded.signature_mime_type,
    contract_sha256 = excluded.contract_sha256,
    source = excluded.source,
    signed_at = excluded.signed_at;

  return jsonb_build_object(
    'contract_document_id', contract_value.id,
    'accepted_at', accepted_at_value
  );
end;
$$;

revoke all on function public.guardian_registration_contract_manifest(text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.guardian_registration_contract_manifest(text, uuid)
  to service_role;

revoke all on function public.record_guardian_registration_agreement_acceptance(
  text,
  uuid,
  text,
  text
) from public, anon, authenticated, service_role;
grant execute on function public.record_guardian_registration_agreement_acceptance(
  text,
  uuid,
  text,
  text
) to service_role;

revoke all on function public.current_guardian_agreement()
  from public, anon, authenticated, service_role;
grant execute on function public.current_guardian_agreement()
  to authenticated;

revoke all on function public.accept_guardian_agreement(uuid, text, text)
  from public, anon, authenticated, service_role;
grant execute on function public.accept_guardian_agreement(uuid, text, text)
  to authenticated;

comment on column public.contract_documents.body_text is
  'Native agreement text rendered directly by the macOS and iOS applications.';
comment on function public.current_guardian_agreement() is
  'Returns the current text agreement and whether the signed content hash is current.';
comment on function public.admin_publish_contract_revision(uuid, text, text) is
  'Atomically retires the active agreement and publishes its next immutable version.';

commit;
