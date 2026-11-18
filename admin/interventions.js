// Intervention planning and monitoring: plan a health promotion activity for a
// priority need, assign who is responsible, tick off milestones and see whether
// the next assessments show the concern improving.
//
// SAMPLE: records live in this browser's localStorage and start with a few
// example interventions. Baselines and results are always calculated from the
// assessment data, never typed in.
'use strict';

const Interventions = (() => {
  const KEY = 'vitalu-admin-interventions-v1';
  const STATUS = { planned: ['Planned', ''], running: ['In progress', 'info'], completed: ['Completed', 'good'], hold: ['On hold', 'warn'] };
  const { PERIODS, IND } = DEMO;
  const filter = { status: '' };
  let memory = null;

  const seed = () => [
    {
      id: 'iv-seed-1', title: 'Healthy Plate weeks and subsidised fruit stalls', indicator: 'low_fruit_veg',
      faculties: [FACULTIES[4], FACULTIES[5], FACULTIES[7]], owner: 'Dr. N. Perera', unit: 'Nutrition Unit',
      start: '2026-02-02', end: '2026-12-18', status: 'running', targetPts: 8, baselinePeriod: '2025-end',
      milestones: [['Review canteen menus with operators', 1], ['Weekly subsidised fruit stalls started', 1], ['Healthy Plate awareness weeks in three faculties', 0], ['Share results at Year End 2026 assessment', 0]],
      notes: 'Canteen operators agreed to a price cap on seasonal fruit.',
    },
    {
      id: 'iv-seed-2', title: 'Campus Move 30: lunchtime activity breaks', indicator: 'inactive',
      faculties: [], owner: 'Mr. A. Silva', unit: 'Sports Unit',
      start: '2026-03-02', end: '2026-11-30', status: 'running', targetPts: 6, baselinePeriod: '2025-end',
      milestones: [['Open-access sports sessions timetabled', 1], ['Walking routes marked on campus', 1], ['Faculty step-count challenge', 0], ['Midpoint review with faculties', 0]],
      notes: 'Uptake is lowest in the evening sessions.',
    },
    {
      id: 'iv-seed-3', title: 'Peer-led stress management workshops', indicator: 'high_stress',
      faculties: [FACULTIES[1], FACULTIES[3], FACULTIES[4], FACULTIES[6]], owner: 'Ms. K. Fernando', unit: 'Counselling Centre',
      start: '2027-01-11', end: '2027-06-30', status: 'planned', targetPts: 6, baselinePeriod: '2026-mid',
      milestones: [['Train 20 student peer facilitators', 0], ['Agree timetable slots with four faculties', 0], ['Run first round of workshops', 0], ['Reassess at Mid Year 2027', 0]],
      notes: '',
    },
    {
      id: 'iv-seed-4', title: 'Hostel breakfast clubs', indicator: 'skip_breakfast',
      faculties: [FACULTIES[4], FACULTIES[5], FACULTIES[2]], owner: 'Ms. S. Wickramasinghe', unit: 'Nutrition Unit',
      start: '2025-07-07', end: '2025-11-28', status: 'completed', targetPts: 4, baselinePeriod: '2025-mid',
      milestones: [['Agree early opening hours with hostel kitchens', 1], ['Launch clubs in six hostels', 1], ['Collect student feedback', 1], ['Reassess at Year End 2025', 1]],
      notes: 'Continued as a standing service after the pilot.',
    },
    {
      id: 'iv-seed-5', title: 'Sleep hygiene awareness campaign', indicator: 'short_sleep',
      faculties: [], owner: 'Dr. M. Rajapaksa', unit: 'Medical Centre',
      start: '2026-08-03', end: '2026-12-11', status: 'hold', targetPts: 5, baselinePeriod: '2026-mid',
      milestones: [['Design posters and in-app messages', 1], ['Pilot quiet hours in two hostels', 0], ['Campaign before examinations', 0]],
      notes: 'Paused until after the semester examinations.',
    },
  ].map((iv) => ({ ...iv, milestones: iv.milestones.map(([text, done]) => ({ text, done: !!done })) }));

  function load() {
    if (memory) return memory;
    try {
      const raw = localStorage.getItem(KEY);
      if (raw) return (memory = JSON.parse(raw));
    } catch {
      /* private mode or corrupt data: fall back to the examples */
    }
    memory = seed();
    save();
    return memory;
  }
  function save() {
    try {
      localStorage.setItem(KEY, JSON.stringify(memory));
    } catch {
      /* private mode: keep in memory only */
    }
  }

  const facText = (iv) => (iv.faculties.length ? iv.faculties.map(shortFaculty).join(', ') : 'All faculties');

  // Compare the baseline period with the latest assessment after the start date.
  function evaluate(iv) {
    const ind = IND[iv.indicator];
    const flt = { faculties: iv.faculties };
    const base = DEMO.summarize({ ...flt, period: iv.baselinePeriod });
    const baseIdx = PERIODS.findIndex((p) => p.id === iv.baselinePeriod);
    const after = PERIODS.filter((p, i) => i > baseIdx && new Date(p.date) > new Date(iv.start));
    const out = { ind, baseline: base.suppressed ? null : base.rates[iv.indicator], goal: null, current: null, state: 'awaiting' };
    if (out.baseline != null) out.goal = Math.max(0, out.baseline - iv.targetPts);
    if (out.baseline == null) return { ...out, state: 'small' };
    if (!after.length) return out;
    const cur = DEMO.summarize({ ...flt, period: after.at(-1).id });
    if (cur.suppressed) return { ...out, state: 'small' };
    const achieved = out.baseline - cur.rates[iv.indicator];
    out.current = cur.rates[iv.indicator];
    out.periodLabel = after.at(-1).label;
    out.achieved = Math.round(achieved * 10) / 10;
    out.state = achieved >= iv.targetPts ? 'met' : achieved >= iv.targetPts * 0.5 ? 'track' : achieved > 0 ? 'early' : 'none';
    return out;
  }
  const VERDICT = { met: ['Target met', 'good'], track: ['On track', 'info'], early: ['Early progress', 'warn'], none: ['Not improving yet', 'bad'], awaiting: ['Awaiting reassessment', ''], small: ['Too few students to measure', ''] };

  function counts() {
    const list = load();
    const e = list.map(evaluate);
    return {
      total: list.length,
      planned: list.filter((i) => i.status === 'planned').length,
      running: list.filter((i) => i.status === 'running').length,
      completed: list.filter((i) => i.status === 'completed').length,
      evaluated: e.filter((x) => x.current != null).length,
      met: e.filter((x) => x.state === 'met').length,
    };
  }
  const forIndicator = (key) => load().filter((i) => i.indicator === key && i.status !== 'completed');

  // ------------------------------------------------------------------ Page
  function render() {
    const el = $('#tab-interventions');
    const list = load();
    const c = counts();
    const shown = list.filter((i) => !filter.status || i.status === filter.status).sort((a, b) => new Date(b.start) - new Date(a.start));
    el.innerHTML = `
      <div class="head"><div><h1>Interventions</h1><p class="muted">Plan health promotion activities for the priority needs, assign who is responsible, and check at each reassessment whether the concern is improving.</p></div>
        <button class="btn primary" id="iv-new">${Insights.icon('plus', 16)} New intervention</button></div>
      ${Insights.cycleStrip(4)}
      ${Insights.demoBanner()}
      <div class="grid k4">
        <div class="card kpi"><div class="label">Interventions</div><div class="value">${c.total}</div><div class="fine">${c.planned} planned</div></div>
        <div class="card kpi"><div class="label">In progress</div><div class="value">${c.running}</div><div class="fine">being delivered now</div></div>
        <div class="card kpi"><div class="label">Completed</div><div class="value">${c.completed}</div><div class="fine">delivered in full</div></div>
        <div class="card kpi"><div class="label">Targets met</div><div class="value">${c.met}<small> / ${c.evaluated}</small></div><div class="fine">of those reassessed</div></div>
      </div>
      <div class="seg" role="group" aria-label="Filter by status">${[['', 'All'], ...Object.entries(STATUS).map(([k, v]) => [k, v[0]])]
        .map(([k, t]) => `<button class="${filter.status === k ? 'on' : ''}" data-st="${k}">${t} <span class="seg-n">${k ? list.filter((i) => i.status === k).length : list.length}</span></button>`)
        .join('')}</div>
      <div class="ivs">${shown.map(card).join('') || '<div class="card muted">No interventions with this status. Use Priority needs to start one.</div>'}</div>`;
    $('#iv-new').onclick = () => edit(null);
    el.querySelectorAll('[data-st]').forEach((b) => (b.onclick = () => ((filter.status = b.dataset.st), render())));
    el.querySelectorAll('[data-edit]').forEach((b) => (b.onclick = () => edit(list.find((i) => i.id === b.dataset.edit))));
    el.querySelectorAll('[data-del]').forEach((b) => (b.onclick = () => remove(list.find((i) => i.id === b.dataset.del))));
    el.querySelectorAll('[data-status]').forEach((s) => (s.onchange = () => ((list.find((i) => i.id === s.dataset.status).status = s.value), save(), render())));
    el.querySelectorAll('[data-ms]').forEach((c2) =>
      c2.addEventListener('change', () => {
        const [id, idx] = c2.dataset.ms.split(':');
        list.find((i) => i.id === id).milestones[Number(idx)].done = c2.checked;
        save();
        render();
      }),
    );
  }

  function card(iv) {
    const ind = IND[iv.indicator];
    const ev = evaluate(iv);
    const [vText, vCls] = VERDICT[ev.state];
    const done = iv.milestones.filter((m) => m.done).length;
    const pctDone = pct(done, iv.milestones.length);
    const rows = [];
    if (ev.baseline != null) rows.push({ label: `Baseline · ${Insights.periodLabel(iv.baselinePeriod)}`, value: ev.baseline, color: 'var(--faint)', display: `${Charts.num(ev.baseline, 1)}%` });
    if (ev.current != null) rows.push({ label: `Latest · ${ev.periodLabel}`, value: ev.current, color: Charts.STATUS_VAR[ev.state === 'none' ? 'bad' : ev.state === 'early' ? 'warn' : 'good'], display: `${Charts.num(ev.current, 1)}%` });
    if (ev.goal != null) rows.push({ label: 'Goal', value: ev.goal, color: 'var(--accent)', display: `${Charts.num(ev.goal, 1)}%` });
    return `<article class="card iv">
      <div class="iv-head">
        <div>
          <div class="q-meta"><span class="pill ${STATUS[iv.status][1]}">${STATUS[iv.status][0]}</span><span class="pill">${esc(ind.short)}</span></div>
          <h3>${esc(iv.title)}</h3>
          <p class="fine">${esc(facText(iv))} · ${fmtDate(iv.start)} to ${fmtDate(iv.end)}</p>
          <p class="iv-owner">${Insights.icon('users', 15)}<span><strong>${esc(iv.owner)}</strong>${iv.unit ? ` · ${esc(iv.unit)}` : ''}</span></p>
        </div>
        <div class="row-actions">
          <select class="status-sel" data-status="${iv.id}" aria-label="Status of ${esc(iv.title)}">${Object.entries(STATUS).map(([k, v]) => `<option value="${k}" ${k === iv.status ? 'selected' : ''}>${v[0]}</option>`).join('')}</select>
          <button class="btn small" data-edit="${iv.id}">Edit</button><button class="btn small danger" data-del="${iv.id}">Delete</button>
        </div>
      </div>
      <div class="iv-body">
        <div>
          <div class="iv-sub"><strong>Implementation</strong><span class="fine">${done} of ${iv.milestones.length} steps · ${pctDone}%</span></div>
          <div class="tile-bar plain"><i style="width:${pctDone}%"></i></div>
          <ul class="ms">${iv.milestones.map((m, i) => `<li><label class="check"><input type="checkbox" data-ms="${iv.id}:${i}" ${m.done ? 'checked' : ''}> <span class="${m.done ? 'done' : ''}">${esc(m.text)}</span></label></li>`).join('')}</ul>
          ${iv.notes ? `<p class="fine iv-notes">${esc(iv.notes)}</p>` : ''}
        </div>
        <div class="iv-eval">
          <div class="iv-sub"><strong>Result at reassessment</strong><span class="pill ${vCls}">${vText}</span></div>
          ${rows.length ? bars(rows, { max: 100 }) : '<p class="muted">No baseline available.</p>'}
          <p class="fine">${ev.current != null ? `${ev.achieved >= 0 ? 'Down' : 'Up'} ${Math.abs(ev.achieved)} pts since the baseline; the goal was ${iv.targetPts} pts down.` : `Goal: ${iv.targetPts} pts lower than the baseline. The next assessment will show the result.`}</p>
        </div>
      </div>
    </article>`;
  }

  // ------------------------------------------------------------------ Edit
  function nextMonday() {
    const d = new Date();
    d.setDate(d.getDate() + ((8 - d.getDay()) % 7 || 7));
    return d.toISOString().slice(0, 10);
  }
  function addMonths(iso, m) {
    const d = new Date(iso);
    d.setMonth(d.getMonth() + m);
    return d.toISOString().slice(0, 10);
  }

  // Open the form for a new (iv = null, optional `prefill`) or existing intervention.
  function edit(iv, prefill = {}) {
    const list = load();
    const isNew = !iv;
    const key = iv?.indicator || prefill.indicator || DEMO.INDICATORS[0].key;
    const sug = Insights.SUGGEST[key];
    const start = iv?.start || nextMonday();
    const v = iv || {
      title: prefill.indicator ? `Programme to reduce ${IND[key].short.toLowerCase()}` : '',
      indicator: key, faculties: prefill.faculties || [], owner: '', unit: sug.unit, start, end: addMonths(start, 6), status: 'planned', targetPts: 5,
      baselinePeriod: Insights.LATEST,
      milestones: [`Agree plan and budget with ${sug.unit}`, sug.actions[0], 'Review progress at the midpoint', 'Reassess at the next periodic assessment'].map((text) => ({ text, done: false })),
      notes: '',
    };
    openModal(
      `<h2>${isNew ? 'Plan an intervention' : 'Edit intervention'}</h2>
      <label>Title<input id="iv-title" required maxlength="120" value="${esc(v.title)}" placeholder="e.g. Hostel breakfast clubs"></label>
      <div class="form-grid">
        <label>Health need<select id="iv-ind">${DEMO.INDICATORS.map((i) => `<option value="${i.key}" ${i.key === v.indicator ? 'selected' : ''}>${esc(i.label)}</option>`).join('')}</select></label>
        <label>Baseline assessment<select id="iv-base">${PERIODS.map((p) => `<option value="${p.id}" ${p.id === v.baselinePeriod ? 'selected' : ''}>${esc(p.label)}</option>`).join('')}</select></label>
        <label>Target reduction (percentage points)<input id="iv-target" type="number" min="1" max="40" step="1" required value="${v.targetPts}"></label>
      </div>
      <div><span class="field-label">Faculties (leave all unticked for the whole university)</span>
        <div class="faculty-list">${FACULTIES.map((f) => `<label class="check"><input type="checkbox" name="iv-fac" value="${esc(f)}" ${v.faculties.includes(f) ? 'checked' : ''}> ${esc(shortFaculty(f))}</label>`).join('')}</div></div>
      <div class="form-grid">
        <label>Responsible person<input id="iv-owner" required maxlength="80" value="${esc(v.owner)}" placeholder="e.g. Dr. N. Perera"></label>
        <label>Unit or department<input id="iv-unit" maxlength="80" value="${esc(v.unit)}"></label>
        <label>Status<select id="iv-status">${Object.entries(STATUS).map(([k, s]) => `<option value="${k}" ${k === v.status ? 'selected' : ''}>${s[0]}</option>`).join('')}</select></label>
        <label>Start<input id="iv-start" type="date" required value="${esc(v.start)}"></label>
        <label>End<input id="iv-end" type="date" required value="${esc(v.end)}"></label>
      </div>
      <label>Steps, one per line<textarea id="iv-ms" rows="5">${esc(v.milestones.map((m) => m.text).join('\n'))}</textarea></label>
      <label>Notes<textarea id="iv-notes" rows="2" maxlength="500">${esc(v.notes)}</textarea></label>
      <p class="fine">The baseline and the result come from the assessment data for the chosen faculties, so they cannot be typed in.</p>
      <div class="modal-actions"><button class="btn" value="cancel" formnovalidate>Cancel</button><button class="btn primary" value="ok">${isNew ? 'Save plan' : 'Save changes'}</button></div>`,
      () => {
        const title = $('#iv-title').value.trim();
        const owner = $('#iv-owner').value.trim();
        if (!title || !owner) return toast('Add a title and a responsible person.');
        if ($('#iv-end').value < $('#iv-start').value) return toast('The end date is before the start date.');
        const old = new Map((iv?.milestones || []).map((m) => [m.text, m.done]));
        const rec = {
          id: iv?.id || `iv-${Date.now().toString(36)}`,
          title, owner, unit: $('#iv-unit').value.trim(), indicator: $('#iv-ind').value, baselinePeriod: $('#iv-base').value,
          targetPts: Math.max(1, Number($('#iv-target').value) || 1), status: $('#iv-status').value, start: $('#iv-start').value, end: $('#iv-end').value,
          faculties: [...document.querySelectorAll('[name="iv-fac"]:checked')].map((c) => c.value),
          milestones: $('#iv-ms').value.split('\n').map((t) => t.trim()).filter(Boolean).map((text) => ({ text, done: old.get(text) || false })),
          notes: $('#iv-notes').value.trim(),
        };
        if (isNew) list.unshift(rec);
        else Object.assign(iv, rec);
        save();
        toast(isNew ? 'Intervention planned.' : 'Changes saved.');
        openTab('interventions');
      },
    );
  }

  function remove(iv) {
    openModal(
      `<h2>Delete this intervention?</h2><p>“${esc(iv.title)}” will be removed from the plan. This cannot be undone.</p>
      <div class="modal-actions"><button class="btn" value="cancel">Keep it</button><button class="btn danger" value="ok">Delete</button></div>`,
      () => {
        memory = load().filter((i) => i.id !== iv.id);
        save();
        toast('Intervention deleted.');
        render();
      },
    );
  }

  renderers.interventions = render;
  return { counts, forIndicator, plan: (prefill) => edit(null, prefill) };
})();
