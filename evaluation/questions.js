// The pilot evaluation form, as data. form.js renders it and researcher.js
// uses the same definitions to build the CSV, so the column names and codes
// always match docs/pilot-evaluation-form.md.
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

const ROLES = [
  ['student', 1, 'Undergraduate student'],
  ['lecturer', 2, 'Lecturer'],
  ['admin', 3, 'Administration or health centre staff'],
];

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
  [10, 'Not faculty-based'],
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

const USED = [
  ['used_app', 'I used the student app myself'],
  ['used_demo', 'I saw a demonstration of the student app'],
  ['used_dash', 'I used the admin dashboard'],
];

const FREQ = [
  [1, 'Once or twice'],
  [2, 'About once a week'],
  [3, 'A few times a week'],
  [4, 'Daily or almost daily'],
];

// System Usability Scale (Brooke, 1996), "system" as "app" and "cumbersome"
// as "awkward" (Finstad, 2006). Keep the wording and order.
const SUS = [
  'I think that I would like to use this app frequently.',
  'I found the app unnecessarily complex.',
  'I thought the app was easy to use.',
  'I think that I would need the support of a technical person to be able to use this app.',
  'I found the various functions in this app were well integrated.',
  'I thought there was too much inconsistency in this app.',
  'I would imagine that most people would learn to use this app very quickly.',
  'I found the app very awkward to use.',
  'I felt very confident using the app.',
  'I needed to learn a lot of things before I could get going with this app.',
];

const FEATURES = [
  ['f_body', 'Body checks', 'BMI and waist-to-hip ratio calculators', 'bmi'],
  ['f_heart', 'Heart health check', 'CVD risk indicator', 'progress'],
  ['f_mind', 'Anxiety tracker', 'DASS-21 self-check, calm music and relaxation ideas', 'stress'],
  ['f_water', 'Water tracker', 'Daily goal, bottle and reminders', 'water'],
  ['f_move', 'Activity and sleep trackers', 'Steps, active minutes and sleep log', 'steps'],
  ['f_cycle', 'Cycle tracker', 'Calendar, phases and notifications', 'progress', { femaleOnly: true }],
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

const DASHBOARD = [
  ['d_nav', 'The dashboard was easy to sign in to and find my way around, on a computer or phone.'],
  ['d_sched', 'Scheduling the assessment for different faculties and dates was straightforward.'],
  ['d_quest', 'Reviewing and editing the questionnaire was straightforward.'],
  ['d_analytics', 'The pooled analytics gave a clear picture of student health.'],
  ['d_complete', 'Checking assessment completion by registration number was useful.'],
  ['d_privacy', "I trust that the dashboard protects students' privacy (pooled results only, small groups hidden)."],
];

const PA_QUESTION = {
  student: 'How likely are you to complete the next six-monthly periodic health assessment in VitalU?',
  lecturer: 'How likely are you to encourage your students to complete the six-monthly periodic health assessment?',
  admin: 'How likely is your office to use the pooled assessment results to plan student health or nutrition support?',
};

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

const IMPROVE = [
  ['i_speed', 'Speed and reliability'],
  ['i_design', 'Look and layout'],
  ['i_easy', 'Easier to understand'],
  ['i_diet', 'Diet tools and food list'],
  ['i_trackers', 'Trackers (water, activity, sleep, cycle)'],
  ['i_learn', 'More or better Learn articles'],
  ['i_notify', 'Reminders and notifications'],
  ['i_help', 'Health support and consultations'],
  ['i_dash', 'Admin dashboard'],
  ['i_lang', 'Sinhala and Tamil language options'],
  ['i_other', 'Other'],
];

/** SUS score (0 to 100) from answers, or '' when any item is missing. */
function susScore(a) {
  let sum = 0;
  for (let i = 1; i <= 10; i++) {
    const v = a['sus' + i];
    if (typeof v !== 'number') return '';
    sum += i % 2 === 1 ? v - 1 : 5 - v;
  }
  return sum * 2.5;
}

/** CSV columns in analysis order: [header, (row) => value]. */
function csvColumns() {
  const ans = (k) => (r) => r.answers[k] ?? '';
  const flag = (list, k) => (r) => (Array.isArray(r.answers[list]) ? (r.answers[list].includes(k) ? 1 : 0) : '');
  const cols = [
    ['response_id', (r) => r.id],
    ['submitted_at', (r) => r.submitted_at],
    ['link_group', (r) => r.link_group ?? ''],
    ['consent', ans('consent')],
    ['role', (r) => (ROLES.find((x) => x[0] === r.role) || [])[1] ?? ''],
    ['faculty', ans('faculty')],
    ['year', ans('year')],
    ['sex', ans('sex')],
    ...USED.map(([k]) => [k, flag('used', k)]),
    ['freq', ans('freq')],
    ...SUS.map((_, i) => ['sus' + (i + 1), ans('sus' + (i + 1))]),
    ['sus_score', (r) => susScore(r.answers)],
    ...FEATURES.map(([k]) => [k, ans(k)]),
    ...PREPOST.flatMap(([k]) => [[k + '_pre', ans(k + '_pre')], [k + '_post', ans(k + '_post')]]),
    ...DASHBOARD.map(([k]) => [k, ans(k)]),
    ['pa_likely', ans('pa_likely')],
    ['pa_done', ans('pa_done')],
    ...PA_REASONS.map(([k]) => [k, flag('pa_reasons', k)]),
    ['pa_reasons_other', ans('pa_reasons_other')],
    ...IMPROVE.map(([k]) => [k, flag('improve_pick', k)]),
    ['improve_other', ans('improve_other')],
    ['recommend', ans('recommend')],
    ['open_best', ans('open_best')],
    ['open_improve', ans('open_improve')],
  ];
  return cols;
}
