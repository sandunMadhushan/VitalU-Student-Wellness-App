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

## Demonstration data

`admin/demo-backend.js` (switch: `DEMO_BACKEND` at the top of the file) answers
the overview, analytics, completion, schedule and anonymous-consultation calls
with generated figures from `demo-data.js`, so every screen tells the same
story. Health insights, Priority needs, Interventions and the consultation
requests are also generated (kept in the browser's `localStorage`). Questionnaire
and Learn always use the real database. Set `DEMO_BACKEND = false` and remove
the demo scripts to go back to live data.

To make them real:

1. Replace `summarize()` in `demo-data.js` with the existing
   `admin_assessment_report` function (add the eight indicators and the
   academic-year / sex breakdowns). Keep the minimum group of five.
2. Store interventions in a table writable only by admins.
3. Store consultation requests in a table with row-level security so that
   reasons and clinical notes are readable only by the assigned health
   professional. The "Viewing as" switch in the sample is only a preview of that
   rule; it does not enforce anything.

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
