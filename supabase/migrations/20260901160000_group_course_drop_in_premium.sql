begin;

create or replace function private.enforce_group_course_per_session_premium()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.format = 'group'
     and new.pricing_status in ('priced', 'review_required')
     and new.unit_price_cents is not null
     and new.unit_price_cents > 0 then
    new.drop_in_unit_price_cents = new.unit_price_cents + 500;
  end if;

  return new;
end;
$$;

drop trigger if exists courses_group_per_session_premium_guard on public.courses;
create trigger courses_group_per_session_premium_guard
before insert or update of format, pricing_status, unit_price_cents, drop_in_unit_price_cents
on public.courses
for each row execute function private.enforce_group_course_per_session_premium();

update public.courses
set
  drop_in_unit_price_cents = unit_price_cents + 500,
  updated_at = now()
where format = 'group'
  and pricing_status in ('priced', 'review_required')
  and unit_price_cents is not null
  and unit_price_cents > 0
  and drop_in_unit_price_cents is distinct from unit_price_cents + 500;

comment on function private.enforce_group_course_per_session_premium() is
  'Keeps a priced group course per-session rate exactly USD 5 above its full-term per-session rate.';

commit;
