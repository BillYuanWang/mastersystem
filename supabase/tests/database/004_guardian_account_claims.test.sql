begin;

create extension if not exists pgtap with schema extensions;

select plan(39);

select has_table('private', 'guardian_link_codes', 'guardian link codes use a private table');
select hasnt_column('private', 'guardian_link_codes', 'link_code', 'raw guardian codes are never stored');
select ok(
  not has_table_privilege('authenticated', 'private.guardian_link_codes', 'SELECT'),
  'authenticated users cannot read guardian code hashes'
);
select ok(
  to_regprocedure('public.admin_issue_guardian_link_code(uuid,integer)') is not null,
  'administrator code-issuance RPC exists'
);
select ok(
  to_regprocedure('public.claim_guardian_link_code(text)') is not null,
  'guardian claim RPC exists'
);
select ok(
  to_regprocedure('public.preview_guardian_registration(text)') is not null,
  'guardian registration preview RPC exists'
);
select has_table(
  'private',
  'guardian_registration_acceptances',
  'pre-auth registration signatures stay private'
);
select has_table(
  'public',
  'contract_consent_signatures',
  'claimed registration signatures have durable evidence'
);
select ok(
  to_regprocedure(
    'public.guardian_registration_contract_manifest(text,uuid)'
  ) is not null,
  'service-only registration contract manifest RPC exists'
);
select ok(
  to_regprocedure(
    'public.record_guardian_registration_acceptance(text,uuid,text,text)'
  ) is not null,
  'service-only registration acceptance RPC exists'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.record_guardian_registration_acceptance(text,uuid,text,text)',
    'EXECUTE'
  ),
  'anonymous callers cannot write registration evidence directly'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.record_guardian_registration_acceptance(text,uuid,text,text)',
    'EXECUTE'
  ),
  'only the trusted contract gateway may record registration evidence'
);
select ok(
  to_regprocedure(
    'public.admin_create_student_for_guardian(uuid,text,text,public.student_kind)'
  ) is not null,
  'family-scoped student creation RPC exists'
);
select ok(
  to_regprocedure('public.admin_link_student_to_guardian(uuid,uuid)') is not null,
  'legacy student-linking RPC exists'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.claim_guardian_link_code(text)',
    'EXECUTE'
  ),
  'anonymous users cannot claim guardian codes'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.claim_guardian_link_code(text)',
    'EXECUTE'
  ),
  'signed-in users may call the guardian claim RPC'
);
select ok(
  has_function_privilege(
    'anon',
    'public.preview_guardian_registration(text)',
    'EXECUTE'
  ),
  'signed-out users may validate a high-entropy guardian invitation'
);

insert into public.organizations (id, name, slug, timezone)
values (
  '92000000-0000-0000-0000-000000000001',
  'Guardian Claim School',
  'guardian-claim-school',
  'America/Los_Angeles'
);

insert into public.terms (
  id,
  organization_id,
  name,
  starts_on,
  ends_on,
  status
)
values (
  '92000000-0000-0000-0000-000000000030',
  '92000000-0000-0000-0000-000000000001',
  'Registration Term',
  current_date - 30,
  current_date + 120,
  'open'
);

insert into public.contract_documents (
  id,
  organization_id,
  term_id,
  version,
  title,
  storage_path,
  status,
  published_at
)
values (
  '92000000-0000-0000-0000-000000000040',
  '92000000-0000-0000-0000-000000000001',
  '92000000-0000-0000-0000-000000000030',
  'registration-v1',
  'Registration Contract',
  '92000000-0000-0000-0000-000000000001/registration-v1.pdf',
  'published',
  now()
);

insert into auth.users (
  id,
  aud,
  role,
  email,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
values
  (
    '92000000-0000-0000-0000-000000000010',
    'authenticated',
    'authenticated',
    'admin@example.test',
    now(),
    '{}'::jsonb,
    '{}'::jsonb,
    now(),
    now()
  ),
  (
    '92000000-0000-0000-0000-000000000011',
    'authenticated',
    'authenticated',
    'family@example.test',
    now(),
    '{}'::jsonb,
    '{}'::jsonb,
    now(),
    now()
  ),
  (
    '92000000-0000-0000-0000-000000000012',
    'authenticated',
    'authenticated',
    'attacker@example.test',
    now(),
    '{}'::jsonb,
    '{}'::jsonb,
    now(),
    now()
  );

insert into public.profiles (
  user_id,
  organization_id,
  role,
  display_name
)
values (
  '92000000-0000-0000-0000-000000000010',
  '92000000-0000-0000-0000-000000000001',
  'administrator',
  'Claim Admin'
);

insert into public.guardians (
  id,
  organization_id,
  display_name,
  email
)
values (
  '92000000-0000-0000-0000-000000000020',
  '92000000-0000-0000-0000-000000000001',
  'Family Account',
  'family@example.test'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '92000000-0000-0000-0000-000000000010',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"92000000-0000-0000-0000-000000000010","role":"authenticated"}',
  true
);

select lives_ok(
  $$
    select public.admin_create_student_for_guardian(
      '92000000-0000-0000-0000-000000000020',
      'Claim Child',
      null,
      'child'
    )
  $$,
  'an administrator can create a child inside a family'
);

select lives_ok(
  $$
    select public.admin_create_student_for_guardian(
      '92000000-0000-0000-0000-000000000020',
      'Adult Self',
      null,
      'adult'
    )
  $$,
  'an adult learner can be a profile inside the same family'
);

select is(
  (
    select count(*)
    from public.guardian_students
    where guardian_id = '92000000-0000-0000-0000-000000000020'
  ),
  2::bigint,
  'one guardian can own multiple learner profiles'
);

select set_config(
  'test.first_guardian_code',
  public.admin_issue_guardian_link_code(
    '92000000-0000-0000-0000-000000000020',
    30
  )->>'link_code',
  true
);

select ok(
  current_setting('test.first_guardian_code') ~
    '^MD-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}$',
  'issued codes are readable and high entropy'
);

select is(
  (
    select count(*)
    from public.admin_list_guardian_link_statuses()
    where guardian_id = '92000000-0000-0000-0000-000000000020'
      and active_code_hint is not null
  ),
  1::bigint,
  'only one active code exists per guardian'
);

select set_config(
  'test.guardian_code',
  public.admin_issue_guardian_link_code(
    '92000000-0000-0000-0000-000000000020',
    30
  )->>'link_code',
  true
);

select isnt(
  current_setting('test.guardian_code'),
  current_setting('test.first_guardian_code'),
  'regenerating a code creates a new secret'
);

select is(
  (
    select count(*)
    from public.admin_list_guardian_link_statuses()
    where guardian_id = '92000000-0000-0000-0000-000000000020'
      and active_code_hint is not null
  ),
  1::bigint,
  'regenerating revokes the prior active code'
);

set local role anon;

select is(
  public.preview_guardian_registration(
    current_setting('test.guardian_code')
  )->>'email',
  'family@example.test',
  'a valid invitation reveals only its locked registration email'
);

select is(
  public.preview_guardian_registration(
    current_setting('test.guardian_code')
  )->'contract'->>'id',
  '92000000-0000-0000-0000-000000000040',
  'registration preview binds the current published contract'
);

select throws_ok(
  $$ select public.preview_guardian_registration('MD-NOT-A-VALID-CODE') $$,
  'P0001',
  'Invalid or expired guardian link code',
  'an invalid invitation cannot preview guardian identity'
);

set local role service_role;

select lives_ok(
  format(
    $sql$
      select public.record_guardian_registration_acceptance(
        %L,
        '92000000-0000-0000-0000-000000000040',
        %L,
        %L
      )
    $sql$,
    current_setting('test.guardian_code'),
    encode(
      decode('89504e470d0a1a0a', 'hex')
        || decode(repeat('00', 128), 'hex'),
      'base64'
    ),
    repeat('a', 64)
  ),
  'the trusted gateway can record the reviewed contract and signature'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '92000000-0000-0000-0000-000000000012',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"92000000-0000-0000-0000-000000000012","role":"authenticated"}',
  true
);

select throws_ok(
  format(
    'select public.claim_guardian_link_code(%L)',
    current_setting('test.guardian_code')
  ),
  '23514',
  'Guardian invitation email does not match authenticated account',
  'an invitation cannot be attached to a different email account'
);

select set_config(
  'request.jwt.claim.sub',
  '92000000-0000-0000-0000-000000000011',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"92000000-0000-0000-0000-000000000011","role":"authenticated"}',
  true
);

select is(
  (select count(*) from public.students),
  0::bigint,
  'an unclaimed Auth account cannot see school data'
);

select lives_ok(
  format(
    'select public.claim_guardian_link_code(%L)',
    current_setting('test.guardian_code')
  ),
  'a signed-in user can claim a valid code once'
);

select is(
  (
    select role::text
    from public.profiles
    where user_id = '92000000-0000-0000-0000-000000000011'
  ),
  'guardian',
  'claiming creates a guardian authorization profile'
);

select is(
  (
    select profile_user_id
    from public.guardians
    where id = '92000000-0000-0000-0000-000000000020'
  ),
  '92000000-0000-0000-0000-000000000011'::uuid,
  'claiming links the Auth account to the guardian record'
);

select is(
  (
    select count(*)
    from public.contract_consents
    where signer_user_id = '92000000-0000-0000-0000-000000000011'
      and contract_document_id = '92000000-0000-0000-0000-000000000040'
      and scope = 'term'
  ),
  1::bigint,
  'claiming converts the pending acceptance into a term consent'
);

select is(
  (
    select count(*)
    from public.contract_consent_signatures signature
    join public.contract_consents consent
      on consent.id = signature.contract_consent_id
    where consent.signer_user_id = '92000000-0000-0000-0000-000000000011'
      and signature.contract_sha256 = repeat('a', 64)
  ),
  1::bigint,
  'claiming preserves the signed contract hash and signature evidence'
);

select is(
  (select count(*) from public.students),
  2::bigint,
  'the claimed family account sees both child and adult learners'
);

select set_config(
  'request.jwt.claim.sub',
  '92000000-0000-0000-0000-000000000012',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"92000000-0000-0000-0000-000000000012","role":"authenticated"}',
  true
);

select is(
  (select count(*) from public.students),
  0::bigint,
  'another unclaimed account cannot see the claimed family'
);

select throws_ok(
  format(
    'select public.claim_guardian_link_code(%L)',
    current_setting('test.guardian_code')
  ),
  'P0001',
  'Invalid or expired guardian link code',
  'a consumed guardian code cannot be reused'
);

select set_config(
  'request.jwt.claim.sub',
  '92000000-0000-0000-0000-000000000010',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"92000000-0000-0000-0000-000000000010","role":"authenticated"}',
  true
);

select throws_ok(
  $$
    select public.admin_issue_guardian_link_code(
      '92000000-0000-0000-0000-000000000020',
      30
    )
  $$,
  '23514',
  'Guardian is already linked to an account',
  'an administrator cannot issue a code for a linked guardian'
);

select * from finish();
rollback;
