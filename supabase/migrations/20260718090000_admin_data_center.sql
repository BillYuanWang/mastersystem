begin;

create table public.course_types (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 120),
  is_private boolean not null default false,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint course_types_id_organization_key unique (id, organization_id)
);

create unique index course_types_organization_name_key
  on public.course_types (organization_id, lower(name));

create table public.term_holidays (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  term_id uuid not null,
  name text not null check (length(btrim(name)) between 1 and 120),
  starts_on date not null,
  ends_on date not null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint term_holidays_date_order check (starts_on <= ends_on),
  constraint term_holidays_term_fk
    foreign key (term_id, organization_id)
    references public.terms(id, organization_id) on delete restrict,
  constraint term_holidays_id_organization_key unique (id, organization_id)
);

create index term_holidays_term_dates_idx
  on public.term_holidays (term_id, starts_on, ends_on);

create or replace function private.validate_term_holiday()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  term_row public.terms;
begin
  select * into term_row
  from public.terms t
  where t.id = new.term_id
    and t.organization_id = new.organization_id;

  if not found then
    raise exception '找不到这个学期。' using errcode = '23503';
  end if;

  if new.starts_on < term_row.starts_on or new.ends_on > term_row.ends_on then
    raise exception '假期日期必须位于学期范围内。' using errcode = '23514';
  end if;

  return new;
end;
$$;

create or replace function private.validate_term_date_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.term_holidays h
    where h.term_id = new.id
      and (h.starts_on < new.starts_on or h.ends_on > new.ends_on)
  ) then
    raise exception '学期日期不能排除已有假期。' using errcode = '23514';
  end if;

  if exists (
    select 1
    from public.courses c
    join public.class_sessions s on s.course_id = c.id
    join public.organizations o on o.id = c.organization_id
    where c.term_id = new.id
      and (
        (s.starts_at at time zone o.timezone)::date < new.starts_on
        or (s.ends_at at time zone o.timezone)::date > new.ends_on
      )
  ) then
    raise exception '学期日期不能排除已有课次。' using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger course_types_set_updated_at
before update on public.course_types
for each row execute function private.set_updated_at();

create trigger term_holidays_set_updated_at
before update on public.term_holidays
for each row execute function private.set_updated_at();

create trigger term_holidays_validate
before insert or update on public.term_holidays
for each row execute function private.validate_term_holiday();

create trigger terms_validate_date_change
before update of starts_on, ends_on on public.terms
for each row execute function private.validate_term_date_change();

alter table public.courses
  add column course_type_id uuid,
  add column is_active boolean not null default true;

insert into public.course_types (
  organization_id,
  name,
  is_private
)
select distinct
  c.organization_id,
  case c.format
    when 'private_lesson'::public.course_format then '私课'
    else '组课'
  end,
  c.format = 'private_lesson'::public.course_format
from public.courses c
on conflict do nothing;

update public.courses c
set course_type_id = ct.id
from public.course_types ct
where ct.organization_id = c.organization_id
  and ct.is_private = (c.format = 'private_lesson'::public.course_format)
  and c.course_type_id is null;

alter table public.courses
  alter column course_type_id set not null,
  add constraint courses_course_type_fk
    foreign key (course_type_id, organization_id)
    references public.course_types(id, organization_id) on delete restrict;

create index courses_course_type_idx on public.courses (course_type_id);

create or replace function private.prepare_course_type()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  private_value boolean;
begin
  select ct.is_private into private_value
  from public.course_types ct
  where ct.id = new.course_type_id
    and ct.organization_id = new.organization_id;

  if not found then
    raise exception '找不到这个课程种类。' using errcode = '23503';
  end if;

  new.format := case
    when private_value then 'private_lesson'::public.course_format
    else 'group'::public.course_format
  end;
  return new;
end;
$$;

create trigger courses_prepare_course_type
before insert or update of course_type_id, organization_id on public.courses
for each row execute function private.prepare_course_type();

create or replace function private.propagate_course_type_privacy()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.is_private is distinct from old.is_private then
    update public.courses
    set format = case
      when new.is_private then 'private_lesson'::public.course_format
      else 'group'::public.course_format
    end
    where course_type_id = new.id
      and organization_id = new.organization_id;
  end if;
  return new;
end;
$$;

create trigger course_types_propagate_privacy
after update of is_private on public.course_types
for each row execute function private.propagate_course_type_privacy();

alter table public.students add column guardian_id uuid;

update public.students s
set guardian_id = (
  select gs.guardian_id
  from public.guardian_students gs
  where gs.student_id = s.id
    and gs.organization_id = s.organization_id
  order by gs.is_primary desc, gs.created_at, gs.guardian_id
  limit 1
)
where s.guardian_id is null;

do $$
declare
  student_row record;
  guardian_id_value uuid;
begin
  for student_row in
    select s.id, s.organization_id, s.display_name, s.kind
    from public.students s
    where s.guardian_id is null
  loop
    insert into public.guardians (
      organization_id,
      display_name
    )
    values (
      student_row.organization_id,
      case student_row.kind
        when 'adult'::public.student_kind then student_row.display_name
        else student_row.display_name || '家庭'
      end
    )
    returning id into guardian_id_value;

    update public.students
    set guardian_id = guardian_id_value
    where id = student_row.id;
  end loop;
end;
$$;

delete from public.guardian_students gs
using public.students s
where gs.student_id = s.id
  and gs.guardian_id <> s.guardian_id;

insert into public.guardian_students (
  organization_id,
  guardian_id,
  student_id,
  relationship_label,
  is_primary
)
select
  s.organization_id,
  s.guardian_id,
  s.id,
  case s.kind when 'adult'::public.student_kind then 'self' else 'child' end,
  true
from public.students s
on conflict (guardian_id, student_id) do update
set
  relationship_label = excluded.relationship_label,
  is_primary = true;

create unique index guardian_students_one_guardian_per_student
  on public.guardian_students (student_id);

alter table public.students
  alter column guardian_id set not null,
  add constraint students_guardian_fk
    foreign key (guardian_id, organization_id)
    references public.guardians(id, organization_id) on delete restrict;

create index students_guardian_idx on public.students (guardian_id, display_name);

create or replace function private.sync_student_guardian_link()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.guardian_students
  where student_id = new.id
    and guardian_id <> new.guardian_id;

  insert into public.guardian_students (
    organization_id,
    guardian_id,
    student_id,
    relationship_label,
    is_primary
  )
  values (
    new.organization_id,
    new.guardian_id,
    new.id,
    case new.kind when 'adult'::public.student_kind then 'self' else 'child' end,
    true
  )
  on conflict (guardian_id, student_id) do update
  set
    relationship_label = excluded.relationship_label,
    is_primary = true;

  return new;
end;
$$;

create trigger students_sync_guardian_link
after insert or update of guardian_id, kind on public.students
for each row execute function private.sync_student_guardian_link();

create or replace function public.admin_create_student_for_guardian(
  target_guardian_id uuid,
  target_display_name text,
  target_legal_name text default null,
  target_kind public.student_kind default 'child'
)
returns public.students
language plpgsql
security definer
set search_path = ''
as $$
declare
  organization_id_value uuid := private.current_user_organization_id();
  resulting_student public.students;
begin
  if not private.is_admin() then
    raise exception '需要教务管理员权限。' using errcode = '42501';
  end if;

  if length(btrim(coalesce(target_display_name, ''))) not between 1 and 120 then
    raise exception '学员姓名需要填写 1 到 120 个字符。' using errcode = '22023';
  end if;

  perform 1
  from public.guardians g
  where g.id = target_guardian_id
    and g.organization_id = organization_id_value;

  if not found then
    raise exception '找不到这个监护人。' using errcode = 'P0002';
  end if;

  insert into public.students (
    organization_id,
    guardian_id,
    display_name,
    legal_name,
    kind
  )
  values (
    organization_id_value,
    target_guardian_id,
    btrim(target_display_name),
    nullif(btrim(coalesce(target_legal_name, '')), ''),
    target_kind
  )
  returning * into resulting_student;

  return resulting_student;
end;
$$;

create or replace function public.admin_link_student_to_guardian(
  target_guardian_id uuid,
  target_student_id uuid
)
returns public.guardian_students
language plpgsql
security definer
set search_path = ''
as $$
declare
  organization_id_value uuid := private.current_user_organization_id();
  resulting_link public.guardian_students;
begin
  if not private.is_admin() then
    raise exception '需要教务管理员权限。' using errcode = '42501';
  end if;

  perform 1
  from public.guardians g
  where g.id = target_guardian_id
    and g.organization_id = organization_id_value;

  if not found then
    raise exception '找不到这个监护人。' using errcode = 'P0002';
  end if;

  update public.students
  set guardian_id = target_guardian_id
  where id = target_student_id
    and organization_id = organization_id_value
    and is_active;

  if not found then
    raise exception '找不到这个学员。' using errcode = 'P0002';
  end if;

  select * into resulting_link
  from public.guardian_students
  where guardian_id = target_guardian_id
    and student_id = target_student_id;

  return resulting_link;
end;
$$;

alter table public.courses drop constraint courses_term_fk;
alter table public.courses
  add constraint courses_term_fk
    foreign key (term_id, organization_id)
    references public.terms(id, organization_id) on delete restrict;

alter table public.class_sessions drop constraint class_sessions_course_fk;
alter table public.class_sessions
  add constraint class_sessions_course_fk
    foreign key (course_id, organization_id)
    references public.courses(id, organization_id) on delete restrict;

alter table public.enrollments drop constraint enrollments_course_term_fk;
alter table public.enrollments
  add constraint enrollments_course_term_fk
    foreign key (course_id, term_id, organization_id)
    references public.courses(id, term_id, organization_id) on delete restrict;

alter table public.enrollments drop constraint enrollments_student_fk;
alter table public.enrollments
  add constraint enrollments_student_fk
    foreign key (student_id, organization_id)
    references public.students(id, organization_id) on delete restrict;

alter table public.attendance drop constraint attendance_session_fk;
alter table public.attendance
  add constraint attendance_session_fk
    foreign key (session_id, organization_id)
    references public.class_sessions(id, organization_id) on delete restrict;

alter table public.attendance drop constraint attendance_student_fk;
alter table public.attendance
  add constraint attendance_student_fk
    foreign key (student_id, organization_id)
    references public.students(id, organization_id) on delete restrict;

alter table public.leave_requests drop constraint leave_requests_session_fk;
alter table public.leave_requests
  add constraint leave_requests_session_fk
    foreign key (session_id, organization_id)
    references public.class_sessions(id, organization_id) on delete restrict;

alter table public.leave_requests drop constraint leave_requests_student_fk;
alter table public.leave_requests
  add constraint leave_requests_student_fk
    foreign key (student_id, organization_id)
    references public.students(id, organization_id) on delete restrict;

alter table public.contract_documents drop constraint contract_documents_term_fk;
alter table public.contract_documents
  add constraint contract_documents_term_fk
    foreign key (term_id, organization_id)
    references public.terms(id, organization_id) on delete restrict;

create or replace function public.admin_delete_record(
  target_kind text,
  target_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  organization_id_value uuid := private.current_user_organization_id();
begin
  if not private.is_admin() then
    raise exception '需要教务管理员权限。' using errcode = '42501';
  end if;

  case target_kind
    when 'term' then
      if exists (
           select 1 from public.courses
           where term_id = target_id and organization_id = organization_id_value
         )
         or exists (
           select 1 from public.term_holidays
           where term_id = target_id and organization_id = organization_id_value
         )
         or exists (
           select 1 from public.contract_documents
           where term_id = target_id and organization_id = organization_id_value
         ) then
        raise exception '这个学期已有课程、假期或合同，不能删除。' using errcode = '23503';
      end if;
      delete from public.terms where id = target_id and organization_id = organization_id_value;
    when 'term_holiday' then
      delete from public.term_holidays where id = target_id and organization_id = organization_id_value;
    when 'course_category' then
      if exists (
        select 1 from public.courses
        where category_id = target_id and organization_id = organization_id_value
      ) then
        raise exception '这个课程分类已被课程使用，不能删除。' using errcode = '23503';
      end if;
      delete from public.course_categories where id = target_id and organization_id = organization_id_value;
    when 'course_type' then
      if exists (
        select 1 from public.courses
        where course_type_id = target_id and organization_id = organization_id_value
      ) then
        raise exception '这个课程种类已被课程使用，不能删除。' using errcode = '23503';
      end if;
      delete from public.course_types where id = target_id and organization_id = organization_id_value;
    when 'age_group' then
      if exists (
        select 1 from public.courses
        where age_group_id = target_id and organization_id = organization_id_value
      ) then
        raise exception '这个年龄段已被课程使用，不能删除。' using errcode = '23503';
      end if;
      delete from public.age_groups where id = target_id and organization_id = organization_id_value;
    when 'room' then
      if exists (
           select 1 from public.courses
           where default_room_id = target_id and organization_id = organization_id_value
         )
         or exists (
           select 1 from public.class_sessions
           where organization_id = organization_id_value
             and (room_override_id = target_id or effective_room_id = target_id)
         ) then
        raise exception '这个教室已被课程或课次使用，不能删除。' using errcode = '23503';
      end if;
      delete from public.rooms where id = target_id and organization_id = organization_id_value;
    when 'instructor' then
      if exists (
           select 1 from public.courses
           where default_instructor_id = target_id and organization_id = organization_id_value
         )
         or exists (
           select 1 from public.class_sessions
           where organization_id = organization_id_value
             and (instructor_override_id = target_id or effective_instructor_id = target_id)
         ) then
        raise exception '这位老师已被课程或课次使用，不能删除。' using errcode = '23503';
      end if;
      delete from public.instructors where id = target_id and organization_id = organization_id_value;
    when 'course' then
      if exists (
           select 1 from public.class_sessions
           where course_id = target_id and organization_id = organization_id_value
         )
         or exists (
           select 1 from public.enrollments
           where course_id = target_id and organization_id = organization_id_value
         ) then
        raise exception '这门课程已有课次或报名，不能删除；可以将它停用。' using errcode = '23503';
      end if;
      delete from public.courses where id = target_id and organization_id = organization_id_value;
    when 'guardian' then
      if exists (
           select 1 from public.guardians
           where id = target_id
             and organization_id = organization_id_value
             and profile_user_id is not null
         )
         or exists (
           select 1 from public.students
           where guardian_id = target_id and organization_id = organization_id_value
         ) then
        raise exception '这个监护人已连接帐号或仍有学员档案，不能删除。' using errcode = '23503';
      end if;
      delete from public.guardians where id = target_id and organization_id = organization_id_value;
    when 'student' then
      if exists (
           select 1 from public.students
           where id = target_id
             and organization_id = organization_id_value
             and profile_user_id is not null
         )
         or exists (
           select 1 from public.enrollments
           where student_id = target_id and organization_id = organization_id_value
         )
         or exists (
           select 1 from public.attendance
           where student_id = target_id and organization_id = organization_id_value
         )
         or exists (
           select 1 from public.leave_requests
           where student_id = target_id and organization_id = organization_id_value
         ) then
        raise exception '这个学员已有帐号、报名、签到或请假记录，不能删除；可以将档案停用。'
          using errcode = '23503';
      end if;
      delete from public.students where id = target_id and organization_id = organization_id_value;
    when 'contract_document' then
      if exists (
        select 1 from public.contract_consents
        where contract_document_id = target_id
          and organization_id = organization_id_value
      ) then
        raise exception '这份合同已有签署记录，不能删除；可以将它停用。' using errcode = '23503';
      end if;
      delete from public.contract_documents where id = target_id and organization_id = organization_id_value;
    else
      raise exception '不支持删除这种资料。' using errcode = '22023';
  end case;
end;
$$;

alter table public.course_types enable row level security;
alter table public.term_holidays enable row level security;

revoke all on public.course_types, public.term_holidays from public, anon, authenticated;
grant select, insert, update, delete on public.course_types, public.term_holidays to authenticated;

create policy course_types_admin_all
on public.course_types
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

create policy course_types_member_select
on public.course_types
for select
to authenticated
using (
  organization_id = private.current_user_organization_id()
  and is_active
);

create policy term_holidays_admin_all
on public.term_holidays
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

create policy term_holidays_member_select
on public.term_holidays
for select
to authenticated
using (private.can_access_term(term_id));

create trigger course_types_audit
after insert or update or delete on public.course_types
for each row execute function private.capture_audit_event();

create trigger term_holidays_audit
after insert or update or delete on public.term_holidays
for each row execute function private.capture_audit_event();

revoke all on function public.admin_delete_record(text, uuid)
  from public, anon, authenticated;
grant execute on function public.admin_delete_record(text, uuid)
  to authenticated;

revoke insert, update, delete on public.guardian_students
  from authenticated;

commit;
