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

## 3. Dietary diversity: MDD-W

### What it is

VitalU uses the **Minimum Dietary Diversity for Women (MDD-W)**, an indicator
published by the Food and Agriculture Organization (FAO) and FHI 360 (2016,
updated 2021). It counts how many of **10 food groups** were eaten in a day:

1. Grains, white roots and tubers, and plantains
2. Pulses (beans, peas and lentils)
3. Nuts and seeds
4. Dairy
5. Meat, poultry and fish
6. Eggs
7. Dark green leafy vegetables
8. Other vitamin A-rich fruits and vegetables
9. Other vegetables
10. Other fruits

A food counts only if at least about **15 g** (one tablespoon) was eaten.

**Score:** 0 to 10 a day. **5 or more groups = minimum dietary diversity
met.**

### Why this tool was chosen

- It is **validated**: in women aged 15 to 49, eating from 5 or more groups
  is associated with a higher probability of adequate intake of 11
  micronutrients (vitamin A, thiamine, riboflavin, niacin, vitamin B6,
  folate, vitamin B12, vitamin C, calcium, iron and zinc).
- It is **simple and quick**: yes/no per group, no weighing or nutrient
  calculation, so it can be counted automatically from meal logs.
- It suits **Sri Lankan, mostly rice-based diets**, where the main nutrition
  problem is often a monotonous diet (rice with few side dishes) rather than
  too little energy.
- It is used internationally, so results can be compared with other studies.

### How VitalU counts it

- Each food in the food database is tagged with the MDD-W groups of its main
  ingredients in a normal portion (e.g. "Rice & curry" → grains, pulses,
  other vegetables). Condiments such as pol sambol or lunu miris, and a
  pinch of spice, are not counted, in line with the 15 g rule.
- Logging a meal records each group once for that day. Students can also
  tick a group directly in the Dietary diversity guide.
- The guide shows today's score out of 10, which groups are missing, and a
  7-day chart of groups per day with a line at 5.

### Limitations

- MDD-W is validated for **women of reproductive age**. VitalU applies it to
  all students as a practical guide; for men it is a reasonable but not
  formally validated proxy.
- It measures **variety, not quantity or quality**. A day with 6 groups can
  still be high in fried food, sugar or salt, and a group counts the same
  whether 15 g or 300 g was eaten.
- It is a **population-level indicator**. It is best for comparing groups of
  students; for one person on one day it is only a rough sign of diet
  variety.
- Counting depends on what students log, and the 15 g threshold is
  approximated by the food tags rather than measured.

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
MDD-W it penalises unhealthy foods.

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

Awarded for **7 days in a row** on which the student:

1. logged **breakfast, lunch and dinner**, and
2. ate from **5 or more MDD-W food groups**.

It rewards both regular meals (meal skipping, especially breakfast, is
common among university students) and a varied diet. The badge is awarded by
the database (`refresh_badges`), and the Diet home shows progress as stars
for each day of the current streak. (The 3-day **Rainbow Plate** badge
rewards 5 or more groups alone.)

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
