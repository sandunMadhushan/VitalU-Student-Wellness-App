-- Pilot evaluation form (evaluation/ website).
--
-- Anyone with the link can submit the anonymous form; only the research team
-- can read the answers. Campus administrators (public.admin_users) do not get
-- access: the answers are read through their own allow-list,
-- public.feedback_viewers, and never appear in the admin dashboard.
--
-- Nothing in this table identifies a person: no user id, email or IP address
-- is stored, only the role chosen on the form and the answers.

create table if not exists public.pilot_feedback (
  id uuid primary key default gen_random_uuid(),
  submitted_at timestamptz not null default now(),
  role text not null check (role in ('student', 'lecturer', 'admin')),
  link_group text,
  form_version int not null default 1,
  answers jsonb not null
);
alter table public.pilot_feedback enable row level security;
-- No policies on purpose: nobody reads or writes the table directly. The
-- functions below are the only way in.

create table if not exists public.feedback_viewers (
  user_id uuid primary key references auth.users(id) on delete cascade,
  note text,
  created_at timestamptz not null default now()
);
alter table public.feedback_viewers enable row level security;
drop policy if exists feedback_viewers_self_read on public.feedback_viewers;
create policy feedback_viewers_self_read on public.feedback_viewers for select to authenticated
  using ((select auth.uid()) = user_id);

create or replace function public.is_feedback_viewer()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.feedback_viewers where user_id = auth.uid());
$$;
revoke execute on function public.is_feedback_viewer() from public, anon;
grant execute on function public.is_feedback_viewer() to authenticated;

-- Submit one anonymous response. Validates the shape so the table only holds
-- real form submissions.
create or replace function public.submit_pilot_feedback(p_role text, p_group text, p_answers jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_role not in ('student', 'lecturer', 'admin') then
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

-- Every response, for the research team only.
create or replace function public.pilot_feedback_responses()
returns setof public.pilot_feedback
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_feedback_viewer() then
    raise exception 'not authorised' using errcode = '42501';
  end if;
  return query select * from public.pilot_feedback order by submitted_at desc;
end;
$$;
revoke execute on function public.pilot_feedback_responses() from public, anon;
grant execute on function public.pilot_feedback_responses() to authenticated;

-- To give someone access (run in the Supabase SQL editor):
--   1. If their email is not a faculty email, allow it to sign up:
--        insert into public.email_allowlist (email, note) values ('you@example.com', 'feedback viewer');
--   2. Create the user in Authentication > Users > Add user (email and password).
--   3. Grant access:
--        insert into public.feedback_viewers (user_id, note)
--        select id, 'researcher' from auth.users where email = 'you@example.com';
