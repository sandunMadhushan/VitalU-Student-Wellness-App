# VitalU website

The public home page for VitalU, served at **vitalu.madhushan.me**. The Flutter web app (with `/admin` and `/evaluation`) moves to **web.vitalu.madhushan.me**.

Plain HTML, CSS and JavaScript. No build step; the one library (Lenis) is self-hosted in `vendor/`.

| File | What it is |
|------|------------|
| `index.html` | The page: hero with the animated phone, facts band, features, tool filter, help lines, privacy, FAQ, footer |
| `styles.css` | Styles and animations. Colours follow the app (`lib/ui/tokens.dart`); headings use Bricolage Grotesque, body text Manrope |
| `main.js` | Load sequence, phone screen rotation, pointer parallax, scroll reveals, counters, tool filter, FAQ |
| `img/` | App icon, 3D icons from `assets/icons3d` and people from `assets/art` and `assets/images` (converted to WebP) |
| `fonts/` | Self-hosted fonts |
| `vendor/` | [Lenis](https://github.com/darkroomengineering/lenis) 1.3.11 for smooth scrolling (turned off when the visitor prefers reduced motion) |
| `api/download.js` | `/download`: starts the download of the APK in the latest GitHub release (see below) |
| `vercel.json` | Sends old `/admin` and `/evaluation` links to the web app, and caches images and fonts |
| `404.html` | Sends any other old app link to the same path on web.vitalu.madhushan.me |

## Links

- Web app: `https://web.vitalu.madhushan.me/`
- Android download: `/download` (on this site)

`/download` looks up the latest GitHub release and sends the browser to its `.apk`, which GitHub serves as a file download, so visitors stay on the page and the download starts. It is cached for 5 minutes. To ship a new version, publish a GitHub release with the APK attached; the site picks it up within 5 minutes.

`GITHUB_TOKEN` (Vercel env var, read-only) is optional; it only raises GitHub's API rate limit. If the lookup fails, `/download` falls back to the GitHub releases page.

## Preview locally

```bash
cd website
python -m http.server 8000
```

Then open http://localhost:8000.

## Going live

DNS for madhushan.me is on Cloudflare. Keep every record below **DNS only** (grey cloud): Cloudflare's free certificate does not cover two-level names like `web.vitalu.madhushan.me`.

1. **Move the web app.** In Cloudflare, add `CNAME web.vitalu -> sandunmadhushan.github.io`. In the GitHub repo, Settings, Pages, change the custom domain from `vitalu.madhushan.me` to `web.vitalu.madhushan.me`. Wait until the certificate is issued, then tick Enforce HTTPS.
2. **Update sign-in.** In Supabase, Authentication, URL Configuration, set the Site URL to `https://web.vitalu.madhushan.me` and add `https://web.vitalu.madhushan.me/**` to the redirect URLs. The app builds its redirect from its own address, so no code change is needed.
3. **Publish this folder.** In Vercel, New Project, import the repo, Root Directory `website`, framework Other, no build command. Then Settings, Domains, add `vitalu.madhushan.me`.
4. **Point the main name at Vercel.** In Cloudflare, change `CNAME vitalu` from `sandunmadhushan.github.io` to `cname.vercel-dns.com`.

Students who installed the web app to their home screen from the old address will now open this page; tell them to open web.vitalu.madhushan.me and add it again.
