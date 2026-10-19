// VitalU pilot evaluation form: one section per screen. The role chosen on the
// first screen picks one of two forms built on the same base questions:
//   student  evaluates the student app from their own use
//   staff    also used the app, so answers as a user; rates each feature for
//            how useful it will be for students; reviews the admin dashboard
// Answers stay in the browser until submitted, then go anonymously through
// submit_pilot_feedback().
'use strict';

const cfg = window.VITALU_EVAL;
const sb = window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseKey, { auth: { persistSession: false } });
const DRAFT_KEY = 'vitalu_eval_draft';
const POS_KEY = 'vitalu_eval_pos';
const SENT_KEY = 'vitalu_eval_sent';

const params = new URLSearchParams(location.search);
const g = params.get('g');
const linkRole = g === 'student' ? 'student' : g === 'staff' || LEGACY_ROLES[g] ? 'staff' : null;

const store = {
  get(k) { try { return JSON.parse(localStorage.getItem(k)); } catch { return null; } },
  set(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch { /* private mode */ } },
  del(k) { try { localStorage.removeItem(k); } catch { /* private mode */ } },
};

let A = store.get(DRAFT_KEY) || {};
if (LEGACY_ROLES[A.role]) A.role = LEGACY_ROLES[A.role];
if (linkRole && !A.role) A.role = linkRole;
let stepIndex = 0;
let featureIndex = 0;
let locked = false;

const el = document.getElementById('step');
const reduceMotion = () => matchMedia('(prefers-reduced-motion: reduce)').matches;
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
const save = () => store.set(DRAFT_KEY, A);
const isStudent = () => A.role === 'student';

// ---------------------------------------------------------------------------
// Which screens this person sees
// ---------------------------------------------------------------------------

function steps() {
  if (isStudent()) return ['role', 'consent', 'about', 'usab1', 'usab2', 'features', 'favourite', 'prepost', 'assessment', 'impact', 'improve', 'open'];
  return ['role', 'consent', 'about', 'usab1', 'usab2', 'features', 'favourite', 'prepost', 'dashboard', 'assessment', 'impact', 'improve', 'open'];
}

function featureList() {
  return FEATURES.filter((f) => !(f[4] && f[4].studentFemaleOnly && isStudent() && A.sex !== 1));
}

// ---------------------------------------------------------------------------
// Small renderers
// ---------------------------------------------------------------------------

function radios(name, options, { columns = false } = {}) {
  return `<div class="choices ${columns ? 'two' : ''}">${options
    .map(([v, label]) => `<label class="choice"><input type="radio" name="${name}" value="${v}" ${String(A[name]) === String(v) ? 'checked' : ''}><span>${esc(label)}</span></label>`)
    .join('')}</div>`;
}

function checks(name, options, { max } = {}) {
  const cur = Array.isArray(A[name]) ? A[name] : [];
  return `<div class="choices two" data-max="${max || ''}">${options
    .map(([v, label]) => `<label class="choice"><input type="checkbox" name="${name}" value="${v}" ${cur.includes(v) ? 'checked' : ''}><span>${esc(label)}</span></label>`)
    .join('')}</div>`;
}

function scale(name, options, ends) {
  return `<div><div class="scale" role="radiogroup">${options
    .map(([v, label]) => `<label class="choice"><input type="radio" name="${name}" value="${v}" aria-label="${v}, ${esc(label)}" ${A[name] === v ? 'checked' : ''}><span><b>${v}</b><small>${esc(label)}</small></span></label>`)
    .join('')}</div><div class="scale-ends" aria-hidden="true"><span>${esc(ends[0])}</span><span>${esc(ends[1])}</span></div></div>`;
}

const AGREE_ENDS = ['Strongly disagree', 'Strongly agree'];
const LIKELY_ENDS = ['Very unlikely', 'Very likely'];

const q = (id, label, body, hint) =>
  `<fieldset class="q" data-q="${id}"><legend>${esc(label)}${hint ? `<span class="hint">${esc(hint)}</span>` : ''}</legend>${body}</fieldset>`;

const statement = (id, text, body) => `<div class="statement" data-q="${id}"><div class="label">${esc(text)}</div>${body}</div>`;

function actions({ next = 'Continue', back = true } = {}) {
  return `<div class="form-actions">
    ${back ? '<button type="button" class="btn ghost" data-act="back">Back</button>' : ''}
    <button type="submit" class="btn primary">${esc(next)}</button>
  </div><p class="error-msg" id="err" role="alert" hidden></p>`;
}

// ---------------------------------------------------------------------------
// Screens
// ---------------------------------------------------------------------------

const screens = {
  role: () => `
    <h1>Give feedback</h1>
    <p class="lead">Choose the option that describes you. You will see questions made for your role.</p>
    <div class="roles">
      ${ROLES.map(([key, , label, text]) => `<button type="button" class="role-card" data-role="${key}" aria-pressed="${A.role === key}"><b>${esc(label)}</b><span>${esc(text)}</span></button>`).join('')}
    </div>`,

  consent: () => `
    <h1>Help us improve VitalU</h1>
    <p class="lead">You took part in the VitalU pilot. This short form asks what worked, what did not and what we should improve. It takes about 5 to 7 minutes.</p>
    <ul class="info">
      <li>Your answers are anonymous and taking part is voluntary. You can skip any question or stop at any time. Results are reported only as group totals in the research project "Development of an ADDIE-Based Mobile Health Platform to Improve Cardiometabolic Health among Undergraduate Students" by Miss. W.M.O.P.Wijesooriya attached to the Department of Food Science and Technology, Faculty of Agriculture, University of Peradeniya.</li>
      <li>Questions? Contact at <a href="mailto:fst20052@agri.pdn.ac.lk">fst20052@agri.pdn.ac.lk</a> or <a href="tel:+94777434769">+94 777 434769</a>.</li>
    </ul>
    ${q('consent', 'Do you agree to take part?', radios('consent', [[1, 'Yes, I have read the information and agree'], [0, 'No, I do not want to take part']]))}
    ${actions({ next: 'Start' })}`,

  about: () => isStudent() ? `
    <h1>About you</h1>
    <p class="lead">A few quick details, so we can see how different groups found VitalU. Nothing here identifies you.</p>
    ${q('faculty', 'Your faculty', `<select name="faculty" aria-label="Your faculty" class="full"><option value="">Select</option>${FACULTIES.map(([v, l]) => `<option value="${v}" ${A.faculty === v ? 'selected' : ''}>${esc(l)}</option>`).join('')}</select>`)}
    ${q('year', 'Your batch', radios('year', YEARS, { columns: true }))}
    ${q('sex', 'Sex', radios('sex', SEXES, { columns: true }))}
    ${q('freq', 'How often did you open the student app?', radios('freq', FREQ, { columns: true }))}
    ${actions()}` : `
    <h1>Your use of VitalU</h1>
    ${q('freq', 'How often did you open the student app during the pilot?', radios('freq', FREQ, { columns: true }))}
    ${actions()}`,

  usab1: () => usabilityScreen(0, 5, false),
  usab2: () => usabilityScreen(5, 8, true),

  features: () => `
    <h1>Student app features</h1>
    <p class="lead">${isStudent() ? 'How useful was each feature for you?' : 'How useful do you think each feature will be for students?'}</p>
    <div id="fc"></div>
    ${actions()}`,

  favourite: () => `
    <h1>Your favourite feature</h1>
    ${q('fav_feature', 'Which feature of the app did you like the most?', radios('fav_feature', [...featureList().map(([k, t]) => [k, t]), ['none', 'None of them, or not sure']], { columns: true }), 'Choose one.')}
    ${actions()}`,

  prepost: () => `
    <h1>Before and after VitalU</h1>
    <p class="lead">For each statement, think back to before you started using VitalU, then think about now.</p>
    ${PREPOST.map(([k, text]) => `
      <div class="pp" data-q="${k}">
        <div class="label">${esc(text)}</div>
        <div class="pp-row"><b>Before</b>${scale(k + '_pre', AGREE, AGREE_ENDS)}</div>
        <div class="pp-row now"><b>Now</b>${scale(k + '_post', AGREE, AGREE_ENDS)}</div>
      </div>`).join('')}
    ${actions()}`,

  dashboard: () => `
    <h1>The admin dashboard</h1>
    <p class="lead">Administration uses the dashboard to schedule the periodic health assessment by faculty and to see pooled, anonymous results. Students do not have access to it.</p>
    <div class="q"><label class="label" for="d_comment">What are your comments on the admin dashboard?<span class="hint">Optional. For example: how easy it is to use, what is missing, or what would help you plan student health support.</span></label>
      <textarea id="d_comment" name="d_comment" maxlength="1000">${esc(A.d_comment || '')}</textarea><div class="counter" data-for="d_comment"></div></div>
    ${actions()}`,

  assessment: () => isStudent()
    ? `
    <h1>The periodic health assessment</h1>
    <p class="lead">Every six months VitalU opens a short health check-in for each faculty. Answers are pooled anonymously to plan campus health support.</p>
    ${q('pa_likely', PA_QUESTION, scale('pa_likely', LIKELY, LIKELY_ENDS))}
    ${q('pa_done', 'Did you complete the periodic health assessment during the pilot?', radios('pa_done', PA_DONE, { columns: true }))}
    ${q('pa_reasons', 'What would make you more likely to complete it?', checks('pa_reasons', PA_REASONS, { max: 2 }), 'Optional. Select up to 2.')}
    <div data-other="pa_reasons" ${(A.pa_reasons || []).includes('r_other') ? '' : 'hidden'}><input type="text" name="pa_reasons_other" maxlength="200" placeholder="Tell us what would help" value="${esc(A.pa_reasons_other || '')}" aria-label="Other reason"></div>
    ${actions()}`
    : `
    <h1>The periodic health assessment</h1>
    <p class="lead">Every six months VitalU opens a short, anonymous health check-in for each faculty. The administration sees only pooled group results.</p>
    ${PA_STAFF.map(([k, text, opts, ends]) => q(k, text, scale(k, opts, ends))).join('')}
    ${actions()}`,

  impact: () => `
    <h1>The bigger picture</h1>
    <p class="callout">${esc(IMPACT_INTRO)}</p>
    ${statement('adopt_pref', ADOPT_PREF, scale('adopt_pref', AGREE, AGREE_ENDS))}
    ${isStudent() ? '' : statement('support_rollout', SUPPORT_ROLLOUT, scale('support_rollout', AGREE, AGREE_ENDS))}
    ${q('adopt_students', ADOPT_STUDENTS, scale('adopt_students', LIKELY, LIKELY_ENDS))}
    ${statement('impact', IMPACT, scale('impact', AGREE, AGREE_ENDS))}
    ${actions()}`,

  improve: () => `
    <h1>What should we improve?</h1>
    ${q('improve_pick', 'Which areas should we improve first?', checks('improve_pick', IMPROVE.filter((o) => !(o[2] && o[2].staffOnly && isStudent())).map(([k, l]) => [k, l]), { max: 3 }), 'Select up to 3.')}
    <div data-other="improve_pick" ${(A.improve_pick || []).includes('i_other') ? '' : 'hidden'}><input type="text" name="improve_other" maxlength="200" placeholder="What else should we improve?" value="${esc(A.improve_other || '')}" aria-label="Other area to improve"></div>
    ${actions()}`,

  open: () => `
    <h1>In your own words</h1>
    <p class="lead">Both questions are optional. Please do not include names or anything that could identify you or others.</p>
    <div class="q"><label class="label" for="open_overall">Do you have any overall comments about the VitalU initiative?</label>
      <textarea id="open_overall" name="open_overall" maxlength="1000">${esc(A.open_overall || '')}</textarea><div class="counter" data-for="open_overall"></div></div>
    <div class="q"><label class="label" for="open_improve">What should we change, fix or add?<span class="hint">Please be as specific as you can.</span></label>
      <textarea id="open_improve" name="open_improve" maxlength="1000">${esc(A.open_improve || '')}</textarea><div class="counter" data-for="open_improve"></div></div>
    ${actions({ next: 'Send my feedback' })}`,
};

function usabilityScreen(from, to, withLook) {
  const items = USABILITY.slice(from, to);
  return `
    <h1>Using the student app</h1>
    <p class="lead">Think about your experience using the VitalU app. How much do you agree with each statement? (${from === 0 ? `1 to ${to}` : `${from + 1} to ${to}`} of ${USABILITY.length})</p>
    ${items.map((text, i) => statement('us' + (from + i + 1), text, scale('us' + (from + i + 1), AGREE, AGREE_ENDS))).join('')}
    ${withLook ? statement('ui_look', UI_LOOK, scale('ui_look', AGREE, AGREE_ENDS)) : ''}
    ${actions()}`;
}

// The feature cards swap in place: only the card changes, so the rest of the
// page stays still while a student works through the list.
function cardHtml() {
  const list = featureList();
  const none = isStudent() ? 'Did not use' : 'Not sure';
  featureIndex = Math.max(0, Math.min(featureIndex, list.length));
  const dots = `<div class="dots" aria-hidden="true">${list.map(([k], i) => `<i class="${i === featureIndex ? 'now' : k in A ? 'done' : ''}"></i>`).join('')}</div>`;
  if (featureIndex >= list.length) {
    const answered = list.filter(([k]) => typeof A[k] === 'number').length;
    return `<div class="fcard"><h2>All ${list.length} features done</h2><p>You rated ${answered} of them. Continue, or go back to change an answer.</p></div>
      <div class="fnav"><button type="button" class="btn ghost" data-act="fprev">Review the last feature</button></div>${dots}`;
  }
  const [k, title, hint, img] = list[featureIndex];
  return `<div class="fcard" data-q="${k}">
      <img src="img/${img}.jpg" alt="">
      <h2>${esc(title)}</h2>
      <p>${esc(hint)}</p>
      <div class="faces" role="group" aria-label="How useful: ${esc(title)}">
        ${USEFUL.map(([v, label, e]) => `<button type="button" class="face" data-face="${v}" aria-pressed="${A[k] === v}"><span class="e" aria-hidden="true">${e}</span>${esc(label)}</button>`).join('')}
      </div>
      <div class="fnav">
        ${featureIndex > 0 ? '<button type="button" class="btn ghost" data-act="fprev">Previous feature</button>' : ''}
        <button type="button" class="btn ghost" data-face="skip" aria-pressed="${A[k] === null}">${none}</button>
      </div>
    </div>${dots}`;
}

function paintCard(animate) {
  const box = el.querySelector('#fc');
  if (!box) return;
  box.innerHTML = cardHtml();
  const btn = el.querySelector('button[type="submit"]');
  if (btn) btn.textContent = featureIndex >= featureList().length ? 'Continue' : 'Skip the rest';
  if (animate && !reduceMotion()) {
    box.classList.remove('swap');
    void box.offsetWidth;
    box.classList.add('swap');
  }
}

// ---------------------------------------------------------------------------
// Validation: only what steers the form, plus the usability items (the score
// cannot be worked out with a gap).
// ---------------------------------------------------------------------------

function missing(id) {
  switch (id) {
    case 'consent': return A.consent === undefined ? ['consent'] : [];
    case 'usab1': return [1, 2, 3, 4, 5].map((i) => 'us' + i).filter((k) => typeof A[k] !== 'number');
    case 'usab2': return [6, 7, 8].map((i) => 'us' + i).filter((k) => typeof A[k] !== 'number');
    default: return [];
  }
}

// ---------------------------------------------------------------------------
// Rendering and navigation
// ---------------------------------------------------------------------------

function render({ animate = true } = {}) {
  const list = steps();
  stepIndex = Math.max(0, Math.min(stepIndex, list.length - 1));
  const id = list[stepIndex];
  el.innerHTML = screens[id]();
  el.classList.remove('enter', 'enter-back');
  if (animate && !reduceMotion()) {
    void el.offsetWidth;
    el.classList.add(animate === 'back' ? 'enter-back' : 'enter');
  }
  if (id === 'features') paintCard(false);

  // The role screen comes before the form proper, so it has no progress yet.
  document.getElementById('progress').hidden = id === 'role';
  const pct = Math.round((stepIndex / list.length) * 100);
  document.getElementById('progress-fill').style.width = pct + '%';
  document.querySelector('.progress .track').setAttribute('aria-valuenow', String(pct));
  document.getElementById('progress-count').textContent = `${stepIndex + 1} of ${list.length}`;
  updateCounters();
  enforceMax();
  store.set(POS_KEY, stepIndex);
}

function go(delta) {
  stepIndex += delta;
  const id = steps()[stepIndex];
  if (id === 'features') featureIndex = delta < 0 ? featureList().length : firstUnrated();
  render({ animate: delta < 0 ? 'back' : true });
  window.scrollTo({ top: 0, behavior: reduceMotion() ? 'auto' : 'smooth' });
  const h = el.querySelector('h1');
  h?.setAttribute('tabindex', '-1');
  h?.focus({ preventScroll: true });
}

function firstUnrated() {
  const list = featureList();
  const i = list.findIndex(([k]) => !(k in A));
  return i === -1 ? list.length : i;
}

function readInput(t) {
  const name = t.name;
  if (!name) return;
  if (t.type === 'checkbox') {
    const all = [...el.querySelectorAll(`input[name="${name}"]:checked`)].map((x) => x.value);
    A[name] = all;
    const other = el.querySelector(`[data-other="${name}"]`);
    if (other) other.hidden = !all.some((v) => v.endsWith('_other'));
    enforceMax();
  } else if (t.type === 'radio') {
    const n = Number(t.value);
    A[name] = Number.isNaN(n) ? t.value : n;
  } else if (t.tagName === 'SELECT') {
    A[name] = t.value === '' ? undefined : Number(t.value);
  } else {
    A[name] = t.value;
  }
  save();
}

function enforceMax() {
  el.querySelectorAll('.choices[data-max]').forEach((box) => {
    const max = Number(box.dataset.max);
    if (!max) return;
    const boxes = [...box.querySelectorAll('input[type="checkbox"]')];
    const n = boxes.filter((b) => b.checked).length;
    boxes.forEach((b) => (b.disabled = !b.checked && n >= max));
  });
}

function updateCounters() {
  el.querySelectorAll('.counter').forEach((c) => {
    const t = el.querySelector(`#${c.dataset.for}`);
    c.textContent = `${t.value.length} / ${t.maxLength}`;
  });
}

// Choosing an answer only records it. It never redraws the screen.
el.addEventListener('change', (e) => {
  readInput(e.target);
  e.target.closest('[data-q]')?.classList.remove('invalid');
});

el.addEventListener('input', (e) => {
  if (e.target.matches('textarea, input[type="text"]')) {
    readInput(e.target);
    updateCounters();
  }
});

el.addEventListener('click', (e) => {
  const r = e.target.closest('.role-card');
  if (r) {
    A.role = r.dataset.role;
    save();
    return go(1);
  }
  const b = e.target.closest('button');
  if (!b) return;
  if (b.dataset.act === 'back') return go(-1);
  if (b.dataset.act === 'fprev') {
    featureIndex = Math.max(0, featureIndex - 1);
    return paintCard(true);
  }
  if (b.dataset.face && !locked) {
    const [k] = featureList()[featureIndex];
    A[k] = b.dataset.face === 'skip' ? null : Number(b.dataset.face);
    save();
    b.closest('.fcard').querySelectorAll('[aria-pressed]').forEach((x) => x.setAttribute('aria-pressed', String(x === b)));
    // Let the choice show for a moment, then swap in the next card.
    locked = true;
    setTimeout(() => {
      locked = false;
      featureIndex += 1;
      paintCard(true);
      el.querySelector('.face, [data-act="fprev"]')?.focus({ preventScroll: true });
    }, 220);
  }
});

el.addEventListener('submit', async (e) => {
  e.preventDefault();
  const list = steps();
  const id = list[stepIndex];
  const m = missing(id);
  const err = el.querySelector('#err');
  if (m.length) {
    m.forEach((k) => el.querySelector(`[data-q="${k}"]`)?.classList.add('invalid'));
    err.hidden = false;
    err.textContent = id.startsWith('usab')
      ? 'Please answer every statement on this page. The usability score needs all of them.'
      : 'Please answer the highlighted question to continue.';
    el.querySelector('.invalid')?.scrollIntoView({ block: 'center', behavior: 'smooth' });
    return;
  }
  if (id === 'consent' && A.consent === 0) return showDeclined();
  if (stepIndex < list.length - 1) return go(1);
  await submit();
});

// ---------------------------------------------------------------------------
// Submit and end screens
// ---------------------------------------------------------------------------

function cleanAnswers() {
  // Keep only answers for questions this person was actually shown, so
  // switching role midway does not leave stray values.
  const keep = new Set(['consent', 'role', 'freq', 'ui_look', 'fav_feature', 'adopt_pref', 'adopt_students', 'impact', 'improve_pick', 'improve_other', 'open_overall', 'open_improve']);
  USABILITY.forEach((_, i) => keep.add('us' + (i + 1)));
  featureList().forEach(([k]) => keep.add(k));
  PREPOST.forEach(([k]) => { keep.add(k + '_pre'); keep.add(k + '_post'); });
  if (isStudent()) {
    ['faculty', 'year', 'sex', 'pa_likely', 'pa_done', 'pa_reasons', 'pa_reasons_other'].forEach((k) => keep.add(k));
  } else {
    ['d_comment', 'support_rollout'].forEach((k) => keep.add(k));
    PA_STAFF.forEach(([k]) => keep.add(k));
  }
  const out = {};
  for (const k of keep) {
    const v = A[k];
    if (v === undefined || v === '' || (Array.isArray(v) && !v.length)) continue;
    out[k] = typeof v === 'string' ? v.trim().slice(0, 1000) : v;
  }
  if (isStudent() && out.improve_pick) out.improve_pick = out.improve_pick.filter((k) => k !== 'i_dash');
  if (!(out.improve_pick || []).includes('i_other')) delete out.improve_other;
  if (!(out.pa_reasons || []).includes('r_other')) delete out.pa_reasons_other;
  return out;
}

async function submit() {
  const btn = el.querySelector('button[type="submit"]');
  const err = el.querySelector('#err');
  btn.disabled = true;
  btn.textContent = 'Sending…';
  const { error } = await sb.rpc('submit_pilot_feedback', { p_role: A.role, p_group: linkRole, p_answers: cleanAnswers() });
  if (error) {
    btn.disabled = false;
    btn.textContent = 'Send my feedback';
    err.hidden = false;
    err.textContent = 'Your feedback was not sent. Check your connection and press Send again. Your answers are still here.';
    return;
  }
  store.del(DRAFT_KEY);
  store.del(POS_KEY);
  store.set(SENT_KEY, new Date().toISOString());
  showThanks();
}

const check = '<div class="done-mark"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg></div>';

function endScreen(html) {
  document.getElementById('progress').hidden = true;
  el.innerHTML = html;
  el.classList.remove('enter-back');
  if (!reduceMotion()) el.classList.add('enter');
  const h = el.querySelector('h1');
  h?.setAttribute('tabindex', '-1');
  h?.focus();
}

function restart() {
  A = linkRole ? { role: linkRole } : {};
  save();
  featureIndex = 0;
  stepIndex = linkRole ? 1 : 0;
  render();
}

function showThanks() {
  endScreen(`${check}<h1>Thank you!</h1>
    <p class="lead">Your feedback was sent. It will shape the next version of VitalU.</p>
    <div class="form-actions"><a class="btn ghost" href="./">Back to the VitalU page</a></div>`);
}

function showDeclined() {
  endScreen(`<h1>No problem</h1>
    <p class="lead">You chose not to take part, so nothing was sent. If you change your mind, you can start again at any time.</p>
    <div class="form-actions"><a class="btn ghost" href="./">Back to the VitalU page</a><button type="button" class="btn primary" id="restart">Start again</button></div>`);
  el.querySelector('#restart').onclick = restart;
}

function showAlreadySent() {
  endScreen(`${check}<h1>You have already sent your feedback</h1>
    <p class="lead">Thank you. If someone else is using this device and wants to take part, they can start a new response.</p>
    <div class="form-actions"><a class="btn ghost" href="./">Back to the VitalU page</a><button type="button" class="btn primary" id="again">Start a new response</button></div>`);
  el.querySelector('#again').onclick = () => { store.del(SENT_KEY); restart(); };
}

if (store.get(SENT_KEY) && !store.get(DRAFT_KEY)) {
  showAlreadySent();
} else {
  // Resume where the person left off. A link that names the role skips the
  // role screen, and Back still returns to it.
  const saved = store.get(POS_KEY);
  stepIndex = A.role ? (typeof saved === 'number' && saved > 0 ? saved : linkRole ? 1 : 0) : 0;
  if (steps()[stepIndex] === 'features') featureIndex = firstUnrated();
  render({ animate: false });
}
