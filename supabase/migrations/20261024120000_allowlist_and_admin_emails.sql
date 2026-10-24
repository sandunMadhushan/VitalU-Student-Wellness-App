-- Non-university emails that may sign up, and admin access granted by email.
--
-- admin_emails lets an admin account be deleted and created again (for
-- example to go through student sign-up from scratch) without losing admin
-- dashboard access: when a user signs up with a listed email, they are added
-- to admin_users automatically.

insert into public.email_allowlist (email, note) values
  ('parindya2109@gmail.com', 'research team'),
  ('iranthicooray77@gmail.com', 'research team'),
  ('oviniwijesooriya@aiesec.net', 'research team')
on conflict (email) do nothing;

create table if not exists public.admin_emails (
  email text primary key check (email = lower(email)),
  note text,
  created_at timestamptz not null default now()
);
alter table public.admin_emails enable row level security;
-- No policies: only the database itself (and the SQL editor) reads it.

insert into public.admin_emails (email, note) values
  ('fst20052@agri.pdn.ac.lk', 'student researcher')
on conflict (email) do nothing;

create or replace function public.grant_admin_by_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.email is not null and exists (select 1 from public.admin_emails a where a.email = lower(new.email)) then
    insert into public.admin_users (user_id) values (new.id) on conflict (user_id) do nothing;
  end if;
  return new;
end;
$$;
revoke execute on function public.grant_admin_by_email() from public, anon, authenticated;

drop trigger if exists grant_admin_by_email on auth.users;
create trigger grant_admin_by_email after insert on auth.users
  for each row execute function public.grant_admin_by_email();

-- Existing accounts with a listed email.
insert into public.admin_users (user_id)
select u.id from auth.users u join public.admin_emails a on a.email = lower(u.email)
on conflict (user_id) do nothing;
