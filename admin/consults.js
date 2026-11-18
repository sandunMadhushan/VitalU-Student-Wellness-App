// Consultations hub: the anonymous question inbox, consultation requests with
// appointments, and pooled trends in what students ask about.
//
// Requests live in public.consultation_requests, which nobody reads directly.
// The admin_consult_* functions return who asked, the concern, the status and the
// appointment to any administrator, and the reason for the visit and the notes
// ONLY to a signed-in health professional (a row in health_professionals linked to
// that user). The database enforces this; the page only reflects it.
'use strict';

const Consults = (() => {
  const STATUS = { pending: ['Pending', 'warn'], scheduled: ['Scheduled', 'info'], completed: ['Completed', 'good'], followup: ['Follow-up Required', 'bad'] };
  const URGENCY = { urgent: ['Urgent', 'bad'], soon: ['Soon', 'warn'], routine: ['Routine', ''] };
  const CATEGORIES = [
    { key: 'stress', label: 'Stress and anxiety', role: 'Counsellor', ind: 'high_stress', color: '#c2185b' },
    { key: 'mood', label: 'Low mood', role: 'Counsellor', ind: 'low_mood', color: '#7b5cc4' },
    { key: 'academic', label: 'Academic pressure', role: 'Counsellor', ind: 'high_stress', color: '#1a6fe0' },
    { key: 'sleep', label: 'Sleep problems', role: 'Medical Officer', ind: 'short_sleep', color: '#2a9d8f' },
    { key: 'nutrition', label: 'Nutrition and weight', role: 'Dietitian', ind: 'overweight_obese', color: '#d9a21b' },
    { key: 'activity', label: 'Injury and physical activity', role: 'Physiotherapist', ind: 'inactive', color: '#e07a2f' },
    { key: 'sexual', label: 'Sexual and reproductive health', role: 'Medical Officer', ind: null, color: '#5fae6e' },
    { key: 'substance', label: 'Smoking, alcohol and substances', role: 'Counsellor', ind: null, color: '#8b8699' },
  ];
  const CAT = Object.fromEntries(CATEGORIES.map((c) => [c.key, c]));
  const PAGE = 80;

  const ui = { view: 'requests', status: '', cat: '', q: '' };
  let reqs = [];
  let pros = [];
  let isPro = false;

  const when = (iso) => new Date(iso).toLocaleString('en-GB', { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
  const localInput = (iso) => {
    const d = new Date(iso || Date.now());
    return new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
  };
  const tomorrow10 = () => {
    const d = new Date();
    d.setDate(d.getDate() + 1);
    d.setHours(10, 0, 0, 0);
    return d.toISOString();
  };
  const icon = (id, s = 16) => `<svg width="${s}" height="${s}"><use href="#i-${id}"/></svg>`;
  const proOf = (id) => pros.find((p) => p.id === id);

  async function refresh() {
    const [r, p, who] = await Promise.all([
      sb.rpc('admin_consult_requests'),
      sb.from('health_professionals').select('*').eq('active', true).order('name'),
      sb.rpc('is_health_professional'),
    ]);
    if (r.error) toast(`Could not load consultation requests: ${r.error.message}`);
    reqs = (r.data || []).map((x) => ({
      id: x.id, ref: x.ref, student: x.student_name || 'Student', reg: x.registration_number || '', faculty: x.faculty || '', year: x.year_of_study,
      cat: x.category, urgency: x.urgency, mode: x.mode, status: x.status, requested: x.requested_at, pro: x.professional_id, when: x.scheduled_for,
      followUp: x.follow_up_by, reason: x.reason, notes: x.notes, history: x.history || [], restricted: x.restricted,
    }));
    pros = p.data || [];
    isPro = who.data === true;
  }

  // ------------------------------------------------------------------ Hub
  async function renderHub() {
    const el = $('#tab-consults');
    if (ui.view !== 'anon') el.innerHTML = '<p class="muted">Loading…</p>';
    await Promise.all([DEMO.ensure(), refresh()]);
    const pending = reqs.filter((r) => r.status === 'pending').length;
    const anon = Number($('#open-count')?.textContent) || 0;
    const tabs = [['anon', 'Anonymous questions', anon], ['requests', 'Requests and appointments', pending], ['trends', 'Trends', 0]];
    el.innerHTML = `
      <div class="head"><div><h1>Consultations</h1><p class="muted">Answer anonymous questions, manage consultation requests and appointments, and see what students are asking about.</p></div></div>
      <div class="seg" role="tablist" aria-label="Consultation views">${tabs.map(([k, t, n]) => `<button role="tab" aria-selected="${ui.view === k}" class="${ui.view === k ? 'on' : ''}" data-cv="${k}">${t}${n ? ` <span class="seg-n">${n}</span>` : ''}</button>`).join('')}</div>
      <div id="consult-pane" class="consult-pane"></div>`;
    el.querySelectorAll('[data-cv]').forEach((b) => (b.onclick = () => ((ui.view = b.dataset.cv), renderHub())));
    if (ui.view === 'anon') renderAnonConsults();
    else if (ui.view === 'trends') renderTrends();
    else renderRequests();
  }

  // ------------------------------------------------------------------ Requests
  function renderRequests() {
    const pane = $('#consult-pane');
    const q = ui.q.trim().toLowerCase();
    const order = { pending: 0, followup: 1, scheduled: 2, completed: 3 };
    const urg = { urgent: 0, soon: 1, routine: 2 };
    const list = reqs
      .filter((r) => (!ui.status || r.status === ui.status) && (!ui.cat || r.cat === ui.cat) && (!q || [r.ref, r.student, r.reg].some((v) => v.toLowerCase().includes(q))))
      .sort((a, b) => order[a.status] - order[b.status] || urg[a.urgency] - urg[b.urgency] || new Date(b.requested) - new Date(a.requested));
    const n = (s) => reqs.filter((r) => !s || r.status === s).length;
    const urgentWaiting = reqs.filter((r) => r.status === 'pending' && r.urgency === 'urgent').length;
    pane.innerHTML = `
      <div class="card privacy-bar">
        ${icon('shield', 20)}
        <div><strong>Confidential by design.</strong> ${
          isPro
            ? 'You are signed in as a health professional, so reasons for the visit and clinical notes are shown.'
            : 'Administrators see who has asked, the type of concern and the appointment. The reason for the visit and clinical notes are visible only to a signed-in health professional.'
        }</div>
      </div>
      ${urgentWaiting ? `<div class="notice bad-notice">${urgentWaiting} urgent ${urgentWaiting === 1 ? 'request is' : 'requests are'} waiting. Aim to schedule within one working day. If a student may be at risk of harm, the in-person emergency route (1990 / 1926) applies.</div>` : ''}
      <div class="grid k4">${Object.entries(STATUS).map(([k, [t]]) => `<button class="card kpi stat-btn ${ui.status === k ? 'sel' : ''}" data-st="${k}"><div class="label">${t}</div><div class="value">${n(k)}</div><div class="fine">${{ pending: 'waiting to be scheduled', scheduled: 'booked with a professional', completed: 'in the last 60 days', followup: 'needs another contact' }[k]}</div></button>`).join('')}</div>
      <div class="card filters">
        <label>Status<select id="c-st"><option value="">All (${n()})</option>${Object.entries(STATUS).map(([k, [t]]) => `<option value="${k}" ${ui.status === k ? 'selected' : ''}>${t} (${n(k)})</option>`).join('')}</select></label>
        <label>Concern<select id="c-cat"><option value="">All concerns</option>${CATEGORIES.map((c) => `<option value="${c.key}" ${ui.cat === c.key ? 'selected' : ''}>${esc(c.label)}</option>`).join('')}</select></label>
        <label>Find student<input id="c-q" type="search" placeholder="Name, registration no. or CR-1460" value="${esc(ui.q)}"></label>
      </div>
      <div class="card"><div class="table-wrap"><table class="reqs"><thead><tr><th>Request</th><th>Student</th><th>Concern</th><th>Requested</th><th>Appointment</th><th>Status</th><th></th></tr></thead><tbody>
      ${list.slice(0, PAGE).map(row).join('') || '<tr><td colspan="7" class="muted">No requests match.</td></tr>'}</tbody></table></div>
      ${list.length > PAGE ? `<p class="fine" style="margin-top:12px">Showing the first ${PAGE} of ${list.length}. Use the filters or search to narrow the list.</p>` : ''}</div>`;
    $('#c-st').onchange = (e) => ((ui.status = e.target.value), renderRequests());
    pane.querySelectorAll('[data-st]').forEach((b) => (b.onclick = () => ((ui.status = ui.status === b.dataset.st ? '' : b.dataset.st), renderRequests())));
    $('#c-cat').onchange = (e) => ((ui.cat = e.target.value), renderRequests());
    $('#c-q').oninput = (e) => {
      ui.q = e.target.value;
      clearTimeout(renderRequests.t);
      renderRequests.t = setTimeout(() => {
        renderRequests();
        const f = $('#c-q');
        f.focus();
        f.setSelectionRange(f.value.length, f.value.length);
      }, 250);
    };
    pane.querySelectorAll('[data-act]').forEach((b) =>
      b.addEventListener('click', () => {
        const [act, id] = b.dataset.act.split(':');
        const r = reqs.find((x) => x.id === id);
        ({ schedule: () => schedule(r), done: () => complete(r), view: () => details(r) })[act]();
      }),
    );
  }

  function row(r) {
    const [sText, sCls] = STATUS[r.status];
    const [uText, uCls] = URGENCY[r.urgency];
    const pro = proOf(r.pro);
    const acts = { pending: [['schedule', 'Schedule', 1]], scheduled: [['done', 'Mark completed']], followup: [['schedule', 'Book follow-up', 1], ['done', 'Mark completed']], completed: [] }[r.status];
    return `<tr>
      <td><strong>${esc(r.ref)}</strong><div class="fine">${r.urgency !== 'routine' ? `<span class="pill ${uCls}">${uText}</span> ` : ''}${esc(r.mode)}</div></td>
      <td><strong>${esc(r.student)}</strong><div class="fine">${esc(r.reg)} · ${esc(shortFaculty(r.faculty))}${r.year ? `, Year ${r.year}` : ''}</div></td>
      <td>${esc(CAT[r.cat].label)}</td>
      <td class="nowrap">${fmtDate(r.requested)}</td>
      <td>${r.when && pro ? `<strong>${esc(when(r.when))}</strong><div class="fine">${esc(pro.name)} · ${esc(pro.role)}</div>${r.status === 'followup' && r.followUp ? `<div class="fine">Review by ${fmtDate(r.followUp)}</div>` : ''}` : '<span class="muted">Not yet booked</span>'}</td>
      <td><span class="pill ${sCls}">${sText}</span></td>
      <td><div class="row-actions">${acts.map(([a, t, p]) => `<button class="btn small ${p ? 'primary' : ''}" data-act="${a}:${r.id}">${t}</button>`).join('')}<button class="btn small" data-act="view:${r.id}">Details</button></div></td></tr>`;
  }

  function schedule(r) {
    const cat = CAT[r.cat];
    const recommended = pros.filter((p) => p.role === cat.role);
    const others = pros.filter((p) => p.role !== cat.role);
    const opt = (p) => `<option value="${p.id}" ${p.id === r.pro ? 'selected' : ''}>${esc(p.name)} · ${esc(p.role)}</option>`;
    openModal(
      `<h2>${r.status === 'followup' ? 'Book a follow-up' : 'Schedule appointment'}</h2>
      <p class="muted">${esc(r.student)} · ${esc(r.reg)} · ${esc(shortFaculty(r.faculty))}${r.year ? `, Year ${r.year}` : ''} · ${esc(cat.label)}</p>
      <div class="form-grid">
        <label>Health professional<select id="s-pro"><optgroup label="Recommended: ${esc(cat.role)}">${recommended.map(opt).join('')}</optgroup><optgroup label="Other">${others.map(opt).join('')}</optgroup></select></label>
        <label>Date and time<input id="s-when" type="datetime-local" required value="${localInput(r.when && new Date(r.when) > new Date() ? r.when : tomorrow10())}"></label>
        <label>How<select id="s-mode">${['In person', 'Online', 'Phone'].map((m) => `<option ${m === r.mode ? 'selected' : ''}>${m}</option>`).join('')}</select></label>
      </div>
      <p class="fine">The student gets a notification in the app with the time and place.</p>
      <div class="modal-actions"><button class="btn" value="cancel" formnovalidate>Cancel</button><button class="btn primary" value="ok">Confirm appointment</button></div>`,
      async () => {
        const slot = new Date($('#s-when').value);
        if (isNaN(slot)) return toast('Choose a date and time.');
        const { error } = await sb.rpc('admin_consult_schedule', { p_id: r.id, p_pro: $('#s-pro').value, p_when: slot.toISOString(), p_mode: $('#s-mode').value });
        if (error) return toast(error.message);
        toast('Appointment confirmed. The student will be notified.');
        renderHub();
      },
    );
  }

  function complete(r) {
    const pro = proOf(r.pro);
    openModal(
      `<h2>Complete consultation</h2><p class="muted">${esc(r.ref)} · ${esc(CAT[r.cat].label)}${pro ? ` · ${esc(pro.name)}` : ''}</p>
      <label>Outcome<select id="o-out"><option value="done">Completed. No further action</option><option value="follow">Completed. Follow-up required</option></select></label>
      <label id="o-fu-wrap" hidden>Review by<input id="o-fu" type="date" value="${localInput(new Date(Date.now() + 14 * 86400000)).slice(0, 10)}"></label>
      ${isPro ? `<label>Confidential notes<textarea id="o-notes" rows="4"></textarea></label>` : '<p class="restricted">Clinical notes can only be written by a health professional.</p>'}
      <div class="modal-actions"><button class="btn" value="cancel">Cancel</button><button class="btn primary" value="ok">Save</button></div>`,
      async () => {
        const follow = $('#o-out').value === 'follow';
        if (follow && !$('#o-fu').value) return toast('Choose a review date.');
        const { error } = await sb.rpc('admin_consult_complete', {
          p_id: r.id,
          p_follow_up: follow ? new Date(`${$('#o-fu').value}T10:00`).toISOString() : null,
          p_notes: isPro ? $('#o-notes').value.trim() || null : null,
        });
        if (error) return toast(error.message);
        toast(follow ? 'Marked as follow-up required.' : 'Marked as completed.');
        renderHub();
      },
    );
    $('#o-out').onchange = (e) => ($('#o-fu-wrap').hidden = e.target.value !== 'follow');
  }

  function details(r) {
    const cat = CAT[r.cat];
    const pro = proOf(r.pro);
    const locked = `<p class="restricted">${icon('shield', 16)} Restricted. Visible only to a signed-in health professional.</p>`;
    openModal(
      `<h2>${esc(r.student)}</h2><p class="muted">${esc(r.ref)} · ${esc(cat.label)}</p>
      <div class="q-meta"><span class="pill ${STATUS[r.status][1]}">${STATUS[r.status][0]}</span><span class="pill ${URGENCY[r.urgency][1]}">${URGENCY[r.urgency][0]}</span><span class="fine">${esc(r.reg)} · ${esc(shortFaculty(r.faculty))}${r.year ? ` · Year ${r.year}` : ''} · prefers ${esc(r.mode.toLowerCase())}</span></div>
      ${r.when && pro ? `<p><strong>${esc(when(r.when))}</strong> with ${esc(pro.name)} (${esc(pro.role)}, ${esc(pro.unit || '')})</p>` : '<p class="muted">Not yet scheduled.</p>'}
      ${r.followUp ? `<p><strong>Follow-up due</strong> by ${fmtDate(r.followUp)}</p>` : ''}
      <div><span class="field-label">Reason given by the student</span>${isPro ? `<div class="quote">${esc(r.reason || '')}</div>` : locked}</div>
      <div><span class="field-label">Confidential notes</span>${isPro ? `<textarea id="d-notes" rows="4" placeholder="Add notes for this consultation">${esc(r.notes || '')}</textarea>` : locked}</div>
      <div><span class="field-label">Record</span><ol class="timeline">${r.history.map((h) => `<li><span>${esc(h.text)}</span><small>${fmtDateTime(h.at)}</small></li>`).join('')}</ol></div>
      <div class="modal-actions"><button class="btn" value="cancel">Close</button>${isPro ? '<button class="btn primary" value="ok">Save notes</button>' : ''}</div>`,
      async () => {
        if (!isPro) return;
        const { error } = await sb.rpc('admin_consult_save_notes', { p_id: r.id, p_notes: $('#d-notes').value.trim() });
        if (error) return toast(error.message);
        toast('Notes saved.');
        await refresh();
      },
    );
  }

  // ------------------------------------------------------------------ Trends
  const chg = (c) => (Math.abs(c) < 5 ? '<span class="chip flat"><span aria-hidden="true">●</span> steady</span>' : `<span class="chip ${c > 0 ? 'bad' : 'good'}"><span aria-hidden="true">${c > 0 ? '▲' : '▼'}</span> ${Math.abs(c)}%</span>`);

  async function renderTrends() {
    const pane = $('#consult-pane');
    pane.innerHTML = '<p class="muted">Loading…</p>';
    const { data, error } = await sb.rpc('admin_consult_trends');
    if (error) return (pane.innerHTML = `<div class="notice">Could not load trends: ${esc(error.message)}</div>`);
    const months = data.months || [];
    const counts = Object.fromEntries(CATEGORIES.map((c) => [c.key, months.map((m) => m.counts?.[c.key] || 0)]));
    const labels = months.map((m) => m.label);
    const sum = (arr, a, b) => arr.slice(a, b).reduce((x, y) => x + y, 0);
    const rows = CATEGORIES.map((c) => {
      const recent = sum(counts[c.key], 9, 12), before = sum(counts[c.key], 6, 9);
      return { c, recent, before, change: before ? Math.round(((recent - before) / before) * 100) : 0 };
    }).sort((a, b) => b.recent - a.recent);
    const total = rows.reduce((a, r) => a + r.recent, 0) || 1;
    const maxRecent = rows[0].recent || 1;
    const rising = rows.filter((r) => r.change >= 20 && r.recent >= 20);
    const latest = DEMO.PERIODS.at(-1)?.id;
    const link = (r) => {
      if (!r.c.ind || !latest) return '';
      const t = DEMO.trend(r.c.ind, {});
      const now = DEMO.summarize({ period: latest }).rates[r.c.ind];
      return now == null ? '' : ` Assessments show ${DEMO.IND[r.c.ind].short.toLowerCase()} at ${Charts.num(now, 0)}% of students${t.dir === 'worse' ? ' and rising' : ''}.`;
    };
    const byFac = data.by_faculty || {};
    pane.innerHTML = `
      <div class="card"><h3>Consultation requests by month</h3><p class="fine">All requests received in the last 12 months, by concern. Counts are pooled across the university with no student details.</p>
        ${Charts.columns({ labels, stacks: CATEGORIES.map((c) => ({ name: c.label, color: c.color, values: counts[c.key] })), aria: 'Consultation requests per month by concern' })}
        ${Charts.legend(CATEGORIES.map((c) => ({ label: c.label, color: c.color })))}</div>
      <div class="grid k2">
        <div class="card"><h3>Most commonly reported concerns</h3><p class="fine">Last 3 months, with the change compared with the 3 months before.</p>
          <div class="cmp">${rows.map((r) => `<div class="cmp-row"><span class="cmp-label">${esc(r.c.label)}<small>${Math.round((r.recent / total) * 100)}% of requests</small></span><div class="cmp-track"><i style="width:${(r.recent / maxRecent) * 100}%;background:${r.c.color}"></i></div><span class="cmp-val">${r.recent} ${chg(r.change)}</span></div>`).join('')}</div></div>
        <div class="card"><h3>Where more support may be needed</h3><p class="fine">Concerns with at least 20% more requests than the previous 3 months.</p>
          ${rising.length ? `<div class="list">${rising.map((r) => `<div class="li static"><span class="ini c0">${icon('pulse', 18)}</span><span class="li-main wrap"><strong>${esc(r.c.label)} up ${r.change}%</strong><span>${r.before} to ${r.recent} requests.${esc(link(r))}</span></span>${r.c.ind ? `<button class="btn small" data-plan="${r.c.ind}">Plan</button>` : ''}</div>`).join('')}</div>` : '<div class="empty">No concern has risen sharply.</div>'}</div>
      </div>
      <div class="card"><h3>Requests by faculty and concern</h3><p class="fine">Last 6 months. Counts under ${DEMO.MIN_GROUP} are hidden so that no one can be identified.</p>
        <div class="table-wrap"><table class="compare"><thead><tr><th>Faculty</th>${CATEGORIES.map((c) => `<th class="num">${esc(c.label.split(' ')[0] === 'Smoking,' ? 'Substances' : c.label.split(' and ')[0])}</th>`).join('')}</tr></thead><tbody>
        ${FACULTIES.map((f) => `<tr><td>${esc(shortFaculty(f))}</td>${CATEGORIES.map((c) => {
          const v = byFac[f]?.[c.key];
          return v == null || v < DEMO.MIN_GROUP ? '<td class="num muted">&lt;5</td>' : `<td class="num heat" style="background:color-mix(in srgb, var(--info) ${Math.min(34, 6 + v / 2)}%, transparent)">${v}</td>`;
        }).join('')}</tr>`).join('')}</tbody></table></div></div>`;
    pane.querySelectorAll('[data-plan]').forEach((b) => (b.onclick = () => Interventions.plan({ indicator: b.dataset.plan, faculties: [] })));
  }

  renderers.consults = renderHub;
  return { pending: () => reqs.filter((r) => r.status === 'pending').length };
})();
