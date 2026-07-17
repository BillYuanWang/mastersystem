begin;

create or replace function private.current_user_organization_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.organization_id
  from public.profiles p
  where p.user_id = (select auth.uid())
    and p.is_active
  limit 1
$$;

create or replace function private.current_user_role()
returns public.app_role
language sql
stable
security definer
set search_path = ''
as $$
  select p.role
  from public.profiles p
  where p.user_id = (select auth.uid())
    and p.is_active
  limit 1
$$;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select p.role = 'administrator'::public.app_role
      from public.profiles p
      where p.user_id = (select auth.uid())
        and p.is_active
      limit 1
    ),
    false
  )
$$;

create or replace function private.is_same_organization(target_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select target_organization_id is not null
    and target_organization_id = private.current_user_organization_id()
$$;

create or replace function private.can_access_student(target_student_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    exists (
      select 1
      from public.students s
      where s.id = target_student_id
        and s.organization_id = private.current_user_organization_id()
        and (
          private.is_admin()
          or s.profile_user_id = (select auth.uid())
          or exists (
            select 1
            from public.guardian_students gs
            join public.guardians g on g.id = gs.guardian_id
            where gs.student_id = s.id
              and gs.organization_id = s.organization_id
              and g.profile_user_id = (select auth.uid())
          )
        )
    ),
    false
  )
$$;

create or replace function private.is_linked_guardian(target_guardian_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    exists (
      select 1
      from public.guardians g
      where g.id = target_guardian_id
        and g.organization_id = private.current_user_organization_id()
        and (
          private.is_admin()
          or g.profile_user_id = (select auth.uid())
        )
    ),
    false
  )
$$;

create or replace function private.can_access_course(target_course_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    exists (
      select 1
      from public.courses c
      where c.id = target_course_id
        and c.organization_id = private.current_user_organization_id()
        and (
          private.is_admin()
          or exists (
            select 1
            from public.enrollments e
            where e.course_id = c.id
              and e.organization_id = c.organization_id
              and e.status <> 'withdrawn'::public.enrollment_status
              and private.can_access_student(e.student_id)
          )
        )
    ),
    false
  )
$$;

create or replace function private.can_access_session(target_session_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select private.can_access_course(s.course_id)
      from public.class_sessions s
      where s.id = target_session_id
        and s.organization_id = private.current_user_organization_id()
      limit 1
    ),
    false
  )
$$;

create or replace function private.can_access_term(target_term_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    exists (
      select 1
      from public.terms t
      where t.id = target_term_id
        and t.organization_id = private.current_user_organization_id()
        and (
          private.is_admin()
          or exists (
            select 1
            from public.enrollments e
            where e.term_id = t.id
              and e.organization_id = t.organization_id
              and e.status <> 'withdrawn'::public.enrollment_status
              and private.can_access_student(e.student_id)
          )
        )
    ),
    false
  )
$$;

create or replace function private.can_request_leave(
  target_session_id uuid,
  target_student_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    private.can_access_student(target_student_id)
    and exists (
      select 1
      from public.class_sessions s
      join public.enrollments e
        on e.course_id = s.course_id
       and e.student_id = target_student_id
       and e.organization_id = s.organization_id
      where s.id = target_session_id
        and s.organization_id = private.current_user_organization_id()
        and e.status = 'active'::public.enrollment_status
    ),
    false
  )
$$;

create or replace function private.can_access_contract(target_document_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    exists (
      select 1
      from public.contract_documents d
      where d.id = target_document_id
        and d.organization_id = private.current_user_organization_id()
        and (
          private.is_admin()
          or (
            d.status = 'published'::public.contract_document_status
            and private.can_access_term(d.term_id)
          )
        )
    ),
    false
  )
$$;

create or replace function private.can_access_contract_object(target_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    exists (
      select 1
      from public.contract_documents d
      where d.storage_path = target_path
        and private.can_access_contract(d.id)
    ),
    false
  )
$$;

create or replace function private.protect_profile_authorization()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_admin()
     and (
       new.user_id is distinct from old.user_id
       or new.organization_id is distinct from old.organization_id
       or new.role is distinct from old.role
       or new.is_active is distinct from old.is_active
       or new.created_at is distinct from old.created_at
     ) then
    raise exception 'Only administrators may change profile authorization'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create or replace function private.protect_guardian_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_admin()
     and (
       new.id is distinct from old.id
       or new.organization_id is distinct from old.organization_id
       or new.profile_user_id is distinct from old.profile_user_id
       or new.created_at is distinct from old.created_at
     ) then
    raise exception 'Only administrators may change guardian identity links'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger profiles_protect_authorization
before update on public.profiles
for each row execute function private.protect_profile_authorization();

create trigger guardians_protect_identity
before update on public.guardians
for each row execute function private.protect_guardian_identity();

create or replace function public.bootstrap_first_administrator(
  display_name text
)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
  target_organization_id uuid;
  created_profile public.profiles;
begin
  if current_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if exists (select 1 from public.profiles) then
    raise exception 'Administrator bootstrap has already been completed'
      using errcode = '42501';
  end if;

  select id into target_organization_id
  from public.organizations
  order by created_at
  limit 1;

  if target_organization_id is null then
    raise exception 'No organization is available for bootstrap'
      using errcode = '23503';
  end if;

  insert into public.profiles (
    user_id,
    organization_id,
    role,
    display_name
  )
  values (
    current_user_id,
    target_organization_id,
    'administrator',
    btrim(display_name)
  )
  returning * into created_profile;

  return created_profile;
end;
$$;

create or replace function public.admin_update_profile_access(
  target_user_id uuid,
  target_display_name text,
  target_is_active boolean default true
)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  organization_id_value uuid := private.current_user_organization_id();
  existing_role public.app_role;
  resulting_profile public.profiles;
begin
  if not private.is_admin() then
    raise exception 'Administrator access required' using errcode = '42501';
  end if;

  select role into existing_role
  from public.profiles
  where user_id = target_user_id
    and organization_id = organization_id_value;

  if not found then
    raise exception 'Profile not found in this organization'
      using errcode = 'P0002';
  end if;

  if existing_role = 'administrator'::public.app_role
     and not target_is_active
     and (
       select count(*)
       from public.profiles
       where organization_id = organization_id_value
         and role = 'administrator'::public.app_role
         and is_active
     ) <= 1 then
    raise exception 'The final active administrator cannot be removed'
      using errcode = '23514';
  end if;

  update public.profiles
  set
    display_name = btrim(target_display_name),
    is_active = target_is_active
  where user_id = target_user_id
    and organization_id = organization_id_value
  returning * into resulting_profile;

  return resulting_profile;
end;
$$;

create or replace function public.admin_finalize_invited_member(
  target_user_id uuid,
  target_email text,
  target_display_name text,
  target_role public.app_role,
  target_student_ids uuid[] default '{}'::uuid[]
)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  organization_id_value uuid := private.current_user_organization_id();
  normalized_student_ids uuid[];
  guardian_id_value uuid;
  resulting_profile public.profiles;
begin
  if not private.is_admin() then
    raise exception 'Administrator access required' using errcode = '42501';
  end if;

  if length(btrim(target_display_name)) < 1
     or length(btrim(target_display_name)) > 120 then
    raise exception 'Display name must contain 1 to 120 characters'
      using errcode = '22023';
  end if;

  select coalesce(array_agg(distinct value), '{}'::uuid[])
  into normalized_student_ids
  from unnest(coalesce(target_student_ids, '{}'::uuid[])) as ids(value);

  if exists (
    select 1
    from unnest(normalized_student_ids) as ids(student_id)
    left join public.students s
      on s.id = ids.student_id
      and s.organization_id = organization_id_value
      and s.is_active
    where s.id is null
  ) then
    raise exception 'One or more students are unavailable'
      using errcode = '42501';
  end if;

  if target_role = 'administrator'::public.app_role
     and cardinality(normalized_student_ids) <> 0 then
    raise exception 'Administrators cannot be linked to students during invitation'
      using errcode = '22023';
  end if;

  if target_role = 'adult_student'::public.app_role then
    if cardinality(normalized_student_ids) <> 1 then
      raise exception 'Adult-student invitations require exactly one student'
        using errcode = '22023';
    end if;

    if not exists (
      select 1
      from public.students s
      where s.id = normalized_student_ids[1]
        and s.organization_id = organization_id_value
        and s.kind = 'adult'::public.student_kind
        and (s.profile_user_id is null or s.profile_user_id = target_user_id)
    ) then
      raise exception 'The selected record is not an available adult student'
        using errcode = '22023';
    end if;
  end if;

  insert into public.profiles (
    user_id,
    organization_id,
    role,
    display_name
  )
  values (
    target_user_id,
    organization_id_value,
    target_role,
    btrim(target_display_name)
  )
  returning * into resulting_profile;

  if target_role = 'guardian'::public.app_role then
    insert into public.guardians (
      organization_id,
      profile_user_id,
      display_name,
      email
    )
    values (
      organization_id_value,
      target_user_id,
      btrim(target_display_name),
      lower(btrim(target_email))
    )
    returning id into guardian_id_value;

    insert into public.guardian_students (
      organization_id,
      guardian_id,
      student_id,
      is_primary
    )
    select
      organization_id_value,
      guardian_id_value,
      student_id,
      true
    from unnest(normalized_student_ids) as ids(student_id);
  elsif target_role = 'adult_student'::public.app_role then
    update public.students
    set profile_user_id = target_user_id
    where id = normalized_student_ids[1]
      and organization_id = organization_id_value;
  end if;

  return resulting_profile;
end;
$$;

create or replace function public.submit_leave_request(
  target_session_id uuid,
  target_student_id uuid,
  request_note text default null
)
returns public.leave_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  organization_id_value uuid := private.current_user_organization_id();
  enrollment_id_value uuid;
  resulting_request public.leave_requests;
begin
  if not private.can_request_leave(target_session_id, target_student_id) then
    raise exception 'Student is not eligible for this leave request'
      using errcode = '42501';
  end if;

  select e.id into enrollment_id_value
  from public.class_sessions s
  join public.enrollments e
    on e.course_id = s.course_id
   and e.student_id = target_student_id
   and e.organization_id = s.organization_id
  where s.id = target_session_id
    and e.status = 'active'::public.enrollment_status
  limit 1;

  insert into public.leave_requests (
    organization_id,
    session_id,
    student_id,
    enrollment_id,
    source,
    status,
    submitted_by,
    note
  )
  values (
    organization_id_value,
    target_session_id,
    target_student_id,
    enrollment_id_value,
    'app',
    'pending',
    (select auth.uid()),
    nullif(btrim(request_note), '')
  )
  on conflict (session_id, student_id) do update
  set
    status = 'pending',
    submitted_at = now(),
    submitted_by = (select auth.uid()),
    resolved_at = null,
    resolved_by = null,
    note = excluded.note
  returning * into resulting_request;

  return resulting_request;
end;
$$;

create or replace function public.record_contract_consent(
  target_document_id uuid,
  target_enrollment_id uuid default null,
  signer_display_name text default null
)
returns public.contract_consents
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
  current_role public.app_role := private.current_user_role();
  organization_id_value uuid := private.current_user_organization_id();
  term_id_value uuid;
  scope_value public.contract_consent_scope;
  signer_kind_value public.consent_signer_kind;
  resolved_display_name text;
  resulting_consent public.contract_consents;
begin
  if current_role is null or current_role not in (
    'guardian'::public.app_role,
    'adult_student'::public.app_role
  ) then
    raise exception 'Guardian or adult-student access required'
      using errcode = '42501';
  end if;

  if not private.can_access_contract(target_document_id) then
    raise exception 'Contract is not available to this user'
      using errcode = '42501';
  end if;

  select d.term_id into term_id_value
  from public.contract_documents d
  where d.id = target_document_id;

  if target_enrollment_id is not null
     and not exists (
       select 1
       from public.enrollments e
       where e.id = target_enrollment_id
         and e.term_id = term_id_value
         and private.can_access_student(e.student_id)
     ) then
    raise exception 'Enrollment is not available to this signer'
      using errcode = '42501';
  end if;

  scope_value := case
    when target_enrollment_id is null then 'term'::public.contract_consent_scope
    else 'enrollment'::public.contract_consent_scope
  end;

  signer_kind_value := case current_role
    when 'guardian'::public.app_role then 'guardian'::public.consent_signer_kind
    else 'adult_student'::public.consent_signer_kind
  end;

  select coalesce(nullif(btrim(signer_display_name), ''), p.display_name)
  into resolved_display_name
  from public.profiles p
  where p.user_id = current_user_id;

  insert into public.contract_consents (
    organization_id,
    contract_document_id,
    term_id,
    enrollment_id,
    scope,
    signer_user_id,
    signer_kind,
    signer_display_name
  )
  values (
    organization_id_value,
    target_document_id,
    term_id_value,
    target_enrollment_id,
    scope_value,
    current_user_id,
    signer_kind_value,
    resolved_display_name
  )
  returning * into resulting_consent;

  return resulting_consent;
end;
$$;

create or replace function public.mark_notification_read(
  target_notification_id uuid
)
returns public.notifications
language plpgsql
security definer
set search_path = ''
as $$
declare
  resulting_notification public.notifications;
begin
  update public.notifications
  set
    status = 'read',
    read_at = coalesce(read_at, now())
  where id = target_notification_id
    and recipient_user_id = (select auth.uid())
  returning * into resulting_notification;

  if not found then
    raise exception 'Notification not found' using errcode = 'P0002';
  end if;

  return resulting_notification;
end;
$$;

alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.terms enable row level security;
alter table public.course_categories enable row level security;
alter table public.age_groups enable row level security;
alter table public.rooms enable row level security;
alter table public.instructors enable row level security;
alter table public.courses enable row level security;
alter table public.class_sessions enable row level security;
alter table public.students enable row level security;
alter table public.guardians enable row level security;
alter table public.guardian_students enable row level security;
alter table public.enrollments enable row level security;
alter table public.attendance enable row level security;
alter table public.leave_requests enable row level security;
alter table public.contract_documents enable row level security;
alter table public.contract_consents enable row level security;
alter table public.notifications enable row level security;
alter table public.device_push_tokens enable row level security;
alter table public.migration_runs enable row level security;
alter table public.migration_row_mappings enable row level security;

revoke all on all tables in schema public from anon;
revoke all on all tables in schema public from authenticated;

grant select, insert, update, delete on table
  public.organizations,
  public.terms,
  public.course_categories,
  public.age_groups,
  public.rooms,
  public.instructors,
  public.courses,
  public.class_sessions,
  public.students,
  public.guardians,
  public.guardian_students,
  public.enrollments,
  public.attendance,
  public.leave_requests,
  public.contract_documents,
  public.contract_consents,
  public.notifications,
  public.device_push_tokens,
  public.migration_runs,
  public.migration_row_mappings
to authenticated;

grant select on public.profiles to authenticated;
grant update (display_name, appearance) on public.profiles to authenticated;
grant usage, select on all sequences in schema public to authenticated;

create policy organizations_admin_all
on public.organizations
for all
to authenticated
using (private.is_admin() and private.is_same_organization(id))
with check (private.is_admin() and private.is_same_organization(id));

create policy organizations_member_select
on public.organizations
for select
to authenticated
using (private.is_same_organization(id));

create policy profiles_admin_all
on public.profiles
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

create policy profiles_self_select
on public.profiles
for select
to authenticated
using (user_id = (select auth.uid()) and is_active);

create policy profiles_self_update
on public.profiles
for update
to authenticated
using (user_id = (select auth.uid()) and is_active)
with check (user_id = (select auth.uid()) and is_active);

create policy terms_admin_all
on public.terms
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

create policy terms_member_select
on public.terms
for select
to authenticated
using (private.can_access_term(id));

create policy course_categories_admin_all
on public.course_categories
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

create policy course_categories_member_select
on public.course_categories
for select
to authenticated
using (organization_id = private.current_user_organization_id() and is_active);

create policy age_groups_admin_all
on public.age_groups
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

create policy age_groups_member_select
on public.age_groups
for select
to authenticated
using (organization_id = private.current_user_organization_id() and is_active);

create policy rooms_admin_all
on public.rooms
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

create policy rooms_member_select
on public.rooms
for select
to authenticated
using (organization_id = private.current_user_organization_id() and is_active);

create policy instructors_admin_all
on public.instructors
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

create policy instructors_member_select
on public.instructors
for select
to authenticated
using (organization_id = private.current_user_organization_id() and is_active);

create policy courses_admin_all
on public.courses
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

create policy courses_member_select
on public.courses
for select
to authenticated
using (private.can_access_course(id));

create policy class_sessions_admin_all
on public.class_sessions
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

create policy class_sessions_member_select
on public.class_sessions
for select
to authenticated
using (private.can_access_session(id));

create policy students_admin_all
on public.students
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

create policy students_member_select
on public.students
for select
to authenticated
using (private.can_access_student(id));

create policy guardians_admin_all
on public.guardians
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

create policy guardians_self_select
on public.guardians
for select
to authenticated
using (
  profile_user_id = (select auth.uid())
  and organization_id = private.current_user_organization_id()
);

create policy guardians_self_update
on public.guardians
for update
to authenticated
using (
  profile_user_id = (select auth.uid())
  and organization_id = private.current_user_organization_id()
)
with check (
  profile_user_id = (select auth.uid())
  and organization_id = private.current_user_organization_id()
);

create policy guardian_students_admin_all
on public.guardian_students
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

create policy guardian_students_member_select
on public.guardian_students
for select
to authenticated
using (
  private.is_linked_guardian(guardian_id)
  and private.can_access_student(student_id)
);

create policy enrollments_admin_all
on public.enrollments
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

create policy enrollments_member_select
on public.enrollments
for select
to authenticated
using (private.can_access_student(student_id));

create policy attendance_admin_all
on public.attendance
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

create policy attendance_member_select
on public.attendance
for select
to authenticated
using (private.can_access_student(student_id));

create policy leave_requests_admin_all
on public.leave_requests
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

create policy leave_requests_member_select
on public.leave_requests
for select
to authenticated
using (private.can_access_student(student_id));

create policy contract_documents_admin_all
on public.contract_documents
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

create policy contract_documents_member_select
on public.contract_documents
for select
to authenticated
using (private.can_access_contract(id));

create policy contract_consents_admin_all
on public.contract_consents
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

create policy contract_consents_signer_select
on public.contract_consents
for select
to authenticated
using (signer_user_id = (select auth.uid()));

create policy notifications_admin_all
on public.notifications
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

create policy notifications_recipient_select
on public.notifications
for select
to authenticated
using (recipient_user_id = (select auth.uid()));

create policy device_push_tokens_owner_all
on public.device_push_tokens
for all
to authenticated
using (
  user_id = (select auth.uid())
  and organization_id = private.current_user_organization_id()
)
with check (
  user_id = (select auth.uid())
  and organization_id = private.current_user_organization_id()
);

create policy migration_runs_admin_all
on public.migration_runs
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

create policy migration_row_mappings_admin_all
on public.migration_row_mappings
for all
to authenticated
using (
  private.is_admin()
  and exists (
    select 1
    from public.migration_runs r
    where r.id = migration_run_id
      and r.organization_id = private.current_user_organization_id()
  )
)
with check (
  private.is_admin()
  and exists (
    select 1
    from public.migration_runs r
    where r.id = migration_run_id
      and r.organization_id = private.current_user_organization_id()
  )
);

revoke execute on all functions in schema private from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function
  private.current_user_organization_id(),
  private.current_user_role(),
  private.is_admin(),
  private.is_same_organization(uuid),
  private.can_access_student(uuid),
  private.is_linked_guardian(uuid),
  private.can_access_course(uuid),
  private.can_access_session(uuid),
  private.can_access_term(uuid),
  private.can_request_leave(uuid, uuid),
  private.can_access_contract(uuid),
  private.can_access_contract_object(text)
to authenticated;

revoke execute on function
  public.bootstrap_first_administrator(text),
  public.admin_update_profile_access(uuid, text, boolean),
  public.admin_finalize_invited_member(uuid, text, text, public.app_role, uuid[]),
  public.submit_leave_request(uuid, uuid, text),
  public.record_contract_consent(uuid, uuid, text),
  public.mark_notification_read(uuid)
from public, anon;

grant execute on function
  public.bootstrap_first_administrator(text),
  public.admin_update_profile_access(uuid, text, boolean),
  public.admin_finalize_invited_member(uuid, text, text, public.app_role, uuid[]),
  public.submit_leave_request(uuid, uuid, text),
  public.record_contract_consent(uuid, uuid, text),
  public.mark_notification_read(uuid)
to authenticated;

commit;
