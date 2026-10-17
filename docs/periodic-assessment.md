# Periodic health assessment: how the form is built and managed

This guide explains how the VitalU periodic health assessment works: how the
form is put together, how to change it, how to schedule it for each faculty,
how answers are scored, and what the administration can and cannot see.

It is written for the research team and the campus health administration who
run the assessment. No programming is needed for day-to-day use; everything is
done from the admin dashboard (`<site>/admin/`).

---

## 1. The idea in one paragraph

Twice a year (a **Mid Year Assessment** and a **Year End Assessment**), each
faculty's students are asked to complete a short (about 7 minutes)
health questionnaire in the app. It covers the ten health domains plus an
optional **clinical measurements** section. The form is not hard-coded: it is
stored in the database as **domains** (topic areas) and **questions**, so the
administration can edit wording, answers and scoring without releasing a new
app version. Each round of the assessment is a **window** that opens for a
faculty on a chosen date and stays open for a set number of days. Results are
only ever shown to the administration as **pooled totals**, never per
student, and nothing at all is shown for a group of fewer than five students.

What the student sees:

- **Home alert.** While a window is open, the assessment pops up once on Home
  as an important notice ("Open from 12 Jan to 19 Jan"), and a card stays on
  Home until it is done.
- **Introduction before starting.** It says the assessment comes from the
  university health administration. It explains why it matters: the risk
  picture for young adults in Sri Lanka, citing STEPS 2021 and a Peradeniya
  student study. It promises that answers are used only as a pooled overall
  picture with no personal identifiers, to plan future health and nutrition
  interventions.
- **A light, visual form.** It shows one question per screen with tap-to-answer
  cards. Food questions show a photo, define one serving and use a 7-day
  days picker. There are mood faces and an illustrated activity slider.
  Answers animate as they are picked, and progress is saved after every
  answer.

The full question list, with every answer option, is in
[assessment-questionnaire.md](assessment-questionnaire.md).

---

## 2. How the form is structured

```
Assessment form
├── Domain 1  Physical and cardiometabolic health
│   ├── Question p_profile  (profile check: confirm details already given)
│   ├── Question p_general  (1 to 5 scale, scored)
│   └── ...
├── Domain 2  Dietary behaviours and food security
│   └── ...
├── Domain 10 Student voice and institutional priorities
└── Domain 11 Clinical measurements (can be hidden by the admin)
    ├── Question k_source   (were they measured at the health centre?)
    ├── Question k_height   (number, cm, prefilled, asked only if measured)
    └── ...
```

### 2.1 Domains

A domain is a section of the form. The app shows one progress dot per domain,
and each domain gets its own score out of 100.

| Field      | Meaning                                              |
|------------|------------------------------------------------------|
| `id`       | Number that identifies the domain (1, 2, 3 …)        |
| `title`    | Shown as the section heading                         |
| `blurb`    | One line shown under the heading                     |
| `icon`     | Material Symbols icon name, e.g. `restaurant`        |
| `position` | Order in the form                                    |
| `active`   | Hidden sections are skipped by the app (see 4)       |

The default domains:

1. Physical and cardiometabolic health
2. Dietary behaviours and food security
3. Academic workload and time pressure
4. Emotional well-being and stress
5. Sleep and daily routines
6. Physical activity and sedentary behaviour
7. Financial and living conditions
8. Social environment and personal support
9. Campus environment and access to services
10. Student voice and institutional priorities
11. Clinical measurements (height, weight, waist, hip, blood pressure,
    fasting glucose, triglycerides, cholesterol). Students enter their own
    values. The first question asks whether they were measured at the
    university health centre (or elsewhere, or by themselves). Students who
    answer "I don't have recent measurements" skip the rest of the section.

### 2.2 Questions

Each question belongs to one domain.

| Field         | Meaning |
|---------------|---------|
| `id`          | Short unique code, e.g. `d_breakfast`. **Never reuse or rename an id once students have answered it**, because past answers are stored against it. |
| `domain_id`   | Which domain it belongs to |
| `position`    | Order inside the domain |
| `kind`        | `single`, `multi`, `scale`, `number`, `text` or `profile` (see 2.3) |
| `style`       | How a `single` question is drawn: `days`, `faces`, `slider` or empty for cards (see 2.3) |
| `image`       | Optional picture above the question, a path under `assets/` (e.g. `food_groups/fruit.webp`) |
| `show_if`     | Ask only when an earlier answer allows it, e.g. `{"q": "k_source", "not_in": ["none"]}` |
| `text`        | The question as students see it |
| `help`        | Optional hint under the question |
| `options`     | The answer choices (for `single`, `multi`, `scale`) |
| `unit`, `min_value`, `max_value` | For `number` questions, e.g. `cm`, 100 to 230 |
| `max_choices` | For `multi`, the most a student may pick (e.g. "pick up to three") |
| `prefill`     | Fills the answer from the profile or latest logged vitals: `height_cm`, `weight_kg`, `waist_cm`, `hip_cm`, `sbp`, `dbp`, `fbg`, `tg`, `chol`, `accommodation`. Measured values update the profile when the student finishes. |
| `optional`    | Students may skip it |
| `active`      | Retired questions are kept (for past results) but no longer asked |

### 2.3 Question kinds

| Kind     | What the student sees | Stored answer | Scored? |
|----------|------------------------|---------------|---------|
| `single` | Tap one answer; the form moves on automatically | the option `value`, e.g. `"5-7"` | Yes, if options have scores |
| `scale`  | Five buttons from 1 to 5 | `"1"` … `"5"` | Yes |
| `multi`  | Tick several answers | a list, e.g. `["hours","privacy"]` | No (described only) |
| `number` | Number field with unit and range check | a number, e.g. `162.5` | No (used for BMI and WHR) |
| `text`   | Short free-text box | text | No |
| `profile`| A summary of the student's profile (age, sex, faculty, family history, medicines, allergies) to confirm or update, so these are not asked again | `"same"` or `"updated"` | No |

Styles for `single` questions:

| Style    | Looks like | Used for |
|----------|------------|----------|
| (empty)  | Large answer cards, with an icon or picture if the option has one | Most questions |
| `days`   | Food photo, a "one serving is…" line and a 0 to 7 days picker | 7-day food recall |
| `faces`  | A row of animated faces from sad to happy | Mood, sleep quality |
| `slider` | Illustrated slider; the picture changes as it moves (option `image`) | Active days |

### 2.4 Answer options and scores

Options are a list of `value`, `label`, and optional `hint`, `score`,
`icon` (a Material Symbols name) and `image` (a path under `assets/`):

```json
[
  {"value": "0-1", "label": "0 to 1 days", "hint": "Usually skip it", "score": 0},
  {"value": "2-4", "label": "2 to 4 days", "hint": "Depends on lectures", "score": 1},
  {"value": "5-7", "label": "5 to 7 days", "hint": "Most mornings", "score": 2}
]
```

Two rules keep scoring consistent:

- **A higher score always means a healthier answer.** For a question where
  "often" is unhealthy (for example skipping meals), "often" gets 0.
- **Leave `score` empty for descriptive questions** (for example "Where do you
  live?"). They are reported as counts but do not affect any score.

The `value` is what is stored, so keep values short and never change the
`value` of an option that has already been answered; change the `label`
instead.

---

## 3. How answers are scored

Scoring happens in the app when a student finishes
(`lib/features/assessments/assessment_data.dart`, `scoreAssessment`).

1. **Each scored question** is turned into a 0 to 1 fraction:
   `option score ÷ highest score available for that question`.
   Example: "2 to 4 days" scores 1 out of a possible 2 → 0.5.
2. **Domain score (0 to 100)** = the average of that domain's fractions × 100.
   Skipped and unscored questions are left out, so they do not pull the score
   down.
3. **Overall well-being (0 to 100)** = the average of the domain scores.
4. **Result label** shown to the student:

   | Overall | Label |
   |---------|-------|
   | 75 to 100 | Healthy habits |
   | 55 to 74  | Mostly on track |
   | 35 to 54  | Room to improve |
   | below 35  | Needs attention |

5. **Extra measures** worked out from specific questions:
   - **BMI** from `k_height` and `k_weight`, or from the profile when the
     clinical section is hidden or skipped (`bmi_source` records which:
     `health_centre`, `clinic`, `self` or `profile`)
   - **Waist-to-hip ratio** from `k_waist` and `k_hip` (or the profile)
   - **PHQ-2** from `e_phq1` and `e_phq2`, 0 to 6 (Kroenke et al., 2003).
     A total of **3 or more** is a positive screen for low mood
     (`phq2_positive`). It is a screen, not a diagnosis, and students with a
     positive screen are shown where to get support.

The answers and scores are saved together in the student's `assessments` row.
Progress is saved after each answer, so a student can close the app and
continue later while the window is open.

> If you add, remove or rescore questions between rounds, domain scores from
> different rounds are no longer exactly comparable. For research comparisons
> over time, keep the scored questions fixed for the whole study and add new
> questions as unscored ones.

---

## 4. Creating or changing the form (admin dashboard)

Open the dashboard, sign in with an admin account and go to **Questionnaire**.

### Edit a question
1. Find it under its domain and click **Edit**.
2. Change the wording, help text, options, labels or scores.
3. Save. The change applies to anyone who opens the assessment afterwards.

### Add a question
1. Click **Add question** in the domain.
2. Choose the kind, write the question and give it a short unique id with
   the domain's prefix (`p_`, `d_`, `a_`, `e_`, `s_`, `m_`, `f_`, `o_`, `c_`,
   `v_`, `k_`), e.g. `d_water`.
3. Add options and scores (higher = healthier), or leave scores empty.
4. Save, then use the ↑ and ↓ buttons to put it in the right place.

### Retire a question
Click **Retire** instead of deleting it. It disappears from the form but past
answers stay in the reports. **Restore** brings it back.

### Rename a domain
Click **Rename area** next to the domain heading.

### Show or hide a whole section
Click **Hide section** next to the domain heading (and **Show section** to
bring it back). Use this for **Clinical measurements** when the health centre
has not measured the students in a round. The app then skips the section and
uses the profile values for BMI and waist-to-hip ratio.

### Good practice for wording
- One idea per question, in plain English (and keep a Sinhala/Tamil
  translation if one is used in the study).
- Give a time frame: "in the past month", "on a typical day".
- Make answer options cover every case and not overlap
  (e.g. "0 to 1", "2 to 4", "5 to 7").
- Use validated items unchanged where possible (the PHQ-2 items are taken
  from the Patient Health Questionnaire; do not reword them).
- For food questions, say what one serving is and ask about the last 7 days.
- Free-text questions should say "please do not include names".

### The app's built-in copy
The app ships with the same default questionnaire
(`assets/assessment/questionnaire.json`). It is only used if the database
cannot be reached. Once the database has questions, the database version is
always used.

The default questionnaire is kept in one file,
`supabase/seed/assessment_questionnaire.json`. After changing it, run
`python supabase/seed/build_questionnaire.py`. This regenerates three files:
the app's copy, the seed SQL and the readable
[assessment-questionnaire.md](assessment-questionnaire.md).

---

## 5. Scheduling an assessment round

Go to **Schedule** in the dashboard.

1. Pick the **round** (**Mid Year Assessment** or **Year End Assessment**)
   and the **year**. Together they name the round (e.g. "Mid Year Assessment
   2027"), which is how rounds are grouped in reports.
2. Pick the **faculties**. Leave all unticked to open it for everyone.
   Each faculty gets its own window, so faculties can have different dates.
3. Pick the **opening date and time** (Sri Lanka time) and how many **days**
   it stays open (1 to 31, 7 by default). The next suggested date is six
   months after the last round.
4. Save.

What happens next, automatically:

- Every eligible student gets a **"coming up"** notification three days
  before opening and a **"now open"** notification on the day.
- While it is open, the assessment pops up on the student's Home screen as an
  important alert with its open and close dates, and a card stays on Home
  until it is completed.
- Students who registered after a window opened can still complete it while
  it is open.

A window can be deleted only if no student has started it; its unsent
notifications are deleted with it.

---

## 6. What the administration can see

| Tab | Shows | Does not show |
|-----|-------|---------------|
| **Overview** | Number of registered students by faculty; for each window, eligible / in progress / completed counts | Any names or answers |
| **Analytics** | Pooled results: overall and domain averages, BMI categories, answer percentages per question, number summaries (mean, median, middle half), shuffled free-text comments, CSV download | Results for any group under 5 students (the whole report is hidden until 5 have completed) |
| **Completion** | Which **registration numbers** have completed, started or not started each window, with the date completed; search by registration number; CSV | Answers, scores, names or emails |
| **Questionnaire** | The form, for editing | – |
| **Consultations** | Anonymous questions from students and replies | Who sent them |

How this is enforced: admins have no direct read access to the
`assessments` or `profiles` tables. The dashboard can only call database
functions (`admin_assessment_overview`, `admin_assessment_report`,
`admin_assessment_completion`) that check the caller is an admin and return
only the data listed above.

---

## 7. Setting it up

1. **Apply the database migrations** in `supabase/migrations/`, in file-name
   order (Supabase dashboard → SQL editor, or `supabase db push`). The ones
   needed for the assessment and dashboard are:
   - `20261014120100_periodic_assessment_admin.sql` (form tables, windows,
     analytics, consultations, default questionnaire)
   - `20261015120000_diet_profile_completion_email_domains.sql` (Completion
     tab, faculty email domains)
   - `20261016120000_assessment_v2_badges_learn_admin.sql` (this version of
     the questionnaire, section hide switch, Mid Year / Year End rounds)
2. **Create the admin's account** (sign up in the app, or add the user under
   Authentication in Supabase).
3. **Grant admin access** in the SQL editor:

   ```sql
   insert into public.admin_users (user_id, display_name)
   select id, 'Health administration' from auth.users where email = 'admin@example.ac.lk';
   ```

   Remove the row to take access away.
4. Because sign-up is limited to faculty emails (`@agri.pdn.ac.lk`,
   `@eng.pdn.ac.lk` …), an admin or tester with another address must be
   allowed first:

   ```sql
   insert into public.email_allowlist (email, note) values ('admin@example.ac.lk', 'Health centre admin');
   ```

---

## 8. Data model reference

| Table | Holds |
|-------|-------|
| `assessment_domains` | The form's sections |
| `assessment_questions` | The questions, options and scores |
| `assessment_windows` | Each round: title, term, faculty (or all), opens and closes |
| `assessments` | One row per student per window: `answers` (JSON), `scores` (JSON), `status` (`in_progress` / `completed`), `completed_at` |
| `admin_users` | Who can use the dashboard |

`scores` looks like:

```json
{"domains": {"1": 72, "2": 58, "...": 0}, "overall": 66, "bmi": 22.4, "bmi_source": "health_centre", "whr": 0.81, "phq2": 1, "phq2_positive": false}
```

---

## 9. Limitations to keep in mind

- Answers are **self-reported**, so they are subject to recall and
  social-desirability bias.
- Domain scores are a VitalU summary for comparing groups and rounds; they
  are not clinical cut-offs or diagnoses.
- Participation is voluntary, so the students who respond may not represent
  the whole faculty. Report the response rate (Overview) with every result.
- Changing scored questions mid-study breaks comparability (see section 3).
