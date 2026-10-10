#!/usr/bin/env python3
"""WCAG contrast of Maya body vs the real backdrop, and cacao pods.

Maya: samples 3d_x*.png sweep (8 x along selva-1) plus entrance/hazard/cacao.
Body vs immediate non-Maya neighbors (play-jungle band). Outline vs dawn/wind.
Cacao: HP001_*_engine_totem_pods*.png pods vs their neighbors.
Does not change pixels. Numpy so a 1280×720 scan finishes in milliseconds.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

DOCS = Path(__file__).resolve().parents[1] / "docs" / "hp001"

SWEEP = [
    ("3d_x04.png", 4.54),
    ("3d_x36.png", 36.0),
    ("3d_x66.png", 66.0),
    ("3d_x87.png", 86.67),
    ("3d_x95.png", 95.33),
    ("3d_x133.png", 133.33),
    ("3d_x163.png", 162.67),
    ("3d_x193.png", 193.33),
]


def lin(c: np.ndarray) -> np.ndarray:
    c = c / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def rel_lum(rgb) -> float:
    r, g, b = (float(x) for x in rgb[:3])
    arr = lin(np.array([r, g, b], dtype=np.float64))
    return float(0.2126 * arr[0] + 0.7152 * arr[1] + 0.0722 * arr[2])


def wcag(a, b) -> float:
    l1, l2 = rel_lum(a), rel_lum(b)
    hi, lo = (l1, l2) if l1 >= l2 else (l2, l1)
    return (hi + 0.05) / (lo + 0.05)


def median_rgb(samples: np.ndarray) -> tuple[int, int, int]:
    if samples.size == 0:
        return (0, 0, 0)
    return tuple(int(x) for x in np.median(samples, axis=0))


def cream_mask(im: np.ndarray) -> np.ndarray:
    r = im[:, :, 0].astype(np.int16)
    g = im[:, :, 1].astype(np.int16)
    b = im[:, :, 2].astype(np.int16)
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    return (
        (r >= 150)
        & (r <= 225)
        & (g >= 105)
        & (g <= 185)
        & (b >= 60)
        & (b <= 130)
        & (r >= g + 18)
        & (r >= b + 28)
        & ((mx - mn) >= 28)
        & (g >= (0.62 * r))
        & (g <= (0.90 * r))
        & (b >= (0.32 * r))
        & (b <= (0.62 * r))
    )


def outline_mask(im: np.ndarray) -> np.ndarray:
    r = im[:, :, 0]
    g = im[:, :, 1]
    b = im[:, :, 2]
    return (r <= 70) & (g <= 55) & (b <= 48) & (r >= g) & (g >= b) & ((r.astype(np.int16) + g + b) < 150)


def platform_mask(im: np.ndarray) -> np.ndarray:
    r = im[:, :, 0].astype(np.int16)
    g = im[:, :, 1].astype(np.int16)
    b = im[:, :, 2].astype(np.int16)
    return (r < 95) & (g < 75) & (b < 60) & (r > 28) & (np.abs(r - 2 * b) < 40)


def sky_mask(im: np.ndarray) -> np.ndarray:
    r = im[:, :, 0].astype(np.int16)
    g = im[:, :, 1].astype(np.int16)
    b = im[:, :, 2].astype(np.int16)
    return (r >= 130) & (g >= 100) & (b >= 50) & (r >= g - 6) & (g >= b - 8) & ((r + g + b) > 300)


def cacao_mask(im: np.ndarray) -> np.ndarray:
    r = im[:, :, 0].astype(np.int16)
    g = im[:, :, 1].astype(np.int16)
    b = im[:, :, 2].astype(np.int16)
    return (r >= 140) & (r >= g + 8) & (g >= 40) & (b <= 120) & ((r - b) > 40) & (r > 150)


def densest_window(mask: np.ndarray, ww: int, hh: int, lo: int, hi: int) -> np.ndarray:
    h, w = mask.shape
    integral = np.pad(mask.astype(np.int32), ((1, 0), (1, 0))).cumsum(0).cumsum(1)
    best_n = -1
    best = (0, 0, w, h)
    step_y = max(1, hh // 4)
    step_x = max(1, ww // 4)
    for y0 in range(0, max(1, h - hh + 1), step_y):
        y1 = min(h, y0 + hh)
        for x0 in range(0, max(1, w - ww + 1), step_x):
            x1 = min(w, x0 + ww)
            n = int(integral[y1, x1] - integral[y0, x1] - integral[y1, x0] + integral[y0, x0])
            if lo < n < hi and n > best_n:
                best_n = n
                best = (x0, y0, x1, y1)
    out = np.zeros_like(mask)
    if best_n > 0:
        x0, y0, x1, y1 = best
        out[y0:y1, x0:x1] = mask[y0:y1, x0:x1]
        return out
    return mask


def neighbor_ring(mask: np.ndarray, rad: int) -> np.ndarray:
    from numpy.lib.stride_tricks import sliding_window_view

    h, w = mask.shape
    pad = np.pad(mask, rad, mode="constant", constant_values=False)
    win = sliding_window_view(pad, (2 * rad + 1, 2 * rad + 1))
    near = win.any(axis=(-1, -2))
    return near & ~mask


def measure_maya(path: Path, x_m=None) -> dict:
    im = np.array(Image.open(path).convert("RGB"))
    cream = cream_mask(im)
    n_cream = int(cream.sum())
    if n_cream > 200:
        cream = densest_window(cream, 40, 72, 30, 400)
        n_cream = int(cream.sum())
    if n_cream < 12:
        return {"file": path.name, "x_m": x_m, "error": "maya body not found", "cream_n": n_cream}
    ys, xs = np.where(cream)
    body_rgb = im[cream]
    outline = outline_mask(im)
    plat = platform_mask(im)
    sky = sky_mask(im)
    near = neighbor_ring(cream, 3)
    outline_rgb = im[near & outline]
    body_bg = im[near & ~cream & ~outline & ~plat]
    ring = neighbor_ring(cream, 12)
    outline_bg = im[ring & sky]
    extra_body = im[ring & ~cream & ~outline & ~plat & ~sky]
    if extra_body.size:
        body_bg = extra_body if body_bg.size == 0 else np.concatenate([body_bg, extra_body], axis=0)
    if outline_bg.shape[0] < 16:
        ring2 = neighbor_ring(cream, 22)
        outline_bg = im[ring2 & sky]
    body = median_rgb(body_rgb)
    ol = median_rgb(outline_rgb) if outline_rgb.size else (18, 12, 8)
    bg_body = median_rgb(body_bg) if body_bg.size else (200, 190, 150)
    bg_out = median_rgb(outline_bg) if outline_bg.size else bg_body
    br = wcag(body, bg_body)
    o_r = wcag(ol, bg_out)
    return {
        "file": path.name,
        "x_m": x_m,
        "cream_n": n_cream,
        "outline_n": int(outline_rgb.shape[0]) if outline_rgb.size else 0,
        "body_bg_n": int(body_bg.shape[0]) if body_bg.size else 0,
        "center_px": [round(float(xs.mean()), 1), round(float(ys.mean()), 1)],
        "body_rgb": list(body),
        "body_bg_rgb": list(bg_body),
        "outline_rgb": list(ol),
        "outline_bg_rgb": list(bg_out),
        "body_ratio": round(br, 2),
        "outline_ratio": round(o_r, 2),
        "body_pass": br >= 4.4,
        "outline_pass": o_r >= 4.4,
    }


def measure_cacao(path: Path) -> dict:
    im = np.array(Image.open(path).convert("RGB"))
    pods = cacao_mask(im)
    n = int(pods.sum())
    if n < 20:
        return {"file": path.name, "error": "cacao pods not found", "pod_n": n}
    if n > 800:
        pods = densest_window(pods, 72, 96, 30, 1200)
        n = int(pods.sum())
    ys, xs = np.where(pods)
    pod_rgb = im[pods]
    near = neighbor_ring(pods, 4)
    bg = im[near & ~pods]
    pod = median_rgb(pod_rgb)
    bgm = median_rgb(bg) if bg.size else (20, 16, 10)
    ratio = wcag(pod, bgm)
    return {
        "file": path.name,
        "pod_n": n,
        "center_px": [round(float(xs.mean()), 1), round(float(ys.mean()), 1)],
        "pod_rgb": list(pod),
        "bg_rgb": list(bgm),
        "ratio": round(ratio, 2),
        "pass": ratio >= 4.4,
    }


def main() -> int:
    maya = []
    files = [(DOCS / n, x) for n, x in SWEEP]
    extras = {
        "3d_entrance.png": 4.54,
        "3d_hazard.png": 133.33,
        "3d_cacao.png": 65.88,
    }
    seen = {p.name for p, _ in files}
    for name, x in extras.items():
        p = DOCS / name
        if p.exists() and name not in seen:
            files.append((p, x))
    for path, x_m in files:
        if not path.exists():
            maya.append({"file": path.name, "x_m": x_m, "error": "missing"})
            continue
        maya.append(measure_maya(path, x_m))
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
