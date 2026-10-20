// VitalU admin dashboard: pooled assessment analytics, questionnaire
// editing, faculty scheduling and anonymous consultations.
//
// Admins never read individual assessments or profiles: the database only
// returns aggregates (and nothing for groups smaller than five) through
// security-definer functions that check public.is_admin().
'use strict';

const SUPABASE_URL = 'https://cfpuykmzxamkpjeqdemx.supabase.co';
const SUPABASE_KEY = 'sb_publishable_ys85MJS1JSW_GyPNHJfF-A_Kx0hPJIi';
const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

const FACULTIES = [
  'Faculty of Agriculture',
  'Faculty of Allied Health Sciences',
  'Faculty of Arts',
  'Faculty of Dental Sciences',
  'Faculty of Engineering',
  'Faculty of Management',
  'Faculty of Medicine',
  'Faculty of Science',
  'Faculty of Veterinary Medicine and Animal Science',
];
const KINDS = { single: 'Single choice', multi: 'Multiple choice', scale: '1 to 5 scale', number: 'Number', text: 'Free text', profile: 'Confirm profile details' };
const STYLES = { '': 'Answer cards', days: 'Days of the week (with food photo)', faces: 'Faces', slider: 'Illustrated slider' };
const ROUNDS = ['Mid Year Assessment', 'Year End Assessment'];

// Learn topics, the same as the app (lib/features/library/learn_data.dart).
const LEARN_TOPICS = {
  body: 'Body Confidence & Healthy Fitness',
  womens: "Women's Health & Hormonal Balance",
  cravings: 'Food Cravings & Eating Habits',
  heart: 'Heart Health & Disease Prevention',
  smoking: 'Smoking, Alcohol & Breaking Habits',
  signs: 'Know the Signs: Health Conditions',
  skin: 'Skin, Hair & Personal Care',
  mind: 'Mind, Mood & Emotional Well-being',
  sleep: 'Sleep, Energy & Recovery',
  presence: 'Personal Presence & Career Confidence',
  essentials: 'Everyday Health Essentials',
  habits: 'Your Habits, Your Health',
  sexual: 'Sexual Health & STIs',
};

const $ = (sel, root = document) => root.querySelector(sel);
const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmtDate = (d) => new Date(d).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
const fmtDateTime = (d) => new Date(d).toLocaleString('en-GB', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
const pct = (a, b) => (b > 0 ? Math.round((a / b) * 100) : 0);

function toast(msg) {
  const t = $('#toast');
  t.textContent = msg;
  t.hidden = false;
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => (t.hidden = true), 3200);
  // Lets modal handlers `return toast(...)` to keep the dialog open.
  return false;
}

function bars(rows, { max, color, suffix = '' } = {}) {
  const top = max ?? Math.max(1, ...rows.map((r) => r.value));
  return `<div class="bars">${rows
    .map(
      (r) => `<div class="bar-row"><span>${esc(r.label)}</span>
        <div class="bar-track"><div class="bar-fill" style="width:${Math.max(0, Math.min(100, (r.value / top) * 100))}%;${r.color || color ? `background:${r.color || color}` : ''}"></div></div>
        <span class="bar-val">${esc(r.display ?? r.value)}${suffix}</span></div>`,
    )
    .join('')}</div>`;
}

const scoreColor = (v) => (v >= 75 ? 'var(--good)' : v >= 55 ? 'var(--info)' : v >= 35 ? 'var(--warn)' : 'var(--bad)');

function windowStatus(w) {
  const now = Date.now();
  if (now < new Date(w.opens_at)) return ['Upcoming', 'info'];
  if (now > new Date(w.closes_at)) return ['Closed', ''];
  return ['Open', 'good'];
}

// ---------------------------------------------------------------------------
// Session
// ---------------------------------------------------------------------------

const state = { overview: null, domains: [], questions: [] };

async function boot() {
  const { data } = await sb.auth.getSession();
  if (data.session && (await checkAdmin())) return showApp(data.session.user);
  showLogin();
}

async function checkAdmin() {
  const { data, error } = await sb.rpc('is_admin');
  return !error && data === true;
}

function showLogin(message) {
  $('#app').hidden = true;
  $('#login').hidden = false;
  const err = $('#login-error');
  err.hidden = !message;
  err.textContent = message || '';
}

async function showApp(user) {
  $('#login').hidden = true;
  $('#app').hidden = false;
  state.email = user.email || '';
  $('#who-email').textContent = state.email;
  $('#who-initial').textContent = (state.email[0] || 'A').toUpperCase();
  $('#today').textContent = new Date().toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'long' });
  await Promise.all([loadMeta(), refreshConsultCount()]);
  openTab('overview');
}

// Light and dark themes. The choice is remembered in this browser only.
function setTheme(theme) {
  document.documentElement.setAttribute('data-theme', theme);
  try {
    localStorage.setItem('vitalu-admin-theme', theme);
  } catch {
    /* private mode */
  }
}
$('#theme-btn').addEventListener('click', () => setTheme(document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark'));

$('#login-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const btn = $('#login-btn');
  btn.disabled = true;
  btn.textContent = 'Signing in…';
  const { data, error } = await sb.auth.signInWithPassword({ email: $('#login-email').value.trim(), password: $('#login-password').value });
  btn.disabled = false;
  btn.textContent = 'Sign in';
  if (error) return showLogin('Incorrect email or password.');
  if (!(await checkAdmin())) {
    await sb.auth.signOut();
    return showLogin('This account is not an administrator. Ask the VitalU team to grant access.');
  }
  showApp(data.user);
});

$('#logout').addEventListener('click', async () => {
  await sb.auth.signOut();
  showLogin();
});

// ---------------------------------------------------------------------------
// Tabs
// ---------------------------------------------------------------------------

const renderers = { overview: renderOverview, analytics: renderAnalytics, completion: renderCompletion, schedule: renderSchedule, questions: renderQuestions, learn: renderLearn, consults: renderConsults };

// On narrow screens the sidebar slides in as a drawer.
function setMenu(open) {
  document.body.classList.toggle('nav-open', open);
  $('#menu-btn').setAttribute('aria-expanded', String(open));
}

function openTab(name) {
  document.querySelectorAll('.tab').forEach((t) => {
    t.classList.toggle('active', t.dataset.tab === name);
    t.setAttribute('aria-selected', String(t.dataset.tab === name));
  });
  document.querySelectorAll('.tab-panel').forEach((p) => (p.hidden = p.id !== `tab-${name}`));
  const active = document.querySelector(`.tab[data-tab="${name}"]`);
  $('#menu-current').textContent = active ? $('.label', active).textContent.trim() : '';
  setMenu(false);
  $('.main').scrollTop = 0;
  renderers[name]();
}
document.querySelectorAll('.tab').forEach((t) => t.addEventListener('click', () => openTab(t.dataset.tab)));
$('#menu-btn').addEventListener('click', () => setMenu(!document.body.classList.contains('nav-open')));
$('#scrim').addEventListener('click', () => setMenu(false));
document.addEventListener('keydown', (e) => e.key === 'Escape' && setMenu(false));
// Any element with data-goto="<tab>" opens that tab.
document.addEventListener('click', (e) => {
  const go = e.target.closest('[data-goto]');
  if (go) openTab(go.dataset.goto);
});

async function loadMeta() {
  const [ov, d, q] = await Promise.all([
    sb.rpc('admin_assessment_overview'),
    sb.from('assessment_domains').select('*').order('position'),
    sb.from('assessment_questions').select('*').order('domain_id').order('position'),
  ]);
  if (ov.error) toast('Could not load the overview. Has the database migration been applied?');
  state.overview = ov.data || { students: 0, students_by_faculty: {}, windows: [] };
  state.domains = d.data || [];
  state.questions = q.data || [];
}

// ---------------------------------------------------------------------------
// Overview
// ---------------------------------------------------------------------------

async function renderOverview() {
  const el = $('#tab-overview');
  el.innerHTML = '<p class="muted">Loading…</p>';
  const [, recent] = await Promise.all([
    loadMeta(),
    sb.from('anon_consultations').select('id, code, topic, message, urgency, created_at').eq('status', 'open').order('created_at', { ascending: false }).limit(3),
    refreshConsultCount(),
  ]);
  const o = state.overview;
  const windows = o.windows || [];
  const byStart = windows.slice().sort((a, b) => new Date(a.opens_at) - new Date(b.opens_at));
  const current = windows.find((w) => windowStatus(w)[0] === 'Open') || windows.find((w) => windowStatus(w)[0] === 'Closed');
  const upcoming = byStart.filter((w) => windowStatus(w)[0] === 'Upcoming')[0];
  const byFaculty = Object.entries(o.students_by_faculty || {}).sort((a, b) => b[1] - a[1]);
  const consults = recent.data || [];
  const hour = new Date().getHours();
  const hello = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
  const icon = (id) => `<svg><use href="#i-${id}"/></svg>`;
  const shortDate = (d) => new Date(d).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' });
  const ago = (d) => {
    const m = Math.round((Date.now() - new Date(d)) / 60000);
    if (m < 60) return `${Math.max(1, m)} min ago`;
    if (m < 1440) return `${Math.round(m / 60)} h ago`;
    return shortDate(d);
  };
  const donePct = current ? pct(current.completed, current.eligible) : 0;
  const urgency = { urgent: ['Urgent', 'bad'], soon: ['Soon', 'warn'], routine: ['Routine', 'info'] };

  // This week, Monday to Sunday, with a dot on days when a window is open.
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const monday = new Date(today);
  monday.setDate(today.getDate() - ((today.getDay() + 6) % 7));
  const week = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(monday);
    d.setDate(monday.getDate() + i);
    const end = new Date(d);
    end.setDate(d.getDate() + 1);
    const has = windows.some((w) => new Date(w.opens_at) < end && new Date(w.closes_at) >= d);
    return `<div class="day ${d.getTime() === today.getTime() ? 'on' : ''} ${has ? 'has' : ''}">${d.toLocaleDateString('en-GB', { weekday: 'short' }).slice(0, 2)}<b>${d.getDate()}</b></div>`;
  }).join('');

  // Agenda: open and upcoming windows first; otherwise the most recent ones.
  const live = byStart.filter((w) => windowStatus(w)[0] !== 'Closed');
  const agenda = (live.length ? live : byStart.slice(-3).reverse()).slice(0, 4);

  el.innerHTML = `
    <div class="ov">
      <div class="ov-main">
        <div class="hello"><div><h1>${hello}</h1><p class="muted">Track assessment participation and plan student health support.</p></div>
          <button class="btn primary" data-goto="schedule">${icon('calendar').replace('<svg>', '<svg width="16" height="16">')} Schedule assessment</button></div>

        <div class="tiles">
          <div class="tile"><div class="tile-top">Registered students<span class="tile-ico">${icon('users')}</span></div>
            <div class="tile-val">${(o.students ?? 0).toLocaleString('en-GB')}</div>
            <div class="tile-sub">across ${byFaculty.length} ${byFaculty.length === 1 ? 'faculty' : 'faculties'}</div></div>
          <div class="tile"><div class="tile-top">${current && windowStatus(current)[0] === 'Open' ? 'Responses this window' : 'Latest window responses'}<span class="tile-ico">${icon('check')}</span></div>
            <div class="tile-val">${current ? current.completed.toLocaleString('en-GB') : 0}</div>
            <div class="tile-bar"><i style="width:${donePct}%"></i></div>
            <div class="tile-sub">${current ? `${donePct}% of ${current.eligible} eligible · ${esc(current.term)}` : 'No window yet'}</div></div>
          <div class="tile"><div class="tile-top">In progress now<span class="tile-ico">${icon('pulse')}</span></div>
            <div class="tile-val">${current ? current.in_progress : 0}</div>
            <div class="tile-sub">started, not yet submitted</div></div>
          <div class="tile"><div class="tile-top">Next window opens<span class="tile-ico">${icon('calendar')}</span></div>
            <div class="tile-val sm">${upcoming ? fmtDate(upcoming.opens_at) : 'Not scheduled'}</div>
            <div class="tile-sub">${upcoming ? esc(upcoming.faculty || 'All faculties') : 'Use Schedule to plan one'}</div></div>
        </div>

        <div class="ov-grid">
          <div class="card"><div class="card-head"><h3>Waiting consultations</h3><button class="btn small" data-goto="consults">View all</button></div>
            ${
              recent.error
                ? `<p class="muted">${esc(recent.error.message)}</p>`
                : consults.length
                ? `<div class="list">${consults
                    .map((c, i) => {
                      const [u, cls] = urgency[c.urgency] || [c.urgency, ''];
                      return `<button class="li" data-goto="consults"><span class="ini c${i % 4}">${esc((c.code || '?').replace(/[^A-Za-z0-9]/g, '').slice(-2))}</span>
                        <span class="li-main"><strong>${esc(c.topic || c.code)}</strong><span>${esc(c.message)}</span></span>
                        <span class="li-side">${ago(c.created_at)}<span class="pill ${cls}">${esc(u)}</span></span></button>`;
                    })
                    .join('')}</div>`
                : '<div class="empty">No questions waiting for a reply.</div>'
            }</div>
          <div class="card"><div class="big-num"><div><b>${(o.students ?? 0).toLocaleString('en-GB')}</b><div class="muted">students on VitalU</div></div><button class="btn small" data-goto="completion">Completion</button></div>
            <h3 style="margin:14px 0 12px">Students by faculty</h3>
            ${byFaculty.length ? bars(byFaculty.slice(0, 6).map(([k, v]) => ({ label: shortFaculty(k), value: v }))) : '<p class="muted">No students yet.</p>'}
            ${byFaculty.length > 6 ? `<p class="fine" style="margin-top:10px">and ${byFaculty.length - 6} more ${byFaculty.length - 6 === 1 ? 'faculty' : 'faculties'}</p>` : ''}</div>
        </div>

        <div class="card"><div class="card-head"><h3>Assessment windows</h3><button class="btn small" data-goto="schedule">Manage</button></div>
          <div class="table-wrap"><table><thead><tr><th>Window</th><th>Faculty</th><th>Dates</th><th>Completed</th><th>Status</th></tr></thead><tbody>
          ${
            windows.length
              ? windows
                  .map((w, i) => {
                    const [s, cls] = windowStatus(w);
                    const p = pct(w.completed, w.eligible);
                    return `<tr><td><div class="cell-ico"><span class="ini c${i % 4}">${icon('clipboard')}</span><strong>${esc(w.term)}</strong></div></td>
                    <td>${esc(shortFaculty(w.faculty || 'All faculties'))}</td>
                    <td class="nowrap">${shortDate(w.opens_at)} – ${fmtDate(w.closes_at)}</td>
                    <td><div class="prog"><div class="bar-track"><div class="bar-fill" style="width:${p}%"></div></div><span>${w.completed}/${w.eligible}</span></div></td>
                    <td><span class="pill ${cls}">${s}</span></td></tr>`;
                  })
                  .join('')
              : '<tr><td colspan="5" class="muted">No windows scheduled yet.</td></tr>'
          }
          </tbody></table></div></div>
      </div>

      <aside class="rail" aria-label="Your agenda">
        <div class="profile"><span class="avatar">${esc((state.email?.[0] || 'A').toUpperCase())}</span>
          <strong>${esc(state.email || 'Administrator')}</strong><span class="muted">Health administration</span>
          <span class="pill good">Administrator</span></div>
        <div class="card-head" style="margin:0"><h3>Assessment agenda</h3><button class="btn small" data-goto="schedule">View all</button></div>
        <div class="week">${week}</div>
        <div class="agenda">${
          agenda.length
            ? agenda
                .map((w) => {
                  const [s] = windowStatus(w);
                  return `<div class="ag ${s === 'Open' ? 'live' : ''}"><span class="ag-ico">${icon(s === 'Open' ? 'pulse' : s === 'Upcoming' ? 'clock' : 'check')}</span>
                    <div class="ag-main"><strong>${esc(w.term)}</strong><span>${esc(shortFaculty(w.faculty || 'All faculties'))}</span><span>${shortDate(w.opens_at)} – ${shortDate(w.closes_at)} · ${s}</span></div>
                    <span class="ag-pct">${s === 'Upcoming' ? shortDate(w.opens_at) : `${pct(w.completed, w.eligible)}%`}</span></div>`;
                })
                .join('')
            : '<div class="empty">Nothing scheduled. Plan the next six-monthly assessment.</div>'
        }</div>
        <button class="btn wide" data-goto="schedule">All assessment windows</button>
      </aside>
    </div>`;
}

// ---------------------------------------------------------------------------
// Analytics
// ---------------------------------------------------------------------------

const analytics = { window: '', faculty: '', view: 'overall', question: '' };

// Pooled health indicators (from the report's `indicators`), with the cut-off
// each one uses. `n` is how many students had the measurement.
const INDICATORS = [
  { key: 'overweight_obese', n: 'bmi_n', label: 'Overweight or obese', note: 'BMI 25 or more', bad: true },
  { key: 'underweight', n: 'bmi_n', label: 'Underweight', note: 'BMI below 18.5', bad: true },
  { key: 'whr_high', n: 'whr_n', label: 'High waist-to-hip ratio', note: '0.90+ men, 0.85+ women (WHO)', bad: true },
  { key: 'bp_raised', n: 'bp_n', label: 'Raised blood pressure', note: '140/90 mmHg or more', bad: true },
  { key: 'fbg_raised', n: 'fbg_n', label: 'Raised fasting glucose', note: '126 mg/dL or more', bad: true },
  { key: 'tg_high', n: 'tg_n', label: 'High triglycerides', note: '150 mg/dL or more', bad: true },
  { key: 'chol_high', n: 'chol_n', label: 'High total cholesterol', note: '190 mg/dL or more', bad: true },
  { key: 'phq2_positive', n: 'phq2_n', label: 'Low mood screen positive', note: 'PHQ-2 score 3 or more', bad: true },
];

const shortFaculty = (f) => f.replace('Faculty of ', '');

function indicatorRows(ind) {
  if (!ind) return [];
  return INDICATORS.filter((i) => (ind[i.n] || 0) > 0).map((i) => {
    const p = pct(ind[i.key] || 0, ind[i.n]);
    return { label: i.label, value: p, display: `${p}% of ${ind[i.n]}`, color: p >= 30 ? 'var(--bad)' : p >= 15 ? 'var(--warn)' : 'var(--good)', note: i.note };
  });
}

function healthCard(data) {
  const rows = indicatorRows(data.indicators);
  if (!data.indicators) return '<div class="card"><h3>Health indicators</h3><p class="muted">Apply the latest database migration to see pooled health indicators.</p></div>';
  return `<div class="card"><h3>Health indicators</h3><p class="fine">Share of students with each measurement who are outside the healthy range. Clinical values come from the clinical measurements section, so they are missing when that section is hidden.</p>
    ${rows.length ? bars(rows, { max: 100 }) + `<p class="fine">${rows.map((r) => `${esc(r.label)}: ${esc(r.note)}`).join(' · ')}</p>` : '<p class="muted">No measurements yet.</p>'}</div>`;
}

async function renderAnalytics() {
  const el = $('#tab-analytics');
  const windows = state.overview?.windows || [];
  const byFaculty = analytics.view === 'faculty';
  el.innerHTML = `
    <div class="head"><div><h1>Analytics</h1><p class="muted">Pooled results, overall and by faculty. Nothing is shown for groups smaller than five students.</p></div>
      <button class="btn" id="csv">Download CSV</button></div>
    <div class="card filters">
      <div class="seg" role="tablist">
        <button class="${byFaculty ? '' : 'on'}" data-view="overall">Overall</button>
        <button class="${byFaculty ? 'on' : ''}" data-view="faculty">By faculty</button>
      </div>
      <label>Assessment window<select id="f-window"><option value="">All windows</option>
        ${windows.map((w) => `<option value="${esc(w.id)}" ${analytics.window === w.id ? 'selected' : ''}>${esc(w.term)} · ${esc(w.faculty || 'All faculties')}</option>`).join('')}</select></label>
      ${byFaculty ? '' : `<label>Faculty<select id="f-faculty"><option value="">All faculties</option>
        ${FACULTIES.map((f) => `<option ${analytics.faculty === f ? 'selected' : ''}>${esc(f)}</option>`).join('')}</select></label>`}
    </div>
    <div id="report"><p class="muted">Loading…</p></div>`;
  el.querySelectorAll('[data-view]').forEach((b) => (b.onclick = () => ((analytics.view = b.dataset.view), renderAnalytics())));
  $('#f-window').onchange = (e) => ((analytics.window = e.target.value), renderAnalytics());
  if (!byFaculty) $('#f-faculty').onchange = (e) => ((analytics.faculty = e.target.value), renderAnalytics());
  return byFaculty ? renderFacultyComparison() : renderOverall();
}

async function renderOverall() {
  const { data, error } = await sb.rpc('admin_assessment_report', { p_window: analytics.window || null, p_faculty: analytics.faculty || null, p_term: null });
  const box = $('#report');
  if (error) return (box.innerHTML = `<div class="notice">Could not load results: ${esc(error.message)}</div>`);
  if (data.suppressed) {
    box.innerHTML = `<div class="notice">${data.n} completed ${data.n === 1 ? 'response' : 'responses'} so far. Results appear once at least ${data.min_group} students in this group have completed the assessment, so that no one can be identified.</div>`;
    $('#csv').disabled = true;
    return;
  }
  $('#csv').disabled = false;
  $('#csv').onclick = () => downloadCsv(data);

  const domainRows = state.domains
    .filter((d) => data.domains?.[d.id] != null)
    .map((d) => ({ label: d.title, value: Number(data.domains[d.id]), color: scoreColor(Number(data.domains[d.id])) }));
  const bmi = ['Underweight', 'Normal', 'Overweight', 'Obesity'].map((c) => ({ label: c, value: data.bmi_categories?.[c] || 0 }));
  const bmiTotal = bmi.reduce((a, b) => a + b.value, 0);
  const groupRows = (obj) => Object.entries(obj || {}).map(([k, v]) => ({ label: shortFaculty(k), value: v ?? 0, display: v == null ? 'fewer than 5' : v }));
  const ind = data.indicators;

  box.innerHTML = `
    <div class="grid k4">
      <div class="card kpi"><div class="label">Completed responses</div><div class="value">${data.n}</div><div class="fine">${esc(analytics.faculty || 'All faculties')}</div></div>
      <div class="card kpi"><div class="label">Overall well-being</div><div class="value" style="color:${scoreColor(data.overall ?? 0)}">${data.overall ?? '–'}</div><div class="fine">out of 100, higher is healthier</div></div>
      <div class="card kpi"><div class="label">Healthy BMI</div><div class="value">${pct(data.bmi_categories?.Normal || 0, bmiTotal)}%</div><div class="fine">of ${bmiTotal} with measurements</div></div>
      <div class="card kpi"><div class="label">Low mood screen positive</div><div class="value">${ind?.phq2_n ? `${pct(ind.phq2_positive, ind.phq2_n)}%` : '–'}</div><div class="fine">PHQ-2 score 3 or more</div></div>
    </div>
    <div class="grid k2">
      <div class="card"><h3>Well-being by area</h3><p class="fine">Average score out of 100 for each area. Below 55 suggests a priority for support.</p>${domainRows.length ? bars(domainRows, { max: 100 }) : '<p class="muted">No scored answers yet.</p>'}</div>
      ${healthCard(data)}
    </div>
    <div class="grid k2">
      <div class="card"><h3>BMI categories</h3>${bars(bmi.map((r) => ({ ...r, display: `${r.value} (${pct(r.value, bmiTotal)}%)` })))}</div>
      <div class="card"><h3>Responses by faculty</h3>${bars(groupRows(data.by_faculty))}
        <h3 style="margin-top:18px">Responses by sex</h3>${bars(groupRows(data.by_sex))}</div>
    </div>
    ${state.domains.map((d) => domainCard(d, data)).join('')}`;
}

// One report for all faculties together and one per faculty, side by side.
async function renderFacultyComparison() {
  const box = $('#report');
  const call = (f) => sb.rpc('admin_assessment_report', { p_window: analytics.window || null, p_faculty: f, p_term: null });
  const results = await Promise.all([call(null), ...FACULTIES.map(call)]);
  const failed = results.find((r) => r.error);
  if (failed) return (box.innerHTML = `<div class="notice">Could not load results: ${esc(failed.error.message)}</div>`);
  const all = results[0].data;
  const groups = [{ name: 'All faculties', data: all, total: true }, ...FACULTIES.map((f, i) => ({ name: shortFaculty(f), data: results[i + 1].data }))];
  const shown = groups.filter((g) => !g.data.suppressed);
  if (all.suppressed) {
    box.innerHTML = `<div class="notice">${all.n} completed ${all.n === 1 ? 'response' : 'responses'} so far. Faculty results appear once at least ${all.min_group} students in a faculty have completed the assessment.</div>`;
    $('#csv').disabled = true;
    return;
  }

  const bmiPct = (d, cats) => {
    const total = ['Underweight', 'Normal', 'Overweight', 'Obesity'].reduce((a, c) => a + (d.bmi_categories?.[c] || 0), 0);
    return total ? pct(cats.reduce((a, c) => a + (d.bmi_categories?.[c] || 0), 0), total) : null;
  };
  const indPct = (d, key, n) => (d.indicators?.[n] ? pct(d.indicators[key] || 0, d.indicators[n]) : null);
  const metrics = [
    { label: 'Overall well-being', fmt: (d) => d.overall, score: true },
    { label: 'Healthy BMI', fmt: (d) => bmiPct(d, ['Normal']), unit: '%', good: true },
    ...INDICATORS.map((i) => ({ label: i.label, fmt: (d) => indPct(d, i.key, i.n), unit: '%' })),
  ];
  const cellColor = (m, v) => {
    if (v == null) return '';
    if (m.score) return `color:${scoreColor(v)}`;
    if (m.good) return `color:${v >= 70 ? 'var(--good)' : v >= 50 ? 'var(--warn)' : 'var(--bad)'}`;
    return `color:${v >= 30 ? 'var(--bad)' : v >= 15 ? 'var(--warn)' : 'var(--good)'}`;
  };
  const cell = (m, g) => {
    if (g.data.suppressed) return '<td class="muted">–</td>';
    const v = m.fmt(g.data);
    return `<td class="num" style="${cellColor(m, v)}">${v == null ? '–' : `${v}${m.unit || ''}`}</td>`;
  };
  const head = `<tr><th></th>${groups.map((g) => `<th class="num">${esc(g.name)}</th>`).join('')}</tr>`;
  const respRow = `<tr><td><strong>Completed responses</strong></td>${groups.map((g) => `<td class="num">${g.data.suppressed ? `<span class="fine">${g.data.n} (under 5)</span>` : g.data.n}</td>`).join('')}</tr>`;
  const domainRows = state.domains
    .filter((d) => shown.some((g) => g.data.domains?.[d.id] != null))
    .map((d) => `<tr><td>${esc(d.title)}</td>${groups.map((g) => {
      const v = g.data.suppressed ? null : g.data.domains?.[d.id];
      return `<td class="num heat" style="${v == null ? '' : `background:color-mix(in srgb, ${scoreColor(Number(v))} 16%, transparent);color:${scoreColor(Number(v))}`}">${v == null ? '–' : Math.round(Number(v))}</td>`;
    }).join('')}</tr>`)
    .join('');

  const comparable = state.questions.filter((q) => ['single', 'scale'].includes(q.kind) && (q.options || []).length && all.questions?.[q.id]?.answered);
  if (!comparable.some((q) => q.id === analytics.question)) analytics.question = comparable[0]?.id || '';
  const q = comparable.find((x) => x.id === analytics.question);

  box.innerHTML = `
    <div class="card"><h3>Faculty comparison</h3><p class="fine">Each column is one faculty's pooled result. Faculties with fewer than five completed responses are hidden. Health indicators show the share of students with that measurement who are outside the healthy range.</p>
      <div class="table-wrap"><table class="compare"><thead>${head}</thead><tbody>${respRow}
        ${metrics.map((m) => `<tr><td>${esc(m.label)}</td>${groups.map((g) => cell(m, g)).join('')}</tr>`).join('')}
      </tbody></table></div></div>
    <div class="card"><h3>Well-being by area and faculty</h3><p class="fine">Average score out of 100, higher is healthier. Below 55 suggests a priority for support.</p>
      <div class="table-wrap"><table class="compare"><thead>${head}</thead><tbody>${domainRows || `<tr><td colspan="${groups.length + 1}" class="muted">No scored answers yet.</td></tr>`}</tbody></table></div></div>
    <div class="card"><h3>Compare a question across faculties</h3>
      ${comparable.length ? `<label>Question<select id="f-question">${comparable.map((x) => `<option value="${esc(x.id)}" ${x.id === analytics.question ? 'selected' : ''}>${esc(x.text)}</option>`).join('')}</select></label>
      <div id="q-compare" style="margin-top:14px">${questionByFaculty(q, shown)}</div>` : '<p class="muted">No answers yet.</p>'}</div>`;

  const sel = $('#f-question');
  if (sel) sel.onchange = (e) => {
    analytics.question = e.target.value;
    $('#q-compare').innerHTML = questionByFaculty(state.questions.find((x) => x.id === analytics.question), shown);
  };
  $('#csv').disabled = false;
  $('#csv').onclick = () => downloadFacultyCsv(groups, metrics);
}

// Stacked percentage bars: one row per faculty, one colour per answer. Scored
// answers run from red (least healthy) to green (healthiest).
const STACK = ['#1a6fe0', '#7b5cc4', '#e0b03a', '#2a9d8f', '#e07a2f', '#8b8699', '#c2185b', '#5fae6e'];
const RAMP = ['#c62828', '#e07a2f', '#e0b03a', '#7cb860', '#1e8541'];
function answerColors(opts) {
  const scores = opts.map((o) => (typeof o.score === 'number' ? o.score : null));
  if (scores.some((v) => v == null)) return opts.map((_, i) => STACK[i % STACK.length]);
  const lo = Math.min(...scores), hi = Math.max(...scores);
  return scores.map((v) => RAMP[hi === lo ? 4 : Math.round(((v - lo) / (hi - lo)) * 4)]);
}
function questionByFaculty(q, groups) {
  if (!q) return '';
  const opts = q.options || [];
  const colors = answerColors(opts);
  const legend = `<div class="legend">${opts.map((o, i) => `<span><i style="background:${colors[i]}"></i>${esc(o.label)}</span>`).join('')}</div>`;
  const rows = groups
    .map((g) => {
      const r = g.data.questions?.[q.id];
      const counts = r?.counts || {};
      const base = Object.values(counts).reduce((a, b) => a + b, 0);
      if (!base) return '';
      const segs = opts
        .map((o, i) => {
          const p = pct(counts[o.value] || 0, base);
          return p ? `<div title="${esc(o.label)}: ${p}%" style="width:${p}%;background:${colors[i]}">${p >= 8 ? `${p}%` : ''}</div>` : '';
        })
        .join('');
      return `<div class="stack-row"><span>${esc(g.name)}</span><div class="stack">${segs}</div><span class="bar-val">${base}</span></div>`;
    })
    .join('');
  return `${legend}<div class="stacks">${rows}</div><p class="fine">The number on the right is how many answered in that group.</p>`;
}

function downloadFacultyCsv(groups, metrics) {
  const lines = [['measure', ...groups.map((g) => g.name)]];
  lines.push(['Completed responses', ...groups.map((g) => g.data.n)]);
  for (const m of metrics) lines.push([m.label + (m.unit ? ' (%)' : ''), ...groups.map((g) => (g.data.suppressed ? '' : m.fmt(g.data) ?? ''))]);
  for (const d of state.domains) lines.push([`${d.title} (0-100)`, ...groups.map((g) => (g.data.suppressed ? '' : g.data.domains?.[d.id] ?? ''))]);
  const csv = lines.map((l) => l.map((c) => `"${String(c ?? '').replace(/"/g, '""')}"`).join(',')).join('\n');
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }));
  a.download = `vitalu-assessment-by-faculty-${new Date().toISOString().slice(0, 10)}.csv`;
  a.click();
}

function domainCard(d, data) {
  const qs = state.questions.filter((q) => q.domain_id === d.id && data.questions?.[q.id]);
  if (!qs.length) return '';
  return `<div class="card domain-block"><div><h2>${esc(d.title)}</h2>${data.domains?.[d.id] != null ? `<span class="pill">${data.domains[d.id]} / 100</span>` : ''}</div>
    ${qs.map((q) => questionResult(q, data.questions[q.id])).join('')}</div>`;
}

function questionResult(q, r) {
  const meta = `<div class="q-meta"><span class="pill">${esc(KINDS[q.kind] || q.kind)}</span><span class="fine">${r.answered} answered${q.active ? '' : ' · retired question'}</span></div>`;
  let body = '';
  if (q.kind === 'number') {
    body = r.answered ? `<p>Mean <strong>${r.mean}</strong> ${esc(q.unit || '')} · median ${r.median} · middle half ${r.p25} to ${r.p75}</p>` : '<p class="muted">No answers.</p>';
  } else if (q.kind === 'text') {
    body = r.responses?.length ? `<div class="quotes">${r.responses.map((t) => `<div class="quote">${esc(t)}</div>`).join('')}</div>` : '<p class="muted">No comments.</p>';
  } else {
    const opts = q.options || [];
    const base = q.kind === 'multi' ? r.answered : Object.values(r.counts || {}).reduce((a, b) => a + b, 0);
    const rows = opts.map((o) => {
      const c = r.counts?.[o.value] || 0;
      return { label: o.label, value: c, display: `${pct(c, base)}%` };
    });
    body = bars(rows, { max: Math.max(1, base) }) + (q.kind === 'multi' ? '<p class="fine">Students could pick more than one, so percentages add up to more than 100.</p>' : '');
  }
  return `<div class="q"><h3>${esc(q.text)}</h3>${meta}${body}</div>`;
}

function downloadCsv(data) {
  const lines = [['domain', 'question', 'answer', 'count_or_value']];
  for (const q of state.questions) {
    const r = data.questions?.[q.id];
    if (!r) continue;
    const d = state.domains.find((x) => x.id === q.domain_id)?.title || q.domain_id;
    if (q.kind === 'number') ['mean', 'median', 'p25', 'p75'].forEach((k) => lines.push([d, q.text, k, r[k]]));
    else if (q.kind === 'text') lines.push([d, q.text, 'comments', r.answered]);
    else (q.options || []).forEach((o) => lines.push([d, q.text, o.label, r.counts?.[o.value] || 0]));
  }
  Object.entries(data.domains || {}).forEach(([k, v]) => lines.push([state.domains.find((x) => String(x.id) === k)?.title || k, 'Domain score (0-100)', '', v]));
  const csv = lines.map((l) => l.map((c) => `"${String(c ?? '').replace(/"/g, '""')}"`).join(',')).join('\n');
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }));
  a.download = `vitalu-assessment-summary-${new Date().toISOString().slice(0, 10)}.csv`;
  a.click();
}

// ---------------------------------------------------------------------------
// Completion
// ---------------------------------------------------------------------------

// Who has completed each window, by registration number. This shows
// participation only: never answers, scores or names.
const completion = { window: '', reg: '', status: '' };
const STATUS = { completed: ['Completed', 'good'], in_progress: ['In progress', 'info'], not_started: ['Not started', ''] };

async function renderCompletion() {
  const el = $('#tab-completion');
  const windows = state.overview?.windows || [];
  el.innerHTML = `
    <div class="head"><div><h1>Completion</h1><p class="muted">Who has completed each assessment window, by registration number. Answers are never shown here.</p></div>
      <button class="btn" id="c-csv">Download CSV</button></div>
    <form class="card filters" id="c-form">
      <label>Assessment window<select id="c-window"><option value="">All windows</option>
        ${windows.map((w) => `<option value="${esc(w.id)}" ${completion.window === w.id ? 'selected' : ''}>${esc(w.term)} · ${esc(w.faculty || 'All faculties')}</option>`).join('')}</select></label>
      <label>Status<select id="c-status"><option value="">Any status</option>
        ${Object.entries(STATUS).map(([k, [l]]) => `<option value="${k}" ${completion.status === k ? 'selected' : ''}>${l}</option>`).join('')}</select></label>
      <label>Registration number<input id="c-reg" type="search" placeholder="e.g. AG/2021/045" value="${esc(completion.reg)}"></label>
      <button class="btn primary" type="submit">Search</button>
    </form>
    <div id="c-result"><p class="muted">Loading…</p></div>`;
  $('#c-window').onchange = (e) => ((completion.window = e.target.value), renderCompletion());
  $('#c-status').onchange = (e) => ((completion.status = e.target.value), renderCompletion());
  $('#c-form').onsubmit = (e) => {
    e.preventDefault();
    completion.reg = $('#c-reg').value.trim();
    renderCompletion();
  };

  const { data, error } = await sb.rpc('admin_assessment_completion', { p_window: completion.window || null, p_registration: completion.reg || null });
  const box = $('#c-result');
  if (error) return (box.innerHTML = `<div class="notice">Could not load completion: ${esc(error.message)}. Has the latest database migration been applied?</div>`);
  const rows = (data || []).filter((r) => !completion.status || r.status === completion.status);
  const done = rows.filter((r) => r.status === 'completed').length;
  $('#c-csv').disabled = !rows.length;
  $('#c-csv').onclick = () => {
    const lines = [['registration_number', 'faculty', 'academic_year', 'window', 'status', 'completed_at'], ...rows.map((r) => [r.registration_number, r.faculty, r.academic_year, r.window_term, r.status, r.completed_at || ''])];
    const csv = lines.map((l) => l.map((c) => `"${String(c ?? '').replace(/"/g, '""')}"`).join(',')).join('\n');
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }));
    a.download = `vitalu-assessment-completion-${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
  };
  box.innerHTML = `
    <div class="grid k4">
      <div class="card kpi"><div class="label">Students listed</div><div class="value">${rows.length}</div></div>
      <div class="card kpi"><div class="label">Completed</div><div class="value">${done}</div><div class="fine">${pct(done, rows.length)}% of those listed</div></div>
    </div>
    <div class="card"><div class="table-wrap"><table><thead><tr><th>Registration number</th><th>Faculty</th><th>Year</th><th>Window</th><th>Status</th><th>Completed on</th></tr></thead><tbody>
    ${
      rows.length
        ? rows
            .slice(0, 1000)
            .map((r) => {
              const [label, cls] = STATUS[r.status] || [r.status, ''];
              return `<tr><td><strong>${esc(r.registration_number || '–')}</strong></td><td>${esc((r.faculty || '').replace('Faculty of ', ''))}</td>
                <td>${esc(r.academic_year || '')}</td><td>${esc(r.window_term)}</td><td><span class="pill ${cls}">${label}</span></td>
                <td>${r.completed_at ? fmtDate(r.completed_at) : ''}</td></tr>`;
            })
            .join('')
        : '<tr><td colspan="6" class="muted">No students match.</td></tr>'
    }
    </tbody></table></div>${rows.length > 1000 ? '<p class="fine">Showing the first 1,000. Download the CSV for the full list.</p>' : ''}</div>`;
}

// ---------------------------------------------------------------------------
// Schedule
// ---------------------------------------------------------------------------

async function renderSchedule() {
  const el = $('#tab-schedule');
  await loadMeta();
  const windows = state.overview.windows || [];
  const last = windows.slice().sort((a, b) => new Date(b.opens_at) - new Date(a.opens_at))[0];
  const suggested = new Date(last ? new Date(last.opens_at) : Date.now());
  if (last) suggested.setMonth(suggested.getMonth() + 6);
  else suggested.setDate(suggested.getDate() + 14);
  const iso = suggested.toISOString().slice(0, 10);
  // January to June rounds are mid year; July to December are year end.
  const suggestedRound = suggested.getMonth() < 6 ? ROUNDS[0] : ROUNDS[1];

  el.innerHTML = `
    <div class="head"><div><h1>Schedule an assessment</h1><p class="muted">The assessment runs every six months. Each faculty can have its own dates; windows stay open for a week by default.</p></div></div>
    <form class="card" id="sched" style="display:grid;gap:14px">
      <div class="form-grid">
        <label>Round<select name="round" required>${ROUNDS.map((r) => `<option ${r === suggestedRound ? 'selected' : ''}>${r}</option>`).join('')}</select></label>
        <label>Year<input name="year" type="number" min="2024" max="2100" required value="${suggested.getFullYear()}"></label>
        <label>Opens on<input name="date" type="date" required value="${iso}"></label>
        <label>Opening time<input name="time" type="time" required value="08:00"></label>
        <label>Open for (days)<input name="days" type="number" min="1" max="31" value="7" required></label>
      </div>
      <div><button class="btn small" type="button" id="open-now">Open from right now</button>
        <span class="fine">Sets today's date and the current time, so it opens as soon as you schedule it.</span></div>
      <p class="fine" id="sched-preview"></p>
      <div><h3>Faculties</h3><p class="fine">Tick the faculties to schedule now. Each one gets its own window, so you can repeat this with different dates for other faculties. Leave all unticked to open it for every faculty at once.</p>
        <div class="faculty-list">${FACULTIES.map((f) => `<label class="check"><input type="checkbox" name="faculty" value="${esc(f)}"> ${esc(f.replace('Faculty of ', ''))}</label>`).join('')}</div></div>
      <p class="fine">Students in the chosen faculties get a "coming up" notification three days before and a "now open" notification on the day. When they start, they are told the results are used only as a pooled overview, without personal identifiers.</p>
      <div><button class="btn primary" type="submit">Schedule</button></div>
    </form>
    <div class="card"><h3>All windows</h3><div class="table-wrap"><table><thead><tr><th>Window</th><th>Faculty</th><th>Opens</th><th>Closes</th><th>Started</th><th></th></tr></thead><tbody>
      ${windows
        .map((w) => {
          const [s, cls] = windowStatus(w);
          const started = w.completed + w.in_progress;
          return `<tr><td><strong>${esc(w.term)}</strong><br><span class="fine">${esc(w.title)}</span> <span class="pill ${cls}">${s}</span></td>
            <td>${esc(w.faculty || 'All faculties')}</td><td>${fmtDateTime(w.opens_at)}</td><td>${fmtDateTime(w.closes_at)}</td><td>${started}</td>
            <td class="row-actions"><button class="btn small" data-extend="${esc(w.id)}">Change close date</button>
            ${started === 0 ? `<button class="btn small danger" data-del="${esc(w.id)}">Delete</button>` : ''}</td></tr>`;
        })
        .join('') || '<tr><td colspan="6" class="muted">Nothing scheduled yet.</td></tr>'}
    </tbody></table></div></div>`;

  const form = $('#sched');
  // Times are entered in Sri Lanka time (UTC+05:30), whatever the browser's zone.
  const colomboNow = () => new Date(Date.now() + 330 * 60000).toISOString();
  const opensOf = () => new Date(`${form.date.value}T${form.time.value}:00+05:30`);
  // The round and year follow the opening date, so a window can't be labelled
  // with a different year from the one it actually runs in.
  const syncRound = () => {
    const [y, m] = form.date.value.split('-').map(Number);
    if (!y) return;
    form.year.value = y;
    form.round.value = m <= 6 ? ROUNDS[0] : ROUNDS[1];
  };
  const preview = () => {
    const opens = opensOf();
    if (isNaN(opens)) return ($('#sched-preview').textContent = '');
    const closes = new Date(opens.getTime() + Number(form.days.value || 0) * 86400000);
    const now = new Date();
    $('#sched-preview').textContent =
      closes <= now
        ? 'These dates are already over. Pick a date so the window closes in the future.'
        : `Open ${fmtDateTime(opens.toISOString())} to ${fmtDateTime(closes.toISOString())}${opens <= now ? '. It opens straight away and students are notified now.' : '.'}`;
  };
  syncRound();
  preview();
  form.date.addEventListener('change', () => (syncRound(), preview()));
  form.time.addEventListener('change', preview);
  form.days.addEventListener('input', preview);
  $('#open-now').onclick = () => {
    const now = colomboNow();
    form.date.value = now.slice(0, 10);
    form.time.value = now.slice(11, 16);
    syncRound();
    preview();
  };

  form.onsubmit = async (e) => {
    e.preventDefault();
    const f = new FormData(e.target);
    const opens = opensOf();
    const closes = new Date(opens.getTime() + Number(f.get('days')) * 86400000);
    if (closes <= new Date()) return toast('That window would already be closed. Pick a date so it closes in the future.');
    const faculties = f.getAll('faculty');
    const term = `${f.get('round')} ${f.get('year')}`;
    const { error } = await sb.rpc('admin_schedule_assessment', {
      p_title: f.get('round').replace('Assessment', 'Health Assessment'),
      p_term: term,
      p_faculties: faculties,
      p_opens_at: opens.toISOString(),
      p_days: Number(f.get('days')),
    });
    if (error) return toast(`Could not schedule: ${error.message}`);
    toast(faculties.length ? `Scheduled for ${faculties.length} ${faculties.length === 1 ? 'faculty' : 'faculties'}.` : 'Scheduled for all faculties.');
    renderSchedule();
  };
  el.querySelectorAll('[data-del]').forEach((b) =>
    b.addEventListener('click', async () => {
      if (!confirm('Delete this window and its pending notifications?')) return;
      const { error } = await sb.rpc('admin_delete_assessment_window', { p_window: b.dataset.del });
      if (error) return toast(error.message);
      toast('Window deleted.');
      renderSchedule();
    }),
  );
  el.querySelectorAll('[data-extend]').forEach((b) =>
    b.addEventListener('click', () => {
      const w = windows.find((x) => x.id === b.dataset.extend);
      const cur = new Date(w.closes_at);
      openModal(
        `<h2>Change close date</h2><p class="muted">${esc(w.term)} · ${esc(w.faculty || 'All faculties')}</p>
        <label>Closes on<input type="datetime-local" id="close-at" value="${new Date(cur.getTime() - cur.getTimezoneOffset() * 60000).toISOString().slice(0, 16)}"></label>
        <div class="modal-actions"><button class="btn" value="cancel">Cancel</button><button class="btn primary" id="save-close" value="ok">Save</button></div>`,
        async () => {
          const v = new Date($('#close-at').value);
          if (v <= new Date(w.opens_at)) return toast('The close date must be after the opening date.');
          const { error } = await sb.from('assessment_windows').update({ closes_at: v.toISOString() }).eq('id', w.id);
          if (error) return toast(error.message);
          toast('Close date updated.');
          renderSchedule();
        },
      );
    }),
  );
}

// ---------------------------------------------------------------------------
// Questionnaire editor
// ---------------------------------------------------------------------------

async function renderQuestions() {
  const el = $('#tab-questions');
  await loadMeta();
  el.innerHTML = `
    <div class="head"><div><h1>Questionnaire</h1><p class="muted">Edit wording, answers and scoring. Retiring a question hides it from students but keeps past results.</p></div></div>
    <p class="fine">Scoring: give each answer a score where a higher number is the healthier answer (for example 0 to 3). Leave the score empty for descriptive questions. Each area's well-being score is the average of its scored answers, out of 100.</p>
    <p class="fine">Hide a whole section for a round with <strong>Hide section</strong>, for example Clinical measurements when the health centre has not measured students. Students then skip it; past answers are kept.</p>
    ${state.domains
      .map((d) => {
        const qs = state.questions.filter((q) => q.domain_id === d.id);
        return `<div class="card"><div class="head"><div><h2>${esc(d.position)}. ${esc(d.title)}</h2><p class="fine">${esc(d.blurb || '')}</p></div>
          <div class="row-actions">${d.active === false ? '<span class="pill warn">Hidden from students</span>' : '<span class="pill good">Shown to students</span>'}
            <button class="btn small" data-toggle-domain="${d.id}">${d.active === false ? 'Show section' : 'Hide section'}</button>
            <button class="btn small" data-edit-domain="${d.id}">Rename area</button><button class="btn small primary" data-add="${d.id}">Add question</button></div></div>
          ${qs
            .map(
              (q, i) => `<div class="qitem ${q.active ? '' : 'inactive'}"><div><strong>${esc(q.text)}</strong>
                <div class="q-meta"><span class="pill">${esc(KINDS[q.kind] || q.kind)}</span>${q.optional ? '<span class="pill">Optional</span>' : ''}${q.active ? '' : '<span class="pill warn">Retired</span>'}
                <span class="fine">${(q.options || []).map((o) => esc(o.label)).join(' · ')}</span></div></div>
                <div class="row-actions">
                  <button class="btn small" data-move="${esc(q.id)}" data-dir="-1" ${i === 0 ? 'disabled' : ''} aria-label="Move up">↑</button>
                  <button class="btn small" data-move="${esc(q.id)}" data-dir="1" ${i === qs.length - 1 ? 'disabled' : ''} aria-label="Move down">↓</button>
                  <button class="btn small" data-edit="${esc(q.id)}">Edit</button>
                  <button class="btn small ${q.active ? 'danger' : ''}" data-toggle="${esc(q.id)}">${q.active ? 'Retire' : 'Restore'}</button>
                </div></div>`,
            )
            .join('')}</div>`;
      })
      .join('')}`;

  el.querySelectorAll('[data-edit]').forEach((b) => b.addEventListener('click', () => editQuestion(state.questions.find((q) => q.id === b.dataset.edit))));
  el.querySelectorAll('[data-add]').forEach((b) => b.addEventListener('click', () => editQuestion(null, Number(b.dataset.add))));
  el.querySelectorAll('[data-toggle]').forEach((b) =>
    b.addEventListener('click', async () => {
      const q = state.questions.find((x) => x.id === b.dataset.toggle);
      const { error } = await sb.from('assessment_questions').update({ active: !q.active }).eq('id', q.id);
      if (error) return toast(error.message);
      renderQuestions();
    }),
  );
  el.querySelectorAll('[data-move]').forEach((b) =>
    b.addEventListener('click', async () => {
      const q = state.questions.find((x) => x.id === b.dataset.move);
      const list = state.questions.filter((x) => x.domain_id === q.domain_id);
      const i = list.indexOf(q);
      const j = i + Number(b.dataset.dir);
      [list[i], list[j]] = [list[j], list[i]];
      const results = await Promise.all(list.map((x, k) => sb.from('assessment_questions').update({ position: k + 1 }).eq('id', x.id)));
      if (results.some((r) => r.error)) toast('Could not reorder.');
      renderQuestions();
    }),
  );
  el.querySelectorAll('[data-toggle-domain]').forEach((b) =>
    b.addEventListener('click', async () => {
      const d = state.domains.find((x) => x.id === Number(b.dataset.toggleDomain));
      const { error } = await sb.from('assessment_domains').update({ active: d.active === false }).eq('id', d.id);
      if (error) return toast(`${error.message}. Has the latest database migration been applied?`);
      toast(d.active === false ? 'Section shown to students.' : 'Section hidden from students.');
      renderQuestions();
    }),
  );
  el.querySelectorAll('[data-edit-domain]').forEach((b) =>
    b.addEventListener('click', () => {
      const d = state.domains.find((x) => x.id === Number(b.dataset.editDomain));
      openModal(
        `<h2>Rename area</h2><label>Title<input id="d-title" value="${esc(d.title)}"></label><label>Short description<input id="d-blurb" value="${esc(d.blurb || '')}"></label>
        <div class="modal-actions"><button class="btn" value="cancel">Cancel</button><button class="btn primary" value="ok">Save</button></div>`,
        async () => {
          const { error } = await sb.from('assessment_domains').update({ title: $('#d-title').value.trim(), blurb: $('#d-blurb').value.trim() }).eq('id', d.id);
          if (error) return toast(error.message);
          renderQuestions();
        },
      );
    }),
  );
}

function optionRow(o = {}) {
  return `<div class="opt-row"><input placeholder="value" class="o-value" value="${esc(o.value ?? '')}"><input placeholder="Answer label" class="o-label" value="${esc(o.label ?? '')}">
    <input placeholder="Hint (optional)" class="o-hint" value="${esc(o.hint ?? '')}"><input placeholder="Score" type="number" class="o-score" value="${o.score ?? ''}">
    <button type="button" class="btn small danger o-del" aria-label="Remove answer">✕</button></div>`;
}

function editQuestion(q, domainId) {
  const isNew = !q;
  q = q || { id: '', domain_id: domainId, kind: 'single', text: '', help: '', options: [], optional: false, active: true };
  openModal(
    `<h2>${isNew ? 'Add question' : 'Edit question'}</h2>
    ${!isNew ? '<p class="notice" style="margin:0">Changing answer values after students have responded splits the results. Prefer editing labels, or retire the question and add a new one.</p>' : ''}
    <label>Question<textarea id="q-text">${esc(q.text)}</textarea></label>
    <label>Help text (optional)<input id="q-help" value="${esc(q.help || '')}"></label>
    <div class="form-grid">
      <label>Type<select id="q-kind">${Object.entries(KINDS).map(([k, v]) => `<option value="${k}" ${q.kind === k ? 'selected' : ''}>${v}</option>`).join('')}</select></label>
      <label>Unit (numbers)<input id="q-unit" value="${esc(q.unit || '')}"></label>
      <label>Min<input id="q-min" type="number" value="${q.min_value ?? ''}"></label>
      <label>Max<input id="q-max" type="number" value="${q.max_value ?? ''}"></label>
      <label>Max choices (multiple)<input id="q-maxc" type="number" value="${q.max_choices ?? ''}"></label>
      <label>Look (single choice)<select id="q-style">${Object.entries(STYLES).map(([k, v]) => `<option value="${k}" ${(q.style || '') === k ? 'selected' : ''}>${v}</option>`).join('')}</select></label>
      <label>Picture (optional)<input id="q-image" placeholder="e.g. food_groups/pulses.webp" value="${esc(q.image || '')}"></label>
    </div>
    <label class="check"><input type="checkbox" id="q-opt" ${q.optional ? 'checked' : ''}> Students may skip this question</label>
    <div id="opts-box"><h3>Answers</h3><p class="fine">Value is stored with each response; label is what students see. For a 1 to 5 scale use values 1 to 5.</p>
      <div id="opts" style="display:grid;gap:6px">${(q.options || []).map(optionRow).join('')}</div>
      <button type="button" class="btn small" id="add-opt" style="margin-top:8px">Add answer</button></div>
    <div class="modal-actions"><button class="btn" value="cancel">Cancel</button><button class="btn primary" value="ok">Save</button></div>`,
    async () => {
      const kind = $('#q-kind').value;
      const options = [...document.querySelectorAll('#opts .opt-row')]
        .map((r) => {
          const score = $('.o-score', r).value;
          const hint = $('.o-hint', r).value.trim();
          return { value: $('.o-value', r).value.trim(), label: $('.o-label', r).value.trim(), ...(hint ? { hint } : {}), ...(score !== '' ? { score: Number(score) } : {}) };
        })
        .filter((o) => o.value && o.label);
      const text = $('#q-text').value.trim();
      if (!text) return toast('Write the question first.');
      if (['single', 'multi', 'scale'].includes(kind) && options.length < 2) return toast('Add at least two answers.');
      const num = (id) => ($(id).value === '' ? null : Number($(id).value));
      const row = {
        text,
        help: $('#q-help').value.trim() || null,
        kind,
        unit: $('#q-unit').value.trim() || null,
        min_value: num('#q-min'),
        max_value: num('#q-max'),
        max_choices: num('#q-maxc'),
        optional: $('#q-opt').checked,
        options: ['number', 'text'].includes(kind) ? [] : options,
        style: $('#q-style').value || null,
        image: $('#q-image').value.trim() || null,
      };
      let error;
      if (isNew) {
        const pos = state.questions.filter((x) => x.domain_id === q.domain_id).length + 1;
        ({ error } = await sb.from('assessment_questions').insert({ ...row, id: `q${q.domain_id}_${Date.now().toString(36)}`, domain_id: q.domain_id, position: pos }));
      } else {
        ({ error } = await sb.from('assessment_questions').update(row).eq('id', q.id));
      }
      if (error) return toast(error.message);
      toast('Saved.');
      renderQuestions();
    },
  );
  const syncKind = () => ($('#opts-box').hidden = ['number', 'text'].includes($('#q-kind').value));
  $('#q-kind').onchange = syncKind;
  syncKind();
  $('#add-opt').onclick = () => $('#opts').insertAdjacentHTML('beforeend', optionRow());
  $('#opts').addEventListener('click', (e) => e.target.classList.contains('o-del') && e.target.closest('.opt-row').remove());
}

// ---------------------------------------------------------------------------
// Learn articles
// ---------------------------------------------------------------------------

const learnFilter = { topic: '' };

/** Article body <-> simple text the admin can edit. */
function bodyToText(b = {}) {
  const sections = (b.sections || [])
    .map((s) => [`## ${s.heading || ''}`, s.text || '', ...(s.bullets || []).map((x) => `- ${x}`)].filter(Boolean).join('\n'))
    .join('\n\n');
  return {
    hook: b.hook || b.intro || '',
    sections,
    key_point: b.key_point || '',
    myths: (b.myths || []).map((m) => `${m.myth} :: ${m.fact}`).join('\n'),
    takeaway: b.takeaway || '',
    try_this: b.try_this || '',
    seek_help: b.seek_help || '',
    references: (b.references || []).map((r) => (r.url ? `${r.label} | ${r.url}` : r.label)).join('\n'),
  };
}

function textToBody(t, old = {}) {
  const sections = [];
  let cur = null;
  for (const raw of t.sections.split('\n')) {
    const line = raw.trim();
    if (line.startsWith('## ')) {
      cur = { heading: line.slice(3).trim(), text: '', bullets: [] };
      sections.push(cur);
    } else if (line.startsWith('- ')) {
      if (!cur) sections.push((cur = { heading: '', text: '', bullets: [] }));
      cur.bullets.push(line.slice(2).trim());
    } else if (line) {
      if (!cur) sections.push((cur = { heading: '', text: '', bullets: [] }));
      cur.text = cur.text ? `${cur.text} ${line}` : line;
    }
  }
  sections.forEach((s) => !s.bullets.length && delete s.bullets);
  const lines = (v) => v.split('\n').map((x) => x.trim()).filter(Boolean);
  return {
    ...old,
    hook: t.hook.trim(),
    sections,
    key_point: t.key_point.trim() || undefined,
    myths: lines(t.myths).map((l) => {
      const [myth, fact] = l.split('::');
      return { myth: (myth || '').trim(), fact: (fact || '').trim() };
    }),
    takeaway: t.takeaway.trim() || undefined,
    try_this: t.try_this.trim() || undefined,
    seek_help: t.seek_help.trim() || undefined,
    references: lines(t.references).map((l) => {
      const [label, url] = l.split('|');
      return url ? { label: label.trim(), url: url.trim() } : { label: label.trim() };
    }),
  };
}

const slugify = (v) => v.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 60);

async function renderLearn() {
  const el = $('#tab-learn');
  const { data, error } = await sb.from('education_articles').select('*').order('category').order('sort_order').order('published_at', { ascending: false });
  const rows = (data || []).filter((a) => !learnFilter.topic || a.category === learnFilter.topic);
  el.innerHTML = `
    <div class="head"><div><h1>Learn articles</h1><p class="muted">Show, hide, edit or add the health articles students read in the app. Hidden articles stay saved but students cannot see them.</p></div>
      <button class="btn primary" id="l-add">Add article</button></div>
    <form class="card filters"><label>Topic<select id="l-topic"><option value="">All topics</option>
      ${Object.entries(LEARN_TOPICS).map(([k, v]) => `<option value="${k}" ${learnFilter.topic === k ? 'selected' : ''}>${esc(v)}</option>`).join('')}</select></label></form>
    ${error ? `<div class="notice">${esc(error.message)}</div>` : ''}
    <div class="card"><div class="table-wrap"><table><thead><tr><th>Article</th><th>Topic</th><th>Read</th><th>Status</th><th></th></tr></thead><tbody>
    ${
      rows
        .map(
          (a) => `<tr><td><strong>${esc(a.title)}</strong><br><span class="fine">${esc(a.subtitle || '')}</span></td>
            <td>${esc(LEARN_TOPICS[a.category] || a.category_label || a.category || '')}</td><td>${a.read_minutes || ''} min</td>
            <td>${a.hidden ? '<span class="pill warn">Hidden</span>' : '<span class="pill good">Shown</span>'}${a.is_featured ? ' <span class="pill info">Featured</span>' : ''}</td>
            <td class="row-actions"><button class="btn small" data-l-toggle="${esc(a.id)}">${a.hidden ? 'Show' : 'Hide'}</button>
              <button class="btn small" data-l-edit="${esc(a.id)}">Edit</button></td></tr>`,
        )
        .join('') || '<tr><td colspan="5" class="muted">No articles here yet.</td></tr>'
    }
    </tbody></table></div></div>
    <p class="fine">Write in plain, kind English. Every article needs at least one reliable reference (WHO, the Ministry of Health, NHS or peer-reviewed research).</p>`;
  $('#l-topic').onchange = (e) => ((learnFilter.topic = e.target.value), renderLearn());
  $('#l-add').onclick = () => editArticle(null);
  el.querySelectorAll('[data-l-toggle]').forEach((b) =>
    b.addEventListener('click', async () => {
      const a = data.find((x) => x.id === b.dataset.lToggle);
      const { error: e } = await sb.from('education_articles').update({ hidden: !a.hidden }).eq('id', a.id);
      if (e) return toast(`${e.message}. Has the latest database migration been applied?`);
      toast(a.hidden ? 'Article shown to students.' : 'Article hidden from students.');
      renderLearn();
    }),
  );
  el.querySelectorAll('[data-l-edit]').forEach((b) => b.addEventListener('click', () => editArticle(data.find((x) => x.id === b.dataset.lEdit))));
}

function editArticle(a) {
  const isNew = !a;
  a = a || { title: '', subtitle: '', category: learnFilter.topic || 'essentials', read_minutes: 4, body: {}, hidden: false, is_featured: false };
  const t = bodyToText(a.body || {});
  const area = (id, label, value, rows = 3, hint = '') =>
    `<label>${label}${hint ? ` <span class="fine">${hint}</span>` : ''}<textarea id="${id}" rows="${rows}">${esc(value)}</textarea></label>`;
  openModal(
    `<h2>${isNew ? 'Add article' : 'Edit article'}</h2>
    <label>Title<input id="a-title" required value="${esc(a.title)}"></label>
    <label>Subtitle<input id="a-subtitle" value="${esc(a.subtitle || '')}"></label>
    <div class="form-grid">
      <label>Topic<select id="a-topic">${Object.entries(LEARN_TOPICS).map(([k, v]) => `<option value="${k}" ${a.category === k ? 'selected' : ''}>${esc(v)}</option>`).join('')}</select></label>
      <label>Reading time (minutes)<input id="a-min" type="number" min="1" max="30" value="${a.read_minutes || 4}"></label>
      <label>Cover picture<input id="a-cover" type="file" accept="image/*"></label>
    </div>
    ${a.cover_url ? `<p class="fine">Current cover: <a href="${esc(a.cover_url)}" target="_blank" rel="noopener">view</a></p>` : ''}
    ${area('a-hook', 'Opening question or situation', t.hook, 2)}
    ${area('a-sections', 'Sections', t.sections, 12, 'Start each section with "## Heading". Lines starting with "- " become bullet points.')}
    ${area('a-key', 'Key point', t.key_point, 2)}
    ${area('a-myths', 'Myths and facts', t.myths, 3, 'One per line: myth :: fact')}
    ${area('a-takeaway', 'Key takeaway', t.takeaway, 2)}
    ${area('a-try', 'Try this', t.try_this, 2)}
    ${area('a-help', 'When to get help', t.seek_help, 2)}
    ${area('a-refs', 'References', t.references, 3, 'One per line: label | link')}
    <label class="check"><input type="checkbox" id="a-featured" ${a.is_featured ? 'checked' : ''}> Featured at the top of Learn</label>
    <label class="check"><input type="checkbox" id="a-hidden" ${a.hidden ? 'checked' : ''}> Hidden from students</label>
    <div class="modal-actions"><button class="btn" value="cancel">Cancel</button><button class="btn primary" value="ok">Save</button></div>`,
    async () => {
      const title = $('#a-title').value.trim();
      if (!title) return toast('Give the article a title.') || false;
      const body = textToBody(
        {
          hook: $('#a-hook').value,
          sections: $('#a-sections').value,
          key_point: $('#a-key').value,
          myths: $('#a-myths').value,
          takeaway: $('#a-takeaway').value,
          try_this: $('#a-try').value,
          seek_help: $('#a-help').value,
          references: $('#a-refs').value,
        },
        a.body || {},
      );
      if (!body.sections.length) return toast('Add at least one section.') || false;
      const topic = $('#a-topic').value;
      const row = {
        title,
        subtitle: $('#a-subtitle').value.trim() || null,
        category: topic,
        category_label: LEARN_TOPICS[topic],
        read_minutes: Number($('#a-min').value) || 4,
        body,
        is_featured: $('#a-featured').checked,
        hidden: $('#a-hidden').checked,
      };
      const file = $('#a-cover').files[0];
      if (file) {
        const path = `${slugify(title)}-${Date.now()}.${(file.name.split('.').pop() || 'jpg').toLowerCase()}`;
        const up = await sb.storage.from('article-covers').upload(path, file, { contentType: file.type, upsert: true });
        if (up.error) return toast(`Cover upload failed: ${up.error.message}`) || false;
        row.cover_url = sb.storage.from('article-covers').getPublicUrl(path).data.publicUrl;
      }
      let error;
      if (isNew) ({ error } = await sb.from('education_articles').insert({ ...row, slug: `${slugify(title)}-${Date.now().toString(36)}`, author: 'VitalU', published_at: new Date().toISOString() }));
      else ({ error } = await sb.from('education_articles').update(row).eq('id', a.id));
      if (error) return toast(`${error.message}. Has the latest database migration been applied?`) || false;
      toast('Article saved.');
      renderLearn();
    },
  );
}

// ---------------------------------------------------------------------------
// Anonymous consultations
// ---------------------------------------------------------------------------

const consultFilter = { status: 'open' };

async function refreshConsultCount() {
  const { count } = await sb.from('anon_consultations').select('id', { count: 'exact', head: true }).eq('status', 'open');
  const pill = $('#open-count');
  pill.hidden = !count;
  pill.textContent = count || '';
  $('#bell-dot').hidden = !count;
}

async function renderConsults() {
  const el = $('#tab-consults');
  let query = sb.from('anon_consultations').select('*').order('created_at', { ascending: false }).limit(200);
  if (consultFilter.status) query = query.eq('status', consultFilter.status);
  const { data, error } = await query;
  const urgency = { urgent: ['Urgent', 'bad'], soon: ['Soon', 'warn'], routine: ['Routine', ''] };
  el.innerHTML = `
    <div class="head"><div><h1>Anonymous consultations</h1><p class="muted">Questions sent to the health centre with no link to a student account. Replies appear in the student's app under their ticket code.</p></div>
      <label style="min-width:180px">Show<select id="c-status">
        <option value="open" ${consultFilter.status === 'open' ? 'selected' : ''}>Waiting for a reply</option>
        <option value="answered" ${consultFilter.status === 'answered' ? 'selected' : ''}>Answered</option>
        <option value="" ${consultFilter.status === '' ? 'selected' : ''}>All</option></select></label></div>
    <p class="fine">Urgent messages: if a message describes an emergency or risk of harm, the student has already been shown 1990 and 1926. Reply promptly with clear guidance to seek in-person help.</p>
    ${error ? `<div class="notice">${esc(error.message)}</div>` : ''}
    ${(data || [])
      .map(
        (c) => `<div class="card consult"><div class="q-meta"><strong>${esc(c.code)}</strong><span class="pill ${urgency[c.urgency]?.[1] || ''}">${esc(urgency[c.urgency]?.[0] || c.urgency)}</span>
          <span class="pill">${esc(c.topic)}</span><span class="fine">${fmtDateTime(c.created_at)}</span></div>
          <div class="msg">${esc(c.message)}</div>
          ${c.reply ? `<div class="reply"><strong>Your reply</strong> <span class="fine">${c.replied_at ? fmtDateTime(c.replied_at) : ''}</span><br>${esc(c.reply)}</div>` : ''}
          <div class="row-actions" style="justify-content:start"><button class="btn small primary" data-reply="${esc(c.id)}">${c.reply ? 'Edit reply' : 'Reply'}</button>
          ${c.status !== 'closed' ? `<button class="btn small" data-close="${esc(c.id)}">Close</button>` : ''}</div></div>`,
      )
      .join('') || '<div class="card muted">Nothing here.</div>'}`;
  $('#c-status').onchange = (e) => ((consultFilter.status = e.target.value), renderConsults());
  el.querySelectorAll('[data-reply]').forEach((b) =>
    b.addEventListener('click', () => {
      const c = data.find((x) => x.id === b.dataset.reply);
      openModal(
        `<h2>Reply to ${esc(c.code)}</h2><div class="quote msg">${esc(c.message)}</div>
        <label>Reply<textarea id="reply-text" rows="6">${esc(c.reply || '')}</textarea></label>
        <p class="fine">Do not ask for names or contact details. Suggest an in-person visit when needed.</p>
        <div class="modal-actions"><button class="btn" value="cancel">Cancel</button><button class="btn primary" value="ok">Send reply</button></div>`,
        async () => {
          const reply = $('#reply-text').value.trim();
          if (!reply) return toast('Write a reply first.');
          const { error: e } = await sb.from('anon_consultations').update({ reply, status: 'answered', replied_at: new Date().toISOString() }).eq('id', c.id);
          if (e) return toast(e.message);
          toast('Reply sent.');
          await refreshConsultCount();
          renderConsults();
        },
      );
    }),
  );
  el.querySelectorAll('[data-close]').forEach((b) =>
    b.addEventListener('click', async () => {
      await sb.from('anon_consultations').update({ status: 'closed' }).eq('id', b.dataset.close);
      await refreshConsultCount();
      renderConsults();
    }),
  );
}

// ---------------------------------------------------------------------------
// Modal
// ---------------------------------------------------------------------------

function openModal(html, onOk) {
  const dlg = $('#modal');
  const body = $('#modal-body');
  body.innerHTML = html;
  dlg.showModal();
  body.onsubmit = async (e) => {
    if (e.submitter?.value !== 'ok') return;
    e.preventDefault();
    if ((await onOk()) !== false) dlg.close();
  };
}

boot();
