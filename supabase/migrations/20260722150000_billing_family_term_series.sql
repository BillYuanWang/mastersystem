begin;

create unique index billing_invoices_one_root_per_family_term_idx
  on public.billing_invoices (organization_id, guardian_id, term_id)
  where supersedes_invoice_id is null;

create or replace function private.validate_billing_invoice_series_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  previous_invoice public.billing_invoices%rowtype;
begin
  if new.term_id is null then
    raise exception 'Invoice must belong to a term' using errcode = '23514';
  end if;

  if new.supersedes_invoice_id is null then
    if exists (
      select 1
      from public.billing_invoices i
      where i.organization_id = new.organization_id
        and i.guardian_id = new.guardian_id
        and i.term_id = new.term_id
        and i.supersedes_invoice_id is null
        and i.id <> new.id
    ) then
      raise exception 'This family already has an invoice for this term; create a new version'
        using errcode = '23514';
    end if;
  else
    select * into previous_invoice
    from public.billing_invoices i
    where i.id = new.supersedes_invoice_id
      and i.organization_id = new.organization_id;

    if not found
       or previous_invoice.guardian_id <> new.guardian_id
       or previous_invoice.term_id is distinct from new.term_id
       or previous_invoice.invoice_number <> new.invoice_number
       or previous_invoice.version + 1 <> new.version
       or previous_invoice.superseded_by_invoice_id is not null then
      raise exception 'Invoice version must continue from the latest family and term record'
        using errcode = '23514';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function private.validate_billing_invoice_series_insert() from public;

create trigger billing_invoice_series_insert_guard
before insert on public.billing_invoices
for each row execute function private.validate_billing_invoice_series_insert();

comment on index public.billing_invoices_one_root_per_family_term_idx is
  'A family and term have one invoice series; later changes are immutable versions.';
comment on function private.validate_billing_invoice_series_insert() is
  'Requires term-scoped invoices and preserves one family-term version lineage.';

commit;
