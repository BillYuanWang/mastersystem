insert into public.organizations (
  id,
  name,
  slug,
  timezone
)
values (
  '00000000-0000-0000-0000-000000000001',
  'Master Dance',
  'master-dance',
  'America/Los_Angeles'
)
on conflict (id) do nothing;

comment on table public.organizations is
  'Tenant boundary. Production bootstraps only Master Dance; all course reference data remains user-defined.';
