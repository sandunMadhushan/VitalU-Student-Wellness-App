# VitalU outcome framework: did the app reduce cardiometabolic risk?

VitalU's goal is to reduce cardiometabolic risk among university students. Awareness
tools alone don't show that, so this document sets out what to measure and how.
It is a proposal for the team and the ethics reviewer to adjust, not a finished protocol.

## 1. What can realistically be shown

Students are young, so heart disease and diabetes are decades away for most of them. A
student app can credibly change, and so be evaluated on:

1. **Risk-factor behaviours**: activity, diet quality, sugary drinks, smoking and vaping, sleep.
2. **Early detection**: students with raised BP, glucose or waist who get checked and followed up.
3. **Engagement**: whether students keep using it long enough for 1 and 2 to happen.

Disease prevalence is not a feasible outcome for this study. Report it only as a long-term
aim.

## 2. Indicators

| Domain | Indicator | Source (already in the app) | Direction |
|---|---|---|---|
| Activity | Median active minutes per week; % meeting 150 min/week | Activity tracker, IPAQ-SF | up |
| Sedentary time | Daily sitting hours | Periodic assessment | down |
| Diet | Diet diversity score; fruit and vegetable days per week | Diversity tracker, assessment | up |
| Sugar | Sugar-sweetened drinks per week | Habits, assessment | down |
| Fried / packaged food | Times per week | Habits, assessment | down |
| Tobacco | Current smoking or vaping (%) | Assessment | down |
| Sleep | Mean hours; PSQI score | Sleep tracker, PSQI | healthy range |
| Adiposity | Waist-to-hip ratio; BMI (Asian cut-offs) | WHR, BMI tools, assessment | healthy range |
| Blood pressure | % of recorded readings in the normal band | Vitals log | up |
| Detection | % of students with an out-of-range reading who report a clinical follow-up | **Needs adding** (follow-up question) | up |
| Engagement | Day-7 / day-30 retention; logs per active week | **Needs adding** (privacy-preserving usage events) | up |

Choose **2 to 3 primary outcomes** before analysis (suggested: weekly active minutes,
sugar-sweetened drinks per week, and follow-up after an out-of-range reading) and treat the
rest as secondary. Fixing them in advance avoids picking whatever happens to improve.

## 3. Design options (weakest to strongest)

1. **Pre/post by term, consenting students only.** Uses the existing periodic assessments.
   Shows association, not effect. Cannot rule out that students improve over a term anyway.
2. **Dose-response within users.** Compare change between heavy and light users. Still
   observational (healthier students may use the app more); adjust for baseline, faculty,
   sex and batch.
3. **Stepped rollout by faculty.** Faculties get the app (or a new feature) at different
   times, so later faculties act as a comparison. Much stronger and practical for a campus.
4. **Randomised comparison** (individual or faculty-level) if the ethics board and
   university allow it. Strongest.

Recommended: start with 1 and 2 now, and plan for 3 once the goal loop (section 5) exists.

## 4. Analysis plan (minimum)

- Report the number who consented, completed baseline and completed follow-up, and why
  people dropped out. Report results only for those with both measurements, plus a
  comparison of leavers against stayers.
- Within-person change on each primary outcome with a 95% confidence interval.
- Adjust for baseline value, sex, faculty and batch.
- Report effect sizes and intervals, not just p-values. Say plainly that observational
  designs cannot prove cause.
- Keep small-group protection: suppress any cell with fewer than 10 students and any
  complementary cell that would reveal it. (The current analytics view uses 5; raise it.)

## 5. What to build so the outcomes can move

1. **One goal loop.** Pick a target behaviour, set a goal, track it, get weekly feedback.
   For example swap sugary drinks, log them, see the weekly count, earn a badge for the effort.
2. **Next steps for out-of-range readings.** Done in this change for BP, glucose and
   triglycerides (`lib/data/vital_guidance.dart`).
3. **Follow-up question.** A week after an out-of-range reading, ask "Have you seen a
   doctor or repeated the test?" and record yes/no. This is the detection indicator above.
4. **Usage events** (screen opened, log saved, goal set), with no health values, for
   retention and engagement.

## 6. Ethics and privacy

- Use explicit, separate, revocable research consent. Do not bundle it with sign-up.
- Say clearly what leaves the device: AI features send images and reports to a third-party model.
- Take data protection (Sri Lanka PDPA No. 9 of 2022) and ethics-committee approval into account before collecting follow-up data.
- Publish negative or null findings too.

## 7. Timeline sketch

| When | What |
|---|---|
| Now | Fix primary outcomes; add follow-up question and usage events |
| Term 1 | Baseline assessment, collect engagement data |
| Term 2 | Follow-up assessment, first pre/post and dose-response analysis |
| Term 3+ | Stepped rollout of the goal loop; evaluate against comparison faculties |
