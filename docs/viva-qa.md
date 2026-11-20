---
title: "VitalU — Viva Questions and Answers"
subtitle: "Computing technologies and food science, in plain words"
---

# How to use this guide

Each answer is short enough to say in 20–40 seconds. Start with the one-line
answer, then add a detail or an example if the examiner wants more. Numbers
and formulas are the ones VitalU actually uses.

---

# Part A — The big picture

**1. What is VitalU, in one sentence?**

An integrated university health information platform: a student app for
personal health monitoring, and an admin dashboard that turns pooled,
anonymous results into population-level insight for health promotion.

**2. What problem does it solve?**

Students in Sri Lanka show early risks (overweight, central obesity, low fruit
and vegetable intake, breakfast skipping, inactivity, stress), but universities
have little up-to-date data. VitalU helps each student understand their own
numbers, and helps the university see what is common, plan interventions and
check whether they worked.

**3. Who are the users?**

Students (mobile app) and the university health administration (web dashboard).

**4. What makes it different from a normal fitness app?**

- It is built for Sri Lankan campus life: local foods, local emergency numbers
  (1990, 1926, 1333), faculty-based assessment windows.
- It links individual tracking to institutional action through the periodic
  assessment.
- Nutrition is personalised (own energy target, diversity, diet quality),
  not generic advice.

**5. What is the "connecting point" between the two interfaces?**

The six-monthly **periodic assessment**. The admin schedules it, students are
notified and complete it, and the dashboard shows pooled results, trends and
priority needs.

**6. What does "data-driven intervention" mean here?**

Use the data to find the most pressing needs (for example breakfast skipping
or low fruit and vegetable intake), plan a targeted programme, then measure
the same indicators in the next assessment to see if they improved. The cycle
on the dashboard is: data collection → analysis → priority needs → planning →
implementation → reassessment.

---

# Part B — Computing technologies

## B1. Architecture

**7. What is the overall architecture?**

Client–server, cloud-backed:
- **Client 1:** Flutter mobile app (Android, iPhone; also a web build).
- **Client 2:** Admin dashboard, a static web app (HTML, CSS, JavaScript).
- **Backend:** Supabase — PostgreSQL database, authentication, file storage
  and Edge Functions (server-side code).

**8. What is Flutter and why use it?**

Google's cross-platform UI framework, written in the **Dart** language. One
codebase builds Android, iOS and web apps, which saves time and keeps the
apps consistent. It uses Material 3 design.

**9. What is Supabase?**

An open-source "backend as a service" built on **PostgreSQL**. It gives a
database, user login, file storage, auto-generated APIs and serverless
functions, so we did not have to build and run our own server.

**10. What is a "backend as a service" (BaaS)?**

A cloud service that provides ready-made server features (database, auth,
storage, APIs) so developers focus on the app instead of server
maintenance.

**11. Why a relational database (PostgreSQL)?**

Health data is structured and related (a student has many meals, water logs,
assessments). Relational tables, keys and SQL make it easy to keep data
consistent, query it, and calculate pooled statistics.

**12. Name some tables.**

`profiles`, `meals`, `water_logs`, `activity_logs`, `sleep_logs`,
`diversity_logs`, `tool_results`, `assessments`, `assessment_windows`,
`assessment_questions`, `notifications`, `consultation_requests`,
`health_interventions`, `badges`, `user_badges`.

**13. What is an API? How does the app talk to the database?**

An API (application programming interface) is a defined way for programs to
exchange data. The app uses the Supabase client library, which sends
HTTPS requests to Supabase's REST API and calls database functions (RPCs).

**14. What is an Edge Function?**

A small serverless program that runs in the cloud on demand (written in
TypeScript on Deno). VitalU uses them for `analyze-meal` (meal photo) and
`analyze-blood-report`, so secret API keys stay on the server, not in the app.

**15. What is "serverless"?**

You deploy only a function; the cloud provider runs, scales and maintains the
servers. You pay for and manage only the code.

**16. How is the admin dashboard built and deployed?**

A static site (HTML/CSS/JavaScript) with its own chart code. GitHub Actions
builds the Flutter web app and copies the admin folder in, then deploys to
GitHub Pages at `/admin/`.

**17. What is CI/CD?**

Continuous integration / continuous deployment: every push to the main branch
automatically builds and publishes the site, so updates are fast and
repeatable.

**18. What is version control and which did you use?**

Git, hosted on GitHub. It records every change, allows branches and
collaboration, and lets us roll back mistakes.

## B2. Security and privacy

**19. How do users log in?**

Email and password, or Google sign-in (OAuth), through Supabase Auth.
Registration has three steps: basics, health background, body measurements.

**20. What is OAuth?**

A standard that lets a user log in with an existing account (Google) without
giving VitalU their Google password; Google returns a secure token.

**21. How is health data kept private?**

- **Row-Level Security (RLS):** database rules so each student can read and
  write only their own rows.
- **HTTPS** encrypts data in transit.
- Admins **never** read the raw `assessments` or `profiles` tables. They only
  call special database functions that return **pooled counts**.
- Results for groups of **fewer than five** students are never shown.

**22. What is Row-Level Security?**

A PostgreSQL feature that filters rows per user automatically. Even if
someone called the API directly, they would only get their own data.

**23. Why hide groups smaller than five?**

To prevent re-identification. If a faculty/year group had only two students,
a percentage could reveal an individual's answer. This is a simple
**k-anonymity** idea (k = 5).

**24. What is a "security definer" function?**

A database function that runs with the owner's rights but only returns what it
is written to return (here, aggregated counts). Admins get the summary without
direct table access.

**25. Is the publishable key in the app a security risk?**

No. The publishable key only identifies the project; all data is protected by
RLS. Secret keys (e.g. AI keys) are kept in Edge Function secrets.

**26. What about consent and research use?**

Research use is opt-in and only aggregated. The assessment introduction tells
students that answers are used only as a pooled picture, without personal
identifiers.

## B3. Features as computing concepts

**27. How do notifications work?**

In-app notifications stored in a `notifications` table (assessment "coming
up" three days before and "now open" on the day, reminders, milestones), plus
local notifications on the phone.

**28. How does scheduling an assessment work technically?**

The admin picks round, year, date, time, days open and faculties. The
dashboard calls a database function that creates one **window** per faculty
and queues notifications for those students.

**29. Why is the questionnaire stored in the database and not hard-coded?**

So the administration can edit questions, answers and scoring, reorder or
retire questions, without releasing a new app version.

**30. How is progress saved in the assessment?**

After every answer, so a student can leave and "continue where I left off".

**31. How does the meal photo feature work?**

The photo is sent to the `analyze-meal` Edge Function, which asks a
multimodal AI model (Gemini) to recognise the foods and estimate portions and
calories. Results are educational estimates, not exact measurements.

**32. How does the blood report reader work?**

The student uploads a lab report; an Edge Function uses AI to explain the
values in plain language. It is educational, not a diagnosis.

**33. How does the water tracker know the weather?**

It finds approximate location from the IP address and asks the free
**Open-Meteo** weather API for the temperature, then gives a hydration tip.

**34. How are badges and streaks calculated?**

A database function (`refresh_badges`) checks logs (for example 7 days in a
row meeting a goal) and awards badges. Doing it in the database keeps it
consistent and tamper-resistant.

**35. How does the dashboard draw charts?**

It fetches pooled numbers (per period, faculty, academic year, sex) and draws
bar charts (prevalence), line charts (trends) and comparison bars (faculty)
in the browser. Data can be downloaded as CSV.

**36. What is data visualisation's role here?**

It turns thousands of answers into a few clear pictures so administrators can
quickly see the biggest and fastest-rising problems.

**37. How are "priority needs" ranked?**

Each concern gets a score from how common it is, how fast it is rising and
how far it is above the university's target; the highest scores are the
priorities, with hot-spot faculties and suggested interventions.

**38. How are interventions monitored?**

Each intervention records the target concern, faculties, responsible person,
dates, steps and status. Its baseline value is compared with the result in
the next assessment ("result at reassessment").

## B4. Design, quality and limits

**39. What design principles did you follow?**

The student's own numbers come first; logging takes one or two taps; private
by default; supportive language without guilt; help always reachable. Light
and dark themes, safe areas and accessibility on iOS and Android.

**40. How did you test it?**

Manual testing on devices, a pilot evaluation with students (feedback form),
and checks of calculations against worked examples.

**41. What are the main technical limitations?**

Needs internet for syncing; AI estimates can be wrong; self-reported data has
recall bias; notifications are in-app only.

**42. How could it scale to more universities?**

The cloud backend scales automatically; faculties and windows are already
data-driven, so adding a university is mostly configuration.

---

# Part C — Food science and nutrition

## C1. Energy and body measures

**43. What is energy in food, and how is it measured?**

Food energy is measured in kilocalories (kcal). Carbohydrate and protein give
about **4 kcal/g**, fat **9 kcal/g**, alcohol 7 kcal/g.

**44. What is BMR?**

Basal metabolic rate: energy the body uses at complete rest to stay alive
(breathing, heart, temperature).

**45. Which equation does VitalU use for BMR, and why?**

**Mifflin–St Jeor**:
- Men: 10 × weight (kg) + 6.25 × height (cm) − 5 × age + 5
- Women: 10 × weight (kg) + 6.25 × height (cm) − 5 × age − 161

Recommended by the Academy of Nutrition and Dietetics; more accurate for most
adults than Harris–Benedict (within about ±10%).

**46. What is TDEE?**

Total daily energy expenditure = BMR × physical activity level (PAL):
mostly sitting 1.2, light walking 1.375, moderate 1.55, active 1.725. It is
the energy needed to keep weight steady.

**47. How is the personal daily calorie target set?**

TDEE adjusted by BMI: underweight +350 kcal, normal 0, overweight −400,
obesity −500. Never below 1,500 kcal (men) or 1,300 kcal (women). A student
can also enter a target from a dietitian.

**48. Why a 500 kcal deficit?**

About 500 kcal a day ≈ 0.5 kg weight loss a week, a safe, sustainable pace.

**49. Give a worked example.**

Female, 21 y, 55 kg, 158 cm, light walking: BMR = 550 + 987.5 − 105 − 161 =
1,272 kcal; × 1.375 = 1,750 kcal; BMI 22 (normal) → target 1,750 kcal.

**50. What is energy balance?**

Energy in (meals logged) minus energy out (BMR × 1.2 plus logged activity).
Positive balance over time → weight gain; negative → weight loss.

**51. How is the target split across meals?**

Breakfast 25%, lunch 35%, dinner 30%, snacks 10% — a flexible guide.

**52. What is BMI and its categories?**

BMI = weight (kg) ÷ height (m)². WHO: underweight < 18.5, normal 18.5–24.9,
overweight 25–29.9, obesity ≥ 30.

**53. Limitation of BMI?**

It does not show fat distribution or muscle. Asians develop risk at lower BMI
(about ≥ 23), so risk may be underestimated with WHO cut-offs.

**54. What is waist-to-hip ratio (WHR) and why measure it?**

Waist ÷ hip circumference. It shows **central (abdominal) obesity**, which is
more strongly linked to heart disease and diabetes than BMI. WHO: higher risk
at ≥ 0.90 (men), ≥ 0.85 (women). VitalU also shows **waist-to-height ratio**,
with 0.5 or above as a warning.

**55. Apple vs pear body shape?**

Apple: fat around the waist (higher risk). Pear: fat on hips and thighs
(lower metabolic risk).

## C2. Diet variety and quality

**56. What is dietary diversity?**

The number of different food groups eaten. More groups usually means better
coverage of vitamins and minerals (micronutrient adequacy).

**57. Which dietary diversity score does VitalU use?**

A **Sri Lankan 10-group score** (Abeywickrama et al., 2020): cereals; tubers
and starchy vegetables; root and fruit vegetables; green leafy vegetables;
fruits; pulses, nuts and seeds; meat and poultry; eggs; fish and seafood; milk
and milk products. Score 0–10 per day.

**58. What is the cut-off?**

**5 or more groups** = minimum dietary diversity met (from FAO's MDD-W and
studies showing it works for men and women).

**59. Why not use MDD-W?**

MDD-W was designed for women aged 15–49; VitalU users are men and women.

**60. Why are oils, sugar and spices not counted?**

Almost everyone eats them daily in Sri Lanka; counting them makes a diet look
varied without being healthier (Jayawardena et al. found high 12-group scores
linked to obesity).

**61. How much of a food counts as a group?**

About a tablespoon (15 g), following FAO guidance.

**62. Limitation of dietary diversity?**

It measures variety, not quantity or quality: fried snacks and sweet drinks
can still give a "varied" day.

**63. What is diet quality and how does PDQS measure it?**

Diet quality is how healthy the overall pattern is. The **Prime Diet Quality
Score** (Fung et al., 2018) scores **21 food groups over 7 days**: 14 healthy
groups get 0/1/2 points for 0–1 / 2–3 / 4+ servings; 7 less healthy groups
are reverse-scored (2/1/0). Total **0–42**; higher is better.

**64. Name healthy and less healthy PDQS groups.**

Healthy: dark green leafy vegetables, cruciferous vegetables, carrots, other
vegetables, citrus, other fruits, pulses, nuts and seeds, poultry, fish, eggs,
whole grains, liquid vegetable oils, low-fat dairy. Less healthy: red meat,
processed meat, refined grains and baked goods, sugar-sweetened drinks,
desserts, fried food from outside, potatoes.

**65. VitalU's PDQS bands?**

28+ good, 21–27 fair, below 21 room to improve (app bands; PDQS has no
official cut-offs).

**66. Two ways VitalU gets PDQS?**

1) Weekly 21-question check-in (standard). 2) Estimate from meal logs (each
food is tagged with its PDQS groups); shown as reliable only with at least 4
of 7 days logged.

**67. Why use both dietary diversity and PDQS?**

Diversity shows **variety**; PDQS shows **quality** because it penalises
unhealthy foods. Together they give a fuller picture.

**68. What is a serving, and how does VitalU explain it?**

A standard amount for each food group (e.g. ½ cup cooked vegetables, 1 egg,
a palm-sized piece of fish). VitalU uses hand guides: cupped hand, fist, palm,
thumb.

**69. What is the healthy plate?**

A visual guide: **half vegetables, a quarter grains (preferably whole), a
quarter protein**, plus fruit and dairy on the side, with little fat. It
teaches portion balance without counting calories.

**70. Why recommend red rice / whole grains over white rice?**

Whole grains keep the bran and germ: more fibre, B vitamins and minerals,
slower digestion (lower glycaemic response), better satiety and lower
diabetes risk.

**71. What is dietary fibre and why is it important?**

Plant carbohydrate we cannot digest. It helps bowel health, slows sugar
absorption, lowers cholesterol and helps weight control. Sources: vegetables,
fruits, pulses, whole grains.

**72. What is the glycaemic index (GI)?**

How quickly a food raises blood glucose compared with pure glucose. Low-GI
foods (pulses, whole grains) give steadier energy.

**73. Why are green leafy vegetables like gotukola and mukunuwenna important?**

Rich in folate, iron, vitamin A (β-carotene), vitamin C, calcium and fibre;
cheap and local.

**74. Why focus on fruit and vegetable intake?**

They supply vitamins, minerals, fibre and antioxidants and lower the risk of
heart disease and some cancers. Sri Lankan studies found almost no students
meet the daily target.

**75. Why is breakfast skipping a concern?**

Linked to poorer diet quality, more snacking on sugary/fried foods, lower
concentration and weight gain. It is a common student problem, so it is a
tracked indicator and a typical intervention target.

**76. What are sugar-sweetened drinks and why limit them?**

Soft drinks, sweet milk tea, packet juice. "Empty calories" that raise the
risk of weight gain, diabetes and tooth decay.

**77. Why is fried food from outside counted as less healthy?**

High in fat, often reused oil (trans fats and oxidised fats), salt and energy;
linked to obesity and heart disease.

**78. What affects the calorie accuracy of Sri Lankan dishes?**

Amount of oil and coconut milk, portion size and recipe. Logged values are
estimates from food composition values for common recipes.

**79. What is food security, and why is it relevant?**

Reliable access to enough safe, nutritious food. At Peradeniya, 44% of
students were food insecure, and they ate less varied diets. VitalU's budget
planner suggests balanced meals within a rupee budget.

## C3. Other health tools (science basis)

**80. How is the daily water goal calculated?**

Body weight × **35 ml per kg** (e.g. 71 kg × 35 ml ≈ 2.5 L), spread through
the day, more in hot weather or after sport.

**81. Why does hydration matter?**

Water regulates temperature, carries nutrients, removes waste and affects
concentration; even mild dehydration lowers alertness.

**82. How is physical activity measured?**

Steps and logged activities, plus the **IPAQ short form**: MET-minutes/week =
8.0 × vigorous + 4.0 × moderate + 3.3 × walking minutes; categories Low,
Moderate, High.

**83. What is a MET?**

Metabolic equivalent: energy cost of an activity compared with sitting at
rest (1 MET). Running ≈ 8 METs.

**84. How is sleep assessed?**

Sleep logs (bedtime, wake time, estimated stages) and a sleep-quality check
adapted from the **PSQI** (Pittsburgh Sleep Quality Index).

**85. How is anxiety/stress assessed?**

The **DASS-21** (Depression, Anxiety and Stress Scales), 21 statements about
the past week. It is a self-reflection tool, not a diagnosis.

**86. How is cardiovascular (CVD) risk shown?**

A factor-based awareness score (age, sex, BMI, smoking, activity, family
history, diabetes, blood pressure, glucose, cholesterol). Result = points ÷
maximum of answered factors: < 35% low, 35–59% moderate, ≥ 60% high. It is
not a validated 10-year risk equation (those are for people 40+).

**87. Why include a menstrual cycle tracker?**

To predict periods and phases and give phase-based tips (energy, appetite,
rest). Nutritionally, menstruation increases iron needs, and iron-deficiency
anaemia is common in young women.

**88. What are normal fasting glucose and cholesterol cut-offs used?**

Fasting glucose: < 100 normal, 100–125 prediabetes range, ≥ 126 diabetes
range (mg/dL). Total cholesterol: < 200 desirable, 200–239 borderline,
≥ 240 high (mg/dL). Blood pressure: < 120/80 normal, ≥ 140/90 high.

---

# Part D — Integration questions (computing + food science)

**89. How do computing and food science come together in VitalU?**

Food science provides validated methods (Mifflin–St Jeor, dietary diversity,
PDQS, healthy plate, WHO cut-offs); computing turns them into automatic,
personal calculations, stores the data securely, and aggregates it into
dashboards for public-health decisions.

**90. How does a logged meal become nutrition information?**

Each food in the database has portion units with kcal, food-group tags and
PDQS tags. When a student logs "6 string hoppers + dhal", the app multiplies
portions by kcal, adds groups to today's diversity score and counts servings
for the PDQS estimate.

**91. How does the app personalise nutrition?**

It uses the student's own sex, age, height, weight and activity to calculate
an energy target, compares their actual intake against it, and shows which
food groups they personally miss — instead of one general message for all.

**92. How does individual data become population data?**

Students complete the periodic assessment; the database computes pooled
percentages per faculty, year and sex (hiding groups under 5); the dashboard
shows prevalence, trends and comparisons.

**93. Give an example of the full data-to-intervention cycle.**

Assessment shows breakfast skipping at 38% and rising, highest in two
faculties → it appears in Priority needs → the admin plans a "healthy
breakfast" programme (e.g. affordable canteen breakfast) → the next
assessment re-measures breakfast skipping to evaluate the result.

**94. Why are Sri Lankan foods in the database important technically and
nutritionally?**

Nutritionally, generic Western databases miss foods like string hoppers,
kottu, gotukola or kavum. Technically, local food tags let the algorithms
(calories, diversity, PDQS) work correctly for local diets.

**95. How do you prevent the app from encouraging unhealthy eating behaviour?**

Safety floors for calorie targets, neutral messages when going over target,
no streak pressure, and "talk to a professional" options for high-risk
results.

**96. What are the main limitations, combining both areas?**

Self-reported intake (recall bias, under-reporting), estimated calories of
mixed dishes, borrowed cut-offs not validated in Sri Lankan students, AI
estimates, and BMR equations accurate only to about ±10%.

**97. What future improvements would you suggest?**

Validate the diversity cut-off and PDQS bands in Sri Lankan students; add a
local food composition database with nutrients beyond calories; wearable step
sync; push notifications; offline mode; and dietitian review of AI meal
estimates.

---

# Part E — Quick-fire facts (memorise)

| Item | Value |
|---|---|
| kcal per gram | Carbohydrate 4, Protein 4, Fat 9 |
| BMR equation | Mifflin–St Jeor |
| PAL factors | 1.2 / 1.375 / 1.55 / 1.725 |
| BMI adjustment | +350 / 0 / −400 / −500 kcal |
| Calorie floors | Men 1,500, Women 1,300 kcal |
| Meal split | 25 / 35 / 30 / 10 % |
| BMI cut-offs (WHO) | 18.5, 25, 30 (Asian risk from 23) |
| WHR risk | ≥ 0.90 men, ≥ 0.85 women |
| Waist-to-height | ≥ 0.5 = higher risk |
| Diversity score | 10 groups, ≥ 5 = adequate |
| PDQS | 21 groups, 0–42, 7 days |
| PDQS bands (app) | ≥ 28 good, 21–27 fair, < 21 improve |
| Healthy plate | ½ veg, ¼ grains, ¼ protein |
| Water goal | 35 ml × body weight (kg) |
| IPAQ | 8.0 vigorous, 4.0 moderate, 3.3 walking |
| Privacy rule | Groups < 5 students hidden |
| Assessment | Twice a year, 11 sections, ~41 questions, ~7 min |
| Tech stack | Flutter/Dart, Supabase (PostgreSQL, Auth, Storage, Edge Functions), HTML/CSS/JS dashboard, GitHub Actions + Pages |

---

# Part F — Tips for the viva

- If you do not know an exact number, explain the **principle** (e.g. "the
  deficit is chosen to give safe, gradual weight loss").
- Always mention **limitations honestly** — examiners like that.
- Link answers back to the **story**: individual monitoring → periodic
  assessment → pooled analytics → targeted intervention → reassessment.
- Stress **privacy by design**: RLS, pooled results only, groups under five
  hidden, opt-in research.
