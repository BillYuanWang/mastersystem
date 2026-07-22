begin;

alter table public.billing_invoice_items
  drop constraint billing_invoice_items_enrollment_fk,
  add constraint billing_invoice_items_enrollment_requires_student
    check (enrollment_id is null or student_id is not null),
  add constraint billing_invoice_items_enrollment_student_fk
    foreign key (enrollment_id, student_id, organization_id)
    references public.enrollments(id, student_id, organization_id) on delete restrict;

alter table public.billing_payments
  add constraint billing_payments_id_invoice_organization_key
    unique (id, invoice_id, organization_id);

alter table public.billing_artifacts
  drop constraint billing_artifacts_payment_fk,
  add constraint billing_artifacts_payment_invoice_fk
    foreign key (payment_id, invoice_id, organization_id)
    references public.billing_payments(id, invoice_id, organization_id) on delete restrict;

create or replace function private.validate_billing_invoice_item_scope()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  invoice_guardian_id uuid;
  invoice_term_id uuid;
begin
  select i.guardian_id, i.term_id
  into invoice_guardian_id, invoice_term_id
  from public.billing_invoices i
  where i.id = new.invoice_id
    and i.organization_id = new.organization_id;

  if not found then
    raise exception 'Invoice is unavailable for this line item' using errcode = '23514';
  end if;

  if new.student_id is not null and not exists (
    select 1
    from public.students s
    where s.id = new.student_id
      and s.organization_id = new.organization_id
      and s.guardian_id = invoice_guardian_id
  ) then
    raise exception 'Billed learner does not belong to the invoice family' using errcode = '23514';
  end if;

  if new.enrollment_id is not null and not exists (
    select 1
    from public.enrollments e
    where e.id = new.enrollment_id
      and e.student_id = new.student_id
      and e.organization_id = new.organization_id
      and e.term_id = invoice_term_id
  ) then
    raise exception 'Billed enrollment does not match the invoice learner and term' using errcode = '23514';
  end if;

  return new;
end;
$$;

revoke all on function private.validate_billing_invoice_item_scope() from public;

create trigger billing_invoice_items_scope_guard
before insert or update on public.billing_invoice_items
for each row execute function private.validate_billing_invoice_item_scope();

drop policy if exists billing_storage_admin_update on storage.objects;
drop policy if exists billing_storage_admin_delete on storage.objects;

create policy billing_storage_admin_delete_orphan
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'billing-documents'
  and private.is_admin()
  and (storage.foldername(name))[1] = private.current_user_organization_id()::text
  and not exists (
    select 1
    from public.billing_artifacts artifact
    where artifact.storage_path = name
  )
);

comment on function private.validate_billing_invoice_item_scope() is
  'Keeps every learner and enrollment line inside the invoice family and term.';

commit;
