# VitalU — Student Wellness App

VitalU is a Flutter + Supabase mobile app that gives university students a single, private place to
track their physical and mental wellbeing, get AI-assisted help reading their own health data, and stay
connected to campus health support — built around Sri Lankan university life (local emergency numbers,
Sri Lankan rupees, local campus foods, and local academic-year batches).

It started from the concept paper and UI mock-ups in the parent folder and is now a working, installable
Android/iOS app backed by a real Supabase project (Postgres database, Auth, Storage and Edge Functions).

## What problem it solves

University students rarely have one place that pulls together body metrics, mental-health check-ins,
nutrition, sleep, activity and lab results — most of that either lives in someone's head, in scattered
paper reports, or isn't tracked at all. VitalU gives students:

* A private, encrypted "health profile" they own and control.
* Lightweight daily tools instead of clinical-grade trackers, so logging something takes seconds.
* Plain-English AI explanations of things students normally can't interpret themselves (a blood test
  report, a photographed meal).
* A gentle nudge toward campus health services and emergency numbers when they actually need them,
  without turning the app into a diagnostic or clinical tool.

## Key features

### Onboarding & Account
* Splash + onboarding walkthrough, sign up / log in with email+password or Google, and a 3-step guided
  registration (body basics, health background, wellness goals) that seeds the student's profile.
* Light, Dark and System theme modes, picked from the Profile screen and persisted on-device.

### Home
* A daily overview: greeting, today's snapshot (hydration, steps, sleep), a breathing/mindfulness
  exercise, and quick links into the rest of the app.

### Periodic Wellness Assessments
* Term-based self-assessments across six sections — Body Measurements, Nutrition & Eating, Lifestyle &
  Daily Rhythm, Physical Activity, Sleep & Rest, and Stress & Wellbeing — released in scheduled windows
  per term/faculty, with a completion summary at the end.
* With consent, de-identified, faculty-level results (only for groups of 5+ students) can feed a
  read-only research view for the university — anonymous, aggregate, and never reachable from the app
  itself.

### Health Tools
Quick, standalone calculators and trackers: **BMI**, **Waist-Hip Ratio**, **Heart disease risk**,
**Water intake**, **Stress check**, **Activity/step tracking** (device pedometer), **Sleep tracking**,
and a **Menstrual cycle** tracker.

### Diet & Nutrition
* A diet hub with a **visual plate planner** (half veg, quarter grains, quarter protein, plus fruit),
  a **dietary diversity tracker** across 8 food groups, a **meal planner**, a **weekly grocery
  budget planner** (Sri Lankan rupees, shareable list), and **today's nutrition** summary.
* **Snap-to-log meals** — photograph a meal and an AI model estimates the dish, calories, macros and
  which food groups it covers, so logging food doesn't require manual data entry.

### Progress & Motivation
* Trends across all trackers, unlockable milestones/badges for consistent healthy habits, and an
  exportable PDF wellness summary.
* In-app reminders and notifications (hydration, sleep window, check-ins).

### Health Education Library
* Short, student-friendly articles on nutrition, mental health, sleep and preventative care, with
  text-to-speech and share support.

### Blood Report Reader
* Upload a lab report (photo or PDF) to private, encrypted storage; an AI model reads the printed
  values, units and reference ranges and returns a plain-English explanation of what each result means —
  clearly framed as educational, not a diagnosis.

### Support
* One-tap access to Sri Lankan emergency numbers (Suwa Seriya ambulance, NIMH mental-health helpline,
  CCCline), a directory of campus health professionals with booking/chat requests, and an About/FAQ/
  contact section.

### Profile
* A single health record view (BMI/WHR, family history, allergies, medications, conditions, lifestyle
  goals), avatar upload, research-participation consent toggle, appointment history, and account
  settings — all editable and all private to the student by default.

## Privacy & security model

* Every table is protected by Postgres row-level security: a student can only ever read or write their
  own rows; reference/catalogue tables are read-only for everyone.
* Blood reports live in a private per-user storage bucket; avatars live in a public one.
* The only aggregate view of assessment data is a service-role-only analytics view used for anonymised,
  minimum-group-size research reporting — the app itself never has access to other students' data.

## Tech stack

* **Flutter** (Material 3, `go_router` for navigation, custom "Serene Pastel Sanctuary" design system
  with full light/dark theming)
* **Supabase** — Postgres database with RLS, Auth (email + Google OAuth), Storage, and Edge Functions
* **Google Gemini** (via Supabase Edge Functions) for blood-report reading and meal-photo analysis
* Device integrations: pedometer (step counting), image picker, PDF export/printing, share sheet,
  text-to-speech, `url_launcher` for calls/email

## Run it

```bash
flutter pub get
flutter run            # Android device / emulator or iOS simulator
flutter build apk      # Android release build
flutter build web       # Web / PWA build
```

The Supabase URL and publishable key are in `lib/core/config.dart` (project **VitalU**).

## Backend (Supabase project `VitalU`)

* **Database** – profiles, trackers (water, activity, sleep, mood, cycle), diet (meals, diversity, budget
  planner, grocery lists), tool results, periodic assessments & windows, education library, professionals,
  appointments, emergency contacts, notifications, badges and blood reports. Row-level security is on for every
  table: students can only read/write their own rows; catalogue tables are read-only.
* **Research analytics** – `analytics.assessment_faculty_summary` aggregates *only* completed periodic
  assessments of students who gave research consent, by faculty and term, and hides groups smaller than 5.
  It is only reachable with the service-role key (never from the app).
* **Storage** – `blood-reports` (private, per-user folders) and `avatars` (public).
* **Edge Functions**
  * `analyze-blood-report` – reads an uploaded lab report (photo or PDF) with Gemini and stores plain-English
    explanations.
  * `analyze-meal` – "Snap" on the meal log screen; estimates the dish, calories, macros and food groups.

### One-time setup you need to do

1. **Gemini API key** – Supabase Dashboard → Edge Functions → Secrets → add `GEMINI_API_KEY`
   (from Google AI Studio). Optional: `GEMINI_MODEL` (defaults to `gemini-flash-latest`).
2. **Google sign-in** – Authentication → Providers → Google: add your Google OAuth client ID/secret, and add
   `lk.vitalu.app://login-callback` to Authentication → URL Configuration → Redirect URLs.
3. **Email confirmation** – if "Confirm email" is on, new students must verify their email before signing in.
4. **Campus Medical Centre number** – set the `phone` of the *Campus Medical Centre* row in the
   `emergency_contacts` table (left blank on purpose). Professionals' phone/email columns can be filled the same way.
5. **Assessment windows** – add rows to `assessment_windows` for each term (title, term, optional faculty,
   opens_at, closes_at).
6. **iOS step counting** – after the first `pod install`, add `'PERMISSION_SENSORS=1'` to the
   `GCC_PREPROCESSOR_DEFINITIONS` in `ios/Podfile` (permission_handler requirement).

## Adaptations from the mock-ups

* US-specific claims (FERPA/HIPAA, 988 / 741741 hotlines, US phone numbers) were replaced with Sri Lankan
  services: **1990** Suwa Seriya ambulance, **1926** NIMH mental-health helpline and **1333** CCCline.
* Prices use Sri Lankan rupees (Rs.) and Sri Lankan campus foods.
* Academic year is tracked as an intake batch (e.g. `23/24 Batch`) instead of US-style class years
  (Freshman/Sophomore/...), matching how Sri Lankan universities refer to a cohort.
* Campus SSO was removed from sign-in — Sri Lankan universities in scope for this app don't have that
  infrastructure yet, so email/password and Google sign-in are the only options.
* "On-device" wording on the blood-report screens was changed to "stored privately in your account", because the
  report is analysed in the cloud.
* Some header titles in the mock-ups were copy/paste leftovers (e.g. "Home" on About) and were corrected.
* Notifications are in-app (reminders, milestones); push notifications would need Firebase/APNs setup.

## Project structure

```
lib/
  core/      app state, router, theme mode, config, PDF export
  data/      models, catalogue data, Supabase repository
  ui/        design tokens (Serene Pastel Sanctuary, light + dark), text styles, shared widgets, charts
  features/  onboarding, auth, home, assessments, tools, diet, progress, library, blood, support, profile
assets/images/  illustrations from the UI mock-ups + app icon
```
