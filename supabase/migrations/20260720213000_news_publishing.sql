begin;

create type public.news_article_status as enum (
  'draft',
  'published',
  'archived'
);

create table public.news_articles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  title text not null check (length(btrim(title)) between 1 and 160),
  summary text not null default '' check (length(summary) <= 500),
  body_text text not null check (length(btrim(body_text)) >= 1),
  author_name text not null check (length(btrim(author_name)) between 1 and 120),
  status public.news_article_status not null default 'draft',
  published_at timestamptz,
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint news_articles_publish_state check (
    (status = 'published' and published_at is not null)
    or status <> 'published'
  ),
  constraint news_articles_id_organization_key unique (id, organization_id)
);

create index news_articles_feed_idx
  on public.news_articles (organization_id, status, published_at desc);

create table public.news_article_images (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  article_id uuid not null,
  kind text not null check (kind in ('cover', 'body')),
  storage_path text not null check (storage_path !~ '^/' and storage_path !~ '\.\.'),
  mime_type text not null check (mime_type in (
    'image/jpeg', 'image/png', 'image/heic', 'image/heif', 'image/webp'
  )),
  caption text check (caption is null or length(caption) <= 240),
  sort_order integer not null default 0 check (sort_order >= 0),
  placement_after_paragraph integer check (
    placement_after_paragraph is null or placement_after_paragraph >= 0
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint news_article_images_article_fk
    foreign key (article_id, organization_id)
    references public.news_articles(id, organization_id) on delete cascade,
  constraint news_article_images_storage_path_key unique (storage_path)
);

create unique index news_article_images_one_cover_idx
  on public.news_article_images (article_id)
  where kind = 'cover';

create index news_article_images_order_idx
  on public.news_article_images (article_id, kind, sort_order);

create trigger news_articles_set_updated_at
before update on public.news_articles
for each row execute function private.set_updated_at();

create trigger news_article_images_set_updated_at
before update on public.news_article_images
for each row execute function private.set_updated_at();

create trigger news_articles_audit
after insert or update or delete on public.news_articles
for each row execute function private.capture_audit_event();

create trigger news_article_images_audit
after insert or update or delete on public.news_article_images
for each row execute function private.capture_audit_event();

alter table public.news_articles enable row level security;
alter table public.news_article_images enable row level security;

revoke all on public.news_articles from public, anon, authenticated;
revoke all on public.news_article_images from public, anon, authenticated;
grant select, insert, update, delete on public.news_articles to authenticated;
grant select, insert, update, delete on public.news_article_images to authenticated;

create policy news_articles_admin_all
on public.news_articles
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

create policy news_articles_member_select
on public.news_articles
for select
to authenticated
using (
  organization_id = private.current_user_organization_id()
  and status = 'published'::public.news_article_status
);

create policy news_article_images_admin_all
on public.news_article_images
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

create policy news_article_images_member_select
on public.news_article_images
for select
to authenticated
using (
  organization_id = private.current_user_organization_id()
  and exists (
    select 1
    from public.news_articles article
    where article.id = article_id
      and article.organization_id = organization_id
      and article.status = 'published'::public.news_article_status
  )
);

create or replace function private.can_access_news_object(target_path text)
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
      from public.news_article_images image
      join public.news_articles article
        on article.id = image.article_id
       and article.organization_id = image.organization_id
      where image.storage_path = target_path
        and image.organization_id = private.current_user_organization_id()
        and article.status = 'published'::public.news_article_status
    ),
    false
  )
$$;

revoke execute on function private.can_access_news_object(text)
from public, anon, authenticated;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'news-media',
  'news-media',
  false,
  12582912,
  array[
    'image/jpeg', 'image/png', 'image/heic', 'image/heif', 'image/webp'
  ]::text[]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy news_media_member_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'news-media'
  and private.can_access_news_object(name)
);

create policy news_media_admin_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'news-media'
  and private.is_admin()
  and (storage.foldername(name))[1] = private.current_user_organization_id()::text
);

create policy news_media_admin_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'news-media'
  and private.is_admin()
  and (storage.foldername(name))[1] = private.current_user_organization_id()::text
)
with check (
  bucket_id = 'news-media'
  and private.is_admin()
  and (storage.foldername(name))[1] = private.current_user_organization_id()::text
);

create policy news_media_admin_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'news-media'
  and private.is_admin()
  and (storage.foldername(name))[1] = private.current_user_organization_id()::text
);

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'news_articles'
  ) then
    alter publication supabase_realtime add table public.news_articles;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'news_article_images'
  ) then
    alter publication supabase_realtime add table public.news_article_images;
  end if;
end;
$$;

commit;
