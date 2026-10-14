# VitalU admin dashboard

A small static web app for the campus health administration. It is deployed
with the student web app by `.github/workflows/web.yml` and served at
`<site>/admin/`. Open `admin/index.html` through any static server to run it
locally (for example `npx serve admin`).

## What admins can do

- **Overview**: registered students and participation in each assessment window.
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
- **Consultations**: read and reply to anonymous questions sent from the app.

## Privacy model

Admins never read the `assessments` or `profiles` tables. The dashboard only
calls security-definer functions (`admin_assessment_overview`,
`admin_assessment_report`, `admin_assessment_completion`) that check `public.is_admin()` and return
aggregates. Anonymous consultations are stored with no user id.

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
