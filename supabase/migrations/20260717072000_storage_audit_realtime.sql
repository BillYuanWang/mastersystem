begin;

create table public.audit_events (
  id bigint generated always as identity primary key,
  organization_id uuid references public.organizations(id) on delete set null,
  table_name text not null,
  record_key text,
  action text not null check (action in ('INSERT', 'UPDATE', 'DELETE')),
  actor_user_id uuid references auth.users(id) on delete set null,
  transaction_id bigint not null default txid_current(),
  occurred_at timestamptz not null default now()
);

create index audit_events_organization_time_idx
  on public.audit_events (organization_id, occurred_at desc);

create index audit_events_record_idx
  on public.audit_events (table_name, record_key, occurred_at desc);

comment on table public.audit_events is
  'Metadata-only audit trail. Row snapshots are intentionally omitted to avoid duplicating student PII.';

create or replace function private.capture_audit_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  row_data jsonb;
  organization_id_value uuid;
  record_key_value text;
begin
  row_data := case
    when tg_op = 'DELETE' then to_jsonb(old)
    else to_jsonb(new)
  end;

  organization_id_value := nullif(row_data ->> 'organization_id', '')::uuid;
  record_key_value := coalesce(
    row_data ->> 'id',
    concat_ws(':', row_data ->> 'guardian_id', row_data ->> 'student_id')
  );

  insert into public.audit_events (
    organization_id,
    table_name,
    record_key,
    action,
    actor_user_id
  )
  values (
    organization_id_value,
    tg_table_name,
    nullif(record_key_value, ''),
    tg_op,
    (select auth.uid())
  );

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create trigger profiles_audit
after insert or update or delete on public.profiles
for each row execute function private.capture_audit_event();

create trigger terms_audit
after insert or update or delete on public.terms
for each row execute function private.capture_audit_event();

create trigger course_categories_audit
after insert or update or delete on public.course_categories
for each row execute function private.capture_audit_event();

create trigger age_groups_audit
after insert or update or delete on public.age_groups
for each row execute function private.capture_audit_event();

create trigger rooms_audit
after insert or update or delete on public.rooms
for each row execute function private.capture_audit_event();

create trigger instructors_audit
after insert or update or delete on public.instructors
for each row execute function private.capture_audit_event();

create trigger courses_audit
after insert or update or delete on public.courses
for each row execute function private.capture_audit_event();

create trigger class_sessions_audit
after insert or update or delete on public.class_sessions
for each row execute function private.capture_audit_event();

create trigger students_audit
after insert or update or delete on public.students
for each row execute function private.capture_audit_event();

create trigger guardians_audit
after insert or update or delete on public.guardians
for each row execute function private.capture_audit_event();

create trigger guardian_students_audit
after insert or update or delete on public.guardian_students
for each row execute function private.capture_audit_event();

create trigger enrollments_audit
after insert or update or delete on public.enrollments
for each row execute function private.capture_audit_event();

create trigger attendance_audit
after insert or update or delete on public.attendance
for each row execute function private.capture_audit_event();

create trigger leave_requests_audit
after insert or update or delete on public.leave_requests
for each row execute function private.capture_audit_event();

create trigger contract_documents_audit
after insert or update or delete on public.contract_documents
for each row execute function private.capture_audit_event();

create trigger contract_consents_audit
after insert or update or delete on public.contract_consents
for each row execute function private.capture_audit_event();

create trigger notifications_audit
after insert or update or delete on public.notifications
for each row execute function private.capture_audit_event();

create trigger migration_runs_audit
after insert or update or delete on public.migration_runs
for each row execute function private.capture_audit_event();

alter table public.audit_events enable row level security;

revoke all on public.audit_events from anon, authenticated;
grant select on public.audit_events to authenticated;

create policy audit_events_admin_select
on public.audit_events
for select
to authenticated
using (
  private.is_admin()
  and organization_id = private.current_user_organization_id()
);

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'contracts',
  'contracts',
  false,
  10485760,
  array['application/pdf']::text[]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy contracts_storage_member_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'contracts'
  and private.can_access_contract_object(name)
);

create policy contracts_storage_admin_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'contracts'
  and private.is_admin()
  and (storage.foldername(name))[1] =
    private.current_user_organization_id()::text
);

create policy contracts_storage_admin_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'contracts'
  and private.is_admin()
  and (storage.foldername(name))[1] =
    private.current_user_organization_id()::text
)
with check (
  bucket_id = 'contracts'
  and private.is_admin()
  and (storage.foldername(name))[1] =
    private.current_user_organization_id()::text
);

create policy contracts_storage_admin_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'contracts'
  and private.is_admin()
  and (storage.foldername(name))[1] =
    private.current_user_organization_id()::text
);

do $$
declare
  target_table text;
begin
  foreach target_table in array array[
    'attendance',
    'class_sessions',
    'enrollments',
    'leave_requests',
    'notifications'
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

commit;
