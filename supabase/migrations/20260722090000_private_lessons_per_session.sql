begin;

alter table public.courses
  drop constraint courses_pricing_state_consistency;

with normalized_private_prices as (
  select
    id,
    case
      when pricing_status = 'free' then 0
      when pricing_status = 'priced' then coalesce(nullif(drop_in_unit_price_cents, 0), unit_price_cents)
      else coalesce(drop_in_unit_price_cents, unit_price_cents)
    end as effective_price_cents
  from public.courses
  where format = 'private_lesson'
)
update public.courses c
set
  unit_price_cents = null,
  drop_in_unit_price_cents = normalized.effective_price_cents,
  pricing_status = case
    when c.pricing_status = 'pending' and normalized.effective_price_cents > 0 then 'priced'
    when c.pricing_status = 'pending' and normalized.effective_price_cents = 0 then 'free'
    else c.pricing_status
  end,
  updated_at = now()
from normalized_private_prices normalized
where c.id = normalized.id;

alter table public.courses
  add constraint courses_pricing_state_consistency
  check (
    (
      format = 'group'
      and (
        (pricing_status = 'pending' and unit_price_cents is null)
        or (pricing_status = 'priced' and unit_price_cents > 0)
        or (pricing_status = 'free' and unit_price_cents = 0)
        or (pricing_status = 'review_required' and (unit_price_cents is null or unit_price_cents >= 0))
      )
    )
    or
    (
      format = 'private_lesson'
      and unit_price_cents is null
      and (
        (pricing_status = 'pending' and drop_in_unit_price_cents is null)
        or (pricing_status = 'priced' and drop_in_unit_price_cents > 0)
        or (pricing_status = 'free' and drop_in_unit_price_cents = 0)
        or (
          pricing_status = 'review_required'
          and (drop_in_unit_price_cents is null or drop_in_unit_price_cents >= 0)
        )
      )
    )
  );

with converted_enrollments as (
  update public.enrollments e
  set
    registration_mode = 'per_session',
    unit_price_cents = coalesce(e.unit_price_cents, c.drop_in_unit_price_cents),
    updated_at = now()
  from public.courses c
  where c.id = e.course_id
    and c.organization_id = e.organization_id
    and c.format = 'private_lesson'
    and e.registration_mode = 'full_term'
  returning e.id, e.organization_id, e.course_id
)
insert into public.enrollment_session_selections (
  organization_id,
  enrollment_id,
  course_id,
  session_id
)
select
  converted.organization_id,
  converted.id,
  converted.course_id,
  session.id
from converted_enrollments converted
join public.class_sessions session
  on session.course_id = converted.course_id
 and session.organization_id = converted.organization_id
 and session.status <> 'cancelled'
on conflict (enrollment_id, session_id) do nothing;

update public.enrollments e
set
  unit_price_cents = c.drop_in_unit_price_cents,
  updated_at = now()
from public.courses c
where c.id = e.course_id
  and c.organization_id = e.organization_id
  and c.format = 'private_lesson'
  and e.registration_mode = 'per_session'
  and e.unit_price_cents is null
  and c.drop_in_unit_price_cents is not null;

create or replace function private.enforce_private_lesson_enrollment_mode()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  course_format_value public.course_format;
begin
  select c.format into course_format_value
  from public.courses c
  where c.id = new.course_id
    and c.organization_id = new.organization_id;

  if course_format_value = 'private_lesson'
     and new.registration_mode <> 'per_session' then
    raise exception 'Private lessons only support per-session enrollment'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

drop trigger if exists enrollments_private_lesson_mode_guard on public.enrollments;
create trigger enrollments_private_lesson_mode_guard
before insert or update of course_id, organization_id, registration_mode
on public.enrollments
for each row execute function private.enforce_private_lesson_enrollment_mode();

create or replace function private.guard_private_lesson_course_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.format = 'private_lesson'
     and exists (
       select 1
       from public.enrollments e
       where e.course_id = new.id
         and e.organization_id = new.organization_id
         and e.registration_mode <> 'per_session'
     ) then
    raise exception 'Convert every enrollment to per-session before making this a private lesson'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

drop trigger if exists courses_private_lesson_transition_guard on public.courses;
create trigger courses_private_lesson_transition_guard
before update of format on public.courses
for each row execute function private.guard_private_lesson_course_transition();

comment on column public.courses.unit_price_cents is
  'Full-term price per scheduled session for group courses. Always null for private lessons.';
comment on column public.courses.drop_in_unit_price_cents is
  'Per-session price. It is the only course price used by private lessons.';
comment on function private.enforce_private_lesson_enrollment_mode() is
  'Rejects full-term enrollment for private lessons at the database boundary.';

commit;
