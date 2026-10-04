-- Additive compatibility: existing clients/RPCs and issued items stay unchanged.
begin;

alter table public.billing_invoice_items
  add column schedule_snapshot jsonb;

alter table public.billing_invoice_items
  add constraint billing_invoice_items_schedule_snapshot_check check (
    schedule_snapshot is null or (
      jsonb_typeof(schedule_snapshot) = 'object'
      and schedule_snapshot ->> 'version' = '1'
      and jsonb_typeof(schedule_snapshot -> 'sessions') = 'array'
      and jsonb_typeof(schedule_snapshot -> 'courseName') = 'string'
      and jsonb_typeof(schedule_snapshot -> 'studentName') = 'string'
      and schedule_snapshot ->> 'registrationMode' in ('full_term', 'per_session')
    ) is true
  );

create or replace function public.admin_issue_billing_invoice_scoped_dual_v3(
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
  created_invoice := public.admin_issue_billing_invoice_scoped_dual_v2(
    target_invoice_id, target_guardian_id, target_term_id, target_learner_ids,
    target_invoice_number, target_version, target_school_year_label,
    target_issued_at, target_notes, target_supersedes_invoice_id,
    target_bilingual_artifact_id, target_bilingual_storage_path,
    target_english_artifact_id, target_english_storage_path, target_items
  );

  update public.billing_invoice_items stored
  set schedule_snapshot = item.schedule_snapshot
  from jsonb_to_recordset(target_items) as item(id uuid, schedule_snapshot jsonb)
  where stored.id = item.id
    and stored.invoice_id = created_invoice.id
    and stored.organization_id = created_invoice.organization_id;

  return created_invoice;
end;
$$;

revoke all on function public.admin_issue_billing_invoice_scoped_dual_v3(
  uuid, uuid, uuid, uuid[], text, integer, text, timestamptz, text, uuid,
  uuid, text, uuid, text, jsonb
) from public, anon, authenticated, service_role;
grant execute on function public.admin_issue_billing_invoice_scoped_dual_v3(
  uuid, uuid, uuid, uuid[], text, integer, text, timestamptz, text, uuid,
  uuid, text, uuid, text, jsonb
) to authenticated;

comment on column public.billing_invoice_items.schedule_snapshot is
  'Issue-time course, learner, enrollment mode and actual dated session snapshot. Never backfilled from live schedules.';
notify pgrst, 'reload schema';
commit;
