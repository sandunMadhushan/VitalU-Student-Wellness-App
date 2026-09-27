# VitalU — Student Wellness App (Flutter + Supabase)

Flutter implementation of the VitalU personalised mobile health platform (Android + iOS), built from the
designs in `../UI Screens` and the concept paper in the parent folder.

## Run it

```bash
flutter pub get
flutter run            # Android device / emulator or iOS simulator
flutter build apk      # Android release build
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
* "On-device" wording on the blood-report screens was changed to "stored privately in your account", because the
  report is analysed in the cloud.
* Some header titles in the mock-ups were copy/paste leftovers (e.g. "Home" on About) and were corrected.
* Notifications are in-app (reminders, milestones); push notifications would need Firebase/APNs setup.

## Project structure

```
lib/
  core/      app state, router, config, PDF export
  data/      models, catalogue data, Supabase repository
  ui/        design tokens (Serene Pastel Sanctuary), text styles, shared widgets, charts
  features/  onboarding, auth, home, assessments, tools, diet, progress, library, blood, support, profile
assets/images/  illustrations from the UI mock-ups + app icon
```
