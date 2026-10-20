// Light and dark themes, matching the admin dashboard. Loaded in <head> so the
// saved choice applies before the first paint; the choice stays in this browser.
(function () {
  var KEY = 'vitalu-eval-theme';
  var root = document.documentElement;
  var saved = null;
  try { saved = localStorage.getItem(KEY); } catch (e) { /* private mode */ }
  root.setAttribute('data-theme', saved === 'dark' ? 'dark' : 'light');

  document.addEventListener('click', function (e) {
    var btn = e.target.closest && e.target.closest('[data-theme-toggle]');
    if (!btn) return;
    var next = root.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
    root.setAttribute('data-theme', next);
    try { localStorage.setItem(KEY, next); } catch (err) { /* private mode */ }
  });
})();
