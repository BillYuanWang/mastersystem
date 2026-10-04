-- Issue the bilingual and English PNGs in the same database transaction.
-- The original RPCs remain available for already-distributed clients.

create or replace function public.admin_issue_billing_invoice_dual(
  target_invoice_id uuid,
  target_guardian_id uuid,
  target_term_id uuid,
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
  created_invoice := public.admin_issue_billing_invoice(
    target_invoice_id,
    target_guardian_id,
    target_term_id,
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

create or replace function public.admin_record_billing_payment_dual(
  target_payment_id uuid,
  target_invoice_id uuid,
  target_amount_cents integer,
  target_processing_fee_cents integer,
  target_method public.billing_payment_method,
  target_received_at timestamptz,
  target_note text,
  target_bilingual_artifact_id uuid,
  target_bilingual_storage_path text,
  target_english_artifact_id uuid,
  target_english_storage_path text
)
returns public.billing_payments
language plpgsql
security definer
set search_path = ''
as $$
declare
  created_payment public.billing_payments%rowtype;
  invoice_value public.billing_invoices%rowtype;
begin
  created_payment := public.admin_record_billing_payment(
    target_payment_id,
    target_invoice_id,
    target_amount_cents,
    target_processing_fee_cents,
    target_method,
    target_received_at,
    target_note,
    target_bilingual_artifact_id,
    target_bilingual_storage_path
  );

  select * into invoice_value
  from public.billing_invoices
  where id = target_invoice_id
    and organization_id = created_payment.organization_id;

  if target_english_storage_path !~ (
    '^' || created_payment.organization_id::text || '/' || invoice_value.guardian_id::text || '/'
  ) or target_english_storage_path !~ '-en[.]png$' then
    raise exception 'English receipt storage path is invalid' using errcode = '23514';
  end if;

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
    target_english_artifact_id,
    created_payment.organization_id,
    target_invoice_id,
    target_payment_id,
    'receipt',
    target_english_storage_path,
    (select auth.uid()),
    target_received_at
  );

  return created_payment;
end;
$$;

revoke all on function public.admin_issue_billing_invoice_dual(
  uuid, uuid, uuid, text, integer, text, timestamptz, text, uuid,
  uuid, text, uuid, text, jsonb
) from public, anon, authenticated, service_role;
grant execute on function public.admin_issue_billing_invoice_dual(
  uuid, uuid, uuid, text, integer, text, timestamptz, text, uuid,
  uuid, text, uuid, text, jsonb
) to authenticated;

revoke all on function public.admin_record_billing_payment_dual(
  uuid, uuid, integer, integer, public.billing_payment_method, timestamptz, text,
  uuid, text, uuid, text
) from public, anon, authenticated, service_role;
grant execute on function public.admin_record_billing_payment_dual(
  uuid, uuid, integer, integer, public.billing_payment_method, timestamptz, text,
  uuid, text, uuid, text
) to authenticated;
