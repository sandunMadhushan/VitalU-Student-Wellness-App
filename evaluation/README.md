# VitalU pilot evaluation site

A small standalone website for the post-pilot evaluation:

| Page | Who it is for |
|------|---------------|
| `index.html` | Everyone: what VitalU is, and a button to the form |
| `form.html` | Undergraduates, lecturers and administration: the anonymous feedback form |
| `researcher.html` | The research team only: responses, summary and CSV export |

The questions, codes and analysis plan are in [docs/pilot-evaluation-form.md](../docs/pilot-evaluation-form.md). `questions.js` holds the same questions as data, so the form and the CSV always match.

Plain HTML, CSS and JavaScript with no build step. It uses the same Supabase project as the app.

## Privacy

- The form stores no name, email, registration number, user id or IP address.
- Responses are saved through `submit_pilot_feedback()` and read only through `pilot_feedback_responses()`.
- Only accounts in `public.feedback_viewers` can read them. Campus administrators (`public.admin_users`) cannot, and responses never appear in the admin dashboard.

## Set up

1. **Database.** Apply `supabase/migrations/20261019130000_pilot_feedback.sql`, for example with `supabase db push` or by pasting it into the Supabase SQL editor.
2. **Your researcher account.** In the Supabase SQL editor, replace the email and run:

   ```sql
   -- Only needed if the email is not a faculty (pdn.ac.lk) address.
   insert into public.email_allowlist (email, note) values ('you@example.com', 'feedback viewer');
   ```

   Then create the user in **Authentication > Users > Add user** with an email and password, and grant access:

   ```sql
   insert into public.feedback_viewers (user_id, note)
   select id, 'researcher' from auth.users where email = 'you@example.com';
   ```

3. **Sign in** at `researcher.html` with that email and password.

## Links to send

Send one link per group, so you can tell where responses came from. The role is pre-selected but can still be changed.

- Undergraduates: `.../evaluation/form.html?g=student`
- Lecturers: `.../evaluation/form.html?g=lecturer`
- Administration: `.../evaluation/form.html?g=admin`

Or send the home page, `.../evaluation/`, which explains the app and links to the form.

## Hosting

- The GitHub Pages workflow copies this folder to `/evaluation/` on the existing site.
- To host it on its own domain instead, upload this folder as-is to any static host (Netlify, Vercel, Cloudflare Pages). No build step is needed.

## Export

On `researcher.html`, **Download CSV** gives one row per response, oldest first, with the columns in the codebook:
- multi-select answers as 0/1 columns
- `sus_score` already calculated
- blank cells for questions not shown, skipped, or answered "did not use"

The file opens in Excel, jamovi, SPSS, R or Python. Use the filter to export one group only.
