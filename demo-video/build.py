#!/usr/bin/env python3
"""Generates the HyperFrames composition for the VitalU demo film.

Edit SCENES below (timing, captions, zooms), then run:
    python3 build.py
It rewrites index.html and compositions/*.html. Footage lives in
assets/footage/<name>.mp4 (phone clips 780x1688, browser clips 1920x1200).
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).parent
COMP = ROOT / "compositions"
COMP.mkdir(exist_ok=True)

W, H = 1920, 1080

# --- Palette (from lib/ui/tokens.dart) --------------------------------------
CSS_VARS = """
  --green: #0B7A63; --deep: #053D31; --mint: #5FD3B4; --mint-soft: #D5EFE7;
  --lav: #F8F5FD; --lav-2: #EDE9F5; --ink: #111317; --ink-2: #5B5768;
  --coral: #CC2F55; --amber: #F5B321;
"""

# --- Film --------------------------------------------------------------------
# kind: intro | card | phone | browser | split | final
# captions: [start, duration, title, sub]  (times local to the scene)
# zooms:    [at, duration, scale, originX%, originY%]  scale 1 = no zoom
SCENES = [
    dict(id="intro", kind="intro", dur=4.4),
    dict(id="app", kind="phone", dur=12.5, clip="app_home",
         eyebrow="The student app",
         captions=[[0.3, 3.3, "Sign in once", "Email or Google. Health data stays private."],
                   [3.8, 8.5, "Five sections, one app", "Home, Tools, Diet, Learn and Profile"]],
         chips=["Home", "Tools", "Diet", "Learn", "Profile"], chip_times=[6.0, 6.9, 7.8, 9.0, 10.2],
         zooms=[]),
    dict(id="c_tools", kind="card", dur=2.0, line=["Know your", "numbers"]),
    dict(id="tools", kind="phone", dur=22.3, clip="tools",
         eyebrow="Health tools",
         captions=[[0.3, 8.1, "BMI, in seconds", "Height and weight in, category and a personal plan out"],
                   [8.7, 13.4, "Eight tools, one place", "Body, heart, mind, water, movement, sleep and cycle"]],
         chips=["BMI", "Waist-to-hip", "Heart risk", "Anxiety", "Water", "Activity", "Sleep", "Cycle"],
         chip_times=[8.9, 9.0, 10.6, 12.1, 13.6, 17.4, 18.9, 20.5],
         zooms=[[6.4, 0.9, 1.45, 50, 40], [8.0, 0.5, 1.0, 50, 50], [14.6, 0.8, 1.35, 50, 30], [17.0, 0.4, 1.0, 50, 50]]),
    dict(id="c_diet", kind="card", dur=2.0, line=["Nutrition that's", "personal"]),
    dict(id="diet", kind="phone", dur=35.3, clip="diet",
         eyebrow="Personalised nutrition",
         captions=[[0.3, 3.9, "A personal energy target", "Worked out from your own profile"],
                   [4.4, 7.2, "Log a meal", "Sri Lankan foods by portion, in a few taps"],
                   [11.9, 5.1, "Your intake vs your needs", "510 of 1,900 kcal, against energy used today"],
                   [17.3, 4.8, "Dietary diversity", "How many of the ten food groups you ate today"],
                   [22.3, 3.9, "Diet quality (PDQS)", "A two-minute weekly check-in"],
                   [26.5, 4.5, "Your own diet score", "Guidance built on what you eat, not general advice"],
                   [31.2, 3.9, "Healthy plate guidance", "Half vegetables, a quarter grains, a quarter protein"]],
         zooms=[[12.2, 0.9, 1.45, 50, 20], [15.6, 0.6, 1.0, 50, 50],
                [17.6, 0.8, 1.5, 50, 12], [20.6, 0.6, 1.0, 50, 50],
                [26.6, 0.8, 1.4, 50, 45], [29.0, 0.6, 1.0, 50, 50]]),
    dict(id="progress", kind="phone", dur=11.1, clip="progress",
         eyebrow="Progress and engagement",
         captions=[[0.3, 4.3, "Track your progress", "Assessments, meals, diet quality and tools used"],
                   [4.8, 2.8, "Badges and streaks", "Small goals that build lasting habits"],
                   [7.8, 3.2, "Helpful reminders", "Water, cycle and assessment nudges"]],
         zooms=[]),
    dict(id="consult", kind="phone", dur=8.1, clip="consult",
         eyebrow="Student support",
         captions=[[0.3, 7.6, "Request a consultation", "Book a visit with the University Health Centre"]],
         zooms=[]),
    dict(id="c_assess", kind="card", dur=2.0, line=["Every term,", "a check-in"]),
    dict(id="assess", kind="split", dur=24.5, clip="assess", clip2="admin_completion", split_at=19.6,
         eyebrow="Periodic assessment",
         captions=[[0.3, 6.8, "\u201cAssessment now open\u201d", "Every student is notified in the app"],
                   [7.3, 7.0, "Diet, lifestyle, well-being", "41 short questions in 11 sections"],
                   [14.5, 4.9, "A personal snapshot", "Well-being by area, seen only by the student"],
                   [19.7, 4.6, "Student assessment tracking", "Completion reaches the dashboard, never the answers"]],
         zooms=[[0.6, 0.8, 1.6, 82, 4], [2.6, 0.6, 1.0, 50, 50]]),
    dict(id="c_admin", kind="card", dur=2.5, line=["From individual health", "to campus health"]),
    dict(id="admin", kind="browser", dur=17.4, clip="admin_tour",
         eyebrow="University administration dashboard",
         captions=[[0.3, 4.0, "Centralised health overview", "Students, participation and what's coming up"],
                   [4.5, 5.0, "Assessment scheduling", "Open a window for any faculty, from right now"],
                   [9.8, 2.8, "Health education", "Publish and curate Learn articles"],
                   [12.9, 4.3, "Consultation management", "Requests, appointments and follow-ups"]],
         zooms=[[5.0, 0.9, 1.3, 55, 25], [8.3, 0.6, 1.0, 50, 50]]),
    dict(id="analytics", kind="browser", dur=26.6, clip="analytics",
         eyebrow="Aggregated health analytics",
         captions=[[0.3, 5.7, "Health prevalence", "How common each concern is, against university targets"],
                   [6.2, 4.3, "Trends over time", "Change across the six-monthly assessments"],
                   [10.7, 3.9, "Faculty-wise comparison", "Where each concern is concentrated"],
                   [14.8, 5.2, "Priority needs, ranked", "e.g. breakfast skipping, low fruit and vegetable intake"],
                   [20.2, 6.2, "Plan, act, re-assess", "Interventions monitored through the next assessment"]],
         zooms=[[2.9, 0.9, 1.3, 55, 35], [5.6, 0.5, 1.0, 50, 50],
                [8.7, 0.8, 1.3, 55, 50], [10.3, 0.4, 1.0, 50, 50],
                [17.3, 0.8, 1.3, 55, 45], [19.8, 0.5, 1.0, 50, 50],
                [22.9, 0.8, 1.25, 60, 55], [25.3, 0.5, 1.0, 50, 50]]),
    dict(id="final", kind="final", dur=9.3),
]

total = round(sum(s["dur"] for s in SCENES), 3)


def head(extra=""):
    return f"""<style>
  #root {{ position:absolute; inset:0; overflow:hidden; {CSS_VARS} font-family: Inter, sans-serif; }}
  .bg {{ position:absolute; inset:0; background: var(--lav); }}
  .blob {{ position:absolute; border-radius:50%; filter: blur(0px); }}
  .eyebrow {{ font: 700 28px Inter; letter-spacing: .14em; text-transform: uppercase; color: var(--green); }}
  .cap-title {{ font: 700 64px/1.05 Outfit; color: var(--ink); letter-spacing: -0.02em; }}
  .cap-sub {{ font: 400 28px/1.35 Inter; color: var(--ink-2); margin-top: 18px; }}
  .chip {{ display:inline-block; font: 600 28px Inter; color: var(--deep); background: var(--mint-soft);
          padding: 12px 22px; border-radius: 999px; margin: 0 12px 14px 0; }}
  {extra}
</style>"""


def zoom_js(sel, zooms):
    out = []
    for at, d, s, ox, oy in zooms:
        out.append(f'tl.to("{sel}", {{ scale:{s}, transformOrigin:"{ox}% {oy}%", duration:{d}, ease:"power3.inOut" }}, {at});')
    return "\n    ".join(out)


def captions_html(sid, caps, left, top, width, align="left"):
    html, js = [], []
    for i, (st, d, t, sub) in enumerate(caps):
        cid = f"{sid}-cap{i}"
        html.append(f'''<div id="{cid}" class="clip" data-start="{st}" data-duration="{d}" data-track-index="2"
      style="position:absolute; left:{left}px; top:{top}px; width:{width}px; text-align:{align};">
      <div id="{cid}-in"><div class="cap-title">{t}</div><div class="cap-sub">{sub}</div></div></div>''')
        js.append(f'tl.fromTo("#{cid}-in", {{opacity:0, y:30}}, {{opacity:1, y:0, duration:0.5, ease:"power3.out"}}, {st});')
        js.append(f'tl.to("#{cid}-in", {{opacity:0, y:-16, duration:0.3, ease:"power2.in"}}, {round(st + d - 0.35, 2)});')
    return "\n    ".join(html), "\n    ".join(js)


def wrap(sid, body, js, extra_css=""):
    return f"""<template>
  {head(extra_css)}
  <div id="root" data-composition-id="{sid}" data-width="{W}" data-height="{H}">
    {body}
  </div>
  <script>
    const tl = gsap.timeline({{ paused: true }});
    {js}
    window.__timelines["{sid}"] = tl;
  </script>
</template>
"""


PHONE_W, PHONE_H = 430, 930  # outer frame
SCREEN_W, SCREEN_H = 398, 862  # 390x844 viewport at ~1.02


def phone_markup(pid, clip, dur, start=0, left=None, top=None, scale=1.0):
    left = (W - PHONE_W) // 2 if left is None else left
    top = (H - PHONE_H) // 2 if top is None else top
    return f'''<div id="{pid}" style="position:absolute; left:{left}px; top:{top}px; width:{PHONE_W}px; height:{PHONE_H}px;
        border-radius:64px; background:#111317; box-shadow: 0 40px 90px rgba(5,61,49,.28), 0 0 0 2px #2a2d33 inset;">
      <div style="position:absolute; left:16px; top:34px; width:{SCREEN_W}px; height:{SCREEN_H}px; border-radius:44px; overflow:hidden; background:#fff;">
        <div id="{pid}-zoom" style="position:absolute; inset:0;">
          <video id="{pid}-v" class="clip" src="assets/footage/{clip}.mp4" muted playsinline data-start="{start}" data-duration="{dur}" data-track-index="1"
            style="position:absolute; inset:0; width:100%; height:100%; object-fit:cover;"></video>
        </div>
      </div>
      <div style="position:absolute; left:50%; top:16px; width:120px; height:30px; margin-left:-60px; border-radius:20px; background:#111317;"></div>
    </div>'''


BR_W, BR_H = 1500, 984  # frame incl. 46px bar; content 1500x938 (1920x1200 scaled)


def browser_markup(bid, clip, dur, start=0, left=None, top=None, w=BR_W):
    s = w / BR_W
    h = round(BR_H * s)
    left = (W - w) // 2 if left is None else left
    top = (H - h) // 2 if top is None else top
    bar = round(46 * s)
    return f'''<div id="{bid}" style="position:absolute; left:{left}px; top:{top}px; width:{w}px; height:{h}px; border-radius:{round(18*s)}px;
        overflow:hidden; background:#fff; box-shadow: 0 40px 90px rgba(5,61,49,.25);">
      <div style="height:{bar}px; background:#ECE8F3; display:flex; align-items:center; padding-left:{round(20*s)}px; gap:{round(9*s)}px;">
        <i style="width:{round(13*s)}px;height:{round(13*s)}px;border-radius:50%;background:#FF5F57"></i>
        <i style="width:{round(13*s)}px;height:{round(13*s)}px;border-radius:50%;background:#FEBC2E"></i>
        <i style="width:{round(13*s)}px;height:{round(13*s)}px;border-radius:50%;background:#28C840"></i>
        <span data-layout-ignore style="margin-left:{round(24*s)}px; font:500 {round(17*s)}px Inter; color:#5B5768; background:#fff; padding:{round(5*s)}px {round(18*s)}px; border-radius:8px;">vitalu · admin</span>
      </div>
      <div style="position:absolute; left:0; top:{bar}px; right:0; bottom:0; overflow:hidden;">
        <div id="{bid}-zoom" style="position:absolute; inset:0;">
          <video id="{bid}-v" class="clip" src="assets/footage/{clip}.mp4" muted playsinline data-start="{start}" data-duration="{dur}" data-track-index="1"
            style="position:absolute; inset:0; width:100%; height:100%; object-fit:cover; object-position: top;"></video>
        </div>
      </div>
    </div>'''


def blobs(sid):
    return f'''<div class="bg"></div>
    <div id="{sid}-b1" class="blob" style="left:-220px; top:-260px; width:760px; height:760px; background: radial-gradient(circle, rgba(95,211,180,.35), rgba(95,211,180,0) 70%);"></div>
    <div id="{sid}-b2" class="blob" style="right:-260px; bottom:-300px; width:860px; height:860px; background: radial-gradient(circle, rgba(11,122,99,.18), rgba(11,122,99,0) 70%);"></div>'''


def blob_js(sid, dur):
    return (f'tl.fromTo("#{sid}-b1", {{x:0, y:0}}, {{x:120, y:60, duration:{dur}, ease:"none"}}, 0);\n    '
            f'tl.fromTo("#{sid}-b2", {{x:0, y:0}}, {{x:-100, y:-50, duration:{dur}, ease:"none"}}, 0);')


def scene_phone(s):
    sid, d = s["id"], s["dur"]
    phone_left = 300
    body = [blobs(sid),
            f'<div id="{sid}-ph-wrap" style="position:absolute; inset:0;">{phone_markup(sid + "-ph", s["clip"], d, left=phone_left)}</div>',
            f'<div id="{sid}-eb" class="eyebrow" style="position:absolute; left:900px; top:250px;">{s["eyebrow"]}</div>']
    ch, cj = captions_html(sid, s["captions"], 900, 300, 820)
    body.append(ch)
    js = [blob_js(sid, d),
          f'tl.fromTo("#{sid}-ph", {{opacity:0, y:80, rotation:-2}}, {{opacity:1, y:0, rotation:0, duration:0.8, ease:"power3.out"}}, 0);',
          f'tl.fromTo("#{sid}-eb", {{opacity:0, x:-20}}, {{opacity:1, x:0, duration:0.5, ease:"power3.out"}}, 0.15);',
          cj, zoom_js(f"#{sid}-ph-zoom", s.get("zooms", []))]
    if s.get("chips"):
        chips = "".join(f'<span id="{sid}-chip{i}" class="chip">{c}</span>' for i, c in enumerate(s["chips"]))
        at = s.get("chips_at", (s.get("chip_times") or [0])[0])
        body.append(f'<div id="{sid}-chips" class="clip" data-start="{at}" data-duration="{round(d - at, 2)}" data-track-index="3" style="position:absolute; left:900px; top:560px; width:820px;">{chips}</div>')
        times = s.get("chip_times") or [round(at + 0.15 + i * 0.35, 2) for i in range(len(s["chips"]))]
        for i in range(len(s["chips"])):
            js.append(f'tl.fromTo("#{sid}-chip{i}", {{opacity:0, scale:.8}}, {{opacity:1, scale:1, duration:.35, ease:"back.out(2)"}}, {times[i]});')
    return wrap(sid, "\n    ".join(body), "\n    ".join(js))


def scene_browser(s):
    sid, d = s["id"], s["dur"]
    w = 1640
    body = [blobs(sid),
            f'<div id="{sid}-br-wrap" style="position:absolute; inset:0;">{browser_markup(sid + "-br", s["clip"], d, w=w, top=40)}</div>',
            # caption panel bottom-left, over the browser
            f'<div id="{sid}-panel" style="position:absolute; left:80px; bottom:60px; width:840px; height:290px; border-radius:28px; background:rgba(255,255,255,.94); box-shadow:0 24px 60px rgba(5,61,49,.22);"></div>',
            f'<div id="{sid}-eb" class="eyebrow" style="position:absolute; left:120px; bottom:272px;">{s["eyebrow"]}</div>']
    ch, cj = captions_html(sid, s["captions"], 120, 826, 770)
    body.append(ch)
    js = [blob_js(sid, d),
          f'tl.fromTo("#{sid}-br", {{opacity:0, y:60, scale:.96}}, {{opacity:1, y:0, scale:1, duration:0.8, ease:"power3.out"}}, 0);',
          f'tl.fromTo("#{sid}-panel", {{opacity:0, y:30}}, {{opacity:1, y:0, duration:0.5, ease:"power3.out"}}, 0.2);',
          f'tl.fromTo("#{sid}-eb", {{opacity:0}}, {{opacity:1, duration:0.4}}, 0.3);',
          cj, zoom_js(f"#{sid}-br-zoom", s.get("zooms", []))]
    css = ".cap-title{font-size:48px} .cap-sub{font-size:28px; margin-top:10px}"
    return wrap(sid, "\n    ".join(body), "\n    ".join(js), css)


def scene_split(s):
    """Phone on its own, then at split_at the browser slides in beside it."""
    sid, d, sp = s["id"], s["dur"], s["split_at"]
    body = [blobs(sid),
            f'<div id="{sid}-ph-wrap" style="position:absolute; inset:0;">{phone_markup(sid + "-ph", s["clip"], d, left=300)}</div>',
            f'<div id="{sid}-br-wrap" style="position:absolute; inset:0;">'
            f'{browser_markup(sid + "-br", s["clip2"], round(d - sp, 2), start=sp, left=820, top=150, w=1020)}</div>',
            f'<div id="{sid}-eb" class="eyebrow" style="position:absolute; left:900px; top:250px;">{s["eyebrow"]}</div>']
    ch, cj = captions_html(sid, s["captions"][:-1], 900, 300, 820)
    last = s["captions"][-1]
    ch2, cj2 = captions_html(sid + "x", [last], 820, 880, 1020, "left")
    body += [ch, ch2]
    js = [blob_js(sid, d),
          f'tl.fromTo("#{sid}-ph", {{opacity:0, y:80}}, {{opacity:1, y:0, duration:0.8, ease:"power3.out"}}, 0);',
          f'tl.fromTo("#{sid}-eb", {{opacity:0}}, {{opacity:1, duration:0.4}}, 0.15);',
          f'tl.to("#{sid}-eb", {{opacity:0, duration:0.3}}, {sp - 0.4});',
          f'tl.to("#{sid}-ph", {{x:-150, duration:0.8, ease:"power3.inOut"}}, {sp - 0.2});',
          f'tl.set("#{sid}-br", {{opacity:0}}, 0);',
          f'tl.fromTo("#{sid}-br", {{opacity:0, x:200}}, {{opacity:1, x:0, duration:0.8, ease:"power3.out", immediateRender:false}}, {sp});',
          cj, cj2, zoom_js(f"#{sid}-ph-zoom", s.get("zooms", []))]
    css = f"#{sid}x-cap0 .cap-title{{font-size:44px}} #{sid}x-cap0 .cap-sub{{font-size:28px; margin-top:8px}}"
    return wrap(sid, "\n    ".join(body), "\n    ".join(js), css)


def scene_card(s):
    sid, d = s["id"], s["dur"]
    a, b = s["line"]
    body = f'''<div style="position:absolute; inset:0; background: var(--deep);"></div>
    <div id="{sid}-glow" style="position:absolute; left:50%; top:50%; width:1400px; height:1400px; margin:-700px 0 0 -700px; border-radius:50%;
       background: radial-gradient(circle, rgba(95,211,180,.28), rgba(95,211,180,0) 60%);"></div>
    <div style="position:absolute; inset:0; display:flex; align-items:center; justify-content:center; text-align:center;">
      <div style="font: 700 104px/1.05 Outfit; letter-spacing:-0.03em;">
        <span id="{sid}-a" style="display:inline-block; color:#fff;">{a}</span>
        <span id="{sid}-b" style="display:inline-block; color: var(--mint);">{b}</span>
      </div>
    </div>'''
    js = f'''tl.fromTo("#{sid}-glow", {{scale:.7, opacity:.4}}, {{scale:1.1, opacity:1, duration:{d}, ease:"none"}}, 0);
    tl.fromTo("#{sid}-a", {{opacity:0, y:40, filter:"blur(10px)"}}, {{opacity:1, y:0, filter:"blur(0px)", duration:.55, ease:"power3.out"}}, 0.1);
    tl.fromTo("#{sid}-b", {{opacity:0, y:40, filter:"blur(10px)"}}, {{opacity:1, y:0, filter:"blur(0px)", duration:.55, ease:"power3.out"}}, 0.35);
    tl.to(["#{sid}-a", "#{sid}-b"], {{opacity:0, y:-20, duration:.3, ease:"power2.in"}}, {round(d - 0.35, 2)});'''
    return wrap(sid, body, js)


def scene_intro(s):
    sid, d = s["id"], s["dur"]
    body = f'''{blobs(sid)}
    <div style="position:absolute; inset:0; display:flex; flex-direction:column; align-items:center; justify-content:center;">
      <div style="display:flex; align-items:center; gap:34px;">
        <img id="{sid}-icon" src="assets/img/app_icon.png" style="width:170px; height:170px; border-radius:42px; box-shadow:0 30px 70px rgba(5,61,49,.3);" />
        <div id="{sid}-word" style="font: 700 150px Outfit; letter-spacing:-0.04em; color: var(--ink);">VitalU</div>
      </div>
      <div id="{sid}-line" style="margin-top:46px; font: 600 56px Outfit; letter-spacing:-0.01em; color: var(--green);">Beyond the Academic Transcript</div>
    </div>'''
    js = f'''{blob_js(sid, d)}
    tl.fromTo("#{sid}-icon", {{opacity:1, scale:.82, rotation:-8}}, {{opacity:1, scale:1, rotation:0, duration:.8, ease:"back.out(1.8)"}}, 0);
    tl.fromTo("#{sid}-word", {{opacity:1, x:-24}}, {{opacity:1, x:0, duration:.7, ease:"power3.out"}}, 0);
    tl.fromTo("#{sid}-line", {{opacity:0, y:30}}, {{opacity:1, y:0, duration:.7, ease:"power3.out"}}, 1.4);
    tl.fromTo("#{sid}-line", {{scale:1}}, {{scale:1.03, duration:2.4, ease:"none"}}, 2.1);
    tl.to(["#{sid}-icon", "#{sid}-word", "#{sid}-line"], {{opacity:0, y:-20, duration:.4, ease:"power2.in"}}, {d - 0.45});'''
    return wrap(sid, body, js)


def scene_final(s):
    sid, d = s["id"], s["dur"]
    end_at = 3.8
    body = f'''{blobs(sid)}
    <div id="{sid}-split" style="position:absolute; inset:0;">
      <div id="{sid}-sw" style="position:absolute; inset:0;">
        {phone_markup(sid + "-ph", "final_app", end_at, left=170, top=110)}
        {browser_markup(sid + "-br", "final_admin", end_at, left=700, top=200, w=1080)}
      </div>
      <div id="{sid}-l1" style="position:absolute; left:170px; top:1050px; width:430px; text-align:center;"></div>
      <div id="{sid}-tag" style="position:absolute; left:700px; top:110px; width:1080px; font:700 46px Outfit; color:var(--ink); letter-spacing:-0.02em;">
        Individual monitoring <span style="color:var(--green)">+</span> population insight</div>
      <div id="{sid}-labels" style="position:absolute; left:700px; top:930px; width:1080px; display:flex; gap:16px;">
        <span class="chip">Students: monitor and improve</span><span class="chip">University: understand and act</span></div>
    </div>
    <div id="{sid}-end" class="clip" data-start="{end_at}" data-duration="{round(d - end_at, 2)}" data-track-index="3" style="position:absolute; inset:0;">
      <div style="position:absolute; inset:0; background: var(--deep);"></div>
      <div style="position:absolute; inset:0; display:flex; flex-direction:column; align-items:center; justify-content:center; text-align:center;">
        <div style="display:flex; align-items:center; gap:30px;">
          <img id="{sid}-icon" src="assets/img/app_icon.png" style="width:150px; height:150px; border-radius:38px;" />
          <div id="{sid}-word" style="font: 700 136px Outfit; letter-spacing:-0.04em; color:#fff;">VitalU</div>
        </div>
        <div id="{sid}-sub" style="margin-top:40px; font: 500 40px Inter; color: var(--mint-soft);">An integrated university health information platform</div>
        <div id="{sid}-line" style="margin-top:34px; font: 600 30px Outfit; color: var(--deep); background: var(--mint); padding: 14px 34px; border-radius: 999px;">Beyond the Academic Transcript</div>
      </div>
      <div id="{sid}-credit" data-layout-ignore style="position:absolute; left:0; right:0; bottom:44px; text-align:center; font: 400 18px Inter; color: rgba(213,239,231,.65);">Music: \u201cInspiring Ambient Motivation\u201d by Soundrider/Dope (Jamendo), CC BY 3.0</div>
    </div>'''
    js = f'''{blob_js(sid, d)}
    tl.fromTo("#{sid}-ph", {{opacity:0, x:-80}}, {{opacity:1, x:0, duration:.8, ease:"power3.out"}}, 0.1);
    tl.fromTo("#{sid}-br", {{opacity:0, x:80}}, {{opacity:1, x:0, duration:.8, ease:"power3.out"}}, 0.25);
    tl.fromTo("#{sid}-tag", {{opacity:0, y:20}}, {{opacity:1, y:0, duration:.6, ease:"power3.out"}}, 0.8);
    tl.fromTo("#{sid}-labels", {{opacity:0, y:20}}, {{opacity:1, y:0, duration:.6, ease:"power3.out"}}, 1.3);
    tl.set("#{sid}-split", {{opacity:0}}, {end_at});
    tl.to("#{sid}-sw", {{scale:.94, transformOrigin:"50% 55%", duration:{end_at - 0.5}, ease:"none"}}, 0.5);
    tl.fromTo("#{sid}-icon", {{opacity:0, scale:.6}}, {{opacity:1, scale:1, duration:.7, ease:"back.out(1.8)"}}, {end_at + 0.1});
    tl.fromTo("#{sid}-word", {{opacity:0, x:-20}}, {{opacity:1, x:0, duration:.6, ease:"power3.out"}}, {end_at + 0.35});
    tl.fromTo("#{sid}-sub", {{opacity:0, y:20}}, {{opacity:1, y:0, duration:.6, ease:"power3.out"}}, {end_at + 0.6});
    tl.fromTo("#{sid}-line", {{opacity:0, scale:.9}}, {{opacity:1, scale:1, duration:.6, ease:"back.out(1.6)"}}, {end_at + 0.9});'''
    return wrap(sid, body, js)


BUILDERS = dict(intro=scene_intro, card=scene_card, phone=scene_phone, browser=scene_browser,
                split=scene_split, final=scene_final)

hosts, t = [], 0.0
for s in SCENES:
    (COMP / f"{s['id']}.html").write_text(BUILDERS[s["kind"]](s))
    hosts.append(f'''      <div id="{s['id']}" data-composition-id="{s['id']}" data-composition-src="compositions/{s['id']}.html"
        data-start="{round(t, 3)}" data-duration="{s['dur']}" data-track-index="0" data-track-kind="graphics"
        data-width="{W}" data-height="{H}"></div>''')
    t += s["dur"]

starts, _t = {}, 0.0
for _s in SCENES:
    starts[_s["id"]] = round(_t, 3); _t += _s["dur"]
sfx_events = []
for k, _s in enumerate([x for x in SCENES if x["kind"] == "card"]):
    sfx_events.append((starts[_s["id"]], "whoosh.mp3" if k % 2 == 0 else "whoosh-short.mp3", 0.55))
for _s in SCENES:
    if _s["kind"] == "split":
        sfx_events.append((round(starts[_s["id"]] + _s["split_at"], 3), "whoosh-short.mp3", 0.45))
    if _s["kind"] == "final":
        sfx_events.append((starts[_s["id"]], "whoosh.mp3", 0.45))
        sfx_events.append((round(starts[_s["id"]] + 3.9, 3), "pop.mp3", 0.6))
SFX_LEN = {"whoosh.mp3": 0.57, "whoosh-short.mp3": 0.57, "pop.mp3": 0.72}
sfx = "\n".join(f'      <audio id="sfx{i}" class="clip" src="assets/sfx/{f}" data-start="{t}" data-duration="{SFX_LEN[f]}" data-track-index="6" data-volume="{v}"></audio>'
                for i, (t, f, v) in enumerate(sorted(sfx_events)))
music = ""
if (ROOT / "assets" / "music.mp3").exists():
    music = f'''      <audio id="music" class="clip" src="assets/music.mp3" data-start="0" data-duration="{total}" data-track-index="5"
        data-volume="1"></audio>'''

index = f"""<!doctype html>
<html lang="en" data-resolution="landscape">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width={W}, height={H}" />
    <script src="https://cdn.jsdelivr.net/npm/gsap@3.15.0/dist/gsap.min.js"></script>
    <style>
      * {{ margin:0; padding:0; box-sizing:border-box; }}
      html, body {{ margin:0; width:{W}px; height:{H}px; overflow:hidden; background:#F8F5FD; }}
    </style>
  </head>
  <body>
    <div id="root" data-composition-id="main" data-start="0" data-duration="{total}" data-width="{W}" data-height="{H}">
{chr(10).join(hosts)}
{music}
{sfx}
    </div>
    <script>
      const tl = gsap.timeline({{ paused: true }});
      window.__timelines["main"] = tl;
    </script>
  </body>
</html>
"""
(ROOT / "index.html").write_text(index)
json.dump({s["id"]: s.get("clip") for s in SCENES}, open(ROOT / "footage-map.json", "w"), indent=2)
print(f"total {total}s, {len(SCENES)} scenes")
