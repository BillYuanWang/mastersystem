begin;

create extension if not exists pgtap with schema extensions;

select plan(5);

select has_column(
  'public',
  'guardians',
  'address',
  'guardians include an optional household address'
);

select col_type_is(
  'public',
  'guardians',
  'address',
  'text',
  'guardian addresses use text storage'
);

select has_column(
  'public',
  'students',
  'birth_date',
  'students include an optional birth date'
);

select col_type_is(
  'public',
  'students',
  'birth_date',
  'date',
  'student birth dates use date-only storage'
);

select ok(
  to_regprocedure(
    'public.admin_create_student_for_guardian(uuid,text,text,public.student_kind,date)'
  ) is not null,
  'student creation accepts an optional birth date atomically'
);

select * from finish();

rollback;
