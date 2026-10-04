-- Self-contained pgTAP integration test; never depends on production records.
-- All fixtures, audit entries and revisions roll back.
begin;
create extension if not exists pgtap with schema extensions;
select plan(1);
do $$
declare
  admin_id uuid := gen_random_uuid();
  org_id uuid := gen_random_uuid();
  family_id uuid := gen_random_uuid();
  other_family_id uuid := gen_random_uuid();
  learner_id uuid := gen_random_uuid();
  registration_id uuid := gen_random_uuid();
  invoice_id uuid := gen_random_uuid();
  item_id uuid := gen_random_uuid();
  class_id uuid := gen_random_uuid();
  session_id uuid := gen_random_uuid();
  semester_id uuid := gen_random_uuid();
  category_id uuid := gen_random_uuid();
  age_id uuid := gen_random_uuid();
  type_id uuid := gen_random_uuid();
  room_id uuid := gen_random_uuid();
  instructor_id uuid := gen_random_uuid();
  student_row public.students;
  invoice_row public.billing_invoices;
begin
  insert into public.organizations(id, name, slug, timezone)
  values (org_id, 'Billing Test School', 'billing-test-' || org_id::text, 'America/Los_Angeles');
  insert into auth.users(id, aud, role, email, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (admin_id, 'authenticated', 'authenticated', admin_id::text || '@example.test',
    now(), '{}'::jsonb, '{}'::jsonb, now(), now());
  insert into public.profiles(user_id, organization_id, role, display_name)
  values (admin_id, org_id, 'administrator', 'Billing Test Admin');
  insert into public.terms(id, organization_id, name, starts_on, ends_on, status)
  values (semester_id, org_id, 'Test Fall', '2026-08-01', '2026-12-31', 'open');
  insert into public.term_holidays(organization_id, term_id, name, starts_on, ends_on)
  values (org_id, semester_id, 'Test Holiday', '2026-11-23', '2026-11-29');
  insert into public.course_categories(id, organization_id, name)
  values (category_id, org_id, 'Dance');
  insert into public.age_groups(id, organization_id, name)
  values (age_id, org_id, 'Test Age Group');
  insert into public.course_types(id, organization_id, name, is_private)
  values (type_id, org_id, 'Group', false);
  insert into public.rooms(id, organization_id, name)
  values (room_id, org_id, 'Test Room');
  insert into public.instructors(id, organization_id, display_name)
  values (instructor_id, org_id, 'Test Instructor');
  insert into public.courses(id, organization_id, term_id, name, category_id, age_group_id,
    default_room_id, default_instructor_id, course_type_id, format)
  values (class_id, org_id, semester_id, 'Test Course', category_id, age_id,
    room_id, instructor_id, type_id, 'group');
  insert into public.class_sessions(id, organization_id, course_id, starts_at,
    ends_at, effective_instructor_id, effective_room_id)
  values (session_id, org_id, class_id, '2026-09-01 18:00:00-07',
    '2026-09-01 19:00:00-07', instructor_id, room_id);
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', admin_id, 'role', 'authenticated')::text, true);

  insert into public.guardians(id, organization_id, display_name)
  values (family_id, org_id, 'ROLLBACK TEST family'),
         (other_family_id, org_id, 'ROLLBACK TEST other family');
  student_row := public.admin_create_student_for_guardian_v2(
    learner_id, family_id, 'ROLLBACK TEST learner', null, 'child', '2018-01-02');
  if student_row.id <> learner_id or student_row.birth_date <> '2018-01-02'::date then
    raise exception 'Stable student identity/birth date regression';
  end if;
  student_row := public.admin_create_student_for_guardian_v2(
    learner_id, family_id, 'Retry must not overwrite', null, 'child', null);
  if student_row.display_name <> 'ROLLBACK TEST learner'
     or (select count(*) from public.students where guardian_id = family_id) <> 1 then
    raise exception 'Student retry duplicated or overwrote the profile';
  end if;
  begin
    perform public.admin_create_student_for_guardian_v2(
      learner_id, other_family_id, 'Wrong family');
    raise exception 'Cross-family UUID reuse was accepted';
  exception when check_violation then null;
  end;
  begin
    perform public.admin_create_student_for_guardian_v2(null, family_id, 'Missing ID');
    raise exception 'Missing UUID was accepted';
  exception when invalid_parameter_value then null;
  end;

  perform public.admin_save_enrollment(
    registration_id, semester_id, class_id, learner_id, now(), 'active',
    'per_session', 'ready', '2026-09-01', 4000, 0, null, null, null, null,
    array[session_id]);
  invoice_row := public.admin_issue_billing_invoice_scoped_dual_v3(
    invoice_id, family_id, semester_id, array[learner_id],
    'ROLLBACK-TEST-' || invoice_id::text, 1, 'Test semester', now(), '', null,
    gen_random_uuid(), org_id::text || '/' || family_id::text || '/test-zh.png',
    gen_random_uuid(), org_id::text || '/' || family_id::text || '/test-en.png',
    jsonb_build_array(jsonb_build_object(
      'id', item_id, 'student_id', learner_id, 'enrollment_id', registration_id,
      'kind', 'tuition', 'title', 'ROLLBACK TEST tuition', 'detail', '1 session',
      'quantity', 1, 'unit_amount_cents', 4000, 'amount_cents', 4000,
      'included_in_amount_due', false, 'settlement_status', 'paid', 'sort_order', 0,
      'schedule_snapshot', jsonb_build_object('version', 1, 'courseName', 'Test',
        'studentName', 'Test', 'registrationMode', 'per_session', 'sessions', '[]'::jsonb)
    )));
  if invoice_row.amount_due_cents <> 0
     or not exists (select 1 from public.billing_invoice_items
       where id = item_id and student_id = learner_id and schedule_snapshot is not null)
     or (select count(*) from public.billing_artifacts a where a.invoice_id = invoice_row.id) <> 2 then
    raise exception 'Enrollment-to-paid-invoice regression';
  end if;

  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', gen_random_uuid(), 'role', 'authenticated')::text, true);
  begin
    perform public.admin_create_student_for_guardian_v2(gen_random_uuid(), family_id, 'Not admin');
    raise exception 'Non-admin creation was accepted';
  exception when insufficient_privilege then null;
  end;
end;
$$;
select pass('stable identity, retry, scope, birth date, enrollment, paid invoice, dual artifacts and non-admin denial');
select * from finish();
rollback;
