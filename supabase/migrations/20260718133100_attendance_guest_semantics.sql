update public.attendance
set enrollment_id = null
where status::text in ('makeup', 'trial')
  and enrollment_id is not null;

alter table public.attendance
  drop constraint if exists attendance_guest_status_without_enrollment_check;

alter table public.attendance
  add constraint attendance_guest_status_without_enrollment_check
  check (
    status::text not in ('makeup', 'trial')
    or enrollment_id is null
  );

comment on column public.attendance.status is
  'Recorded visit fact. Trial and makeup visits do not require course enrollment.';
