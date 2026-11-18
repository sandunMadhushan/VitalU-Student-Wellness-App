// Demonstration backend. While DEMO_BACKEND is true, the admin dashboard's
// aggregate calls (overview, analytics report, completion list, scheduling and
// anonymous consultations) are answered with the generated figures from
// demo-data.js instead of the database, so every screen tells the same story.
//
// Set DEMO_BACKEND to false (or delete this script tag in index.html) to go
// back to the real Supabase data. Questionnaire and Learn always use the real
// database. Sign-in is always real.
'use strict';

const DEMO_BACKEND = true;

(() => {
  if (!DEMO_BACKEND) return;

  const FAC_CODE = ['AG', 'AH', 'AR', 'DS', 'EN', 'MG', 'MD', 'SC', 'VT'];
  const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
  const hash = (s) => {
    let h = 2166136261;
    for (const c of String(s)) h = Math.imul(h ^ c.charCodeAt(0), 16777619);
    return h >>> 0;
  };
  const DAY = 86400000;

  // ------------------------------------------------------------- Windows
  const windowOf = (p) => {
    const opens = new Date(new Date(`${p.date}T08:00:00+05:30`).getTime() - 3 * DAY);
    const s = DEMO.summarize({ period: p.id });
    return {
      id: `w-${p.id}`, term: p.label, title: `${p.label.split(' ').slice(0, 2).join(' ')} Health Assessment`, faculty: null,
      opens_at: opens.toISOString(), closes_at: new Date(opens.getTime() + 7 * DAY).toISOString(),
      eligible: s.eligible, completed: s.n, in_progress: Math.round(s.eligible * 0.02), period: p.id,
    };
  };
  const windows = DEMO.PERIODS.map(windowOf);
  // The next round, already scheduled.
  const next = new Date(Date.now() + 15 * DAY);
  next.setHours(8, 0, 0, 0);
  windows.push({
    id: 'w-next', term: `Year End ${next.getFullYear()}`, title: 'Year End Health Assessment', faculty: null,
    opens_at: next.toISOString(), closes_at: new Date(next.getTime() + 7 * DAY).toISOString(),
    eligible: DEMO.summarize({ period: DEMO.PERIODS.at(-1).id }).eligible + 24, completed: 0, in_progress: 0, period: null,
  });
  const sortedWindows = () => windows.slice().sort((a, b) => new Date(b.opens_at) - new Date(a.opens_at));
  const periodOfWindow = (id) => windows.find((w) => w.id === id)?.period;

  function overview() {
    const latest = DEMO.PERIODS.at(-1).id;
    const byFaculty = {};
    FACULTIES.forEach((f) => (byFaculty[f] = DEMO.summarize({ period: latest, faculty: f }).eligible));
    return { students: DEMO.summarize({ period: latest }).eligible, students_by_faculty: byFaculty, windows: sortedWindows() };
  }

  // ------------------------------------------------------------- Report
  const QUOTES = [
    'Morning lectures start so early that I usually skip breakfast.',
    'The canteen near the hostel closes before I finish my evening practicals.',
    'I would exercise more if the gym had slots outside lecture hours.',
    'Exam weeks make it very hard to sleep properly.',
    'More affordable vegetable options in the canteen would help a lot.',
    'I would like a quiet place on campus to relax between lectures.',
    'Talking to a counsellor without my batchmates knowing would help.',
    'Group projects and deadlines pile up at the same time.',
  ];

  function numberStats(q, rnd) {
    const t = `${q.text} ${q.unit || ''}`.toLowerCase();
    let [mean, spread] = [5, 2];
    if (q.min_value != null && q.max_value != null) [mean, spread] = [(q.min_value + q.max_value) / 2, (q.max_value - q.min_value) / 8];
    if (/\bkg\b|weight/.test(t)) [mean, spread] = [58.4, 7];
    else if (/waist/.test(t)) [mean, spread] = [76, 7];
    else if (/hip/.test(t)) [mean, spread] = [93, 6];
    else if (/height/.test(t)) [mean, spread] = [162, 8];
    else if (/hour|sleep/.test(t)) [mean, spread] = [6.6, 1];
    else if (/minute/.test(t)) [mean, spread] = [38, 15];
    else if (/systolic/.test(t)) [mean, spread] = [112, 9];
    else if (/diastolic/.test(t)) [mean, spread] = [72, 7];
    else if (/glucose/.test(t)) [mean, spread] = [92, 9];
    else if (/triglycer/.test(t)) [mean, spread] = [118, 38];
    else if (/cholesterol/.test(t)) [mean, spread] = [168, 26];
    else if (/\bage\b|years/.test(t)) [mean, spread] = [21.4, 1.6];
    const j = (rnd() - 0.5) * spread * 0.2;
    const r = (v) => Math.round(v * 10) / 10;
    return { mean: r(mean + j), median: r(mean + j - spread * 0.05), p25: r(mean + j - spread * 0.65), p75: r(mean + j + spread * 0.7) };
  }

  function questionResult(q, answered, rnd) {
    if (q.kind === 'number') return { answered, ...numberStats(q, rnd) };
    if (q.kind === 'text') return { answered: Math.round(answered * 0.18), responses: QUOTES.slice().sort(() => rnd() - 0.5).slice(0, 6) };
    const opts = q.options || [];
    if (!opts.length || q.kind === 'profile') return null;
    if (q.kind === 'multi') return { answered, counts: Object.fromEntries(opts.map((o) => [o.value, Math.round(answered * (0.1 + rnd() * 0.5))])) };
    const top = Math.max(1, ...opts.map((o) => (typeof o.score === 'number' ? o.score : 0)));
    const w = opts.map((o) => (0.4 + rnd()) * (1 + ((typeof o.score === 'number' ? o.score : 0) / top) * 0.6));
    const sum = w.reduce((a, b) => a + b, 0);
    const counts = {};
    let used = 0;
    opts.forEach((o, i) => {
      const c = i === opts.length - 1 ? answered - used : Math.round((w[i] / sum) * answered);
      counts[o.value] = Math.max(0, c);
      used += counts[o.value];
    });
    return { answered, counts };
  }

  function report(args = {}) {
    const known = !args.p_window || windows.some((w) => w.id === args.p_window);
    const period = periodOfWindow(args.p_window) || '';
    const faculty = args.p_faculty || '';
    const s = known && (!args.p_window || period) ? DEMO.summarize({ period, faculty }) : { n: 0, suppressed: true };
    if (s.suppressed) return { suppressed: true, n: s.n, min_group: DEMO.MIN_GROUP };
    const r = s.rates;
    const seed = hash(`${period}|${faculty}`);
    const rnd = DEMO.rng(seed);
    const rates = Object.values(r);
    const nut = DEMO.distribution('nutrition', r);
    const bmiN = Math.round(s.n * 0.92);
    const share = (p) => Math.round((bmiN * p) / 100);
    const part = (frac, rate) => ({ n: Math.round(s.n * frac), hit: Math.round(s.n * frac * clamp(rate + (rnd() - 0.5) * 2, 1, 90) / 100) });
    const whr = part(0.86, r.central_obesity), bp = part(0.7, 9), fbg = part(0.62, 7), tg = part(0.6, 17), chol = part(0.6, 21), phq = part(0.97, r.low_mood);

    const domains = {};
    for (const d of state.domains) {
      const drnd = DEMO.rng(hash(String(d.id)) + (faculty ? hash(faculty) : 0) + (period ? hash(period) : 0));
      domains[d.id] = Math.round(clamp(46 + (hash(String(d.id)) % 100) * 0.4 + (drnd() - 0.5) * 8, 30, 92));
    }
    const questions = {};
    for (const q of state.questions) {
      const qrnd = DEMO.rng(hash(String(q.id)) + (faculty ? hash(faculty) : 0) + (period ? hash(period) : 0));
      const answered = Math.round(s.n * (0.93 + qrnd() * 0.06));
      const res = questionResult(q, answered, qrnd);
      if (res) questions[q.id] = res;
    }
    const byFaculty = {};
    FACULTIES.forEach((f) => {
      if (faculty && f !== faculty) return;
      const x = DEMO.summarize({ period, faculty: f });
      byFaculty[f] = x.suppressed ? null : x.n;
    });
    const sex = (k) => {
      const x = DEMO.summarize({ period, faculty, sex: k });
      return x.suppressed ? null : x.n;
    };
    return {
      suppressed: false, n: s.n, min_group: DEMO.MIN_GROUP,
      overall: Math.round(100 - 0.8 * (rates.reduce((a, b) => a + b, 0) / rates.length)),
      domains, questions, by_faculty: byFaculty, by_sex: { Female: sex('F'), Male: sex('M') },
      bmi_categories: { Underweight: share(nut[0].value), Normal: share(nut[1].value), Overweight: share(nut[2].value), Obesity: share(nut[3].value) },
      indicators: {
        bmi_n: bmiN, overweight_obese: share(r.overweight_obese), underweight: share(nut[0].value),
        whr_n: whr.n, whr_high: whr.hit, bp_n: bp.n, bp_raised: bp.hit, fbg_n: fbg.n, fbg_raised: fbg.hit,
        tg_n: tg.n, tg_high: tg.hit, chol_n: chol.n, chol_high: chol.hit, phq2_n: phq.n, phq2_positive: phq.hit,
      },
    };
  }

  // ------------------------------------------------------------- Completion roster
  function completion(args = {}) {
    const wins = sortedWindows().filter((w) => w.period && (!args.p_window || w.id === args.p_window));
    const reg = (args.p_registration || '').trim().toUpperCase();
    const out = [];
    for (const w of wins) {
      const year = new Date(w.opens_at).getFullYear();
      FACULTIES.forEach((f, fi) => {
        for (let y = 1; y <= 4; y++) {
          const s = DEMO.summarize({ period: w.period, faculty: f, year: String(y) });
          const rnd = DEMO.rng(hash(`${w.id}|${fi}|${y}`));
          const ip = Math.round(s.eligible * 0.02);
          const states = Array.from({ length: s.eligible }, (_, i) => (i < s.n ? 'completed' : i < s.n + ip ? 'in_progress' : 'not_started')).sort(() => rnd() - 0.5);
          states.forEach((status, i) => {
            const registration_number = `${FAC_CODE[fi]}/${year - y + 1}/${String(i + 1).padStart(3, '0')}`;
            if (reg && !registration_number.includes(reg)) return;
            out.push({
              registration_number, faculty: f, academic_year: `Year ${y}`, window_term: w.term, status,
              completed_at: status === 'completed' ? new Date(new Date(w.opens_at).getTime() + rnd() * 6.5 * DAY).toISOString() : null,
            });
          });
        }
      });
    }
    return out;
  }

  // ------------------------------------------------------------- Anonymous consultations
  const ago = (h) => new Date(Date.now() - h * 3600000).toISOString();
  const anon = [
    ['VU-7K2Q9', 'Stress and exams', 'I have not slept properly for a week because of the final exams and I keep getting panic attacks in the evening. What should I do?', 'urgent', 'open', 2],
    ['VU-3M8TX', 'Low mood', 'I feel very low and have stopped going to lectures. I do not want my friends to know.', 'urgent', 'open', 9],
    ['VU-9D4LP', 'Sleep', 'I can only sleep around 4 hours a night because of the hostel noise. Is there any advice?', 'soon', 'open', 26],
    ['VU-5R1ZH', 'Nutrition', 'I am trying to lose weight before the sports meet. Is skipping dinner a good idea?', 'soon', 'open', 50],
    ['VU-2B6NC', 'Physical activity', 'Is it safe to start running again after a knee injury last semester?', 'routine', 'open', 74],
    ['VU-8W3YF', 'Nutrition', 'How can I eat healthy on a small allowance when I live in the hostel?', 'routine', 'answered', 120, 'Rice with dhal, a vegetable mallum and a boiled egg is a balanced and low-cost plate. Seasonal fruit from the market is cheaper than snacks. The Nutrition Unit also runs a Wednesday drop-in; you are welcome to visit.'],
    ['VU-6H5GA', 'Stress and exams', 'How can I stay calm before presentations? My hands shake every time.', 'soon', 'answered', 168, 'This is very common. Try slow breathing (in for 4, out for 6) for two minutes before you start, and practise out loud with one friend first. If it keeps affecting you, the Counselling Centre offers short group sessions.'],
    ['VU-1T9KE', 'Sleep', 'Is it normal to feel tired all day even after 8 hours of sleep?', 'routine', 'closed', 260],
  ].map(([code, topic, message, urgency, status, hours, reply], i) => ({
    id: `a${i + 1}`, code, topic, message, urgency, status, created_at: ago(hours), reply: reply || null, replied_at: reply ? ago(hours - 20) : null,
  }));

  // ------------------------------------------------------------- Tiny query builder for the fake tables
  function table(rows) {
    const query = (o) => {
      const filters = [];
      let order = null, lim = null;
      const api = {
        eq: (k, v) => (filters.push([k, v]), api),
        order: (k, opt = {}) => ((order = [k, opt.ascending !== false]), api),
        limit: (n) => ((lim = n), api),
        then: (resolve) => {
          let list = rows.filter((r) => filters.every(([k, v]) => r[k] === v));
          if (o.patch) {
            list.forEach((r) => Object.assign(r, o.patch));
            return resolve({ data: null, error: null });
          }
          if (order) list = list.slice().sort((a, b) => (a[order[0]] > b[order[0]] ? 1 : -1) * (order[1] ? 1 : -1));
          if (lim) list = list.slice(0, lim);
          resolve(o.head ? { data: null, count: list.length, error: null } : { data: list.map((r) => ({ ...r })), count: list.length, error: null });
        },
      };
      return api;
    };
    return { select: (_c, opt = {}) => query({ head: opt.head }), update: (patch) => query({ patch }) };
  }
  const fakeTables = { anon_consultations: table(anon), assessment_windows: table(windows) };

  // ------------------------------------------------------------- Install
  const realRpc = sb.rpc.bind(sb);
  const realFrom = sb.from.bind(sb);
  const ok = (data) => Promise.resolve({ data, error: null });
  sb.rpc = (name, args) => {
    switch (name) {
      case 'admin_assessment_overview': return ok(overview());
      case 'admin_assessment_report': return ok(report(args));
      case 'admin_assessment_completion': return ok(completion(args));
      case 'admin_schedule_assessment': {
        const opens = new Date(args.p_opens_at);
        const facs = args.p_faculties?.length ? args.p_faculties : [null];
        facs.forEach((f) => {
          windows.push({
            id: `w-new-${Date.now()}-${windows.length}`, term: args.p_term, title: args.p_title, faculty: f, opens_at: opens.toISOString(),
            closes_at: new Date(opens.getTime() + args.p_days * DAY).toISOString(), period: null,
            eligible: f ? DEMO.summarize({ period: DEMO.PERIODS.at(-1).id, faculty: f }).eligible : overview().students, completed: 0, in_progress: 0,
          });
        });
        return ok(null);
      }
      case 'admin_delete_assessment_window': {
        const i = windows.findIndex((w) => w.id === args.p_window);
        if (i >= 0) windows.splice(i, 1);
        return ok(null);
      }
      default: return realRpc(name, args);
    }
  };
  sb.from = (name) => fakeTables[name] || realFrom(name);
})();
