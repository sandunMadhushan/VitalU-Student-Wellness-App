-- Diet section rework, profile details, assessment completion tracking and
-- university email restriction. Run after the two 20261014 migrations.

-- ---------------------------------------------------------------------------
-- Profile: accommodation details
-- ---------------------------------------------------------------------------

alter table public.profiles add column if not exists accommodation text
  check (accommodation in ('hostel', 'boarding', 'home', 'other'));

-- ---------------------------------------------------------------------------
-- Meals: the individual foods in a logged meal, from the shared food
-- database (name, portion, kcal, MDD-W groups and PDQS groups), so diet
-- quality can be estimated from meal logs.
-- ---------------------------------------------------------------------------

alter table public.meals add column if not exists items jsonb not null default '[]'::jsonb;

-- ---------------------------------------------------------------------------
-- Smart Eater: 7 days in a row with breakfast, lunch and dinner logged and at
-- least 5 of the 10 MDD-W food groups. It rewards regular, varied eating,
-- never a calorie deficit.
-- ---------------------------------------------------------------------------

insert into public.badges (code, title, icon, category, pending_label, description, sort_order)
values ('smart_eater', 'Smart Eater', 'restaurant', 'nourish', '7-day streak',
        'Logged breakfast, lunch and dinner, eating from 5 or more food groups, seven days in a row.', 16)
on conflict (code) do update set title = excluded.title, pending_label = excluded.pending_label,
  description = excluded.description, sort_order = excluded.sort_order;

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

  if (select count(*) from (select date(logged_at) d, sum(amount_ml) s from public.water_logs where user_id = uid group by 1) x
      where x.s >= coalesce(p.water_goal_ml,2500)) >= 3 then new_codes := new_codes || 'hydration_habit'; end if;
  if exists (select 1 from public.assessments where user_id = uid and status='completed') then new_codes := new_codes || 'first_assess'; end if;
  if (select count(*) from public.article_bookmarks where user_id = uid) + (select count(*) from public.article_helpful where user_id = uid) >= 3 then new_codes := new_codes || 'curious_learner'; end if;
  if exists (select 1 from public.tool_results where user_id = uid and tool='stress') then new_codes := new_codes || 'mindful_breath'; end if;
  if (select count(*) from public.meals where user_id = uid and status='logged') >= 10 then new_codes := new_codes || 'nourish_bowl'; end if;
  if (select count(*) from public.sleep_logs where user_id = uid and extract(epoch from (wake_time-bedtime))/3600 >= 7) >= 3 then new_codes := new_codes || 'restful_sleep'; end if;
  if exists (select 1 from (select activity_date, sum(steps) s from public.activity_logs where user_id = uid group by 1) x where x.s >= coalesce(p.step_goal,8000)) then new_codes := new_codes || 'gentle_steps'; end if;
  if exists (select 1 from public.tool_results where user_id = uid and tool='cvd') then new_codes := new_codes || 'heart_minded'; end if;
  if (select count(*) from public.menstrual_cycles where user_id = uid) >= 2 then new_codes := new_codes || 'cycle_harmony'; end if;
  if (select count(*) from public.activity_logs where user_id = uid) >= 5 then new_codes := new_codes || 'campus_stroll'; end if;
  if exists (select 1 from public.diversity_logs where user_id = uid group by log_date having count(distinct food_group) >= 5) then new_codes := new_codes || 'plate_harmony'; end if;
  if (select count(*) from public.mood_logs where user_id = uid) >= 5 then new_codes := new_codes || 'exam_refuge'; end if;

  -- Aqua Achiever: daily water goal, 3 days in a row
  if exists (
    with d as (select (logged_at at time zone 'Asia/Colombo')::date d from public.water_logs where user_id = uid
               group by 1 having sum(amount_ml) >= coalesce(p.water_goal_ml, 2500))
    select 1 from d a join d b on b.d = a.d - 1 join d c on c.d = a.d - 2
  ) then new_codes := new_codes || 'aqua_achiever'; end if;
  -- Rainbow Plate: 5+ food groups a day, 3 days in a row
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
  -- Smart Eater: breakfast, lunch and dinner logged and 5+ food groups, 7 days in a row
  if exists (
    with meals_ok as (
      select meal_date d from public.meals where user_id = uid and status = 'logged'
      group by 1 having count(distinct meal_type) filter (where meal_type in ('breakfast', 'lunch', 'dinner')) = 3),
    groups_ok as (select log_date d from public.diversity_logs where user_id = uid group by 1 having count(distinct food_group) >= 5),
    d as (select m.d from meals_ok m join groups_ok g on g.d = m.d),
    runs as (select d - (row_number() over (order by d))::int as grp from d)
    select 1 from runs group by grp having count(*) >= 7
  ) then new_codes := new_codes || 'smart_eater'; end if;

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

-- ---------------------------------------------------------------------------
-- Assessment completion, for administrators: who has completed which
-- window, by registration number. Completion status only. Answers, scores
-- and any other health information are never returned.
-- ---------------------------------------------------------------------------

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
    on p.onboarding_completed and (w.faculty is null or p.faculty = w.faculty)
  left join public.assessments a on a.window_id = w.id and a.user_id = p.id
  where (p_window is null or w.id = p_window)
    and (p_registration is null or upper(p.registration_number) like '%' || upper(trim(p_registration)) || '%')
  order by w.opens_at desc, p.registration_number;
end;
$$;
revoke execute on function public.admin_assessment_completion(uuid, text) from public, anon;
grant execute on function public.admin_assessment_completion(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Only University of Peradeniya faculty email addresses can create an
-- account. Administrators and testers with other addresses are added to
-- email_allowlist first. Existing accounts are not affected.
-- ---------------------------------------------------------------------------

create table if not exists public.allowed_email_domains (
  domain text primary key,
  faculty text not null
);
alter table public.allowed_email_domains enable row level security;
drop policy if exists allowed_email_domains_read on public.allowed_email_domains;
create policy allowed_email_domains_read on public.allowed_email_domains for select to anon, authenticated using (true);

insert into public.allowed_email_domains (domain, faculty) values
  ('agri.pdn.ac.lk', 'Faculty of Agriculture'),
  ('arts.pdn.ac.lk', 'Faculty of Arts'),
  ('eng.pdn.ac.lk', 'Faculty of Engineering'),
  ('mgt.pdn.ac.lk', 'Faculty of Management'),
  ('sci.pdn.ac.lk', 'Faculty of Science'),
  ('ahs.pdn.ac.lk', 'Faculty of Allied Health Sciences'),
  ('med.pdn.ac.lk', 'Faculty of Medicine'),
  ('dental.pdn.ac.lk', 'Faculty of Dental Sciences'),
  ('vet.pdn.ac.lk', 'Faculty of Veterinary Medicine and Animal Science')
on conflict (domain) do update set faculty = excluded.faculty;

create table if not exists public.email_allowlist (
  email text primary key,
  note text
);
alter table public.email_allowlist enable row level security;

create or replace function public.enforce_university_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.email is null
     or exists (select 1 from public.allowed_email_domains d where lower(split_part(new.email, '@', 2)) = d.domain)
     or exists (select 1 from public.email_allowlist a where lower(a.email) = lower(new.email)) then
    return new;
  end if;
  raise exception 'Please use your University of Peradeniya faculty email address.' using errcode = '22023';
end;
$$;

drop trigger if exists enforce_university_email on auth.users;
create trigger enforce_university_email before insert on auth.users
  for each row execute function public.enforce_university_email();

-- New students: set their faculty from their email domain.
create or replace function public.handle_new_user()
 returns trigger
 language plpgsql
 security definer
 set search_path to ''
as $function$
begin
  insert into public.profiles (id, email, full_name, faculty)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
          (select d.faculty from public.allowed_email_domains d where d.domain = lower(split_part(new.email, '@', 2))));
  return new;
end; $function$;
