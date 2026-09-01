begin;

create type public.billing_line_item_settlement_status as enum (
  'unpaid',
  'paid',
  'waived'
);

alter table public.billing_invoice_items
  add column settlement_status public.billing_line_item_settlement_status;

update public.billing_invoice_items
set settlement_status = case
  when included_in_amount_due then 'unpaid'::public.billing_line_item_settlement_status
  else 'paid'::public.billing_line_item_settlement_status
end;

create or replace function private.normalize_billing_line_item_settlement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.settlement_status is null then
      new.settlement_status := case
        when new.included_in_amount_due then 'unpaid'::public.billing_line_item_settlement_status
        else 'paid'::public.billing_line_item_settlement_status
      end;
    else
      new.included_in_amount_due := new.settlement_status = 'unpaid';
    end if;
  elsif new.settlement_status is distinct from old.settlement_status then
    new.included_in_amount_due := new.settlement_status = 'unpaid';
  elsif new.included_in_amount_due is distinct from old.included_in_amount_due then
    new.settlement_status := case
      when new.included_in_amount_due then 'unpaid'::public.billing_line_item_settlement_status
      else 'paid'::public.billing_line_item_settlement_status
    end;
  end if;

  return new;
end;
$$;

revoke all on function private.normalize_billing_line_item_settlement() from public;

create trigger billing_invoice_items_settlement_guard
before insert or update of included_in_amount_due, settlement_status
on public.billing_invoice_items
for each row execute function private.normalize_billing_line_item_settlement();

alter table public.billing_invoice_items
  alter column settlement_status set not null,
  add constraint billing_invoice_items_settlement_consistent
    check (
      included_in_amount_due = (settlement_status = 'unpaid')
    );

create or replace function public.admin_issue_billing_invoice_scoped_dual_v2(
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
  updated_item_count integer;
begin
  created_invoice := public.admin_issue_billing_invoice_scoped_dual(
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
    target_english_artifact_id,
    target_english_storage_path,
    target_items
  );

  update public.billing_invoice_items stored
  set settlement_status = coalesce(
    item.settlement_status::public.billing_line_item_settlement_status,
    case
      when stored.included_in_amount_due
        then 'unpaid'::public.billing_line_item_settlement_status
      else 'paid'::public.billing_line_item_settlement_status
    end
  )
  from jsonb_to_recordset(coalesce(target_items, '[]'::jsonb)) as item(
    id uuid,
    settlement_status text
  )
  where stored.id = item.id
    and stored.invoice_id = target_invoice_id
    and stored.organization_id = created_invoice.organization_id;

  get diagnostics updated_item_count = row_count;
  if updated_item_count <> jsonb_array_length(coalesce(target_items, '[]'::jsonb)) then
    raise exception 'Every invoice item requires a stable identifier'
      using errcode = '23514';
  end if;

  return created_invoice;
end;
$$;

revoke all on function public.admin_issue_billing_invoice_scoped_dual_v2(
  uuid, uuid, uuid, uuid[], text, integer, text, timestamptz, text, uuid,
  uuid, text, uuid, text, jsonb
) from public, anon, authenticated, service_role;
grant execute on function public.admin_issue_billing_invoice_scoped_dual_v2(
  uuid, uuid, uuid, uuid[], text, integer, text, timestamptz, text, uuid,
  uuid, text, uuid, text, jsonb
) to authenticated;

comment on column public.billing_invoice_items.settlement_status is
  'Unpaid contributes to amount due; paid and waived retain original price without contributing.';
comment on function public.admin_issue_billing_invoice_scoped_dual_v2(
  uuid, uuid, uuid, uuid[], text, integer, text, timestamptz, text, uuid,
  uuid, text, uuid, text, jsonb
) is
  'Atomically issues bilingual learner-scoped invoices with unpaid, paid, or waived line items.';

notify pgrst, 'reload schema';

commit;
