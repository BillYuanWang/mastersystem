begin;

alter table public.guardians
  add column secondary_email text;

alter table public.guardians
  add constraint guardians_secondary_email_format_check
  check (
    secondary_email is null
    or (
      length(secondary_email) between 3 and 254
      and secondary_email = lower(btrim(secondary_email))
      and secondary_email ~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'
    )
  );

comment on column public.guardians.secondary_email is
  'Optional additional email maintained by the guardian or an administrator.';

create or replace function private.protect_guardian_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
  is_controlled_self_claim boolean :=
    current_user_id is not null
    and old.profile_user_id is null
    and new.profile_user_id = current_user_id
    and new.id is not distinct from old.id
    and new.organization_id is not distinct from old.organization_id
    and new.created_at is not distinct from old.created_at;
  is_linked_guardian_self boolean :=
    current_user_id is not null
    and old.profile_user_id = current_user_id;
begin
  if not private.is_admin()
     and (
       new.id is distinct from old.id
       or new.organization_id is distinct from old.organization_id
       or new.profile_user_id is distinct from old.profile_user_id
       or new.created_at is distinct from old.created_at
     )
     and not is_controlled_self_claim then
    raise exception 'Only administrators may change guardian identity links'
      using errcode = '42501';
  end if;

  if not private.is_admin()
     and is_linked_guardian_self
     and (
       new.display_name is distinct from old.display_name
       or new.email is distinct from old.email
       or new.address is distinct from old.address
     ) then
    raise exception 'Guardians may only change phone and secondary email'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

notify pgrst, 'reload schema';

commit;
