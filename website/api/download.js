// GET /download: sends the visitor straight to the APK of the latest GitHub
// release, so the file downloads without opening GitHub.
//
// The repository is private, so this looks the release up with a read-only
// token (Vercel env var GITHUB_TOKEN) and redirects to GitHub's short-lived
// signed download link. The APK bytes never pass through Vercel.
const REPO = 'sandunMadhushan/VitalU-Student-Wellness-App';
const FALLBACK = `https://github.com/${REPO}/releases/latest`;

module.exports = async (req, res) => {
  const go = (url, cache) => {
    res.statusCode = 302;
    res.setHeader('Location', url);
    res.setHeader('Cache-Control', cache);
    res.end();
  };

  const token = process.env.GITHUB_TOKEN;
  if (!token) return go(FALLBACK, 'no-store');

  const headers = {
    Authorization: `Bearer ${token}`,
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'vitalu-website',
  };

  try {
    const rel = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`, {
      headers: { ...headers, Accept: 'application/vnd.github+json' },
    });
    if (!rel.ok) throw new Error(`release lookup ${rel.status}`);
    const { assets = [] } = await rel.json();
    const apk = assets.find((a) => a.name.toLowerCase().endsWith('.apk'));
    if (!apk) throw new Error('no apk in latest release');

    const file = await fetch(apk.url, {
      headers: { ...headers, Accept: 'application/octet-stream' },
      redirect: 'manual',
    });
    const signed = file.headers.get('location');
    if (!signed) throw new Error(`asset lookup ${file.status}`);

    // The signed link is valid for a few minutes; let Vercel's edge reuse it briefly.
    return go(signed, 'public, max-age=0, s-maxage=60');
  } catch (err) {
    console.error('download:', err.message);
    return go(FALLBACK, 'no-store');
  }
};
