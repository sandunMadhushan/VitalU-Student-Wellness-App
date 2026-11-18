# VitalU admin dashboard

A small static web app for the campus health administration. It is deployed
with the student web app by `.github/workflows/web.yml` and served at
`<site>/admin/`. Open `admin/index.html` through any static server to run it
locally (for example `npx serve admin`).

## What admins can do

- **Light and dark themes**: switch with the moon/sun button at the top right.
  The choice is remembered in that browser.
- **Overview**: registered students and participation in each assessment window.
- **Health insights**: prevalence of eight health concerns (overweight and
  obesity, central obesity, breakfast skipping, low fruit and vegetable
  intake, physical inactivity, short sleep, high stress, low mood), trend lines
  across assessment periods, comparison by faculty / academic year / sex, risk
  distributions (nutritional status and others) and participation by faculty.
- **Priority needs**: concerns ranked by how common, how fast rising and how far
  above target they are, with hot-spot faculties and suggested interventions.
- **Interventions**: plan, assign, monitor and evaluate health promotion
  activities against the next periodic assessment.
- **Analytics**: pooled results of the periodic assessment, by window and
  faculty, with a CSV download. Results for groups of fewer than five
  students are never shown.
- **Completion**: which registration numbers have completed each window
  (search by registration number, CSV). Shows participation only, never
  answers or names.
- **Schedule**: open the six-monthly assessment for some or all faculties on
  their own dates (open for 7 days by default). Students get a "coming up"
  and a "now open" notification.
- **Questionnaire**: edit questions, answers and scoring, reorder, add or
  retire questions.
- **Consultations**: anonymous questions from the app, consultation requests
  with appointment scheduling and statuses (Pending, Scheduled, Completed,
  Follow-up Required), and pooled trends in what students ask about.

## Privacy model

Admins never read the `assessments` or `profiles` tables. The dashboard only
calls security-definer functions (`admin_assessment_overview`,
`admin_assessment_report`, `admin_assessment_completion`) that check `public.is_admin()` and return
aggregates. Anonymous consultations are stored with no user id.

## Where the data comes from

Everything comes from the database. Overview, Analytics, Completion, Schedule and
the anonymous questions use the existing admin functions. Health insights,
Priority needs and the intervention results use `admin_health_cells()`: anonymous
counts per period, faculty, academic year and sex, with groups under five
students left out. If that call fails, the screens fall back to a generated set in
`demo-data.js`.

- **Interventions** are rows in `health_interventions` (admins only).
- **Consultation requests** are rows in `consultation_requests`, which nobody
  reads directly. Administrators use the `admin_consult_*` functions and see who
  asked, the concern, the status and the appointment. The reason for the visit and
  the notes are returned only to a signed-in **health professional**, meaning a
  row in `health_professionals` whose `user_id` is that account. To see them
  yourself:

  ```sql
  update public.health_professionals set user_id = (select id from auth.users where email = 'you@example.ac.lk')
  where name = 'Dr. N. Perera';
  ```

### Demonstration students

`supabase/seed/demo_peradeniya_*.sql` creates about 4,300 University of
Peradeniya students (399 to 549 per faculty) with faculty email addresses and
registration numbers in the app's format (`AG/24/041`, `ag24041@agri.pdn.ac.lk`),
seven assessment rounds, health professionals, interventions and about 1,460
consultation requests. Their accounts are tagged
`raw_user_meta_data.demo_seed = 'peradeniya-2026'`. The older test windows that
had no responses (Year End 2026 on 24 Oct and 10 Nov, and the February 2026 faculty
windows labelled "Mid Year 2028") were filled with the same generator.
`demo_peradeniya_cleanup.sql` removes all of it.

## Setup

1. Apply the migrations in `supabase/migrations/` (Supabase dashboard, SQL
   editor, in file-name order, or `supabase db push`).
2. Create the admin's account (they can sign up in the VitalU app, or add the
   user under Authentication in the Supabase dashboard).
3. Grant admin access in the SQL editor:

   ```sql
   insert into public.admin_users (user_id, display_name)
   select id, 'Health administration' from auth.users where email = 'admin@example.ac.lk';
   ```

To remove access, delete the row from `public.admin_users`.

See `docs/periodic-assessment.md` for how the questionnaire, scoring and
scheduling work.
