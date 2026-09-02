begin;

alter table public.billing_invoices
  add column learner_ids uuid[] not null default '{}'::uuid[];

-- Existing invoices were family-wide. Give every version in the same historical
-- series one stable scope, using billed learners first and current profiles as
-- a fallback for invoices that only contained family-level charges.
update public.billing_invoices invoice
set learner_ids = coalesce(
  (
    select array_agg(distinct item.student_id order by item.student_id)
    from public.billing_invoices series_invoice
    join public.billing_invoice_items item
      on item.invoice_id = series_invoice.id
     and item.organization_id = series_invoice.organization_id
    where series_invoice.organization_id = invoice.organization_id
      and series_invoice.guardian_id = invoice.guardian_id
      and series_invoice.term_id is not distinct from invoice.term_id
      and item.student_id is not null
  ),
  (
    select array_agg(student.id order by student.id)
    from public.students student
    where student.organization_id = invoice.organization_id
      and student.guardian_id = invoice.guardian_id
  ),
  '{}'::uuid[]
);

drop index if exists public.billing_invoices_one_root_per_family_term_idx;

create unique index billing_invoices_one_root_per_family_term_scope_idx
  on public.billing_invoices (organization_id, guardian_id, term_id, learner_ids)
  where supersedes_invoice_id is null;

create or replace function private.validate_billing_invoice_series_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  previous_invoice public.billing_invoices%rowtype;
  normalized_learner_ids uuid[];
begin
  if new.term_id is null then
    raise exception 'Invoice must belong to a term' using errcode = '23514';
  end if;

  select coalesce(array_agg(distinct learner_id order by learner_id), '{}'::uuid[])
  into normalized_learner_ids
  from unnest(coalesce(new.learner_ids, '{}'::uuid[])) learner_id;

  if cardinality(normalized_learner_ids) < 1
     or cardinality(normalized_learner_ids) > 20 then
    raise exception 'Invoice requires between 1 and 20 learners' using errcode = '23514';
  end if;

  if exists (
    select 1
    from unnest(normalized_learner_ids) learner_id
    left join public.students student
      on student.id = learner_id
     and student.organization_id = new.organization_id
     and student.guardian_id = new.guardian_id
    where student.id is null
  ) then
    raise exception 'Every invoice learner must belong to the selected family'
      using errcode = '23514';
  end if;

  new.learner_ids := normalized_learner_ids;

  if new.supersedes_invoice_id is null then
    if exists (
      select 1
      from public.billing_invoices invoice
      where invoice.organization_id = new.organization_id
        and invoice.guardian_id = new.guardian_id
        and invoice.term_id = new.term_id
        and invoice.learner_ids = new.learner_ids
        and invoice.supersedes_invoice_id is null
        and invoice.id <> new.id
    ) then
      raise exception 'These learners already have an invoice for this term; create a new version'
        using errcode = '23514';
    end if;
  else
    select * into previous_invoice
    from public.billing_invoices invoice
    where invoice.id = new.supersedes_invoice_id
      and invoice.organization_id = new.organization_id;

    if not found
       or previous_invoice.guardian_id <> new.guardian_id
       or previous_invoice.term_id is distinct from new.term_id
       or previous_invoice.learner_ids is distinct from new.learner_ids
       or previous_invoice.invoice_number <> new.invoice_number
       or previous_invoice.version + 1 <> new.version
       or previous_invoice.superseded_by_invoice_id is not null then
      raise exception 'Invoice version must continue the latest family, term, and learner scope'
        using errcode = '23514';
    end if;
  end if;

  return new;
end;
$$;

create or replace function private.validate_billing_invoice_item_scope()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  invoice_guardian_id uuid;
  invoice_term_id uuid;
  invoice_learner_ids uuid[];
begin
  select invoice.guardian_id, invoice.term_id, invoice.learner_ids
  into invoice_guardian_id, invoice_term_id, invoice_learner_ids
  from public.billing_invoices invoice
  where invoice.id = new.invoice_id
    and invoice.organization_id = new.organization_id;

  if not found then
    raise exception 'Invoice is unavailable for this line item' using errcode = '23514';
  end if;

  if new.student_id is not null and not (
    new.student_id = any(invoice_learner_ids)
    and exists (
      select 1
      from public.students student
      where student.id = new.student_id
        and student.organization_id = new.organization_id
        and student.guardian_id = invoice_guardian_id
    )
  ) then
    raise exception 'Billed learner is outside the invoice learner scope' using errcode = '23514';
  end if;

  if new.enrollment_id is not null and not exists (
    select 1
    from public.enrollments enrollment
    where enrollment.id = new.enrollment_id
      and enrollment.student_id = new.student_id
      and enrollment.organization_id = new.organization_id
      and enrollment.term_id = invoice_term_id
  ) then
    raise exception 'Billed enrollment does not match the invoice learner and term'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create or replace function private.issue_billing_invoice_scoped(
  target_invoice_id uuid,
  target_guardian_id uuid,
  target_term_id uuid,
  target_learner_ids uuid[],
  target_invoice_number text,
  target_version integer,
  target_school_year_label text,
  target_issued_at timestamptz,
  target_notes text,
  target_supersedes_invoice_id uuid,
  target_artifact_id uuid,
  target_storage_path text,
  target_items jsonb
)
returns public.billing_invoices
language plpgsql
security definer
set search_path = ''
as $$
declare
  organization_id_value uuid;
  previous_invoice public.billing_invoices%rowtype;
  created_invoice public.billing_invoices%rowtype;
  normalized_learner_ids uuid[];
  calculated_total bigint;
  item_count integer;
begin
  if not private.is_admin() then
    raise exception 'Only administrators may issue invoices' using errcode = '42501';
  end if;

  organization_id_value := private.current_user_organization_id();
  if organization_id_value is null then
    raise exception 'Administrator organization is unavailable' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.guardians guardian
    where guardian.id = target_guardian_id
      and guardian.organization_id = organization_id_value
  ) then
    raise exception 'Guardian is unavailable' using errcode = '23503';
  end if;

  if target_term_id is null or not exists (
    select 1 from public.terms term
    where term.id = target_term_id
      and term.organization_id = organization_id_value
  ) then
    raise exception 'Term is unavailable' using errcode = '23503';
  end if;

  select coalesce(array_agg(distinct learner_id order by learner_id), '{}'::uuid[])
  into normalized_learner_ids
  from unnest(coalesce(target_learner_ids, '{}'::uuid[])) learner_id;

  if cardinality(normalized_learner_ids) < 1
     or cardinality(normalized_learner_ids) > 20
     or exists (
       select 1
       from unnest(normalized_learner_ids) learner_id
       left join public.students student
         on student.id = learner_id
        and student.organization_id = organization_id_value
        and student.guardian_id = target_guardian_id
       where student.id is null
     ) then
    raise exception 'Invoice learner scope is invalid' using errcode = '23514';
  end if;

  if target_storage_path !~ (
    '^' || organization_id_value::text || '/' || target_guardian_id::text || '/'
  ) then
    raise exception 'Invoice storage path does not match its family' using errcode = '23514';
  end if;

  select count(*),
         coalesce(sum(case when coalesce(item.included_in_amount_due, true)
                           then item.amount_cents else 0 end), 0)
  into item_count, calculated_total
  from jsonb_to_recordset(coalesce(target_items, '[]'::jsonb)) as item(
    id uuid,
    student_id uuid,
    enrollment_id uuid,
    kind text,
    title text,
    detail text,
    quantity integer,
    unit_amount_cents integer,
    amount_cents integer,
    included_in_amount_due boolean,
    sort_order integer
  );

  if item_count < 1 or item_count > 40 then
    raise exception 'Invoice requires between 1 and 40 line items' using errcode = '23514';
  end if;
  if calculated_total < 0 or calculated_total > 2147483647 then
    raise exception 'Invoice amount is outside the supported range' using errcode = '23514';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(target_items) as item(student_id uuid)
    where item.student_id is not null
      and not (item.student_id = any(normalized_learner_ids))
  ) then
    raise exception 'Every billed learner must be inside the invoice learner scope'
      using errcode = '23514';
  end if;

  if target_supersedes_invoice_id is null then
    if target_version <> 1 then
      raise exception 'A new invoice must start at version 1' using errcode = '23514';
    end if;
  else
    select * into previous_invoice
    from public.billing_invoices invoice
    where invoice.id = target_supersedes_invoice_id
      and invoice.organization_id = organization_id_value
    for update;

    if not found
       or previous_invoice.guardian_id <> target_guardian_id
       or previous_invoice.term_id is distinct from target_term_id
       or previous_invoice.learner_ids is distinct from normalized_learner_ids
       or previous_invoice.invoice_number <> btrim(target_invoice_number)
       or previous_invoice.version + 1 <> target_version
       or previous_invoice.superseded_by_invoice_id is not null then
      raise exception 'Invoice version lineage is invalid' using errcode = '23514';
    end if;
  end if;

  insert into public.billing_invoices (
    id,
    organization_id,
    guardian_id,
    term_id,
    learner_ids,
    invoice_number,
    version,
    school_year_label,
    issued_at,
    amount_due_cents,
    notes,
    supersedes_invoice_id,
    created_by
  ) values (
    target_invoice_id,
    organization_id_value,
    target_guardian_id,
    target_term_id,
    normalized_learner_ids,
    btrim(target_invoice_number),
    target_version,
    btrim(target_school_year_label),
    target_issued_at,
    calculated_total::integer,
    nullif(btrim(target_notes), ''),
    target_supersedes_invoice_id,
    (select auth.uid())
  )
  returning * into created_invoice;

  insert into public.billing_invoice_items (
    id,
    organization_id,
    invoice_id,
    student_id,
    enrollment_id,
    kind,
    title,
    detail,
    quantity,
    unit_amount_cents,
    amount_cents,
    included_in_amount_due,
    sort_order
  )
  select
    coalesce(item.id, gen_random_uuid()),
    organization_id_value,
    target_invoice_id,
    item.student_id,
    item.enrollment_id,
    item.kind::public.billing_line_item_kind,
    btrim(item.title),
    nullif(btrim(item.detail), ''),
    coalesce(item.quantity, 1),
    item.unit_amount_cents,
    item.amount_cents,
    coalesce(item.included_in_amount_due, true),
    coalesce(item.sort_order, 0)
  from jsonb_to_recordset(target_items) as item(
    id uuid,
    student_id uuid,
    enrollment_id uuid,
    kind text,
    title text,
    detail text,
    quantity integer,
    unit_amount_cents integer,
    amount_cents integer,
    included_in_amount_due boolean,
    sort_order integer
  );

  insert into public.billing_artifacts (
    id,
    organization_id,
    invoice_id,
    kind,
    storage_path,
    generated_by,
    generated_at
  ) values (
    target_artifact_id,
    organization_id_value,
    target_invoice_id,
    'invoice',
    target_storage_path,
    (select auth.uid()),
    target_issued_at
  );

  if target_supersedes_invoice_id is not null then
    update public.billing_invoices
    set superseded_by_invoice_id = target_invoice_id
    where id = target_supersedes_invoice_id;
  end if;

  return created_invoice;
end;
$$;

-- Compatibility entry point for already-distributed clients. Their family-wide
-- invoices derive the learner scope from line items, then all family profiles.
create or replace function public.admin_issue_billing_invoice(
  target_invoice_id uuid,
  target_guardian_id uuid,
  target_term_id uuid,
  target_invoice_number text,
  target_version integer,
  target_school_year_label text,
  target_issued_at timestamptz,
  target_notes text,
  target_supersedes_invoice_id uuid,
  target_artifact_id uuid,
  target_storage_path text,
  target_items jsonb
)
returns public.billing_invoices
language plpgsql
security definer
set search_path = ''
as $$
declare
  derived_learner_ids uuid[];
begin
  select array_agg(distinct item.student_id order by item.student_id)
  into derived_learner_ids
  from jsonb_to_recordset(coalesce(target_items, '[]'::jsonb)) as item(student_id uuid)
  where item.student_id is not null;

  if coalesce(cardinality(derived_learner_ids), 0) = 0 then
    select array_agg(student.id order by student.id)
    into derived_learner_ids
    from public.students student
    where student.guardian_id = target_guardian_id
      and student.organization_id = private.current_user_organization_id();
  end if;

  return private.issue_billing_invoice_scoped(
    target_invoice_id,
    target_guardian_id,
    target_term_id,
    derived_learner_ids,
    target_invoice_number,
    target_version,
    target_school_year_label,
    target_issued_at,
    target_notes,
    target_supersedes_invoice_id,
    target_artifact_id,
    target_storage_path,
    target_items
  );
end;
$$;

create or replace function public.admin_issue_billing_invoice_scoped_dual(
  target_invoice_id uuid,
  target_guardian_id uuid,
  target_term_id uuid,
  target_learner_ids uuid[],
  target_invoice_number text,
  target_version integer,
  target_school_year_label text,
  target_issued_at timestamptz,
  target_notes text,
  target_supersedes_invoice_id uuid,
  target_bilingual_artifact_id uuid,
  target_bilingual_storage_path text,
  target_english_artifact_id uuid,
  target_english_storage_path text,
  target_items jsonb
)
returns public.billing_invoices
language plpgsql
security definer
set search_path = ''
as $$
declare
  created_invoice public.billing_invoices%rowtype;
begin
  created_invoice := private.issue_billing_invoice_scoped(
    target_invoice_id,
    target_guardian_id,
    target_term_id,
    target_learner_ids,
    target_invoice_number,
    target_version,
    target_school_year_label,
    target_issued_at,
    target_notes,
    target_supersedes_invoice_id,
    target_bilingual_artifact_id,
    target_bilingual_storage_path,
    target_items
  );

  if target_english_storage_path !~ (
    '^' || created_invoice.organization_id::text || '/' || target_guardian_id::text || '/'
  ) or target_english_storage_path !~ '-en[.]png$' then
    raise exception 'English invoice storage path is invalid' using errcode = '23514';
  end if;

  insert into public.billing_artifacts (
    id,
    organization_id,
    invoice_id,
    kind,
    storage_path,
    generated_by,
    generated_at
  ) values (
    target_english_artifact_id,
    created_invoice.organization_id,
    target_invoice_id,
    'invoice',
    target_english_storage_path,
    (select auth.uid()),
    target_issued_at
  );

  return created_invoice;
end;
$$;

revoke all on function private.issue_billing_invoice_scoped(
  uuid, uuid, uuid, uuid[], text, integer, text, timestamptz, text, uuid,
  uuid, text, jsonb
) from public;

revoke all on function public.admin_issue_billing_invoice_scoped_dual(
  uuid, uuid, uuid, uuid[], text, integer, text, timestamptz, text, uuid,
  uuid, text, uuid, text, jsonb
) from public, anon, authenticated, service_role;
grant execute on function public.admin_issue_billing_invoice_scoped_dual(
  uuid, uuid, uuid, uuid[], text, integer, text, timestamptz, text, uuid,
  uuid, text, uuid, text, jsonb
) to authenticated;

comment on column public.billing_invoices.learner_ids is
  'Immutable sorted learner scope for this invoice series. One or more learners may share a family invoice.';
comment on index public.billing_invoices_one_root_per_family_term_scope_idx is
  'One root invoice series per family, term, and exact learner combination.';
comment on function private.validate_billing_invoice_series_insert() is
  'Preserves one immutable family-term-learner version lineage.';
comment on function private.validate_billing_invoice_item_scope() is
  'Keeps every learner line inside the invoice learner scope and term.';

notify pgrst, 'reload schema';

commit;
