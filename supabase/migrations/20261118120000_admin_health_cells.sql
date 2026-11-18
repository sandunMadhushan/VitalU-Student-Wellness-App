-- Health insights for the admin dashboard, and fairer participation figures.
--
--  1. admin_health_cells(): pooled counts of eight health concerns for every
--     closed-or-open assessment period, by faculty, academic year and sex. Cells
--     with fewer than five completed assessments are not returned, so no small
--     group can be identified. Admins still never read individual rows.
--     Indicator order in "c": overweight/obese, central obesity, skips breakfast,
--     low fruit and veg, inactive, short sleep, high stress, low mood.
--  2. A student is only "eligible" for a window if they had registered by the
--     time it closed (overview and completion list), so participation in older
--     rounds is not understated by students who joined later.

create or replace function public.admin_health_cells()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare result jsonb;
begin
  if not public.is_admin() then raise exception 'not authorised' using errcode = '42501'; end if;

  with prof as materialized (
    select id, faculty, sex, created_at,
           case when academic_year ~ '^\d\d/\d\d' then 2000 + substr(academic_year, 4, 2)::int end as intake
    from public.profiles
    where onboarding_completed and faculty is not null and sex in ('female', 'male')
  ),
  win as materialized (
    select w.id, w.term, w.opens_at, w.closes_at, w.faculty
    from public.assessment_windows w
    where exists (select 1 from public.assessments a where a.window_id = w.id and a.status = 'completed')
  ),
  pw as materialized (
    select w.id as wid, w.term, w.opens_at, p.id as uid, p.faculty, p.sex,
           least(4, greatest(1, extract(year from w.opens_at)::int - p.intake + 1)) as yr
    from win w
    join prof p on p.intake is not null and p.created_at <= w.closes_at and (w.faculty is null or p.faculty = w.faculty)
  ),
  cell as (
    select pw.term, min(pw.opens_at) as opens, pw.faculty, pw.yr, pw.sex,
      count(*) as eligible,
      count(a.id) as n,
      count(*) filter (where jsonb_typeof(a.scores -> 'bmi') = 'number' and (a.scores ->> 'bmi')::numeric >= 25) as ow,
      count(*) filter (where jsonb_typeof(a.scores -> 'whr') = 'number'
                         and (a.scores ->> 'whr')::numeric >= case when pw.sex = 'male' then 0.90 else 0.85 end) as ce,
      count(*) filter (where a.answers ->> 'd_breakfast' in ('0', '1-3')) as sb,
      count(*) filter (where a.answers ->> 'd_fruit' in ('0', '1-3') or a.answers ->> 'd_veg' in ('0', '1-3')) as fv,
      count(*) filter (where a.answers ->> 'm_active_days' in ('0', '1-2')) as ia,
      count(*) filter (where a.answers ->> 's_hours' in ('<5', '5-6')) as ss,
      count(*) filter (where a.answers ->> 'a_load' in ('1', '2') or a.answers ->> 'a_interfere' in ('often', 'very_often')) as st,
      count(*) filter (where a.scores ->> 'phq2_positive' = 'true') as lm
    from pw
    left join public.assessments a on a.window_id = pw.wid and a.user_id = pw.uid and a.status = 'completed'
    group by pw.term, pw.faculty, pw.yr, pw.sex
    having count(a.id) >= 5
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           't', term, 'd', opens, 'f', faculty, 'y', yr, 's', case sex when 'female' then 'F' else 'M' end,
           'e', eligible, 'n', n, 'c', jsonb_build_array(ow, ce, sb, fv, ia, ss, st, lm))
         order by opens), '[]'::jsonb)
  into result from cell;
  return result;
end;
$$;
revoke execute on function public.admin_health_cells() from public, anon;
grant execute on function public.admin_health_cells() to authenticated;

-- Overview: eligible = registered by the time the window closed.
create or replace function public.admin_assessment_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare result jsonb;
begin
  if not public.is_admin() then raise exception 'not authorised' using errcode = '42501'; end if;
  select jsonb_build_object(
    'students', (select count(*) from public.profiles where onboarding_completed),
    'students_by_faculty', (
      select coalesce(jsonb_object_agg(f, n), '{}'::jsonb)
      from (select coalesce(faculty, 'Unspecified') f, count(*) n from public.profiles where onboarding_completed group by 1) x),
    'windows', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', w.id, 'title', w.title, 'term', w.term, 'faculty', w.faculty,
        'opens_at', w.opens_at, 'closes_at', w.closes_at,
        'completed', (select count(*) from public.assessments a where a.window_id = w.id and a.status = 'completed'),
        'in_progress', (select count(*) from public.assessments a where a.window_id = w.id and a.status = 'in_progress'),
        'eligible', (select count(*) from public.profiles p
                     where p.onboarding_completed and p.created_at <= w.closes_at and (w.faculty is null or p.faculty = w.faculty))
      ) order by w.opens_at desc), '[]'::jsonb)
      from public.assessment_windows w)
  ) into result;
  return result;
end;
$$;

-- Completion list: only windows that have opened, and only students registered
-- by the time the window closed.
create or replace function public.admin_assessment_completion(p_window uuid default null, p_registration text default null)
returns table (registration_number text, faculty text, academic_year text, window_term text, status text, completed_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then raise exception 'not authorised' using errcode = '42501'; end if;
  return query
  select p.registration_number, p.faculty, p.academic_year, w.term,
         coalesce(a.status, 'not_started') as status, a.completed_at
  from public.assessment_windows w
  join public.profiles p
    on p.onboarding_completed and p.created_at <= w.closes_at and (w.faculty is null or p.faculty = w.faculty)
  left join public.assessments a on a.window_id = w.id and a.user_id = p.id
  where w.opens_at <= now()
    and (p_window is null or w.id = p_window)
    and (p_registration is null or upper(p.registration_number) like '%' || upper(trim(p_registration)) || '%')
  order by w.opens_at desc, p.registration_number;
end;
$$;
