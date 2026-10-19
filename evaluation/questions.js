// The pilot evaluation form, as data. form.js renders it and researcher.js
// uses the same definitions to build the CSV, so the column names and codes
// always match docs/pilot-evaluation-form.md.
//
// Two forms share one set of base questions:
//   student  Undergraduates evaluate the student app (how it was for them).
//   staff    Lecturers, administration, health centre staff and technical
//            experts, who also used the app. They answer as users, rate
//            each feature for how useful it will be for students, and
//            review the admin dashboard.
'use strict';

const AGREE = [
  [1, 'Strongly disagree'],
  [2, 'Disagree'],
  [3, 'Neutral'],
  [4, 'Agree'],
  [5, 'Strongly agree'],
];

const USEFUL = [
  [1, 'Not useful', '😞'],
  [2, 'Slightly', '🙁'],
  [3, 'Moderately', '😐'],
  [4, 'Very useful', '🙂'],
  [5, 'Extremely', '😄'],
];

const LIKELY = [
  [1, 'Very unlikely'],
  [2, 'Unlikely'],
  [3, 'Not sure'],
  [4, 'Likely'],
  [5, 'Very likely'],
];

const VALUABLE = [
  [1, 'Not valuable'],
  [2, 'Slightly'],
  [3, 'Moderately'],
  [4, 'Valuable'],
  [5, 'Very valuable'],
];

// Role chosen at the entry to the form. The second group is one category.
const ROLES = [
  ['student', 1, 'Undergraduate student', 'You took part in the pilot as a student.'],
  ['staff', 2, 'Lecturer, administration or health centre staff, technical expert', 'You used VitalU during the pilot and are reviewing it for students and the university.'],
];
// Roles saved by an earlier version of the form.
const LEGACY_ROLES = { lecturer: 'staff', admin: 'staff' };

const FACULTIES = [
  [1, 'Agriculture'],
  [2, 'Allied Health Sciences'],
  [3, 'Arts'],
  [4, 'Dental Sciences'],
  [5, 'Engineering'],
  [6, 'Management'],
  [7, 'Medicine'],
  [8, 'Science'],
  [9, 'Veterinary Medicine and Animal Science'],
];

const YEARS = [
  [1, '1st year'],
  [2, '2nd year'],
  [3, '3rd year'],
  [4, '4th year or above'],
];

const SEXES = [
  [1, 'Female'],
  [2, 'Male'],
  [3, 'Prefer not to say'],
];

const FREQ = [
  [1, 'Once or twice'],
  [2, 'About once a week'],
  [3, 'A few times a week'],
  [4, 'Daily or almost daily'],
];

// Usability items, adapted from the System Usability Scale (Brooke, 1996),
// "system" as "app" and "cumbersome" as "awkward" (Finstad, 2006). Items 9 and
// 10 of the standard scale are left out because they repeat items 3 and 7, so
// the result is a usability score out of 100 from eight items, not a standard
// SUS score. Do not compare it with the published SUS benchmarks.
const USABILITY = [
  'I think that I would like to use this app frequently.',
  'I found the app unnecessarily complex.',
  'I thought the app was easy to use.',
  'I think that I would need the support of a technical person to be able to use this app.',
  'I found the various functions in this app were well integrated.',
  'I thought there was too much inconsistency in this app.',
  'I would imagine that most people would learn to use this app very quickly.',
  'I found the app very awkward to use.',
];

const UI_LOOK = 'The screens, animations, illustrations and images made VitalU clearer and more pleasant to use.';

const FEATURES = [
  ['f_body', 'Body checks', 'BMI and waist-to-hip ratio calculators', 'bmi'],
  ['f_heart', 'Heart health check', 'CVD risk indicator', 'progress'],
  ['f_mind', 'Anxiety tracker', 'DASS-21 self-check, calm music and relaxation ideas', 'stress'],
  ['f_water', 'Water tracker', 'Daily goal, bottle and reminders', 'water'],
  ['f_move', 'Activity and sleep trackers', 'Steps, active minutes and sleep log', 'steps'],
  ['f_cycle', 'Cycle tracker', 'Calendar, phases and notifications', 'progress', { studentFemaleOnly: true }],
  ['f_diet', 'Diet tools', 'Calorie counter, meal diary, healthy plate, diversity guide, budget planner', 'diet'],
  ['f_learn', 'Learn articles', 'Health topics written for students', 'assessment'],
  ['f_badges', 'Badges and streaks', 'Aqua Achiever, Active Aura, Smart Eater and others', 'water'],
  ['f_notify', 'Reminders', 'Morning, evening and water notifications', 'progress'],
  ['f_help', 'Getting help', 'Ask anonymously, campus professionals, emergency numbers', 'consult'],
  ['f_report', 'Your progress', 'Home dashboard, summary and personal health report (PDF)', 'progress'],
];

const PREPOST = [
  ['pp1', 'I understand what my own health numbers (BMI, waist, blood pressure) mean.'],
  ['pp2', 'I pay attention to how balanced and varied my meals are.'],
  ['pp3', 'I drink enough water and stay active most days.'],
  ['pp4', 'I know where to get health or mental health support on campus.'],
];

// Periodic health assessment: students are asked about their own use.
const PA_QUESTION = 'How likely are you to complete the next six-monthly periodic health assessment in VitalU?';

const PA_DONE = [
  [1, 'Yes'],
  [2, 'Started but did not finish'],
  [3, 'No'],
  [4, 'It was not open for my faculty'],
];

const PA_REASONS = [
  ['r_short', 'It being shorter'],
  ['r_remind', 'A reminder when it opens'],
  ['r_results', 'Seeing my own results afterwards'],
  ['r_privacy', 'Being sure it is anonymous'],
  ['r_time', 'A quieter time in the semester'],
  ['r_other', 'Other'],
];

// ...and the staff group is asked related questions about the same process.
const PA_STAFF = [
  ['pa_value', 'How valuable do you think a six-monthly periodic health assessment is for understanding and supporting student health?', VALUABLE, ['Not valuable', 'Very valuable']],
  ['pa_students', 'How likely do you think students are to complete it every six months?', LIKELY, ['Very unlikely', 'Very likely']],
  ['pa_use', 'How likely are you to encourage students to complete it, or to use its pooled results in your work?', LIKELY, ['Very unlikely', 'Very likely']],
];

const IMPACT_INTRO =
  'A health monitoring system like VitalU is being introduced at a university in Sri Lanka for the very first time. Its impact builds with long-term use, so these questions ask what you expect over time.';

// Asked of everyone in the same words, so the two groups can be compared.
const ADOPT_PREF = 'I would like to keep using VitalU.';
// Staff only: whether they back a wider roll-out.
const SUPPORT_ROLLOUT = 'I would support rolling VitalU out to all students at the university.';
const ADOPT_STUDENTS = 'How likely do you think students at the university are to adopt VitalU and keep using it?';
const IMPACT = "I think an initiative like VitalU can change young people's lifestyles and habits, and help build a healthier generation of young adults.";

const IMPROVE = [
  ['i_speed', 'Speed and reliability'],
  ['i_design', 'Look and layout'],
  ['i_easy', 'Easier to understand'],
  ['i_diet', 'Diet tools and food list'],
  ['i_trackers', 'Trackers (water, activity, sleep, cycle)'],
  ['i_learn', 'More or better Learn articles'],
  ['i_notify', 'Reminders and notifications'],
  ['i_help', 'Health support and consultations'],
  ['i_dash', 'Admin dashboard', { staffOnly: true }],
  ['i_lang', 'Sinhala and Tamil language options'],
  ['i_other', 'Other'],
];

/**
 * Usability score (0 to 100) from the eight usability items, or '' when any is
 * missing. Odd items are positive (answer - 1), even items negative (5 - answer).
 */
function usabilityScore(a) {
  let sum = 0;
  for (let i = 1; i <= USABILITY.length; i++) {
    const v = a['us' + i];
    if (typeof v !== 'number') return '';
    sum += i % 2 === 1 ? v - 1 : 5 - v;
  }
  return Math.round((sum / (USABILITY.length * 4)) * 1000) / 10;
}

/** CSV columns in analysis order: [header, (row) => value]. */
function csvColumns() {
  const ans = (k) => (r) => r.answers[k] ?? '';
  const flag = (list, k) => (r) => (Array.isArray(r.answers[list]) ? (r.answers[list].includes(k) ? 1 : 0) : '');
  const roleOf = (r) => LEGACY_ROLES[r.role] || r.role;
  return [
    ['response_id', (r) => r.id],
    ['submitted_at', (r) => r.submitted_at],
    ['link_group', (r) => r.link_group ?? ''],
    ['consent', ans('consent')],
    ['role', (r) => (ROLES.find((x) => x[0] === roleOf(r)) || [])[1] ?? ''],
    ['faculty', ans('faculty')],
    ['year', ans('year')],
    ['sex', ans('sex')],
    ['freq', ans('freq')],
    ...USABILITY.map((_, i) => ['us' + (i + 1), ans('us' + (i + 1))]),
    ['usability_score', (r) => usabilityScore(r.answers)],
    ['ui_look', ans('ui_look')],
    ...FEATURES.map(([k]) => [k, ans(k)]),
    ['fav_feature', ans('fav_feature')],
    ...PREPOST.flatMap(([k]) => [[k + '_pre', ans(k + '_pre')], [k + '_post', ans(k + '_post')]]),
    ['d_comment', ans('d_comment')],
    ['pa_likely', ans('pa_likely')],
    ['pa_done', ans('pa_done')],
    ...PA_REASONS.map(([k]) => [k, flag('pa_reasons', k)]),
    ['pa_reasons_other', ans('pa_reasons_other')],
    ...PA_STAFF.map(([k]) => [k, ans(k)]),
    ['adopt_pref', ans('adopt_pref')],
    ['support_rollout', ans('support_rollout')],
    ['adopt_students', ans('adopt_students')],
    ['impact', ans('impact')],
    ...IMPROVE.map(([k]) => [k, flag('improve_pick', k)]),
    ['improve_other', ans('improve_other')],
    ['open_overall', ans('open_overall')],
    ['open_improve', ans('open_improve')],
  ];
}
