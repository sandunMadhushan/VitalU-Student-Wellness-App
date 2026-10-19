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
const ROLE_NAME = { student: 'Undergraduate', lecturer: 'Lecturer', admin: 'Administration' };
const FACULTY_NAME = Object.fromEntries(FACULTIES);

let all = [];

// ---------------------------------------------------------------------------
// Session
// ---------------------------------------------------------------------------

function showLogin(message) {
  $('#dash').hidden = true;
  $('#signout').hidden = true;
  $('#login').hidden = false;
  const err = $('#login-err');
  err.hidden = !message;
  err.textContent = message || '';
}

async function start() {
  const { data } = await sb.auth.getSession();
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
  return role ? all.filter((r) => r.role === role) : all;
};

$('#role-filter').addEventListener('change', render);
$('#refresh').addEventListener('click', load);
$('#export').addEventListener('click', () => downloadCsv(filtered()));

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------

const nums = (rows, k) => rows.map((r) => r.answers[k]).filter((v) => typeof v === 'number');
const mean = (xs) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : null);
const pct = (n, d) => (d ? Math.round((n / d) * 100) : 0);
const fmtDate = (iso) => new Date(iso).toLocaleString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });

function median(xs) {
  if (!xs.length) return null;
  const s = [...xs].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
}

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
  const counts = { student: 0, lecturer: 0, admin: 0 };
  all.forEach((r) => (counts[r.role] = (counts[r.role] || 0) + 1));
  $('#summary-line').textContent = `${all.length} total: ${counts.student} undergraduates, ${counts.lecturer} lecturers, ${counts.admin} administration`;

  if (!rows.length) {
    $('#report').innerHTML = `<div class="quote"><p>No responses ${all.length ? 'for this group' : 'yet'}. Share the form link, and responses will appear here as they arrive.</p></div>`;
    return;
  }

  const sus = rows.map((r) => susScore(r.answers)).filter((v) => v !== '');
  const likely = nums(rows, 'pa_likely');
  const rec = nums(rows, 'recommend');
  const susMean = mean(sus);

  // Improvement priorities
  const improve = IMPROVE.map(([k, label]) => [label, rows.filter((r) => (r.answers.improve_pick || []).includes(k)).length]).sort((a, b) => b[1] - a[1]);

  // Feature usefulness: % rating 4 or 5 among those who rated it
  const features = FEATURES.map(([k, title]) => {
    const v = nums(rows, k);
    const useful = v.filter((x) => x >= 4).length;
    return [title, pct(useful, v.length), v.length ? `${pct(useful, v.length)}% of ${v.length}` : 'none'];
  }).sort((a, b) => b[1] - a[1]);

  // Before and now (medians)
  const prepost = PREPOST.map(([k, text]) => {
    const pairs = rows.filter((r) => typeof r.answers[k + '_pre'] === 'number' && typeof r.answers[k + '_post'] === 'number');
    const up = pairs.filter((r) => r.answers[k + '_post'] > r.answers[k + '_pre']).length;
    const down = pairs.filter((r) => r.answers[k + '_post'] < r.answers[k + '_pre']).length;
    return `<tr><td>${esc(text)}</td><td class="num">${pairs.length}</td><td class="num">${median(pairs.map((r) => r.answers[k + '_pre'])) ?? '–'}</td><td class="num">${median(pairs.map((r) => r.answers[k + '_post'])) ?? '–'}</td><td class="num">${up} / ${pairs.length - up - down} / ${down}</td></tr>`;
  }).join('');

  // Dashboard items
  const dash = DASHBOARD.map(([k, text]) => {
    const v = nums(rows, k);
    return `<tr><td>${esc(text)}</td><td class="num">${v.length}</td><td class="num">${median(v) ?? '–'}</td><td class="num">${v.length ? `${v.filter((x) => x >= 4).length} of ${v.length}` : '–'}</td></tr>`;
  }).join('');

  // Open-ended answers
  const open = rows.filter((r) => r.answers.open_best || r.answers.open_improve);

  $('#report').innerHTML = `
    <div class="kpis">
      ${kpi('Responses', rows.length, $('#role-filter').value ? ROLE_NAME[$('#role-filter').value] : 'Everyone')}
      ${kpi('App usability (SUS)', susMean == null ? '–' : susMean.toFixed(1), sus.length ? `Mean of ${sus.length}, median ${median(sus)}. Average is 68.` : 'No SUS answers yet')}
      ${kpi('Periodic assessment', likely.length ? `${pct(likely.filter((x) => x >= 4).length, likely.length)}%` : '–', likely.length ? `Likely or very likely, of ${likely.length}` : 'No answers yet')}
      ${kpi('Would recommend', rec.length ? `${pct(rec.filter((x) => x >= 4).length, rec.length)}%` : '–', rec.length ? `Likely or very likely, of ${rec.length}` : 'No answers yet')}
    </div>

    <div class="grid2">
      <div class="r-section"><h2>What to improve first</h2>${bars(improve.filter((x) => x[1] > 0), rows.length)}</div>
      <div class="r-section"><h2>Features rated very or extremely useful</h2>${bars(features.filter((x) => x[2] !== 'none'))}</div>
    </div>

    ${prepost && rows.some((r) => r.answers.pp1_pre != null) ? `<div class="r-section"><h2>Before and now</h2>
      <p class="fine" style="margin-bottom:10px">Medians on the 1 to 5 agreement scale. Run the Wilcoxon signed-rank test on the CSV (see docs/pilot-evaluation-form.md).</p>
      <div class="table-wrap"><table><thead><tr><th>Statement</th><th>Pairs</th><th>Before</th><th>Now</th><th>Higher / same / lower</th></tr></thead><tbody>${prepost}</tbody></table></div></div>` : ''}

    ${rows.some((r) => r.answers.d_nav != null || r.answers.d_sched != null) ? `<div class="r-section"><h2>Admin dashboard</h2>
      <div class="table-wrap"><table><thead><tr><th>Statement</th><th>Answers</th><th>Median</th><th>Agree</th></tr></thead><tbody>${dash}</tbody></table></div></div>` : ''}

    <div class="r-section"><h2>In their own words (${open.length})</h2>
      ${open.length ? open.map((r) => `<div class="quote"><div class="meta">${esc(ROLE_NAME[r.role])}${r.answers.faculty ? `, ${esc(FACULTY_NAME[r.answers.faculty])}` : ''}, ${esc(fmtDate(r.submitted_at))}</div>
        ${r.answers.open_best ? `<p><strong>Most useful:</strong> ${esc(r.answers.open_best)}</p>` : ''}
        ${r.answers.open_improve ? `<p><strong>Change, fix or add:</strong> ${esc(r.answers.open_improve)}</p>` : ''}</div>`).join('') : '<p class="muted">No written answers yet.</p>'}
    </div>

    <div class="r-section"><h2>All responses</h2>
      <div class="table-wrap"><table>
        <thead><tr><th>Submitted</th><th>Role</th><th>Faculty</th><th>SUS</th><th>Assessment likely</th><th>Recommend</th><th>Link</th></tr></thead>
        <tbody>${rows.map((r) => `<tr><td>${esc(fmtDate(r.submitted_at))}</td><td>${esc(ROLE_NAME[r.role])}</td><td>${esc(FACULTY_NAME[r.answers.faculty] || '–')}</td>
          <td class="num">${susScore(r.answers) === '' ? '–' : susScore(r.answers)}</td><td class="num">${r.answers.pa_likely ?? '–'}</td><td class="num">${r.answers.recommend ?? '–'}</td><td>${esc(r.link_group || '–')}</td></tr>`).join('')}</tbody>
      </table></div></div>`;
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

function downloadCsv(rows) {
  if (!rows.length) return alertBox('There are no responses to download yet.');
  const cols = csvColumns();
  const lines = [cols.map(([h]) => h).join(',')];
  // Oldest first reads more naturally in a spreadsheet.
  for (const r of [...rows].reverse()) lines.push(cols.map(([, f]) => csvCell(f(r))).join(','));
  // A byte order mark so Excel opens the file as UTF-8.
  const blob = new Blob(['﻿' + lines.join('\r\n')], { type: 'text/csv;charset=utf-8' });
  const a = document.createElement('a');
  const role = $('#role-filter').value;
  a.href = URL.createObjectURL(blob);
  a.download = `vitalu-pilot-feedback${role ? '-' + role : ''}-${new Date().toISOString().slice(0, 10)}.csv`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 1000);
}

function alertBox(message) {
  const p = document.createElement('p');
  p.className = 'error-msg';
  p.textContent = message;
  $('.r-bar').after(p);
  setTimeout(() => p.remove(), 4000);
}

start();
