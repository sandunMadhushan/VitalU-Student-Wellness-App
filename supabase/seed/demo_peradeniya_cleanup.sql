-- Removes everything created by demo_peradeniya_1_students.sql and
-- demo_peradeniya_2_assessments.sql (and the demo anonymous questions).
-- Deleting the auth users cascades to their profiles and assessments.

delete from auth.users where raw_user_meta_data ->> 'demo_seed' = 'peradeniya-2026';

delete from public.assessment_windows
where faculty is null
  and term in ('Mid Year Assessment 2024', 'Year End Assessment 2024', 'Mid Year Assessment 2025', 'Year End Assessment 2025', 'Mid Year Assessment 2026')
  and not exists (select 1 from public.assessments a where a.window_id = assessment_windows.id);

delete from public.anon_consultations
where code in ('VU-7K2Q9', 'VU-3M8TX', 'VU-9D4LP', 'VU-5R1ZH', 'VU-2B6NC', 'VU-8W3YF', 'VU-6H5GA', 'VU-1T9KE');

drop schema if exists demo_seed cascade;
