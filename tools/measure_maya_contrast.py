#!/usr/bin/env python3
"""WCAG contrast of Maya body and outline vs the immediate background.

Samples 3d_entrance.png (play strip) and 3d_hazard.png (wind zone).
Does not change pixels. Prints body_ratio and outline_ratio.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

DOCS = Path(__file__).resolve().parents[1] / "docs" / "hp001"


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


def measure(path: Path, region=None) -> dict:
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    x0, y0, x1, y1 = region if region else (0, 0, w, h)
    cream = []
    for y in range(y0, y1):
        for x in range(x0, x1):
            if is_cream(px[x, y]):
                cream.append((x, y, px[x, y]))
    # Prefer a compact blob (Maya) over painted-cumulus hits.
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
    cx = sum(xs) / len(xs)
    cy = sum(ys) / len(ys)
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
    # Ring just outside the cream+outline cluster.
    for y in range(max(y0, int(min(ys)) - 10), min(y1, int(max(ys)) + 11)):
        for x in range(max(x0, int(min(xs)) - 10), min(x1, int(max(xs)) + 11)):
            rgb = px[x, y]
            if is_cream(rgb) or is_outline(rgb) or is_platform(rgb):
                continue
            # near the silhouette, not far sky
            if min(abs(x - min(xs)), abs(x - max(xs)), abs(y - min(ys)), abs(y - max(ys))) <= 8:
                outline_bg.append(rgb)
                if not is_cream(rgb):
                    body_bg.append(rgb)
    body = median_rgb(body_rgb)
    outline = median_rgb(outline_rgb) if outline_rgb else (18, 12, 8)
    bg_body = median_rgb(body_bg) if body_bg else (200, 190, 150)
    bg_out = median_rgb(outline_bg) if outline_bg else bg_body
    return {
        "file": path.name,
        "cream_n": len(cream),
        "outline_n": len(outline_rgb),
        "body_bg_n": len(body_bg),
        "outline_bg_n": len(outline_bg),
        "center_px": [round(cx, 1), round(cy, 1)],
        "body_rgb": list(body),
        "outline_rgb": list(outline),
        "body_bg_rgb": list(bg_body),
        "outline_bg_rgb": list(bg_out),
        "body_ratio": round(wcag(body, bg_body), 2),
        "outline_ratio": round(wcag(outline, bg_out), 2),
        "body_pass": wcag(body, bg_body) >= 4.4,
        "outline_pass": wcag(outline, bg_out) >= 4.4,
    }


def main() -> int:
    shots = [
        (DOCS / "3d_entrance.png", (40, 240, 420, 520)),
        (DOCS / "3d_hazard.png", (480, 200, 820, 500)),
    ]
    report = []
    for path, region in shots:
        if not path.exists():
            report.append({"file": path.name, "error": "missing"})
            continue
        report.append(measure(path, region))
    print(json.dumps(report, indent=2))
    ok = all(r.get("body_pass") and r.get("outline_pass") for r in report if "body_pass" in r)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
