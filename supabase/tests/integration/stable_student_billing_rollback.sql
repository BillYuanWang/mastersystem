-- Run only against a configured test/linked project with an active admin and
-- scheduled course. All synthetic rows, audit entries and revisions roll back.
begin;
do $$
declare
  admin_id uuid;
  org_id uuid;
  family_id uuid := gen_random_uuid();
  other_family_id uuid := gen_random_uuid();
  learner_id uuid := gen_random_uuid();
  registration_id uuid := gen_random_uuid();
  invoice_id uuid := gen_random_uuid();
  item_id uuid := gen_random_uuid();
  class_id uuid;
  session_id uuid;
  semester_id uuid;
  student_row public.students;
  invoice_row public.billing_invoices;
begin
  select p.user_id, p.organization_id into strict admin_id, org_id
  from public.profiles p where p.role = 'administrator' and p.is_active limit 1;
  select c.id, c.term_id, s.id into strict class_id, semester_id, session_id
  from public.courses c join public.class_sessions s on s.course_id = c.id
  where c.organization_id = org_id and s.status <> 'cancelled' limit 1;
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
    'per_session', 'ready', current_date, 4000, 0, null, null, null, null,
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
select 'PASS: stable identity, retry, scope, birth date, enrollment, paid invoice, dual artifacts, non-admin denial; all rolled back' as result;
rollback;
