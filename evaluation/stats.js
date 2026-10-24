// Small statistics helpers for the researcher page: the Wilcoxon signed-rank
// test and the Holm correction. Results match R's
//   wilcox.test(post, pre, paired = TRUE)
// which uses the exact distribution when there are fewer than 50 pairs with
// no zero differences and no ties, and otherwise the normal approximation
// with tie and continuity corrections.
'use strict';

/** Standard normal cumulative distribution (Abramowitz and Stegun 26.2.17). */
function normalCdf(z) {
  const t = 1 / (1 + 0.2316419 * Math.abs(z));
  const d = 0.3989422804014327 * Math.exp((-z * z) / 2);
  const p = d * t * (0.31938153 + t * (-0.356563782 + t * (1.781477937 + t * (-1.821255978 + t * 1.330274429))));
  return z > 0 ? 1 - p : p;
}

/** Ranks of |d|, ties sharing the average rank. Returns [ranks, tieGroupSizes]. */
function rankAbs(diffs) {
  const order = diffs.map((d, i) => [Math.abs(d), i]).sort((a, b) => a[0] - b[0]);
  const ranks = new Array(diffs.length);
  const ties = [];
  for (let i = 0; i < order.length; ) {
    let j = i;
    while (j + 1 < order.length && order[j + 1][0] === order[i][0]) j++;
    const avg = (i + j + 2) / 2; // ranks are 1-based
    for (let k = i; k <= j; k++) ranks[order[k][1]] = avg;
    if (j > i) ties.push(j - i + 1);
    i = j + 1;
  }
  return [ranks, ties];
}

/** Exact two-sided p for W+ with n untied, non-zero differences. */
function exactWilcoxonP(wPlus, n) {
  const max = (n * (n + 1)) / 2;
  // counts[s] = number of subsets of {1..n} whose ranks sum to s
  let counts = new Array(max + 1).fill(0);
  counts[0] = 1;
  for (let k = 1; k <= n; k++) {
    const next = counts.slice();
    for (let s = k; s <= max; s++) next[s] += counts[s - k];
    counts = next;
  }
  const total = 2 ** n;
  const lowTail = (w) => counts.slice(0, Math.floor(w) + 1).reduce((a, b) => a + b, 0) / total;
  const lo = Math.min(wPlus, max - wPlus);
  return Math.min(1, 2 * lowTail(lo));
}

/**
 * Wilcoxon signed-rank test on paired values (arrays of equal length, numbers).
 * Returns { pairs, n, zeros, wPlus, wMinus, z, p, r, method, up, same, down,
 * medianPre, medianPost } or null when there are no pairs.
 */
function wilcoxonSignedRank(pre, post) {
  const pairs = pre.length;
  if (!pairs) return null;
  const all = post.map((b, i) => b - pre[i]);
  const diffs = all.filter((d) => d !== 0);
  const n = diffs.length;
  const zeros = pairs - n;
  const up = all.filter((d) => d > 0).length;
  const down = all.filter((d) => d < 0).length;
  const out = { pairs, n, zeros, up, down, same: zeros, medianPre: median(pre), medianPost: median(post) };
  if (!n) return { ...out, wPlus: 0, wMinus: 0, z: 0, p: 1, r: 0, method: 'no change in any pair' };

  const [ranks, ties] = rankAbs(diffs);
  let wPlus = 0;
  let wMinus = 0;
  diffs.forEach((d, i) => (d > 0 ? (wPlus += ranks[i]) : (wMinus += ranks[i])));

  const mean = (n * (n + 1)) / 4;
  const tieAdj = ties.reduce((a, t) => a + (t ** 3 - t), 0) / 48;
  const sd = Math.sqrt((n * (n + 1) * (2 * n + 1)) / 24 - tieAdj);
  // z without continuity correction is the usual basis for the effect size.
  const zPlain = sd ? (wPlus - mean) / sd : 0;

  let p;
  let method;
  if (n < 50 && zeros === 0 && ties.length === 0) {
    p = exactWilcoxonP(wPlus, n);
    method = 'exact';
  } else {
    const diff = wPlus - mean;
    const cc = diff === 0 ? 0 : 0.5 * Math.sign(diff);
    const zc = sd ? (diff - cc) / sd : 0;
    p = Math.min(1, 2 * (1 - normalCdf(Math.abs(zc))));
    method = 'normal approximation, tie and continuity corrected';
  }
  return { ...out, wPlus, wMinus, z: zPlain, p, r: Math.abs(zPlain) / Math.sqrt(n), method };
}

function median(xs) {
  if (!xs.length) return null;
  const s = [...xs].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
}

/** Holm-adjusted p-values, in the original order. */
function holm(ps) {
  const idx = ps.map((p, i) => [p, i]).filter(([p]) => p != null).sort((a, b) => a[0] - b[0]);
  const m = idx.length;
  const out = ps.map(() => null);
  let running = 0;
  idx.forEach(([p, i], k) => {
    running = Math.max(running, Math.min(1, (m - k) * p));
    out[i] = running;
  });
  return out;
}

/** "small", "medium" or "large" for an effect size r (Cohen, 1988). */
function effectLabel(r) {
  if (r >= 0.5) return 'large';
  if (r >= 0.3) return 'medium';
  if (r >= 0.1) return 'small';
  return 'negligible';
}
