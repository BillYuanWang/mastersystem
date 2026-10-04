begin;

create extension if not exists pgtap with schema extensions;

select plan(26);

select has_column('public', 'courses', 'unit_price_cents', 'courses have a per-session price');
select has_column('public', 'courses', 'pricing_status', 'courses have a pricing status');
select has_column('public', 'enrollments', 'billing_starts_on', 'enrollments have an adjustable billing start');
select has_column('public', 'enrollments', 'trial_fee_cents', 'enrollments record trial fees');
select has_column('public', 'enrollments', 'discount_kind', 'enrollments support one course discount');

select has_table('public', 'billing_invoices', 'family invoices table exists');
select has_column('public', 'billing_invoices', 'learner_ids', 'invoices preserve their selected learner scope');
select has_table('public', 'billing_invoice_items', 'immutable invoice items table exists');
select has_column(
  'public',
  'billing_invoice_items',
  'settlement_status',
  'invoice items distinguish unpaid, paid, and waived prices'
);
select has_table('public', 'billing_payments', 'append-only payments table exists');
select has_table('public', 'billing_artifacts', 'invoice and receipt PNG metadata table exists');

select ok(
  not has_table_privilege('authenticated', 'public.billing_invoices', 'INSERT'),
  'clients cannot insert invoice rows outside the controlled RPC'
);

select ok(
  to_regprocedure(
    'public.admin_issue_billing_invoice(uuid,uuid,uuid,text,integer,text,timestamptz,text,uuid,uuid,text,jsonb)'
  ) is not null,
  'versioned invoice issuance RPC exists'
);

select ok(
  to_regprocedure(
    'public.admin_record_billing_payment(uuid,uuid,integer,integer,public.billing_payment_method,timestamptz,text,uuid,text)'
  ) is not null,
  'append-only payment RPC exists'
);

select ok(
  to_regprocedure(
    'public.admin_issue_billing_invoice_scoped_dual(uuid,uuid,uuid,uuid[],text,integer,text,timestamptz,text,uuid,uuid,text,uuid,text,jsonb)'
  ) is not null,
  'scoped invoice issuance stores bilingual and English artifacts atomically'
);

select ok(
  to_regprocedure(
    'public.admin_issue_billing_invoice_scoped_dual_v2(uuid,uuid,uuid,uuid[],text,integer,text,timestamptz,text,uuid,uuid,text,uuid,text,jsonb)'
  ) is not null,
  'current invoice issuance preserves three-state settlement data'
);

select ok(
  exists (
    select 1
    from storage.buckets
    where id = 'billing-documents'
      and not public
      and file_size_limit = 8388608
  ),
  'billing PNGs use a private 8 MB bucket'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'billing_invoices'
  ),
  'issued invoices participate in active-client synchronization'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.billing_invoice_items'::regclass
      and conname = 'billing_invoice_items_enrollment_student_fk'
  ),
  'invoice enrollment lines are tied to the selected learner'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.billing_artifacts'::regclass
      and conname = 'billing_artifacts_payment_invoice_fk'
  ),
  'receipt artifacts cannot point to a payment from another invoice'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_trigger
    where tgrelid = 'public.billing_invoice_items'::regclass
      and tgname = 'billing_invoice_items_scope_guard'
      and not tgisinternal
  ),
  'invoice items enforce family and term scope'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_trigger
    where tgrelid = 'public.billing_invoice_items'::regclass
      and tgname = 'billing_invoice_items_settlement_guard'
      and not tgisinternal
  ),
  'invoice items keep the legacy amount-due flag synchronized'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.billing_invoice_items'::regclass
      and conname = 'billing_invoice_items_settlement_consistent'
  ),
  'settlement status and amount-due behavior cannot disagree'
);

select ok(
  not exists (
    select 1
    from pg_catalog.pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'billing_storage_admin_update'
  ),
  'issued billing PNGs cannot be overwritten'
);

select ok(
  to_regclass('public.billing_invoices_one_root_per_family_term_scope_idx') is not null,
  'a family, term, and exact learner selection can start one invoice series'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_trigger
    where tgrelid = 'public.billing_invoices'::regclass
      and tgname = 'billing_invoice_series_insert_guard'
      and not tgisinternal
  ),
  'invoice versions remain in the same family and term series'
);

select * from finish();

rollback;
