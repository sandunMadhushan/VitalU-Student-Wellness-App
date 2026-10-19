# VitalU pilot evaluation form

A short form for feedback after the VitalU pilot at the University of Peradeniya. It reviews the student app and the admin dashboard, asks how likely people are to take part in the periodic health assessment, asks what to improve, and asks whether an initiative like this could change young people's habits.

Revised after the researcher's review of the first version (changes are listed at the end of Part 1).

This document has three parts:

1. **The forms**: every question, who sees it, and how answers are coded.
2. **The analysis plan**: how to turn the answers into findings, including the Wilcoxon signed-rank test.
3. **Notes for the website**: how this is built and where responses go.

---

## Part 1. The forms

### Two forms, one base

At the entry to the form, after pressing **Give feedback**, the respondent chooses one of two roles. Each role gets its own form, built from the same base questions with different wording.

| | Form A: undergraduate students | Form B: lecturers, administration or health centre staff, technical experts |
|---|---|---|
| What they evaluate | The student app, from their own use | The student app, for students, **and** the admin dashboard |
| Feature wording | "How useful **was** each feature **for you**?" | "How useful **do you think** each feature **will be for students**?" |
| Admin dashboard | Not shown (students have no access) | Shown, as one open comment |
| Faculty, batch, sex | Asked | Not asked |
| Periodic assessment | Their own likelihood to complete it | Related questions about its value and uptake |
| Before and after | Asked | Not asked |
| Time | About 6 to 8 minutes | About 4 to 6 minutes |

Because the role is chosen at the entry, the form no longer asks "Which describes you best?" or "Which parts of VitalU did you use?".

### Design rules

- **Anonymous.** No name, email, registration number or phone number is asked.
- **Mostly taps.** Every rating uses a 1 to 5 scale. Only a few text boxes, all optional.
- **No page reloads.** Choosing an answer only records it. The page does not redraw, jump or reload, and the person stays where they are. The feature cards change in place.
- **Mobile first.** One section per screen, a progress bar, large tap targets, and the person's place is remembered if the page is refreshed.

### Answer scales

| Name | 1 | 2 | 3 | 4 | 5 |
|------|---|---|---|---|---|
| Agreement | Strongly disagree | Disagree | Neutral | Agree | Strongly agree |
| Usefulness (faces) | Not useful | Slightly | Moderately | Very useful | Extremely |
| Likelihood | Very unlikely | Unlikely | Not sure | Likely | Very likely |
| Value | Not valuable | Slightly | Moderately | Valuable | Very valuable |

"Did not use" (students) and "Not sure" (staff) are saved as blank, not 0.

### Screens in order

| # | Screen | Form A | Form B |
|---|--------|:------:|:------:|
| 0 | Choose your role | ✓ | ✓ |
| 1 | Welcome and consent | ✓ | ✓ |
| 2 | About you | ✓ | |
| 3 | Using the student app (usability, part 1) | ✓ | ✓ |
| 4 | Using the student app (usability, part 2, and look and feel) | ✓ | ✓ |
| 5 | Student app features | ✓ | ✓ |
| 6 | Favourite feature | ✓ | ✓ |
| 7 | Before and after VitalU | ✓ | |
| 8 | The admin dashboard | | ✓ |
| 9 | The periodic health assessment | ✓ | ✓ |
| 10 | The bigger picture (adoption and impact) | ✓ | ✓ |
| 11 | What should we improve? | ✓ | ✓ |
| 12 | In your own words | ✓ | ✓ |

---

### Screen 0. Choose your role

Two large buttons. Pressing one starts the matching form.

| Code | Role |
|------|------|
| 1 | Undergraduate student |
| 2 | Lecturer, administration or health centre staff, technical expert |

A link ending `?g=student` or `?g=staff` selects the role in advance and skips this screen. **Back** returns to it.

### Screen 1. Welcome and consent

> **Help us improve VitalU**
>
> You took part in the VitalU pilot. This short form asks what worked, what did not and what we should improve. It takes about 5 to 7 minutes.
>
> - Your answers are anonymous and taking part is voluntary. You can skip any question or stop at any time. Results are reported only as group totals in the research project *"Development of an ADDIE-Based Mobile Health Platform to Improve Cardiometabolic Health among Undergraduate Students"* by Miss. W.M.O.P.Wijesooriya attached to the Department of Food Science and Technology, Faculty of Agriculture, University of Peradeniya.
> - Questions? Contact at fst20052@agri.pdn.ac.lk or +94 777 434769.

| ID | Question | Answers |
|----|----------|---------|
| `consent` | Do you agree to take part? | 1 = Yes, I have read the information and agree · 0 = No (ends the form) |

### Screen 2. About you (Form A only)

| ID | Question | Codes |
|----|----------|-------|
| `faculty` | Your faculty | 1 Agriculture · 2 Allied Health Sciences · 3 Arts · 4 Dental Sciences · 5 Engineering · 6 Management · 7 Medicine · 8 Science · 9 Veterinary Medicine and Animal Science |
| `year` | Your batch | 1 = 1st year · 2 = 2nd year · 3 = 3rd year · 4 = 4th year or above |
| `sex` | Sex | 1 = Female · 2 = Male · 3 = Prefer not to say |
| `freq` | How often did you open the student app? | 1 = Once or twice · 2 = About once a week · 3 = A few times a week · 4 = Daily or almost daily |

`sex` decides whether students see the cycle tracker in the feature list.

### Screens 3 and 4. Using the student app (both forms)

Agreement scale, all required in this section so the score can be worked out. Form B's introduction reads "Think about your experience trying the VitalU app, even if it was brief."

These are eight of the ten System Usability Scale items (Brooke, 1996; "system" is "app" and "cumbersome" is "awkward", after Finstad, 2006). Items 9 ("I felt very confident using the app") and 10 ("I needed to learn a lot of things before I could get going") were removed because they repeat items 3 and 7.

| ID | Statement |
|----|-----------|
| `us1` | I think that I would like to use this app frequently. |
| `us2` | I found the app unnecessarily complex. |
| `us3` | I thought the app was easy to use. |
| `us4` | I think that I would need the support of a technical person to be able to use this app. |
| `us5` | I found the various functions in this app were well integrated. |
| `us6` | I thought there was too much inconsistency in this app. |
| `us7` | I would imagine that most people would learn to use this app very quickly. |
| `us8` | I found the app very awkward to use. |

**Look and feel** (agreement scale, optional, shown with `us6` to `us8`):

| ID | Statement |
|----|-----------|
| `ui_look` | The screens, animations, illustrations and images made VitalU clearer and more pleasant to use. |

### Screen 5. Student app features

One card per feature, each rated with five faces. A tap moves to the next card. Options: faces 1 to 5, or **Did not use** (Form A) / **Not sure** (Form B).

| ID | Feature |
|----|---------|
| `f_body` | Body checks: BMI and waist-to-hip ratio calculators |
| `f_heart` | Heart health check: CVD risk indicator |
| `f_mind` | Anxiety tracker: DASS-21 self-check, calm music and relaxation ideas |
| `f_water` | Water tracker: daily goal, bottle and reminders |
| `f_move` | Activity and sleep trackers |
| `f_cycle` | Cycle tracker (Form A: only if `sex` = 1; Form B: always) |
| `f_diet` | Diet tools: calorie counter, meal diary, healthy plate, diversity guide, budget planner |
| `f_learn` | Learn articles |
| `f_badges` | Badges and streaks |
| `f_notify` | Reminders |
| `f_help` | Getting help: ask anonymously, campus professionals, emergency numbers |
| `f_report` | Your progress: home dashboard, summary and personal health report (PDF) |

### Screen 6. Favourite feature

| ID | Question | Answer |
|----|----------|--------|
| `fav_feature` | Form A: Which feature of the app did you like the most? Form B: Which feature do you think students will like the most? | One of the feature IDs above, or `none` |

### Screen 7. Before and after VitalU (Form A only)

Each statement is rated twice on the agreement scale, **before** the pilot and **now**.

| ID before | ID now | Statement |
|-----------|--------|-----------|
| `pp1_pre` | `pp1_post` | I understand what my own health numbers (BMI, waist, blood pressure) mean. |
| `pp2_pre` | `pp2_post` | I pay attention to how balanced and varied my meals are. |
| `pp3_pre` | `pp3_post` | I drink enough water and stay active most days. |
| `pp4_pre` | `pp4_post` | I know where to get health or mental health support on campus. |

These four pairs are what the **Wilcoxon signed-rank test** is run on (Part 2, step 4).

### Screen 8. The admin dashboard (Form B only)

Students have no access to the dashboard, so only Form B asks about it. To keep the two forms close, it is one optional comment, not a set of ratings.

| ID | Question |
|----|----------|
| `d_comment` | What are your comments on the admin dashboard? (Optional. For example: how easy it is to use, what is missing, or what would help you plan student health support.) |

### Screen 9. The periodic health assessment

Form A, about the student's own use:

| ID | Question | Answers |
|----|----------|---------|
| `pa_likely` | How likely are you to complete the next six-monthly periodic health assessment in VitalU? | Likelihood scale |
| `pa_done` | Did you complete the periodic health assessment during the pilot? | 1 = Yes · 2 = Started but did not finish · 3 = No · 4 = It was not open for my faculty |
| `pa_reasons` | What would make you more likely to complete it? (Optional, up to 2.) | `r_short` It being shorter · `r_remind` A reminder when it opens · `r_results` Seeing my own results afterwards · `r_privacy` Being sure it is anonymous · `r_time` A quieter time in the semester · `r_other` Other (with `pa_reasons_other`) |

Form B, related questions about the same process:

| ID | Question | Scale |
|----|----------|-------|
| `pa_value` | How valuable do you think a six-monthly periodic health assessment is for understanding and supporting student health? | Value |
| `pa_students` | How likely do you think students are to complete it every six months? | Likelihood |
| `pa_use` | How likely are you to encourage students to complete it, or to use its pooled results in your work? | Likelihood |

### Screen 10. The bigger picture (both forms)

Introduction shown above the questions:

> A health monitoring system like VitalU is being introduced at a university in Sri Lanka for the very first time. Its impact builds with long-term use, so these questions ask what you expect over time.

| ID | Question | Scale |
|----|----------|-------|
| `adopt_pref` | Form A: I would like to keep using VitalU. Form B: I would support rolling VitalU out to all students at the university. | Agreement. This is the **overall adoption preference**. |
| `adopt_students` | How likely do you think students at the university are to adopt VitalU and keep using it? | Likelihood |
| `impact` | I think an initiative like VitalU can change young people's lifestyles and habits, and help build a healthier generation of young adults. | Agreement |

### Screen 11. What to improve

| ID | Question | Type |
|----|----------|------|
| `improve_pick` | Which areas should we improve first? (Select up to 3.) | `i_speed` Speed and reliability · `i_design` Look and layout · `i_easy` Easier to understand · `i_diet` Diet tools and food list · `i_trackers` Trackers · `i_learn` Learn articles · `i_notify` Reminders and notifications · `i_help` Health support and consultations · `i_dash` Admin dashboard (Form B only) · `i_lang` Sinhala and Tamil language options · `i_other` Other (with `improve_other`) |

### Screen 12. In your own words

Both optional. "Please do not include names or anything that could identify you or others."

| ID | Question |
|----|----------|
| `open_overall` | Do you have any overall comments about the VitalU initiative? |
| `open_improve` | What should we change, fix or add? (Please be as specific as you can.) |

### Length check

| Form | Screens | Time |
|------|---------|------|
| A: undergraduate students | 12 | 6 to 8 minutes |
| B: lecturers, administration, staff and experts | 11 | 4 to 6 minutes |

### What changed after the researcher's review

| Request | What was done |
|---------|---------------|
| The page keeps refreshing when moving forward and choosing answers | Choosing an answer no longer redraws the page. The question about parts used, which caused a redraw, is gone, and the feature cards swap in place. The person's place is also saved. |
| Choose a role at the entry; two roles | New first screen with two roles. "Which describes you best?" removed. |
| Two customised forms from one base | Forms A and B, with student wording ("was useful for you") and staff wording ("will be useful for students"). |
| Dashboard only for the second group; one open comment | Screen 8, Form B only, one comment. The six dashboard ratings were removed. |
| Faculty only for undergraduates | Faculty, batch and sex are asked in Form A only. |
| Remove "Which parts of VitalU did you use?" | Removed. |
| Periodic assessment only for students; related questions for lecturers | Form B gets `pa_value`, `pa_students` and `pa_use`. |
| Scale question for overall adoption preference | `adopt_pref` and `adopt_students`. |
| One question as an overall comment about the initiative | `open_best` became `open_overall`. |
| Favourite feature | `fav_feature`. |
| Explain that this is the first such system in Sri Lanka, and ask about long-term change and adoption | Introduction text, `impact`, `adopt_students`. |
| Remove repeated usability items; ask about interface, animations, illustrations and images | Items 9 and 10 removed. `ui_look` added. |
| Contact details and wording on the consent screen | Updated as requested, with the phone number added. |

The "likely to recommend VitalU to a fellow student" question was also dropped, because the adoption questions now cover the same idea.

---

## Part 2. How to analyse the responses

Use free tools: **jamovi** (point and click), **R**, or Python with `pandas` and `scipy`. SPSS works too. Export the responses as a CSV (one row per respondent, the IDs above as column names). **Always analyse Form A and Form B separately first**, because the same feature question means something different in each: what students found useful versus what staff expect to be useful.

### Step 1. Clean the data

1. Remove rows where `consent` is not 1.
2. Remove clear duplicates: same answers in every column, submitted minutes apart.
3. Remove **straight-liners** from the usability items: people who chose the same answer for all eight. Half the items are negatively worded, so identical answers mean they did not read them. Report how many.
4. Leave blank cells as missing. Do not turn "Did not use" or "Not sure" into 0 or 3.

### Step 2. Describe who answered

Report counts and percentages for `role`, and, for undergraduates, `faculty`, `year`, `sex` and `freq`. Give a response rate per group if you know how many were invited: `completed forms ÷ people invited × 100`.

### Step 3. Usability score

The CSV includes `usability_score` (0 to 100), worked out from `us1` to `us8` for anyone who answered all eight. To work it out yourself:

1. Odd items (`us1`, `us3`, `us5`, `us7`): subtract 1 from the answer.
2. Even items (`us2`, `us4`, `us6`, `us8`): subtract the answer from 5.
3. Add the 8 results (0 to 32), divide by 32, multiply by 100.

In R:

```r
odd  <- c("us1","us3","us5","us7")
even <- c("us2","us4","us6","us8")
d$usability <- (rowSums(d[odd] - 1) + rowSums(5 - d[even])) / 32 * 100
```

**Report** mean, standard deviation, median and interquartile range, for each form.

> **Important.** With items 9 and 10 removed this is **not a standard SUS score**, so the published benchmarks (68 is average, above 80 is excellent) cannot be applied to it. Describe it as "a usability score from eight System Usability Scale items" and compare it only within your own data (students against staff) and across future rounds. If you later need the benchmarks, ask all ten items.

Example sentence: *"Undergraduates rated usability at a mean of 78.1 out of 100 (SD 11.5, n = 42), using eight items adapted from the System Usability Scale."*

### Step 4. Before and after: the Wilcoxon signed-rank test (Form A)

#### Why this test

Each student rated the same statement twice ("before" and "now"), so the two answers are **paired**. Likert answers are **ordinal**, not truly numeric, and small samples are rarely normally distributed. The Wilcoxon signed-rank test is the standard non-parametric test for paired ordinal data. It asks: *are the "now" ratings consistently higher (or lower) than the "before" ratings?*

#### How it works, in five steps

For one statement, say `pp1`:

1. **Difference.** For each student, `d = now − before`.
2. **Drop zeros.** Students with no change (`d = 0`) are set aside. *n* is the number left.
3. **Rank.** Rank the absolute differences `|d|` from smallest (rank 1) to largest. Tied values get the average of the ranks they cover.
4. **Sum by sign.** Add the ranks of the positive differences (**W+**) and of the negative ones (**W−**).
5. **Compare.** If nothing changed, W+ and W− should be similar. The bigger the gap, the stronger the evidence of change. The p-value tells you how likely a gap this big is by chance.

#### Worked example (made-up numbers)

Eight students rate *"I understand what my own health numbers mean"*:

| Student | Before | Now | d | \|d\| | Rank | Signed rank |
|---------|--------|-----|---|-------|------|-------------|
| A | 2 | 4 | +2 | 2 | 5 | +5 |
| B | 3 | 4 | +1 | 1 | 2 | +2 |
| C | 2 | 2 | 0 | | dropped | |
| D | 1 | 3 | +2 | 2 | 5 | +5 |
| E | 3 | 5 | +2 | 2 | 5 | +5 |
| F | 4 | 4 | 0 | | dropped | |
| G | 2 | 3 | +1 | 1 | 2 | +2 |
| H | 3 | 2 | −1 | 1 | 2 | −2 |

- *n* = 6, after dropping C and F.
- The three 1s share ranks 1, 2 and 3, so each gets 2. The three 2s share ranks 4, 5 and 6, so each gets 5.
- **W+** = 5 + 2 + 5 + 5 + 2 = **19**. **W−** = **2**.
- Under "no change" the expected W+ is n(n+1)/4 = 10.5.
- Spread: √(n(n+1)(2n+1)/24 − tie correction) = √(22.75 − 1) = 4.66. The tie correction is Σ(t³ − t)/48 over each group of t tied values: (24 + 24)/48 = 1.
- **z** = (19 − 10.5) / 4.66 = **1.82**, two-tailed **p ≈ 0.07**.
- **Effect size r** = z / √n = 1.82 / √6 = **0.74**.
- Medians: before = 2.5, now = 3.5.

With only 6 students who changed, a fairly large shift still does not reach p < 0.05. Aim for **at least 20 to 30 students** completing this screen.

#### Running it

| Tool | How |
|------|-----|
| jamovi | T-Tests → Paired Samples T-Test → move `pp1_pre` and `pp1_post` in → tick **Wilcoxon rank**, untick Student's, tick **Effect size** |
| SPSS | Analyze → Nonparametric Tests → Legacy Dialogs → 2 Related Samples → Wilcoxon |
| R | `wilcox.test(d$pp1_post, d$pp1_pre, paired = TRUE, exact = FALSE)` |
| Python | `scipy.stats.wilcoxon(df.pp1_post, df.pp1_pre, zero_method="wilcox")` |

R does not print z. Get it from the p-value with `z <- qnorm(p / 2, lower.tail = FALSE)`, or use `rstatix::wilcox_effsize()`, which gives r directly.

#### Four tests, so adjust the p-values

You run the test four times (pp1 to pp4), so correct for multiple testing with the **Holm** method: `p.adjust(c(p1, p2, p3, p4), method = "holm")`.

#### Reading the effect size r

| r | Size of change (Cohen, 1988) |
|---|-------------------------------|
| 0.1 | Small |
| 0.3 | Medium |
| 0.5 or more | Large |

#### Reporting

| Statement | Before median (IQR) | Now median (IQR) | Improved / same / worse | z | p (Holm) | r |
|-----------|--------------------|------------------|-------------------------|---|----------|---|
| Understand my health numbers | | | | | | |
| Balanced and varied meals | | | | | | |
| Water and activity | | | | | | |
| Know where to get help | | | | | | |

#### Limitation to state honestly

This is a **retrospective pre-test**: "before" is remembered, not measured at the start. It is accepted in programme evaluation and avoids response-shift bias (Howard, 1980), but it can overstate change if people want to please the researchers. Report it as **self-perceived change**, not proof that behaviour changed.

### Step 5. Feature usefulness

For each feature, in each form separately:

- **Rated by:** % who gave a rating (not blank).
- **Median and IQR** of the 1 to 5 rating.
- **% useful:** % who chose 4 or 5.

Present all 12 as a **diverging stacked bar chart**, sorted by % useful. Then compare the two forms side by side: *"Do staff expect the same features to be useful that students actually found useful?"* Where they differ most is a useful finding in itself. A **Mann-Whitney U test** per feature (Holm-corrected) can test the difference.

*Optional:* a **one-sample Wilcoxon signed-rank test** against 3 ("moderately useful") shows whether a feature was rated reliably above the middle: `wilcox.test(d$f_water, mu = 3)`. Holm-correct across the 12 features.

**Favourite feature.** Count `fav_feature` per form and show as a bar chart. Compare what students chose with what staff predicted students would choose.

### Step 6. Look and feel

Report the median and % agree (4 or 5) for `ui_look`, per form. It is one item, so keep it descriptive. Read it together with the "Look and layout" choice in the improvement list and the written comments.

### Step 7. Admin dashboard (Form B)

`d_comment` is open text. Use **thematic analysis** (step 10). Count how many staff commented, group the comments into themes (for example *Ease of use*, *Missing features*, *Analytics*, *Privacy*), and quote a few.

### Step 8. Periodic health assessment

**Form A (students)**
- Report `pa_likely` as % likely or very likely (4 or 5) and the median.
- Cross-tabulate with `pa_done`: did students who completed it in the pilot say they are more likely to do it again?
- Rank `pa_reasons` by how often each was chosen. That tells you what to change to raise completion.
- *Optional:* compare likelihood between students who did and did not complete it with a **Mann-Whitney U test**: `wilcox.test(pa_likely ~ completed, data = d)`.

**Form B (staff)**
- Report the median and % 4 or 5 for `pa_value`, `pa_students` and `pa_use`.
- Compare `pa_students` (what staff expect) with students' own `pa_likely`: *"Staff expect students to take part less (or more) than students say they will."*

### Step 9. Adoption and impact (both forms)

These three items answer the central question of the study.

| Item | Report |
|------|--------|
| `adopt_pref` | % agree (4 or 5) and median, per form: students want to keep using it, staff support a roll-out |
| `adopt_students` | % likely (4 or 5) and median, per form: do both groups believe students will adopt it? |
| `impact` | % agree and median, per form: can an initiative like this change young people's habits? |

Use a **Mann-Whitney U test** to compare the two forms on each item, Holm-corrected across the three. Optionally check the link between them with **Spearman's rank correlation** (`cor.test(d$adopt_pref, d$impact, method = "spearman")`): do people who believe in long-term change also want to adopt it?

Frame `impact` carefully. It is a **belief and an expectation**, not evidence of change. Because the system is new and its effect builds with long-term use, state that the pilot can show intention and early perception, and that behaviour change needs follow-up over a longer period.

### Step 10. Improvement priorities

Rank `improve_pick` options by % choosing each, overall and per form, as a horizontal bar chart. `i_dash` appears for Form B only, so compute its percentage within Form B.

### Step 11. Open-ended answers

Fields: `open_overall`, `open_improve`, and for staff `d_comment`. Use **thematic analysis** (Braun & Clarke, 2006):

1. **Read** all answers once without coding.
2. **Code** each answer with short labels, for example "wants Sinhala", "water reminders helpful", "dashboard needs export". One answer can have several codes.
3. **Group** codes into 4 to 8 **themes**, for example *Ease of use*, *Motivation and badges*, *Diet tools*, *Privacy and trust*, *Feature requests*, *Value of the initiative*.
4. **Count** how many respondents mention each theme, per form.
5. **Quote** one or two short, anonymous answers per theme.
6. **Check:** if possible, a second person codes 20% of answers independently, and you resolve differences together.

| Theme | Example codes | Students (n) | Staff (n) | Example quote |
|-------|---------------|--------------|-----------|---------------|

### Step 12. Comparing groups within a form

To see whether usability differs by faculty (students), use the **Kruskal-Wallis test** for three or more groups: `kruskal.test(usability_score ~ factor(faculty), data = students)`, or Mann-Whitney U for two. With small groups, describe the medians side by side instead of testing.

### Suggested findings structure

1. **Respondents:** who took part, by form (step 2).
2. **Usability and look and feel:** the usability score and `ui_look` (steps 3 and 6).
3. **Perceived change (students):** before-and-after table with Wilcoxon results (step 4).
4. **Feature value:** usefulness chart and favourite feature, students against staff (step 5).
5. **Admin dashboard:** staff comments and themes (step 7).
6. **Periodic assessment:** students' likelihood and what would help; staff's views (step 8).
7. **Adoption and long-term impact:** the three items (step 9).
8. **Priorities for improvement:** closed choices backed by themes and quotes (steps 10 and 11).
9. **Limitations:**
   - self-report data
   - retrospective pre-test
   - small and self-selected sample
   - short pilot, so only early perception of a long-term effect
   - eight-item usability score, not the standard SUS
   - Likert data treated as ordinal

### References

- Braun, V., & Clarke, V. (2006). Using thematic analysis in psychology. *Qualitative Research in Psychology, 3*(2), 77–101.
- Brooke, J. (1996). SUS: A "quick and dirty" usability scale. In P. W. Jordan et al. (Eds.), *Usability Evaluation in Industry* (pp. 189–194). Taylor & Francis.
- Cohen, J. (1988). *Statistical Power Analysis for the Behavioral Sciences* (2nd ed.). Lawrence Erlbaum.
- Finstad, K. (2006). The System Usability Scale and non-native English speakers. *Journal of Usability Studies, 1*(4), 185–188.
- Howard, G. S. (1980). Response-shift bias: A problem in evaluating interventions with pre/post self-reports. *Evaluation Review, 4*(1), 93–106.
- Wilcoxon, F. (1945). Individual comparisons by ranking methods. *Biometrics Bulletin, 1*(6), 80–83.

---

## Part 3. The website

Built in the `evaluation/` folder (see its README):

- **Home page:** what VitalU is, and a **Give feedback** button.
- **Form:** role screen first, then the matching form. Answers are saved anonymously.
- **Researcher page** (`researcher.html`): visible only to the research team, not in the campus admin dashboard. It shows a summary and every written comment, and has a **Download CSV** button.
- **Links to send:** one per group, so you can tell where responses came from.
  - Undergraduates: `.../evaluation/form.html?g=student`
  - Lecturers, administration, health centre staff and technical experts: `.../evaluation/form.html?g=staff`
  - Or send the home page `.../evaluation/`, where people choose their role.
- **CSV columns:** one row per response, oldest first. Multi-select answers are 0/1 columns (`r_short`, `i_speed` and so on), `usability_score` is already worked out, `role` is 1 = student and 2 = staff, and blank means not shown, skipped, or "did not use".
