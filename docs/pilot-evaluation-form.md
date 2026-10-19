# VitalU pilot evaluation form

A short form for feedback after the VitalU pilot at the University of Peradeniya. It reviews the student app and the admin dashboard, asks how likely people are to take part in the periodic health assessment, asks what to improve, and asks whether an initiative like this could change young people's habits.

Revised after the researcher's review of the first version (changes are listed at the end of Part 1).

This document has three parts:

1. **The forms**: every question, who sees it, and how answers are coded.
2. **The analysis plan**: step-by-step quantitative and qualitative analysis, the tests to use, and the software.
3. **Notes for the website**: how this is built and where responses go.

---

## Part 1. The forms

### Two forms, one base

At the entry to the form, after pressing **Give feedback**, the respondent chooses one of two roles. Each role gets its own form, built from the same base questions. **Both groups used the app during the pilot**, so both answer the usability, favourite-feature, before-and-after and adoption questions as users, in the same words. They differ only where the roles differ.

| | Form A: undergraduate students | Form B: lecturers, administration or health centre staff, technical experts |
|---|---|---|
| What they evaluate | The student app | The student app **and** the admin dashboard |
| Usability, favourite feature, before and after | Asked as a user | Asked as a user, same wording |
| Feature usefulness | "How useful **was** each feature **for you**?" | "How useful **do you think** each feature **will be for students**?" |
| Admin dashboard | Not shown (students have no access) | Shown, as one open comment |
| Faculty, batch, sex | Asked | Not asked |
| How often they opened the app | Asked | Asked |
| Periodic assessment | Their own likelihood to complete it | Related questions about its value and uptake |
| Overall adoption preference | "I would like to keep using VitalU." | "I would support rolling VitalU out to all students at the university." |
| Time | About 6 to 8 minutes | About 5 to 7 minutes |

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
| 2 | About you (Form B: "Your use of VitalU", frequency only) | ✓ | ✓ |
| 3 | Using the student app (usability, part 1) | ✓ | ✓ |
| 4 | Using the student app (usability, part 2, and look and feel) | ✓ | ✓ |
| 5 | Student app features | ✓ | ✓ |
| 6 | Favourite feature | ✓ | ✓ |
| 7 | Before and after VitalU | ✓ | ✓ |
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

### Screen 2. About you

Form A asks all four questions. Form B asks only `freq` ("How often did you open the student app during the pilot?").

| ID | Question | Codes |
|----|----------|-------|
| `faculty` | Your faculty | 1 Agriculture · 2 Allied Health Sciences · 3 Arts · 4 Dental Sciences · 5 Engineering · 6 Management · 7 Medicine · 8 Science · 9 Veterinary Medicine and Animal Science |
| `year` | Your batch | 1 = 1st year · 2 = 2nd year · 3 = 3rd year · 4 = 4th year or above |
| `sex` | Sex | 1 = Female · 2 = Male · 3 = Prefer not to say |
| `freq` | How often did you open the student app? | 1 = Once or twice · 2 = About once a week · 3 = A few times a week · 4 = Daily or almost daily |

`sex` decides whether students see the cycle tracker in the feature list.

### Screens 3 and 4. Using the student app (both forms)

Agreement scale, all required in this section so the score can be worked out. Both forms read "Think about your experience using the VitalU app."

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
| `fav_feature` | Which feature of the app did you like the most? (both forms) | One of the feature IDs above, or `none` |

### Screen 7. Before and after VitalU (both forms)

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
| B: lecturers, administration, staff and experts | 13 | 5 to 7 minutes |

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

**Second revision.** The second group also used the app, so they now answer as users: the same usability introduction, favourite feature ("Which feature of the app did you like the most?"), before-and-after statements and frequency of use. Feature usefulness still asks how useful each feature will be for students, and the overall adoption question keeps its role-specific wording (students: keep using it; staff: support a roll-out to all students).

---

## Part 2. How to analyse the responses

### 2.1 Overview

The form gives two kinds of data, and they are analysed in different places:

| Data | Questions | Analysed with | Where |
|------|-----------|---------------|-------|
| **Quantitative** (numbers, choices) | All 1 to 5 scales, usability items, favourite feature, multi-select lists, role, faculty | Descriptive statistics and non-parametric tests | jamovi (recommended), JASP, SPSS, R or Excel |
| **Qualitative** (written comments) | `open_overall`, `open_improve`, `d_comment`, `improve_other`, `pa_reasons_other` | Thematic analysis | NVivo, ATLAS.ti, MAXQDA, or free: Taguette, QualCoder, Excel |

**The workflow:**

1. Download the CSV from the researcher page.
2. Clean it in Excel.
3. Analyse the numbers in jamovi.
4. Import the written comments into NVivo, or a free alternative, and code them into themes.
5. Combine both in the findings: numbers show *how many*, themes and quotes show *why*.

### 2.2 Software

**For the numbers**

| Software | Cost | Why use it |
|----------|------|-----------|
| **jamovi** (jamovi.org) | Free | Point and click, opens CSV directly, has every test below, and gives effect sizes. **Recommended.** |
| **JASP** (jasp-stats.org) | Free | Very similar to jamovi, with clean APA-style tables. |
| **IBM SPSS Statistics** | Paid; often available through the university | The traditional choice in health research. Same tests, more menus. |
| **R** (with RStudio) | Free | Most flexible and reproducible, but needs code. Commands are given below. |
| **Microsoft Excel** or Google Sheets | Usually available | Cleaning, counts, percentages and charts. Not for the tests. |

**For the written comments**

| Software | Cost | Notes |
|----------|------|-------|
| **NVivo** (Lumivero) | Paid; a 14-day free trial; often licensed by universities | The most widely used qualitative software in health research. Imports the CSV as a dataset, so each comment stays linked to the person's role and faculty. |
| **ATLAS.ti** | Paid, with a student licence | Similar to NVivo, strong on visual networks of codes. |
| **MAXQDA** | Paid, with a student licence | Similar, with good mixed-methods tools that link codes with the numbers. |
| **Taguette** (taguette.org) | Free, open source | Simple highlight-and-tag coding in the browser. Enough for a few hundred comments. |
| **QualCoder** | Free, open source | A desktop tool closer to NVivo. |
| **Excel** | Usually available | A coding spreadsheet: one row per comment, one column per code. Fine for under about 150 comments. |

If "Nova" meant **NVivo**, it is the right choice when the university has a licence. If not, Taguette or an Excel coding sheet gives the same result for a dataset of this size.

### 2.3 Step 1. Prepare the data (Excel)

1. On the researcher page, press **Download CSV**. Use **Everyone** for the full file.
2. Open it in Excel and **save a copy** as `vitalu_feedback_raw.xlsx`. Never edit the raw file; work on a copy.
3. **Remove** rows where `consent` is not 1.
4. **Remove duplicates**: rows with the same answers in every column, submitted minutes apart.
5. **Remove straight-liners** from the usability items: people who chose the same answer for all eight (`us1` to `us8`). Half the items are negatively worded, so identical answers mean they did not read them. Report how many you removed.
6. **Keep blanks as blanks.** A blank means not shown, skipped, "Did not use" or "Not sure". Never replace it with 0 or 3.
7. Add a column `group` = "Student" when `role` = 1 and "Staff" when `role` = 2.
8. Save as `vitalu_feedback_clean.csv` for jamovi, and copy the text columns into a separate sheet for the qualitative work (section 2.7).

### 2.4 Step 2. Descriptive statistics (jamovi: Exploration → Descriptives)

Report these for each group (put `group` in **Split by**).

| What | Columns | Report |
|------|---------|--------|
| Who answered | `group`, `faculty`, `year`, `sex`, `freq` | Counts (n) and % (tick **Frequency tables**) |
| Usability | `usability_score` | Mean, SD, median, IQR, min and max |
| Each 1 to 5 item | `ui_look`, `f_*`, `pp*_pre`, `pp*_post`, `pa_*`, `adopt_pref`, `adopt_students`, `impact` | **Median and IQR**, and **% agreeing**, which is the % answering 4 or 5 ("top-two box") |
| Choices | `fav_feature`, `pa_done` | Counts and % |
| Multi-select | `r_*`, `i_*` | % ticking each (mean of the 0/1 column × 100) |
| Comments | `open_*`, `d_comment` | Number who wrote something |

**Why median and IQR, not only means?** Likert answers are ordered categories, not measurements, so the median is the safer summary. Many papers also give the mean (SD) alongside, which is acceptable if you say so.

**Response rate** per group = completed forms ÷ people invited × 100.

**Charts:**
- **Diverging stacked bars** for the 1 to 5 items (features, adoption, impact): one bar per item, disagree to the left and agree to the right.
- **Horizontal bars** for favourite feature and improvement priorities.
- **A box plot** of usability score by group.

### 2.5 Step 3. Usability score

`usability_score` (0 to 100) is already in the CSV, from the eight usability items:

- odd items (`us1`, `us3`, `us5`, `us7`): answer − 1
- even items (`us2`, `us4`, `us6`, `us8`): 5 − answer
- add the eight results, divide by 32, and multiply by 100

> Because items 9 and 10 of the standard System Usability Scale were removed, this is **not a standard SUS score**, so the published benchmarks (68 average, above 80 excellent) do not apply. Call it "a usability score from eight items adapted from the System Usability Scale" and compare it between groups and across future rounds only.

**Reliability:** check that the eight items hang together with **Cronbach's alpha** (jamovi: Factor → Reliability Analysis, move `us1` to `us8` in, and tick **Reverse scaled items** for `us2`, `us4`, `us6` and `us8`). Alpha of 0.70 or more is acceptable.

### 2.6 Step 4. Statistical tests

All tests here are **non-parametric**, because Likert answers are ordinal and the samples are small and rarely normal. Use p < 0.05. When you run the same test on several items, adjust with the **Holm** correction.

| Research question | Data | Test | jamovi menu |
|-------------------|------|------|-------------|
| Did people feel their knowledge and habits improved after using VitalU? | `pp1_pre` vs `pp1_post` (and pp2 to pp4), per group | **Wilcoxon signed-rank** (paired) | T-Tests → Paired Samples → tick Wilcoxon rank |
| Do students and staff differ in usability, impact belief, expected student uptake or look-and-feel? | `usability_score`, `adopt_students`, `impact`, `ui_look` by `group` | **Mann-Whitney U** (two independent groups) | T-Tests → Independent Samples → tick Mann-Whitney U |
| Do staff expect a feature to be more or less useful than students found it? | Each `f_*` by `group` | **Mann-Whitney U**, Holm-corrected across the 12 | Same as above |
| Is a feature rated reliably above "moderately useful"? | Each `f_*` against 3 | **One-sample Wilcoxon signed-rank** | T-Tests → One Sample T-Test → tick Wilcoxon rank, test value 3 |
| Does usability differ by faculty or batch (students)? | `usability_score` by `faculty` or `year` | **Kruskal-Wallis**, then Dwass-Steel-Critchlow-Fligner pairwise comparisons | ANOVA → One-Way ANOVA (Non-parametric) |
| Are students who completed the assessment more willing to do it again? | `pa_likely` by `pa_done` | **Mann-Whitney U** (Yes vs No) | Independent Samples |
| Do people who find the app easy also want to keep using it, or believe in its impact? | `usability_score` with `adopt_pref`, `impact` | **Spearman's rank correlation** | Regression → Correlation Matrix → tick Spearman |
| Is the favourite feature linked to group? | `fav_feature` by `group` | **Chi-square test of independence**, or **Fisher's exact test** when expected counts are under 5 (likely here) | Frequencies → Independent Samples (χ²) → Statistics: tick Fisher's exact |

**Always report an effect size**, not only p:

| Test | Effect size | Small / medium / large |
|------|-------------|------------------------|
| Wilcoxon signed-rank | r = z / √n (jamovi: rank biserial correlation) | 0.1 / 0.3 / 0.5 |
| Mann-Whitney U | r = z / √N, or rank biserial correlation | 0.1 / 0.3 / 0.5 |
| Kruskal-Wallis | ε² (epsilon squared) | 0.01 / 0.08 / 0.26 |
| Spearman | ρ itself | 0.1 / 0.3 / 0.5 |
| Chi-square | Cramér's V | 0.1 / 0.3 / 0.5 |

**Sample size.** With fewer than about 6 people per group, describe medians instead of testing. For the before-and-after test, aim for **20 to 30 or more** per group.

#### The Wilcoxon signed-rank test, step by step

Each person rated the same statement twice, before and now, so the answers are **paired**. The test asks whether the "now" ratings are consistently higher than the "before" ratings.

1. **Difference.** For each person, d = now − before.
2. **Drop zeros.** People with no change are set aside. *n* is the number left.
3. **Rank** the absolute differences |d| from smallest (1) to largest. Ties share the average rank.
4. **Sum by sign:** W+ (ranks of positive differences) and W− (ranks of negative ones).
5. **Compare.** The further W+ is from W−, the stronger the evidence of change. The p-value says how likely a gap this big is by chance.

**Worked example** (made-up numbers): eight students rate *"I understand what my own health numbers mean"*.

| Person | Before | Now | d | Rank of \|d\| | Signed rank |
|--------|--------|-----|---|---------------|-------------|
| A | 2 | 4 | +2 | 5 | +5 |
| B | 3 | 4 | +1 | 2 | +2 |
| C | 2 | 2 | 0 | dropped | |
| D | 1 | 3 | +2 | 5 | +5 |
| E | 3 | 5 | +2 | 5 | +5 |
| F | 4 | 4 | 0 | dropped | |
| G | 2 | 3 | +1 | 2 | +2 |
| H | 3 | 2 | −1 | 2 | −2 |

- *n* = 6, W+ = 19 and W− = 2.
- Expected W+ under no change is n(n+1)/4 = 10.5.
- Spread, with the tie correction, is √(22.75 − 1) = 4.66.
- **z = (19 − 10.5) / 4.66 = 1.82**, two-tailed **p ≈ 0.07**.
- **r = 1.82 / √6 = 0.74**, a large effect.

A large shift in only 6 people still misses p < 0.05, which is why you need enough respondents.

**Run it for pp1 to pp4, once for each group**, then Holm-correct the four p-values. In R: `p.adjust(c(p1, p2, p3, p4), method = "holm")`.

**How to write it:** *"Students reported better understanding of their own health numbers after the pilot (median 2 before, 4 now; Wilcoxon z = 4.12, p < .001, r = 0.62)."*

**Limitation.** "Before" is remembered, not measured at the start: a retrospective pre-test. It is accepted in programme evaluation (Howard, 1980) but can overstate change. Call it **self-perceived change**.

#### The same tests in R and SPSS

| Test | R | SPSS |
|------|---|------|
| Wilcoxon signed-rank | `wilcox.test(d$pp1_post, d$pp1_pre, paired = TRUE, exact = FALSE)` | Analyze → Nonparametric Tests → Legacy Dialogs → 2 Related Samples |
| Mann-Whitney U | `wilcox.test(usability_score ~ group, data = d)` | Analyze → Nonparametric Tests → Legacy Dialogs → 2 Independent Samples |
| One-sample Wilcoxon | `wilcox.test(d$f_water, mu = 3)` | Analyze → Nonparametric Tests → One Sample |
| Kruskal-Wallis | `kruskal.test(usability_score ~ factor(faculty), data = students)` | Analyze → Nonparametric Tests → Legacy Dialogs → K Independent Samples |
| Spearman | `cor.test(d$usability_score, d$adopt_pref, method = "spearman")` | Analyze → Correlate → Bivariate → Spearman |
| Fisher's exact | `fisher.test(table(d$group, d$fav_feature))` | Analyze → Descriptive Statistics → Crosstabs → Exact |
| Cronbach's alpha | `psych::alpha(d[paste0("us", 1:8)], check.keys = TRUE)` | Analyze → Scale → Reliability Analysis |
| Effect size r | `rstatix::wilcox_effsize()` | Compute by hand: z / √n |

### 2.7 Step 5. Qualitative analysis of the comments

**Which text to analyse:**

| Column | Who | Question |
|--------|-----|----------|
| `open_overall` | Both | Overall comments about the VitalU initiative |
| `open_improve` | Both | What should we change, fix or add? |
| `d_comment` | Staff | Comments on the admin dashboard |
| `improve_other`, `pa_reasons_other` | Both / students | Short "Other" answers |

**Where to do it.** Not in jamovi. Use NVivo, or a free alternative, so every comment keeps its link to the person's group and faculty.

**In NVivo:**
1. **Import.** Create a project, then Import → Survey (or Dataset), and choose the clean CSV. Mark `response_id` as the identifier. Mark `group`, `faculty` and `year` as **classifying** columns (they become attributes). Mark the text columns as **codable**.
2. **Read** every comment once without coding, to get a feel for the data.
3. **Code** by highlighting a phrase and dragging it onto a new **code** (NVivo calls codes "nodes" in older versions), for example "wants Sinhala", "water reminders helpful", "dashboard needs export". One comment can have several codes.
4. **Group** related codes into 4 to 8 parent codes, the **themes**. For example:
   - *Ease of use*
   - *Motivation and badges*
   - *Diet tools*
   - *Privacy and trust*
   - *Feature requests*
   - *Value of the initiative*
   - *Dashboard improvements*
5. **Compare groups** with a **Crosstab query** (themes × `group`) to see which themes students and staff each raised.
6. **Export** the code book and the crosstab for your appendix, and pick one or two short quotes per theme.

**Without NVivo:**
- **Taguette:** paste or upload the comments, highlight phrases, add tags, then export the tagged highlights.
- **Excel:** one row per comment, with columns for `response_id`, `group`, the comment, Code 1, Code 2 and Code 3. Filter by code to group them into themes, and use a PivotTable (theme × group) for the counts.

**Method:** Braun and Clarke's (2006) **reflexive thematic analysis**, six phases:
1. Get familiar with the data.
2. Generate initial codes.
3. Search for themes.
4. Review the themes.
5. Define and name them.
6. Write up.

For short survey comments like these, a simpler **qualitative content analysis**, which codes and then counts how often each code appears, is also acceptable. Say which one you used.

**Rigour:**
- If possible, a second person (for example your supervisor) codes about 20% of the comments independently.
- You then compare and resolve any differences. NVivo can calculate **Cohen's kappa** for agreement; 0.6 or more is good.
- Keep a short code book: the code name, its definition and an example quote.

**Report it as:**

| Theme | What it covers | Students (n) | Staff (n) | Example quote |
|-------|----------------|--------------|-----------|---------------|

Remove anything that could identify someone before quoting.

### 2.8 Step 6. Bring it together (mixed methods)

Use the numbers and the comments side by side. For example: *"Diet tools had the lowest usefulness rating among students (52% very or extremely useful), and comments explain why: the food list was missing common canteen meals (n = 9)."* This is a **convergent mixed-methods** presentation: each result is backed by the other kind of data.

### 2.9 Suggested findings structure

1. **Respondents:** who took part, by group (section 2.4).
2. **Usability and look and feel:** usability score with Cronbach's alpha, `ui_look`, and the students vs staff comparison.
3. **Perceived change:** before-and-after table with Wilcoxon results, for each group.
4. **Feature value:** usefulness chart; students' experience vs staff expectations; favourite feature.
5. **Admin dashboard:** staff themes from `d_comment`.
6. **Periodic assessment:**
   - students' likelihood to complete it, and what would help
   - staff views on its value and uptake
7. **Adoption and long-term impact:** `adopt_pref` (reported separately per group, as the wording differs), `adopt_students` and `impact`, with group comparisons and the Spearman links.
8. **Priorities for improvement:** closed choices plus themes and quotes.
9. **Limitations:**
   - self-report data
   - retrospective pre-test
   - small, self-selected sample
   - a short pilot showing early perception of a long-term effect
   - an eight-item usability score, not the standard SUS
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
