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
  ['staff', 2, 'Lecturer, administration or health centre staff, technical expert', 'You are reviewing VitalU for students and the university.'],
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

// Overall adoption preference, worded for each role.
const ADOPT_PREF = {
  student: 'I would like to keep using VitalU.',
  staff: 'I would support rolling VitalU out to all students at the university.',
};
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

// Favourite feature as a number for analysis: 1 to 12 in FEATURES order,
// 13 = none of them, or not sure.
const FAV_CODES = [...FEATURES.map(([k, t], i) => [i + 1, t, k]), [13, 'None of them, or not sure', 'none']];

/**
 * Every exported column, in analysis order. One row per response, one column
 * per field, numbers wherever the answer is a choice, so the file opens
 * straight in jamovi, SPSS, R or Excel. Each field:
 *   col      column name
 *   section  part of the form
 *   q        question or statement as shown (or a description)
 *   values   [code, label] pairs for coded answers (omitted for text/number)
 *   shown    who sees it
 *   get(r)   the value for one response ('' when blank)
 */
function fields() {
  const ans = (k) => (r) => r.answers[k] ?? '';
  const flag = (list, k) => (r) => (Array.isArray(r.answers[list]) ? (r.answers[list].includes(k) ? 1 : 0) : '');
  const roleOf = (r) => LEGACY_ROLES[r.role] || r.role;
  const ticked = [[0, 'Not ticked'], [1, 'Ticked']];
  const both = 'Both groups';
  const bothDiff = (k) => (r) => {
    const a = r.answers[k + '_pre'];
    const b = r.answers[k + '_post'];
    return typeof a === 'number' && typeof b === 'number' ? b - a : '';
  };
  return [
    { col: 'response_id', section: 'Record', q: 'Unique id of the response', get: (r) => r.id, shown: 'System' },
    { col: 'submitted_at', section: 'Record', q: 'Date and time submitted (UTC)', get: (r) => r.submitted_at, shown: 'System' },
    { col: 'link_group', section: 'Record', q: 'Group named in the link used (student or staff), blank if none', get: (r) => r.link_group ?? '', shown: 'System' },
    { col: 'consent', section: 'Consent', q: 'Do you agree to take part?', values: [[1, 'Yes'], [0, 'No']], get: ans('consent'), shown: both },
    { col: 'role', section: 'About you', q: 'Role', values: ROLES.map(([, c, l]) => [c, l]), get: (r) => (ROLES.find((x) => x[0] === roleOf(r)) || [])[1] ?? '', shown: both },
    { col: 'faculty', section: 'About you', q: 'Your faculty', values: FACULTIES, get: ans('faculty'), shown: 'Students' },
    { col: 'year', section: 'About you', q: 'Your batch', values: YEARS, get: ans('year'), shown: 'Students' },
    { col: 'sex', section: 'About you', q: 'Sex', values: SEXES, get: ans('sex'), shown: 'Students' },
    { col: 'freq', section: 'About you', q: 'How often did you open the student app?', values: FREQ, get: ans('freq'), shown: both },
    ...USABILITY.map((q, i) => ({ col: 'us' + (i + 1), section: 'Usability', q, values: AGREE, get: ans('us' + (i + 1)), shown: both })),
    { col: 'usability_score', section: 'Usability', q: 'Usability score 0 to 100 from us1 to us8 (odd items: answer minus 1; even items: 5 minus answer; sum divided by 32, times 100). Blank unless all eight are answered.', get: (r) => usabilityScore(r.answers), shown: 'Computed' },
    { col: 'ui_look', section: 'Usability', q: UI_LOOK, values: AGREE, get: ans('ui_look'), shown: both },
    ...FEATURES.map(([k, t, hint]) => ({
      col: k,
      section: 'Feature usefulness',
      q: `${t} (${hint}). Students: how useful was it for you? Staff: how useful will it be for students? Blank means did not use or not sure.`,
      values: USEFUL.map(([c, l]) => [c, l]),
      get: ans(k),
      shown: k === 'f_cycle' ? 'Female students and staff' : both,
    })),
    { col: 'fav_feature', section: 'Feature usefulness', q: 'Which feature of the app did you like the most?', values: FAV_CODES.map(([c, l]) => [c, l]), get: (r) => (FAV_CODES.find((x) => x[2] === r.answers.fav_feature) || [])[0] ?? '', shown: both },
    ...PREPOST.flatMap(([k, q]) => [
      { col: k + '_pre', section: 'Before and after', q: `Before using VitalU: ${q}`, values: AGREE, get: ans(k + '_pre'), shown: both },
      { col: k + '_post', section: 'Before and after', q: `Now: ${q}`, values: AGREE, get: ans(k + '_post'), shown: both },
      { col: k + '_diff', section: 'Before and after', q: `${k}_post minus ${k}_pre (positive means improved). Blank unless both are answered.`, get: bothDiff(k), shown: 'Computed' },
    ]),
    { col: 'd_comment', section: 'Admin dashboard', q: 'What are your comments on the admin dashboard?', get: ans('d_comment'), shown: 'Staff' },
    { col: 'pa_likely', section: 'Periodic assessment', q: PA_QUESTION, values: LIKELY, get: ans('pa_likely'), shown: 'Students' },
    { col: 'pa_done', section: 'Periodic assessment', q: 'Did you complete the periodic health assessment during the pilot?', values: PA_DONE, get: ans('pa_done'), shown: 'Students' },
    ...PA_REASONS.map(([k, l]) => ({ col: k, section: 'Periodic assessment', q: `What would make you more likely to complete it? ${l}`, values: ticked, get: flag('pa_reasons', k), shown: 'Students' })),
    { col: 'pa_reasons_other', section: 'Periodic assessment', q: 'Other reason (text)', get: ans('pa_reasons_other'), shown: 'Students' },
    ...PA_STAFF.map(([k, q, opts]) => ({ col: k, section: 'Periodic assessment', q, values: opts, get: ans(k), shown: 'Staff' })),
    { col: 'adopt_pref', section: 'Bigger picture', q: `Overall adoption preference. Students: "${ADOPT_PREF.student}" Staff: "${ADOPT_PREF.staff}"`, values: AGREE, get: ans('adopt_pref'), shown: both },
    { col: 'adopt_students', section: 'Bigger picture', q: ADOPT_STUDENTS, values: LIKELY, get: ans('adopt_students'), shown: both },
    { col: 'impact', section: 'Bigger picture', q: IMPACT, values: AGREE, get: ans('impact'), shown: both },
    ...IMPROVE.map(([k, l]) => ({ col: k, section: 'Improve', q: `Which areas should we improve first? ${l}`, values: ticked, get: flag('improve_pick', k), shown: k === 'i_dash' ? 'Staff' : both })),
    { col: 'improve_other', section: 'Improve', q: 'Other area to improve (text)', get: ans('improve_other'), shown: both },
    { col: 'open_overall', section: 'In your own words', q: 'Do you have any overall comments about the VitalU initiative?', get: ans('open_overall'), shown: both },
    { col: 'open_improve', section: 'In your own words', q: 'What should we change, fix or add?', get: ans('open_improve'), shown: both },
  ];
}

/** CSV columns in analysis order: [header, (row) => value]. */
function csvColumns() {
  return fields().map((f) => [f.col, f.get]);
}

/** The label for a coded value, or the value itself. */
function labelOf(field, v) {
  if (v === '' || v === null || v === undefined || !field.values) return v ?? '';
  const hit = field.values.find(([c]) => String(c) === String(v));
  return hit ? hit[1] : v;
}
