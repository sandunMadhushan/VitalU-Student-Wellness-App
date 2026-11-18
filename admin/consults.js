// Consultations hub: the existing anonymous question inbox, plus consultation
// requests and appointments, plus pooled trends in what students ask about.
//
// Requests are kept in this browser's localStorage for now. Reasons and
// clinical notes are shown only when "Viewing as" is a health professional;
// the real system must enforce that rule in the database, not the page.
'use strict';

const Consults = (() => {
  const KEY = 'vitalu-admin-consult-requests-v2';
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
  const PROS = [
    { id: 'p1', name: 'Ms. K. Fernando', role: 'Counsellor', unit: 'Counselling Centre' },
    { id: 'p2', name: 'Mr. R. Jayasinghe', role: 'Counsellor', unit: 'Counselling Centre' },
    { id: 'p3', name: 'Dr. N. Perera', role: 'Medical Officer', unit: 'Medical Centre' },
    { id: 'p4', name: 'Dr. M. Rajapaksa', role: 'Medical Officer', unit: 'Medical Centre' },
    { id: 'p5', name: 'Ms. S. Wickramasinghe', role: 'Dietitian', unit: 'Nutrition Unit' },
    { id: 'p6', name: 'Mr. A. Silva', role: 'Physiotherapist', unit: 'Sports Medicine' },
  ];
  const REG = ['AG', 'AH', 'AR', 'DS', 'EN', 'MG', 'MD', 'SC', 'VT'];
  const PRO = Object.fromEntries(PROS.map((p) => [p.id, p]));

  const ui = { view: 'requests', status: '', cat: '', q: '', role: 'admin' };
  let memory = null;

  const at = (days, h = 9, m = 0) => {
    const d = new Date();
    d.setDate(d.getDate() + days);
    d.setHours(h, m, 0, 0);
    return d.toISOString();
  };

  // [ref, student name, faculty index, year, category, urgency, mode, requested (days ago), status, professional, appointment (days from today, hour, minute), follow-up (days from today), reason, notes]
  const SEED = [
    ['CR-0421', 'Nethmi Wijesekara', 6, 4, 'stress', 'urgent', 'In person', 0, 'pending', null, null, null, 'Finding it very hard to cope before final examinations and not sleeping.', ''],
    ['CR-0420', 'Kavindu Perera', 4, 3, 'sleep', 'soon', 'Online', 1, 'pending', null, null, null, 'Waking at 3 am most nights for the last month.', ''],
    ['CR-0419', 'Ayesha Fernando', 1, 2, 'mood', 'soon', 'In person', 2, 'pending', null, null, null, 'Feeling low and withdrawn since the start of the semester.', ''],
    ['CR-0418', 'Dineth Rajapaksha', 5, 1, 'nutrition', 'routine', 'Online', 3, 'pending', null, null, null, 'Would like advice on eating well on a hostel budget.', ''],
    ['CR-0417', 'Sanduni Jayawardena', 2, 2, 'academic', 'routine', 'In person', 4, 'pending', null, null, null, 'Struggling to keep up with deadlines across three courses.', ''],
    ['CR-0415', 'Thilini Gunasekara', 7, 3, 'stress', 'soon', 'Phone', 5, 'scheduled', 'p1', [1, 10, 0], null, 'Anxious about group presentations.', 'First session. Suggested breathing exercises.'],
    ['CR-0414', 'Mohamed Rizwan', 3, 3, 'activity', 'routine', 'In person', 6, 'scheduled', 'p6', [2, 14, 30], null, 'Knee pain after running.', ''],
    ['CR-0413', 'Hasitha Bandara', 4, 4, 'mood', 'urgent', 'In person', 7, 'scheduled', 'p2', [0, 15, 0], null, 'Feeling hopeless about final year project.', 'Safety check completed at intake call.'],
    ['CR-0410', 'Chamodi Senanayake', 0, 2, 'nutrition', 'routine', 'Online', 10, 'scheduled', 'p5', [4, 11, 0], null, 'Unintended weight loss over two months.', ''],
    ['CR-0405', 'Ishara Weerasinghe', 6, 3, 'stress', 'soon', 'In person', 14, 'completed', 'p1', [-9, 10, 0], null, 'Pressure of clinical placement.', 'Three sessions. Coping plan agreed; no further action.'],
    ['CR-0402', 'Lahiru Dissanayake', 5, 2, 'substance', 'routine', 'In person', 18, 'completed', 'p2', [-12, 13, 0], null, 'Wants to cut down on smoking.', 'Brief advice given; information leaflet shared.'],
    ['CR-0399', 'Sharmila Thavarajah', 8, 1, 'sexual', 'routine', 'In person', 21, 'completed', 'p3', [-15, 9, 30], null, 'Questions about contraception.', 'Counselled; referred to family planning clinic.'],
    ['CR-0396', 'Pasindu Amarasinghe', 4, 2, 'mood', 'urgent', 'In person', 24, 'followup', 'p1', [-17, 11, 0], 3, 'Low mood and loss of interest.', 'PHQ-9 moderate. Review in two weeks; consider medical referral.'],
    ['CR-0391', 'Fathima Nusrath', 1, 4, 'sleep', 'soon', 'Online', 28, 'followup', 'p3', [-20, 16, 0], 8, 'Poor sleep during night shifts at placement.', 'Sleep diary requested. Review after one week of changes.'],
    ['CR-0388', 'Oshadi Ranasinghe', 7, 1, 'academic', 'routine', 'Online', 30, 'completed', 'p2', [-25, 10, 30], null, 'Adjusting to university study.', 'Study skills workshop suggested.'],
  ];

  function seed() {
    return SEED.map(([ref, student, fac, year, cat, urgency, mode, ago, status, pro, appt, follow, reason, notes]) => {
      const requested = at(-ago, 9, 15);
      const history = [{ at: requested, text: 'Request received from the student app' }];
      if (pro) history.push({ at: at(-Math.max(0, ago - 1), 11), text: `Scheduled with ${PRO[pro].name}` });
      if (status === 'completed') history.push({ at: at(appt[0], appt[1] + 1), text: 'Consultation completed' });
      if (status === 'followup') history.push({ at: at(appt[0], appt[1] + 1), text: 'Consultation completed. Follow-up required' });
      const reg = `${REG[fac]}/${new Date().getFullYear() + 1 - year}/${String(ref.slice(3) * 7 % 900 + 100).padStart(4, '0')}`;
      return { id: `cr-${ref}`, ref, student, reg, faculty: FACULTIES[fac], year, cat, urgency, mode, requested, status, pro, when: appt ? at(appt[0], appt[1], appt[2]) : null, followUp: follow == null ? null : at(follow, 10), reason, notes, history };
    });
  }
  function load() {
    if (memory) return memory;
    try {
      const raw = localStorage.getItem(KEY);
      if (raw) return (memory = JSON.parse(raw));
    } catch {
      /* private mode: use the examples */
    }
    memory = seed();
    save();
    return memory;
  }
  function save() {
    try {
      localStorage.setItem(KEY, JSON.stringify(memory));
    } catch {
      /* keep in memory */
    }
  }

  const when = (iso) => new Date(iso).toLocaleString('en-GB', { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
  const localInput = (iso) => {
    const d = new Date(iso || Date.now());
    return new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
  };
  const isPro = () => ui.role === 'pro';
  const icon = (id, s = 16) => `<svg width="${s}" height="${s}"><use href="#i-${id}"/></svg>`;

  // ------------------------------------------------------------------ Hub
  function renderHub() {
    const el = $('#tab-consults');
    const pending = load().filter((r) => r.status === 'pending').length;
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
    const all = load();
    const q = ui.q.trim().toLowerCase();
    const list = all
      .filter((r) => (!ui.status || r.status === ui.status) && (!ui.cat || r.cat === ui.cat) && (!q || r.ref.toLowerCase().includes(q) || r.student.toLowerCase().includes(q) || r.reg.toLowerCase().includes(q)))
      .sort((a, b) => {
        const order = { pending: 0, followup: 1, scheduled: 2, completed: 3 };
        const u = { urgent: 0, soon: 1, routine: 2 };
        return order[a.status] - order[b.status] || u[a.urgency] - u[b.urgency] || new Date(b.requested) - new Date(a.requested);
      });
    const n = (s) => all.filter((r) => !s || r.status === s).length;
    const urgentWaiting = all.filter((r) => r.status === 'pending' && r.urgency === 'urgent').length;
    pane.innerHTML = `
      <div class="card privacy-bar">
        ${icon('shield', 20)}
        <div><strong>Confidential by design.</strong> Administrators see who has asked, the type of concern and the appointment. The reason for the visit and clinical notes are visible to the assigned health professional alone.</div>
        <label class="inline-sel">Viewing as<select id="c-role"><option value="admin" ${ui.role === 'admin' ? 'selected' : ''}>Administrator</option><option value="pro" ${ui.role === 'pro' ? 'selected' : ''}>Health professional</option></select></label>
      </div>
      ${urgentWaiting ? `<div class="notice bad-notice">${urgentWaiting} urgent ${urgentWaiting === 1 ? 'request is' : 'requests are'} waiting. Aim to schedule within one working day. If a student may be at risk of harm, the in-person emergency route (1990 / 1926) applies.</div>` : ''}
      <div class="grid k4">${Object.entries(STATUS).map(([k, [t]]) => `<button class="card kpi stat-btn ${ui.status === k ? 'sel' : ''}" data-st="${k}"><div class="label">${t}</div><div class="value">${n(k)}</div><div class="fine">${{ pending: 'waiting to be scheduled', scheduled: 'booked with a professional', completed: 'consultation done', followup: 'needs another contact' }[k]}</div></button>`).join('')}</div>
      <div class="card filters">
        <label>Status<select id="c-st"><option value="">All (${n()})</option>${Object.entries(STATUS).map(([k, [t]]) => `<option value="${k}" ${ui.status === k ? 'selected' : ''}>${t} (${n(k)})</option>`).join('')}</select></label>
        <label>Concern<select id="c-cat"><option value="">All concerns</option>${CATEGORIES.map((c) => `<option value="${c.key}" ${ui.cat === c.key ? 'selected' : ''}>${esc(c.label)}</option>`).join('')}</select></label>
        <label>Find student<input id="c-q" type="search" placeholder="Name, registration no. or CR-0421" value="${esc(ui.q)}"></label>
      </div>
      <div class="card"><div class="table-wrap"><table class="reqs"><thead><tr><th>Request</th><th>Student</th><th>Concern</th><th>Requested</th><th>Appointment</th><th>Status</th><th></th></tr></thead><tbody>
      ${list.map(row).join('') || '<tr><td colspan="7" class="muted">No requests match.</td></tr>'}</tbody></table></div></div>`;
    $('#c-role').onchange = (e) => ((ui.role = e.target.value), renderRequests());
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
        const r = load().find((x) => x.id === id);
        ({ schedule: () => schedule(r), done: () => complete(r), view: () => details(r) })[act]();
      }),
    );
  }

  function row(r) {
    const [sText, sCls] = STATUS[r.status];
    const [uText, uCls] = URGENCY[r.urgency];
    const acts = { pending: [['schedule', 'Schedule', 1]], scheduled: [['done', 'Mark completed']], followup: [['schedule', 'Book follow-up', 1], ['done', 'Mark completed']], completed: [] }[r.status];
    return `<tr>
      <td><strong>${esc(r.ref)}</strong><div class="fine">${r.urgency !== 'routine' ? `<span class="pill ${uCls}">${uText}</span> ` : ''}${esc(r.mode)}</div></td>
      <td><strong>${esc(r.student)}</strong><div class="fine">${esc(r.reg)} · ${esc(shortFaculty(r.faculty))}, Year ${r.year}</div></td>
      <td>${esc(CAT[r.cat].label)}</td>
      <td class="nowrap">${fmtDate(r.requested)}</td>
      <td>${r.when ? `<strong>${esc(when(r.when))}</strong><div class="fine">${esc(PRO[r.pro].name)} · ${esc(PRO[r.pro].role)}</div>${r.status === 'followup' && r.followUp ? `<div class="fine">Review by ${fmtDate(r.followUp)}</div>` : ''}` : '<span class="muted">Not yet booked</span>'}</td>
      <td><span class="pill ${sCls}">${sText}</span></td>
      <td><div class="row-actions">${acts.map(([a, t, p]) => `<button class="btn small ${p ? 'primary' : ''}" data-act="${a}:${r.id}">${t}</button>`).join('')}<button class="btn small" data-act="view:${r.id}">Details</button></div></td></tr>`;
  }

  function schedule(r) {
    const cat = CAT[r.cat];
    const recommended = PROS.filter((p) => p.role === cat.role);
    const others = PROS.filter((p) => p.role !== cat.role);
    const opt = (p) => `<option value="${p.id}" ${p.id === r.pro ? 'selected' : ''}>${esc(p.name)} · ${esc(p.role)}</option>`;
    openModal(
      `<h2>${r.status === 'followup' ? 'Book a follow-up' : 'Schedule appointment'}</h2>
      <p class="muted">${esc(r.student)} · ${esc(r.reg)} · ${esc(shortFaculty(r.faculty))}, Year ${r.year} · ${esc(cat.label)}</p>
      <div class="form-grid">
        <label>Health professional<select id="s-pro"><optgroup label="Recommended: ${esc(cat.role)}">${recommended.map(opt).join('')}</optgroup><optgroup label="Other">${others.map(opt).join('')}</optgroup></select></label>
        <label>Date and time<input id="s-when" type="datetime-local" required value="${localInput(r.when || at(1, 10))}"></label>
        <label>How<select id="s-mode">${['In person', 'Online', 'Phone'].map((m) => `<option ${m === r.mode ? 'selected' : ''}>${m}</option>`).join('')}</select></label>
      </div>
      <p class="fine">The student gets a notification in the app with the time and place. </p>
      <div class="modal-actions"><button class="btn" value="cancel" formnovalidate>Cancel</button><button class="btn primary" value="ok">Confirm appointment</button></div>`,
      () => {
        const proId = $('#s-pro').value;
        const slot = new Date($('#s-when').value);
        if (isNaN(slot)) return toast('Choose a date and time.');
        if (slot < new Date()) return toast('Choose a time in the future.');
        const clash = load().find((x) => x.id !== r.id && x.pro === proId && x.status === 'scheduled' && x.when && Math.abs(new Date(x.when) - slot) < 30 * 60000);
        if (clash) return toast(`${PRO[proId].name} already has an appointment at ${when(clash.when)}.`);
        r.pro = proId;
        r.when = slot.toISOString();
        r.mode = $('#s-mode').value;
        r.status = 'scheduled';
        r.followUp = null;
        r.history.push({ at: new Date().toISOString(), text: `${r.history.some((h) => /completed/i.test(h.text)) ? 'Follow-up booked' : 'Scheduled'} with ${PRO[proId].name} for ${when(r.when)}` });
        save();
        toast('Appointment confirmed. The student will be notified.');
        renderHub();
      },
    );
  }

  function complete(r) {
    openModal(
      `<h2>Complete consultation</h2><p class="muted">${esc(r.ref)} · ${esc(CAT[r.cat].label)} · ${esc(PRO[r.pro].name)}</p>
      <label>Outcome<select id="o-out"><option value="done">Completed. No further action</option><option value="follow">Completed. Follow-up required</option></select></label>
      <label id="o-fu-wrap" hidden>Review by<input id="o-fu" type="date" value="${localInput(at(14)).slice(0, 10)}"></label>
      ${isPro() ? `<label>Confidential notes<textarea id="o-notes" rows="4">${esc(r.notes)}</textarea></label>` : '<p class="restricted">Clinical notes can only be written by the health professional.</p>'}
      <div class="modal-actions"><button class="btn" value="cancel">Cancel</button><button class="btn primary" value="ok">Save</button></div>`,
      () => {
        const follow = $('#o-out').value === 'follow';
        if (follow && !$('#o-fu').value) return toast('Choose a review date.');
        r.status = follow ? 'followup' : 'completed';
        r.followUp = follow ? new Date(`${$('#o-fu').value}T10:00`).toISOString() : null;
        if (isPro()) r.notes = $('#o-notes').value.trim();
        r.history.push({ at: new Date().toISOString(), text: follow ? `Consultation completed. Follow-up required by ${fmtDate(r.followUp)}` : 'Consultation completed' });
        save();
        toast(follow ? 'Marked as follow-up required.' : 'Marked as completed.');
        renderHub();
      },
    );
    $('#o-out').onchange = (e) => ($('#o-fu-wrap').hidden = e.target.value !== 'follow');
  }

  function details(r) {
    const cat = CAT[r.cat];
    const locked = '<p class="restricted">' + icon('shield', 16) + ' Restricted. Visible only to the assigned health professional.</p>';
    openModal(
      `<h2>${esc(r.student)}</h2><p class="muted">${esc(r.ref)} · ${esc(cat.label)}</p>
      <div class="q-meta"><span class="pill ${STATUS[r.status][1]}">${STATUS[r.status][0]}</span><span class="pill ${URGENCY[r.urgency][1]}">${URGENCY[r.urgency][0]}</span><span class="fine">${esc(r.student)} · ${esc(r.reg)} · ${esc(shortFaculty(r.faculty))} · Year ${r.year} · prefers ${esc(r.mode.toLowerCase())}</span></div>
      ${r.when ? `<p><strong>${esc(when(r.when))}</strong> with ${esc(PRO[r.pro].name)} (${esc(PRO[r.pro].role)}, ${esc(PRO[r.pro].unit)})</p>` : '<p class="muted">Not yet scheduled.</p>'}
      ${r.followUp ? `<p><strong>Follow-up due</strong> by ${fmtDate(r.followUp)}</p>` : ''}
      <div><span class="field-label">Reason given by the student</span>${isPro() ? `<div class="quote">${esc(r.reason)}</div>` : locked}</div>
      <div><span class="field-label">Confidential notes</span>${isPro() ? `<textarea id="d-notes" rows="4" placeholder="Add notes for this consultation">${esc(r.notes)}</textarea>` : locked}</div>
      <div><span class="field-label">Record</span><ol class="timeline">${r.history.map((h) => `<li><span>${esc(h.text)}</span><small>${fmtDateTime(h.at)}</small></li>`).join('')}</ol></div>
      <div class="modal-actions"><button class="btn" value="cancel">Close</button>${isPro() ? '<button class="btn primary" value="ok">Save notes</button>' : ''}</div>`,
      () => {
        if (!isPro()) return;
        r.notes = $('#d-notes').value.trim();
        save();
        toast('Notes saved.');
      },
    );
  }

  // ------------------------------------------------------------------ Trends
  // Pooled monthly counts (sample). Faculty groups with fewer than 5 are hidden.
  function trendData() {
    if (trendData.cache) return trendData.cache;
    const months = Array.from({ length: 12 }, (_, i) => {
      const d = new Date();
      d.setDate(1);
      d.setMonth(d.getMonth() - (11 - i));
      return d;
    });
    const labels = months.map((d) => d.toLocaleDateString('en-GB', { month: 'short' }));
    const prof = { stress: [22, 1.6], mood: [14, 0.7], academic: [18, 0.4], sleep: [9, 0.6], nutrition: [11, 0], activity: [8, 0.1], sexual: [6, 0.1], substance: [4, 0] };
    const counts = {};
    CATEGORIES.forEach((c, ci) => {
      const [base, growth] = prof[c.key];
      const r = DEMO.rng(700 + ci);
      counts[c.key] = months.map((d, i) => {
        const exam = [5, 10].includes(d.getMonth()) ? 1.35 : [3, 8].includes(d.getMonth()) ? 1.1 : 1;
        return Math.max(0, Math.round((base + growth * i) * exam + (r() - 0.5) * 4));
      });
    });
    const fr = DEMO.rng(4242);
    const sums = Object.fromEntries(CATEGORIES.map((c) => [c.key, counts[c.key].slice(-6).reduce((a, b) => a + b, 0)]));
    const size = [28, 36, 52, 14, 60, 56, 30, 48, 12];
    const heat = FACULTIES.map((f, fi) => {
      const row = {};
      CATEGORIES.forEach((c) => {
        const w = size.map((s, k) => s * (0.7 + fr() * 0.6) * (c.key === 'stress' && (k === 6 || k === 4) ? 1.6 : 1));
        row[c.key] = Math.round((sums[c.key] * w[fi]) / w.reduce((a, b) => a + b, 0));
      });
      return { faculty: f, row };
    });
    return (trendData.cache = { labels, counts, heat });
  }
  const chg = (c) => (Math.abs(c) < 5 ? '<span class="chip flat"><span aria-hidden="true">●</span> steady</span>' : `<span class="chip ${c > 0 ? 'bad' : 'good'}"><span aria-hidden="true">${c > 0 ? '▲' : '▼'}</span> ${Math.abs(c)}%</span>`);

  function renderTrends() {
    const pane = $('#consult-pane');
    const { labels, counts, heat } = trendData();
    const sum = (arr, a, b) => arr.slice(a, b).reduce((x, y) => x + y, 0);
    const rows = CATEGORIES.map((c) => {
      const recent = sum(counts[c.key], 9, 12), before = sum(counts[c.key], 6, 9);
      return { c, recent, before, change: before ? Math.round(((recent - before) / before) * 100) : 0 };
    }).sort((a, b) => b.recent - a.recent);
    const total = rows.reduce((a, r) => a + r.recent, 0);
    const maxRecent = rows[0].recent;
    const rising = rows.filter((r) => r.change >= 20 && r.recent >= 20);
    const link = (r) => {
      if (!r.c.ind) return '';
      const t = DEMO.trend(r.c.ind, {});
      const now = DEMO.summarize({ period: DEMO.PERIODS.at(-1).id }).rates[r.c.ind];
      return ` Assessments show ${DEMO.IND[r.c.ind].short.toLowerCase()} at ${Charts.num(now, 0)}% of students${t.dir === 'worse' ? ' and rising' : ''}.`;
    };
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
        ${heat.map((h) => `<tr><td>${esc(shortFaculty(h.faculty))}</td>${CATEGORIES.map((c) => {
          const v = h.row[c.key];
          return v < DEMO.MIN_GROUP ? '<td class="num muted">&lt;5</td>' : `<td class="num heat" style="background:color-mix(in srgb, var(--info) ${Math.min(34, 6 + v)}%, transparent)">${v}</td>`;
        }).join('')}</tr>`).join('')}</tbody></table></div></div>`;
    pane.querySelectorAll('[data-plan]').forEach((b) => (b.onclick = () => Interventions.plan({ indicator: b.dataset.plan, faculties: [] })));
  }

  renderers.consults = renderHub;
  return { pending: () => load().filter((r) => r.status === 'pending').length };
})();
