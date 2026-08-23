-- Correct the course-name typo confirmed by the school. Course records keep
-- their IDs so sessions, enrollments, attendance, and billing links remain
-- unchanged.

begin;

do $$
declare
  organization_id_value constant uuid := '00000000-0000-0000-0000-000000000001'::uuid;
  updated_count integer;
begin
  perform pg_advisory_xact_lock(hashtext('master-dance:rename-ballet-training-courses'));

  update public.courses
  set name = '芭蕾基训'
  where organization_id = organization_id_value
    and name = '芭蕾集训';

  get diagnostics updated_count = row_count;
  raise notice 'Renamed % ballet training course(s)', updated_count;

  if exists (
    select 1
    from public.courses
    where organization_id = organization_id_value
      and name = '芭蕾集训'
  ) then
    raise exception 'Ballet course-name correction did not update every matching course';
  end if;
end
$$;

commit;
