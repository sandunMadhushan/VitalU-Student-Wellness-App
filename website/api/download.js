// GET /download: starts the download of the APK in the latest GitHub release,
// so visitors get the file straight away without seeing GitHub.
//
// The release's asset link answers with the file itself (Content-Disposition:
// attachment), so the browser stays on the page and the download starts.
// GITHUB_TOKEN is optional: with it, the release lookup uses the higher API
// rate limit. The APK bytes never pass through Vercel.
const REPO = 'sandunMadhushan/VitalU-Student-Wellness-App';
const FALLBACK = `https://github.com/${REPO}/releases/latest`;

module.exports = async (req, res) => {
  const go = (url, cache) => {
    res.statusCode = 302;
    res.setHeader('Location', url);
    res.setHeader('Cache-Control', cache);
    res.end();
  };

  const headers = {
    Accept: 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'vitalu-website',
  };
  if (process.env.GITHUB_TOKEN) headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;

  try {
    const rel = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`, { headers });
    if (!rel.ok) throw new Error(`release lookup ${rel.status}`);
    const { assets = [] } = await rel.json();
    const apk = assets.find((a) => a.name.toLowerCase().endsWith('.apk'));
    if (!apk) throw new Error('no apk in latest release');
    // Cached at Vercel's edge for 5 minutes, so GitHub is asked at most a few
    // times an hour; a new release shows up within 5 minutes.
    return go(apk.browser_download_url, 'public, max-age=0, s-maxage=300, stale-while-revalidate=600');
  } catch (err) {
    console.error('download:', err.message);
    return go(FALLBACK, 'no-store');
  }
};
