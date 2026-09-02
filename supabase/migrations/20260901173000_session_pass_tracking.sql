begin;

alter table public.attendance
  add column uses_session_pass boolean not null default false;

alter table public.attendance
  add constraint attendance_session_pass_semantics_check
  check (
    not uses_session_pass
    or (
      status::text = 'present'
      and enrollment_id is null
      and makeup_for_session_id is null
    )
  );

alter table public.attendance
  add constraint attendance_id_organization_key unique (id, organization_id);

comment on column public.attendance.uses_session_pass is
  'Backward-compatible marker for a physically present drop-in visit that consumes one learner session-pass use.';

create table public.session_pass_plans (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 120),
  included_sessions integer not null check (included_sessions between 1 and 10000),
  unit_price_cents integer not null check (unit_price_cents >= 0),
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint session_pass_plans_id_organization_key unique (id, organization_id)
);

create unique index session_pass_plans_organization_name_key
  on public.session_pass_plans (organization_id, lower(name));

create table public.student_session_passes (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  student_id uuid not null,
  plan_id uuid not null,
  issued_at timestamptz not null default now(),
  included_sessions integer not null check (included_sessions between 1 and 10000),
  unit_price_cents integer not null check (unit_price_cents >= 0),
  notes text,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint student_session_passes_id_organization_key unique (id, organization_id),
  constraint student_session_passes_student_fk
    foreign key (student_id, organization_id)
    references public.students(id, organization_id) on delete restrict,
  constraint student_session_passes_plan_fk
    foreign key (plan_id, organization_id)
    references public.session_pass_plans(id, organization_id) on delete restrict
);

create index student_session_passes_student_issued_idx
  on public.student_session_passes (student_id, issued_at, id);

create table public.session_pass_uses (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  student_session_pass_id uuid not null,
  attendance_id uuid not null,
  session_id uuid not null,
  student_id uuid not null,
  used_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint session_pass_uses_pass_fk
    foreign key (student_session_pass_id, organization_id)
    references public.student_session_passes(id, organization_id) on delete restrict,
  constraint session_pass_uses_attendance_fk
    foreign key (attendance_id, organization_id)
    references public.attendance(id, organization_id) on delete cascade,
  constraint session_pass_uses_session_fk
    foreign key (session_id, organization_id)
    references public.class_sessions(id, organization_id) on delete restrict,
  constraint session_pass_uses_student_fk
    foreign key (student_id, organization_id)
    references public.students(id, organization_id) on delete restrict,
  constraint session_pass_uses_attendance_key unique (attendance_id),
  constraint session_pass_uses_attendance_organization_key unique (attendance_id, organization_id)
);

create index session_pass_uses_pass_time_idx
  on public.session_pass_uses (student_session_pass_id, used_at desc);

create index session_pass_uses_student_time_idx
  on public.session_pass_uses (student_id, used_at desc);

create trigger session_pass_plans_set_updated_at
before update on public.session_pass_plans
for each row execute function private.set_updated_at();

create trigger student_session_passes_set_updated_at
before update on public.student_session_passes
for each row execute function private.set_updated_at();

create or replace function private.validate_student_session_pass()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  student_kind_value text;
  plan_sessions integer;
  plan_unit_price integer;
  plan_is_active boolean;
begin
  select s.kind::text
  into student_kind_value
  from public.students s
  where s.id = new.student_id
    and s.organization_id = new.organization_id;

  if student_kind_value is distinct from 'adult' then
    raise exception '当前版本只允许成人学员使用次卡。'
      using errcode = '23514';
  end if;

  select p.included_sessions, p.unit_price_cents, p.is_active
  into plan_sessions, plan_unit_price, plan_is_active
  from public.session_pass_plans p
  where p.id = new.plan_id
    and p.organization_id = new.organization_id;

  if plan_sessions is null then
    raise exception '找不到这个次卡方案。'
      using errcode = '23503';
  end if;

  if tg_op = 'INSERT' or new.plan_id is distinct from old.plan_id then
    if not plan_is_active then
      raise exception '这个次卡方案已经停用。'
        using errcode = '23514';
    end if;
    if new.included_sessions is distinct from plan_sessions
       or new.unit_price_cents is distinct from plan_unit_price then
      raise exception '发卡时的次数和单价必须与所选次卡方案一致。'
        using errcode = '23514';
    end if;
  end if;

  return new;
end;
$$;

create trigger student_session_passes_validate
before insert or update on public.student_session_passes
for each row execute function private.validate_student_session_pass();

create or replace function private.protect_used_student_session_pass()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.session_pass_uses u
    where u.student_session_pass_id = old.id
      and u.organization_id = old.organization_id
  ) then
    if tg_op = 'DELETE' then
      raise exception '这张次卡已有划卡记录，不能删除；可以将它停用。'
        using errcode = '23503';
    end if;

    if new.student_id is distinct from old.student_id
       or new.plan_id is distinct from old.plan_id
       or new.issued_at is distinct from old.issued_at
       or new.included_sessions is distinct from old.included_sessions
       or new.unit_price_cents is distinct from old.unit_price_cents then
      raise exception '这张次卡已有划卡记录，只能修改备注或启用状态。'
        using errcode = '23514';
    end if;
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create trigger student_session_passes_protect_used
before update or delete on public.student_session_passes
for each row execute function private.protect_used_student_session_pass();

create or replace function private.sync_session_pass_use()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  selected_pass_id uuid;
  existing_pass_id uuid;
begin
  if not new.uses_session_pass then
    delete from public.session_pass_uses
    where attendance_id = new.id
      and organization_id = new.organization_id;
    return new;
  end if;

  select u.student_session_pass_id
  into existing_pass_id
  from public.session_pass_uses u
  where u.attendance_id = new.id
    and u.organization_id = new.organization_id;

  if existing_pass_id is not null then
    if not exists (
      select 1
      from public.student_session_passes p
      where p.id = existing_pass_id
        and p.organization_id = new.organization_id
        and p.student_id = new.student_id
    ) then
      raise exception '划卡记录与学员不一致。'
        using errcode = '23514';
    end if;

    update public.session_pass_uses
    set
      session_id = new.session_id,
      student_id = new.student_id,
      used_at = new.recorded_at
    where attendance_id = new.id
      and organization_id = new.organization_id;
    return new;
  end if;

  select p.id
  into selected_pass_id
  from public.student_session_passes p
  where p.organization_id = new.organization_id
    and p.student_id = new.student_id
    and p.is_active
    and (
      select count(*)
      from public.session_pass_uses u
      where u.student_session_pass_id = p.id
        and u.organization_id = p.organization_id
    ) < p.included_sessions
  order by p.issued_at, p.id
  limit 1
  for update of p;

  if selected_pass_id is null then
    raise exception '这名学员没有可用次数，请先发放或启用一张次卡。'
      using errcode = '23514';
  end if;

  insert into public.session_pass_uses (
    organization_id,
    student_session_pass_id,
    attendance_id,
    session_id,
    student_id,
    used_at
  )
  values (
    new.organization_id,
    selected_pass_id,
    new.id,
    new.session_id,
    new.student_id,
    new.recorded_at
  );

  return new;
end;
$$;

revoke execute on function private.validate_student_session_pass()
from public, anon, authenticated;
revoke execute on function private.protect_used_student_session_pass()
from public, anon, authenticated;
revoke execute on function private.sync_session_pass_use()
from public, anon, authenticated;

create trigger attendance_sync_session_pass_use
after insert or update of uses_session_pass, status, enrollment_id,
  makeup_for_session_id, session_id, student_id, recorded_at
on public.attendance
for each row execute function private.sync_session_pass_use();

alter table public.session_pass_plans enable row level security;
alter table public.student_session_passes enable row level security;
alter table public.session_pass_uses enable row level security;

revoke all on public.session_pass_plans, public.student_session_passes,
  public.session_pass_uses from public, anon, authenticated;
grant select, insert, update, delete on public.session_pass_plans,
  public.student_session_passes to authenticated;
grant select on public.session_pass_uses to authenticated;

create policy session_pass_plans_admin_all
on public.session_pass_plans
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

create policy session_pass_plans_member_select
on public.session_pass_plans
for select
to authenticated
using (
  organization_id = private.current_user_organization_id()
  and is_active
);

create policy student_session_passes_admin_all
on public.student_session_passes
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

create policy student_session_passes_member_select
on public.student_session_passes
for select
to authenticated
using (private.can_access_student(student_id));

create policy session_pass_uses_admin_select
on public.session_pass_uses
for select
to authenticated
using (
  private.is_admin()
  and organization_id = private.current_user_organization_id()
);

create policy session_pass_uses_member_select
on public.session_pass_uses
for select
to authenticated
using (private.can_access_student(student_id));

create trigger session_pass_plans_audit
after insert or update or delete on public.session_pass_plans
for each row execute function private.capture_audit_event();

create trigger student_session_passes_audit
after insert or update or delete on public.student_session_passes
for each row execute function private.capture_audit_event();

create trigger session_pass_uses_audit
after insert or update or delete on public.session_pass_uses
for each row execute function private.capture_audit_event();

do $$
declare
  target_table text;
begin
  foreach target_table in array array[
    'session_pass_plans',
    'student_session_passes',
    'session_pass_uses'
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

comment on table public.session_pass_plans is
  'Administrator-defined reusable N-session card templates.';
comment on table public.student_session_passes is
  'Learner-owned session cards with immutable issue-time count and unit-price snapshots.';
comment on table public.session_pass_uses is
  'One automatically managed card use for one backward-compatible attendance visit.';

commit;
