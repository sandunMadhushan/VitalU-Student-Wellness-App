// VitalU pilot evaluation form: one section per screen, with branching by
// role and by which parts of VitalU the person used. Answers are kept in the
// browser until submitted, then sent anonymously through
// submit_pilot_feedback().
'use strict';

const cfg = window.VITALU_EVAL;
const sb = window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseKey, { auth: { persistSession: false } });
const DRAFT_KEY = 'vitalu_eval_draft';
const SENT_KEY = 'vitalu_eval_sent';

const params = new URLSearchParams(location.search);
const linkGroup = ['student', 'lecturer', 'admin'].includes(params.get('g')) ? params.get('g') : null;

const store = {
  get(k) { try { return JSON.parse(localStorage.getItem(k)); } catch { return null; } },
  set(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch { /* private mode */ } },
  del(k) { try { localStorage.removeItem(k); } catch { /* private mode */ } },
};

let A = store.get(DRAFT_KEY) || {};
if (linkGroup && !A.role) A.role = linkGroup;
let stepIndex = 0;
let featureIndex = 0;
let direction = 1;

const el = document.getElementById('step');
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
const save = () => store.set(DRAFT_KEY, A);
const used = (k) => Array.isArray(A.used) && A.used.includes(k);
const isStudent = () => A.role === 'student';

// ---------------------------------------------------------------------------
// Which screens this person sees
// ---------------------------------------------------------------------------

function steps() {
  const s = ['consent', 'about'];
  if (used('used_app')) s.push('sus1', 'sus2');
  s.push('features');
  if (isStudent() && used('used_app')) s.push('prepost');
  if (used('used_dash')) s.push('dashboard');
  s.push('assessment', 'improve', 'open');
  return s;
}

function visibleFeatures() {
  return FEATURES.filter((f) => !(f[4] && f[4].femaleOnly && A.sex !== 1));
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

const q = (id, label, body, hint) =>
  `<fieldset class="q" data-q="${id}"><legend>${esc(label)}${hint ? `<span class="hint">${esc(hint)}</span>` : ''}</legend>${body}</fieldset>`;

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
  consent: () => `
    <h1>Help us improve VitalU</h1>
    <p class="lead">You took part in the VitalU pilot. This short form asks what worked, what did not and what we should improve. It takes about 5 to 7 minutes.</p>
    <ul class="info">
      <li>Your answers are anonymous. We do not ask for your name, email or registration number.</li>
      <li>Taking part is voluntary. You can skip any question or stop at any time.</li>
      <li>Results are reported only as group totals in the research project "Development of an ADDIE-Based Mobile Health Platform to Improve Cardiometabolic Health among Undergraduate Students", Department of Food Science and Technology, University of Peradeniya.</li>
      <li>Questions? Contact W. M. O. P. Wijesooriya at <a href="mailto:fst20052@agri.pdn.ac.lk">fst20052@agri.pdn.ac.lk</a>.</li>
    </ul>
    ${q('consent', 'Do you agree to take part?', radios('consent', [[1, 'Yes, I have read the information and agree'], [0, 'No, I do not want to take part']]))}
    ${actions({ back: false, next: 'Start' })}`,

  about: () => `
    <h1>About you</h1>
    <p class="lead">This decides which questions you see.</p>
    ${q('role', 'Which describes you best?', radios('role', ROLES.map((r) => [r[0], r[2]])))}
    ${q('faculty', 'Your faculty', `<select name="faculty" aria-label="Your faculty" style="width:100%;border-radius:18px"><option value="">Select</option>${FACULTIES.map(([v, l]) => `<option value="${v}" ${A.faculty === v ? 'selected' : ''}>${esc(l)}</option>`).join('')}</select>`)}
    ${isStudent() ? q('year', 'Your batch', radios('year', YEARS, { columns: true })) : ''}
    ${q('sex', 'Sex', radios('sex', SEXES, { columns: true }))}
    ${q('used', 'Which parts of VitalU did you use during the pilot?', checks('used', USED), 'Select all that apply.')}
    ${used('used_app') ? q('freq', 'How often did you open the student app?', radios('freq', FREQ, { columns: true })) : ''}
    ${actions()}`,

  sus1: () => susScreen(0),
  sus2: () => susScreen(5),

  features: () => featureScreen(),

  prepost: () => `
    <h1>Before and after VitalU</h1>
    <p class="lead">For each statement, think back to before you started using VitalU, then think about now.</p>
    ${PREPOST.map(([k, text]) => `
      <div class="pp" data-q="${k}">
        <div class="label">${esc(text)}</div>
        <div class="pp-row"><b>Before</b>${scale(k + '_pre', AGREE, ['Strongly disagree', 'Strongly agree'])}</div>
        <div class="pp-row now"><b>Now</b>${scale(k + '_post', AGREE, ['Strongly disagree', 'Strongly agree'])}</div>
      </div>`).join('')}
    ${actions()}`,

  dashboard: () => `
    <h1>The admin dashboard</h1>
    <p class="lead">How much do you agree with each statement?</p>
    ${DASHBOARD.map(([k, text]) => `<div class="statement" data-q="${k}"><div class="label">${esc(text)}</div>${scale(k, AGREE, ['Strongly disagree', 'Strongly agree'])}</div>`).join('')}
    ${actions()}`,

  assessment: () => `
    <h1>The periodic health assessment</h1>
    <p class="lead">Every six months VitalU opens a short health check-in for each faculty. Answers are pooled anonymously to plan campus health support.</p>
    ${q('pa_likely', PA_QUESTION[A.role] || PA_QUESTION.student, scale('pa_likely', LIKELY, ['Very unlikely', 'Very likely']))}
    ${isStudent() ? q('pa_done', 'Did you complete the periodic health assessment during the pilot?', radios('pa_done', PA_DONE, { columns: true })) : ''}
    ${isStudent() ? q('pa_reasons', 'What would make you more likely to complete it?', checks('pa_reasons', PA_REASONS, { max: 2 }), 'Optional. Select up to 2.') : ''}
    ${isStudent() ? `<div data-other="pa_reasons" ${(A.pa_reasons || []).includes('r_other') ? '' : 'hidden'}><input type="text" name="pa_reasons_other" maxlength="200" placeholder="Tell us what would help" value="${esc(A.pa_reasons_other || '')}" aria-label="Other reason"></div>` : ''}
    ${actions()}`,

  improve: () => `
    <h1>What should we improve?</h1>
    ${q('improve_pick', 'Which areas should we improve first?', checks('improve_pick', IMPROVE, { max: 3 }), 'Select up to 3.')}
    <div data-other="improve_pick" ${(A.improve_pick || []).includes('i_other') ? '' : 'hidden'}><input type="text" name="improve_other" maxlength="200" placeholder="What else should we improve?" value="${esc(A.improve_other || '')}" aria-label="Other area to improve"></div>
    ${q('recommend', 'How likely are you to recommend VitalU to a fellow student?', scale('recommend', LIKELY, ['Very unlikely', 'Very likely']))}
    ${actions()}`,

  open: () => `
    <h1>In your own words</h1>
    <p class="lead">Both questions are optional. Please do not include names or anything that could identify you or others.</p>
    <div class="q"><label class="label" for="open_best">What did you find most useful about VitalU?</label>
      <textarea id="open_best" name="open_best" maxlength="500">${esc(A.open_best || '')}</textarea><div class="counter" data-for="open_best"></div></div>
    <div class="q"><label class="label" for="open_improve">What should we change, fix or add?<span class="hint">Please be as specific as you can.</span></label>
      <textarea id="open_improve" name="open_improve" maxlength="1000">${esc(A.open_improve || '')}</textarea><div class="counter" data-for="open_improve"></div></div>
    ${actions({ next: 'Send my feedback' })}`,
};

function susScreen(from) {
  const items = SUS.slice(from, from + 5);
  return `
    <h1>Using the student app</h1>
    <p class="lead">Think about your experience with the VitalU app. How much do you agree with each statement? (${from === 0 ? '1 to 5' : '6 to 10'} of 10)</p>
    ${items.map((text, i) => {
      const k = 'sus' + (from + i + 1);
      return `<div class="statement" data-q="${k}"><div class="label">${esc(text)}</div>${scale(k, AGREE, ['Strongly disagree', 'Strongly agree'])}</div>`;
    }).join('')}
    ${actions()}`;
}

function featureScreen() {
  const list = visibleFeatures();
  const demoOnly = !used('used_app');
  featureIndex = Math.max(0, Math.min(featureIndex, list.length));
  const header = `<h1>Student app features</h1>
    <p class="lead">${demoOnly ? 'How useful would each feature be for students?' : 'How useful was each feature for you?'}</p>`;
  if (featureIndex >= list.length) {
    const answered = list.filter(([k]) => typeof A[k] === 'number').length;
    return `${header}
      <div class="fcard"><h2>All ${list.length} features done</h2><p>You rated ${answered} of them. Continue, or go back to change an answer.</p></div>
      <div class="fnav"><button type="button" class="btn ghost" data-act="frev">Review the last feature</button></div>
      ${dots(list)}
      ${actions()}`;
  }
  const [k, title, hint, img] = list[featureIndex];
  return `${header}
    <div class="fcard" data-q="${k}">
      <img src="img/${img}.jpg" alt="">
      <h2>${esc(title)}</h2>
      <p>${esc(hint)}</p>
      <div class="faces" role="group" aria-label="How useful was ${esc(title)}">
        ${USEFUL.map(([v, label, e]) => `<button type="button" class="face" data-face="${v}" aria-pressed="${A[k] === v}"><span class="e" aria-hidden="true">${e}</span>${esc(label)}</button>`).join('')}
      </div>
      <div class="fnav">
        ${featureIndex > 0 ? '<button type="button" class="btn ghost" data-act="fprev">Previous feature</button>' : ''}
        <button type="button" class="btn ghost" data-face="skip" aria-pressed="${A[k] === null}">${demoOnly ? 'Not sure' : 'Did not use'}</button>
      </div>
    </div>
    ${dots(list)}
    ${actions({ next: 'Skip the rest' })}`;
}

function dots(list) {
  return `<div class="dots" aria-hidden="true">${list.map(([k], i) => `<i class="${i === featureIndex ? 'now' : k in A ? 'done' : ''}"></i>`).join('')}</div>`;
}

// ---------------------------------------------------------------------------
// Validation: only the questions that steer the form are required, plus the
// SUS (it cannot be scored with a gap).
// ---------------------------------------------------------------------------

function missing(id) {
  switch (id) {
    case 'consent': return A.consent === undefined ? ['consent'] : [];
    case 'about': {
      const m = [];
      if (!A.role) m.push('role');
      if (!Array.isArray(A.used) || !A.used.length) m.push('used');
      return m;
    }
    case 'sus1': case 'sus2': {
      const from = id === 'sus1' ? 1 : 6;
      return [0, 1, 2, 3, 4].map((i) => 'sus' + (from + i)).filter((k) => typeof A[k] !== 'number');
    }
    default: return [];
  }
}

// ---------------------------------------------------------------------------
// Rendering and navigation
// ---------------------------------------------------------------------------

function render() {
  const list = steps();
  stepIndex = Math.min(stepIndex, list.length - 1);
  const id = list[stepIndex];
  el.innerHTML = screens[id]();
  el.classList.remove('enter', 'enter-back');
  void el.offsetWidth;
  el.classList.add(direction > 0 ? 'enter' : 'enter-back');

  const prog = document.getElementById('progress');
  prog.hidden = false;
  const pct = Math.round((stepIndex / list.length) * 100);
  document.getElementById('progress-fill').style.width = pct + '%';
  document.querySelector('.progress .track').setAttribute('aria-valuenow', String(pct));
  document.getElementById('progress-count').textContent = `${stepIndex + 1} of ${list.length}`;
  updateCounters();
  enforceMax();
}

function go(delta) {
  direction = delta;
  stepIndex += delta;
  if (delta < 0 && steps()[stepIndex] === 'features') featureIndex = visibleFeatures().length;
  if (delta > 0 && steps()[stepIndex] === 'features') featureIndex = firstUnrated();
  render();
  window.scrollTo({ top: 0, behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' });
  el.querySelector('h1')?.setAttribute('tabindex', '-1');
  el.querySelector('h1')?.focus({ preventScroll: true });
}

function firstUnrated() {
  const list = visibleFeatures();
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
    A[name] = name === 'role' ? t.value : Number.isNaN(n) ? t.value : n;
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

el.addEventListener('change', (e) => {
  const t = e.target;
  readInput(t);
  // Answers that change the branching re-render this screen.
  if (['role', 'used', 'sex'].includes(t.name)) {
    const focusName = t.name;
    const focusValue = t.value;
    direction = 0;
    render();
    el.querySelector(`input[name="${focusName}"][value="${focusValue}"]`)?.focus();
  }
  t.closest('[data-q]')?.classList.remove('invalid');
});

el.addEventListener('input', (e) => {
  if (e.target.matches('textarea, input[type="text"]')) {
    readInput(e.target);
    updateCounters();
  }
});

el.addEventListener('click', (e) => {
  const b = e.target.closest('button');
  if (!b) return;
  if (b.dataset.act === 'back') return go(-1);
  if (b.dataset.act === 'fprev' || b.dataset.act === 'frev') {
    featureIndex = Math.max(0, featureIndex - 1);
    direction = -1;
    return render();
  }
  if (b.dataset.face) {
    const [k] = visibleFeatures()[featureIndex];
    A[k] = b.dataset.face === 'skip' ? null : Number(b.dataset.face);
    save();
    b.closest('.fcard').querySelectorAll('[aria-pressed]').forEach((x) => x.setAttribute('aria-pressed', String(x === b)));
    // Let the choice show for a moment before the next card slides in.
    setTimeout(() => {
      featureIndex += 1;
      direction = 1;
      render();
      el.querySelector('.face, [data-act="frev"]')?.focus({ preventScroll: true });
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
    err.textContent = id.startsWith('sus')
      ? 'Please answer every statement on this page. The usability score needs all ten.'
      : 'Please answer the highlighted questions to continue.';
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
  const keep = new Set(['consent', 'role', 'faculty', 'sex', 'used', 'pa_likely', 'improve_pick', 'improve_other', 'recommend', 'open_best', 'open_improve']);
  const s = steps();
  if (isStudent()) ['year', 'pa_done', 'pa_reasons', 'pa_reasons_other'].forEach((k) => keep.add(k));
  if (used('used_app')) keep.add('freq');
  if (s.includes('sus1')) SUS.forEach((_, i) => keep.add('sus' + (i + 1)));
  visibleFeatures().forEach(([k]) => keep.add(k));
  if (s.includes('prepost')) PREPOST.forEach(([k]) => { keep.add(k + '_pre'); keep.add(k + '_post'); });
  if (s.includes('dashboard')) DASHBOARD.forEach(([k]) => keep.add(k));
  const out = {};
  for (const k of keep) {
    const v = A[k];
    if (v === undefined || v === '' || (Array.isArray(v) && !v.length)) continue;
    out[k] = typeof v === 'string' ? v.trim().slice(0, 1000) : v;
  }
  if (!(out.improve_pick || []).includes('i_other')) delete out.improve_other;
  if (!(out.pa_reasons || []).includes('r_other')) delete out.pa_reasons_other;
  return out;
}

async function submit() {
  const btn = el.querySelector('button[type="submit"]');
  const err = el.querySelector('#err');
  btn.disabled = true;
  btn.textContent = 'Sending…';
  const { error } = await sb.rpc('submit_pilot_feedback', { p_role: A.role, p_group: linkGroup, p_answers: cleanAnswers() });
  if (error) {
    btn.disabled = false;
    btn.textContent = 'Send my feedback';
    err.hidden = false;
    err.textContent = 'Your feedback was not sent. Check your connection and press Send again. Your answers are still here.';
    return;
  }
  store.del(DRAFT_KEY);
  store.set(SENT_KEY, new Date().toISOString());
  showThanks();
}

const check = '<div class="done-mark"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg></div>';

function endScreen(html) {
  document.getElementById('progress').hidden = true;
  el.innerHTML = html;
  el.classList.remove('enter-back');
  el.classList.add('enter');
  el.querySelector('h1')?.setAttribute('tabindex', '-1');
  el.querySelector('h1')?.focus();
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
  el.querySelector('#restart').onclick = () => { A = linkGroup ? { role: linkGroup } : {}; save(); stepIndex = 0; render(); };
}

function showAlreadySent() {
  endScreen(`${check}<h1>You have already sent your feedback</h1>
    <p class="lead">Thank you. If someone else is using this device and wants to take part, they can start a new response.</p>
    <div class="form-actions"><a class="btn ghost" href="./">Back to the VitalU page</a><button type="button" class="btn primary" id="again">Start a new response</button></div>`);
  el.querySelector('#again').onclick = () => { store.del(SENT_KEY); A = linkGroup ? { role: linkGroup } : {}; save(); stepIndex = 0; render(); };
}

if (store.get(SENT_KEY) && !store.get(DRAFT_KEY)) showAlreadySent();
else render();
