# How VitalU's diet and heart tools work

This document explains the calculations behind the Diet section (calorie
target, energy balance, dietary diversity, diet quality, the Smart Eater
badge) and the CVD risk indicator: what each one does, where it comes from,
and its limits. It is background for the research team and supervisors; the
app shows students only a short, plain version.

Code references: `lib/features/diet/diet_science.dart`,
`lib/data/food_db.dart`, `lib/features/diet/pdqs_screen.dart`,
`lib/features/tools/heart_risk_screen.dart`.

---

## 1. Daily calorie target

The target is built in four steps from the student's profile (sex, age,
height, weight and activity level).

### Step 1. Basal metabolic rate (BMR): Mifflin–St Jeor equation

The energy the body uses at complete rest.

```
Men:    BMR = 10 × weight (kg) + 6.25 × height (cm) − 5 × age (years) + 5
Women:  BMR = 10 × weight (kg) + 6.25 × height (cm) − 5 × age (years) − 161
```

Mifflin–St Jeor (1990) is the equation the Academy of Nutrition and
Dietetics recommends for healthy adults, because it predicts measured
resting energy within ±10 % for most people, more often than the older
Harris–Benedict equation.

### Step 2. Total daily energy expenditure (TDEE)

BMR is multiplied by a physical activity level (PAL) factor that matches the
activity option the student chose in their profile:

| Profile option          | PAL   | Meaning |
|-------------------------|-------|---------|
| Mostly sitting          | 1.2   | Lectures and study, little walking |
| Light walking (campus)  | 1.375 | Walking between lectures most days |
| Moderate walking (campus) | 1.55 | Plenty of walking, or exercise 3 to 5 days a week |
| Active / sports         | 1.725 | Hard exercise or sport most days |

```
TDEE = BMR × PAL      (rounded to the nearest 50 kcal)
```

TDEE is the energy needed to **keep weight steady**.

### Step 3. BMI-based adjustment

BMI = weight (kg) ÷ height (m)². The target then moves gently from TDEE
depending on the BMI category (WHO cut-offs):

| BMI category | Adjustment | Goal |
|--------------|-----------|------|
| Underweight (< 18.5)  | **+350 kcal** | Gain weight gradually |
| Normal (18.5 to 24.9) | 0         | Keep weight steady |
| Overweight (25 to 29.9) | **−400 kcal** | Lose weight gradually |
| Obesity (≥ 30)        | **−500 kcal** | Lose weight steadily and safely |

Why these amounts: a deficit of about 500 kcal a day leads to roughly
0.5 kg of weight loss a week, the pace most guidelines recommend as safe and
sustainable. A smaller surplus (+350) is used for underweight students so
gain is gradual and mostly lean tissue rather than fat.

### Step 4. Safety floor

The target never goes below **1,500 kcal for men** or **1,300 kcal for
women**, so a student is never advised to eat too little to meet nutrient
needs.

```
Target = max(TDEE + adjustment, floor)
```

### Worked examples

**Female student**, 21 years, 55 kg, 158 cm, light walking:

- BMR = 10×55 + 6.25×158 − 5×21 − 161 = 550 + 987.5 − 105 − 161 = **1,272 kcal**
- TDEE = 1,272 × 1.375 = 1,749 → **1,750 kcal**
- BMI = 55 ÷ 1.58² = 22.0 (normal) → adjustment 0
- **Target: 1,750 kcal a day**

**Male student**, 22 years, 80 kg, 172 cm, mostly sitting:

- BMR = 800 + 1,075 − 110 + 5 = **1,770 kcal**
- TDEE = 1,770 × 1.2 = 2,124 → **2,100 kcal**
- BMI = 80 ÷ 1.72² = 27.0 (overweight) → −400
- **Target: 1,700 kcal a day** (above the 1,500 floor)

### Own target

A student can replace the estimate with their own number (for example one
given by a dietitian). The app then uses that number everywhere, and can be
switched back to the estimate at any time.

### Meal split

The target is shown spread across the day as a flexible guide:

| Breakfast | Lunch | Dinner | Snacks |
|-----------|-------|--------|--------|
| 25 %      | 35 %  | 30 %   | 10 %   |

For a 1,750 kcal target: about 440 / 610 / 525 / 175 kcal.

---

## 2. Energy balance (Calorie counter screen)

```
Energy in   = kcal of all meals logged today
Energy out  = BMR × 1.2  +  activity kcal logged today (or counted by the phone)
Balance     = Energy in − Energy out
```

`BMR × 1.2` covers resting needs plus ordinary daily living. Exercise is then
added from what the student actually logged in the Activity tracker, instead
of assuming an activity level, so that the day's "out" reflects that day.

The screen also shows "kcal left" against the target. When a student goes
over, the message is deliberately neutral ("That is okay: one day does not
define your habits") to avoid encouraging restrictive eating.

### Where calorie values come from

Each food in the food database (`food_db.dart`) has practical portion units
(tablespoon, cup, piece, slice, glass, serving) with an estimated kcal per
unit, based on common Sri Lankan recipes and food composition values.
Snapped meal photos are estimated by the AI meal analyser.

### Limitations

- Predictive equations estimate BMR; an individual's true value can differ
  by 10 % or more (more in very muscular people or those with obesity).
- PAL is self-chosen and people tend to overestimate their activity.
- Calories of mixed dishes vary a lot with oil, coconut milk and portion
  size, so logged intake is an estimate. Under-reporting is common in all
  food diaries.
- The target is not designed for pregnancy, breastfeeding, competitive
  athletes, eating disorders or medical diets. Those students should follow
  a health professional's advice.

---

## 3. Dietary diversity: a Sri Lankan Dietary Diversity Score

### Why VitalU no longer uses MDD-W

Earlier versions used the FAO **Minimum Dietary Diversity for Women
(MDD-W)**. It was designed and validated for **women aged 15 to 49**, but
VitalU's students are men and women. VitalU now uses the **dietary diversity
score (DDS) that Sri Lankan researchers have used for adult men and women**,
with the cut-off taken from the international evidence that also covers men.

### What it is

The score counts how many of **10 food groups** were eaten in a day, whatever
the amount (one point per group). The groups are those of Abeywickrama et
al. (2020), a Sri Lankan study of adult men and women. They adapted the
FAO and FANTA individual dietary diversity groups and the *Food Based Dietary
Guidelines for Sri Lankans* to the local diet:

| # | Group | Sri Lankan examples |
|---|-------|---------------------|
| 1 | Cereals | Red or white rice, string hoppers, roti, bread, pittu, kurakkan, noodles |
| 2 | Tubers and starchy vegetables | Manioc, sweet potato, potato, polos (young jackfruit), breadfruit, yams |
| 3 | Root and fruit vegetables | Carrot, pumpkin, beans, brinjal, cabbage, okra, beetroot, tomato |
| 4 | Green leafy vegetables | Gotukola, mukunuwenna, kankun, spinach, murunga leaves, thampala |
| 5 | Fruits | Banana, papaya, mango, guava, pineapple, orange, wood apple |
| 6 | Pulses, nuts and seeds | Dhal, chickpeas (kadala), green gram, cowpea, soya, peanuts, sesame |
| 7 | Meat and poultry | Chicken, beef, pork, mutton, sausages |
| 8 | Eggs | Boiled egg, egg curry, omelette, egg hoppers |
| 9 | Fish and seafood | Fish curry, sprats, dried fish, tinned fish, prawns |
| 10 | Milk and milk products | Milk, curd, yoghurt, cheese |

**Oils and fats, sugar and sweets, and spices, condiments and drinks are not
counted.** Abeywickrama et al. left them out because almost everyone in Sri
Lanka has them every day. Jayawardena et al. (2013) used a 12-group score
that included them, and found that a higher score went with more obesity and
a larger waist in Sri Lankan adults. Counting these groups makes a diet look
varied without making it healthier. Nuts and seeds are counted with pulses,
as in Jayawardena et al., except coconut, which is treated as a fat.

**Score:** 0 to 10 a day. **5 or more groups = minimum dietary diversity
met.**

### Why 5 groups for men and women

No study has validated a cut-off for this exact 10-group score in Sri Lankan
young adults, so the cut-off comes from the closest evidence:

- FAO's MDD-W uses **5 of 10 groups** as the level linked with adequate
  intake of 11 micronutrients in women.
- In 8 Latin American countries, Gómez et al. (2024) tested the same 5-group
  cut-off in **men** and in women of all ages. It balanced sensitivity and
  specificity for adequate micronutrient intake **as well in men as in
  women**.
- In Sri Lanka, Rathnayake et al. (2012) validated a dietary diversity score
  against nutrient adequacy in older men and women. The best cut-off was
  about **half the groups** (4.5 of 6), which matches 5 of 10.

The 10 groups are close to the MDD-W groups. The differences are that
cereals are separate from tubers, meat is separate from fish, and nuts are
counted with pulses. So the 5-group cut-off carries over sensibly.

### Dietary diversity findings in Sri Lanka

| Study | People | Score used | Main findings |
|-------|--------|------------|---------------|
| Jayawardena et al., 2013 | 600 adults (national sample, urban and rural) | 12 food groups, 24-h recall | Mean DDS 6.23 (men) vs 6.50 (women), not significantly different. Diversity varied with residence, ethnicity and education. Higher scores went with obesity and larger waist |
| Rathnayake et al., 2012 | 200 rural older adults | 6 groups from the national guidelines | Mean DDS 4.4. DDS correlated with nutrient adequacy (r = 0.48). Best cut-off 4.5 groups. Mean nutrient adequacy only 39% |
| Abeywickrama et al., 2020 | 120 rural adults (dry zone, men and women) | **10 groups (the score VitalU uses)** | Mean DDS 4.77 of 10. Only 1.7% met the fruit and 8.3% the vegetable recommendation. Starch and added sugar were high |
| Senanayake & Daundasekara, 2024 | 600 undergraduates, all 9 faculties, University of Peradeniya | FAO individual dietary diversity tool | Mean DDS 7.07 ± 1.71. 44.1% were food insecure, and food insecurity went with lower diversity (r = -0.21). 27% were underweight |
| Ralapanawa et al., 2023 | University of Peradeniya students | Metabolic syndrome survey | No student met the daily fruit and vegetable target |

Taken together, Sri Lankan diets are built on rice and other starches.
Fruit, vegetables, dairy and animal protein are the groups most often
missing. Men and women have similar diversity, and students who struggle to
afford food eat less varied diets. This is why VitalU shows which groups are
missing and suggests cheap ways to add them, and why the score is paired
with PDQS, which also measures quality.

### How VitalU counts it

- Each food in the food database is tagged with the groups of its main
  ingredients in a normal portion (e.g. "Rice & curry" → cereals, pulses,
  root and fruit vegetables). Condiments such as pol sambol or lunu miris,
  and a pinch of spice, are not counted. Following FAO guidance, a group
  needs about a tablespoon (15 g) to count.
- Logging a meal records each group once for that day. Students can also
  tick a group directly in the Dietary diversity guide.
- The guide shows today's score out of 10, which groups are missing, and a
  7-day chart of groups per day with a line at 5.
- Logs saved with the old MDD-W groups are mapped to the new groups, both
  in the app (`legacyGroupKey`) and in the database (`dds_group`). Where an
  old group was split, the food's name decides: "meat and fish" becomes
  fish for a fish curry and meat for a chicken curry, and "grains" becomes
  tubers for potato or manioc.

### Limitations

- The 5-group cut-off for this score is **borrowed** from FAO and from
  studies in other countries. It has not been validated against nutrient
  intake in Sri Lankan university students.
- It measures **variety, not quantity or quality**. A day with 6 groups can
  still be high in fried food, sugar or salt, and a group counts the same
  whether 15 g or 300 g was eaten.
- It is a **population-level indicator**. It is best for comparing groups of
  students; for one person on one day it is only a rough sign of diet
  variety.
- Counting depends on what students log, and the 15 g threshold is
  approximated by the food tags rather than measured.

### References

- Abeywickrama HM, Wimalasiri KMS, Koyama Y, et al. Assessment of nutritional status and dietary pattern of a rural adult population in dry zone, Sri Lanka. *Int J Environ Res Public Health.* 2020;17(1):150. <https://doi.org/10.3390/ijerph17010150>
- Jayawardena R, Byrne NM, Soares MJ, Katulanda P, Yadav B, Hills AP. High dietary diversity is associated with obesity in Sri Lankan adults: an evaluation of three dietary scores. *BMC Public Health.* 2013;13:314. <https://doi.org/10.1186/1471-2458-13-314>
- Rathnayake KM, Madushani P, Silva K. Use of dietary diversity score as a proxy indicator of nutrient adequacy of rural elderly people in Sri Lanka. *BMC Res Notes.* 2012;5:469. <https://doi.org/10.1186/1756-0500-5-469>
- Gómez G, Monge-Rojas R, Vargas-Quesada R, et al. Exploring the FAO Minimum Dietary Diversity Indicator as a suitable proxy of micronutrient adequacy in men and women across reproductive and non-reproductive ages in 8 Latin American countries. *Food Nutr Bull.* 2024;45(2 suppl):S55-S65. <https://doi.org/10.1177/03795721241242920>
- Senanayake HRV, Daundasekara DMSS. Prevalence and predictors of food insecurity among undergraduate students residing on campus: a case study at University of Peradeniya, Sri Lanka. *iPURSE 2024 Proceedings*, p. 227. <https://ir.lib.pdn.ac.lk/items/b4270390-b4b8-4b0d-bbb4-b8f58bcf9a4b>
- Ralapanawa DMPUK, et al. Prevalence of metabolic syndrome and its components among university students at the University of Peradeniya. *iPURSE 2023 Proceedings.*
- Kennedy G, Ballard T, Dop MC. *Guidelines for Measuring Household and Individual Dietary Diversity.* Rome: FAO; 2011.
- FAO. *Minimum Dietary Diversity for Women: An Updated Guide for Measurement, from Collection to Action.* Rome: FAO; 2021.
- Nutrition Division, Ministry of Health. *Food Based Dietary Guidelines for Sri Lankans.* 2nd ed. Colombo; 2011.

---

## 4. Diet quality: Prime Diet Quality Score (PDQS)

### What it is

PDQS (Fung et al., 2018) scores the whole diet over the **past 7 days**
across **21 food groups**:

- **14 healthy groups:** dark green leafy vegetables, cruciferous vegetables,
  carrots, other vegetables, whole citrus fruits, other whole fruits, pulses
  and legumes, nuts and seeds, poultry, fish, eggs, whole grains, liquid
  vegetable oils, low-fat dairy.
- **7 less healthy groups:** red meat, processed meat, refined grains and
  baked goods, sugar-sweetened drinks, desserts and ice cream, fried food
  eaten away from home, potatoes.

Each group is scored by servings in the week:

| Servings / week | Healthy group | Less healthy group |
|-----------------|---------------|--------------------|
| 0 to 1          | 0             | 2                  |
| 2 to 3          | 1             | 1                  |
| 4 or more       | 2             | 0                  |

**Total: 0 to 42.** Higher means a healthier diet. PDQS has been linked to
lower risk of cardiometabolic disease and to nutrient adequacy, and unlike
the dietary diversity score it penalises unhealthy foods.

### Why VitalU uses PDQS

- **It measures quality, not just variety.** The dietary diversity score shows whether a diet is
  varied. PDQS also shows whether it is healthy, because fried short eats,
  sweet drinks and refined grains lower the score.
- **It works for food-based, low-cost assessment.** It needs only "how many
  servings of each group this week", not weighed food or nutrient tables. It
  was designed for use across countries, including low- and middle-income
  settings, and has been validated against nutrient adequacy and
  cardiometabolic outcomes.
- **It fits the risks found in Sri Lankan students.** Studies of Sri Lankan
  undergraduates found low fruit and vegetable intake and frequent fried and
  sugary snacks. These are exactly the groups PDQS rewards and penalises.
- **Its groups map onto local foods.** Every PDQS group has Sri Lankan
  examples (gotukola, kurakkan, kadala, short eats, kavum). That lets the app
  tag each food in its database and estimate the score from meal logs.

VitalU reading of the score (PDQS has no official cut-offs, so these are
app bands, not clinical categories): **28 or more** good, **21 to 27** fair,
**below 21** room to improve.

### Two ways VitalU gets the score

1. **Weekly check-in:** the student answers the 21 questions directly
   ("how many servings this week?"). This is the standard method.
2. **From meal logs:** every food in the database is also tagged with its
   PDQS groups (e.g. red rice → whole grains; fish bun → refined grains and
   fried food away from home). Each logged food counts as one serving of each
   of its groups over the last 7 days, and the same scoring table is applied.
   The Diet home card shows this score when meals have been logged.

### Limitations of the logged estimate

- **One logged food = one serving**, whatever the amount, so servings are
  approximate.
- **Missing logs inflate the score**: a less healthy group that was eaten but
  not logged scores 2 points as if avoided. For that reason the app labels
  the estimate as reliable only when at least **4 of the 7 days** have logged
  meals, and invites students to do the check-in otherwise.
- Liquid oils and low-fat dairy are hard to see in mixed dishes, so they tend
  to be under-counted.
- Like all self-reported diet measures, it is affected by recall and by
  students logging "better" meals than they ate.

---

## 5. Smart Eater badge

Smart Eater recognises a **health-conscious eater over a whole week**. It is
awarded when, for **7 days in a row**, the student:

1. logged **breakfast, lunch and dinner** (regular meals), and
2. ate from **5 or more of the 10 dietary diversity groups** each day (variety), and
3. over those 7 days, reached a **PDQS of at least 22 out of 42** from the
   meal logs (quality).

### Why these three rules

- **Regular meals.** Meal skipping, especially breakfast, is common among
  university students and is linked to poorer diet quality and snacking.
- **Variety (5 or more of 10 groups).** Five groups is the cut-off for
  minimum dietary diversity. It means the day's diet is likely to cover the
  main micronutrients.
- **Quality (PDQS ≥ 22).** Variety alone can be met with fried snacks and
  sweet drinks, because the diversity score does not penalise unhealthy foods. PDQS does.
  It gives up to 2 points for each of 14 healthy groups and takes points
  away for 7 less healthy ones. A score of 22 is more than half of the
  possible 42 points. A student reaches it by eating several healthy
  groups on 2 or more days of the week (2 to 3 servings scores 1 point,
  4 or more scores 2) while keeping most of the less healthy groups to
  0 or 1 serving a week. PDQS has no official cut-off, so 22 is a VitalU
  threshold: more than half the points, and above the bottom of the app's
  "fair" band (21 to 27), so a borderline week does not earn the badge.

### What counts as one serving

PDQS counts servings, so each group has a defined serving. The app shows it
with the group's picture and a hand-size guide (cupped hand, fist, palm or
thumb) on the diet quality check-in. The assessment's 7-day food questions
use the same definitions.

| PDQS group | Examples | One serving |
|------------|----------|-------------|
| Dark green leafy vegetables | Gotukola, mukunuwenna, kankun, spinach | ½ cup cooked or as mallum |
| Cabbage-family vegetables | Cabbage, cauliflower, broccoli, knol-khol | ½ cup cooked, or 1 cup raw |
| Carrots | Raw, in salads or curries | ½ cup chopped, or 1 medium carrot |
| Other vegetables | Beans, brinjal, okra, pumpkin, gourds, tomato | ½ cup cooked |
| Whole citrus fruits | Orange, mandarin, lime (not juice) | 1 orange, or 2 small mandarins |
| Other whole fruits | Banana, papaya, guava, mango, pineapple | 1 medium fruit, or ½ cup cut fruit |
| Pulses and legumes | Dhal, kadala, green gram, cowpea | ½ cup cooked |
| Nuts and seeds | Peanuts, cashews, sesame | 2 tablespoons, a small handful |
| Poultry | Chicken | A palm-sized piece |
| Fish | Fresh fish, sprats, tinned fish | A palm-sized piece |
| Eggs | Boiled, curried, omelette | 1 egg |
| Whole grains | Red rice, kurakkan, oats, atta | 1 cup cooked rice, or 1 roti |
| Liquid vegetable oils | Sunflower, soybean, gingelly, olive | 1 tablespoon |
| Low-fat dairy | Low-fat milk, curd, yoghurt | 1 glass of milk (200 ml) or 1 small cup of curd |
| Red meat | Beef, pork, mutton | A palm-sized piece |
| Processed meat | Sausages, meatballs, ham, nuggets | 1 sausage, 2 slices of ham, or 3 nuggets |
| Refined grains and baked goods | White rice, white bread, buns, biscuits | 1 cup cooked white rice, 2 slices of bread, or 1 bun |
| Sugar-sweetened drinks | Soft drinks, sweet milk tea, packet juice | 1 glass or small bottle (200 ml) |
| Desserts and ice cream | Cake, kavum, chocolate, ice cream | 1 piece, or 1 scoop of ice cream |
| Fried food from outside | Short eats, rolls, fried rice, kottu | 1 short eat, or 1 plate |
| Potatoes | Potato curry, chips, fries | ½ cup potato curry or chips |

The badge is awarded by the database (`refresh_badges`), and the Diet home
and Achievements screens show progress as one star for each day of the
current streak, with the week's PDQS beside it.

---

## 6. CVD risk indicator

### What it is

A **factor-based awareness tool**, not a validated risk equation. It does not
calculate a 10-year heart attack probability (as the WHO/ISH charts or
Framingham score do), because those equations are designed for people aged
40 and over and need laboratory values most students do not have. Instead it
shows how many known cardiovascular risk factors a student has, so they can
see what to work on.

### Points

Every question is optional; skipped questions are left out of both the score
and the maximum.

| Factor | 0 points | 1 point | 2 points | 3 points |
|--------|----------|---------|----------|----------|
| Age | under 30 | 30 to 45 | 46 to 60 | over 60 |
| Sex | female | male | – | – |
| BMI | below 25 | 25 to 29.9 | 30 or more | – |
| Smoking | never | occasional | daily | – |
| Physical activity | active | rarely | inactive | – |
| Family history of early heart attack | no | – | yes | – |
| Diabetes (diagnosed) | no | – | yes | – |
| High blood pressure (diagnosed) | no | – | yes | – |
| Blood pressure reading (mmHg) | below 120/80 | below 140/90 | 140/90 or more | – |
| Fasting blood sugar (mg/dL) | below 100 | 100 to 125 | 126 or more | – |
| Total cholesterol (mg/dL) | below 200 | 200 to 239 | 240 or more | – |

### Result

```
Score      = sum of points for the factors answered
Maximum    = sum of the highest possible points for those same factors
Proportion = Score ÷ Maximum
```

| Proportion | Result |
|------------|--------|
| below 35 % | Low |
| 35 % to 59 % | Moderate |
| 60 % or more | High |

Using a proportion of the factors actually answered means a student who
skips the laboratory questions is not given a falsely low or high result.

### Worked example: a result shown as "of 20"

The result ring shows the score over the maximum, for example "5 of 20".
The maximum is not fixed. It is the sum of the highest points for the
questions the student answered:

- All 11 factors answered: 3 (age) + 1 (sex) + 9 × 2 (every other factor)
  = **22**.
- One 2-point factor skipped, such as total cholesterol: 22 − 2 = **20**.
- Both fasting blood sugar and cholesterol skipped: 22 − 4 = **18**.

Results saved before the app started storing the maximum also show "of 20".

A student who answers everything except cholesterol:

| Factor | Answer | Points | Highest possible |
|--------|--------|--------|------------------|
| Age | 22 years (under 30) | 0 | 3 |
| Sex | female | 0 | 1 |
| BMI | 26.0 (25 to 29.9) | 1 | 2 |
| Smoking | never | 0 | 2 |
| Physical activity | rarely | 1 | 2 |
| Family history of early heart attack | yes | 2 | 2 |
| Diabetes (diagnosed) | no | 0 | 2 |
| High blood pressure (diagnosed) | no | 0 | 2 |
| Blood pressure reading | 125/82 mmHg | 1 | 2 |
| Fasting blood sugar | 95 mg/dL | 0 | 2 |
| Total cholesterol | skipped | – | – |
| **Total** | | **5** | **20** |

Proportion = 5 ÷ 20 = 25 %, which is below 35 %, so the result is **Low**.
The app shows "5 of 20, Low risk". The contributing factors list marks
BMI, physical activity and blood pressure as "Some risk" (1 point) and
family history as "Higher risk" (2 points).

The same student would reach Moderate at 7 points (35 % of 20) and High at
12 points (60 % of 20). A score of 20 on its own would mean every answered
factor scored its maximum: 20 of 20 (100 %) or 20 of 22 (91 %), both High.
The cut-offs for each factor follow common clinical thresholds (WHO BMI
categories, American Diabetes Association fasting glucose, NCEP ATP III
cholesterol, and the 120/80 and 140/90 blood pressure levels).

### Limitations

- It is **not a validated prediction score** and should not be used for
  diagnosis or to decide on treatment. A "high" result means "talk to a
  doctor", and the app always offers that option.
- Factors are equally weighted in simple steps, whereas real risk combines
  them in a non-linear way (smoking and diabetes, for example, matter more
  than sex at a young age).
- WHO BMI cut-offs are used; Asian populations develop cardiometabolic risk
  at lower BMI (≥ 23), so risk in Sri Lankan students may be
  underestimated.
- Most students are young, so their absolute risk is low; the tool's value is
  in showing modifiable habits (smoking, inactivity, weight) early.
