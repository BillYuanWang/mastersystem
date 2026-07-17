begin;

create extension if not exists btree_gist with schema extensions;

create schema if not exists private;
revoke all on schema private from public;

create type public.app_role as enum (
  'administrator',
  'guardian',
  'adult_student'
);

create type public.appearance_preference as enum (
  'system',
  'light',
  'dark'
);

create type public.term_status as enum (
  'draft',
  'open',
  'closed'
);

create type public.course_format as enum (
  'group',
  'private_lesson'
);

create type public.class_session_status as enum (
  'scheduled',
  'cancelled',
  'completed'
);

create type public.student_kind as enum (
  'child',
  'adult'
);

create type public.enrollment_status as enum (
  'active',
  'withdrawn',
  'completed'
);

create type public.attendance_status as enum (
  'present',
  'absent',
  'excused',
  'makeup'
);

create type public.leave_request_source as enum (
  'app',
  'administrator'
);

create type public.leave_request_status as enum (
  'pending',
  'approved',
  'denied',
  'late'
);

create type public.contract_document_status as enum (
  'draft',
  'published',
  'retired'
);

create type public.contract_consent_scope as enum (
  'term',
  'enrollment'
);

create type public.consent_signer_kind as enum (
  'guardian',
  'adult_student'
);

create type public.notification_kind as enum (
  'class_reminder',
  'leave_submitted',
  'leave_resolved',
  'contract_available'
);

create type public.notification_channel as enum (
  'in_app',
  'apple_push'
);

create type public.notification_delivery_status as enum (
  'pending',
  'sent',
  'failed',
  'read'
);

create type public.migration_run_status as enum (
  'dry_run',
  'ready',
  'applying',
  'applied',
  'failed',
  'rolled_back'
);

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(btrim(name)) between 1 and 120),
  slug text not null check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  timezone text not null default 'America/Los_Angeles',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index organizations_slug_key on public.organizations (lower(slug));

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  role public.app_role not null,
  display_name text not null check (length(btrim(display_name)) between 1 and 120),
  appearance public.appearance_preference not null default 'system',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index profiles_organization_role_idx
  on public.profiles (organization_id, role)
  where is_active;

create table public.terms (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 120),
  starts_on date not null,
  ends_on date not null,
  status public.term_status not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint terms_date_order check (starts_on <= ends_on),
  constraint terms_id_organization_key unique (id, organization_id)
);

create index terms_organization_dates_idx
  on public.terms (organization_id, starts_on desc, ends_on desc);

create table public.course_categories (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 120),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint course_categories_id_organization_key unique (id, organization_id)
);

create unique index course_categories_organization_name_key
  on public.course_categories (organization_id, lower(name));

create table public.age_groups (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 120),
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint age_groups_id_organization_key unique (id, organization_id)
);

create unique index age_groups_organization_name_key
  on public.age_groups (organization_id, lower(name));

create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 120),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint rooms_id_organization_key unique (id, organization_id)
);

create unique index rooms_organization_name_key
  on public.rooms (organization_id, lower(name));

create table public.instructors (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  display_name text not null check (length(btrim(display_name)) between 1 and 120),
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint instructors_id_organization_key unique (id, organization_id)
);

create unique index instructors_organization_name_key
  on public.instructors (organization_id, lower(display_name));

create table public.courses (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  term_id uuid not null,
  name text not null check (length(btrim(name)) between 1 and 160),
  category_id uuid not null,
  age_group_id uuid not null,
  default_room_id uuid not null,
  default_instructor_id uuid not null,
  format public.course_format not null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint courses_term_fk
    foreign key (term_id, organization_id)
    references public.terms(id, organization_id) on delete cascade,
  constraint courses_category_fk
    foreign key (category_id, organization_id)
    references public.course_categories(id, organization_id) on delete restrict,
  constraint courses_age_group_fk
    foreign key (age_group_id, organization_id)
    references public.age_groups(id, organization_id) on delete restrict,
  constraint courses_room_fk
    foreign key (default_room_id, organization_id)
    references public.rooms(id, organization_id) on delete restrict,
  constraint courses_instructor_fk
    foreign key (default_instructor_id, organization_id)
    references public.instructors(id, organization_id) on delete restrict,
  constraint courses_id_organization_key unique (id, organization_id),
  constraint courses_id_term_organization_key unique (id, term_id, organization_id)
);

create index courses_term_idx on public.courses (term_id, name);
create index courses_category_idx on public.courses (category_id);
create index courses_age_group_idx on public.courses (age_group_id);

create table public.class_sessions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  course_id uuid not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  instructor_override_id uuid,
  room_override_id uuid,
  effective_instructor_id uuid not null,
  effective_room_id uuid not null,
  status public.class_session_status not null default 'scheduled',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint class_sessions_time_order check (starts_at < ends_at),
  constraint class_sessions_course_fk
    foreign key (course_id, organization_id)
    references public.courses(id, organization_id) on delete cascade,
  constraint class_sessions_instructor_override_fk
    foreign key (instructor_override_id, organization_id)
    references public.instructors(id, organization_id) on delete restrict,
  constraint class_sessions_room_override_fk
    foreign key (room_override_id, organization_id)
    references public.rooms(id, organization_id) on delete restrict,
  constraint class_sessions_effective_instructor_fk
    foreign key (effective_instructor_id, organization_id)
    references public.instructors(id, organization_id) on delete restrict,
  constraint class_sessions_effective_room_fk
    foreign key (effective_room_id, organization_id)
    references public.rooms(id, organization_id) on delete restrict,
  constraint class_sessions_id_organization_key unique (id, organization_id),
  constraint class_sessions_course_start_key unique (course_id, starts_at)
);

create index class_sessions_course_time_idx
  on public.class_sessions (course_id, starts_at);

create index class_sessions_room_time_idx
  on public.class_sessions (effective_room_id, starts_at);

alter table public.class_sessions
  add constraint class_sessions_room_no_overlap
  exclude using gist (
    organization_id with =,
    effective_room_id with =,
    tstzrange(starts_at, ends_at, '[)') with &&
  )
  where (status <> 'cancelled');

alter table public.class_sessions
  add constraint class_sessions_instructor_no_overlap
  exclude using gist (
    organization_id with =,
    effective_instructor_id with =,
    tstzrange(starts_at, ends_at, '[)') with &&
  )
  where (status <> 'cancelled');

create table public.students (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  profile_user_id uuid unique references auth.users(id) on delete set null,
  display_name text not null check (length(btrim(display_name)) between 1 and 120),
  legal_name text,
  kind public.student_kind not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint students_id_organization_key unique (id, organization_id),
  constraint students_profile_kind check (
    profile_user_id is null or kind = 'adult'
  )
);

create index students_organization_active_idx
  on public.students (organization_id, display_name)
  where is_active;

create table public.guardians (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  profile_user_id uuid unique references auth.users(id) on delete set null,
  display_name text not null check (length(btrim(display_name)) between 1 and 120),
  email text,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint guardians_id_organization_key unique (id, organization_id)
);

create index guardians_organization_name_idx
  on public.guardians (organization_id, display_name);

create table public.guardian_students (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  guardian_id uuid not null,
  student_id uuid not null,
  relationship_label text,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (guardian_id, student_id),
  constraint guardian_students_guardian_fk
    foreign key (guardian_id, organization_id)
    references public.guardians(id, organization_id) on delete cascade,
  constraint guardian_students_student_fk
    foreign key (student_id, organization_id)
    references public.students(id, organization_id) on delete cascade
);

create index guardian_students_student_idx
  on public.guardian_students (student_id, guardian_id);

create unique index guardian_students_one_primary_guardian
  on public.guardian_students (student_id)
  where is_primary;

create table public.enrollments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  term_id uuid not null,
  course_id uuid not null,
  student_id uuid not null,
  enrolled_at timestamptz not null default now(),
  status public.enrollment_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint enrollments_course_term_fk
    foreign key (course_id, term_id, organization_id)
    references public.courses(id, term_id, organization_id) on delete cascade,
  constraint enrollments_student_fk
    foreign key (student_id, organization_id)
    references public.students(id, organization_id) on delete cascade,
  constraint enrollments_term_course_student_key
    unique (term_id, course_id, student_id),
  constraint enrollments_id_organization_key
    unique (id, organization_id),
  constraint enrollments_id_student_organization_key
    unique (id, student_id, organization_id),
  constraint enrollments_id_term_organization_key
    unique (id, term_id, organization_id)
);

create index enrollments_student_status_idx
  on public.enrollments (student_id, status);

create index enrollments_course_status_idx
  on public.enrollments (course_id, status);

create table public.attendance (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  session_id uuid not null,
  student_id uuid not null,
  enrollment_id uuid,
  status public.attendance_status not null,
  recorded_at timestamptz not null default now(),
  recorded_by uuid references auth.users(id) on delete set null,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint attendance_session_fk
    foreign key (session_id, organization_id)
    references public.class_sessions(id, organization_id) on delete cascade,
  constraint attendance_student_fk
    foreign key (student_id, organization_id)
    references public.students(id, organization_id) on delete cascade,
  constraint attendance_enrollment_fk
    foreign key (enrollment_id, student_id, organization_id)
    references public.enrollments(id, student_id, organization_id)
    on delete set null (enrollment_id),
  constraint attendance_session_student_key unique (session_id, student_id)
);

create index attendance_student_recorded_idx
  on public.attendance (student_id, recorded_at desc);

create table public.leave_requests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  session_id uuid not null,
  student_id uuid not null,
  enrollment_id uuid,
  source public.leave_request_source not null,
  status public.leave_request_status not null default 'pending',
  submitted_at timestamptz not null default now(),
  submitted_by uuid references auth.users(id) on delete set null,
  resolved_at timestamptz,
  resolved_by uuid references auth.users(id) on delete set null,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint leave_requests_session_fk
    foreign key (session_id, organization_id)
    references public.class_sessions(id, organization_id) on delete cascade,
  constraint leave_requests_student_fk
    foreign key (student_id, organization_id)
    references public.students(id, organization_id) on delete cascade,
  constraint leave_requests_enrollment_fk
    foreign key (enrollment_id, student_id, organization_id)
    references public.enrollments(id, student_id, organization_id)
    on delete set null (enrollment_id),
  constraint leave_requests_resolution_pair check (
    (resolved_at is null and resolved_by is null)
    or (resolved_at is not null and resolved_by is not null)
  ),
  constraint leave_requests_session_student_key unique (session_id, student_id)
);

create index leave_requests_status_submitted_idx
  on public.leave_requests (organization_id, status, submitted_at desc);

create table public.contract_documents (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  term_id uuid not null,
  version text not null check (length(btrim(version)) between 1 and 80),
  title text not null check (length(btrim(title)) between 1 and 160),
  storage_path text not null check (storage_path !~ '^/' and storage_path !~ '\.\.'),
  status public.contract_document_status not null default 'draft',
  published_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint contract_documents_term_fk
    foreign key (term_id, organization_id)
    references public.terms(id, organization_id) on delete cascade,
  constraint contract_documents_term_version_key unique (term_id, version),
  constraint contract_documents_storage_path_key unique (storage_path),
  constraint contract_documents_id_term_organization_key
    unique (id, term_id, organization_id),
  constraint contract_documents_publish_state check (
    (status = 'published' and published_at is not null)
    or status <> 'published'
  )
);

create table public.contract_consents (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  contract_document_id uuid not null,
  term_id uuid not null,
  enrollment_id uuid,
  scope public.contract_consent_scope not null,
  signer_user_id uuid not null references auth.users(id) on delete restrict,
  signer_kind public.consent_signer_kind not null,
  signer_display_name text not null check (length(btrim(signer_display_name)) between 1 and 120),
  consented_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint contract_consents_document_fk
    foreign key (contract_document_id, term_id, organization_id)
    references public.contract_documents(id, term_id, organization_id) on delete restrict,
  constraint contract_consents_enrollment_fk
    foreign key (enrollment_id, term_id, organization_id)
    references public.enrollments(id, term_id, organization_id) on delete restrict,
  constraint contract_consents_scope_enrollment check (
    (scope = 'term' and enrollment_id is null)
    or (scope = 'enrollment' and enrollment_id is not null)
  )
);

create unique index contract_consents_term_scope_key
  on public.contract_consents (contract_document_id, signer_user_id)
  where enrollment_id is null;

create unique index contract_consents_enrollment_scope_key
  on public.contract_consents (contract_document_id, enrollment_id, signer_user_id)
  where enrollment_id is not null;

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  kind public.notification_kind not null,
  channel public.notification_channel not null,
  title text not null check (length(btrim(title)) between 1 and 160),
  body text not null check (length(btrim(body)) between 1 and 4000),
  scheduled_at timestamptz,
  sent_at timestamptz,
  status public.notification_delivery_status not null default 'pending',
  read_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint notifications_read_state check (
    (status = 'read' and read_at is not null)
    or status <> 'read'
  )
);

create index notifications_recipient_status_idx
  on public.notifications (recipient_user_id, status, created_at desc);

create table public.device_push_tokens (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null,
  platform text not null default 'ios' check (platform in ('ios', 'macos')),
  environment text not null check (environment in ('sandbox', 'production')),
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint device_push_tokens_user_token_key unique (user_id, token)
);

create index device_push_tokens_user_idx
  on public.device_push_tokens (user_id, last_seen_at desc);

create table public.migration_runs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  source_fingerprint text not null check (length(source_fingerprint) >= 16),
  source_label text not null check (length(btrim(source_label)) between 1 and 200),
  status public.migration_run_status not null default 'dry_run',
  summary jsonb not null default '{}'::jsonb check (jsonb_typeof(summary) = 'object'),
  started_by uuid references auth.users(id) on delete set null,
  started_at timestamptz not null default now(),
  applied_at timestamptz,
  finished_at timestamptz,
  error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint migration_runs_fingerprint_key unique (organization_id, source_fingerprint),
  constraint migration_runs_apply_state check (
    (status = 'applied' and applied_at is not null)
    or status <> 'applied'
  )
);

create table public.migration_row_mappings (
  id bigint generated always as identity primary key,
  migration_run_id uuid not null references public.migration_runs(id) on delete cascade,
  entity_kind text not null,
  source_row integer not null check (source_row > 0),
  action text not null check (action in ('insert', 'update', 'skip', 'error')),
  destination_id uuid,
  issue_severity text check (issue_severity in ('warning', 'error')),
  message text,
  source_snapshot jsonb not null default '{}'::jsonb check (jsonb_typeof(source_snapshot) = 'object'),
  created_at timestamptz not null default now(),
  constraint migration_row_mappings_run_row_key
    unique (migration_run_id, entity_kind, source_row)
);

create index migration_row_mappings_destination_idx
  on public.migration_row_mappings (destination_id)
  where destination_id is not null;

create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function private.prepare_class_session()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  course_row record;
  local_start_date date;
  local_end_date date;
begin
  select
    c.organization_id,
    c.default_room_id,
    c.default_instructor_id,
    t.starts_on,
    t.ends_on,
    o.timezone
  into course_row
  from public.courses c
  join public.terms t on t.id = c.term_id
  join public.organizations o on o.id = c.organization_id
  where c.id = new.course_id;

  if not found then
    raise exception 'Unknown course %', new.course_id using errcode = '23503';
  end if;

  if new.organization_id <> course_row.organization_id then
    raise exception 'Session organization does not match course organization'
      using errcode = '23514';
  end if;

  new.effective_room_id =
    coalesce(new.room_override_id, course_row.default_room_id);
  new.effective_instructor_id =
    coalesce(new.instructor_override_id, course_row.default_instructor_id);

  local_start_date := (new.starts_at at time zone course_row.timezone)::date;
  local_end_date := (new.ends_at at time zone course_row.timezone)::date;

  if local_start_date < course_row.starts_on
     or local_end_date > course_row.ends_on then
    raise exception 'Session must fall inside its term date range'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create or replace function private.propagate_course_defaults()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.default_room_id is distinct from old.default_room_id then
    update public.class_sessions
    set effective_room_id = new.default_room_id
    where course_id = new.id and room_override_id is null;
  end if;

  if new.default_instructor_id is distinct from old.default_instructor_id then
    update public.class_sessions
    set effective_instructor_id = new.default_instructor_id
    where course_id = new.id and instructor_override_id is null;
  end if;

  return new;
end;
$$;

create or replace function private.validate_session_enrollment()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  session_course_id uuid;
  enrollment_course_id uuid;
begin
  if new.enrollment_id is null then
    return new;
  end if;

  select course_id into session_course_id
  from public.class_sessions
  where id = new.session_id;

  select course_id into enrollment_course_id
  from public.enrollments
  where id = new.enrollment_id;

  if session_course_id is distinct from enrollment_course_id then
    raise exception 'Enrollment course does not match session course'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create or replace function private.validate_contract_consent()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  document_status public.contract_document_status;
begin
  select status into document_status
  from public.contract_documents
  where id = new.contract_document_id;

  if document_status is distinct from 'published'::public.contract_document_status then
    raise exception 'Consent can only be recorded for a published contract'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger organizations_set_updated_at
before update on public.organizations
for each row execute function private.set_updated_at();

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function private.set_updated_at();

create trigger terms_set_updated_at
before update on public.terms
for each row execute function private.set_updated_at();

create trigger course_categories_set_updated_at
before update on public.course_categories
for each row execute function private.set_updated_at();

create trigger age_groups_set_updated_at
before update on public.age_groups
for each row execute function private.set_updated_at();

create trigger rooms_set_updated_at
before update on public.rooms
for each row execute function private.set_updated_at();

create trigger instructors_set_updated_at
before update on public.instructors
for each row execute function private.set_updated_at();

create trigger courses_set_updated_at
before update on public.courses
for each row execute function private.set_updated_at();

create trigger courses_propagate_defaults
after update of default_room_id, default_instructor_id on public.courses
for each row execute function private.propagate_course_defaults();

create trigger class_sessions_prepare
before insert or update on public.class_sessions
for each row execute function private.prepare_class_session();

create trigger class_sessions_set_updated_at
before update on public.class_sessions
for each row execute function private.set_updated_at();

create trigger students_set_updated_at
before update on public.students
for each row execute function private.set_updated_at();

create trigger guardians_set_updated_at
before update on public.guardians
for each row execute function private.set_updated_at();

create trigger enrollments_set_updated_at
before update on public.enrollments
for each row execute function private.set_updated_at();

create trigger attendance_validate_enrollment
before insert or update on public.attendance
for each row execute function private.validate_session_enrollment();

create trigger attendance_set_updated_at
before update on public.attendance
for each row execute function private.set_updated_at();

create trigger leave_requests_validate_enrollment
before insert or update on public.leave_requests
for each row execute function private.validate_session_enrollment();

create trigger leave_requests_set_updated_at
before update on public.leave_requests
for each row execute function private.set_updated_at();

create trigger contract_documents_set_updated_at
before update on public.contract_documents
for each row execute function private.set_updated_at();

create trigger contract_consents_validate
before insert or update on public.contract_consents
for each row execute function private.validate_contract_consent();

create trigger notifications_set_updated_at
before update on public.notifications
for each row execute function private.set_updated_at();

create trigger device_push_tokens_set_updated_at
before update on public.device_push_tokens
for each row execute function private.set_updated_at();

create trigger migration_runs_set_updated_at
before update on public.migration_runs
for each row execute function private.set_updated_at();

commit;
