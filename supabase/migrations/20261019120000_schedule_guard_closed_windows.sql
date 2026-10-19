-- Refuse assessment windows that would already be closed. Scheduling one with
-- past dates used to create a closed window and still send every student in
-- the faculty a "now open" notification for it.

create or replace function public.admin_schedule_assessment(
  p_title text,
  p_term text,
  p_faculties text[],
  p_opens_at timestamptz,
  p_days int default 7
)
returns setof public.assessment_windows
language plpgsql
security definer
set search_path = ''
as $$
declare
  f text;
  w public.assessment_windows%rowtype;
  targets text[] := case when coalesce(array_length(p_faculties, 1), 0) = 0 then array[null::text] else p_faculties end;
begin
  if not public.is_admin() then raise exception 'not authorised' using errcode = '42501'; end if;
  if p_days < 1 or p_days > 31 then raise exception 'window must be open for 1 to 31 days'; end if;
  if p_opens_at + make_interval(days => p_days) <= now() then
    raise exception 'that window would already be closed; pick dates that end in the future';
  end if;
  foreach f in array targets loop
    insert into public.assessment_windows (title, term, faculty, opens_at, closes_at, estimated_minutes)
    values (p_title, p_term, f, p_opens_at, p_opens_at + make_interval(days => p_days), 6)
    returning * into w;

    insert into public.notifications (user_id, category, label, title, body, icon, route, scheduled_for)
    select p.id, 'milestone', 'Assessment', 'Your health assessment is coming up',
           'The ' || w.term || ' periodic health assessment opens on ' || to_char(w.opens_at at time zone 'Asia/Colombo', 'FMDD Mon') ||
           '. It takes about 6 minutes, and you will have ' || p_days || ' days to complete it.',
           'event_upcoming', '/assessments', w.opens_at - interval '3 days'
    from public.profiles p
    where p.onboarding_completed and (w.faculty is null or p.faculty = w.faculty)
      and w.opens_at - interval '3 days' > now();

    insert into public.notifications (user_id, category, label, title, body, icon, route, scheduled_for)
    select p.id, 'milestone', 'Assessment', 'Health assessment now open',
           'Your ' || w.term || ' assessment is open until ' || to_char(w.closes_at at time zone 'Asia/Colombo', 'FMDD Mon') ||
           '. Answers are pooled anonymously to plan campus health support.',
           'event_upcoming', '/assessments', greatest(w.opens_at, now())
    from public.profiles p
    where p.onboarding_completed and (w.faculty is null or p.faculty = w.faculty);

    return next w;
  end loop;
end;
$$;
revoke execute on function public.admin_schedule_assessment(text, text, text[], timestamptz, int) from public, anon;
grant execute on function public.admin_schedule_assessment(text, text, text[], timestamptz, int) to authenticated;
