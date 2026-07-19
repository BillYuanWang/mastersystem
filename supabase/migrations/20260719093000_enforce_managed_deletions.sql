begin;

revoke delete on table
  public.organizations,
  public.terms,
  public.course_categories,
  public.course_types,
  public.age_groups,
  public.rooms,
  public.instructors,
  public.courses,
  public.students,
  public.guardians,
  public.term_holidays,
  public.contract_documents,
  public.contract_consents
from authenticated;

comment on function public.admin_delete_record(text, uuid) is
  'Sole authenticated deletion path for managed academic and family records; reversible operational records remain directly removable.';

commit;
