begin;

create or replace function private.validate_course_term_ready()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE'
     and new.term_id is not distinct from old.term_id
     and new.organization_id is not distinct from old.organization_id then
    return new;
  end if;

  if not exists (
    select 1
    from public.terms t
    where t.id = new.term_id
      and t.organization_id = new.organization_id
  ) then
    raise exception '找不到这个学期。' using errcode = '23503';
  end if;

  if not exists (
    select 1
    from public.term_holidays h
    where h.term_id = new.term_id
      and h.organization_id = new.organization_id
  ) then
    raise exception '请先为这个学期创建至少一个假期，再创建课程。'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

drop trigger if exists courses_validate_term_ready on public.courses;
create trigger courses_validate_term_ready
before insert or update of term_id, organization_id on public.courses
for each row execute function private.validate_course_term_ready();

comment on function private.validate_course_term_ready() is
  'Requires a real term and at least one configured term holiday before a course enters that term.';

create or replace function public.admin_delete_record(
  target_kind text,
  target_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  organization_id_value uuid := private.current_user_organization_id();
  holiday_term_id uuid;
begin
  if not private.is_admin() then
    raise exception '需要教务管理员权限。' using errcode = '42501';
  end if;

  case target_kind
    when 'term' then
      if exists (
        select 1 from public.courses
        where term_id = target_id and organization_id = organization_id_value
      ) then
        raise exception '这个学期已有课程，不能删除；请先删除或停用课程。'
          using errcode = '23503';
      end if;
      if exists (
        select 1 from public.term_holidays
        where term_id = target_id and organization_id = organization_id_value
      ) then
        raise exception '这个学期已有假期，不能删除；请先删除假期。'
          using errcode = '23503';
      end if;
      if exists (
        select 1 from public.contract_documents
        where term_id = target_id and organization_id = organization_id_value
      ) then
        raise exception '这个学期已有合同，不能删除；请先处理合同。'
          using errcode = '23503';
      end if;
      delete from public.terms
      where id = target_id and organization_id = organization_id_value;

    when 'term_holiday' then
      select h.term_id
      into holiday_term_id
      from public.term_holidays h
      where h.id = target_id
        and h.organization_id = organization_id_value;

      if not found then
        return;
      end if;

      if exists (
        select 1
        from public.courses c
        where c.term_id = holiday_term_id
          and c.organization_id = organization_id_value
      ) then
        raise exception '这个假期所属学期已有课程，不能删除；请先处理课程。'
          using errcode = '23503';
      end if;

      delete from public.term_holidays
      where id = target_id and organization_id = organization_id_value;

    when 'course_category' then
      if exists (
        select 1 from public.courses
        where category_id = target_id and organization_id = organization_id_value
      ) then
        raise exception '这个课程分类已被课程使用，不能删除。'
          using errcode = '23503';
      end if;
      delete from public.course_categories
      where id = target_id and organization_id = organization_id_value;

    when 'course_type' then
      if exists (
        select 1 from public.courses
        where course_type_id = target_id and organization_id = organization_id_value
      ) then
        raise exception '这个课程种类已被课程使用，不能删除。'
          using errcode = '23503';
      end if;
      delete from public.course_types
      where id = target_id and organization_id = organization_id_value;

    when 'age_group' then
      if exists (
        select 1 from public.courses
        where age_group_id = target_id and organization_id = organization_id_value
      ) then
        raise exception '这个年龄段已被课程使用，不能删除。'
          using errcode = '23503';
      end if;
      delete from public.age_groups
      where id = target_id and organization_id = organization_id_value;

    when 'room' then
      if exists (
           select 1 from public.courses
           where default_room_id = target_id and organization_id = organization_id_value
         )
         or exists (
           select 1 from public.class_sessions
           where organization_id = organization_id_value
             and (room_override_id = target_id or effective_room_id = target_id)
         ) then
        raise exception '这个教室已被课程或课次使用，不能删除。'
          using errcode = '23503';
      end if;
      delete from public.rooms
      where id = target_id and organization_id = organization_id_value;

    when 'instructor' then
      if exists (
           select 1 from public.courses
           where default_instructor_id = target_id and organization_id = organization_id_value
         )
         or exists (
           select 1 from public.class_sessions
           where organization_id = organization_id_value
             and (instructor_override_id = target_id or effective_instructor_id = target_id)
         ) then
        raise exception '这位老师已被课程或课次使用，不能删除。'
          using errcode = '23503';
      end if;
      delete from public.instructors
      where id = target_id and organization_id = organization_id_value;

    when 'course' then
      if exists (
        select 1 from public.enrollments
        where course_id = target_id and organization_id = organization_id_value
      ) then
        raise exception '这门课程已有报名，不能删除；可以将它停用。'
          using errcode = '23503';
      end if;
      if exists (
        select 1
        from public.attendance a
        join public.class_sessions s
          on s.id = a.session_id
         and s.organization_id = a.organization_id
        where s.course_id = target_id
          and s.organization_id = organization_id_value
      ) then
        raise exception '这门课程已有签到记录，不能删除；可以将它停用。'
          using errcode = '23503';
      end if;
      if exists (
        select 1
        from public.leave_requests l
        join public.class_sessions s
          on s.id = l.session_id
         and s.organization_id = l.organization_id
        where s.course_id = target_id
          and s.organization_id = organization_id_value
      ) then
        raise exception '这门课程已有请假记录，不能删除；可以将它停用。'
          using errcode = '23503';
      end if;

      delete from public.class_sessions
      where course_id = target_id and organization_id = organization_id_value;
      delete from public.courses
      where id = target_id and organization_id = organization_id_value;

    when 'guardian' then
      if exists (
        select 1 from public.guardians
        where id = target_id
          and organization_id = organization_id_value
          and profile_user_id is not null
      ) then
        raise exception '这个监护人已连接帐号，不能删除。'
          using errcode = '23503';
      end if;
      if exists (
        select 1 from public.students
        where guardian_id = target_id and organization_id = organization_id_value
      ) then
        raise exception '这个监护人仍有学员档案，不能删除；请先处理学员。'
          using errcode = '23503';
      end if;
      if exists (
        select 1 from private.guardian_registration_acceptances
        where guardian_id = target_id and organization_id = organization_id_value
      ) then
        raise exception '这个监护人已有合同签字记录，不能删除。'
          using errcode = '23503';
      end if;
      delete from public.guardians
      where id = target_id and organization_id = organization_id_value;

    when 'student' then
      if exists (
        select 1 from public.students
        where id = target_id
          and organization_id = organization_id_value
          and profile_user_id is not null
      ) then
        raise exception '这个学员已连接帐号，不能删除。'
          using errcode = '23503';
      end if;
      if exists (
        select 1 from public.enrollments
        where student_id = target_id and organization_id = organization_id_value
      ) then
        raise exception '这个学员已有报名，不能删除；可以将档案停用。'
          using errcode = '23503';
      end if;
      if exists (
        select 1 from public.attendance
        where student_id = target_id and organization_id = organization_id_value
      ) then
        raise exception '这个学员已有签到记录，不能删除；可以将档案停用。'
          using errcode = '23503';
      end if;
      if exists (
        select 1 from public.leave_requests
        where student_id = target_id and organization_id = organization_id_value
      ) then
        raise exception '这个学员已有请假记录，不能删除；可以将档案停用。'
          using errcode = '23503';
      end if;
      delete from public.students
      where id = target_id and organization_id = organization_id_value;

    when 'contract_document' then
      if exists (
        select 1 from public.contract_consents
        where contract_document_id = target_id
          and organization_id = organization_id_value
      ) then
        raise exception '这份合同已有正式签署记录，不能删除；可以将它停用。'
          using errcode = '23503';
      end if;
      if exists (
        select 1 from private.guardian_registration_acceptances
        where contract_document_id = target_id
          and organization_id = organization_id_value
      ) then
        raise exception '这份合同已有注册签字记录，不能删除；可以将它停用。'
          using errcode = '23503';
      end if;
      delete from public.contract_documents
      where id = target_id and organization_id = organization_id_value;

    else
      raise exception '不支持删除这种资料。' using errcode = '22023';
  end case;
end;
$$;

comment on function public.admin_delete_record(text, uuid) is
  'Deletes only unreferenced business records; derived empty class sessions are removed with their course.';

commit;
