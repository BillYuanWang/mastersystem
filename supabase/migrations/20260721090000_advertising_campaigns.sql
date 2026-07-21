begin;

create type public.advertisement_status as enum (
  'draft',
  'published',
  'archived'
);

create table public.advertisements (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  slot_number smallint not null check (slot_number between 1 and 5),
  advertiser_name text not null check (length(btrim(advertiser_name)) between 1 and 40),
  copy_text text not null check (length(btrim(copy_text)) between 1 and 120),
  starts_on date not null,
  ends_on date not null,
  monthly_rate_cents integer not null default 9900 check (monthly_rate_cents = 9900),
  status public.advertisement_status not null default 'draft',
  thumbnail_storage_path text,
  thumbnail_mime_type text,
  thumbnail_width integer,
  thumbnail_height integer,
  thumbnail_byte_count integer,
  poster_storage_path text,
  poster_mime_type text,
  poster_width integer,
  poster_height integer,
  poster_byte_count integer,
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint advertisements_date_range_check check (ends_on >= starts_on),
  constraint advertisements_thumbnail_metadata_check check (
    (
      thumbnail_storage_path is null
      and thumbnail_mime_type is null
      and thumbnail_width is null
      and thumbnail_height is null
      and thumbnail_byte_count is null
    )
    or (
      thumbnail_storage_path is not null
      and thumbnail_storage_path !~ '^/'
      and thumbnail_storage_path !~ '\.\.'
      and thumbnail_mime_type in ('image/jpeg', 'image/png', 'image/heic', 'image/heif')
      and thumbnail_width between 600 and 4096
      and thumbnail_height between 600 and 4096
      and thumbnail_byte_count between 1 and 8388608
      and abs((thumbnail_width::numeric / thumbnail_height::numeric) - 1.0) <= 0.02
    )
  ),
  constraint advertisements_poster_metadata_check check (
    (
      poster_storage_path is null
      and poster_mime_type is null
      and poster_width is null
      and poster_height is null
      and poster_byte_count is null
    )
    or (
      poster_storage_path is not null
      and poster_storage_path !~ '^/'
      and poster_storage_path !~ '\.\.'
      and poster_mime_type in ('image/jpeg', 'image/png', 'image/heic', 'image/heif')
      and poster_width between 900 and 4096
      and poster_height between 1125 and 4096
      and poster_byte_count between 1 and 8388608
      and abs((poster_width::numeric / poster_height::numeric) - 0.8) <= 0.02
    )
  ),
  constraint advertisements_published_media_check check (
    status <> 'published'::public.advertisement_status
    or (thumbnail_storage_path is not null and poster_storage_path is not null)
  ),
  constraint advertisements_id_organization_key unique (id, organization_id),
  constraint advertisements_slot_schedule_excl
    exclude using gist (
      organization_id with =,
      slot_number with =,
      daterange(starts_on, ends_on, '[]') with &&
    )
    where (status = 'published'::public.advertisement_status)
);

create index advertisements_feed_idx
  on public.advertisements (organization_id, status, slot_number, starts_on, ends_on);

create trigger advertisements_set_updated_at
before update on public.advertisements
for each row execute function private.set_updated_at();

create trigger advertisements_audit
after insert or update or delete on public.advertisements
for each row execute function private.capture_audit_event();

alter table public.advertisements enable row level security;

revoke all on public.advertisements from public, anon, authenticated;
grant select, insert, update, delete on public.advertisements to authenticated;

create policy advertisements_admin_all
on public.advertisements
for all
to authenticated
using (
  private.is_admin()
  and organization_id = private.current_user_organization_id()
)
with check (
  private.is_admin()
  and organization_id = private.current_user_organization_id()
);

create policy advertisements_member_select
on public.advertisements
for select
to authenticated
using (
  organization_id = private.current_user_organization_id()
  and status = 'published'::public.advertisement_status
);

create or replace function private.can_access_advertisement_object(target_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      private.is_admin()
      and (storage.foldername(target_path))[1] = private.current_user_organization_id()::text
    )
    or exists (
      select 1
      from public.advertisements advertisement
      where advertisement.organization_id = private.current_user_organization_id()
        and advertisement.status = 'published'::public.advertisement_status
        and target_path in (
          advertisement.thumbnail_storage_path,
          advertisement.poster_storage_path
        )
    ),
    false
  )
$$;

revoke execute on function private.can_access_advertisement_object(text)
from public, anon, authenticated;
grant execute on function private.can_access_advertisement_object(text)
to authenticated;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'advertisement-media',
  'advertisement-media',
  false,
  8388608,
  array['image/jpeg', 'image/png', 'image/heic', 'image/heif']::text[]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy advertisement_media_member_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'advertisement-media'
  and private.can_access_advertisement_object(name)
);

create policy advertisement_media_admin_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'advertisement-media'
  and private.is_admin()
  and (storage.foldername(name))[1] = private.current_user_organization_id()::text
);

create policy advertisement_media_admin_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'advertisement-media'
  and private.is_admin()
  and (storage.foldername(name))[1] = private.current_user_organization_id()::text
)
with check (
  bucket_id = 'advertisement-media'
  and private.is_admin()
  and (storage.foldername(name))[1] = private.current_user_organization_id()::text
);

create policy advertisement_media_admin_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'advertisement-media'
  and private.is_admin()
  and (storage.foldername(name))[1] = private.current_user_organization_id()::text
);

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'advertisements'
  ) then
    alter publication supabase_realtime add table public.advertisements;
  end if;
end;
$$;

commit;
