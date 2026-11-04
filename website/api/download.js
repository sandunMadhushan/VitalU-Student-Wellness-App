// GET /download: starts the download of the APK attached to the latest GitHub
// release, so visitors get the file straight away without seeing GitHub.
//
// GitHub resolves /releases/latest/download/<name> to the newest release's
// asset and answers with the file itself (Content-Disposition: attachment), so
// the browser stays on the page. No API call is made, so there is no rate limit
// and no failure path that lands on the releases page. Every release must
// attach its APK as VitalU.apk. The APK bytes never pass through Vercel.
const URL = 'https://github.com/sandunMadhushan/VitalU-Student-Wellness-App/releases/latest/download/VitalU.apk';

module.exports = (req, res) => {
  res.statusCode = 302;
  res.setHeader('Location', URL);
  res.setHeader('Cache-Control', 'no-store');
  res.end();
};
