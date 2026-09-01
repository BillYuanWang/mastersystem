begin;

create extension if not exists pgtap with schema extensions;

select plan(6);

select ok(
  exists (
    select 1
    from pg_catalog.pg_trigger
    where tgrelid = 'public.courses'::regclass
      and tgname = 'courses_group_per_session_premium_guard'
      and not tgisinternal
  ),
  'group course per-session premium is enforced by a database trigger'
);

insert into public.organizations (id, name, slug, timezone)
values (
  '92000000-0000-0000-0000-000000000001',
  'Group Pricing Test School',
  'group-pricing-test-school',
  'America/Los_Angeles'
);

insert into public.terms (id, organization_id, name, starts_on, ends_on, status)
values (
  '92000000-0000-0000-0000-000000000002',
  '92000000-0000-0000-0000-000000000001',
  'Group Pricing Test Term',
  '2026-08-01',
  '2026-12-31',
  'open'
);

insert into public.course_categories (id, organization_id, name)
values (
  '92000000-0000-0000-0000-000000000003',
  '92000000-0000-0000-0000-000000000001',
  'Test Category'
);

insert into public.age_groups (id, organization_id, name)
values (
  '92000000-0000-0000-0000-000000000004',
  '92000000-0000-0000-0000-000000000001',
  'Test Age Group'
);

insert into public.rooms (id, organization_id, name)
values (
  '92000000-0000-0000-0000-000000000005',
  '92000000-0000-0000-0000-000000000001',
  'Test Room'
);

insert into public.instructors (id, organization_id, display_name)
values (
  '92000000-0000-0000-0000-000000000006',
  '92000000-0000-0000-0000-000000000001',
  'Test Teacher'
);

insert into public.course_types (id, organization_id, name, is_private)
values
  (
    '92000000-0000-0000-0000-000000000007',
    '92000000-0000-0000-0000-000000000001',
    'Group Lesson',
    false
  ),
  (
    '92000000-0000-0000-0000-000000000008',
    '92000000-0000-0000-0000-000000000001',
    'Private Lesson',
    true
  );

insert into public.courses (
  id,
  organization_id,
  term_id,
  name,
  category_id,
  age_group_id,
  default_room_id,
  default_instructor_id,
  course_type_id,
  format,
  pricing_status,
  unit_price_cents,
  drop_in_unit_price_cents
) values (
  '92000000-0000-0000-0000-000000000009',
  '92000000-0000-0000-0000-000000000001',
  '92000000-0000-0000-0000-000000000002',
  'Priced Group Lesson',
  '92000000-0000-0000-0000-000000000003',
  '92000000-0000-0000-0000-000000000004',
  '92000000-0000-0000-0000-000000000005',
  '92000000-0000-0000-0000-000000000006',
  '92000000-0000-0000-0000-000000000007',
  'group',
  'priced',
  4000,
  9999
);

select is(
  (select drop_in_unit_price_cents from public.courses where id = '92000000-0000-0000-0000-000000000009'),
  4500,
  'a USD 40 full-term unit price produces a USD 45 per-session price'
);

update public.courses
set unit_price_cents = 3500
where id = '92000000-0000-0000-0000-000000000009';

select is(
  (select drop_in_unit_price_cents from public.courses where id = '92000000-0000-0000-0000-000000000009'),
  4000,
  'changing the full-term unit price keeps the USD 5 premium'
);

update public.courses
set drop_in_unit_price_cents = 1234
where id = '92000000-0000-0000-0000-000000000009';

select is(
  (select drop_in_unit_price_cents from public.courses where id = '92000000-0000-0000-0000-000000000009'),
  4000,
  'a manual group per-session override is normalized back to the policy price'
);

insert into public.courses (
  id,
  organization_id,
  term_id,
  name,
  category_id,
  age_group_id,
  default_room_id,
  default_instructor_id,
  course_type_id,
  format,
  pricing_status,
  unit_price_cents,
  drop_in_unit_price_cents
) values (
  '92000000-0000-0000-0000-000000000010',
  '92000000-0000-0000-0000-000000000001',
  '92000000-0000-0000-0000-000000000002',
  'Pending Group Lesson',
  '92000000-0000-0000-0000-000000000003',
  '92000000-0000-0000-0000-000000000004',
  '92000000-0000-0000-0000-000000000005',
  '92000000-0000-0000-0000-000000000006',
  '92000000-0000-0000-0000-000000000007',
  'group',
  'pending',
  null,
  2700
);

select is(
  (select drop_in_unit_price_cents from public.courses where id = '92000000-0000-0000-0000-000000000010'),
  2700,
  'a pending full-term price is left unchanged'
);

insert into public.courses (
  id,
  organization_id,
  term_id,
  name,
  category_id,
  age_group_id,
  default_room_id,
  default_instructor_id,
  course_type_id,
  format,
  pricing_status,
  unit_price_cents,
  drop_in_unit_price_cents
) values (
  '92000000-0000-0000-0000-000000000011',
  '92000000-0000-0000-0000-000000000001',
  '92000000-0000-0000-0000-000000000002',
  'Private Lesson',
  '92000000-0000-0000-0000-000000000003',
  '92000000-0000-0000-0000-000000000004',
  '92000000-0000-0000-0000-000000000005',
  '92000000-0000-0000-0000-000000000006',
  '92000000-0000-0000-0000-000000000008',
  'private_lesson',
  'priced',
  null,
  8000
);

select is(
  (select drop_in_unit_price_cents from public.courses where id = '92000000-0000-0000-0000-000000000011'),
  8000,
  'private lesson pricing remains independently editable'
);

select * from finish();
rollback;
