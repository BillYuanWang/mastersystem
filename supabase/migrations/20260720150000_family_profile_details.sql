begin;

alter table public.guardians
  add column address text;

alter table public.students
  add column birth_date date;

comment on column public.guardians.address is
  'Optional household mailing address maintained by administrators.';

comment on column public.students.birth_date is
  'Optional learner birth date used for family records and age-aware workflows.';

commit;
