begin;

create type public.course_pricing_status as enum (
  'pending',
  'priced',
  'free',
  'review_required'
);

create type public.enrollment_pricing_status as enum (
  'pending',
  'ready',
  'review_required'
);

create type public.billing_discount_kind as enum (
  'percentage',
  'fixed_amount'
);

create type public.billing_line_item_kind as enum (
  'tuition',
  'trial',
  'registration',
  'discount',
  'balance_credit',
  'prior_balance',
  'manual'
);

create type public.billing_payment_method as enum (
  'cash',
  'check',
  'zelle',
  'card'
);

create type public.billing_artifact_kind as enum (
  'invoice',
  'receipt'
);

alter table public.courses
  add column pricing_status public.course_pricing_status not null default 'pending',
  add column unit_price_cents integer;

alter table public.courses
  add constraint courses_unit_price_nonnegative
    check (unit_price_cents is null or unit_price_cents >= 0),
  add constraint courses_pricing_state_consistency
    check (
      (pricing_status = 'pending' and unit_price_cents is null)
      or (pricing_status = 'priced' and unit_price_cents > 0)
      or (pricing_status = 'free' and unit_price_cents = 0)
      or (pricing_status = 'review_required' and (unit_price_cents is null or unit_price_cents >= 0))
    );

comment on column public.courses.unit_price_cents is
  'Standard per-session tuition stored as integer US cents. Semester totals are derived from actual scheduled sessions.';

alter table public.enrollments
  add column pricing_status public.enrollment_pricing_status not null default 'pending',
  add column billing_starts_on date,
  add column unit_price_cents integer,
  add column trial_fee_cents integer not null default 0,
  add column discount_name text,
  add column discount_kind public.billing_discount_kind,
  add column discount_value integer,
  add column billing_notes text;

alter table public.enrollments
  add constraint enrollments_unit_price_nonnegative
    check (unit_price_cents is null or unit_price_cents >= 0),
  add constraint enrollments_trial_fee_nonnegative
    check (trial_fee_cents >= 0),
  add constraint enrollments_discount_consistency
    check (
      (
        discount_kind is null
        and discount_value is null
        and discount_name is null
      )
      or (
        discount_kind = 'percentage'
        and discount_value between 1 and 10000
        and discount_name is not null
        and length(btrim(discount_name)) between 1 and 80
      )
      or (
        discount_kind = 'fixed_amount'
        and discount_value > 0
        and discount_name is not null
        and length(btrim(discount_name)) between 1 and 80
      )
    ),
  add constraint enrollments_ready_pricing_consistency
    check (
      pricing_status <> 'ready'
      or (unit_price_cents is not null and billing_starts_on is not null)
    ),
  add constraint enrollments_billing_notes_length
    check (billing_notes is null or length(billing_notes) <= 1000);

comment on column public.enrollments.unit_price_cents is
  'Enrollment price snapshot. Later course price changes do not rewrite this value.';
comment on column public.enrollments.discount_value is
  'Basis points for percentage discounts (10000 = 100%), or integer cents for fixed discounts.';

create table public.billing_invoices (
  id uuid primary key,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  guardian_id uuid not null,
  term_id uuid,
  invoice_number text not null check (length(btrim(invoice_number)) between 1 and 80),
  version integer not null check (version >= 1),
  school_year_label text not null check (length(btrim(school_year_label)) between 1 and 40),
  issued_at timestamptz not null,
  currency text not null default 'USD' check (currency = 'USD'),
  amount_due_cents integer not null check (amount_due_cents >= 0),
  notes text check (notes is null or length(notes) <= 2000),
  supersedes_invoice_id uuid,
  superseded_by_invoice_id uuid,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint billing_invoices_guardian_fk
    foreign key (guardian_id, organization_id)
    references public.guardians(id, organization_id) on delete restrict,
  constraint billing_invoices_term_fk
    foreign key (term_id, organization_id)
    references public.terms(id, organization_id) on delete restrict,
  constraint billing_invoices_id_organization_key unique (id, organization_id),
  constraint billing_invoices_number_version_key
    unique (organization_id, invoice_number, version),
  constraint billing_invoices_version_lineage
    check (
      (version = 1 and supersedes_invoice_id is null)
      or (version > 1 and supersedes_invoice_id is not null)
    ),
  constraint billing_invoices_not_self_superseding
    check (supersedes_invoice_id is distinct from id and superseded_by_invoice_id is distinct from id)
);

alter table public.billing_invoices
  add constraint billing_invoices_supersedes_fk
    foreign key (supersedes_invoice_id, organization_id)
    references public.billing_invoices(id, organization_id) on delete restrict,
  add constraint billing_invoices_superseded_by_fk
    foreign key (superseded_by_invoice_id, organization_id)
    references public.billing_invoices(id, organization_id) on delete restrict;

create index billing_invoices_guardian_time_idx
  on public.billing_invoices (guardian_id, issued_at desc);
create index billing_invoices_term_time_idx
  on public.billing_invoices (term_id, issued_at desc);

create table public.billing_invoice_items (
  id uuid primary key,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  invoice_id uuid not null,
  student_id uuid,
  enrollment_id uuid,
  kind public.billing_line_item_kind not null,
  title text not null check (length(btrim(title)) between 1 and 160),
  detail text check (detail is null or length(detail) <= 500),
  quantity integer not null default 1 check (quantity between 1 and 999),
  unit_amount_cents integer not null check (abs(unit_amount_cents) <= 100000000),
  amount_cents integer not null check (abs(amount_cents) <= 100000000),
  included_in_amount_due boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  constraint billing_invoice_items_invoice_fk
    foreign key (invoice_id, organization_id)
    references public.billing_invoices(id, organization_id) on delete restrict,
  constraint billing_invoice_items_student_fk
    foreign key (student_id, organization_id)
    references public.students(id, organization_id) on delete restrict,
  constraint billing_invoice_items_enrollment_fk
    foreign key (enrollment_id, organization_id)
    references public.enrollments(id, organization_id) on delete restrict,
  constraint billing_invoice_items_id_organization_key unique (id, organization_id)
);

create index billing_invoice_items_invoice_order_idx
  on public.billing_invoice_items (invoice_id, sort_order, created_at);
create index billing_invoice_items_student_idx
  on public.billing_invoice_items (student_id, created_at desc);

create table public.billing_payments (
  id uuid primary key,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  invoice_id uuid not null,
  amount_cents integer not null check (amount_cents > 0),
  processing_fee_cents integer not null default 0 check (processing_fee_cents >= 0),
  method public.billing_payment_method not null,
  received_at timestamptz not null,
  note text check (note is null or length(note) <= 1000),
  recorded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint billing_payments_invoice_fk
    foreign key (invoice_id, organization_id)
    references public.billing_invoices(id, organization_id) on delete restrict,
  constraint billing_payments_fee_consistency
    check (
      (method = 'card' and processing_fee_cents >= 0)
      or (method <> 'card' and processing_fee_cents = 0)
    ),
  constraint billing_payments_id_organization_key unique (id, organization_id)
);

create index billing_payments_invoice_time_idx
  on public.billing_payments (invoice_id, received_at);

create table public.billing_artifacts (
  id uuid primary key,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  invoice_id uuid not null,
  payment_id uuid,
  kind public.billing_artifact_kind not null,
  storage_path text not null check (storage_path !~ '^/' and storage_path !~ '\.\.'),
  mime_type text not null default 'image/png' check (mime_type = 'image/png'),
  generated_by uuid references auth.users(id) on delete set null,
  generated_at timestamptz not null default now(),
  constraint billing_artifacts_invoice_fk
    foreign key (invoice_id, organization_id)
    references public.billing_invoices(id, organization_id) on delete restrict,
  constraint billing_artifacts_payment_fk
    foreign key (payment_id, organization_id)
    references public.billing_payments(id, organization_id) on delete restrict,
  constraint billing_artifacts_kind_consistency
    check (
      (kind = 'invoice' and payment_id is null)
      or (kind = 'receipt' and payment_id is not null)
    ),
  constraint billing_artifacts_storage_path_key unique (storage_path),
  constraint billing_artifacts_id_organization_key unique (id, organization_id)
);

create index billing_artifacts_invoice_time_idx
  on public.billing_artifacts (invoice_id, generated_at desc);

create or replace function private.can_access_billing_invoice(target_invoice_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    exists (
      select 1
      from public.billing_invoices i
      join public.guardians g
        on g.id = i.guardian_id
       and g.organization_id = i.organization_id
      where i.id = target_invoice_id
        and i.organization_id = private.current_user_organization_id()
        and (
          private.is_admin()
          or g.profile_user_id = (select auth.uid())
        )
    ),
    false
  )
$$;

create or replace function private.can_access_billing_object(target_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    exists (
      select 1
      from public.billing_artifacts a
      where a.storage_path = target_path
        and private.can_access_billing_invoice(a.invoice_id)
    ),
    false
  )
$$;

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
  organization_id_value uuid;
  previous_invoice public.billing_invoices%rowtype;
  created_invoice public.billing_invoices%rowtype;
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
    select 1 from public.guardians g
    where g.id = target_guardian_id
      and g.organization_id = organization_id_value
  ) then
    raise exception 'Guardian is unavailable' using errcode = '23503';
  end if;

  if target_term_id is not null and not exists (
    select 1 from public.terms t
    where t.id = target_term_id
      and t.organization_id = organization_id_value
  ) then
    raise exception 'Term is unavailable' using errcode = '23503';
  end if;

  if target_storage_path !~ (
    '^' || organization_id_value::text || '/' || target_guardian_id::text || '/'
  ) then
    raise exception 'Invoice storage path does not match its family' using errcode = '23514';
  end if;

  select count(*),
         coalesce(sum(case when coalesce(x.included_in_amount_due, true) then x.amount_cents else 0 end), 0)
  into item_count, calculated_total
  from jsonb_to_recordset(coalesce(target_items, '[]'::jsonb)) as x(
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
    from jsonb_to_recordset(target_items) as x(student_id uuid)
    left join public.students s
      on s.id = x.student_id
     and s.organization_id = organization_id_value
    where x.student_id is not null
      and (s.id is null or s.guardian_id <> target_guardian_id)
  ) then
    raise exception 'Every billed learner must belong to the selected family' using errcode = '23514';
  end if;

  if target_supersedes_invoice_id is null then
    if target_version <> 1 then
      raise exception 'A new invoice must start at version 1' using errcode = '23514';
    end if;
  else
    select * into previous_invoice
    from public.billing_invoices i
    where i.id = target_supersedes_invoice_id
      and i.organization_id = organization_id_value
    for update;

    if not found
       or previous_invoice.guardian_id <> target_guardian_id
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
    coalesce(x.id, gen_random_uuid()),
    organization_id_value,
    target_invoice_id,
    x.student_id,
    x.enrollment_id,
    x.kind::public.billing_line_item_kind,
    btrim(x.title),
    nullif(btrim(x.detail), ''),
    coalesce(x.quantity, 1),
    x.unit_amount_cents,
    x.amount_cents,
    coalesce(x.included_in_amount_due, true),
    coalesce(x.sort_order, 0)
  from jsonb_to_recordset(target_items) as x(
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

create or replace function public.admin_record_billing_payment(
  target_payment_id uuid,
  target_invoice_id uuid,
  target_amount_cents integer,
  target_processing_fee_cents integer,
  target_method public.billing_payment_method,
  target_received_at timestamptz,
  target_note text,
  target_artifact_id uuid,
  target_storage_path text
)
returns public.billing_payments
language plpgsql
security definer
set search_path = ''
as $$
declare
  organization_id_value uuid;
  invoice_value public.billing_invoices%rowtype;
  paid_cents bigint;
  outstanding_cents bigint;
  expected_fee integer;
  created_payment public.billing_payments%rowtype;
begin
  if not private.is_admin() then
    raise exception 'Only administrators may record payments' using errcode = '42501';
  end if;

  organization_id_value := private.current_user_organization_id();
  select * into invoice_value
  from public.billing_invoices i
  where i.id = target_invoice_id
    and i.organization_id = organization_id_value
  for update;

  if not found or invoice_value.superseded_by_invoice_id is not null then
    raise exception 'Invoice is unavailable for payment' using errcode = '23514';
  end if;

  select coalesce(sum(p.amount_cents), 0)
  into paid_cents
  from public.billing_payments p
  where p.invoice_id = target_invoice_id;
  outstanding_cents := invoice_value.amount_due_cents - paid_cents;

  if target_amount_cents <= 0 or target_amount_cents > outstanding_cents then
    raise exception 'Payment must be positive and cannot exceed the outstanding balance' using errcode = '23514';
  end if;

  expected_fee := case
    when target_method = 'card' then ((target_amount_cents::bigint * 350 + 5000) / 10000)::integer
    else 0
  end;
  if target_processing_fee_cents <> expected_fee then
    raise exception 'Payment processing fee is incorrect' using errcode = '23514';
  end if;

  if target_storage_path !~ (
    '^' || organization_id_value::text || '/' || invoice_value.guardian_id::text || '/'
  ) then
    raise exception 'Receipt storage path does not match its family' using errcode = '23514';
  end if;

  insert into public.billing_payments (
    id,
    organization_id,
    invoice_id,
    amount_cents,
    processing_fee_cents,
    method,
    received_at,
    note,
    recorded_by
  ) values (
    target_payment_id,
    organization_id_value,
    target_invoice_id,
    target_amount_cents,
    target_processing_fee_cents,
    target_method,
    target_received_at,
    nullif(btrim(target_note), ''),
    (select auth.uid())
  )
  returning * into created_payment;

  insert into public.billing_artifacts (
    id,
    organization_id,
    invoice_id,
    payment_id,
    kind,
    storage_path,
    generated_by,
    generated_at
  ) values (
    target_artifact_id,
    organization_id_value,
    target_invoice_id,
    target_payment_id,
    'receipt',
    target_storage_path,
    (select auth.uid()),
    target_received_at
  );

  return created_payment;
end;
$$;

revoke all on function public.admin_issue_billing_invoice(
  uuid, uuid, uuid, text, integer, text, timestamptz, text, uuid, uuid, text, jsonb
) from public, anon, authenticated, service_role;
grant execute on function public.admin_issue_billing_invoice(
  uuid, uuid, uuid, text, integer, text, timestamptz, text, uuid, uuid, text, jsonb
) to authenticated;

revoke all on function public.admin_record_billing_payment(
  uuid, uuid, integer, integer, public.billing_payment_method, timestamptz, text, uuid, text
) from public, anon, authenticated, service_role;
grant execute on function public.admin_record_billing_payment(
  uuid, uuid, integer, integer, public.billing_payment_method, timestamptz, text, uuid, text
) to authenticated;

alter table public.billing_invoices enable row level security;
alter table public.billing_invoice_items enable row level security;
alter table public.billing_payments enable row level security;
alter table public.billing_artifacts enable row level security;

revoke all on public.billing_invoices from anon, authenticated;
revoke all on public.billing_invoice_items from anon, authenticated;
revoke all on public.billing_payments from anon, authenticated;
revoke all on public.billing_artifacts from anon, authenticated;
grant select on public.billing_invoices to authenticated;
grant select on public.billing_invoice_items to authenticated;
grant select on public.billing_payments to authenticated;
grant select on public.billing_artifacts to authenticated;

create policy billing_invoices_member_select
on public.billing_invoices
for select
to authenticated
using (private.can_access_billing_invoice(id));

create policy billing_invoice_items_member_select
on public.billing_invoice_items
for select
to authenticated
using (private.can_access_billing_invoice(invoice_id));

create policy billing_payments_member_select
on public.billing_payments
for select
to authenticated
using (private.can_access_billing_invoice(invoice_id));

create policy billing_artifacts_member_select
on public.billing_artifacts
for select
to authenticated
using (private.can_access_billing_invoice(invoice_id));

create trigger billing_invoices_audit
after insert or update or delete on public.billing_invoices
for each row execute function private.capture_audit_event();

create trigger billing_invoice_items_audit
after insert or update or delete on public.billing_invoice_items
for each row execute function private.capture_audit_event();

create trigger billing_payments_audit
after insert or update or delete on public.billing_payments
for each row execute function private.capture_audit_event();

create trigger billing_artifacts_audit
after insert or update or delete on public.billing_artifacts
for each row execute function private.capture_audit_event();

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'billing-documents',
  'billing-documents',
  false,
  8388608,
  array['image/png']::text[]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy billing_storage_member_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'billing-documents'
  and private.can_access_billing_object(name)
);

create policy billing_storage_admin_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'billing-documents'
  and private.is_admin()
  and (storage.foldername(name))[1] = private.current_user_organization_id()::text
);

create policy billing_storage_admin_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'billing-documents'
  and private.is_admin()
  and (storage.foldername(name))[1] = private.current_user_organization_id()::text
)
with check (
  bucket_id = 'billing-documents'
  and private.is_admin()
  and (storage.foldername(name))[1] = private.current_user_organization_id()::text
);

create policy billing_storage_admin_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'billing-documents'
  and private.is_admin()
  and (storage.foldername(name))[1] = private.current_user_organization_id()::text
);

do $$
declare
  target_table text;
begin
  foreach target_table in array array[
    'billing_invoices',
    'billing_payments',
    'billing_artifacts'
  ]
  loop
    if not exists (
      select 1
      from pg_catalog.pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = target_table
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I',
        target_table
      );
    end if;
  end loop;
end;
$$;

comment on table public.billing_invoices is
  'Immutable family invoices. Corrections create a new version and supersede the previous row.';
comment on table public.billing_payments is
  'Append-only family payments. Card processing fees remain separate from invoice principal.';

commit;
