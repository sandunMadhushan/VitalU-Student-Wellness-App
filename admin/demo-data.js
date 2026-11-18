// SAMPLE DATA for the Insights, Priority needs, Interventions and
// Consultations views.
//
// Nothing in this file comes from the database. It generates a repeatable
// (seeded) set of pooled assessment results so the decision-support screens can
// be designed and reviewed before the real aggregate functions exist. When the
// backend is ready, replace the body of `summarize()` (and `PERIODS`) with calls
// to the security-definer report functions; the screens only use the functions
// returned at the bottom of this file.
//
// The privacy rule of the real system is kept: any group of fewer than five
// students is suppressed.
'use strict';

const DEMO = (() => {
  const MIN_GROUP = 5;

  // Assessment periods (the six-monthly Mid Year / Year End windows).
  const PERIODS = [
    { id: '2024-mid', label: 'Mid Year 2024', short: "Mid '24", date: '2024-06-20' },
    { id: '2024-end', label: 'Year End 2024', short: "End '24", date: '2024-12-12' },
    { id: '2025-mid', label: 'Mid Year 2025', short: "Mid '25", date: '2025-06-19' },
    { id: '2025-end', label: 'Year End 2025', short: "End '25", date: '2025-12-11' },
    { id: '2026-mid', label: 'Mid Year 2026', short: "Mid '26", date: '2026-06-18' },
  ];
  const LAST = PERIODS.length - 1;

  // Health indicators. For every indicator a higher percentage is worse.
  // `base` is the university-wide level in the latest period, `slope` the
  // average change per period (points) and `target` the level the university
  // would like to reach.
  const INDICATORS = [
    { key: 'overweight_obese', label: 'Overweight or obesity', short: 'Overweight / obese', group: 'Nutrition', note: 'BMI 25 or more', base: 25, slope: 0.4, target: 20 },
    { key: 'central_obesity', label: 'Central obesity', short: 'Central obesity', group: 'Nutrition', note: 'Waist-to-hip ratio 0.90+ men, 0.85+ women', base: 18, slope: 0, target: 12 },
    { key: 'skip_breakfast', label: 'Breakfast skipping', short: 'Skips breakfast', group: 'Nutrition', note: 'Breakfast on fewer than 5 days a week', base: 38, slope: -2.4, target: 25 },
    { key: 'low_fruit_veg', label: 'Inadequate fruit and vegetable intake', short: 'Low fruit & veg', group: 'Nutrition', note: 'Fruit or vegetables on fewer than 5 days a week', base: 68, slope: 1.8, target: 50 },
    { key: 'inactive', label: 'Physical inactivity', short: 'Inactive', group: 'Activity', note: 'Under 150 minutes of activity a week', base: 55, slope: 2.2, target: 40 },
    { key: 'short_sleep', label: 'Insufficient sleep', short: 'Short sleep', group: 'Rest and mind', note: 'Under 7 hours a night', base: 47, slope: 0.3, target: 35 },
    { key: 'high_stress', label: 'High perceived stress', short: 'High stress', group: 'Rest and mind', note: 'Perceived stress score in the high band', base: 41, slope: 3, target: 30 },
    { key: 'low_mood', label: 'Low mood screen positive', short: 'Low mood', group: 'Rest and mind', note: 'PHQ-2 score 3 or more', base: 15, slope: -1.3, target: 10 },
  ];
  const IND = Object.fromEntries(INDICATORS.map((i) => [i.key, i]));

  // Faculty order follows FACULTIES in app.js:
  // Agriculture, Allied Health, Arts, Dental, Engineering, Management, Medicine, Science, Veterinary.
  const ELIGIBLE = [28, 36, 52, 14, 60, 56, 30, 48, 12]; // registered students per academic year (latest)
  const FEMALE = [0.55, 0.7, 0.72, 0.65, 0.3, 0.62, 0.6, 0.58, 0.58];
  const PART = [0.72, 0.58, 0.66, 0.46, 0.74, 0.69, 0.81, 0.7, 0.52]; // participation in the latest period
  const REG_GROWTH = [0.55, 0.68, 0.8, 0.9, 1];
  const PART_GROWTH = [0.66, 0.76, 0.86, 0.94, 1];
  const PART_YEAR = [0.04, 0.02, 0, -0.06];

  // How far each faculty / academic year / sex sits from the university level.
  const MOD = {
    overweight_obese: { fac: [-4, -3, 4, 1, 2, 6, 0, -2, -1], year: [-4, -1, 2, 3], sex: [-2, 2] },
    central_obesity: { fac: [-2, -2, 3, 1, 1, 4, 0, -1, 0], year: [-2, 0, 1, 2], sex: [3, -3] },
    skip_breakfast: { fac: [-7, -4, 3, 1, 9, 6, -2, 2, -6], year: [4, 2, 0, -2], sex: [3, -3] },
    low_fruit_veg: { fac: [-8, -5, 3, 1, 8, 5, 4, 2, -7], year: [3, 1, 0, -2], sex: [-3, 3] },
    inactive: { fac: [-9, 5, -4, 6, 4, 0, 8, -1, -6], year: [0, 2, 4, 6], sex: [8, -8] },
    short_sleep: { fac: [-2, 3, -3, 6, 7, -1, 9, 0, 1], year: [0, 1, 3, 6], sex: [2, -2] },
    high_stress: { fac: [-3, 5, -4, 7, 9, -2, 12, 1, 3], year: [2, 0, 3, 7], sex: [4, -4] },
    low_mood: { fac: [-2, 2, -1, 3, 4, -2, 5, 0, 1], year: [0, 0, 2, 4], sex: [3, -3] },
  };

  // A small sample effect so the intervention evaluation has something to show:
  // fruit and vegetable intake improved a little where a programme started.
  const EFFECTS = [{ key: 'low_fruit_veg', facs: [4, 5, 7], from: 4, delta: -3 }];

  function rng(seed) {
    let a = seed >>> 0;
    return () => {
      a = (a + 0x6d2b79f5) >>> 0;
      let t = a;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }
  const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));

  // One cell per period x faculty x academic year x sex.
  const shared = INDICATORS.map((_, i) => PERIODS.map((_, p) => (rng(9000 + i * 31 + p)() - 0.5) * 1.6));
  const CELLS = [];
  for (let p = 0; p < PERIODS.length; p++) {
    for (let f = 0; f < ELIGIBLE.length; f++) {
      for (let y = 0; y < 4; y++) {
        for (let s = 0; s < 2; s++) {
          const r = rng(((p * 9 + f) * 4 + y) * 2 + s + 1);
          const share = s === 0 ? FEMALE[f] : 1 - FEMALE[f];
          const eligible = Math.round(ELIGIBLE[f] * share * REG_GROWTH[p]);
          const part = clamp(PART[f] * PART_GROWTH[p] + PART_YEAR[y] + (r() - 0.5) * 0.08, 0.2, 0.95);
          const n = Math.round(eligible * part);
          const counts = {};
          INDICATORS.forEach((ind, i) => {
            const m = MOD[ind.key];
            let rate = ind.base + ind.slope * (p - LAST) + m.fac[f] + m.year[y] + m.sex[s] + shared[i][p] + (r() - 0.5) * 2.4;
            for (const e of EFFECTS) if (e.key === ind.key && e.facs.includes(f) && p >= e.from) rate += e.delta;
            counts[ind.key] = Math.round((n * clamp(rate, 2, 95)) / 100);
          });
          CELLS.push({ p, f, y, s, eligible, n, counts });
        }
      }
    }
  }

  const facIdx = (name) => FACULTIES.indexOf(name);

  // Pooled result for a filter: { period, faculty, faculties[], year, sex }.
  // Every field is optional; '' or missing means "all".
  function summarize(flt = {}) {
    const pIdx = flt.period ? PERIODS.findIndex((x) => x.id === flt.period) : -1;
    const facs = flt.faculties?.length ? flt.faculties.map(facIdx) : flt.faculty ? [facIdx(flt.faculty)] : null;
    const year = flt.year ? Number(flt.year) - 1 : -1;
    const sex = flt.sex === 'F' ? 0 : flt.sex === 'M' ? 1 : -1;
    let n = 0, eligible = 0;
    const sums = Object.fromEntries(INDICATORS.map((i) => [i.key, 0]));
    for (const c of CELLS) {
      if (pIdx >= 0 && c.p !== pIdx) continue;
      if (facs && !facs.includes(c.f)) continue;
      if (year >= 0 && c.y !== year) continue;
      if (sex >= 0 && c.s !== sex) continue;
      n += c.n;
      eligible += c.eligible;
      for (const k in sums) sums[k] += c.counts[k];
    }
    const suppressed = n < MIN_GROUP;
    const rates = {};
    for (const k in sums) rates[k] = n ? Math.round((sums[k] / n) * 1000) / 10 : null;
    return { n, eligible, participation: eligible ? Math.round((n / eligible) * 1000) / 10 : null, suppressed, rates };
  }

  // One value per period (null when a group is too small), up to and including `upTo`.
  function series(key, flt = {}, upTo) {
    const end = upTo ? PERIODS.findIndex((x) => x.id === upTo) : LAST;
    return PERIODS.slice(0, end + 1).map((p) => {
      const s = summarize({ ...flt, period: p.id });
      if (s.suppressed) return null;
      return key === 'participation' ? s.participation : s.rates[key];
    });
  }

  // Direction of change: least-squares slope over the available periods.
  function trend(key, flt = {}, upTo) {
    const vals = series(key, flt, upTo);
    const pts = vals.map((v, i) => [i, v]).filter(([, v]) => v != null);
    if (pts.length < 3) return { dir: 'stable', slope: 0, first: pts[0]?.[1] ?? null, last: pts.at(-1)?.[1] ?? null, prev: null, values: vals };
    const mx = pts.reduce((a, [x]) => a + x, 0) / pts.length;
    const my = pts.reduce((a, [, y]) => a + y, 0) / pts.length;
    const slope = pts.reduce((a, [x, y]) => a + (x - mx) * (y - my), 0) / pts.reduce((a, [x]) => a + (x - mx) ** 2, 0);
    const last = pts.at(-1)[1];
    const prev = pts.length > 1 ? pts.at(-2)[1] : null;
    return { dir: slope >= 1 ? 'worse' : slope <= -1 ? 'better' : 'stable', slope: Math.round(slope * 10) / 10, first: pts[0][1], last, prev, values: vals };
  }

  // Break one period down by faculty, academic year or sex.
  function groupBy(dim, flt = {}) {
    const groups =
      dim === 'faculty'
        ? FACULTIES.map((name) => ({ label: name.replace('Faculty of ', ''), flt: { faculty: name } }))
        : dim === 'year'
        ? [1, 2, 3, 4].map((y) => ({ label: `Year ${y}`, flt: { year: String(y) } }))
        : [{ label: 'Female', flt: { sex: 'F' } }, { label: 'Male', flt: { sex: 'M' } }];
    return groups.map((g) => ({ label: g.label, ...summarize({ ...flt, ...g.flt }) }));
  }

  // Category breakdowns derived from the pooled rates (sample shares).
  const DISTRIBUTIONS = {
    nutrition: {
      label: 'Nutritional status (BMI)',
      parts: [['Underweight', '#2a9d8f'], ['Normal', '#5fae6e'], ['Overweight', '#e0b03a'], ['Obesity', '#c62828']],
      from: (r) => {
        const obese = r.overweight_obese * 0.24;
        const over = r.overweight_obese - obese;
        const under = clamp(13 - 0.15 * (r.overweight_obese - 25), 6, 20);
        return [under, 100 - under - over - obese, over, obese];
      },
    },
    stress: {
      label: 'Perceived stress',
      parts: [['Low', '#5fae6e'], ['Moderate', '#e0b03a'], ['High', '#c62828']],
      from: (r) => [(100 - r.high_stress) * 0.38, (100 - r.high_stress) * 0.62, r.high_stress],
    },
    activity: {
      label: 'Physical activity',
      parts: [['High', '#5fae6e'], ['Moderate', '#e0b03a'], ['Inactive', '#c62828']],
      from: (r) => [(100 - r.inactive) * 0.38, (100 - r.inactive) * 0.62, r.inactive],
    },
    sleep: {
      label: 'Sleep per night',
      parts: [['9 hours or more', '#2a9d8f'], ['7 to 9 hours', '#5fae6e'], ['6 to 7 hours', '#e0b03a'], ['Under 6 hours', '#c62828']],
      from: (r) => [(100 - r.short_sleep) * 0.1, (100 - r.short_sleep) * 0.9, r.short_sleep * 0.65, r.short_sleep * 0.35],
    },
    breakfast: {
      label: 'Breakfast per week',
      parts: [['Every day', '#5fae6e'], ['5 to 6 days', '#7cb860'], ['3 to 4 days', '#e0b03a'], ['0 to 2 days', '#c62828']],
      from: (r) => [(100 - r.skip_breakfast) * 0.6, (100 - r.skip_breakfast) * 0.4, r.skip_breakfast * 0.55, r.skip_breakfast * 0.45],
    },
    fruitveg: {
      label: 'Fruit and vegetables',
      parts: [['Most days', '#5fae6e'], ['Some days', '#e0b03a'], ['Rarely', '#c62828']],
      from: (r) => [100 - r.low_fruit_veg, r.low_fruit_veg * 0.65, r.low_fruit_veg * 0.35],
    },
  };
  function distribution(kind, rates) {
    const d = DISTRIBUTIONS[kind];
    const vals = d.from(rates);
    return d.parts.map(([label, color], i) => ({ label, color, value: Math.round(vals[i] * 10) / 10 }));
  }

  return { MIN_GROUP, rng, PERIODS, LAST, INDICATORS, IND, DISTRIBUTIONS, summarize, series, trend, groupBy, distribution };
})();
