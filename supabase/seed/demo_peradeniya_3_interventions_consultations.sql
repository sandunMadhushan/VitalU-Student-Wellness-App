-- DEMONSTRATION DATA (step 3): health professionals, interventions and
-- consultation requests, drawn from the demo students created by step 1.
-- Safe to re-run: each block only inserts when its table has no demo rows.
-- Reasons and notes are stored but only a linked health professional can read them
-- (see the migration 20261119120000_...).

insert into public.health_professionals (name, role, unit)
select v.name, v.role, v.unit
from (values
  ('Ms. K. Fernando', 'Counsellor', 'Counselling Centre'),
  ('Mr. R. Jayasinghe', 'Counsellor', 'Counselling Centre'),
  ('Dr. N. Perera', 'Medical Officer', 'Medical Centre'),
  ('Dr. M. Rajapaksa', 'Medical Officer', 'Medical Centre'),
  ('Ms. S. Wickramasinghe', 'Dietitian', 'Nutrition Unit'),
  ('Mr. A. Silva', 'Physiotherapist', 'Sports Medicine')) v(name, role, unit)
where not exists (select 1 from public.health_professionals h where h.name = v.name);

insert into public.health_interventions (title, indicator, faculties, owner, unit, start_date, end_date, status, target_pts, baseline_period, milestones, notes)
select v.title, v.indicator, v.faculties, v.owner, v.unit, v.s::date, v.e::date, v.status, v.target, v.base, v.ms::jsonb, v.notes
from (values
  ('Healthy Plate weeks and subsidised fruit stalls', 'low_fruit_veg', array['Faculty of Engineering', 'Faculty of Management', 'Faculty of Science'], 'Dr. N. Perera', 'Nutrition Unit',
   '2026-02-02', '2026-12-18', 'running', 8, '2025-end',
   '[{"text":"Review canteen menus with operators","done":true},{"text":"Weekly subsidised fruit stalls started","done":true},{"text":"Healthy Plate awareness weeks in three faculties","done":false},{"text":"Share results at the Year End 2026 assessment","done":false}]',
   'Canteen operators agreed to a price cap on seasonal fruit.'),
  ('Campus Move 30: lunchtime activity breaks', 'inactive', array[]::text[], 'Mr. A. Silva', 'Sports Unit',
   '2026-03-02', '2026-11-30', 'running', 6, '2025-end',
   '[{"text":"Open-access sports sessions timetabled","done":true},{"text":"Walking routes marked on campus","done":true},{"text":"Faculty step-count challenge","done":false},{"text":"Midpoint review with faculties","done":false}]',
   'Uptake is lowest in the evening sessions.'),
  ('Peer-led stress management workshops', 'high_stress', array['Faculty of Allied Health Sciences', 'Faculty of Dental Sciences', 'Faculty of Engineering', 'Faculty of Medicine'], 'Ms. K. Fernando', 'Counselling Centre',
   '2027-01-11', '2027-06-30', 'planned', 6, '2026-mid',
   '[{"text":"Train 20 student peer facilitators","done":false},{"text":"Agree timetable slots with four faculties","done":false},{"text":"Run first round of workshops","done":false},{"text":"Reassess at Mid Year 2027","done":false}]',
   ''),
  ('Hostel breakfast clubs', 'skip_breakfast', array['Faculty of Engineering', 'Faculty of Management', 'Faculty of Arts'], 'Ms. S. Wickramasinghe', 'Nutrition Unit',
   '2025-07-07', '2025-11-28', 'completed', 4, '2025-mid',
   '[{"text":"Agree early opening hours with hostel kitchens","done":true},{"text":"Launch clubs in six hostels","done":true},{"text":"Collect student feedback","done":true},{"text":"Reassess at Year End 2025","done":true}]',
   'Continued as a standing service after the pilot.'),
  ('Sleep hygiene awareness campaign', 'short_sleep', array[]::text[], 'Dr. M. Rajapaksa', 'Medical Centre',
   '2026-08-03', '2026-12-11', 'hold', 5, '2026-mid',
   '[{"text":"Design posters and in-app messages","done":true},{"text":"Pilot quiet hours in two hostels","done":false},{"text":"Campaign before examinations","done":false}]',
   'Paused until after the semester examinations.')) v(title, indicator, faculties, owner, unit, s, e, status, target, base, ms, notes)
where not exists (select 1 from public.health_interventions i where i.title = v.title);

do $$
declare students uuid[]; boosted uuid[];
begin
  if exists (select 1 from public.consultation_requests) then return; end if;
  select array_agg(p.id) into students from public.profiles p join auth.users u on u.id = p.id where u.raw_user_meta_data ->> 'demo_seed' = 'peradeniya-2026';
  select array_agg(p.id) into boosted from public.profiles p join auth.users u on u.id = p.id
   where u.raw_user_meta_data ->> 'demo_seed' = 'peradeniya-2026'
     and p.faculty in ('Faculty of Medicine', 'Faculty of Engineering', 'Faculty of Allied Health Sciences', 'Faculty of Dental Sciences');

  create temp table _r (requested_at timestamptz, cat text, student uuid, urg text, mode text, st text, pro uuid, sched timestamptz, fu timestamptz, reason text, notes text) on commit drop;

  -- About a year of past requests, completed unless recent enough to need a follow-up.
  insert into _r
  with cats(cat, base, growth, role) as (values
    ('stress', 22, 1.6, 'Counsellor'), ('mood', 14, .7, 'Counsellor'), ('academic', 18, .4, 'Counsellor'), ('sleep', 9, .6, 'Medical Officer'),
    ('nutrition', 11, 0, 'Dietitian'), ('activity', 8, .1, 'Physiotherapist'), ('sexual', 6, .1, 'Medical Officer'), ('substance', 4, 0, 'Counsellor')),
  mo as (select i, date_trunc('month', now()) - ((11 - i) * interval '1 month') as m from generate_series(0, 11) i),
  cnt as (select cats.*, mo.i, mo.m,
            greatest(0, round((base + growth * mo.i) * case when extract(month from mo.m) in (6, 11) then 1.35 when extract(month from mo.m) in (4, 9) then 1.1 else 1 end
                              + (random() - .5) * 4))::int as n
          from cats cross join mo),
  gen as (select cat, role, m, generate_series(1, n) as k from cnt),
  r1 as materialized (
    select cat, role,
      least(m + floor(random() * 27)::int * interval '1 day' + (8 + random() * 9) * interval '1 hour', now() - interval '15 days' - random() * interval '10 days') as req,
      random() as r_u, random() as r_m, random() as r_s, random() as r_f
    from gen),
  r2 as materialized (
    select r1.*,
      case when cat in ('stress', 'academic', 'sleep') and random() < .4 then boosted[1 + floor(random() * cardinality(boosted))::int]
           else students[1 + floor(random() * cardinality(students))::int] end as student,
      (select h.id from public.health_professionals h where h.role = r1.role order by random() limit 1) as pro
    from r1)
  select req, cat, student,
    case when r_u < .1 then 'urgent' when r_u < .4 then 'soon' else 'routine' end,
    case when r_m < .6 then 'In person' when r_m < .85 then 'Online' else 'Phone' end,
    case when r_f < .08 and req > now() - interval '45 days' then 'followup' else 'completed' end,
    pro,
    req + (1 + floor(r_s * 4)::int) * interval '1 day' + interval '2 hours',
    case when r_f < .08 and req > now() - interval '45 days' then now() + (2 + floor(random() * 12)::int) * interval '1 day' end,
    (array(select unnest(case cat
        when 'stress' then array['Very anxious before exams and finding it hard to cope.', 'Constant worry about presentations and group work.', 'Feeling overwhelmed by the workload this semester.']
        when 'mood' then array['Feeling low and withdrawn for the past few weeks.', 'Lost interest in things I used to enjoy.', 'Often tearful and tired for no clear reason.']
        when 'academic' then array['Struggling to keep up with deadlines across several courses.', 'Worried about falling behind and failing a module.', 'Cannot balance the project and the lectures.']
        when 'sleep' then array['Waking early most nights and unable to fall back asleep.', 'Only sleeping four or five hours because of noise in the hostel.', 'Sleep pattern is completely upside down in exam weeks.']
        when 'nutrition' then array['Would like advice on eating well on a small allowance.', 'Unintended weight change over the last two months.', 'Want help planning healthier meals in the hostel.']
        when 'activity' then array['Knee pain after running.', 'Back pain from long hours of studying.', 'Would like a safe plan to start exercising again.']
        when 'sexual' then array['Questions about contraception.', 'Would like a confidential health check-up.', 'Need advice about a recent worry.']
        else array['Wants to cut down on smoking.', 'Concerned about drinking more than intended.', 'Would like advice on managing cravings.'] end))
     )[1 + floor(random() * 3)::int],
    case when r_f < .08 and req > now() - interval '45 days' then (array['Review in two weeks.', 'Progress is slow; follow-up session arranged.', 'Consider a medical referral at the next visit.'])[1 + floor(random() * 3)::int]
         else (array['Consultation completed. No further action.', 'Coping plan agreed. No further action.', 'Advice given and written information shared.', 'Referred to the in-house clinic for review.', 'Two sessions held; progress is good.'])[1 + floor(random() * 5)::int] end
  from r2;

  -- The last two weeks: pending, scheduled and follow-up requests the coordinators are working on.
  insert into _r
  select now() - v.ago * interval '1 day' - interval '3 hours', v.cat, students[1 + floor(random() * cardinality(students))::int], v.urg, v.mode, v.st,
         (select id from public.health_professionals where name = v.pro),
         case when v.appt is not null then date_trunc('day', now()) + v.appt * interval '1 day' + v.hh * interval '1 hour' + v.mm * interval '1 minute' end,
         case when v.fu is not null then now() + v.fu * interval '1 day' end, v.reason, v.notes
  from (values
    (0, 'stress', 'urgent', 'In person', 'pending', null, null::int, null::int, null::int, null::int, 'Finding it very hard to cope before final examinations and not sleeping.', ''),
    (1, 'sleep', 'soon', 'Online', 'pending', null, null, null, null, null, 'Waking at 3 am most nights for the last month.', ''),
    (2, 'mood', 'soon', 'In person', 'pending', null, null, null, null, null, 'Feeling low and withdrawn since the start of the semester.', ''),
    (3, 'nutrition', 'routine', 'Online', 'pending', null, null, null, null, null, 'Would like advice on eating well on a hostel budget.', ''),
    (4, 'academic', 'routine', 'In person', 'pending', null, null, null, null, null, 'Struggling to keep up with deadlines across three courses.', ''),
    (5, 'stress', 'soon', 'Phone', 'scheduled', 'Ms. K. Fernando', 1, 10, 0, null, 'Anxious about group presentations.', 'First session. Suggested breathing exercises.'),
    (6, 'activity', 'routine', 'In person', 'scheduled', 'Mr. A. Silva', 2, 14, 30, null, 'Knee pain after running.', ''),
    (7, 'mood', 'urgent', 'In person', 'scheduled', 'Mr. R. Jayasinghe', 1, 15, 0, null, 'Feeling hopeless about final year project.', 'Safety check completed at intake call.'),
    (10, 'nutrition', 'routine', 'Online', 'scheduled', 'Ms. S. Wickramasinghe', 4, 11, 0, null, 'Unintended weight loss over two months.', ''),
    (14, 'stress', 'soon', 'In person', 'followup', 'Ms. K. Fernando', -9, 10, 0, 6, 'Pressure of clinical placement.', 'PHQ-9 moderate. Review in two weeks; consider medical referral.'),
    (14, 'sleep', 'soon', 'Online', 'followup', 'Dr. N. Perera', -8, 16, 0, 9, 'Poor sleep during night shifts at placement.', 'Sleep diary requested. Review after one week of changes.'))
    v(ago, cat, urg, mode, st, pro, appt, hh, mm, fu, reason, notes);

  insert into public.consultation_requests (ref, student_id, category, urgency, mode, status, requested_at, professional_id, scheduled_for, follow_up_by, reason, notes, history)
  select 'CR-' || lpad((row_number() over (order by r.requested_at))::text, 4, '0'), r.student, r.cat, r.urg, r.mode, r.st, r.requested_at, r.pro, r.sched, r.fu, r.reason, r.notes,
    jsonb_build_array(jsonb_build_object('at', r.requested_at, 'text', 'Request received from the student app'))
    || case when r.pro is not null then jsonb_build_array(jsonb_build_object('at', r.requested_at + interval '3 hours',
         'text', 'Scheduled with ' || h.name || ' for ' || to_char(r.sched at time zone 'Asia/Colombo', 'Dy DD Mon HH24:MI'))) else '[]'::jsonb end
    || case when r.st in ('completed', 'followup') then jsonb_build_array(jsonb_build_object('at', r.sched + interval '1 hour',
         'text', case when r.st = 'followup' then 'Consultation completed. Follow-up required by ' || to_char(r.fu at time zone 'Asia/Colombo', 'DD Mon YYYY') else 'Consultation completed' end)) else '[]'::jsonb end
  from _r r left join public.health_professionals h on h.id = r.pro;
end $$;

select status, count(*) from public.consultation_requests group by 1 order by 1;
