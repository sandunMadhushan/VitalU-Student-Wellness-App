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
const KINDS = { single: 'Single choice', multi: 'Multiple choice', scale: '1 to 5 scale', number: 'Number', text: 'Free text' };

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
  $('#who-email').textContent = user.email || '';
  await Promise.all([loadMeta(), refreshConsultCount()]);
  openTab('overview');
}

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

const renderers = { overview: renderOverview, analytics: renderAnalytics, completion: renderCompletion, schedule: renderSchedule, questions: renderQuestions, consults: renderConsults };

function openTab(name) {
  document.querySelectorAll('.tab').forEach((t) => t.classList.toggle('active', t.dataset.tab === name));
  document.querySelectorAll('.tab-panel').forEach((p) => (p.hidden = p.id !== `tab-${name}`));
  renderers[name]();
}
document.querySelectorAll('.tab').forEach((t) => t.addEventListener('click', () => openTab(t.dataset.tab)));

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
  await loadMeta();
  const o = state.overview;
  const windows = o.windows || [];
  const current = windows.find((w) => windowStatus(w)[0] === 'Open') || windows.find((w) => windowStatus(w)[0] === 'Closed');
  const upcoming = windows.filter((w) => windowStatus(w)[0] === 'Upcoming').sort((a, b) => new Date(a.opens_at) - new Date(b.opens_at))[0];
  const byFaculty = Object.entries(o.students_by_faculty || {}).sort((a, b) => b[1] - a[1]);

  el.innerHTML = `
    <div class="head"><div><h1>Overview</h1><p class="muted">Registered students and assessment participation.</p></div></div>
    <div class="grid k4">
      <div class="card kpi"><div class="label">Registered students</div><div class="value">${o.students ?? 0}</div></div>
      <div class="card kpi"><div class="label">${current ? esc(current.term) : 'Latest window'} responses</div>
        <div class="value">${current ? current.completed : 0}</div>
        <div class="fine">${current ? `${pct(current.completed, current.eligible)}% of ${current.eligible} eligible` : 'No window yet'}</div></div>
      <div class="card kpi"><div class="label">In progress now</div><div class="value">${current ? current.in_progress : 0}</div></div>
      <div class="card kpi"><div class="label">Next window opens</div><div class="value" style="font-size:22px">${upcoming ? fmtDate(upcoming.opens_at) : 'Not scheduled'}</div>
        <div class="fine">${upcoming ? esc(upcoming.faculty || 'All faculties') : 'Use Schedule to plan one'}</div></div>
    </div>
    <div class="grid k2">
      <div class="card"><h3>Assessment windows</h3>
        <div class="table-wrap"><table><thead><tr><th>Window</th><th>Faculty</th><th>Dates</th><th>Completed</th></tr></thead><tbody>
        ${
          windows.length
            ? windows
                .map((w) => {
                  const [s, cls] = windowStatus(w);
                  return `<tr><td><strong>${esc(w.term)}</strong><br><span class="pill ${cls}">${s}</span></td>
                  <td>${esc(w.faculty || 'All faculties')}</td>
                  <td>${fmtDate(w.opens_at)} to ${fmtDate(w.closes_at)}</td>
                  <td>${w.completed} / ${w.eligible} <span class="fine">(${pct(w.completed, w.eligible)}%)</span></td></tr>`;
                })
                .join('')
            : '<tr><td colspan="4" class="muted">No windows scheduled yet.</td></tr>'
        }
        </tbody></table></div></div>
      <div class="card"><h3>Students by faculty</h3>${byFaculty.length ? bars(byFaculty.map(([k, v]) => ({ label: k.replace('Faculty of ', ''), value: v }))) : '<p class="muted">No students yet.</p>'}</div>
    </div>`;
}

// ---------------------------------------------------------------------------
// Analytics
// ---------------------------------------------------------------------------

const analytics = { window: '', faculty: '' };

async function renderAnalytics() {
  const el = $('#tab-analytics');
  const windows = state.overview?.windows || [];
  el.innerHTML = `
    <div class="head"><div><h1>Analytics</h1><p class="muted">Pooled results. Nothing is shown for groups smaller than five students.</p></div>
      <button class="btn" id="csv">Download CSV</button></div>
    <div class="card filters">
      <label>Assessment window<select id="f-window"><option value="">All windows</option>
        ${windows.map((w) => `<option value="${esc(w.id)}" ${analytics.window === w.id ? 'selected' : ''}>${esc(w.term)} · ${esc(w.faculty || 'All faculties')}</option>`).join('')}</select></label>
      <label>Faculty<select id="f-faculty"><option value="">All faculties</option>
        ${FACULTIES.map((f) => `<option ${analytics.faculty === f ? 'selected' : ''}>${esc(f)}</option>`).join('')}</select></label>
    </div>
    <div id="report"><p class="muted">Loading…</p></div>`;
  $('#f-window').onchange = (e) => ((analytics.window = e.target.value), renderAnalytics());
  $('#f-faculty').onchange = (e) => ((analytics.faculty = e.target.value), renderAnalytics());

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
  const groupRows = (obj) =>
    Object.entries(obj || {}).map(([k, v]) => ({ label: k.replace('Faculty of ', ''), value: v ?? 0, display: v == null ? 'fewer than 5' : v }));

  box.innerHTML = `
    <div class="grid k4">
      <div class="card kpi"><div class="label">Completed responses</div><div class="value">${data.n}</div></div>
      <div class="card kpi"><div class="label">Overall well-being</div><div class="value" style="color:${scoreColor(data.overall ?? 0)}">${data.overall ?? '–'}</div><div class="fine">out of 100, higher is healthier</div></div>
      <div class="card kpi"><div class="label">Healthy BMI</div><div class="value">${pct(data.bmi_categories?.Normal || 0, bmiTotal)}%</div><div class="fine">of ${bmiTotal} with measurements</div></div>
    </div>
    <div class="grid k2">
      <div class="card"><h3>Well-being by area</h3><p class="fine">Average score out of 100 for each area. Below 55 suggests a priority for support.</p>${domainRows.length ? bars(domainRows, { max: 100 }) : '<p class="muted">No scored answers yet.</p>'}</div>
      <div class="card"><h3>BMI categories</h3>${bars(bmi.map((r) => ({ ...r, display: `${r.value} (${pct(r.value, bmiTotal)}%)` })))}
        <h3 style="margin-top:18px">Responses by faculty</h3>${bars(groupRows(data.by_faculty))}
        <h3 style="margin-top:18px">Responses by sex</h3>${bars(groupRows(data.by_sex))}</div>
    </div>
    ${state.domains.map((d) => domainCard(d, data)).join('')}`;
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

  el.innerHTML = `
    <div class="head"><div><h1>Schedule an assessment</h1><p class="muted">The assessment runs every six months. Each faculty can have its own dates; windows stay open for a week by default.</p></div></div>
    <form class="card" id="sched" style="display:grid;gap:14px">
      <div class="form-grid">
        <label>Title<input name="title" required value="Periodic Health Assessment"></label>
        <label>Term label<input name="term" required placeholder="for example Semester 1, 2027"></label>
        <label>Opens on<input name="date" type="date" required value="${iso}"></label>
        <label>Opening time<input name="time" type="time" required value="08:00"></label>
        <label>Open for (days)<input name="days" type="number" min="1" max="31" value="7" required></label>
      </div>
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

  $('#sched').onsubmit = async (e) => {
    e.preventDefault();
    const f = new FormData(e.target);
    // Times are entered in Sri Lanka time (UTC+05:30).
    const opens = new Date(`${f.get('date')}T${f.get('time')}:00+05:30`);
    const faculties = f.getAll('faculty');
    const { error } = await sb.rpc('admin_schedule_assessment', {
      p_title: f.get('title'),
      p_term: f.get('term'),
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
    ${state.domains
      .map((d) => {
        const qs = state.questions.filter((q) => q.domain_id === d.id);
        return `<div class="card"><div class="head"><div><h2>${esc(d.position)}. ${esc(d.title)}</h2><p class="fine">${esc(d.blurb || '')}</p></div>
          <div class="row-actions"><button class="btn small" data-edit-domain="${d.id}">Rename area</button><button class="btn small primary" data-add="${d.id}">Add question</button></div></div>
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
// Anonymous consultations
// ---------------------------------------------------------------------------

const consultFilter = { status: 'open' };

async function refreshConsultCount() {
  const { count } = await sb.from('anon_consultations').select('id', { count: 'exact', head: true }).eq('status', 'open');
  const pill = $('#open-count');
  pill.hidden = !count;
  pill.textContent = count || '';
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
