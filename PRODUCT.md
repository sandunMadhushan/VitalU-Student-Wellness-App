# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

One Flutter codebase built on Material 3, shipped as an Android APK and to iPhone with equal priority. Android follows Material 3 conventions; on iOS it keeps the OS guarantees (safe areas, edge-swipe back, Reduce Motion). A web/PWA build exists but is not tuned separately.

## Users

University students in Sri Lanka (for example University of Peradeniya faculties) tracking their own health between lectures, in hostels and at home, usually on a mid-range Android phone. They check in briefly several times a day and do a longer periodic self-assessment each term.

## Product Purpose

A private, personal health record and daily tracker for students: body metrics (BMI, WHR), water, meals and dietary diversity, activity, sleep, stress, menstrual cycle, periodic wellness assessments, AI explanations of blood reports and meal photos, a health education library, and quick access to campus health support and Sri Lankan emergency lines. Success is a student who logs in seconds, understands their own numbers, and knows where to get help.

## Positioning

Built around Sri Lankan campus life: local emergency numbers (1990, 1926, 1333), Sri Lankan foods and rupee budgets, intake-batch academic years (e.g. 23/24 Batch), faculty-scheduled assessment windows, and anonymised faculty-level research only with consent.

## Operating Context

Short, frequent check-ins on a phone, in daylight and at night, light or dark system theme. Backend is Supabase (Auth, Postgres with row-level security, Storage, Edge Functions using Gemini). Current temperature for hydration tips comes from IP geolocation plus Open-Meteo.

## Capabilities and Constraints

- Sign-in: email/password and Google. Campus SSO was removed on purpose.
- Registration is three steps: basics, health background, body measurements.
- Health data is private per student; research use is opt-in and aggregated (groups of 5+).
- Not a diagnostic tool; blood-report and meal analyses are educational.
- Notifications are in-app only.

## Brand Commitments

- Name: "VitalU" (exact casing everywhere).
- App icon: coral heart with a mint leaf (assets/images/app_icon.png). Kept.
- Everything else (colors, type, components, imagery) is free to change.
- The 3D clay-style illustrations in assets/images are retired; no replacement illustrations.
- Quality bar set by the user: Apple Health / Fitness and Samsung Health / Google Fit.

## Evidence on Hand

Real feature set and copy in lib/features. No testimonials, user counts or clinical claims exist; none may be invented.

## Product Principles

1. The student's own numbers come first; decoration never competes with data.
2. Logging anything takes one or two taps.
3. Private by default, and say so plainly without repeating it on every screen.
4. Supportive, plain language; no hype, no guilt, no streak pressure.
5. Help is always reachable.
