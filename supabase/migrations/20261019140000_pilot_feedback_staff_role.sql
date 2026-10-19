-- The evaluation form now has two roles: undergraduate students, and a single
-- "staff" group (lecturers, administration, health centre staff and technical
-- experts). Accept 'staff'. The older role values stay valid so nothing
-- already stored, or sent by a cached copy of the old form, is rejected.

alter table public.pilot_feedback drop constraint if exists pilot_feedback_role_check;
alter table public.pilot_feedback
  add constraint pilot_feedback_role_check check (role in ('student', 'staff', 'lecturer', 'admin'));

create or replace function public.submit_pilot_feedback(p_role text, p_group text, p_answers jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_role not in ('student', 'staff', 'lecturer', 'admin') then
    raise exception 'unknown role' using errcode = '22023';
  end if;
  if jsonb_typeof(p_answers) <> 'object' or (p_answers ->> 'consent') is distinct from '1' then
    raise exception 'consent is required' using errcode = '22023';
  end if;
  if octet_length(p_answers::text) > 20000 then
    raise exception 'response too large' using errcode = '22023';
  end if;
  insert into public.pilot_feedback (role, link_group, answers)
  values (p_role, nullif(left(coalesce(p_group, ''), 20), ''), p_answers);
end;
$$;
revoke execute on function public.submit_pilot_feedback(text, text, jsonb) from public;
grant execute on function public.submit_pilot_feedback(text, text, jsonb) to anon, authenticated;
