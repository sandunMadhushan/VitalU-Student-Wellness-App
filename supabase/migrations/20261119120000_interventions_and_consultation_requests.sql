-- Intervention planning and consultation management for the admin dashboard.
--
--  * health_interventions: health promotion activities planned for a priority
--    need. Admins read and write them directly (row-level security).
--  * health_professionals: counsellors, medical officers, dietitians and
--    physiotherapists who can be booked. user_id links one to a sign-in; that
--    person is a "health professional" for the purpose below.
--  * consultation_requests: named requests with appointments. The table has NO
--    policies, so nobody reads it directly. Administrators use the admin_consult_*
--    functions, which return who asked, the concern, the status and the
--    appointment, but return the reason for the visit and the notes ONLY to a
--    signed-in health professional. Notes can only be written by one.

create table if not exists public.health_interventions (
  id uuid primary key default gen_random_uuid(),
  title text not null check (length(title) between 3 and 160),
  indicator text not null check (indicator in ('overweight_obese', 'central_obesity', 'skip_breakfast', 'low_fruit_veg', 'inactive', 'short_sleep', 'high_stress', 'low_mood')),
  faculties text[] not null default '{}',
  owner text not null,
  unit text,
  start_date date not null,
  end_date date not null check (end_date >= start_date),
  status text not null default 'planned' check (status in ('planned', 'running', 'completed', 'hold')),
  target_pts numeric not null default 5 check (target_pts > 0),
  baseline_period text not null,
  milestones jsonb not null default '[]'::jsonb,
  notes text,
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.health_interventions enable row level security;
drop policy if exists health_interventions_admin on public.health_interventions;
create policy health_interventions_admin on public.health_interventions for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
drop trigger if exists health_interventions_updated_at on public.health_interventions;
create trigger health_interventions_updated_at before update on public.health_interventions
  for each row execute function public.set_updated_at();

create table if not exists public.health_professionals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users(id) on delete set null,
  name text not null,
  role text not null check (role in ('Counsellor', 'Medical Officer', 'Dietitian', 'Physiotherapist')),
  unit text,
  active boolean not null default true
);
alter table public.health_professionals enable row level security;
drop policy if exists health_professionals_admin on public.health_professionals;
create policy health_professionals_admin on public.health_professionals for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

create or replace function public.is_health_professional()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.health_professionals where user_id = auth.uid() and active);
$$;
revoke execute on function public.is_health_professional() from public, anon;
grant execute on function public.is_health_professional() to authenticated;

create table if not exists public.consultation_requests (
  id uuid primary key default gen_random_uuid(),
  ref text not null unique,
  student_id uuid not null references auth.users(id) on delete cascade,
  category text not null check (category in ('stress', 'mood', 'academic', 'sleep', 'nutrition', 'activity', 'sexual', 'substance')),
  urgency text not null default 'routine' check (urgency in ('routine', 'soon', 'urgent')),
  mode text not null default 'In person' check (mode in ('In person', 'Online', 'Phone')),
  status text not null default 'pending' check (status in ('pending', 'scheduled', 'completed', 'followup')),
  requested_at timestamptz not null default now(),
  professional_id uuid references public.health_professionals(id) on delete set null,
  scheduled_for timestamptz,
  follow_up_by timestamptz,
  reason text,   -- restricted: health professionals only
  notes text,    -- restricted: health professionals only
  history jsonb not null default '[]'::jsonb
);
create index if not exists consultation_requests_status_idx on public.consultation_requests (status, requested_at desc);
create index if not exists consultation_requests_requested_idx on public.consultation_requests (requested_at);
alter table public.consultation_requests enable row level security;  -- no policies on purpose

create or replace function public.admin_consult_requests()
returns table (id uuid, ref text, student_name text, registration_number text, faculty text, academic_year text, year_of_study int,
               category text, urgency text, mode text, status text, requested_at timestamptz, professional_id uuid, scheduled_for timestamptz,
               follow_up_by timestamptz, reason text, notes text, history jsonb, restricted boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare pro boolean := public.is_health_professional();
begin
  if not public.is_admin() then raise exception 'not authorised' using errcode = '42501'; end if;
  return query
  select r.id, r.ref, p.full_name, p.registration_number, p.faculty, p.academic_year,
         case when p.academic_year ~ '^\d\d/\d\d'
              then least(4, greatest(1, extract(year from now())::int - (2000 + substr(p.academic_year, 4, 2)::int) + 1)) end,
         r.category, r.urgency, r.mode, r.status, r.requested_at, r.professional_id, r.scheduled_for, r.follow_up_by,
         case when pro then r.reason end, case when pro then r.notes end, r.history, not pro
  from public.consultation_requests r
  join public.profiles p on p.id = r.student_id
  where r.status <> 'completed' or r.requested_at > now() - interval '60 days'
  order by r.requested_at desc;
end;
$$;

create or replace function public.admin_consult_schedule(p_id uuid, p_pro uuid, p_when timestamptz, p_mode text)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare r public.consultation_requests%rowtype; pr public.health_professionals%rowtype; clash timestamptz; followup boolean;
begin
  if not public.is_admin() then raise exception 'not authorised' using errcode = '42501'; end if;
  select * into r from public.consultation_requests where id = p_id;
  if not found then raise exception 'request not found'; end if;
  select * into pr from public.health_professionals where id = p_pro and active;
  if not found then raise exception 'unknown health professional'; end if;
  if p_when <= now() then raise exception 'choose a time in the future'; end if;
  if p_mode not in ('In person', 'Online', 'Phone') then raise exception 'unknown mode'; end if;
  select x.scheduled_for into clash from public.consultation_requests x
   where x.id <> p_id and x.professional_id = p_pro and x.status = 'scheduled' and abs(extract(epoch from x.scheduled_for - p_when)) < 1800 limit 1;
  if clash is not null then
    raise exception '% already has an appointment at %', pr.name, to_char(clash at time zone 'Asia/Colombo', 'Dy DD Mon HH24:MI');
  end if;
  followup := r.history::text ilike '%completed%';
  update public.consultation_requests set professional_id = p_pro, scheduled_for = p_when, mode = p_mode, status = 'scheduled', follow_up_by = null,
    history = history || jsonb_build_array(jsonb_build_object('at', now(),
      'text', case when followup then 'Follow-up booked with ' else 'Scheduled with ' end || pr.name || ' for ' || to_char(p_when at time zone 'Asia/Colombo', 'Dy DD Mon HH24:MI')))
  where id = p_id;
end;
$$;

create or replace function public.admin_consult_complete(p_id uuid, p_follow_up timestamptz default null, p_notes text default null)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then raise exception 'not authorised' using errcode = '42501'; end if;
  update public.consultation_requests set
    status = case when p_follow_up is not null then 'followup' else 'completed' end,
    follow_up_by = p_follow_up,
    notes = case when public.is_health_professional() and p_notes is not null then left(p_notes, 4000) else notes end,
    history = history || jsonb_build_array(jsonb_build_object('at', now(),
      'text', case when p_follow_up is not null
                   then 'Consultation completed. Follow-up required by ' || to_char(p_follow_up at time zone 'Asia/Colombo', 'DD Mon YYYY')
                   else 'Consultation completed' end))
  where id = p_id;
  if not found then raise exception 'request not found'; end if;
end;
$$;

create or replace function public.admin_consult_save_notes(p_id uuid, p_notes text)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then raise exception 'not authorised' using errcode = '42501'; end if;
  if not public.is_health_professional() then raise exception 'only a health professional can write notes' using errcode = '42501'; end if;
  update public.consultation_requests set notes = left(p_notes, 4000) where id = p_id;
end;
$$;

-- Pooled monthly counts by concern and faculty. Faculty cells under five are returned as null.
create or replace function public.admin_consult_trends()
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
    'months', (
      select coalesce(jsonb_agg(jsonb_build_object('m', to_char(mo, 'YYYY-MM'), 'label', to_char(mo, 'Mon'), 'counts', coalesce(c.counts, '{}'::jsonb)) order by mo), '[]'::jsonb)
      from generate_series(date_trunc('month', now()) - interval '11 months', date_trunc('month', now()), interval '1 month') mo
      left join lateral (
        select jsonb_object_agg(category, n) as counts
        from (select r.category, count(*) as n from public.consultation_requests r where date_trunc('month', r.requested_at) = mo group by 1) x) c on true),
    'by_faculty', (
      select coalesce(jsonb_object_agg(faculty, cats), '{}'::jsonb)
      from (select faculty, jsonb_object_agg(category, case when n < 5 then null else n end) as cats
            from (select p.faculty, r.category, count(*) as n
                  from public.consultation_requests r join public.profiles p on p.id = r.student_id
                  where r.requested_at > now() - interval '6 months' and p.faculty is not null group by 1, 2) x
            group by faculty) y)
  ) into result;
  return result;
end;
$$;

do $$
declare f text;
begin
  foreach f in array array['admin_consult_requests()', 'admin_consult_schedule(uuid, uuid, timestamptz, text)', 'admin_consult_complete(uuid, timestamptz, text)',
                           'admin_consult_save_notes(uuid, text)', 'admin_consult_trends()'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
