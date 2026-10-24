// Research team view of the pilot feedback. Only accounts listed in
// public.feedback_viewers can read responses (pilot_feedback_responses()
// checks it in the database); campus administrators cannot.
'use strict';

const cfg = window.VITALU_EVAL;
// A separate storage key, so signing in here never shares a session with the
// admin dashboard when both are served from the same domain.
const sb = window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseKey, { auth: { storageKey: 'vitalu-eval-research-auth' } });

const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
const ROLE_NAME = { student: 'Undergraduate', staff: 'Staff and experts', lecturer: 'Staff and experts', admin: 'Staff and experts' };
const roleOf = (r) => LEGACY_ROLES[r.role] || r.role;
const FACULTY_NAME = Object.fromEntries(FACULTIES);

let all = [];

// ---------------------------------------------------------------------------
// Session
// ---------------------------------------------------------------------------

// Google sign-in and password reset emails return to this page. The URL
// must be listed in Supabase: Authentication > URL Configuration > Redirect URLs.
const RETURN_URL = location.origin + location.pathname;
let recovering = false;

function showLogin(message, ok) {
  $('#dash').hidden = true;
  $('#reset').hidden = true;
  $('#signout').hidden = true;
  $('#login').hidden = false;
  const err = $('#login-err');
  err.hidden = !message;
  err.textContent = message || '';
  const okEl = $('#login-ok');
  okEl.hidden = !ok;
  okEl.textContent = ok || '';
}

function showReset() {
  $('#dash').hidden = true;
  $('#login').hidden = true;
  $('#signout').hidden = true;
  $('#reset').hidden = false;
  $('#new-pass').focus();
}

// Arriving from a password reset email signs the person in with a recovery
// session; ask for the new password before showing anything else.
sb.auth.onAuthStateChange((event) => {
  if (event === 'PASSWORD_RECOVERY') {
    recovering = true;
    showReset();
  }
});

async function start() {
  // An error from Google or the reset link comes back in the URL.
  const back = new URLSearchParams(location.hash.slice(1) || location.search);
  if (back.get('error_description')) {
    history.replaceState(null, '', RETURN_URL);
    return showLogin(back.get('error_description').replace(/\+/g, ' '));
  }
  if (recovering) return;
  const { data } = await sb.auth.getSession();
  if (recovering) return;
  if (!data.session) return showLogin();
  const { data: ok, error } = await sb.rpc('is_feedback_viewer');
  if (error || !ok) {
    await sb.auth.signOut();
    return showLogin('This account does not have access to the feedback responses.');
  }
  $('#login').hidden = true;
  $('#dash').hidden = false;
  $('#signout').hidden = false;
  await load();
}

$('#login').addEventListener('submit', async (e) => {
  e.preventDefault();
  const btn = $('#login-btn');
  btn.disabled = true;
  btn.textContent = 'Signing in…';
  const { error } = await sb.auth.signInWithPassword({ email: $('#email').value.trim(), password: $('#password').value });
  btn.disabled = false;
  btn.textContent = 'Sign in';
  if (error) return showLogin('Email or password is incorrect.');
  start();
});

$('#google-btn').addEventListener('click', async () => {
  const { error } = await sb.auth.signInWithOAuth({ provider: 'google', options: { redirectTo: RETURN_URL } });
  if (error) showLogin('Google sign-in is not available right now. Use your email and password instead.');
});

$('#forgot-btn').addEventListener('click', async () => {
  const email = $('#email').value.trim();
  if (!email || !$('#email').checkValidity()) {
    $('#email').focus();
    return showLogin('Enter your email above, then press Forgot password again.');
  }
  const btn = $('#forgot-btn');
  btn.disabled = true;
  const { error } = await sb.auth.resetPasswordForEmail(email, { redirectTo: RETURN_URL });
  btn.disabled = false;
  if (error) {
    return showLogin(/rate|seconds/i.test(error.message) ? 'Please wait a minute before asking for another email.' : 'Could not send the email. Check the address and try again.');
  }
  showLogin(null, `If ${email} has an account, a password reset link is on its way. Open it on this device.`);
});

$('#reset').addEventListener('submit', async (e) => {
  e.preventDefault();
  const a = $('#new-pass').value;
  const b = $('#new-pass2').value;
  const err = $('#reset-err');
  err.hidden = false;
  if (a.length < 8) return (err.textContent = 'Use at least 8 characters.');
  if (a !== b) return (err.textContent = 'The two passwords do not match.');
  err.hidden = true;
  const btn = $('#reset-btn');
  btn.disabled = true;
  btn.textContent = 'Saving…';
  const { error } = await sb.auth.updateUser({ password: a });
  btn.disabled = false;
  btn.textContent = 'Save new password';
  if (error) {
    err.hidden = false;
    err.textContent = 'Could not save the new password. The reset link may have expired, so ask for a new one.';
    return;
  }
  recovering = false;
  history.replaceState(null, '', RETURN_URL);
  $('#reset').hidden = true;
  start();
});

$('#signout').addEventListener('click', async () => {
  await sb.auth.signOut();
  all = [];
  showLogin();
});

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

async function load() {
  $('#report').innerHTML = '<p class="muted">Loading responses…</p>';
  const { data, error } = await sb.rpc('pilot_feedback_responses');
  if (error) {
    $('#report').innerHTML = `<p class="error-msg">Could not load responses: ${esc(error.message)}</p>`;
    return;
  }
  all = data || [];
  render();
}

const filtered = () => {
  const role = $('#role-filter').value;
  return role ? all.filter((r) => roleOf(r) === role) : all;
};

$('#role-filter').addEventListener('change', render);
$('#refresh').addEventListener('click', load);
$('#export-menu').addEventListener('click', (e) => {
  const b = e.target.closest('[data-dl]');
  if (!b) return;
  const kind = b.dataset.dl;
  if (kind === 'codes') downloadCsv(filtered());
  if (kind === 'labels') downloadCsv(filtered(), true);
  if (kind === 'codebook') downloadCodebook();
  if (kind === 'wilcoxon') downloadWilcoxon(filtered());
  b.closest('details').open = false;
});

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------

const nums = (rows, k) => rows.map((r) => r.answers[k]).filter((v) => typeof v === 'number');
const mean = (xs) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : null);
const pct = (n, d) => (d ? Math.round((n / d) * 100) : 0);
const fmtDate = (iso) => new Date(iso).toLocaleString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });

// median() comes from stats.js.

function kpi(label, value, sub) {
  return `<div class="kpi"><div class="k">${esc(label)}</div><div class="v">${esc(value)}</div>${sub ? `<div class="s">${esc(sub)}</div>` : ''}</div>`;
}

function bars(rows, total) {
  if (!rows.length) return '<p class="muted">No answers yet.</p>';
  const max = Math.max(...rows.map((r) => r[1]), 1);
  return `<div class="bars">${rows
    .map(([label, n, suffix]) => `<div class="barrow"><span>${esc(label)}</span><span class="t"><i style="width:${(n / max) * 100}%"></i></span><span class="n">${suffix ?? `${n}${total ? ` (${pct(n, total)}%)` : ''}`}</span></div>`)
    .join('')}</div>`;
}

function render() {
  const rows = filtered();
  const counts = { student: 0, staff: 0 };
  all.forEach((r) => (counts[roleOf(r)] = (counts[roleOf(r)] || 0) + 1));
  $('#summary-line').textContent = `${all.length} total: ${counts.student} undergraduates, ${counts.staff} lecturers, administration, staff and experts`;

  if (!rows.length) {
    $('#report').innerHTML = `<div class="quote"><p>No responses ${all.length ? 'for this group' : 'yet'}. Share the form link, and responses will appear here as they arrive.</p></div>`;
    return;
  }

  const usab = rows.map((r) => usabilityScore(r.answers)).filter((v) => v !== '');
  const adopt = nums(rows, 'adopt_pref');
  const impact = nums(rows, 'impact');
  const likely = nums(rows, 'pa_likely');
  const usabMean = mean(usab);

  // Improvement priorities
  const improve = IMPROVE.map(([k, label]) => [label, rows.filter((r) => (r.answers.improve_pick || []).includes(k)).length]).sort((a, b) => b[1] - a[1]);

  // Feature usefulness: % rating 4 or 5 among those who rated it
  const features = FEATURES.map(([k, title]) => {
    const v = nums(rows, k);
    const useful = v.filter((x) => x >= 4).length;
    return [title, pct(useful, v.length), v.length ? `${pct(useful, v.length)}% of ${v.length}` : 'none'];
  }).sort((a, b) => b[1] - a[1]);

  // Before and now: Wilcoxon signed-rank test per statement, Holm-corrected.
  const prepost = wilcoxonTable(rows);

  // Favourite feature
  const favs = FEATURES.map(([k, title]) => [title, rows.filter((r) => r.answers.fav_feature === k).length]).filter((x) => x[1] > 0).sort((a, b) => b[1] - a[1]);
  const favTotal = rows.filter((r) => r.answers.fav_feature).length;

  // Admin dashboard comments (staff group only)
  const dashComments = rows.filter((r) => r.answers.d_comment);

  // Open-ended answers
  const open = rows.filter((r) => r.answers.open_overall || r.answers.open_improve);

  $('#report').innerHTML = `
    <div class="kpis">
      ${kpi('Responses', rows.length, $('#role-filter').value ? ROLE_NAME[$('#role-filter').value] : 'Everyone')}
      ${kpi('App usability (0 to 100)', usabMean == null ? '–' : usabMean.toFixed(1), usab.length ? `Mean of ${usab.length}, median ${median(usab)}. Eight items, not the standard SUS.` : 'No answers yet')}
      ${kpi('Adoption preference', adopt.length ? `${pct(adopt.filter((x) => x >= 4).length, adopt.length)}%` : '–', adopt.length ? `Agree or strongly agree, of ${adopt.length}` : 'No answers yet')}
      ${kpi('Expect lasting change', impact.length ? `${pct(impact.filter((x) => x >= 4).length, impact.length)}%` : '–', impact.length ? `Agree or strongly agree, of ${impact.length}` : 'No answers yet')}
      ${kpi('Students will complete it', likely.length ? `${pct(likely.filter((x) => x >= 4).length, likely.length)}%` : '–', likely.length ? `Undergraduates likely to complete the assessment, of ${likely.length}` : 'No answers yet')}
    </div>

    <div class="grid2">
      <div class="r-section"><h2>What to improve first</h2>${bars(improve.filter((x) => x[1] > 0), rows.length)}</div>
      <div class="r-section"><h2>Features rated very or extremely useful</h2><p class="fine" style="margin-bottom:10px">Undergraduates rate how useful a feature was for them. Staff and experts rate how useful they expect it to be for students. Use the filter to see one group.</p>${bars(features.filter((x) => x[2] !== 'none'))}</div>
    </div>
    <div class="r-section"><h2>Favourite feature</h2>${bars(favs, favTotal)}</div>

    ${prepost}

    ${dashComments.length ? `<div class="r-section"><h2>Admin dashboard comments (${dashComments.length})</h2>
      ${dashComments.map((r) => `<div class="quote"><div class="meta">${esc(ROLE_NAME[r.role])}, ${esc(fmtDate(r.submitted_at))}</div><p>${esc(r.answers.d_comment)}</p></div>`).join('')}</div>` : ''}

    <div class="r-section"><h2>In their own words (${open.length})</h2>
      ${open.length ? open.map((r) => `<div class="quote"><div class="meta">${esc(ROLE_NAME[r.role])}${r.answers.faculty ? `, ${esc(FACULTY_NAME[r.answers.faculty])}` : ''}, ${esc(fmtDate(r.submitted_at))}</div>
        ${r.answers.open_overall ? `<p><strong>Overall:</strong> ${esc(r.answers.open_overall)}</p>` : ''}
        ${r.answers.open_improve ? `<p><strong>Change, fix or add:</strong> ${esc(r.answers.open_improve)}</p>` : ''}</div>`).join('') : '<p class="muted">No written answers yet.</p>'}
    </div>

    <div class="r-section"><h2>All responses</h2>
      <p class="fine" style="margin-bottom:10px">Select a response to read every answer, then use Previous and Next to go through them one by one.</p>
      <div class="table-wrap"><table class="pick-table">
        <thead><tr><th>#</th><th>Submitted</th><th>Role</th><th>Faculty</th><th>Usability</th><th>Adoption preference</th><th>Lasting change</th><th></th></tr></thead>
        <tbody>${rows.map((r, i) => `<tr data-open="${i}" tabindex="0"><td class="num">${rows.length - i}</td><td>${esc(fmtDate(r.submitted_at))}</td><td>${esc(ROLE_NAME[r.role])}</td><td>${esc(FACULTY_NAME[r.answers.faculty] || '–')}</td>
          <td class="num">${usabilityScore(r.answers) === '' ? '–' : usabilityScore(r.answers)}</td><td class="num">${r.answers.adopt_pref ?? '–'}</td><td class="num">${r.answers.impact ?? '–'}</td><td><button class="btn ghost small" type="button" data-open="${i}">View</button></td></tr>`).join('')}</tbody>
      </table></div></div>

    <div class="r-section"><details class="data-table">
      <summary><h2>Data table, as exported</h2><span class="fine">One row per response, one column per question, numeric codes. This is exactly what Download CSV gives you.</span></summary>
      ${dataTable(rows)}
    </details></div>`;

  $('#report').querySelectorAll('[data-open]').forEach((el) => {
    const open = (e) => {
      e.stopPropagation();
      openResponse(Number(el.dataset.open));
    };
    el.addEventListener('click', open);
    if (el.tagName === 'TR') el.addEventListener('keydown', (e) => (e.key === 'Enter' || e.key === ' ') && (e.preventDefault(), open(e)));
  });
}

// ---------------------------------------------------------------------------
// Before and after: Wilcoxon signed-rank test
// ---------------------------------------------------------------------------

const p3 = (p) => (p == null ? '–' : p < 0.001 ? '< .001' : p.toFixed(3).replace(/^0/, ''));

function wilcoxonFor(rows) {
  const tests = PREPOST.map(([k, text]) => {
    const pairs = rows.filter((r) => typeof r.answers[k + '_pre'] === 'number' && typeof r.answers[k + '_post'] === 'number');
    return { k, text, res: wilcoxonSignedRank(pairs.map((r) => r.answers[k + '_pre']), pairs.map((r) => r.answers[k + '_post'])) };
  });
  const adj = holm(tests.map((t) => (t.res && t.res.n ? t.res.p : null)));
  tests.forEach((t, i) => (t.pHolm = adj[i]));
  return tests;
}

function wilcoxonTable(rows) {
  if (!rows.some((r) => typeof r.answers.pp1_pre === 'number')) return '';
  // Students and staff are tested separately, as the groups are different people.
  const groups = $('#role-filter').value
    ? [[ROLE_NAME[$('#role-filter').value], rows]]
    : [['Undergraduates', rows.filter((r) => roleOf(r) === 'student')], ['Staff and experts', rows.filter((r) => roleOf(r) === 'staff')]].filter(([, g]) => g.some((r) => typeof r.answers.pp1_pre === 'number'));
  const methods = new Set();
  const body = groups.map(([name, g]) => {
    const tests = wilcoxonFor(g);
    return `<tr class="group-row"><th colspan="9">${esc(name)}</th></tr>` + tests.map((t) => {
      const r = t.res;
      if (!r) return `<tr><td>${esc(t.text)}</td><td class="num" colspan="8">No pairs yet</td></tr>`;
      if (r.n) methods.add(r.method);
      const sig = t.pHolm != null && t.pHolm < 0.05;
      return `<tr>
        <td>${esc(t.text)}</td>
        <td class="num">${r.pairs}</td>
        <td class="num">${r.medianPre}</td>
        <td class="num">${r.medianPost}</td>
        <td class="num">${r.up} / ${r.same} / ${r.down}</td>
        <td class="num">${r.n ? `${r.wPlus} / ${r.wMinus}` : '–'}</td>
        <td class="num">${r.n ? r.z.toFixed(2) : '–'}</td>
        <td class="num">${r.n ? `${p3(r.p)} <span class="fine">(Holm ${p3(t.pHolm)})</span>` : '–'}${sig ? ' <span class="sig">significant</span>' : ''}</td>
        <td class="num">${r.n ? `${r.r.toFixed(2)} <span class="fine">${effectLabel(r.r)}</span>` : '–'}</td>
      </tr>`;
    }).join('');
  }).join('');
  const few = groups.some(([, g]) => g.filter((r) => typeof r.answers.pp1_pre === 'number').length < 20);
  return `<div class="r-section"><h2>Before and now: Wilcoxon signed-rank test</h2>
    <p class="fine" style="margin-bottom:10px">Each person rated each statement for before VitalU and now (1 = strongly disagree, 5 = strongly agree). The test checks whether "now" is consistently higher than "before". Medians are shown; W+ and W− are the summed ranks of increases and decreases; z is the standardised statistic; r = |z| / √n is the effect size (0.1 small, 0.3 medium, 0.5 large). p-values are two-sided, and Holm-corrected for the four statements. Method: ${esc([...methods].join('; ') || 'none yet')}. Same results as R <code>wilcox.test(post, pre, paired = TRUE)</code>.</p>
    ${few ? '<p class="fine warn-note">Fewer than 20 pairs in a group: treat the p-values with caution and report the medians and counts too.</p>' : ''}
    <div class="table-wrap"><table class="stats-table"><thead><tr><th>Statement</th><th>Pairs</th><th>Before (median)</th><th>Now (median)</th><th>Higher / same / lower</th><th>W+ / W−</th><th>z</th><th>p</th><th>r</th></tr></thead><tbody>${body}</tbody></table></div></div>`;
}

// ---------------------------------------------------------------------------
// One response at a time
// ---------------------------------------------------------------------------

let viewIndex = 0;

function openResponse(i) {
  const rows = filtered();
  if (!rows.length) return;
  viewIndex = (i + rows.length) % rows.length;
  const r = rows[viewIndex];
  let section = '';
  const items = fields().filter((f) => f.section !== 'Record').map((f) => {
    const v = f.get(r);
    if (v === '' || v === null || v === undefined) return '';
    // Ticked boxes: list only the ones ticked.
    if (f.values && f.values.length === 2 && f.values[1][1] === 'Ticked' && v !== 1) return '';
    const head = f.section !== section ? `<h3 class="v-sec">${esc((section = f.section))}</h3>` : '';
    const ans = f.values ? `${esc(labelOf(f, v))} <span class="code">${esc(v)}</span>` : esc(v);
    return `${head}<div class="v-row"><div class="v-q"><span class="code">${esc(f.col)}</span> ${esc(f.q)}</div><div class="v-a">${ans}</div></div>`;
  }).join('');
  const dlg = $('#viewer');
  dlg.querySelector('.v-title').textContent = `Response ${rows.length - viewIndex} of ${rows.length}`;
  dlg.querySelector('.v-meta').textContent = `${ROLE_NAME[r.role]}, submitted ${fmtDate(r.submitted_at)}. ID ${r.id}`;
  dlg.querySelector('.v-body').innerHTML = items || '<p class="muted">No answers.</p>';
  dlg.querySelector('.v-body').scrollTop = 0;
  const pick = dlg.querySelector('#v-pick');
  pick.innerHTML = rows.map((x, k) => `<option value="${k}" ${k === viewIndex ? 'selected' : ''}>#${rows.length - k}: ${esc(ROLE_NAME[x.role])}, ${esc(fmtDate(x.submitted_at))}</option>`).join('');
  if (!dlg.open) dlg.showModal();
}

$('#viewer').addEventListener('click', (e) => {
  const b = e.target.closest('[data-v]');
  if (b) {
    if (b.dataset.v === 'close') return $('#viewer').close();
    openResponse(viewIndex + (b.dataset.v === 'next' ? -1 : 1));
  } else if (e.target === $('#viewer')) {
    $('#viewer').close();
  }
});
$('#v-pick').addEventListener('change', (e) => openResponse(Number(e.target.value)));
document.addEventListener('keydown', (e) => {
  if (!$('#viewer').open || e.target.tagName === 'SELECT') return;
  if (e.key === 'ArrowRight') openResponse(viewIndex - 1);
  if (e.key === 'ArrowLeft') openResponse(viewIndex + 1);
});

// ---------------------------------------------------------------------------
// The data table, exactly as exported
// ---------------------------------------------------------------------------

function dataTable(rows) {
  const fs = fields();
  const head = fs.map((f) => `<th title="${esc(f.q)}">${esc(f.col)}</th>`).join('');
  const body = [...rows].reverse().map((r) => `<tr>${fs.map((f) => {
    const v = f.get(r);
    const s = v === null || v === undefined ? '' : String(v);
    return `<td title="${esc(labelOf(f, v))}">${esc(s.length > 40 ? s.slice(0, 40) + '…' : s)}</td>`;
  }).join('')}</tr>`).join('');
  return `<div class="table-wrap data-wrap"><table class="raw"><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table></div>`;
}

// ---------------------------------------------------------------------------
// CSV export: one row per response, columns and codes as in the codebook
// (docs/pilot-evaluation-form.md). Blank means not shown, skipped or
// "did not use".
// ---------------------------------------------------------------------------

function csvCell(v) {
  const s = v === null || v === undefined ? '' : String(v);
  return /[",\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

function saveFile(name, lines) {
  // A byte order mark so Excel opens the file as UTF-8.
  const blob = new Blob(['﻿' + lines.join('\r\n')], { type: 'text/csv;charset=utf-8' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 1000);
}

const fileTag = () => `${$('#role-filter').value ? '-' + $('#role-filter').value : ''}-${new Date().toISOString().slice(0, 10)}`;

/** One row per response, oldest first. labels = answer text instead of codes. */
function downloadCsv(rows, labels = false) {
  if (!rows.length) return alertBox('There are no responses to download yet.');
  const fs = fields();
  const lines = [fs.map((f) => f.col).join(',')];
  for (const r of [...rows].reverse()) lines.push(fs.map((f) => csvCell(labels ? labelOf(f, f.get(r)) : f.get(r))).join(','));
  saveFile(`vitalu-pilot-feedback${labels ? '-labels' : ''}${fileTag()}.csv`, lines);
}

/** What every column means and how each answer is coded. */
function downloadCodebook() {
  const lines = ['column,section,question,shown_to,codes'];
  for (const f of fields()) {
    const codes = f.values ? f.values.map(([c, l]) => `${c} = ${l}`).join('; ') : f.shown === 'Computed' ? 'number' : 'text';
    lines.push([f.col, f.section, f.q, f.shown, codes].map(csvCell).join(','));
  }
  saveFile('vitalu-pilot-feedback-codebook.csv', lines);
}

/** The Wilcoxon results table, ready for a report. */
function downloadWilcoxon(rows) {
  const lines = ['group,statement,pairs,median_before,median_now,higher,same,lower,n_nonzero,W_plus,W_minus,z,p,p_holm,r,effect,method'];
  const groups = $('#role-filter').value
    ? [[ROLE_NAME[$('#role-filter').value], rows]]
    : [['Undergraduates', rows.filter((r) => roleOf(r) === 'student')], ['Staff and experts', rows.filter((r) => roleOf(r) === 'staff')]];
  for (const [name, g] of groups) {
    for (const t of wilcoxonFor(g)) {
      const r = t.res;
      if (!r) continue;
      lines.push([name, t.text, r.pairs, r.medianPre, r.medianPost, r.up, r.same, r.down, r.n, r.wPlus, r.wMinus, r.z.toFixed(3), r.p.toFixed(4), t.pHolm == null ? '' : t.pHolm.toFixed(4), r.r.toFixed(3), effectLabel(r.r), r.method].map(csvCell).join(','));
    }
  }
  if (lines.length === 1) return alertBox('No before-and-after answers yet.');
  saveFile(`vitalu-pilot-wilcoxon${fileTag()}.csv`, lines);
}

function alertBox(message) {
  const p = document.createElement('p');
  p.className = 'error-msg';
  p.textContent = message;
  $('.r-bar').after(p);
  setTimeout(() => p.remove(), 4000);
}

start();
