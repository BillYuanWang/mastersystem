begin;
select plan(4);
select ok(to_regprocedure(
  'public.admin_create_student_for_guardian_v2(uuid,uuid,text,text,public.student_kind,date)'
) is not null, 'local-first creation accepts the existing learner UUID');
select ok(has_function_privilege('authenticated',
  'public.admin_create_student_for_guardian_v2(uuid,uuid,text,text,public.student_kind,date)',
  'execute'), 'authenticated clients can call the admin-guarded RPC');
select ok(not has_function_privilege('anon',
  'public.admin_create_student_for_guardian_v2(uuid,uuid,text,text,public.student_kind,date)',
  'execute'), 'anonymous creation remains forbidden');
select ok(to_regprocedure(
  'public.admin_create_student_for_guardian(uuid,text,text,public.student_kind,date)'
) is not null, 'older installed clients retain their existing RPC');
select * from finish();
rollback;
