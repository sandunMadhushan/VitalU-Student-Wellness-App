-- Body shape picked at registration (fat distribution reference).
alter table public.profiles add column if not exists body_shape text
  check (body_shape in ('apple', 'pear', 'hourglass', 'rectangle', 'inverted_triangle'));

-- Diet quality (PDQS) check-ins and manually logged vitals (BP, fasting glucose, triglycerides).
alter table public.tool_results drop constraint if exists tool_results_tool_check;
alter table public.tool_results add constraint tool_results_tool_check
  check (tool = any (array['bmi', 'whr', 'cvd', 'stress', 'psqi', 'ipaq', 'pdqs', 'vitals']));

-- Active Aura replaces Move Maker: a 7-day activity streak.
insert into public.badges (code, title, icon, category, pending_label, description, sort_order)
values ('active_aura', 'Active Aura', 'directions_walk', 'nourish', '7-day streak',
        'Reached your step goal or 30 active minutes seven days in a row.', 15)
on conflict (code) do update set title = excluded.title, pending_label = excluded.pending_label,
  description = excluded.description, sort_order = excluded.sort_order;
delete from public.badges where code = 'move_maker';

create or replace function public.refresh_badges()
 returns setof text
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare uid uuid := auth.uid(); p public.profiles%rowtype; new_codes text[] := '{}';
begin
  if uid is null then return; end if;
  select * into p from public.profiles where id = uid;

  -- Hydration Habit: reached water goal on 3 different days
  if (select count(*) from (select date(logged_at) d, sum(amount_ml) s from public.water_logs where user_id = uid group by 1) x
      where x.s >= coalesce(p.water_goal_ml,2500)) >= 3 then new_codes := new_codes || 'hydration_habit'; end if;
  -- First Assess
  if exists (select 1 from public.assessments where user_id = uid and status='completed') then new_codes := new_codes || 'first_assess'; end if;
  -- Curious Learner: 3 bookmarks or helpful votes
  if (select count(*) from public.article_bookmarks where user_id = uid) + (select count(*) from public.article_helpful where user_id = uid) >= 3 then new_codes := new_codes || 'curious_learner'; end if;
  -- Mindful Breath: completed a stress check
  if exists (select 1 from public.tool_results where user_id = uid and tool='stress') then new_codes := new_codes || 'mindful_breath'; end if;
  -- Nourish Bowl: 10 logged meals
  if (select count(*) from public.meals where user_id = uid and status='logged') >= 10 then new_codes := new_codes || 'nourish_bowl'; end if;
  -- Restful Sleep: 3 nights >= 7h
  if (select count(*) from public.sleep_logs where user_id = uid and extract(epoch from (wake_time-bedtime))/3600 >= 7) >= 3 then new_codes := new_codes || 'restful_sleep'; end if;
  -- Gentle Steps: step goal reached once
  if exists (select 1 from (select activity_date, sum(steps) s from public.activity_logs where user_id = uid group by 1) x where x.s >= coalesce(p.step_goal,8000)) then new_codes := new_codes || 'gentle_steps'; end if;
  -- Heart Minded: completed CVD risk check
  if exists (select 1 from public.tool_results where user_id = uid and tool='cvd') then new_codes := new_codes || 'heart_minded'; end if;
  -- Cycle Harmony: 2 cycles logged
  if (select count(*) from public.menstrual_cycles where user_id = uid) >= 2 then new_codes := new_codes || 'cycle_harmony'; end if;
  -- Campus Stroll: 5 activity logs
  if (select count(*) from public.activity_logs where user_id = uid) >= 5 then new_codes := new_codes || 'campus_stroll'; end if;
  -- Plate Harmony: 5 different food groups in one day
  if exists (select 1 from public.diversity_logs where user_id = uid group by log_date having count(distinct food_group) >= 5) then new_codes := new_codes || 'plate_harmony'; end if;
  -- Exam Refuge: 5 mood reflections
  if (select count(*) from public.mood_logs where user_id = uid) >= 5 then new_codes := new_codes || 'exam_refuge'; end if;

  -- Streak badges: a goal met on consecutive (Sri Lanka) calendar days.
  -- Aqua Achiever: daily water goal, 3 days
  if exists (
    with d as (select (logged_at at time zone 'Asia/Colombo')::date d from public.water_logs where user_id = uid
               group by 1 having sum(amount_ml) >= coalesce(p.water_goal_ml, 2500))
    select 1 from d a join d b on b.d = a.d - 1 join d c on c.d = a.d - 2
  ) then new_codes := new_codes || 'aqua_achiever'; end if;
  -- Rainbow Plate: 5+ food groups a day, 3 days
  if exists (
    with d as (select log_date d from public.diversity_logs where user_id = uid group by 1 having count(distinct food_group) >= 5)
    select 1 from d a join d b on b.d = a.d - 1 join d c on c.d = a.d - 2
  ) then new_codes := new_codes || 'rainbow_plate'; end if;
  -- Active Aura: step goal or 30 active minutes a day, 7 days in a row
  if exists (
    with d as (select activity_date d from public.activity_logs where user_id = uid group by 1
               having sum(steps) >= coalesce(p.step_goal, 8000) or sum(active_minutes) >= 30),
    runs as (select d - (row_number() over (order by d))::int as grp from d)
    select 1 from runs group by grp having count(*) >= 7
  ) then new_codes := new_codes || 'active_aura'; end if;

  return query
  with ins as (
    insert into public.user_badges (user_id, badge_code)
    select uid, c from unnest(new_codes) c
    on conflict do nothing
    returning badge_code
  ), notif as (
    insert into public.notifications (user_id, category, label, title, body, icon, route)
    select uid, 'milestone', 'Milestone', 'New Milestone Unlocked',
           'You earned the ' || b.title || ' badge! Great mindful pacing and body care.', b.icon, '/milestones'
    from ins join public.badges b on b.code = ins.badge_code
    returning 1
  )
  select badge_code from ins;
end; $function$;
