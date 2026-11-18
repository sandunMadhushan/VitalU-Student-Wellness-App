-- DEMONSTRATION DATA (step 1 of 2): about 4,300 University of Peradeniya
-- students across the nine faculties, plus five past all-faculty assessment
-- windows. Every user carries raw_user_meta_data.demo_seed = 'peradeniya-2026'
-- so demo_peradeniya_cleanup.sql can remove all of it. Run as the project owner
-- (the SQL editor); triggers are bypassed for this transaction only, because
-- the demo accounts use non-routable @seed.vitalu.invalid addresses.

create schema if not exists demo_seed;

create or replace function demo_seed.elt(arr text[]) returns text language sql volatile as
$$ select arr[1 + floor(random() * array_length(arr, 1))::int] $$;

create or replace function demo_seed.pick(vals text[], w float8[]) returns text language plpgsql volatile as $$
declare r float8 := random() * (select sum(x) from unnest(w) x); acc float8 := 0; i int;
begin
  for i in 1 .. array_length(vals, 1) loop
    acc := acc + w[i];
    if r <= acc then return vals[i]; end if;
  end loop;
  return vals[array_length(vals, 1)];
end $$;

create or replace function demo_seed.norm(mu float8, sd float8) returns float8 language sql volatile as
$$ select mu + sd * sqrt(-2 * ln(1 - random())) * cos(2 * pi() * random()) $$;

create or replace function demo_seed.first_name(eth int, sex text) returns text language sql volatile as $$
  select demo_seed.elt(case
    when eth = 1 and sex = 'female' then array['Nethmi','Sanduni','Thilini','Dilini','Hansika','Kavindi','Ishara','Oshadi','Chamodi','Sachini','Madushi','Nimasha','Tharushi','Pavithra','Rashmi','Dinithi','Sewwandi','Imesha','Anushka','Wasana','Gayani','Hiruni','Yashodha','Lakshika','Maleesha','Udari','Piumi','Sithara','Amaya','Nadeesha']
    when eth = 1 then array['Kavindu','Dineth','Hasitha','Lahiru','Pasindu','Thisara','Nuwan','Chamath','Sandun','Buddhika','Isuru','Ravindu','Dilshan','Tharindu','Supun','Malith','Janith','Shehan','Yasiru','Kasun','Gimhan','Sachith','Vishwa','Dasun','Nipun','Charith','Ashen','Pubudu','Hirantha','Damith']
    when eth = 2 and sex = 'female' then array['Sharmila','Kavitha','Thanuja','Priyanka','Abirami','Nirosha','Sivaranjani','Kiruthika','Vaishnavi','Tharani','Mathumitha','Janani']
    when eth = 2 then array['Karthik','Sathish','Arun','Pirabakaran','Kishore','Thushyanthan','Vithushan','Ahilan','Sajeevan','Nilaxan','Thevan','Mayuran']
    when sex = 'female' then array['Fathima','Nusrath','Aaminah','Zahra','Ayesha','Shifna','Rishana','Safna','Hana','Mariyam']
    else array['Mohamed','Rizwan','Imran','Aadil','Fazil','Shakir','Ashraf','Naushad','Irfan','Ramzan'] end) $$;

create or replace function demo_seed.last_name(eth int) returns text language sql volatile as $$
  select demo_seed.elt(case
    when eth = 1 then array['Perera','Fernando','Silva','Jayawardena','Wijesekara','Gunasekara','Rajapaksha','Senanayake','Weerasinghe','Dissanayake','Amarasinghe','Ranasinghe','Bandara','Herath','Jayasinghe','Samarasinghe','Karunaratne','Wickramasinghe','Abeysekara','Gamage','Liyanage','Ekanayake','Rathnayake','Kumara','Hettiarachchi','Pathirana','Seneviratne','Gunawardena','Alwis','Madushanka']
    when eth = 2 then array['Thavarajah','Sivakumar','Rajendran','Selvarajah','Nadarajah','Kandasamy','Balasingham','Ratnam','Sathananthan','Vijayakumar']
    else array['Nazeer','Hameed','Cassim','Marikar','Rahuman','Lebbe','Jaleel','Farook','Ismail','Mohideen'] end) $$;

-- Students -------------------------------------------------------------------
drop table if exists demo_seed.students;
create table demo_seed.students as
with raw as materialized (
  select f, gen_random_uuid() as id,
         demo_seed.pick(array['2023','2024','2025','2026'], array[.23,.25,.26,.26]::float8[])::int as intake,
         case when random() < (array[.55,.70,.72,.65,.30,.62,.60,.58,.58])[f] then 'female' else 'male' end as sex,
         case when random() < .82 then 1 when random() < .55 then 2 else 3 end as eth,
         random() as r_b
  from (select f, generate_series(1, (array[487,436,541,398,524,503,462,549,417])[f]) as i from generate_series(1, 9) f) x
),
named as materialized (
  select raw.*, demo_seed.first_name(eth, sex) as first_name, demo_seed.last_name(eth) as last_name,
         row_number() over (partition by f, intake order by random()) as seq,
         row_number() over (order by random()) as gseq
  from raw
)
select id, f, intake, sex, first_name, last_name,
       first_name || ' ' || last_name as full_name,
       left(first_name, 1) || '.' || substr('ABCDGHJKLMNPRSTW', 1 + floor(random() * 16)::int, 1) || '. ' || last_name as name_with_initials,
       (array['AG','AH','AR','DS','E','MG','M','S','V'])[f] || '/' || lpad((intake - 2000)::text, 2, '0') || '/' || lpad(seq::text, 3, '0') as reg,
       lpad((intake - 1 - 2000)::text, 2, '0') || '/' || lpad((intake - 2000)::text, 2, '0') || ' Batch' as academic_year,
       lower(regexp_replace(first_name || last_name, '[^A-Za-z]', '', 'g')) || lpad(gseq::text, 4, '0') as username,
       (make_date(intake - 19, 1, 1) + (floor(random() * 365))::int - case when random() < .25 then 365 else 0 end) as dob,
       (make_date(intake, 2, 1) + (floor(random() * 120))::int)::timestamptz + interval '8 hours' as created_at,
       demo_seed.pick(array['hostel','boarding','home','other'], array[.55,.20,.22,.03]::float8[]) as accommodation,
       demo_seed.pick(array['Moderate Walking (Campus)','Light Walking (Campus)','Mostly sitting','Vigorous (Sports)'], array[.5,.25,.2,.05]::float8[]) as activity_level,
       demo_seed.pick(array['apple','pear','hourglass','rectangle','inverted_triangle'], array[.18,.22,.2,.3,.1]::float8[]) as body_shape,
       random() < .55 as consent
from named;

alter table demo_seed.students add column height numeric, add column weight numeric, add column waist numeric, add column hip numeric;
update demo_seed.students set height = round((case when sex = 'male' then demo_seed.norm(171, 6.5) else demo_seed.norm(158, 5.5) end)::numeric, 1);
update demo_seed.students set weight = round((demo_seed.norm(22.6, 3.4) * power(height / 100, 2))::numeric, 1),
                             hip = round((case when sex = 'male' then demo_seed.norm(91, 5) else demo_seed.norm(94, 6) end)::numeric, 0);
update demo_seed.students set waist = round((hip * case when sex = 'male' then 0.80 + random() * 0.08 else 0.74 + random() * 0.09 end)::numeric, 0);

begin;
set local session_replication_role = replica;

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, confirmation_token, recovery_token,
                        email_change_token_new, email_change, email_change_token_current, phone_change, phone_change_token, reauthentication_token,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at, is_sso_user, is_anonymous)
select '00000000-0000-0000-0000-000000000000', id, 'authenticated', 'authenticated',
       lower(replace(reg, '/', '')) || '@seed.vitalu.invalid', null, created_at, '', '', '', '', '', '', '', '',
       '{"provider":"email","providers":["email"]}'::jsonb,
       jsonb_build_object('demo_seed', 'peradeniya-2026', 'full_name', full_name), created_at, created_at, false, false
from demo_seed.students;

insert into public.profiles (id, full_name, email, date_of_birth, sex, faculty, academic_year, height_cm, weight_kg, waist_cm, hip_cm,
                             activity_level, onboarding_completed, research_consent, registration_number, username, name_with_initials,
                             body_shape, accommodation, measurement_source, measured_at, created_at, updated_at)
select id, full_name, lower(replace(reg, '/', '')) || '@seed.vitalu.invalid', dob, sex,
       (array['Faculty of Agriculture','Faculty of Allied Health Sciences','Faculty of Arts','Faculty of Dental Sciences','Faculty of Engineering',
              'Faculty of Management','Faculty of Medicine','Faculty of Science','Faculty of Veterinary Medicine and Animal Science'])[f],
       academic_year, height, weight, waist, hip, activity_level, true, consent, reg, username, name_with_initials, body_shape, accommodation,
       case when random() < .25 then 'clinic' end, created_at + interval '30 days', created_at, created_at
from demo_seed.students;

-- Five past all-faculty windows (the six-monthly rounds).
insert into public.assessment_windows (title, term, faculty, opens_at, closes_at, estimated_minutes)
select v.title, v.term, null, v.o::timestamptz, v.o::timestamptz + interval '7 days', 6
from (values
  ('Mid Year Health Assessment',  'Mid Year Assessment 2024',  '2024-06-17 08:00+05:30'),
  ('Year End Health Assessment',  'Year End Assessment 2024',  '2024-12-09 08:00+05:30'),
  ('Mid Year Health Assessment',  'Mid Year Assessment 2025',  '2025-06-16 08:00+05:30'),
  ('Year End Health Assessment',  'Year End Assessment 2025',  '2025-12-08 08:00+05:30'),
  ('Mid Year Health Assessment',  'Mid Year Assessment 2026',  '2026-06-15 08:00+05:30')) v(title, term, o)
where not exists (select 1 from public.assessment_windows w where w.term = v.term and w.faculty is null);
commit;

select f, count(*) n from demo_seed.students group by f order by f;
