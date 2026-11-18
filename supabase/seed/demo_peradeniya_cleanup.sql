-- Removes everything created by the demo_peradeniya_* scripts.
-- Deleting the auth users cascades to their profiles, assessments and
-- consultation requests. Windows that already existed (for example your test
-- windows) are left in place, only emptied of the demo responses.

delete from auth.users where raw_user_meta_data ->> 'demo_seed' = 'peradeniya-2026';

delete from public.assessment_windows
where faculty is null
  and term in ('Mid Year Assessment 2024', 'Year End Assessment 2024', 'Mid Year Assessment 2025', 'Year End Assessment 2025', 'Mid Year Assessment 2026')
  and not exists (select 1 from public.assessments a where a.window_id = assessment_windows.id);

delete from public.anon_consultations
where code in ('VU-7K2Q9', 'VU-3M8TX', 'VU-9D4LP', 'VU-5R1ZH', 'VU-2B6NC', 'VU-8W3YF', 'VU-6H5GA', 'VU-1T9KE');

delete from public.health_interventions
where title in ('Healthy Plate weeks and subsidised fruit stalls', 'Campus Move 30: lunchtime activity breaks', 'Peer-led stress management workshops',
                'Hostel breakfast clubs', 'Sleep hygiene awareness campaign');

delete from public.health_professionals
where name in ('Ms. K. Fernando', 'Mr. R. Jayasinghe', 'Dr. N. Perera', 'Dr. M. Rajapaksa', 'Ms. S. Wickramasinghe', 'Mr. A. Silva') and user_id is null;

drop schema if exists demo_seed cascade;
