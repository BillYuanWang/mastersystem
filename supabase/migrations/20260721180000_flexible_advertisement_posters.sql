begin;

alter table public.advertisements
  drop constraint if exists advertisements_copy_text_check;

alter table public.advertisements
  add constraint advertisements_copy_text_check
  check (length(btrim(copy_text)) between 1 and 1024) not valid;

alter table public.advertisements
  validate constraint advertisements_copy_text_check;

alter table public.advertisements
  drop constraint if exists advertisements_poster_metadata_check;

alter table public.advertisements
  add constraint advertisements_poster_metadata_check check (
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
      and poster_width between 1 and 4096
      and poster_height between 1 and 4096
      and poster_byte_count between 1 and 8388608
    )
  ) not valid;

alter table public.advertisements
  validate constraint advertisements_poster_metadata_check;

comment on column public.advertisements.copy_text is
  'Full advertisement copy shown on the detail screen; limited to 1024 characters.';

comment on column public.advertisements.poster_width is
  'Optimized poster width. Advertisement posters may use any aspect ratio.';

commit;
