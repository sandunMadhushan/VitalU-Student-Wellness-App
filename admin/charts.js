// Small dependency-free SVG/HTML chart helpers for the decision-support views.
// Colours that depend on the theme come from CSS variables (set through
// classes in styles.css); series colours are fixed hex values.
'use strict';

const Charts = (() => {
  // Categorical series colours that read on both the light and dark themes.
  const SERIES = ['#1a6fe0', '#7b5cc4', '#d9a21b', '#2a9d8f', '#e07a2f', '#c2185b', '#5fae6e', '#8b8699'];

  const num = (v, d = 0) => (v == null ? '–' : Number(v).toFixed(d).replace(/\.0$/, ''));

  // Traffic-light colour for a "higher is worse" value measured against its target.
  function status(value, target) {
    if (value == null) return 'none';
    if (value <= target) return 'good';
    if (value <= target * 1.35) return 'warn';
    return 'bad';
  }
  // Same, for values where higher is better (for example participation).
  function statusHigh(value, target) {
    if (value == null) return 'none';
    if (value >= target) return 'good';
    if (value >= target * 0.8) return 'warn';
    return 'bad';
  }
  const STATUS_VAR = { good: 'var(--good)', warn: 'var(--warn)', bad: 'var(--bad)', none: 'var(--faint)' };

  // Direction chip. `dir` is 'worse', 'better' or 'stable' (higher is worse).
  function trendChip(dir, text) {
    const map = {
      worse: ['bad', '▲', 'Worsening'],
      better: ['good', '▼', 'Improving'],
      stable: ['flat', '●', 'No clear change'],
    };
    const [cls, mark, label] = map[dir] || map.stable;
    return `<span class="chip ${cls}"><span aria-hidden="true">${mark}</span> ${esc(text ?? label)}</span>`;
  }

  // Change versus the previous period as a chip, e.g. "▲ 1.9 pts".
  function deltaChip(delta) {
    if (delta == null) return '';
    const d = Math.round(delta * 10) / 10;
    if (Math.abs(d) < 0.5) return '<span class="chip flat"><span aria-hidden="true">●</span> steady</span>';
    return `<span class="chip ${d > 0 ? 'bad' : 'good'}"><span aria-hidden="true">${d > 0 ? '▲' : '▼'}</span> ${Math.abs(d).toFixed(1).replace(/\.0$/, '')} pts</span>`;
  }

  // Line chart. series: [{ name, color, values[], width? }], labels: x labels.
  function line({ labels, series, target, targetLabel, unit = '%', aria = 'Line chart' }) {
    const W = 720, H = 300, L = 46, R = 22, T = 16, B = 36;
    const vals = series.flatMap((s) => s.values).filter((v) => v != null);
    if (target != null) vals.push(target);
    if (!vals.length) return '<p class="muted">Not enough data for this selection.</p>';
    let lo = Math.max(0, Math.floor((Math.min(...vals) - 6) / 10) * 10);
    let hi = Math.min(100, Math.ceil((Math.max(...vals) + 6) / 10) * 10);
    if (hi - lo < 20) hi = Math.min(100, lo + 20);
    const step = hi - lo <= 40 ? 10 : 20;
    const x = (i) => L + (labels.length === 1 ? (W - L - R) / 2 : (i * (W - L - R)) / (labels.length - 1));
    const y = (v) => T + (1 - (v - lo) / (hi - lo)) * (H - T - B);

    let grid = '';
    for (let v = lo; v <= hi; v += step) grid += `<line class="c-grid" x1="${L}" x2="${W - R}" y1="${y(v)}" y2="${y(v)}"/><text class="c-axis" x="${L - 8}" y="${y(v) + 4}" text-anchor="end">${v}${unit}</text>`;
    const xl = labels.map((t, i) => `<text class="c-axis" x="${x(i)}" y="${H - 12}" text-anchor="middle">${esc(t)}</text>`).join('');
    const tgt = target != null
      ? `<line class="c-target" x1="${L}" x2="${W - R}" y1="${y(target)}" y2="${y(target)}"/><text class="c-axis c-target-label" x="${W - R}" y="${y(target) - 6}" text-anchor="end">${esc(targetLabel || `Target ${target}${unit}`)}</text>`
      : '';
    const paths = series
      .map((s) => {
        let d = '', pen = false;
        s.values.forEach((v, i) => {
          if (v == null) return void (pen = false);
          d += `${pen ? 'L' : 'M'}${x(i).toFixed(1)} ${y(v).toFixed(1)} `;
          pen = true;
        });
        return `<path d="${d}" fill="none" stroke="${s.color}" stroke-width="${s.width || 2.6}" stroke-linecap="round" stroke-linejoin="round"/>`;
      })
      .join('');
    const dots = series
      .map((s) =>
        s.values
          .map((v, i) => (v == null ? '' : `<circle cx="${x(i).toFixed(1)}" cy="${y(v).toFixed(1)}" r="4" fill="${s.color}" class="c-dot"/><circle cx="${x(i).toFixed(1)}" cy="${y(v).toFixed(1)}" r="12" fill="transparent"><title>${esc(s.name)}, ${esc(labels[i])}: ${num(v, 1)}${unit}</title></circle>`))
          .join(''),
      )
      .join('');
    return `<div class="chart-wrap"><svg class="chart" viewBox="0 0 ${W} ${H}" role="img" aria-label="${esc(aria)}">${grid}${tgt}${paths}${dots}${xl}</svg></div>`;
  }

  // Stacked column chart. stacks: [{ name, color, values[] }] (one value per label).
  function columns({ labels, stacks, aria = 'Stacked column chart' }) {
    const W = 720, H = 290, L = 40, R = 12, T = 12, B = 34;
    const totals = labels.map((_, i) => stacks.reduce((a, s) => a + (s.values[i] || 0), 0));
    const maxV = Math.max(1, ...totals);
    const stepG = maxV > 120 ? 40 : maxV > 60 ? 20 : 10;
    const hi = Math.ceil(maxV / stepG) * stepG;
    const bw = ((W - L - R) / labels.length) * 0.62;
    const cx = (i) => L + ((i + 0.5) * (W - L - R)) / labels.length;
    const y = (v) => T + (1 - v / hi) * (H - T - B);
    let grid = '';
    for (let v = 0; v <= hi; v += stepG) grid += `<line class="c-grid" x1="${L}" x2="${W - R}" y1="${y(v)}" y2="${y(v)}"/><text class="c-axis" x="${L - 8}" y="${y(v) + 4}" text-anchor="end">${v}</text>`;
    const bars = labels
      .map((lab, i) => {
        let acc = 0;
        const segs = stacks
          .map((s) => {
            const v = s.values[i] || 0;
            if (!v) return '';
            const r = `<rect x="${(cx(i) - bw / 2).toFixed(1)}" y="${y(acc + v).toFixed(1)}" width="${bw.toFixed(1)}" height="${Math.max(0, y(acc) - y(acc + v)).toFixed(1)}" fill="${s.color}"><title>${esc(lab)} · ${esc(s.name)}: ${v}</title></rect>`;
            acc += v;
            return r;
          })
          .join('');
        return `${segs}<text class="c-axis" x="${cx(i).toFixed(1)}" y="${H - 12}" text-anchor="middle">${esc(lab)}</text>`;
      })
      .join('');
    return `<div class="chart-wrap"><svg class="chart" viewBox="0 0 ${W} ${H}" role="img" aria-label="${esc(aria)}">${grid}${bars}</svg></div>`;
  }

  // Donut. parts: [{ label, value, color }]. centre: { big, small }.
  function donut({ parts, centre, aria = 'Distribution' }) {
    const r = 56, C = 2 * Math.PI * r;
    const total = parts.reduce((a, p) => a + p.value, 0) || 1;
    let acc = 0;
    const segs = parts
      .map((p) => {
        const frac = p.value / total;
        const seg = `<circle cx="80" cy="80" r="${r}" fill="none" stroke="${p.color}" stroke-width="24" stroke-dasharray="${(frac * C).toFixed(2)} ${(C - frac * C).toFixed(2)}" stroke-dashoffset="${(-acc * C).toFixed(2)}" transform="rotate(-90 80 80)"><title>${esc(p.label)}: ${num(p.value, 1)}%</title></circle>`;
        acc += frac;
        return seg;
      })
      .join('');
    return `<svg class="donut" viewBox="0 0 160 160" role="img" aria-label="${esc(aria)}"><circle cx="80" cy="80" r="${r}" fill="none" class="donut-bg" stroke-width="24"/>${segs}
      <text x="80" y="78" text-anchor="middle" class="donut-big">${esc(centre?.big ?? '')}</text>
      <text x="80" y="96" text-anchor="middle" class="c-axis">${esc(centre?.small ?? '')}</text></svg>`;
  }

  // Tiny trend line for tables.
  function spark(values, color = 'var(--accent)') {
    const pts = values.map((v, i) => [i, v]).filter(([, v]) => v != null);
    if (pts.length < 2) return '';
    const W = 84, H = 26;
    const lo = Math.min(...pts.map(([, v]) => v)), hi = Math.max(...pts.map(([, v]) => v));
    const x = (i) => 3 + (i * (W - 6)) / (values.length - 1);
    const y = (v) => (hi === lo ? H / 2 : 3 + (1 - (v - lo) / (hi - lo)) * (H - 6));
    const d = pts.map(([i, v], k) => `${k ? 'L' : 'M'}${x(i).toFixed(1)} ${y(v).toFixed(1)}`).join(' ');
    const [li, lv] = pts.at(-1);
    return `<svg class="spark" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" aria-hidden="true"><path d="${d}" fill="none" stroke="${color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><circle cx="${x(li).toFixed(1)}" cy="${y(lv).toFixed(1)}" r="2.8" fill="${color}"/></svg>`;
  }

  // Horizontal comparison bars with an optional average marker and target tick.
  // rows: [{ label, value, sub?, suppressed?, right? }]
  function compareBars(rows, { target, average, max = 100, higherIsBetter = false } = {}) {
    return `<div class="cmp">${rows
      .map((r) => {
        if (r.suppressed) return `<div class="cmp-row"><span class="cmp-label">${esc(r.label)}</span><div class="cmp-track faded"></div><span class="cmp-val muted">fewer than 5</span></div>`;
        const st = target != null ? (higherIsBetter ? statusHigh : status)(r.value, target) : 'none';
        return `<div class="cmp-row"><span class="cmp-label">${esc(r.label)}${r.sub ? `<small>${esc(r.sub)}</small>` : ''}</span>
          <div class="cmp-track"><i style="width:${Math.min(100, (r.value / max) * 100)}%;background:${target != null ? STATUS_VAR[st] : 'var(--accent)'}"></i>
          ${average != null ? `<b class="mark avg" style="left:${(average / max) * 100}%" title="University: ${num(average, 1)}%"></b>` : ''}
          ${target != null ? `<b class="mark tgt" style="left:${(target / max) * 100}%" title="Target: ${target}%"></b>` : ''}</div>
          <span class="cmp-val">${r.right ?? `${num(r.value, 1)}%`}</span></div>`;
      })
      .join('')}</div>`;
  }

  // Stacked 100% rows, one per group. rows: [{ label, parts:[{value,color,label}], right }]
  function stackRows(rows) {
    return `<div class="stacks">${rows
      .map((r) => {
        const total = r.parts.reduce((a, p) => a + p.value, 0) || 1;
        const segs = r.parts
          .map((p) => {
            const w = (p.value / total) * 100;
            return w < 0.5 ? '' : `<div title="${esc(p.label)}: ${num(p.value, 1)}%" style="width:${w}%;background:${p.color}">${w >= 9 ? `${Math.round(w)}%` : ''}</div>`;
          })
          .join('');
        return r.suppressed
          ? `<div class="stack-row"><span>${esc(r.label)}</span><div class="stack faded"></div><span class="bar-val muted">&lt;5</span></div>`
          : `<div class="stack-row"><span>${esc(r.label)}</span><div class="stack">${segs}</div><span class="bar-val">${esc(r.right ?? '')}</span></div>`;
      })
      .join('')}</div>`;
  }

  const legend = (items) => `<div class="legend">${items.map((i) => `<span><i style="background:${i.color}"></i>${esc(i.label)}</span>`).join('')}</div>`;

  // Tinted table cell colour for an indicator value against its target.
  const heat = (value, target, higherIsBetter = false) => {
    const st = (higherIsBetter ? statusHigh : status)(value, target);
    return st === 'none' ? '' : `background:color-mix(in srgb, ${STATUS_VAR[st]} 16%, transparent);color:${STATUS_VAR[st]}`;
  };

  return { SERIES, num, status, statusHigh, STATUS_VAR, trendChip, deltaChip, line, columns, donut, spark, compareBars, stackRows, legend, heat };
})();
