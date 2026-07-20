begin;

create or replace function public.current_sync_revision()
returns table (change_sequence bigint)
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(max(a.id), 0)::bigint
  from public.audit_events a
  where a.organization_id = private.current_user_organization_id()
$$;

revoke all on function public.current_sync_revision()
from public, anon, authenticated, service_role;

grant execute on function public.current_sync_revision()
to authenticated;

comment on function public.current_sync_revision() is
  'Returns only the caller organization audit sequence so active clients can pull changes without exposing audit metadata.';

commit;
