# VitalU redesign brief

A brief for redesigning the whole VitalU app: look, layout, navigation and motion. It describes what exists today, what must not change, and what each screen should become.

## 1. The app in one paragraph

VitalU is a private health companion for University of Peradeniya undergraduates. Students log water, meals, steps, sleep, stress and their menstrual cycle in a few taps, check body and heart-risk numbers (BMI, WHR, CVD risk), read short health articles, and reach campus health staff. Every six months a periodic health assessment opens for their faculty. The university sees only pooled, anonymous results. Built in Flutter (Material 3), Android and iPhone with equal priority, backend on Supabase.

Users are mostly on mid-range Android phones, in daylight and at night, in hostels and between lectures. Sessions are short and frequent.

## 2. Goals of the redesign

1. One consistent visual language. Today each area (Home, Tools, Diet, Learn, Profile) has grown its own card style.
2. The student's own numbers come first; decoration never competes with data.
3. Logging anything takes one or two taps.
4. Feels rewarding without pressure: badges and streaks celebrate, they never scold.
5. Quality bar: Apple Health / Fitness and Samsung Health, with a warmer, student-friendly tone.
6. Works on small screens (360 px wide), with large text sizes, in light and dark.

## 3. Must stay

- **Name:** "VitalU", exact casing.
- **Icon:** coral heart with a mint leaf, as in `assets/images/app_icon.png`.
- **Theme colours:** the current green, coral and purple palette (section 5). Colours may be refined, not replaced.
- **Five tabs only:** Home, Tools, Diet, Learn, Profile. No Habits tab.
- **Brand mark top left** on every main screen (icon plus "VitalU"), with the bell and avatar top right.
- **Privacy rules:** health data is private per student. Admins see completion status and pooled results only. Groups under 5 are hidden.
- **Not a diagnosis:** tools are for awareness. No alarming or guilt language.
- **Help always reachable:** health centre 081 239 2022 (open 24/7), ambulance 1990, mental health line 1926.
- **No em dashes** in any copy.
- **Sex-aware art:** home hero and the Active Aura badge show a girl or boy depending on the profile.
- **Calm music, sound effects and badge pop-ups** stay, each with a sound on/off setting.

## 4. What is wrong today

- Large page titles used to collapse into the top bar and get cut off. Fixed in code, but the header needs a proper design (section 7.1).
- Home is a long list of equal-weight cards. The most important thing (today's check-in, an open assessment) does not stand out.
- Diet, Tools and Home cards look related but are not the same component, with different corner radii, paddings and button styles.
- Icons mix 3D illustrations, line icons and filled icons.
- The BMI result, plate guide and cycle ring were called out as dull or monotonous.
- Result screens (BMI, WHR, CVD, DASS-21) each present results differently.
- Long text blocks in several tools; hard to scan on a phone.

## 5. Design system to build

Deliver tokens and components first, then screens.

### 5.1 Colour

Current light values, to refine:

| Role | Value | Use |
|------|-------|-----|
| Surface | `#F8F5FD` | page background |
| Card | `#FFFFFF` | cards |
| Primary | `#0B7A63` | main actions, selected states |
| Secondary | `#CC2F55` | accents, heart |
| Water | `#1A6FE0` | hydration |
| Activity | `#E0590F` | movement, steps |
| Sleep | `#5552D1` | sleep |
| Nutrition | `#2E8F42` | diet |
| Heart | `#D1344E` | cardiovascular |
| Mind | `#7C4DD6` | stress, anxiety |
| Cycle | `#D13C78` | cycle tracker |
| Body | `#0B7A63` | BMI, WHR |

Dark surface is `#0F0E13` with primary `#4FD1B0`. Each health area keeps its own accent colour so a student learns "blue is water" without reading. Provide light and dark for every token, and check contrast: 4.5:1 for text, 3:1 for icons and chart marks.

### 5.2 Type

Manrope, already bundled. Keep the scale (32, 28, 24, 19, 16, 15.5, 14.5, 12.5) and the heavy tabular numerals for metrics. Decide a minimum body size of 14 and verify nothing breaks at 130% system font scale.

### 5.3 Shape, space, elevation

- One radius ladder (suggested 12, 16, 24, pill). Cards use one radius everywhere.
- 4 px spacing grid, 16 px screen margin.
- Elevation by tint and soft shadow in light, by surface step in dark. No heavy shadows.

### 5.4 Icons and imagery

- One icon family (Material Symbols Rounded) for UI.
- One illustration style for feature art. Today it is 3D icons for tools and Diet; pick one direction and apply it to every feature card.
- Food photography for Healthy Plate and food groups should look real, not cartoon.
- Illustrations of bodies (cycle, lungs, WHR tape guide, body shapes) must be anatomically accurate and non-sexualised.

### 5.5 Components to design

Page header (brand, bell, avatar, large title) · metric tile · feature card (wide and half) · list row and grouped list · progress ring and bar · segmented control · chip · ruler picker (vertical and horizontal) · bottom sheet · dialog · toast · badge medal (locked, in progress, earned) · streak track (stars) · empty state · skeleton loader · chart (bars, lines, calendar heat) · question card for assessments · bottom navigation.

### 5.6 Motion and sound

- Short and purposeful: 150 to 300 ms for UI, longer only for celebrations.
- Water bottle fill and swirl on logging, plus a pour sound.
- Badge pop-up: scale in, burst, fanfare. All five badges use the same sound.
- Cycle womb-lining animation per phase, lung animation in the smoking article, answer animations in the assessment.
- Respect Reduce Motion: replace with fades.

## 6. Navigation

```
Home | Tools | Diet | Learn | Profile
```

- Floating bottom bar with five items, icon plus label, selected pill.
- Bell opens Notifications. Avatar opens Profile.
- Deep screens use a back button and a title, not the large header.
- Emergency help reachable from Home, Tools and Profile in at most two taps.

## 7. Screen by screen

### 7.1 Header (all main tabs)

Fixed bar: VitalU icon and name left, bell and avatar right. The large title sits below the bar and scrolls away. On the Home tab the title is the greeting ("Good Morning, Nimal", always title case).

### 7.2 Home

Order, top to bottom:

1. Greeting.
2. Alert area: open periodic assessment (with open and close dates and days left), or "coming soon". Reminder to finish the health profile (allergies, family history, medications).
3. Hero: friendly girl or boy illustration by sex, with "How are you feeling?".
4. Daily health updates, in this order: BMI, WHR, Diet quality (PDQS), Water, Steps, Sleep, Stress (DASS-21), then Blood pressure, Fasting glucose, Triglycerides. Lab values show the latest reading and its date, not a daily number.
5. Key health habits, picked from logs and assessments (low fruit, sugary cravings, low water, low activity, irregular sleep).
6. Ask anonymously: a prominent card to the health centre, with a clear emergency line.
7. Your badges (earned first).
8. Progress card linking to the Progress screen.

Explore section stays removed.

### 7.3 Tools

Card grid with one component. Order: BMI, WHR, CVD risk, Anxiety tracker, Water, Activity, Sleep, Cycle (female profiles only), Talk to a professional, Blood report reader last. Titles may wrap to two lines.

### 7.4 Tool screens

| Tool | Redesign direction |
|------|--------------------|
| BMI | Result hero with category, then illustrated, category-specific plan (food, movement, habits), then a supportive "what this means" block. Distinct palette per category, not monotone. |
| WHR | Tape-position illustration, waist-to-height guideline, no BMI comparison. |
| CVD risk | Optional fields note, Yes/No for family history, None for conditions, "Low risk" wording. One shared result layout with the other tools. |
| Anxiety (DASS-21) | One question per screen, auto-advance, "Go to previous question", calm music card, results matching the Nurse Diary DASS-21 reference, five practical relaxation ideas with illustrations. |
| Water | Order: body weight and reminders, goal explanation, bottle, temperature card, add water, 3-day Aqua Achiever streak, logs. |
| Activity | 7-day Active Aura streak, IPAQ-SF check-in, step sync. |
| Sleep | Log and PSQI quiz. |
| Cycle | Lunar-style ring, year calendar with tap-a-month logs, animated womb lining per phase, phase messages as estimates, notification settings. No spotting or notes. |

### 7.5 Diet

Hub styled like Tools: calorie counter (wide, with progress), Meal diary, Healthy plate, Dietary diversity guide, Budget planner (max LKR 10,000 a week), then diet quality score and the Smart Eater streak.

- **Calorie counter:** big ring with target, eaten, left; clear but gentle over-target state; energy balance when activity data exists; flexible split across meals.
- **Healthy plate:** realistic 3D plate, fruit and fats shown separately, hand portions.
- **Diversity guide:** ten food groups with Sri Lankan examples and photos.
- All screens use the single food database.

### 7.6 Learn

Follow the reference layout: Learn home with search and "Recommended for you", topic grid (13 topics including Sexual Health and STIs), category page, article list, article detail with hook, sections, key point, myths, try-this, related tools, reading time and references.

### 7.7 Profile

Profile header (round bust avatar, name, username, faculty) opens Account. Then: Account, Achievements (earned badges shown under the title), Summary, About This Project, Settings (Mode: Light, Dark, System Default; sounds), Contact Us.

### 7.8 Registration and assessment

- Registration: three steps, every field in step 1 mandatory, rulers for height and weight, body shape cards, activity level.
- Periodic assessment: intro explaining why (Sri Lankan young adult risk facts) and that answers are anonymous; ten sections; mixed question types (cards, illustrated sliders, day pickers, short text); 7-day recall for diet questions; under 10 minutes.

### 7.9 Support

Consult anonymously, professionals directory (placeholders), help and emergency lines. Calm, never alarming.

## 8. Badges

Five only, each with a medal design, an earn animation and the same sound.

| Badge | Rule |
|-------|------|
| Aqua Achiever | Water goal 3 days in a row |
| Active Aura | Step goal or 30 active minutes, 7 days in a row |
| Smart Eater | Breakfast, lunch, dinner with 5+ food groups for 7 days, PDQS at least 22 of 42 |
| Heart Minded | Heart check plus blood pressure and a sugar or triglyceride value within 90 days |
| Curious Learner | 5 articles read to the end from 3+ topics |

States for each: locked, in progress (stars or steps, days remaining), earned (date).

## 9. Content and tone

- Warm, plain, supportive. Short sentences. Everyday Sri Lankan examples.
- No body shaming, no guilt, no streak pressure.
- Never imply a diagnosis. Say "may", "can", "talk to a doctor".
- Do not invent statistics or references.

## 10. Accessibility

- Contrast as in 5.1, tap targets at least 48 px.
- Labels on every icon button, semantic order on every screen.
- Not colour alone: pair colour with text or icon.
- Works with TalkBack and VoiceOver, large fonts, Reduce Motion.

## 11. Deliverables

1. Design tokens and component library (Figma), light and dark.
2. High-fidelity screens for every screen in section 7, at 360 and 390 px widths.
3. Clickable prototype for: registration, logging water with badge pop-up, BMI result, cycle calendar, assessment, Learn article.
4. Motion spec for the celebrations and animations in 5.6.
5. Short handoff notes mapping each component to the Flutter widgets in `lib/ui/widgets.dart`.

## 12. Out of scope

New features, new backend tables, campus SSO, notifications outside the device, and any change to scoring rules or clinical content.
