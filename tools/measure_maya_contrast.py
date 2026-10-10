#!/usr/bin/env python3
"""WCAG contrast of Maya body vs the real backdrop, and cacao pods.

Maya: samples 3d_x*.png sweep (8 x along selva-1) plus entrance/hazard/cacao.
Body vs immediate non-Maya neighbors (play-jungle band). Outline vs dawn/wind.
Cacao: HP001_*_engine_totem_pods*.png pods vs their neighbors.
Does not change pixels.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

DOCS = Path(__file__).resolve().parents[1] / "docs" / "hp001"

SWEEP = [
    ("3d_x04.png", None),
    ("3d_x36.png", None),
    ("3d_x66.png", None),
    ("3d_x87.png", None),
    ("3d_x95.png", None),
    ("3d_x133.png", None),
    ("3d_x163.png", None),
    ("3d_x193.png", None),
]


def lin(c: float) -> float:
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rel_lum(rgb) -> float:
    r, g, b = rgb[:3]
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)


def wcag(a, b) -> float:
    l1, l2 = rel_lum(a), rel_lum(b)
    hi, lo = (l1, l2) if l1 >= l2 else (l2, l1)
    return (hi + 0.05) / (lo + 0.05)


def median_rgb(samples: list[tuple[int, int, int]]) -> tuple[int, int, int]:
    if not samples:
        return (0, 0, 0)
    rs = sorted(p[0] for p in samples)
    gs = sorted(p[1] for p in samples)
    bs = sorted(p[2] for p in samples)
    mid = len(samples) // 2
    return (rs[mid], gs[mid], bs[mid])


def is_cream(rgb) -> bool:
    r, g, b = rgb[:3]
    if r < 95 or r > 210 or g < 80 or g > 195 or b < 60 or b > 175:
        return False
    if r < g - 8 or r < b:
        return False
    mx, mn = max(r, g, b), min(r, g, b)
    if mx - mn < 12:
        return False
    return 0.70 * r <= g <= 1.05 * r and 0.50 * r <= b <= 0.95 * r


def is_outline(rgb) -> bool:
    r, g, b = rgb[:3]
    if r > 70 or g > 55 or b > 48:
        return False
    return r >= g >= b and r + g + b < 150


def is_platform(rgb) -> bool:
    r, g, b = rgb[:3]
    return r < 95 and g < 75 and b < 60 and r > 28 and abs(r - 2 * b) < 40


def is_sky_or_wind(rgb) -> bool:
    r, g, b = rgb[:3]
    if r < 130 or g < 100 or b < 50:
        return False
    return r >= g - 6 and g >= b - 8 and r + g + b > 300


def is_cacao(rgb) -> bool:
    r, g, b = rgb[:3]
    if r < 140 or r < g + 8:
        return False
    if g < 40 or b > 120:
        return False
    return r - b > 40 and r > 150


def measure_maya(path: Path, region=None) -> dict:
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    x0, y0, x1, y1 = region if region else (0, 0, w, h)
    cream = []
    for y in range(y0, y1):
        for x in range(x0, x1):
            if is_cream(px[x, y]):
                cream.append((x, y, px[x, y]))
    if len(cream) > 400:
        best = []
        step = 8
        for cy in range(y0, y1, step):
            for cx in range(x0, x1, step):
                bunch = [p for p in cream if abs(p[0] - cx) < 28 and abs(p[1] - cy) < 40]
                if len(bunch) > len(best) and 20 < len(bunch) < 900:
                    best = bunch
        if best:
            cream = best
    if len(cream) < 12:
        return {"file": path.name, "error": "maya body not found", "cream_n": len(cream)}
    xs = [p[0] for p in cream]
    ys = [p[1] for p in cream]
    body_rgb = [p[2] for p in cream]
    outline_rgb = []
    body_bg = []
    outline_bg = []
    for x, y, _ in cream:
        for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2), (-3, -1), (3, 1), (-1, 3), (1, -3)):
            nx, ny = x + dx, y + dy
            if not (0 <= nx < w and 0 <= ny < h):
                continue
            rgb = px[nx, ny]
            if is_outline(rgb):
                outline_rgb.append(rgb)
            elif not is_cream(rgb) and not is_platform(rgb):
                body_bg.append(rgb)
    for y in range(max(y0, int(min(ys)) - 12), min(y1, int(max(ys)) + 13)):
        for x in range(max(x0, int(min(xs)) - 12), min(x1, int(max(xs)) + 13)):
            rgb = px[x, y]
            if is_cream(rgb) or is_outline(rgb) or is_platform(rgb):
                continue
            if min(abs(x - min(xs)), abs(x - max(xs)), abs(y - min(ys)), abs(y - max(ys))) <= 12:
                if is_sky_or_wind(rgb):
                    outline_bg.append(rgb)
                else:
                    body_bg.append(rgb)
    if len(outline_bg) < 16:
        for rad in (16, 22):
            for y in range(max(y0, int(min(ys)) - rad), min(y1, int(max(ys)) + rad + 1)):
                for x in range(max(x0, int(min(xs)) - rad), min(x1, int(max(xs)) + rad + 1)):
                    rgb = px[x, y]
                    if is_sky_or_wind(rgb):
                        outline_bg.append(rgb)
            if len(outline_bg) >= 16:
                break
    body = median_rgb(body_rgb)
    outline = median_rgb(outline_rgb) if outline_rgb else (18, 12, 8)
    bg_body = median_rgb(body_bg) if body_bg else (200, 190, 150)
    bg_out = median_rgb(outline_bg) if outline_bg else bg_body
    return {
        "file": path.name,
        "cream_n": len(cream),
        "outline_n": len(outline_rgb),
        "body_bg_n": len(body_bg),
        "center_px": [round(sum(xs) / len(xs), 1), round(sum(ys) / len(ys), 1)],
        "body_rgb": list(body),
        "body_bg_rgb": list(bg_body),
        "outline_rgb": list(outline),
        "outline_bg_rgb": list(bg_out),
        "body_ratio": round(wcag(body, bg_body), 2),
        "outline_ratio": round(wcag(outline, bg_out), 2),
        "body_pass": wcag(body, bg_body) >= 4.4,
        "outline_pass": wcag(outline, bg_out) >= 4.4,
    }


def measure_cacao(path: Path) -> dict:
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    pods = []
    for y in range(h):
        for x in range(w):
            if is_cacao(px[x, y]):
                pods.append((x, y, px[x, y]))
    if len(pods) < 20:
        return {"file": path.name, "error": "cacao pods not found", "pod_n": len(pods)}
    if len(pods) > 800:
        best = []
        for cy in range(0, h, 10):
            for cx in range(0, w, 10):
                bunch = [p for p in pods if abs(p[0] - cx) < 36 and abs(p[1] - cy) < 48]
                if len(bunch) > len(best) and 30 < len(bunch) < 1200:
                    best = bunch
        if best:
            pods = best
    xs = [p[0] for p in pods]
    ys = [p[1] for p in pods]
    pod_rgb = [p[2] for p in pods]
    bg = []
    for x, y, _ in pods:
        for dx, dy in ((-3, 0), (3, 0), (0, -3), (0, 3), (-4, -2), (4, 2)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h:
                rgb = px[nx, ny]
                if not is_cacao(rgb):
                    bg.append(rgb)
    pod = median_rgb(pod_rgb)
    bgm = median_rgb(bg) if bg else (20, 16, 10)
    return {
        "file": path.name,
        "pod_n": len(pods),
        "center_px": [round(sum(xs) / len(xs), 1), round(sum(ys) / len(ys), 1)],
        "pod_rgb": list(pod),
        "bg_rgb": list(bgm),
        "ratio": round(wcag(pod, bgm), 2),
        "pass": wcag(pod, bgm) >= 4.4,
    }


def main() -> int:
    maya = []
    files = [(DOCS / n, r) for n, r in SWEEP]
    for extra in ("3d_entrance.png", "3d_hazard.png", "3d_cacao.png"):
        p = DOCS / extra
        if p.exists() and p not in [f for f, _ in files]:
            files.append((p, None))
    for path, region in files:
        if not path.exists():
            maya.append({"file": path.name, "error": "missing"})
            continue
        maya.append(measure_maya(path, region))
    cacao = []
    for p in sorted(DOCS.glob("HP001_*engine_totem_pods*.png")):
        cacao.append(measure_cacao(p))
    report = {"maya": maya, "cacao": cacao}
    print(json.dumps(report, indent=2))
    ok_m = all(r.get("body_pass") for r in maya if "body_pass" in r)
    ok_c = all(r.get("pass") for r in cacao if "pass" in r) if cacao else True
    return 0 if ok_m and ok_c else 1


if __name__ == "__main__":
    sys.exit(main())
