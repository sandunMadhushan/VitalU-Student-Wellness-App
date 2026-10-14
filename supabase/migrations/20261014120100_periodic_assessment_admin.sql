-- Periodic (six-monthly) health assessment run by the campus administration:
-- admin accounts, an admin-editable questionnaire, faculty-specific
-- assessment windows, pooled (anonymous, groups of 5+) analytics, and
-- anonymous consultations with the university health centre.

-- ---------------------------------------------------------------------------
-- Admin accounts
-- ---------------------------------------------------------------------------

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now()
);
alter table public.admin_users enable row level security;
drop policy if exists admin_users_self_read on public.admin_users;
create policy admin_users_self_read on public.admin_users for select to authenticated
  using ((select auth.uid()) = user_id);

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.admin_users where user_id = auth.uid());
$$;
revoke execute on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- ---------------------------------------------------------------------------
-- Questionnaire (domains and questions), editable by admins
-- ---------------------------------------------------------------------------

create table if not exists public.assessment_domains (
  id int primary key,
  title text not null,
  blurb text,
  icon text not null default 'assignment',
  position int not null default 0
);
alter table public.assessment_domains enable row level security;
drop policy if exists assessment_domains_read on public.assessment_domains;
create policy assessment_domains_read on public.assessment_domains for select to authenticated using (true);
drop policy if exists assessment_domains_admin on public.assessment_domains;
create policy assessment_domains_admin on public.assessment_domains for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

-- options: [{"value": "...", "label": "...", "hint": "...", "score": 0..n | null}]
-- A higher option score always means a healthier answer; null = not scored.
create table if not exists public.assessment_questions (
  id text primary key,
  domain_id int not null references public.assessment_domains(id) on update cascade,
  position int not null default 0,
  kind text not null check (kind in ('single', 'multi', 'scale', 'number', 'text')),
  text text not null,
  help text,
  options jsonb not null default '[]'::jsonb,
  unit text,
  min_value numeric,
  max_value numeric,
  max_choices int,
  prefill text check (prefill in ('height_cm', 'weight_kg', 'waist_cm', 'hip_cm')),
  optional boolean not null default false,
  active boolean not null default true,
  updated_at timestamptz not null default now()
);
create index if not exists assessment_questions_domain_idx on public.assessment_questions (domain_id, position);
alter table public.assessment_questions enable row level security;
drop policy if exists assessment_questions_read on public.assessment_questions;
create policy assessment_questions_read on public.assessment_questions for select to authenticated
  using (active or (select public.is_admin()));
drop policy if exists assessment_questions_admin_insert on public.assessment_questions;
create policy assessment_questions_admin_insert on public.assessment_questions for insert to authenticated
  with check ((select public.is_admin()));
drop policy if exists assessment_questions_admin_update on public.assessment_questions;
create policy assessment_questions_admin_update on public.assessment_questions for update to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
drop policy if exists assessment_questions_admin_delete on public.assessment_questions;
create policy assessment_questions_admin_delete on public.assessment_questions for delete to authenticated
  using ((select public.is_admin()));

drop trigger if exists assessment_questions_updated_at on public.assessment_questions;
create trigger assessment_questions_updated_at before update on public.assessment_questions
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Assessment windows: admins schedule them per faculty
-- ---------------------------------------------------------------------------

alter table public.assessment_windows alter column estimated_minutes set default 6;

drop policy if exists assessment_windows_admin_insert on public.assessment_windows;
create policy assessment_windows_admin_insert on public.assessment_windows for insert to authenticated
  with check ((select public.is_admin()));
drop policy if exists assessment_windows_admin_update on public.assessment_windows;
create policy assessment_windows_admin_update on public.assessment_windows for update to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
drop policy if exists assessment_windows_admin_delete on public.assessment_windows;
create policy assessment_windows_admin_delete on public.assessment_windows for delete to authenticated
  using ((select public.is_admin()));

-- Creates one window per faculty (or one for everyone when p_faculties is
-- empty) and schedules each eligible student's "coming up" and "now open"
-- notifications. Admins cannot otherwise write to students' notifications.
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

-- Removes a window that nobody has started, together with its scheduled,
-- not yet delivered notifications.
create or replace function public.admin_delete_assessment_window(p_window uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then raise exception 'not authorised' using errcode = '42501'; end if;
  if exists (select 1 from public.assessments where window_id = p_window) then
    raise exception 'students have already started this assessment';
  end if;
  delete from public.notifications n
  using public.assessment_windows w
  where w.id = p_window and n.route = '/assessments' and n.read_at is null and n.scheduled_for > now()
    and n.body like '%' || w.term || '%';
  delete from public.assessment_windows where id = p_window;
end;
$$;
revoke execute on function public.admin_delete_assessment_window(uuid) from public, anon;
grant execute on function public.admin_delete_assessment_window(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Pooled analytics. Admins never read assessment rows or profiles directly:
-- only these aggregates, and nothing at all for groups smaller than five.
-- ---------------------------------------------------------------------------

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
        'eligible', (select count(*) from public.profiles p where p.onboarding_completed and (w.faculty is null or p.faculty = w.faculty))
      ) order by w.opens_at desc), '[]'::jsonb)
      from public.assessment_windows w)
  ) into result;
  return result;
end;
$$;
revoke execute on function public.admin_assessment_overview() from public, anon;
grant execute on function public.admin_assessment_overview() to authenticated;

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
    'questions', questions
  ) into result;
  return result;
end;
$$;
revoke execute on function public.admin_assessment_report(uuid, text, text) from public, anon;
grant execute on function public.admin_assessment_report(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Anonymous consultations with the university health centre. Rows carry no
-- user id: the student keeps a ticket code to read the reply.
-- ---------------------------------------------------------------------------

create table if not exists public.anon_consultations (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  topic text not null,
  message text not null check (length(message) between 5 and 2000),
  urgency text not null default 'routine' check (urgency in ('routine', 'soon', 'urgent')),
  status text not null default 'open' check (status in ('open', 'answered', 'closed')),
  reply text,
  replied_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.anon_consultations enable row level security;
drop policy if exists anon_consultations_admin_read on public.anon_consultations;
create policy anon_consultations_admin_read on public.anon_consultations for select to authenticated
  using ((select public.is_admin()));
drop policy if exists anon_consultations_admin_update on public.anon_consultations;
create policy anon_consultations_admin_update on public.anon_consultations for update to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

create or replace function public.submit_anon_consultation(p_topic text, p_message text, p_urgency text default 'routine')
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare c text;
begin
  if auth.uid() is null then raise exception 'sign in first' using errcode = '42501'; end if;
  loop
    c := 'VU-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
    exit when not exists (select 1 from public.anon_consultations where code = c);
  end loop;
  insert into public.anon_consultations (code, topic, message, urgency)
  values (c, left(trim(p_topic), 80), trim(p_message), coalesce(p_urgency, 'routine'));
  return c;
end;
$$;
revoke execute on function public.submit_anon_consultation(text, text, text) from public, anon;
grant execute on function public.submit_anon_consultation(text, text, text) to authenticated;

create or replace function public.anon_consultations_by_codes(p_codes text[])
returns table (code text, topic text, message text, urgency text, status text, reply text, replied_at timestamptz, created_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select c.code, c.topic, c.message, c.urgency, c.status, c.reply, c.replied_at, c.created_at
  from public.anon_consultations c
  where c.code = any (p_codes[1:50])
  order by c.created_at desc;
$$;
revoke execute on function public.anon_consultations_by_codes(text[]) from public, anon;
grant execute on function public.anon_consultations_by_codes(text[]) to authenticated;

-- ---------------------------------------------------------------------------
-- Default questionnaire: ten domains, short tap-to-answer questions.
-- ---------------------------------------------------------------------------

insert into public.assessment_domains (id, title, blurb, icon, position) values
  (1, 'Physical and cardiometabolic health', 'Your body measurements and general health.', 'monitor_heart', 1),
  (2, 'Dietary behaviours and food security', 'What and how regularly you eat.', 'restaurant', 2),
  (3, 'Academic workload and time pressure', 'How study fits around the rest of life.', 'school', 3),
  (4, 'Emotional well-being and stress', 'How you have been feeling lately.', 'psychology', 4),
  (5, 'Sleep and daily routines', 'Rest and the rhythm of your days.', 'bedtime', 5),
  (6, 'Physical activity and sedentary behaviour', 'Moving and sitting through the week.', 'directions_walk', 6),
  (7, 'Financial and living conditions', 'Where you stay and how money affects health.', 'savings', 7),
  (8, 'Social environment and personal support', 'The people around you.', 'diversity_3', 8),
  (9, 'Campus environment and access to services', 'Food, spaces and health services on campus.', 'local_hospital', 9),
  (10, 'Student voice and institutional priorities', 'What the university should do next.', 'campaign', 10)
on conflict (id) do nothing;

insert into public.assessment_questions (id, domain_id, position, kind, text, help, options, unit, min_value, max_value, max_choices, prefill, optional) values
  ('p_height', 1, 1, 'number', 'What is your height?', 'We filled this in from your profile. Change it if it is out of date.', '[]', 'cm', 100, 230, null, 'height_cm', true),
  ('p_weight', 1, 2, 'number', 'What is your weight?', 'A recent reading is perfect.', '[]', 'kg', 25, 250, null, 'weight_kg', true),
  ('p_waist', 1, 3, 'number', 'What is your waist measurement?', 'Measure midway between your lowest rib and hip bone, after breathing out.', '[]', 'cm', 40, 200, null, 'waist_cm', true),
  ('p_hip', 1, 4, 'number', 'What is your hip measurement?', 'Measure around the widest part of your hips.', '[]', 'cm', 50, 200, null, 'hip_cm', true),
  ('p_general', 1, 5, 'scale', 'How would you rate your overall physical health right now?', null,
    '[{"value":"1","label":"Poor","score":0},{"value":"2","label":"Fair","score":1},{"value":"3","label":"Good","score":2},{"value":"4","label":"Very good","score":3},{"value":"5","label":"Excellent","score":4}]', null, null, null, null, null, false),
  ('p_conditions', 1, 6, 'multi', 'Has a doctor ever told you that you have any of these?', 'Select all that apply.',
    '[{"value":"high_bp","label":"High blood pressure"},{"value":"diabetes","label":"Diabetes or prediabetes"},{"value":"cholesterol","label":"High cholesterol"},{"value":"asthma","label":"Asthma"},{"value":"anaemia","label":"Anaemia"},{"value":"thyroid","label":"Thyroid condition"},{"value":"pcos","label":"PCOS"},{"value":"none","label":"None of these"}]', null, null, null, null, null, false),
  ('p_checkup', 1, 7, 'single', 'When did you last have your blood pressure or blood sugar checked?', null,
    '[{"value":"6m","label":"Within the last 6 months","score":3},{"value":"12m","label":"6 to 12 months ago","score":2},{"value":"older","label":"More than a year ago","score":1},{"value":"never","label":"Never, or not sure","score":0}]', null, null, null, null, null, false),

  ('d_breakfast', 2, 1, 'single', 'How many days a week do you eat breakfast?', null,
    '[{"value":"0-1","label":"0 to 1 days","hint":"Usually skip it","score":0},{"value":"2-4","label":"2 to 4 days","hint":"Depends on lectures","score":1},{"value":"5-7","label":"5 to 7 days","hint":"Most mornings","score":2}]', null, null, null, null, null, false),
  ('d_fruitveg', 2, 2, 'single', 'On a typical day, how many servings of fruit and vegetables do you eat?', 'One serving is about a handful, or a small bowl of mallum.',
    '[{"value":"0-1","label":"0 to 1 servings","score":0},{"value":"2-3","label":"2 to 3 servings","score":1},{"value":"4","label":"4 servings","score":2},{"value":"5+","label":"5 or more servings","score":3}]', null, null, null, null, null, false),
  ('d_sugary', 2, 3, 'single', 'How many sugary drinks do you have a day?', 'Soft drinks, sweet milk tea or coffee, packet juice.',
    '[{"value":"0","label":"None","score":2},{"value":"1","label":"1 a day","score":1},{"value":"2+","label":"2 or more a day","score":0}]', null, null, null, null, null, false),
  ('d_fried', 2, 4, 'single', 'How often do you eat fried or fast food?', 'Short eats, kottu, fried rice, instant noodles, burgers.',
    '[{"value":"rare","label":"Rarely","hint":"Less than once a week","score":3},{"value":"1-2","label":"1 to 2 times a week","score":2},{"value":"3-5","label":"3 to 5 times a week","score":1},{"value":"daily","label":"Almost every day","score":0}]', null, null, null, null, null, false),
  ('d_skip_money', 2, 5, 'single', 'In the past month, did you skip meals or eat less because money was short?', null,
    '[{"value":"never","label":"Never","score":3},{"value":"once","label":"Once or twice","score":2},{"value":"sometimes","label":"Sometimes","score":1},{"value":"often","label":"Often","score":0}]', null, null, null, null, null, false),

  ('a_load', 3, 1, 'scale', 'How manageable is your academic workload right now?', null,
    '[{"value":"1","label":"Very hard","score":0},{"value":"2","label":"Hard","score":1},{"value":"3","label":"Okay","score":2},{"value":"4","label":"Manageable","score":3},{"value":"5","label":"Very manageable","score":4}]', null, null, null, null, null, false),
  ('a_tradeoff', 3, 2, 'single', 'How often do deadlines make you skip meals, sleep or exercise?', null,
    '[{"value":"never","label":"Never","score":3},{"value":"sometimes","label":"Sometimes","score":2},{"value":"often","label":"Often","score":1},{"value":"always","label":"Almost always","score":0}]', null, null, null, null, null, false),
  ('a_breaks', 3, 3, 'single', 'Do you take short breaks while studying?', null,
    '[{"value":"regularly","label":"Regularly","score":2},{"value":"sometimes","label":"Sometimes","score":1},{"value":"rarely","label":"Rarely","score":0}]', null, null, null, null, null, false),

  ('e_mood', 4, 1, 'scale', 'Overall, how has your mood been over the past two weeks?', null,
    '[{"value":"1","label":"Very low","score":0},{"value":"2","label":"Low","score":1},{"value":"3","label":"Okay","score":2},{"value":"4","label":"Good","score":3},{"value":"5","label":"Great","score":4}]', null, null, null, null, null, false),
  ('e_pss1', 4, 2, 'single', 'In the last month, how often have you felt unable to control the important things in your life?', null,
    '[{"value":"0","label":"Never","score":4},{"value":"1","label":"Almost never","score":3},{"value":"2","label":"Sometimes","score":2},{"value":"3","label":"Fairly often","score":1},{"value":"4","label":"Very often","score":0}]', null, null, null, null, null, false),
  ('e_pss2', 4, 3, 'single', 'In the last month, how often have you felt confident about handling your personal problems?', null,
    '[{"value":"0","label":"Never","score":0},{"value":"1","label":"Almost never","score":1},{"value":"2","label":"Sometimes","score":2},{"value":"3","label":"Fairly often","score":3},{"value":"4","label":"Very often","score":4}]', null, null, null, null, null, false),
  ('e_pss3', 4, 4, 'single', 'In the last month, how often have you felt that things were going your way?', null,
    '[{"value":"0","label":"Never","score":0},{"value":"1","label":"Almost never","score":1},{"value":"2","label":"Sometimes","score":2},{"value":"3","label":"Fairly often","score":3},{"value":"4","label":"Very often","score":4}]', null, null, null, null, null, false),
  ('e_pss4', 4, 5, 'single', 'In the last month, how often have difficulties piled up so high that you could not overcome them?', null,
    '[{"value":"0","label":"Never","score":4},{"value":"1","label":"Almost never","score":3},{"value":"2","label":"Sometimes","score":2},{"value":"3","label":"Fairly often","score":1},{"value":"4","label":"Very often","score":0}]', null, null, null, null, null, false),

  ('s_hours', 5, 1, 'single', 'On average, how many hours do you sleep a night?', null,
    '[{"value":"<5","label":"Less than 5 hours","score":0},{"value":"5-6","label":"5 to 6 hours","score":1},{"value":"7-8","label":"7 to 8 hours","score":3},{"value":"9+","label":"9 hours or more","score":2}]', null, null, null, null, null, false),
  ('s_quality', 5, 2, 'single', 'How would you rate your sleep quality this month?', null,
    '[{"value":"very_good","label":"Very good","score":3},{"value":"fairly_good","label":"Fairly good","score":2},{"value":"fairly_bad","label":"Fairly bad","score":1},{"value":"very_bad","label":"Very bad","score":0}]', null, null, null, null, null, false),
  ('s_regular', 5, 3, 'single', 'Do you go to bed and wake up at about the same times most days?', null,
    '[{"value":"mostly","label":"Mostly, yes","score":2},{"value":"sometimes","label":"Sometimes","score":1},{"value":"rarely","label":"Rarely","score":0}]', null, null, null, null, null, false),

  ('m_active_days', 6, 1, 'single', 'In the last 7 days, on how many days were you active for at least 30 minutes?', 'Brisk walking, sport, gym, cycling or dancing all count.',
    '[{"value":"0","label":"0 days","score":0},{"value":"1-2","label":"1 to 2 days","score":1},{"value":"3-4","label":"3 to 4 days","score":2},{"value":"5-7","label":"5 to 7 days","score":3}]', null, null, null, null, null, false),
  ('m_getting_around', 6, 2, 'single', 'How do you usually get around campus?', null,
    '[{"value":"walk","label":"Mostly walk or cycle","score":2},{"value":"mix","label":"A mix of walking and transport","score":1},{"value":"vehicle","label":"Mostly bus, three-wheeler or vehicle","score":0}]', null, null, null, null, null, false),
  ('m_sitting', 6, 3, 'single', 'On a typical weekday, how many hours do you spend sitting?', 'Lectures, studying, travel and screen time together.',
    '[{"value":"<6","label":"Less than 6 hours","score":2},{"value":"6-9","label":"6 to 9 hours","score":1},{"value":"10+","label":"10 hours or more","score":0}]', null, null, null, null, null, false),

  ('f_living', 7, 1, 'single', 'Where do you live during the semester?', null,
    '[{"value":"hostel","label":"University hostel"},{"value":"boarding","label":"Boarding or rented room"},{"value":"home","label":"At home with family"},{"value":"other","label":"Somewhere else"}]', null, null, null, null, null, false),
  ('f_money', 7, 2, 'single', 'How often do money worries affect your food, transport or health choices?', null,
    '[{"value":"never","label":"Never","score":3},{"value":"sometimes","label":"Sometimes","score":2},{"value":"often","label":"Often","score":1},{"value":"always","label":"Almost always","score":0}]', null, null, null, null, null, false),
  ('f_water', 7, 3, 'single', 'Can you easily get safe drinking water where you stay?', null,
    '[{"value":"always","label":"Always","score":2},{"value":"mostly","label":"Mostly","score":1},{"value":"rarely","label":"Rarely","score":0}]', null, null, null, null, null, false),

  ('o_talk', 8, 1, 'single', 'Do you have someone you can talk to when things get hard?', null,
    '[{"value":"always","label":"Yes, always","score":2},{"value":"sometimes","label":"Sometimes","score":1},{"value":"no","label":"Not really","score":0}]', null, null, null, null, null, false),
  ('o_lonely', 8, 2, 'single', 'How often do you feel lonely on campus?', null,
    '[{"value":"never","label":"Never","score":3},{"value":"rarely","label":"Rarely","score":2},{"value":"sometimes","label":"Sometimes","score":1},{"value":"often","label":"Often","score":0}]', null, null, null, null, null, false),
  ('o_groups', 8, 3, 'single', 'Do you take part in clubs, sports, societies or cultural groups?', null,
    '[{"value":"regularly","label":"Regularly","score":2},{"value":"occasionally","label":"Occasionally","score":1},{"value":"no","label":"Not at all","score":0}]', null, null, null, null, null, false),

  ('c_food', 9, 1, 'scale', 'How easy is it to find healthy, affordable food on campus?', null,
    '[{"value":"1","label":"Very hard","score":0},{"value":"2","label":"Hard","score":1},{"value":"3","label":"Okay","score":2},{"value":"4","label":"Easy","score":3},{"value":"5","label":"Very easy","score":4}]', null, null, null, null, null, false),
  ('c_spaces', 9, 2, 'scale', 'How suitable are campus spaces for walking or exercise?', null,
    '[{"value":"1","label":"Very poor","score":0},{"value":"2","label":"Poor","score":1},{"value":"3","label":"Okay","score":2},{"value":"4","label":"Good","score":3},{"value":"5","label":"Very good","score":4}]', null, null, null, null, null, false),
  ('c_health_centre', 9, 3, 'single', 'Have you used the university health centre this academic year?', null,
    '[{"value":"yes","label":"Yes"},{"value":"no_need","label":"No, I did not need to"},{"value":"no_barrier","label":"No, I needed to but did not go"}]', null, null, null, null, null, false),
  ('c_barriers', 9, 4, 'multi', 'What makes it hard to use campus health services?', 'Select all that apply.',
    '[{"value":"unaware","label":"Not sure what is offered"},{"value":"hours","label":"Opening hours"},{"value":"waiting","label":"Waiting time"},{"value":"privacy","label":"Privacy worries"},{"value":"distance","label":"Distance or transport"},{"value":"uncomfortable","label":"Feeling uncomfortable asking"},{"value":"none","label":"Nothing, it is easy"}]', null, null, null, null, null, false),

  ('v_priorities', 10, 1, 'multi', 'Pick up to three things the university should prioritise for student health.', null,
    '[{"value":"canteen","label":"Healthier canteen food"},{"value":"affordable","label":"Affordable meals"},{"value":"mental","label":"Mental health and counselling"},{"value":"fitness","label":"Sports and fitness facilities"},{"value":"water","label":"Drinking water stations"},{"value":"schedule","label":"Better exam and study scheduling"},{"value":"screening","label":"Regular health screenings"},{"value":"hostels","label":"Safer, cleaner hostels"},{"value":"education","label":"Health workshops and education"}]', null, null, null, 3, null, false),
  ('v_idea', 10, 2, 'text', 'One change that would make student life healthier (optional)', 'Please do not include names or anything that could identify you.', '[]', null, null, null, null, null, true)
on conflict (id) do nothing;
