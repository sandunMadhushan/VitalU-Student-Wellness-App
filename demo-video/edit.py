#!/usr/bin/env python3
"""Cuts the raw screen recordings into one clip per scene.

Raw recordings live in RAW (not committed: they contain the demo account's
screens). Each scene is a list of (clip, in, out, speed); the result is
written to assets/footage/<scene>.mp4 and the segment start times (in scene
time) to footage-segments.json, which build.py uses to time captions/zooms.
"""
import json
import os
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).parent
RAW = pathlib.Path(os.environ.get("RAW", ROOT.parent.parent / "vitalu-demo-raw"))
OUT = ROOT / "assets" / "footage"
OUT.mkdir(parents=True, exist_ok=True)

PHONE = "780:1688"
WEB = "1920:1200"

# Blur boxes applied to a raw clip before cutting: (x, y, w, h, t0, t1) in px.
BLUR = {"app_home": [(30, 500, 720, 110, 0, 12.0)]}

SCENES = {
    "app_home": (PHONE, [("app_home", 0.5, 7.9, 2.0), ("app_home", 10.2, 13.2, 1.0), ("app_home", 26.6, 40.4, 2.2)]),
    "tools": (PHONE, [("tools", 0.3, 15.8, 1.8), ("tools", 18.4, 22.4, 2.0), ("tools", 25.1, 28.1, 2.0),
                      ("tools", 29.4, 32.4, 2.0), ("tools", 36.6, 48.0, 3.0), ("tools", 52.3, 55.3, 2.0),
                      ("tools3", 2.7, 5.2, 1.6), ("tools3", 7.1, 9.6, 1.4)]),
    "diet": (PHONE, [("diet", 0.5, 7.4, 1.6), ("diet", 7.4, 52.5, 6.0), ("diet", 62.9, 71.5, 1.6),
                     ("diet_b", 8.4, 18.0, 1.9), ("diet_c", 3.5, 20.0, 4.0), ("pdqs_score", 1.0, 7.2, 1.3),
                     ("diet_c", 120.7, 126.0, 1.3)]),
    "progress": (PHONE, [("progress", 3.0, 12.0, 1.9), ("progress", 29.2, 34.0, 1.6), ("progress", 45.8, 52.5, 2.0)]),
    "consult": (PHONE, [("consult", 0.8, 19.4, 2.3)]),
    "assess": (PHONE, [("assess_a", 0.5, 13.5, 1.8), ("assess_a", 13.2, 35.0, 3.0), ("assess_b", 52.0, 61.4, 1.5)]),
    "admin_completion": (WEB, [("admin_tour2", 23.0, 30.0, 1.4)]),
    "admin_tour": (WEB, [("admin_tour2", 0.3, 22.5, 2.3), ("admin_tour2", 30.5, 34.5, 1.3), ("admin_tour2", 34.6, 42.1, 1.6)]),
    "analytics": (WEB, [("analytics", 3.3, 53.9, 1.9)]),
    "final_app": (PHONE, [("app_home", 12.0, 17.0, 1.0)]),
    "final_admin": (WEB, [("analytics", 4.5, 12.0, 1.5)]),
}


def dur(p):
    return float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(p)]).decode())


def prep(name):
    """Raw clip with blur boxes burnt in (cached)."""
    src = RAW / f"{name}.mp4"
    if name not in BLUR:
        return src
    dst = RAW / f"{name}.blur.mp4"
    if dst.exists() and dst.stat().st_mtime > src.stat().st_mtime:
        return dst
    chain, last = [], "0:v"
    for i, (x, y, w, h, t0, t1) in enumerate(BLUR[name]):
        chain.append(f"[0:v]crop={w}:{h}:{x}:{y},boxblur=18:2[b{i}]")
        chain.append(f"[{last}][b{i}]overlay={x}:{y}:enable='between(t,{t0},{t1})'[v{i}]")
        last = f"v{i}"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(src), "-filter_complex", ";".join(chain), "-map", f"[{last}]",
                    "-c:v", "libx264", "-crf", "15", "-preset", "medium", str(dst)], check=True)
    return dst


def build(scene, pad_to=None):
    size, segs = SCENES[scene]
    parts, starts, t = [], [], 0.0
    for i, (clip, a, b, sp) in enumerate(segs):
        part = OUT / f".{scene}_{i}.mp4"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", f"{a}", "-to", f"{b}", "-i", str(prep(clip)),
                        "-vf", f"setpts=(PTS-STARTPTS)/{sp},fps=30,scale={size}:flags=lanczos,format=yuv420p",
                        "-an", "-c:v", "libx264", "-crf", "17", "-preset", "medium", str(part)], check=True)
        starts.append(round(t, 2))
        t += dur(part)
        parts.append(part)
    lst = OUT / f".{scene}.txt"
    lst.write_text("".join(f"file '{p.name}'\n" for p in parts))
    out = OUT / f"{scene}.mp4"
    vf = ["-vf", f"tpad=stop_mode=clone:stop_duration={pad_to}"] if pad_to else []
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(lst), *vf,
                    "-c:v", "libx264", "-crf", "17", "-preset", "medium", "-pix_fmt", "yuv420p", str(out)], check=True)
    for p in parts:
        p.unlink()
    lst.unlink()
    return {"length": round(t, 2), "starts": starts}


if __name__ == "__main__":
    only = sys.argv[1:] or list(SCENES)
    segf = ROOT / "footage-segments.json"
    info = json.loads(segf.read_text()) if segf.exists() else {}
    for s in only:
        info[s] = build(s, pad_to=8)
        print(s, info[s])
    segf.write_text(json.dumps(info, indent=1))
