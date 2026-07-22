begin;

create type public.enrollment_registration_mode as enum (
  'full_term',
  'per_session'
);

alter table public.courses
  add column drop_in_unit_price_cents integer;

alter table public.courses
  add constraint courses_drop_in_unit_price_nonnegative
    check (drop_in_unit_price_cents is null or drop_in_unit_price_cents >= 0);

comment on column public.courses.unit_price_cents is
  'Full-term enrollment price per scheduled session, stored as integer US cents.';
comment on column public.courses.drop_in_unit_price_cents is
  'Per-session enrollment price, stored as integer US cents. Null means per-session enrollment is not yet priced.';

alter table public.enrollments
  add column registration_mode public.enrollment_registration_mode not null default 'full_term';

comment on column public.enrollments.registration_mode is
  'Full-term registrations cover every eligible session; per-session registrations cover only explicitly selected sessions.';

alter table public.class_sessions
  add constraint class_sessions_id_course_organization_key
    unique (id, course_id, organization_id);

alter table public.enrollments
  add constraint enrollments_id_course_organization_key
    unique (id, course_id, organization_id);

create table public.enrollment_session_selections (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  enrollment_id uuid not null,
  course_id uuid not null,
  session_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (enrollment_id, session_id),
  constraint enrollment_session_selections_enrollment_fk
    foreign key (enrollment_id, course_id, organization_id)
    references public.enrollments(id, course_id, organization_id) on delete cascade,
  constraint enrollment_session_selections_session_fk
    foreign key (session_id, course_id, organization_id)
    references public.class_sessions(id, course_id, organization_id) on delete restrict
);

create index enrollment_session_selections_session_idx
  on public.enrollment_session_selections (session_id, enrollment_id);

create or replace function public.admin_save_enrollment(
  target_id uuid,
  target_term_id uuid,
  target_course_id uuid,
  target_student_id uuid,
  target_enrolled_at timestamptz,
  target_status text,
  target_registration_mode text,
  target_pricing_status text,
  target_billing_starts_on date,
  target_unit_price_cents integer,
  target_trial_fee_cents integer,
  target_discount_name text,
  target_discount_kind text,
  target_discount_value integer,
  target_billing_notes text,
  target_selected_session_ids uuid[]
)
returns public.enrollments
language plpgsql
security definer
set search_path = ''
as $$
declare
  organization_id_value uuid;
  existing_enrollment public.enrollments%rowtype;
  saved_enrollment public.enrollments%rowtype;
  selected_count integer;
begin
  if not private.is_admin() then
    raise exception 'Only administrators may save enrollments' using errcode = '42501';
  end if;

  organization_id_value := private.current_user_organization_id();
  if organization_id_value is null then
    raise exception 'Administrator organization is unavailable' using errcode = '42501';
  end if;

  if target_registration_mode not in ('full_term', 'per_session') then
    raise exception 'Registration mode is invalid' using errcode = '23514';
  end if;

  if not exists (
    select 1
    from public.courses c
    where c.id = target_course_id
      and c.term_id = target_term_id
      and c.organization_id = organization_id_value
  ) then
    raise exception 'Course and term are unavailable' using errcode = '23503';
  end if;

  if not exists (
    select 1
    from public.students s
    where s.id = target_student_id
      and s.organization_id = organization_id_value
  ) then
    raise exception 'Student is unavailable' using errcode = '23503';
  end if;

  selected_count := cardinality(coalesce(target_selected_session_ids, '{}'::uuid[]));
  if target_registration_mode = 'full_term' and selected_count <> 0 then
    raise exception 'Full-term enrollments cannot contain selected sessions' using errcode = '23514';
  end if;
  if target_registration_mode = 'per_session' and selected_count = 0 then
    raise exception 'Per-session enrollments require at least one session' using errcode = '23514';
  end if;

  if target_registration_mode = 'per_session' and (
    select count(distinct s.id)
    from public.class_sessions s
    where s.id = any(target_selected_session_ids)
      and s.course_id = target_course_id
      and s.organization_id = organization_id_value
      and s.status <> 'cancelled'
  ) <> selected_count then
    raise exception 'Every selected session must be active and belong to the enrollment course' using errcode = '23514';
  end if;

  select * into existing_enrollment
  from public.enrollments e
  where e.id = target_id
    and e.organization_id = organization_id_value;

  if found and (
    existing_enrollment.term_id <> target_term_id
    or existing_enrollment.course_id <> target_course_id
    or existing_enrollment.student_id <> target_student_id
  ) then
    raise exception 'Enrollment identity cannot be changed' using errcode = '23514';
  end if;

  insert into public.enrollments (
    id,
    organization_id,
    term_id,
    course_id,
    student_id,
    enrolled_at,
    status,
    registration_mode,
    pricing_status,
    billing_starts_on,
    unit_price_cents,
    trial_fee_cents,
    discount_name,
    discount_kind,
    discount_value,
    billing_notes
  ) values (
    target_id,
    organization_id_value,
    target_term_id,
    target_course_id,
    target_student_id,
    target_enrolled_at,
    target_status::public.enrollment_status,
    target_registration_mode::public.enrollment_registration_mode,
    target_pricing_status::public.enrollment_pricing_status,
    target_billing_starts_on,
    target_unit_price_cents,
    target_trial_fee_cents,
    nullif(btrim(target_discount_name), ''),
    case
      when target_discount_kind is null then null
      else target_discount_kind::public.billing_discount_kind
    end,
    target_discount_value,
    nullif(btrim(target_billing_notes), '')
  )
  on conflict (id) do update set
    status = excluded.status,
    registration_mode = excluded.registration_mode,
    pricing_status = excluded.pricing_status,
    billing_starts_on = excluded.billing_starts_on,
    unit_price_cents = excluded.unit_price_cents,
    trial_fee_cents = excluded.trial_fee_cents,
    discount_name = excluded.discount_name,
    discount_kind = excluded.discount_kind,
    discount_value = excluded.discount_value,
    billing_notes = excluded.billing_notes,
    updated_at = now()
  returning * into saved_enrollment;

  delete from public.enrollment_session_selections
  where enrollment_id = target_id
    and organization_id = organization_id_value;

  if target_registration_mode = 'per_session' then
    insert into public.enrollment_session_selections (
      organization_id,
      enrollment_id,
      course_id,
      session_id
    )
    select
      organization_id_value,
      target_id,
      target_course_id,
      selected_session_id
    from unnest(target_selected_session_ids) as selected_session_id;
  end if;

  return saved_enrollment;
end;
$$;

revoke all on function public.admin_save_enrollment(
  uuid, uuid, uuid, uuid, timestamptz, text, text, text, date, integer,
  integer, text, text, integer, text, uuid[]
) from public, anon, authenticated, service_role;
grant execute on function public.admin_save_enrollment(
  uuid, uuid, uuid, uuid, timestamptz, text, text, text, date, integer,
  integer, text, text, integer, text, uuid[]
) to authenticated;

revoke insert, update on public.enrollments from authenticated;

alter table public.enrollment_session_selections enable row level security;
revoke all on public.enrollment_session_selections from anon, authenticated;
grant select on public.enrollment_session_selections to authenticated;

create policy enrollment_session_selections_admin_select
on public.enrollment_session_selections
for select
to authenticated
using (
  private.is_admin()
  and organization_id = private.current_user_organization_id()
);

create policy enrollment_session_selections_member_select
on public.enrollment_session_selections
for select
to authenticated
using (
  exists (
    select 1
    from public.enrollments e
    where e.id = enrollment_id
      and e.organization_id = enrollment_session_selections.organization_id
      and private.can_access_student(e.student_id)
  )
);

create trigger enrollment_session_selections_audit
after insert or update or delete on public.enrollment_session_selections
for each row execute function private.capture_audit_event();

do $$
begin
  if not exists (
    select 1
    from pg_catalog.pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'enrollment_session_selections'
  ) then
    alter publication supabase_realtime
      add table public.enrollment_session_selections;
  end if;
end;
$$;

comment on table public.enrollment_session_selections is
  'Specific class sessions included in a per-session enrollment. Empty for full-term enrollments.';

commit;
