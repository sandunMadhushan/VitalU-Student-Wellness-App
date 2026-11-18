-- DEMONSTRATION DATA (step 2 of 2): assessments for the students created by
-- demo_peradeniya_1_students.sql, for the five past windows. Each student only
-- takes part in windows that closed after they registered. Answers use the
-- questionnaire's own option values; scores follow scoreAssessment() in the app.
-- Then, ONE CALL PER STATEMENT (each is quick, but a single request that does all five can time out):
--   select demo_seed.gen_window(0);  ... select demo_seed.gen_window(4);
--   select demo_seed.score_window(0); ... select demo_seed.score_window(4);
-- and finally:  drop schema demo_seed cascade;

-- 'value:weight,value:weight' -> one random value
create or replace function demo_seed.pk(spec text) returns text language plpgsql volatile as $$
declare items text[] := string_to_array(spec, ','); tot float8 := 0; acc float8 := 0; r float8; it text;
begin
  foreach it in array items loop tot := tot + split_part(it, ':', 2)::float8; end loop;
  r := random() * tot;
  foreach it in array items loop
    acc := acc + split_part(it, ':', 2)::float8;
    if r <= acc then return split_part(it, ':', 1); end if;
  end loop;
  return split_part(items[1], ':', 1);
end $$;

create or replace function demo_seed.rand_subset(vals text[], k int) returns jsonb language sql volatile as
$$ select coalesce(jsonb_agg(x), '[]'::jsonb) from (select x from unnest(vals) x order by random() limit k) t $$;

-- Probability (%) of each health concern. ind: 1 overweight/obese, 2 central obesity, 3 skips breakfast,
-- 4 low fruit and veg, 5 inactive, 6 short sleep, 7 high stress, 8 low mood.
-- p 0..4 is the period, f 1..9 the faculty, y 1..4 the academic year, s 1 female / 2 male.
create or replace function demo_seed.rate(ind int, p int, f int, y int, s int) returns float8 language sql immutable as $$
  select least(95, greatest(2,
    (array[25,18,38,68,55,47,41,15])[ind]
    + (array[0.4,0,-2.4,1.8,2.2,0.3,3,-1.3])[ind] * (p - 4)
    + (array[-4,-3,4,1,2,6,0,-2,-1, -2,-2,3,1,1,4,0,-1,0, -7,-4,3,1,9,6,-2,2,-6, -8,-5,3,1,8,5,4,2,-7,
             -9,5,-4,6,4,0,8,-1,-6, -2,3,-3,6,7,-1,9,0,1, -3,5,-4,7,9,-2,12,1,3, -2,2,-1,3,4,-2,5,0,1])[(ind - 1) * 9 + f]
    + (array[-4,-1,2,3, -2,0,1,2, 4,2,0,-2, 3,1,0,-2, 0,2,4,6, 0,1,3,6, 2,0,3,7, 0,0,2,4])[(ind - 1) * 4 + y]
    + (array[-2,2, 3,-3, 3,-3, -3,3, 8,-8, 2,-2, 4,-4, 3,-3])[(ind - 1) * 2 + s]
    + case when ind = 4 and p = 4 and f in (5, 6, 8) then -3 else 0 end)::float8) $$;

create or replace function demo_seed.gen_window(p_idx int, p_fac int default null) returns int language plpgsql as $fn$
declare w public.assessment_windows%rowtype; n int;
begin
  select * into w from public.assessment_windows where faculty is null
    and term = (array['Mid Year Assessment 2024','Year End Assessment 2024','Mid Year Assessment 2025','Year End Assessment 2025','Mid Year Assessment 2026'])[p_idx + 1];

  insert into public.assessments (user_id, window_id, title, status, current_index, answers, scores, started_at, completed_at)
  with el as materialized (
    select s.*, least(4, greatest(1, extract(year from w.opens_at)::int - s.intake + 1)) as yr, case s.sex when 'female' then 1 else 2 end as sx
    from demo_seed.students s where s.created_at <= w.closes_at and (p_fac is null or s.f = p_fac)
  ),
  part as materialized (
    select el.* from el
    where random() < least(0.95, greatest(0.2,
      (array[.72,.58,.66,.46,.74,.69,.81,.70,.52])[el.f] * (array[.66,.76,.86,.94,1])[p_idx + 1]
      + (array[.04,.02,0,-.06])[el.yr] + (random() - .5) * .08))
  ),
  fl as materialized (
    select part.*,
      random() * 100 < demo_seed.rate(1, p_idx, f, yr, sx) as ow,
      random() * 100 < demo_seed.rate(2, p_idx, f, yr, sx) as ce,
      random() * 100 < demo_seed.rate(3, p_idx, f, yr, sx) as sb,
      random() * 100 < demo_seed.rate(4, p_idx, f, yr, sx) as fv,
      random() * 100 < demo_seed.rate(5, p_idx, f, yr, sx) as ia,
      random() * 100 < demo_seed.rate(6, p_idx, f, yr, sx) as ss,
      random() * 100 < demo_seed.rate(7, p_idx, f, yr, sx) as st,
      random() * 100 < demo_seed.rate(8, p_idx, f, yr, sx) as lm
    from part
  ),
  fl2 as materialized (
    select fl.*,
      (fv and random() < .75) as fruit_low, (st and random() < .75) as load_low,
      (random() < .08) as bp_hi, (random() < .06) as fbg_hi, (random() < .16) as tg_hi, (random() < .2) as chol_hi, (random() < .6) as has_lab,
      (random() < .025) as is_ip,
      case when lm then demo_seed.pk('12:.2,21:.2,22:.15,30:.1,03:.1,31:.1,13:.05,23:.05,33:.05')
           else demo_seed.pk('00:.3,01:.18,10:.18,11:.14,02:.1,20:.1') end as ph,
      (case when ow then 25.3 + random() * 6 when random() < .10 then 16.8 + random() * 1.5 else 18.7 + random() * 6 end)::numeric as bmi,
      (case when ce then (case when sex = 'male' then .91 + random() * .08 else .86 + random() * .09 end)
            else (case when sex = 'male' then .76 + random() * .12 else .70 + random() * .135 end) end)::numeric as whr,
      w.opens_at + (random() * (w.closes_at - w.opens_at) * .98) as done_at
    from fl
  ),
  fl3 as materialized (
    select fl2.*,
      (fv and (not fruit_low or random() < .6)) as veg_low,
      (st and (not load_low or random() < .75)) as intf_high,
      round(bmi * power(height / 100.0, 2), 1) as kw,
      round(hip * whr, 0) as kwst
    from fl2
  )
  select id, w.id, w.title,
    case when is_ip then 'in_progress' else 'completed' end,
    case when is_ip then 4 else 49 end,
    case when is_ip then jsonb_build_object('k_height', height, 'k_weight', kw, 'k_waist', kwst, 'k_hip', hip)
    else jsonb_strip_nulls(
      jsonb_build_object(
        'p_profile', 'same',
        'p_general', greatest(1, least(5, round(4.3 - .4 * (ow::int + ia::int + ss::int + st::int + lm::int + sb::int) + demo_seed.norm(0, .7))))::int::text,
        'p_new_dx', case when random() < .82 then '["none"]'::jsonb else jsonb_build_array(demo_seed.pk('high_bp:.35,diabetes:.15,cholesterol:.2,heart:.05,other:.25')) end,
        'p_substance', case when random() < .86 then '["none"]'::jsonb else jsonb_build_array(demo_seed.pk('tobacco:.2,vape:.1,alcohol:.35,cannabis:.03,nonpres:.05,other:.07,pns:.2')) end,
        'd_breakfast', case when sb then demo_seed.pk('0:.35,1-3:.65') else demo_seed.pk('4-6:.45,7:.55') end,
        'd_veg', case when veg_low then demo_seed.pk('0:.3,1-3:.7') else demo_seed.pk('4-6:.5,7:.5') end,
        'd_greens', case when fv then demo_seed.pk('0:.3,1-2:.4,3-4:.2,5-7:.1') else demo_seed.pk('0:.08,1-2:.25,3-4:.4,5-7:.27') end,
        'd_fruit', case when fruit_low then demo_seed.pk('0:.3,1-3:.7') else demo_seed.pk('4-6:.5,7:.5') end,
        'd_pulses', demo_seed.pk('0:.1,1-2:.3,3-4:.35,5-7:.25'),
        'd_protein', demo_seed.pk('0:.05,1-2:.25,3-4:.4,5-7:.3'),
        'd_wholegrain', demo_seed.pk('0:.25,1-2:.4,3-4:.25,5-7:.1'),
        'd_dairy', demo_seed.pk('0:.2,1-2:.4,3-4:.25,5-7:.15'),
        'd_sugary', case when ow then demo_seed.pk('0:.15,1-2:.35,3-4:.3,5-7:.2') else demo_seed.pk('0:.3,1-2:.4,3-4:.2,5-7:.1') end,
        'd_fried', case when ow then demo_seed.pk('0:.1,1-2:.35,3-4:.35,5-7:.2') else demo_seed.pk('0:.25,1-2:.45,3-4:.2,5-7:.1') end,
        'd_balanced', case when fv or sb then demo_seed.pk('almost_always:.1,often:.3,sometimes:.4,rarely:.2') else demo_seed.pk('almost_always:.3,often:.4,sometimes:.25,rarely:.05') end,
        'd_rating', demo_seed.pk('1:.05,2:.15,3:.4,4:.3,5:.1'),
        'd_skip_money', demo_seed.pk('never:.5,once:.25,sometimes:.18,often:.07'),
        'a_load', case when load_low then demo_seed.pk('1:.4,2:.6') else demo_seed.pk('3:.4,4:.4,5:.2') end,
        'a_interfere', case when intf_high then demo_seed.pk('often:.7,very_often:.3') else demo_seed.pk('never:.3,rarely:.4,sometimes:.3') end,
        'e_mood', case when lm then demo_seed.pk('1:.4,2:.6') when st then demo_seed.pk('2:.25,3:.5,4:.25') else demo_seed.pk('3:.3,4:.45,5:.25') end,
        'e_phq1', substr(ph, 1, 1),
        'e_phq2', substr(ph, 2, 1))
      || jsonb_build_object(
        's_hours', case when ss then demo_seed.pk('<5:.25,5-6:.75') else demo_seed.pk('7-8:.7,>8:.3') end,
        's_quality', case when ss then demo_seed.pk('very_bad:.2,fairly_bad:.45,fairly_good:.3,very_good:.05') else demo_seed.pk('very_bad:.03,fairly_bad:.17,fairly_good:.5,very_good:.3') end,
        's_regular', demo_seed.pk('mostly:.4,sometimes:.4,rarely:.2'),
        'm_active_days', case when ia then demo_seed.pk('0:.25,1-2:.75') else demo_seed.pk('3-4:.5,5-7:.5') end,
        'm_sitting', demo_seed.pk('<6:.2,6-9:.55,10+:.25'),
        'f_living', accommodation,
        'f_money', demo_seed.pk('never:.45,sometimes:.35,often:.15,always:.05'),
        'o_talk', demo_seed.pk('always:.5,sometimes:.35,no:.15'),
        'o_lonely', demo_seed.pk('never:.25,rarely:.35,sometimes:.3,often:.1'),
        'c_food', demo_seed.pk('1:.1,2:.25,3:.35,4:.22,5:.08'),
        'c_health_centre', demo_seed.pk('yes:.35,no_need:.45,no_barrier:.2'),
        'c_barriers', demo_seed.rand_subset(array['unaware','hours','waiting','privacy','distance','uncomfortable'], 1 + floor(random() * 3)::int),
        'v_challenges', demo_seed.rand_subset(array['workload','emotional','money','food_cost','meals','inactive','sleep','care','living'], 1 + floor(random() * 3)::int),
        'v_priorities', demo_seed.rand_subset(array['canteen','affordable','mental','fitness','water','schedule','screening','hostels','education'], 1 + floor(random() * 3)::int),
        'v_problem', case when random() < .2 then demo_seed.elt(array['Exams and deadlines bunch up in the same weeks.','Healthy food in the canteen is too expensive for my allowance.','Not enough quiet places to rest between lectures.','Hostel noise makes it hard to sleep.','Long travel from boarding to the faculty.','Hard to find time to exercise during lecture weeks.']) end,
        'v_change', case when random() < .25 then demo_seed.elt(array['More affordable vegetable and fruit options.','Spread the exam timetable out.','Open the sports complex earlier in the morning.','More counsellors and a quicker booking system.','Free drinking water stations near every faculty.','Health talks during orientation.','Longer lunch breaks.']) end,
        'k_source', demo_seed.pk('health_centre:.3,clinic:.25,self:.35,none:.1'),
        'k_when', demo_seed.pk('week:.1,month:.3,six:.35,older:.25'),
        'k_height', height, 'k_weight', kw, 'k_waist', kwst, 'k_hip', hip,
        'k_sbp', case when has_lab then (case when bp_hi then 140 + floor(random() * 25) else 100 + floor(random() * 28) end) end,
        'k_dbp', case when has_lab then (case when bp_hi then 90 + floor(random() * 10) else 62 + floor(random() * 20) end) end,
        'k_fbg', case when has_lab then (case when fbg_hi then 126 + floor(random() * 45) else 78 + floor(random() * 30) end) end,
        'k_tg', case when has_lab then (case when tg_hi then 150 + floor(random() * 110) else 60 + floor(random() * 80) end) end,
        'k_chol', case when has_lab then (case when chol_hi then 190 + floor(random() * 60) else 125 + floor(random() * 60) end) end)) end,
    '{}'::jsonb,
    done_at - ((4 + random() * 8) * interval '1 minute'),
    case when is_ip then null else done_at end
  from fl3;
  get diagnostics n = row_count;

  get diagnostics n = row_count;
  return n;
end $fn$;

-- Scores, as scoreAssessment() does in the app: per-domain 0 to 100, overall, BMI, WHR, PHQ-2.
-- Staging tables are indexed and analysed; without that the planner goes quadratic.
create or replace function demo_seed.score_window(p_idx int) returns int language plpgsql as $fn$
declare w public.assessment_windows%rowtype; n int;
begin
  select * into w from public.assessment_windows where faculty is null
    and term = (array['Mid Year Assessment 2024','Year End Assessment 2024','Mid Year Assessment 2025','Year End Assessment 2025','Mid Year Assessment 2026'])[p_idx + 1];
  drop table if exists _qa;
  create temp table _qa (aid uuid, domain_id int, frac numeric) on commit drop;
  insert into _qa
  select a3.id, q.domain_id, (opt.o ->> 'score')::numeric / nullif(mx.m, 0)
  from public.assessments a3
  join public.assessment_questions q on q.kind in ('single', 'scale') and a3.answers ? q.id
  cross join lateral (select max((x ->> 'score')::numeric) as m from jsonb_array_elements(q.options) x where x ->> 'score' is not null) mx
  join lateral (select x as o from jsonb_array_elements(q.options) x where x ->> 'value' = a3.answers ->> q.id and x ->> 'score' is not null limit 1) opt on true
  where a3.window_id = w.id and a3.status = 'completed' and a3.scores = '{}'::jsonb;
  create index on _qa (aid);
  analyze _qa;
  create temp table _dom on commit drop as
    select aid, jsonb_object_agg(domain_id::text, sc) as domains, round(avg(sc)) as overall
    from (select aid, domain_id, round(avg(frac) * 100) as sc from _qa where frac is not null group by aid, domain_id) dd group by aid;
  create index on _dom (aid);
  analyze _dom;
  update public.assessments a set
    scores = jsonb_strip_nulls(jsonb_build_object('domains', coalesce(d.domains, '{}'::jsonb), 'overall', d.overall,
      'bmi', round((a.answers ->> 'k_weight')::numeric / power((a.answers ->> 'k_height')::numeric / 100, 2), 1),
      'bmi_source', a.answers ->> 'k_source',
      'whr', round((a.answers ->> 'k_waist')::numeric / (a.answers ->> 'k_hip')::numeric, 2),
      'phq2', (a.answers ->> 'e_phq1')::int + (a.answers ->> 'e_phq2')::int,
      'phq2_positive', (a.answers ->> 'e_phq1')::int + (a.answers ->> 'e_phq2')::int >= 3)),
    result_label = case when d.overall is null then 'Completed' when d.overall >= 75 then 'Healthy habits' when d.overall >= 55 then 'Mostly on track'
           when d.overall >= 35 then 'Room to improve' else 'Needs attention' end
  from _dom d where a.id = d.aid and a.window_id = w.id and a.status = 'completed' and a.scores = '{}'::jsonb;
  get diagnostics n = row_count;
  return n;
end $fn$;
