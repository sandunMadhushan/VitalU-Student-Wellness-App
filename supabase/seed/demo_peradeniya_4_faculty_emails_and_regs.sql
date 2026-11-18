-- DEMONSTRATION DATA (step 4, run after step 1): give every demo student a faculty
-- email address and registration number in the University of Peradeniya format used
-- by the app: AG/24/041 and ag24041@agri.pdn.ac.lk (code / two-digit batch year /
-- three-digit number, and the same characters lower-cased as the email name).
-- Domains come from public.allowed_email_domains; numbers already used by a real
-- (non-demo) account are skipped. Two phases avoid unique-key clashes mid-update.
begin;
create temp table _s on commit drop as
select p.id, array_position(array['Faculty of Agriculture','Faculty of Allied Health Sciences','Faculty of Arts','Faculty of Dental Sciences','Faculty of Engineering',
         'Faculty of Management','Faculty of Medicine','Faculty of Science','Faculty of Veterinary Medicine and Animal Science'], p.faculty) as f,
       2000 + substr(p.academic_year, 4, 2)::int as intake
from public.profiles p join auth.users u on u.id = p.id
where u.raw_user_meta_data ->> 'demo_seed' = 'peradeniya-2026';
create temp table _cfg on commit drop as
select i as f, (array['AG','AH','A','DS','E','MG','M','S','V'])[i] as code, (array['agri','ahs','arts','dental','eng','mgt','med','sci','vet'])[i] || '.pdn.ac.lk' as dom
from generate_series(1, 9) i;
create temp table _num on commit drop as
select g.f, g.intake, n, row_number() over (partition by g.f, g.intake order by random()) as rk
from (select f, intake, count(*) c from _s group by 1, 2) g
cross join lateral generate_series(1, ceil(g.c * 1.4)::int + 20) n
join _cfg c on c.f = g.f
where not exists (select 1 from auth.users u where u.raw_user_meta_data ->> 'demo_seed' is null
                    and lower(u.email) = lower(c.code || lpad((g.intake - 2000)::text, 2, '0') || lpad(n::text, 3, '0') || '@' || c.dom))
  and not exists (select 1 from public.profiles pr where pr.id not in (select id from _s)
                    and upper(pr.registration_number) = upper(c.code || '/' || lpad((g.intake - 2000)::text, 2, '0') || '/' || lpad(n::text, 3, '0')));
create temp table _new on commit drop as
select s.id, c.code || '/' || lpad((s.intake - 2000)::text, 2, '0') || '/' || lpad(nm.n::text, 3, '0') as reg,
       lower(c.code || lpad((s.intake - 2000)::text, 2, '0') || lpad(nm.n::text, 3, '0')) || '@' || c.dom as email
from (select _s.*, row_number() over (partition by f, intake order by random()) as rk from _s) s
join _num nm on nm.f = s.f and nm.intake = s.intake and nm.rk = s.rk
join _cfg c on c.f = s.f;
do $$ begin
  if (select count(*) from _new) <> (select count(*) from _s) then raise exception 'numbering pool too small'; end if;
end $$;
update auth.users u set email = 'tmp-' || u.id || '@seed.vitalu.invalid' where u.id in (select id from _s);
update public.profiles p set email = 'tmp-' || p.id || '@seed.vitalu.invalid', registration_number = 'TMP-' || p.id where p.id in (select id from _s);
update auth.users u set email = n.email, updated_at = now() from _new n where u.id = n.id;
update public.profiles p set email = n.email, registration_number = n.reg from _new n where p.id = n.id;
commit;
