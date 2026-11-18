// Health insights (prevalence, trends, faculty comparison, risk profile,
// participation) and Priority health needs. Both read the sample data in
// demo-data.js and draw with charts.js.
'use strict';

const Insights = (() => {
  const { PERIODS, INDICATORS, IND } = DEMO;
  const LATEST = PERIODS[PERIODS.length - 1].id;
  const PART_TARGET = 60; // participation the university aims for, %

  // Filters shared by Insights and Priority needs.
  const F = { period: LATEST, faculty: '', year: '', sex: '' };
  const ui = { view: 'prevalence', dim: 'faculty', ind: 'high_stress', dist: 'nutrition', trend: new Set(['low_fruit_veg', 'inactive', 'high_stress']) };

  const periodLabel = (id) => PERIODS.find((p) => p.id === id)?.label || '';
  const prevPeriod = (id) => PERIODS[PERIODS.findIndex((p) => p.id === id) - 1]?.id;
  const colorOf = (key) => Charts.SERIES[INDICATORS.findIndex((i) => i.key === key) % Charts.SERIES.length];
  const icon = (id, size = 16) => `<svg width="${size}" height="${size}"><use href="#i-${id}"/></svg>`;
  const strip = (flt, ...drop) => Object.fromEntries(Object.entries(flt).filter(([k]) => !drop.includes(k)));

  const OPTIONS = {
    period: PERIODS.map((p) => [p.id, p.label]).reverse(),
    faculty: [['', 'All faculties'], ...FACULTIES.map((f) => [f, shortFaculty(f)])],
    year: [['', 'All years'], ['1', 'Year 1'], ['2', 'Year 2'], ['3', 'Year 3'], ['4', 'Year 4']],
    sex: [['', 'All students'], ['F', 'Female'], ['M', 'Male']],
  };
  const FIELD_LABEL = { period: 'Assessment period', faculty: 'Faculty', year: 'Academic year', sex: 'Student group' };

  function filterBar(fields) {
    return `<div class="card filters">${fields
      .map((k) => `<label>${FIELD_LABEL[k]}<select data-f="${k}">${OPTIONS[k].map(([v, t]) => `<option value="${esc(v)}" ${F[k] === v ? 'selected' : ''}>${esc(t)}</option>`).join('')}</select></label>`)
      .join('')}</div>`;
  }
  function bindFilters(root, rerender) {
    root.querySelectorAll('[data-f]').forEach((s) => (s.onchange = () => ((F[s.dataset.f] = s.value), rerender())));
  }

  const demoBanner = () =>
    `<div class="demo-note">${icon('flask', 16)}<span><strong>Sample data.</strong> These screens show generated example figures so the design can be reviewed. They are not student results.</span></div>`;

  const scopeText = (...skip) =>
    [!skip.includes('period') && periodLabel(F.period), F.faculty ? shortFaculty(F.faculty) : !skip.includes('faculty') && 'All faculties', F.year ? `Year ${F.year}` : !skip.includes('year') && 'All years', F.sex === 'F' ? 'Female' : F.sex === 'M' ? 'Male' : !skip.includes('sex') && 'All students']
      .filter(Boolean)
      .join(' · ');

  const tooSmall = (n) => `<div class="notice">Only ${n} ${n === 1 ? 'student' : 'students'} in this selection. Results appear once at least ${DEMO.MIN_GROUP} students are included, so that no one can be identified. Widen the filters.</div>`;

  // ---------------------------------------------------------------- Cycle strip
  function cycleStrip(active) {
    const cur = DEMO.summarize({ period: LATEST });
    const high = computeNeeds({ period: LATEST })?.filter((n) => n.level === 'High').length ?? 0;
    const c = Interventions.counts();
    const steps = [
      ['insights', 'Data collection', `${cur.n.toLocaleString('en-GB')} responses`],
      ['insights', 'Analysis', `${INDICATORS.length} indicators`],
      ['priority', 'Priority needs', `${high} high priority`],
      ['interventions', 'Planning', `${c.planned} planned`],
      ['interventions', 'Implementation', `${c.running} running`],
      ['interventions', 'Reassessment', `${c.evaluated} evaluated`],
    ];
    return `<ol class="cycle" aria-label="Health promotion cycle">${steps
      .map(([tab, name, sub], i) => `<li class="${i === active ? 'active' : i < active ? 'done' : ''}"><button type="button" data-goto="${tab}"><span class="cy-n">${i + 1}</span><b>${name}</b><small>${esc(sub)}</small></button></li>`)
      .join('')}</ol>`;
  }

  // ---------------------------------------------------------------- Insights page
  function renderInsights() {
    const el = $('#tab-insights');
    const flt = { ...F };
    const cur = DEMO.summarize(flt);
    const pp = prevPeriod(F.period);
    const prev = pp ? DEMO.summarize({ ...flt, period: pp }) : null;
    const worsening = INDICATORS.filter((i) => DEMO.trend(i.key, strip(flt, 'period'), F.period).dir === 'worse').length;
    const top = cur.suppressed ? null : INDICATORS.map((i) => ({ i, v: cur.rates[i.key] })).sort((a, b) => b.v - a.v)[0];

    const VIEWS = [['prevalence', 'Prevalence'], ['trends', 'Trends'], ['groups', 'Compare groups'], ['risk', 'Risk profile'], ['participation', 'Participation']];
    const fields = { prevalence: ['period', 'faculty', 'year', 'sex'], trends: ['faculty', 'year', 'sex'], groups: ['period', 'faculty', 'year', 'sex'].filter((k) => k !== ui.dim), risk: ['period', 'faculty', 'year', 'sex'], participation: ['period', 'sex'] }[ui.view];

    el.innerHTML = `
      <div class="head"><div><h1>Health insights</h1><p class="muted">What the university's students report about their health, how it is changing and where it differs. Groups under five students are never shown.</p></div></div>
      ${cycleStrip(1)}
      ${demoBanner()}
      <div class="grid k4">
        <div class="card kpi"><div class="label">Completed assessments</div><div class="value">${cur.n.toLocaleString('en-GB')}</div><div class="fine">of ${cur.eligible.toLocaleString('en-GB')} registered · ${esc(periodLabel(F.period))}</div></div>
        <div class="card kpi"><div class="label">Participation</div><div class="value">${cur.participation ?? '–'}%</div><div class="fine">${prev && !prev.suppressed ? participationDelta(cur, prev) : 'first period on record'}</div></div>
        <div class="card kpi"><div class="label">Indicators getting worse</div><div class="value" style="color:${worsening ? 'var(--bad)' : 'var(--good)'}">${worsening}<small> / ${INDICATORS.length}</small></div><div class="fine">over the periods on record</div></div>
        <div class="card kpi"><div class="label">Most common concern</div><div class="value sm">${top ? esc(top.i.short) : '–'}</div><div class="fine">${top ? `${Charts.num(top.v, 1)}% of students` : 'not enough students'}</div></div>
      </div>
      <div class="seg" role="tablist" aria-label="Insight views">${VIEWS.map(([k, t]) => `<button role="tab" aria-selected="${ui.view === k}" class="${ui.view === k ? 'on' : ''}" data-view="${k}">${t}</button>`).join('')}</div>
      ${filterBar(fields)}
      <div id="ins-body" class="ins-body"></div>`;
    el.querySelectorAll('[data-view]').forEach((b) => (b.onclick = () => ((ui.view = b.dataset.view), renderInsights())));
    bindFilters(el, renderInsights);

    const body = { prevalence: prevalenceView, trends: trendsView, groups: groupsView, risk: riskView, participation: participationView }[ui.view];
    $('#ins-body').innerHTML = body({ ...flt });
    bindBody(el);
  }

  function participationDelta(cur, prev) {
    const d = Math.round((cur.participation - prev.participation) * 10) / 10;
    return Math.abs(d) < 0.5 ? '<span class="chip flat">● steady</span> vs last period' : `<span class="chip ${d > 0 ? 'good' : 'bad'}"><span aria-hidden="true">${d > 0 ? '▲' : '▼'}</span> ${Math.abs(d)} pts</span> vs last period`;
  }

  function bindBody(root) {
    root.querySelectorAll('[data-ind-toggle]').forEach((b) =>
      b.addEventListener('click', () => {
        const k = b.dataset.indToggle;
        if (ui.trend.has(k)) ui.trend.size > 1 && ui.trend.delete(k);
        else ui.trend.add(k);
        renderInsights();
      }),
    );
    root.querySelectorAll('[data-dim]').forEach((b) => (b.onclick = () => ((ui.dim = b.dataset.dim), renderInsights())));
    const bind = (id, key) => {
      const s = root.querySelector(id);
      if (s) s.onchange = () => ((ui[key] = s.value), renderInsights());
    };
    bind('#sel-ind', 'ind');
    bind('#sel-dist', 'dist');
  }

  // 1. Prevalence --------------------------------------------------------------
  function prevalenceView(flt) {
    const cur = DEMO.summarize(flt);
    if (cur.suppressed) return tooSmall(cur.n);
    const pp = prevPeriod(flt.period);
    const prev = pp ? DEMO.summarize({ ...flt, period: pp }) : null;
    const rows = INDICATORS.map((i) => ({ i, v: cur.rates[i.key], d: prev && !prev.suppressed ? cur.rates[i.key] - prev.rates[i.key] : null })).sort((a, b) => b.v - a.v);
    const hot = flt.faculty
      ? ''
      : `<div class="card"><h3>Where each concern is highest</h3><p class="fine">The faculty with the highest share for each indicator, compared with the university as a whole. ${esc(scopeText('faculty', 'period'))}.</p>
        <div class="table-wrap"><table><thead><tr><th>Indicator</th><th>Highest in</th><th class="num">Faculty</th><th class="num">University</th></tr></thead><tbody>${INDICATORS.map((i) => {
          const best = DEMO.groupBy('faculty', flt).filter((g) => !g.suppressed).sort((a, b) => b.rates[i.key] - a.rates[i.key])[0];
          return `<tr><td>${esc(i.short)}</td><td>${best ? esc(best.label) : '–'}</td><td class="num" style="${best ? Charts.heat(best.rates[i.key], i.target) : ''}">${best ? `${Charts.num(best.rates[i.key], 1)}%` : '–'}</td><td class="num">${Charts.num(cur.rates[i.key], 1)}%</td></tr>`;
        }).join('')}</tbody></table></div></div>`;
    return `<div class="card"><h3>How common is each health concern?</h3>
      <p class="fine">Share of students affected, ${esc(scopeText('period'))}, in ${esc(periodLabel(flt.period))}. The tick marks the university target; the chip shows the change since the previous period.</p>
      <div class="prev">${rows
        .map(
          ({ i, v, d }) => `<div class="prev-row"><div class="prev-label"><strong>${esc(i.label)}</strong><span>${esc(i.note)}</span></div>
          <div class="cmp-track"><i style="width:${v}%;background:${Charts.STATUS_VAR[Charts.status(v, i.target)]}"></i><b class="mark tgt" style="left:${i.target}%" title="Target ${i.target}%"></b></div>
          <div class="prev-val"><strong>${Charts.num(v, 1)}%</strong>${Charts.deltaChip(d)}</div></div>`,
        )
        .join('')}</div>
      <div class="legend" style="margin-top:14px"><span><i style="background:var(--good)"></i>At or under target</span><span><i style="background:var(--warn)"></i>Up to 35% over target</span><span><i style="background:var(--bad)"></i>Well over target</span></div></div>
      ${hot}`;
  }

  // 2. Trends ------------------------------------------------------------------
  function trendsView(flt) {
    const base = strip(flt, 'period');
    const labels = PERIODS.map((p) => p.short);
    const picked = INDICATORS.filter((i) => ui.trend.has(i.key));
    const series = picked.map((i) => ({ name: i.short, color: colorOf(i.key), values: DEMO.series(i.key, base) }));
    const single = picked.length === 1 ? picked[0] : null;
    const chips = INDICATORS.map((i) => `<button type="button" class="ind-chip" aria-pressed="${ui.trend.has(i.key)}" data-ind-toggle="${i.key}"><i style="background:${colorOf(i.key)}"></i>${esc(i.short)}</button>`).join('');
    const table = INDICATORS.map((i) => {
      const t = DEMO.trend(i.key, base);
      const delta = t.first != null && t.last != null ? t.last - t.first : null;
      return `<tr><td><strong>${esc(i.label)}</strong></td><td class="num">${Charts.num(t.first, 1)}%</td><td class="num">${Charts.num(t.last, 1)}%</td>
        <td class="num">${delta == null ? '–' : `${delta > 0 ? '+' : ''}${delta.toFixed(1)}`}</td><td>${Charts.spark(t.values, colorOf(i.key))}</td>
        <td>${Charts.trendChip(t.dir, t.dir === 'stable' ? 'No clear change' : `${t.dir === 'worse' ? 'Worsening' : 'Improving'} · ${Math.abs(t.slope)} pts per period`)}</td></tr>`;
    }).join('');
    return `<div class="card"><h3>Change across assessment periods</h3>
      <p class="fine">Share of students affected at each six-monthly assessment${scopeText('period') ? `, ${esc(scopeText('period'))}` : ''}. Pick up to all eight indicators; pick one to see its target.</p>
      <div class="ind-chips">${chips}</div>
      ${Charts.line({ labels, series, target: single?.target, targetLabel: single ? `Target ${single.target}%` : '', aria: `Trend of ${picked.map((i) => i.short).join(', ')} across ${labels.length} assessment periods` })}</div>
      <div class="card"><h3>Is it improving, worsening or unchanged?</h3>
      <p class="fine">A concern is called worsening or improving when it moves by at least one percentage point per period on average, across all periods on record.</p>
      <div class="table-wrap"><table><thead><tr><th>Indicator</th><th class="num">${esc(PERIODS[0].short)}</th><th class="num">${esc(PERIODS.at(-1).short)}</th><th class="num">Change</th><th>Trend</th><th>Direction</th></tr></thead><tbody>${table}</tbody></table></div></div>`;
  }

  // 3. Compare groups ----------------------------------------------------------
  function groupsView(flt) {
    const dims = [['faculty', 'Faculties'], ['year', 'Academic years'], ['sex', 'Student groups']];
    const base = strip(flt, ui.dim);
    const all = DEMO.summarize(base);
    const rows = DEMO.groupBy(ui.dim, base);
    const ind = IND[ui.ind];
    const sorted = rows.slice().sort((a, b) => (a.suppressed ? 1 : 0) - (b.suppressed ? 1 : 0) || (b.rates?.[ind.key] ?? 0) - (a.rates?.[ind.key] ?? 0));
    const dimName = { faculty: 'faculty', year: 'academic year', sex: 'student group' }[ui.dim];
    return `<div class="card"><div class="card-head"><h3>Compare ${dimName === 'faculty' ? 'faculties' : dimName === 'academic year' ? 'academic years' : 'student groups'}</h3>
        <div class="seg small" role="group" aria-label="Compare by">${dims.map(([k, t]) => `<button class="${ui.dim === k ? 'on' : ''}" data-dim="${k}">${t}</button>`).join('')}</div></div>
      <label class="inline-sel">Health indicator<select id="sel-ind">${INDICATORS.map((i) => `<option value="${i.key}" ${ui.ind === i.key ? 'selected' : ''}>${esc(i.label)}</option>`).join('')}</select></label>
      <p class="fine" style="margin:10px 0 14px">${esc(ind.label)}: ${esc(ind.note)}. ${esc(scopeText(ui.dim))}. The dark tick is the university average (${Charts.num(all.rates[ind.key], 1)}%); the lighter tick is the ${ind.target}% target.</p>
      ${Charts.compareBars(sorted.map((g) => ({ label: g.label, value: g.rates?.[ind.key], suppressed: g.suppressed, right: g.suppressed ? '' : `${Charts.num(g.rates[ind.key], 1)}% <small class="muted">n=${g.n}</small>` })), { target: ind.target, average: all.suppressed ? null : all.rates[ind.key] })}</div>
      <div class="card"><h3>All indicators at a glance</h3><p class="fine">Colour shows distance from the target for each indicator: green at or under target, amber up to 35% over, red well over.</p>
      <div class="table-wrap"><table class="compare"><thead><tr><th>${dimName[0].toUpperCase() + dimName.slice(1)}</th><th class="num">Students</th>${INDICATORS.map((i) => `<th class="num">${esc(i.short)}</th>`).join('')}</tr></thead><tbody>
        ${rows.map((g) => `<tr><td>${esc(g.label)}</td>${g.suppressed ? `<td class="num fine" colspan="${INDICATORS.length + 1}">${g.n} (under ${DEMO.MIN_GROUP}, hidden)</td>` : `<td class="num">${g.n}</td>${INDICATORS.map((i) => `<td class="num heat" style="${Charts.heat(g.rates[i.key], i.target)}">${Math.round(g.rates[i.key])}</td>`).join('')}`}</tr>`).join('')}
        ${all.suppressed ? '' : `<tr class="total"><td><strong>All</strong></td><td class="num">${all.n}</td>${INDICATORS.map((i) => `<td class="num heat" style="${Charts.heat(all.rates[i.key], i.target)}">${Math.round(all.rates[i.key])}</td>`).join('')}</tr>`}
      </tbody></table></div></div>`;
  }

  // 4. Risk profile ------------------------------------------------------------
  function riskView(flt) {
    const cur = DEMO.summarize(flt);
    const d = DEMO.DISTRIBUTIONS[ui.dist];
    const select = `<label class="inline-sel">Show<select id="sel-dist">${Object.entries(DEMO.DISTRIBUTIONS).map(([k, v]) => `<option value="${k}" ${ui.dist === k ? 'selected' : ''}>${esc(v.label)}</option>`).join('')}</select></label>`;
    if (cur.suppressed) return `<div class="card">${select}</div>${tooSmall(cur.n)}`;
    const parts = DEMO.distribution(ui.dist, cur.rates);
    const rows = DEMO.groupBy('faculty', strip(flt, 'faculty')).map((g) => ({ label: g.label, suppressed: g.suppressed, right: g.suppressed ? '' : String(g.n), parts: g.suppressed ? [] : DEMO.distribution(ui.dist, g.rates) }));
    return `<div class="card"><div class="card-head"><h3>${esc(d.label)}</h3>${select}</div>
      <div class="risk-grid">
        <div class="donut-box">${Charts.donut({ parts, centre: { big: cur.n.toLocaleString('en-GB'), small: 'students' }, aria: `${d.label}: ${parts.map((p) => `${p.label} ${Charts.num(p.value, 1)}%`).join(', ')}` })}</div>
        <ul class="dist-list">${parts.map((p) => `<li><i style="background:${p.color}"></i><span>${esc(p.label)}</span><b>${Charts.num(p.value, 1)}%</b></li>`).join('')}</ul>
      </div>
      <p class="fine">${esc(scopeText())}. Shares are rounded and add up to 100%.</p></div>
      <div class="card"><h3>${esc(d.label)} by faculty</h3><p class="fine">Each bar is one faculty (all years and the selected student group). The number on the right is how many students.</p>
      ${Charts.legend(parts)}${Charts.stackRows(rows)}</div>`;
  }

  // 5. Participation -----------------------------------------------------------
  function participationView(flt) {
    const rows = DEMO.groupBy('faculty', flt);
    const sorted = rows.slice().sort((a, b) => (b.participation ?? 0) - (a.participation ?? 0));
    const low = rows.filter((g) => g.eligible && g.participation < 55).sort((a, b) => a.participation - b.participation);
    const yearRows = DEMO.groupBy('year', flt);
    const lowYear = yearRows.filter((g) => g.eligible && g.participation < 55);
    const labels = PERIODS.map((p) => p.short);
    const sexOnly = { sex: flt.sex };
    const series = [
      { name: 'All students', color: '#18181b', width: 3.4, values: PERIODS.map((p) => DEMO.summarize({ ...sexOnly, period: p.id }).participation) },
      ...[1, 2, 3, 4].map((y, i) => ({ name: `Year ${y}`, color: Charts.SERIES[i], values: PERIODS.map((p) => DEMO.summarize({ ...sexOnly, year: String(y), period: p.id }).participation) })),
    ];
    series[0].color = 'var(--text)';
    return `<div class="card"><h3>Assessment completion by faculty</h3>
      <p class="fine">Share of registered students who completed the ${esc(periodLabel(flt.period))} assessment. The tick marks the ${PART_TARGET}% participation goal.</p>
      ${Charts.compareBars(sorted.map((g) => ({ label: g.label, value: g.participation, right: `${Charts.num(g.participation, 1)}% <small class="muted">${g.n}/${g.eligible}</small>` })), { target: PART_TARGET, higherIsBetter: true })}</div>
      <div class="grid k2">
        <div class="card"><h3>Participation over time</h3><p class="fine">Completion rate at each assessment, overall and by academic year.</p>
          ${Charts.line({ labels, series, target: PART_TARGET, targetLabel: `Goal ${PART_TARGET}%`, aria: 'Participation rate across assessment periods, overall and by academic year' })}
          ${Charts.legend([{ label: 'All students', color: 'var(--text)' }, ...[1, 2, 3, 4].map((y, i) => ({ label: `Year ${y}`, color: Charts.SERIES[i] }))])}</div>
        <div class="card"><h3>Needs outreach</h3><p class="fine">Groups under 55% in ${esc(periodLabel(flt.period))}.</p>
          ${low.length || lowYear.length
            ? `<div class="list">${[...low.map((g) => ({ ...g, kind: 'Faculty' })), ...lowYear.map((g) => ({ ...g, kind: 'Academic year' }))]
                .map((g) => `<div class="li static"><span class="ini c0">${icon('users', 18)}</span><span class="li-main"><strong>${esc(g.label)}</strong><span>${g.kind} · ${g.n} of ${g.eligible} completed</span></span><span class="pill bad">${Charts.num(g.participation, 0)}%</span></div>`)
                .join('')}</div><p class="fine" style="margin-top:12px">Ideas: ask the faculty office to share the reminder, run a short in-class prompt, or extend the window by a few days for these groups in Schedule.</p>`
            : '<div class="empty">Every group is at or above 55%.</div>'}</div>
      </div>
      <div class="card"><h3>Completion rate by faculty and period</h3><p class="fine">Green meets the ${PART_TARGET}% goal, amber is within 20% of it, red is below.</p>
      <div class="table-wrap"><table class="compare"><thead><tr><th>Faculty</th>${PERIODS.map((p) => `<th class="num">${esc(p.short)}</th>`).join('')}</tr></thead><tbody>
      ${FACULTIES.map((f) => `<tr><td>${esc(shortFaculty(f))}</td>${PERIODS.map((p) => {
        const s = DEMO.summarize({ ...sexOnly, faculty: f, period: p.id });
        return `<td class="num heat" style="${Charts.heat(s.participation, PART_TARGET, true)}">${s.participation == null ? '–' : `${Math.round(s.participation)}%`}</td>`;
      }).join('')}</tr>`).join('')}</tbody></table></div></div>`;
  }

  // ---------------------------------------------------------------- Priority needs
  const SUGGEST = {
    low_fruit_veg: { unit: 'Nutrition Unit', why: 'Fruit and vegetable intake protects against diabetes and heart disease, and low intake is the most common concern.', actions: ['Nutrition awareness programme built on the Healthy Plate and the VitalU Learn articles', 'Improve access to affordable healthy meals: fruit and vegetable options and price caps in canteens', 'Student-led "Eat the rainbow" challenges in hostels with weekly fruit stalls'] },
    inactive: { unit: 'Sports Unit', why: 'Fewer than 150 active minutes a week raises risk of overweight, low mood and poor sleep.', actions: ['Timetabled activity breaks and open-access sessions at lunchtime', 'Free or low-cost use of sports facilities, with walking and cycling routes marked on campus', 'Faculty step-count challenges using the VitalU activity tools'] },
    high_stress: { unit: 'Counselling Centre', why: 'High stress is rising fastest and tends to cluster around demanding programmes and final years.', actions: ['Targeted stress management and resilience workshops for the faculties and years most affected', 'Peer-support network and a clear route to the counselling centre, including the anonymous consultation service', 'Work with faculties to spread assessment deadlines and protect revision breaks'] },
    short_sleep: { unit: 'Medical Centre', why: 'Under 7 hours of sleep affects concentration, mood and appetite regulation.', actions: ['Sleep hygiene awareness campaign before examination periods', 'Quiet hours in hostels and late-night screen-time nudges in the app', 'Review early-morning and late-evening lecture slots with the faculties'] },
    skip_breakfast: { unit: 'Nutrition Unit', why: 'Skipping breakfast is linked with poorer concentration and snacking later in the day.', actions: ['Affordable breakfast options available before 8 am in canteens and hostels', 'Breakfast clubs in hostels and early-lecture reminders in the app', 'Awareness posts that show quick low-cost breakfasts'] },
    overweight_obese: { unit: 'Medical Centre', why: 'Overweight and obesity increase long-term risk of diabetes, hypertension and heart disease.', actions: ['Offer BMI and waist checks at the medical centre with brief lifestyle advice', 'Healthier default options and clear portion guidance in canteens', 'Group programmes that combine nutrition and activity, with follow-up at the next assessment'] },
    central_obesity: { unit: 'Medical Centre', why: 'A high waist-to-hip ratio is an early warning sign for metabolic disease even at a normal BMI.', actions: ['Waist-to-hip screening days with referral for those above the cut-off', 'Combine with activity and nutrition programmes for the affected groups', 'Share simple self-measurement guidance in the Learn section'] },
    low_mood: { unit: 'Counselling Centre', why: 'A positive low-mood screen signals students who may benefit from early support.', actions: ['Mental health awareness weeks and stigma-reduction sessions', 'Ensure follow-up pathways are quick for students who screen positive', 'Train hostel wardens and student leaders to recognise and refer'] },
  };

  // Scoring: burden (up to 50), momentum (up to 30), distance from target (up to 20).
  function computeNeeds(flt) {
    const cur = DEMO.summarize(flt);
    if (cur.suppressed) return null;
    const pp = prevPeriod(flt.period);
    const prev = pp ? DEMO.summarize({ ...flt, period: pp }) : null;
    const fac = flt.faculty ? [] : DEMO.groupBy('faculty', flt).filter((g) => !g.suppressed);
    return INDICATORS.map((i) => {
      const p = cur.rates[i.key];
      const t = DEMO.trend(i.key, strip(flt, 'period'), flt.period);
      const burden = Math.min(1, p / 80) * 50;
      const momentum = Math.min(1, Math.max(0, t.slope / 3)) * 30;
      const gap = Math.min(1, Math.max(0, (p - i.target) / 30)) * 20;
      const score = Math.round(burden + momentum + gap);
      const delta = prev && !prev.suppressed ? p - prev.rates[i.key] : null;
      const hot = fac.filter((g) => g.rates[i.key] >= p + 4).sort((a, b) => b.rates[i.key] - a.rates[i.key]).slice(0, 3);
      return { i, p, t, score, delta, hot, level: score >= 60 ? 'High' : score >= 40 ? 'Medium' : 'Watch', emerging: t.slope >= 2 || (delta != null && delta >= 3) };
    }).sort((a, b) => b.score - a.score);
  }

  function renderPriority() {
    const el = $('#tab-priority');
    const flt = { ...F, sex: '' };
    const needs = computeNeeds(flt);
    el.innerHTML = `
      <div class="head"><div><h1>Priority health needs</h1><p class="muted">The concerns that most call for university-level action, ranked from the assessment results, with suggested ways to respond.</p></div></div>
      ${cycleStrip(2)}
      ${demoBanner()}
      ${filterBar(['period', 'faculty', 'year'])}
      ${needs ? needsList(needs, flt) : tooSmall(DEMO.summarize(flt).n)}`;
    bindFilters(el, renderPriority);
    el.querySelectorAll('[data-plan]').forEach((b) =>
      b.addEventListener('click', () => {
        const n = needs.find((x) => x.i.key === b.dataset.plan);
        Interventions.plan({ indicator: n.i.key, faculties: flt.faculty ? [flt.faculty] : n.hot.map((g) => FACULTIES.find((f) => shortFaculty(f) === g.label)).filter(Boolean) });
      }),
    );
    el.querySelectorAll('[data-trend]').forEach((b) =>
      b.addEventListener('click', () => {
        ui.trend = new Set([b.dataset.trend]);
        ui.view = 'trends';
        openTab('insights');
      }),
    );
  }

  function needsList(needs, flt) {
    const lvl = { High: 'bad', Medium: 'warn', Watch: '' };
    return `<div class="card how"><strong>How the ranking works.</strong> Each concern scores out of 100 from how many students it affects (up to 50), how fast it is rising (up to 30) and how far it is above its target (up to 20). Scores of 60+ are high priority, 40+ medium. <span class="fine">${esc(scopeText('sex'))}.</span></div>
      <div class="needs">${needs
        .map((n, idx) => {
          const s = SUGGEST[n.i.key];
          const linked = Interventions.forIndicator(n.i.key);
          return `<article class="card need ${n.level.toLowerCase()}">
          <div class="need-rank" aria-label="Rank ${idx + 1}">${idx + 1}</div>
          <div class="need-main">
            <div class="need-head"><h3>${esc(n.i.label)}</h3><span class="pill ${lvl[n.level]}">${n.level}${n.level === 'Watch' ? '' : ' priority'}</span>${n.emerging ? '<span class="pill info">Emerging</span>' : ''}</div>
            <p class="fine">${esc(n.i.note)}. ${esc(s.why)}</p>
            <div class="need-stats">
              <div><b>${Charts.num(n.p, 1)}%</b><span>of students</span></div>
              <div><b>${n.t.slope > 0 ? '+' : ''}${n.t.slope}</b><span>pts per period</span></div>
              <div><b style="color:${n.p > n.i.target ? 'var(--bad)' : 'var(--good)'}">${n.p > n.i.target ? '+' : ''}${Charts.num(n.p - n.i.target, 1)}</b><span>vs ${n.i.target}% target</span></div>
              <div><b>${n.score}</b><span>priority score</span></div>
            </div>
            ${n.hot.length ? `<p class="need-hot"><strong>Hot spots</strong> ${n.hot.map((g) => `<span class="pill bad-soft">${esc(g.label)} ${Math.round(g.rates[n.i.key])}%</span>`).join(' ')}</p>` : ''}
            <details ${n.level === 'High' ? 'open' : ''}><summary>Suggested interventions · lead: ${esc(s.unit)}</summary><ul class="actions">${s.actions.map((a) => `<li>${esc(a)}</li>`).join('')}</ul></details>
            <div class="row-actions" style="justify-content:start;margin-top:12px">
              <button class="btn small primary" data-plan="${n.i.key}">${icon('plus', 14)} Plan intervention</button>
              <button class="btn small" data-trend="${n.i.key}">${icon('chart', 14)} View trend</button>
              ${linked.length ? `<button class="btn small ghost" data-goto="interventions">${linked.length} linked ${linked.length === 1 ? 'intervention' : 'interventions'}</button>` : ''}
            </div>
          </div>
          ${Charts.spark(n.t.values, Charts.STATUS_VAR[Charts.status(n.p, n.i.target)]).replace('class="spark"', 'class="spark need-spark"')}
        </article>`;
        })
        .join('')}</div>`;
  }

  renderers.insights = renderInsights;
  renderers.priority = renderPriority;
  return { F, computeNeeds, cycleStrip, demoBanner, filterBar, periodLabel, icon, SUGGEST, LATEST };
})();
