-- Sri Lankan dietary diversity score and faculty-wise assessment analytics.
--
--  1. Dietary diversity now uses the ten food groups used to measure the
--     dietary diversity of Sri Lankan men and women (Abeywickrama et al.,
--     2020, adapted from FAO/FANTA): cereals; tubers and starchy vegetables;
--     root and fruit vegetables; green leafy vegetables; fruits; pulses, nuts
--     and seeds; meat and poultry; eggs; fish and seafood; milk and milk
--     products. MDD-W was designed for women only. dds_group() maps the keys
--     stored by earlier versions of the app onto these groups, and Smart Eater
--     counts groups through it.
--  2. The assessment report also returns pooled health indicators (BMI,
--     waist-to-hip ratio, blood pressure, fasting glucose, lipids and the
--     PHQ-2 screen). The dashboard calls the report once overall and once per
--     faculty to compare faculties; groups under five students stay hidden.

-- ---------------------------------------------------------------------------
-- 1. Dietary diversity groups
-- ---------------------------------------------------------------------------
create or replace function public.dds_group(p_group text, p_food text default null)
returns text
language sql
immutable
set search_path = ''
as $fn$
  select case
    when p_group in ('cereals', 'starchy', 'other_veg', 'dark_leafy', 'fruits', 'pulses', 'meat', 'eggs', 'fish', 'dairy') then p_group
    when p_group = 'grains' then
      case when lower(coalesce(p_food, '')) ~ '(potato|manioc|cassava|yam|kiriala|innala|polos|jackfruit|breadfruit)' then 'starchy' else 'cereals' end
    when p_group in ('meat_fish', 'protein') then
      case when lower(coalesce(p_food, '')) ~ '(fish|sprat|halmasso|prawn|shrimp|cuttle|squid|crab|tuna|seer|seafood|karawala|ambul)' then 'fish' else 'meat' end
    when p_group = 'vita_veg_fruit' then
      case when lower(coalesce(p_food, '')) ~ '(papaya|mango|fruit|melon|passion)' then 'fruits' else 'other_veg' end
    when p_group = 'other_fruit' then 'fruits'
    when p_group = 'greens' then 'dark_leafy'
    when p_group in ('nuts_seeds', 'fats_seeds', 'legumes_nuts') then 'pulses'
    when p_group = 'probiotics' then 'dairy'
    else null
  end;
$fn$;

create or replace function public.refresh_badges()
returns setof text
language plpgsql
security definer
set search_path = ''
as $fn$
declare uid uuid := auth.uid(); p public.profiles%rowtype; new_codes text[] := '{}';
begin
  if uid is null then return; end if;
  select * into p from public.profiles where id = uid;

  -- Aqua Achiever: daily water goal, 3 days in a row.
  if exists (
    with d as (select (logged_at at time zone 'Asia/Colombo')::date d from public.water_logs where user_id = uid
               group by 1 having sum(amount_ml) >= coalesce(p.water_goal_ml, 2500))
    select 1 from d a join d b on b.d = a.d - 1 join d c on c.d = a.d - 2
  ) then new_codes := new_codes || 'aqua_achiever'; end if;

  -- Active Aura: step goal or 30 active minutes a day, 7 days in a row.
  if exists (
    with d as (select activity_date d from public.activity_logs where user_id = uid group by 1
               having sum(steps) >= coalesce(p.step_goal, 8000) or sum(active_minutes) >= 30),
    runs as (select d - (row_number() over (order by d))::int as grp from d)
    select 1 from runs group by grp having count(*) >= 7
  ) then new_codes := new_codes || 'active_aura'; end if;

  -- Smart Eater: for 7 days in a row, breakfast, lunch and dinner logged with
  -- 5 or more of the 10 dietary diversity groups, and that week's diet quality
  -- score at least 22/42.
  if exists (
    with meals_ok as (
      select meal_date d from public.meals where user_id = uid and status = 'logged'
      group by 1 having count(distinct meal_type) filter (where meal_type in ('breakfast', 'lunch', 'dinner')) = 3),
    groups_ok as (select log_date d from public.diversity_logs where user_id = uid group by 1
                  having count(distinct public.dds_group(food_group, food_name)) >= 5),
    ok as (select m.d from meals_ok m join groups_ok g on g.d = m.d)
    select 1 from ok o
    where (select count(*) from ok x where x.d between o.d - 6 and o.d) = 7
      and public.pdqs_from_meals(uid, o.d - 6, o.d) >= 22
  ) then new_codes := new_codes || 'smart_eater'; end if;

  -- Heart Minded: the heart check, a blood pressure reading and a blood sugar
  -- or triglyceride result (logged, or from a blood report), within 90 days.
  if exists (select 1 from public.tool_results where user_id = uid and tool = 'cvd' and created_at > now() - interval '90 days')
     and exists (select 1 from public.tool_results where user_id = uid and tool = 'vitals' and data ? 'systolic' and created_at > now() - interval '90 days')
     and (exists (select 1 from public.tool_results where user_id = uid and tool = 'vitals'
                  and (data ? 'fasting_glucose' or data ? 'triglycerides') and created_at > now() - interval '90 days')
          or exists (select 1 from public.blood_reports where user_id = uid and status = 'done' and created_at > now() - interval '90 days'))
  then new_codes := new_codes || 'heart_minded'; end if;

  -- Curious Learner: 5 articles read to the end, from 3 or more topics.
  if exists (
    select 1 from public.article_reads r join public.education_articles a on a.id = r.article_id
    where r.user_id = uid having count(*) >= 5 and count(distinct a.category) >= 3
  ) then new_codes := new_codes || 'curious_learner'; end if;

  return query
  with ins as (
    insert into public.user_badges (user_id, badge_code)
    select uid, c from unnest(new_codes) c
    on conflict do nothing
    returning badge_code
  ), notif as (
    insert into public.notifications (user_id, category, label, title, body, icon, route)
    select uid, 'milestone', 'Badge', 'You earned ' || b.title || '!', b.description || ' Well done, keep it up.', b.icon, '/milestones'
    from ins join public.badges b on b.code = ins.badge_code
    returning 1
  )
  select badge_code from ins;
end; $fn$;

-- ---------------------------------------------------------------------------
-- 2. Assessment report with health indicators
-- ---------------------------------------------------------------------------
create or replace function public.admin_assessment_report(p_window uuid default null, p_faculty text default null, p_term text default null)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  min_group constant int := 5;
  n int;
  q record;
  questions jsonb := '{}'::jsonb;
  item jsonb;
  result jsonb;
begin
  if not public.is_admin() then raise exception 'not authorised' using errcode = '42501'; end if;

  drop table if exists pg_temp._base;
  create temporary table _base on commit drop as
  select a.answers, a.scores, p.faculty, p.sex, p.academic_year
  from public.assessments a
  join public.profiles p on p.id = a.user_id
  left join public.assessment_windows w on w.id = a.window_id
  where a.status = 'completed'
    and (p_window is null or a.window_id = p_window)
    and (p_faculty is null or p.faculty = p_faculty)
    and (p_term is null or w.term = p_term);

  select count(*) into n from _base;
  if n < min_group then
    return jsonb_build_object('n', n, 'suppressed', true, 'min_group', min_group);
  end if;

  for q in select * from public.assessment_questions order by domain_id, position loop
    if q.kind in ('single', 'scale') then
      select jsonb_build_object('kind', q.kind, 'answered', coalesce(sum(c), 0), 'counts', coalesce(jsonb_object_agg(v, c), '{}'::jsonb))
      into item
      from (select answers ->> q.id v, count(*) c from _base where answers ? q.id group by 1) x;
    elsif q.kind = 'multi' then
      select jsonb_build_object('kind', q.kind,
               'answered', (select count(*) from _base where jsonb_typeof(answers -> q.id) = 'array'),
               'counts', coalesce(jsonb_object_agg(v, c), '{}'::jsonb))
      into item
      from (select e v, count(*) c
            from _base, jsonb_array_elements_text(case when jsonb_typeof(answers -> q.id) = 'array' then answers -> q.id else '[]'::jsonb end) e
            group by 1) x;
    elsif q.kind = 'number' then
      select jsonb_build_object('kind', q.kind, 'answered', count(v),
               'mean', round(avg(v), 1), 'median', round(percentile_cont(0.5) within group (order by v)::numeric, 1),
               'p25', round(percentile_cont(0.25) within group (order by v)::numeric, 1),
               'p75', round(percentile_cont(0.75) within group (order by v)::numeric, 1))
      into item
      from (select (answers ->> q.id)::numeric v from _base where jsonb_typeof(answers -> q.id) = 'number') x;
    else
      -- Free text: shown only in shuffled order, with no dates or groups attached.
      select jsonb_build_object('kind', q.kind, 'answered', count(*),
               'responses', coalesce(jsonb_agg(t order by random()), '[]'::jsonb))
      into item
      from (select left(trim(answers ->> q.id), 500) t from _base where length(trim(coalesce(answers ->> q.id, ''))) > 0 limit 300) x;
    end if;
    questions := questions || jsonb_build_object(q.id, item);
  end loop;

  select jsonb_build_object(
    'n', n,
    'suppressed', false,
    'min_group', min_group,
    'overall', (select round(avg((scores ->> 'overall')::numeric), 1) from _base where scores ? 'overall'),
    'domains', (
      select coalesce(jsonb_object_agg(d, s), '{}'::jsonb)
      from (select k d, round(avg(v::numeric), 1) s
            from _base, jsonb_each_text(coalesce(scores -> 'domains', '{}'::jsonb)) as e(k, v)
            group by 1) x),
    'bmi_categories', (
      select coalesce(jsonb_object_agg(c, cnt), '{}'::jsonb)
      from (select case when b < 18.5 then 'Underweight' when b < 25 then 'Normal' when b < 30 then 'Overweight' else 'Obesity' end c, count(*) cnt
            from (select (scores ->> 'bmi')::numeric b from _base where scores ? 'bmi') y group by 1) x),
    'by_faculty', (
      select coalesce(jsonb_object_agg(f, case when c < min_group then null else to_jsonb(c) end), '{}'::jsonb)
      from (select coalesce(faculty, 'Unspecified') f, count(*) c from _base group by 1) x),
    'by_sex', (
      select coalesce(jsonb_object_agg(s, case when c < min_group then null else to_jsonb(c) end), '{}'::jsonb)
      from (select coalesce(sex, 'unspecified') s, count(*) c from _base group by 1) x),
    'indicators', (
      select jsonb_build_object(
        'bmi_n', count(bmi),
        'underweight', count(*) filter (where bmi < 18.5),
        'overweight_obese', count(*) filter (where bmi >= 25),
        'whr_n', count(whr),
        'whr_high', count(*) filter (where whr >= case when sex = 'male' then 0.90 else 0.85 end),
        'bp_n', count(*) filter (where sbp is not null or dbp is not null),
        'bp_raised', count(*) filter (where sbp >= 140 or dbp >= 90),
        'fbg_n', count(fbg),
        'fbg_raised', count(*) filter (where fbg >= 126),
        'tg_n', count(tg),
        'tg_high', count(*) filter (where tg >= 150),
        'chol_n', count(chol),
        'chol_high', count(*) filter (where chol >= 190),
        'phq2_n', count(phq2),
        'phq2_positive', count(*) filter (where phq2 >= 3))
      from (
        select sex,
               case when jsonb_typeof(scores -> 'bmi') = 'number' then (scores ->> 'bmi')::numeric end bmi,
               case when jsonb_typeof(scores -> 'whr') = 'number' then (scores ->> 'whr')::numeric end whr,
               case when jsonb_typeof(scores -> 'phq2') = 'number' then (scores ->> 'phq2')::numeric end phq2,
               case when jsonb_typeof(answers -> 'k_sbp') = 'number' then (answers ->> 'k_sbp')::numeric end sbp,
               case when jsonb_typeof(answers -> 'k_dbp') = 'number' then (answers ->> 'k_dbp')::numeric end dbp,
               case when jsonb_typeof(answers -> 'k_fbg') = 'number' then (answers ->> 'k_fbg')::numeric end fbg,
               case when jsonb_typeof(answers -> 'k_tg') = 'number' then (answers ->> 'k_tg')::numeric end tg,
               case when jsonb_typeof(answers -> 'k_chol') = 'number' then (answers ->> 'k_chol')::numeric end chol
        from _base) h),
    'questions', questions
  ) into result;
  return result;
end;
$$;
revoke execute on function public.admin_assessment_report(uuid, text, text) from public, anon;
grant execute on function public.admin_assessment_report(uuid, text, text) to authenticated;
