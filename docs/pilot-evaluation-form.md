# VitalU pilot evaluation form

A short form to collect feedback after the VitalU pilot from three groups at the University of Peradeniya: undergraduates, lecturers and administration staff. It reviews the student app and the admin dashboard, asks how likely people are to take part in the periodic health assessment, and asks what to improve.

This document has three parts:

1. **The form**: every question, who sees it, and how answers are coded.
2. **The analysis plan**: how to turn the answers into findings, including the Wilcoxon signed-rank test.
3. **Notes for the website**: what to keep in mind when building it as a separate site later.

---

## Part 1. The form

### Design rules

- **Short.** Undergraduates: about 7 minutes. Lecturers and administration: about 4 to 5 minutes.
- **Anonymous.** No name, email, registration number or phone number is asked.
- **Branching.** Each person only sees the sections that match their role and what they used.
- **Mostly taps.** Every rating question uses the same 5-point scale. Only two questions need typing, and both are optional.
- **Mobile first.** One section per screen, a progress bar, large tap targets.

### Answer scale used throughout

Unless a question says otherwise, ratings use this 5-point scale:

| Code | Label |
|------|-------|
| 1 | Strongly disagree |
| 2 | Disagree |
| 3 | Neutral |
| 4 | Agree |
| 5 | Strongly agree |

"Did not use" is coded as blank (missing), not 0.

### Who sees what

| Section | Undergraduates | Lecturers | Administration |
|---------|:--------------:|:---------:|:--------------:|
| 0. Welcome and consent | ✓ | ✓ | ✓ |
| 1. About you | ✓ | ✓ | ✓ |
| 2. Using the student app (SUS) | ✓ | if they used it | if they used it |
| 3. Student app features | ✓ | ✓ | ✓ |
| 4. Before and after VitalU | ✓ | | |
| 5. Admin dashboard | | if they used it | if they used it |
| 6. Periodic health assessment | ✓ | ✓ | ✓ |
| 7. What to improve | ✓ | ✓ | ✓ |

---

### Section 0. Welcome and consent

> **Help us improve VitalU**
>
> You took part in the VitalU pilot. This short form asks what worked, what did not and what we should improve. It takes about 5 to 7 minutes.
>
> - Your answers are anonymous. We do not ask for your name, email or registration number.
> - Taking part is voluntary. You can skip any question or stop at any time.
> - Results are reported only as group totals in the research project *"Development of an ADDIE-Based Mobile Health Platform to Improve Cardiometabolic Health among Undergraduate Students"*, Department of Food Science and Technology, Faculty of Agriculture, University of Peradeniya.
>
> Questions? Contact W. M. O. P. Wijesooriya, fst20052@agri.pdn.ac.lk.

| ID | Question | Type | Answers |
|----|----------|------|---------|
| `consent` | I have read the information above and agree to take part. | Single choice, required | 1 = Yes, continue · 0 = No (ends the form) |

---

### Section 1. About you

| ID | Question | Type | Answers and codes | Shown to |
|----|----------|------|-------------------|----------|
| `role` | Which describes you best? | Single choice, required | 1 = Undergraduate student · 2 = Lecturer · 3 = Administration or health centre staff | All |
| `faculty` | Your faculty | Single choice | 1 = Agriculture · 2 = Allied Health Sciences · 3 = Arts · 4 = Dental Sciences · 5 = Engineering · 6 = Management · 7 = Medicine · 8 = Science · 9 = Veterinary Medicine and Animal Science · 10 = Not faculty-based | All |
| `year` | Your batch | Single choice | 1 = 1st year · 2 = 2nd year · 3 = 3rd year · 4 = 4th year or above | Undergraduates |
| `sex` | Sex | Single choice | 1 = Female · 2 = Male · 3 = Prefer not to say | All |
| `used` | Which parts of VitalU did you use during the pilot? Select all that apply. | Multi-select, required | `used_app` = I used the student app myself · `used_demo` = I saw a demonstration of the student app · `used_dash` = I used the admin dashboard | All |
| `freq` | How often did you open the student app? | Single choice | 1 = Once or twice · 2 = About once a week · 3 = A few times a week · 4 = Daily or almost daily | Anyone who ticked `used_app` |

**Branching:**
- Section 2 and the "before and after" in Section 4 appear only if `used_app` is ticked.
- Section 5 appears only if `used_dash` is ticked.
- If someone ticks only `used_demo`, Section 3 asks how useful each feature *would be* for students, instead of how useful it *was*.

---

### Section 2. Using the student app

Shown if `used_app` is ticked. This is the **System Usability Scale (SUS)** (Brooke, 1996), a standard 10-item usability questionnaire. Keep the wording and order exactly as below, so the score can be compared with published benchmarks. "System" is replaced with "app", and "cumbersome" with "awkward" (Finstad, 2006), which is clearer for respondents who do not speak English as a first language.

Intro text: *Think about your experience with the VitalU app. Rate how much you agree with each statement.*

| ID | Statement | Scale |
|----|-----------|-------|
| `sus1` | I think that I would like to use this app frequently. | 1 to 5 |
| `sus2` | I found the app unnecessarily complex. | 1 to 5 |
| `sus3` | I thought the app was easy to use. | 1 to 5 |
| `sus4` | I think that I would need the support of a technical person to be able to use this app. | 1 to 5 |
| `sus5` | I found the various functions in this app were well integrated. | 1 to 5 |
| `sus6` | I thought there was too much inconsistency in this app. | 1 to 5 |
| `sus7` | I would imagine that most people would learn to use this app very quickly. | 1 to 5 |
| `sus8` | I found the app very awkward to use. | 1 to 5 |
| `sus9` | I felt very confident using the app. | 1 to 5 |
| `sus10` | I needed to learn a lot of things before I could get going with this app. | 1 to 5 |

The SUS must have all 10 items answered to be scored, so make these required inside this section.

---

### Section 3. Student app features

Shown to everyone.

- **If they used the app:** *How useful was each feature for you? Choose "Did not use" if you did not try it.*
- **If they only saw a demo:** *How useful would each feature be for students?*

Scale: 1 = Not useful at all · 2 = Slightly useful · 3 = Moderately useful · 4 = Very useful · 5 = Extremely useful · blank = Did not use / Not sure.

| ID | Feature (with a one-line hint shown under it) |
|----|-----------------------------------------------|
| `f_body` | **Body checks:** BMI and waist-to-hip ratio calculators |
| `f_heart` | **Heart health check:** CVD risk indicator |
| `f_mind` | **Anxiety tracker:** DASS-21 self-check, calm music and relaxation ideas |
| `f_water` | **Water tracker:** daily goal, bottle and reminders |
| `f_move` | **Activity and sleep trackers:** steps, active minutes, sleep log |
| `f_cycle` | **Cycle tracker:** calendar, phases and notifications *(shown only if `sex` = 1)* |
| `f_diet` | **Diet tools:** calorie counter, meal diary, healthy plate, diversity guide, budget planner |
| `f_learn` | **Learn articles:** health topics written for students |
| `f_badges` | **Badges and streaks:** Aqua Achiever, Active Aura, Smart Eater and others |
| `f_notify` | **Reminders:** morning, evening and water notifications |
| `f_help` | **Getting help:** ask anonymously, campus professionals, emergency numbers |
| `f_report` | **Your progress:** home dashboard, summary and personal health report (PDF) |

> **Interactive idea:** show each feature as a card with its icon from the app, and the five answers as a row of faces (😞 to 😄). Tapping a face moves to the next card.

---

### Section 4. Before and after VitalU

Shown only to undergraduates who ticked `used_app`. Each statement is rated twice on the agreement scale: once for **before** the pilot, once for **now**. Show the two ratings side by side so they are answered together.

Intro text: *For each statement, think back to before you started using VitalU, then think about now.*

| ID before | ID now | Statement |
|-----------|--------|-----------|
| `pp1_pre` | `pp1_post` | I understand what my own health numbers (BMI, waist, blood pressure) mean. |
| `pp2_pre` | `pp2_post` | I pay attention to how balanced and varied my meals are. |
| `pp3_pre` | `pp3_post` | I drink enough water and stay active most days. |
| `pp4_pre` | `pp4_post` | I know where to get health or mental health support on campus. |

These four pairs are what the **Wilcoxon signed-rank test** is run on (Part 2, step 4).

---

### Section 5. Admin dashboard

Shown if `used_dash` is ticked. Agreement scale, 1 to 5.

| ID | Statement |
|----|-----------|
| `d_nav` | The dashboard was easy to sign in to and find my way around, on a computer or phone. |
| `d_sched` | Scheduling the assessment for different faculties and dates was straightforward. |
| `d_quest` | Reviewing and editing the questionnaire was straightforward. |
| `d_analytics` | The pooled analytics gave a clear picture of student health. |
| `d_complete` | Checking assessment completion by registration number was useful. |
| `d_privacy` | I trust that the dashboard protects students' privacy (pooled results only, small groups hidden). |

---

### Section 6. Periodic health assessment

Shown to everyone. The question changes with the role.

| ID | Question (by role) | Scale |
|----|--------------------|-------|
| `pa_likely` | **Undergraduates:** How likely are you to complete the next six-monthly periodic health assessment in VitalU? | 1 = Very unlikely · 2 = Unlikely · 3 = Not sure · 4 = Likely · 5 = Very likely |
| | **Lecturers:** How likely are you to encourage your students to complete the six-monthly periodic health assessment? | same |
| | **Administration:** How likely is your office to use the pooled assessment results to plan student health or nutrition support? | same |
| `pa_done` | *Undergraduates only:* Did you complete the periodic health assessment during the pilot? | 1 = Yes · 2 = Started but did not finish · 3 = No · 4 = It was not open for my faculty |
| `pa_reasons` | *Undergraduates only, optional:* What would make you more likely to complete it? Select up to 2. | `r_short` It being shorter · `r_remind` A reminder when it opens · `r_results` Seeing my own results afterwards · `r_privacy` Being sure it is anonymous · `r_time` A quieter time in the semester · `r_other` Other |

---

### Section 7. What to improve

Shown to everyone.

| ID | Question | Type |
|----|----------|------|
| `improve_pick` | Which areas should we improve first? Select up to 3. | Multi-select, max 3: `i_speed` Speed and reliability · `i_design` Look and layout · `i_easy` Easier to understand · `i_diet` Diet tools and food list · `i_trackers` Trackers (water, activity, sleep, cycle) · `i_learn` More or better Learn articles · `i_notify` Reminders and notifications · `i_help` Health support and consultations · `i_dash` Admin dashboard · `i_lang` Sinhala and Tamil language options · `i_other` Other |
| `recommend` | How likely are you to recommend VitalU to a fellow student? | 1 = Very unlikely to 5 = Very likely |
| `open_best` | What did you find most useful about VitalU? *(optional)* | Short text, 500 characters |
| `open_improve` | What should we change, fix or add? Please be as specific as you can. *(optional)* | Long text, 1,000 characters |

Hint under both text boxes: *Please do not include names or anything that could identify you or others.*

Closing screen:

> **Thank you!** Your feedback will shape the next version of VitalU.

---

### Length check

| Role | Questions shown (approx.) | Time |
|------|---------------------------|------|
| Undergraduate who used the app | 5 about you + 10 SUS + 12 features + 4 before-and-after pairs + 3 assessment + 4 improve | 6 to 8 min |
| Lecturer who saw a demo | 5 + 12 + 1 + 4 | 3 to 4 min |
| Administration who used the dashboard | 5 + 12 + 6 + 1 + 4 | 4 to 5 min |

---

## Part 2. How to analyse the responses

Use free tools: **jamovi** (point and click, free), **R**, or Python with `pandas` and `scipy`. SPSS works too. Export the responses as a CSV with one row per respondent and the IDs above as column names.

### Step 1. Clean the data

1. Remove rows where `consent` is not 1.
2. Remove clear duplicates: same answers in every column, submitted minutes apart.
3. Remove **straight-liners** from the SUS only: people who chose the same answer for all 10 items. Because half the items are worded negatively, the same answer everywhere means they did not read them. Report how many you removed.
4. Leave "Did not use" as missing. Do not turn it into 0 or 3.

### Step 2. Describe who answered

Report counts and percentages for `role`, `faculty`, `year`, `sex` and `freq`.

| Characteristic | n | % |
|----------------|---|---|
| Undergraduates | | |
| Lecturers | | |
| Administration | | |
| ... | | |

Give a response rate per group if you know how many were invited:
`Response rate = completed forms ÷ people invited × 100`.

### Step 3. Score the SUS (student app usability)

For each respondent:

1. Odd items (`sus1`, 3, 5, 7, 9): subtract 1 from the answer.
2. Even items (`sus2`, 4, 6, 8, 10): subtract the answer from 5.
3. Add the 10 results (range 0 to 40), then multiply by 2.5. The SUS score is 0 to 100.

In R:

```r
odd  <- c("sus1","sus3","sus5","sus7","sus9")
even <- c("sus2","sus4","sus6","sus8","sus10")
d$sus <- (rowSums(d[odd] - 1) + rowSums(5 - d[even])) * 2.5
```

**Report:** mean, standard deviation, median and interquartile range (IQR).

**Interpretation.** The SUS is not a percentage. Use these published benchmarks:

| SUS score | Meaning |
|-----------|---------|
| below 50 | Not acceptable (Bangor et al., 2008) |
| 50 to 70 | Marginal |
| 68 | Average across hundreds of studies (Sauro, 2011) |
| above 70 | Acceptable |
| above 80 | Excellent, about the top 10% of products |

Example sentence: *"Undergraduates rated the app's usability at a mean SUS of 74.2 (SD 11.5, n = 42), above the benchmark average of 68."*

### Step 4. Before and after: the Wilcoxon signed-rank test

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
- Spread: √(n(n+1)(2n+1)/24 − tie correction) = √(22.75 − 1) = 4.66.
  The tie correction is Σ(t³ − t)/48 over each group of t tied values: (24 + 24)/48 = 1.
- **z** = (19 − 10.5) / 4.66 = **1.82**, two-tailed **p ≈ 0.07**.
- **Effect size r** = z / √n = 1.82 / √6 = **0.74**.
- Medians: before = 2.5, now = 3.5.

With only 6 students who changed, a fairly large shift still does not reach p < 0.05. This is why you should aim for **at least 20 to 30 students** completing Section 4.

#### Running it

| Tool | How |
|------|-----|
| jamovi | T-Tests → Paired Samples T-Test → move `pp1_pre` and `pp1_post` in → tick **Wilcoxon rank**, untick Student's, tick **Effect size** |
| SPSS | Analyze → Nonparametric Tests → Legacy Dialogs → 2 Related Samples → Wilcoxon |
| R | `wilcox.test(d$pp1_post, d$pp1_pre, paired = TRUE, exact = FALSE)` |
| Python | `scipy.stats.wilcoxon(df.pp1_post, df.pp1_pre, zero_method="wilcox")` |

R does not print z. Get it from the p-value with `z <- qnorm(p / 2, lower.tail = FALSE)`, or use `rstatix::wilcox_effsize()`, which gives r directly.

#### Four tests, so adjust the p-values

You run the test four times (pp1 to pp4), so correct for multiple testing with the **Holm** method. Sort the four p-values from smallest to largest. Compare the smallest with 0.05/4, the next with 0.05/3, then 0.05/2, then 0.05/1. Stop at the first one that is not below its threshold. In R: `p.adjust(c(p1, p2, p3, p4), method = "holm")`.

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

Example sentence: *"Students reported better understanding of their own health numbers after the pilot (median 2 before, 4 now; Wilcoxon z = 4.12, p < .001, r = 0.62), with 31 of 42 rating it higher."*

#### Limitation to state honestly

This is a **retrospective pre-test**: "before" is remembered, not measured at the start. It is accepted in programme evaluation and avoids "response-shift" bias, where people only realise how little they knew once they learn more. However, it can overstate change if people want to please the researchers. Report it as **self-perceived change**, not proof that behaviour changed.

### Step 5. Feature usefulness

For each feature:

- **Use rate:** % of app users who rated it (did not choose "Did not use").
- **Median and IQR** of the 1 to 5 rating.
- **% useful:** % who chose 4 or 5.

Present all 12 features as a **diverging stacked bar chart**, sorted by % useful. It shows at a glance which features students valued and which were ignored.

| Feature | Used (%) | Median (IQR) | Very or extremely useful (%) |
|---------|----------|--------------|------------------------------|

*Optional test:* a **one-sample Wilcoxon signed-rank test** against 3 ("moderately useful") shows whether a feature was rated reliably above the middle. In R: `wilcox.test(d$f_water, mu = 3)`. Holm-correct across the 12 features.

### Step 6. Admin dashboard

Usually few people answer this section, so keep it descriptive. Report the median and the count for each of the six items, for example *"5 of 6 agreed scheduling by faculty was straightforward"*. Do not run significance tests with fewer than about 6 respondents.

### Step 7. Periodic assessment likelihood

- Report `pa_likely` separately for each role as % likely or very likely (4 or 5), with the median.
- For undergraduates, cross-tabulate `pa_likely` with `pa_done`. Did students who completed it in the pilot say they are more likely to do it again?
- Rank `pa_reasons` by how often each was chosen. That tells you what to change to raise completion.

| Role | n | Likely or very likely (%) | Median |
|------|---|---------------------------|--------|

*Optional:* compare likelihood between students who did and did not complete the pilot assessment with a **Mann-Whitney U test**. It is the unpaired cousin of the Wilcoxon test. In R: `wilcox.test(pa_likely ~ completed, data = d)`.

### Step 8. Improvement priorities and recommendation

- Rank `improve_pick` options by % of respondents choosing each, overall and by role. A horizontal bar chart works well.
- Report `recommend` as % likely or very likely, and the median.

### Step 9. Open-ended answers

Use **thematic analysis** (Braun & Clarke, 2006). It is manageable by hand or in a spreadsheet:

1. **Read** all `open_best` and `open_improve` answers once without coding.
2. **Code** each answer with short labels, for example "wants Sinhala", "water reminders helpful", "dashboard slow on phone". One answer can have several codes.
3. **Group** codes into 4 to 8 **themes**, for example *Ease of use*, *Motivation and badges*, *Diet tools*, *Privacy and trust*, *Feature requests*.
4. **Count** how many respondents mention each theme, overall and by role.
5. **Quote** one or two short, anonymous answers per theme.
6. **Check:** if possible, a second person codes 20% of answers independently, and you resolve differences together.

| Theme | Example codes | Undergraduates (n) | Lecturers (n) | Administration (n) | Example quote |
|-------|---------------|--------------------|---------------|--------------------|---------------|

### Step 10. Comparing groups (only if each group has 5 or more)

To see whether usability or likelihood differs by role or faculty, use the **Kruskal-Wallis test** for three or more groups, or the **Mann-Whitney U test** for two. In R: `kruskal.test(sus ~ factor(role), data = d)`. With small groups, describe the medians side by side instead of testing.

### Suggested findings structure

1. **Respondents:** who took part (Step 2).
2. **Usability:** SUS score against benchmarks (Step 3).
3. **Perceived change:** before-and-after table with Wilcoxon results (Step 4).
4. **Feature value:** feature usefulness chart (Step 5).
5. **Admin dashboard:** the six items (Step 6).
6. **Periodic assessment:** likelihood by role and what would help (Step 7).
7. **Priorities for improvement:** closed choices (Step 8) backed by themes and quotes (Step 9).
8. **Limitations:**
   - self-report data
   - retrospective pre-test
   - small and self-selected sample
   - pilot length
   - Likert data treated as ordinal

### References

- Bangor, A., Kortum, P. T., & Miller, J. T. (2008). An empirical evaluation of the System Usability Scale. *International Journal of Human-Computer Interaction, 24*(6), 574–594.
- Braun, V., & Clarke, V. (2006). Using thematic analysis in psychology. *Qualitative Research in Psychology, 3*(2), 77–101.
- Brooke, J. (1996). SUS: A "quick and dirty" usability scale. In P. W. Jordan et al. (Eds.), *Usability Evaluation in Industry* (pp. 189–194). Taylor & Francis.
- Cohen, J. (1988). *Statistical Power Analysis for the Behavioral Sciences* (2nd ed.). Lawrence Erlbaum.
- Finstad, K. (2006). The System Usability Scale and non-native English speakers. *Journal of Usability Studies, 1*(4), 185–188.
- Howard, G. S. (1980). Response-shift bias: A problem in evaluating interventions with pre/post self-reports. *Evaluation Review, 4*(1), 93–106.
- Sauro, J. (2011). *A Practical Guide to the System Usability Scale.* Measuring Usability LLC.
- Wilcoxon, F. (1945). Individual comparisons by ranking methods. *Biometrics Bulletin, 1*(6), 80–83.

---

## Part 3. Notes for building it as a website

- **Separate from the app.** A small standalone site with no login, so lecturers and administration can open it without a VitalU account. It can live beside the admin dashboard, for example `/feedback/`.
- **One link per group.** Send a different link to each group, for example `?g=student`, `?g=lecturer`, `?g=admin`. Pre-select `role` from it, but still let people change it.
- **Store answers** in a new Supabase table such as `pilot_feedback`, with one row per submission and the IDs above as columns, or a single JSON `answers` column plus `role` and `submitted_at`. Row-level security: anyone can **insert**, nobody can read except admins. Store no IP address and no user ID.
- **Discourage duplicates** by saving a "submitted" flag in the browser after sending and showing a thank-you screen on return. Do not use logins or tracking.
- **Export.** Built in `evaluation/`: the private researcher page (`researcher.html`, not the campus admin dashboard) has a "Download CSV" button, so the data opens straight in jamovi, R or SPSS. Multi-select questions become one 0/1 column per option (for example `i_speed`, `i_design`).
- **Interaction:**
  - one section per screen with a progress bar
  - face icons for the 1 to 5 scales
  - feature cards using the app's own icons
  - side-by-side "before" and "now" sliders for Section 4
  - the next card slides in after each tap
- **Accessibility:**
  - large tap targets
  - works at 360 px width, in light and dark mode
  - every scale also has text labels, not faces alone
- **No em dashes** in any on-screen text, matching the app.
