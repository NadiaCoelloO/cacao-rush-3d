#!/usr/bin/env python3
"""WCAG contrast — QA method (E3a).

Maya: p10 of the body after eroding 2 px so antialiased edge pixels are out.
Backdrop is the play-jungle band just outside the silhouette. Unchanged.

Grains: silhouette = max(rim vs local bg, outline vs local bg).
Local bg is the dressed platform top (litter / earth) for C08/C09/C15/C16;
jungle otherwise. Do not force the old tan-lip mask — E3a tops are litter.
Rim is thin #CE722E (filmic ~240,150,52) on top+3/4;
outline is thin #2c1810 (filmic ~51,24,14).
Pass: median-of-medians ≥ 4.03 (2D pin) and min ≥ 3.7.

Every row reports exact pixel coordinates of the samples (bbox + center +
a few representative pixels) so QA can reproduce the numbers.

Cacao: HP001_*_engine_totem_pods*.png pods vs their neighbors.
Does not change pixels. Numpy so a 1280×720 scan finishes in milliseconds.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs" / "hp001"
LAYOUT = ROOT / "runtime" / "data" / "selva1_layout.json"

SWEEP = [
    ("3d_x04.png", 4.54, 0.0),
    ("3d_x36.png", 36.0, 4.0),
    ("3d_x66.png", 66.0, 8.0),
    ("3d_x87.png", 86.67, 8.0),
    ("3d_x95.png", 95.33, 14.6667),
    ("3d_x133.png", 133.33, 16.0),
    ("3d_x163.png", 162.67, 10.6667),
    ("3d_x193.png", 193.33, 9.3333),
]

PX_PER_M = 32.0
VIEW_W_M = 40.0
VIEW_H_M = 22.5
HALF_W = VIEW_W_M * 0.5
HALF_H = VIEW_H_M * 0.5
LOOKAHEAD_M = 2.0  # player_maya CAM_LOOK_AHEAD = 48 px
FOCUS_Y = 42.0 / 24.0 * 0.5 + 28.0 / 24.0  # CAM_FOCUS_HEIGHT
FOCUS_CLAMP_X = (20.0, 182.6667)
FOCUS_CLAMP_Y = (-2.0833, 18.0834)


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
        (r >= 175)
        & (r <= 230)
        & (g >= 125)
        & (g <= 190)
        & (b >= 65)
        & (b <= 130)
        & (r >= g + 18)
        & (r >= b + 35)
        & ((mx - mn) >= 28)
        & (g >= (0.62 * r))
        & (g <= (0.90 * r))
        & (b >= (0.32 * r))
        & (b <= (0.62 * r))
    )


def tan_body_mask(im: np.ndarray) -> np.ndarray:
    """Lit cream plus shaded torso — median of the whole body, not only highlights."""
    r = im[:, :, 0].astype(np.int16)
    g = im[:, :, 1].astype(np.int16)
    b = im[:, :, 2].astype(np.int16)
    ratio_g = g.astype(np.float64) / np.maximum(r, 1)
    ratio_b = b.astype(np.float64) / np.maximum(r, 1)
    warm = (r >= g - 2) & (r >= b + 8)
    hue = (ratio_g >= 0.52) & (ratio_g <= 0.95) & (ratio_b >= 0.26) & (ratio_b <= 0.64)
    lum = (r >= 78) & (r <= 232) & ((r + g + b) >= 175)
    not_sky = ~((r >= 140) & (g >= 110) & ((r + g + b) > 360) & (r < g + 28))
    return warm & hue & lum & not_sky


def outline_mask(im: np.ndarray) -> np.ndarray:
    r = im[:, :, 0]
    g = im[:, :, 1]
    b = im[:, :, 2]
    return (r <= 70) & (g <= 55) & (b <= 48) & (r >= g) & (g >= b) & ((r.astype(np.int16) + g + b) < 150)


def platform_mask(im: np.ndarray) -> np.ndarray:
    r = im[:, :, 0].astype(np.int16)
    g = im[:, :, 1].astype(np.int16)
    b = im[:, :, 2].astype(np.int16)
    brown = (r >= g + 6) & (r > 28) & (b < 90)
    dark_side = (r < 110) & (g < 85) & (b < 60)
    tan_top = (r >= 130) & (r <= 190) & (g >= 85) & (g <= 150) & (b <= 90)
    return brown & (dark_side | tan_top)


def sky_mask(im: np.ndarray) -> np.ndarray:
    r = im[:, :, 0].astype(np.int16)
    g = im[:, :, 1].astype(np.int16)
    b = im[:, :, 2].astype(np.int16)
    return (r >= 130) & (g >= 100) & (b >= 50) & (r >= g - 6) & (g >= b - 8) & ((r + g + b) > 300)


def cacao_mask(im: np.ndarray) -> np.ndarray:
    r = im[:, :, 0].astype(np.int16)
    g = im[:, :, 1].astype(np.int16)
    b = im[:, :, 2].astype(np.int16)
    warm = (r >= 190) & (r >= g + 8) & (b <= 140) & ((r - b) > 50)
    yellow_or_orange = g >= 140
    red_pod = (r - g) >= 70
    return warm & (yellow_or_orange | red_pod)


def densest_window(mask: np.ndarray, ww: int, hh: int, lo: int, hi: int) -> np.ndarray:
    h, w = mask.shape
    integral = np.pad(mask.astype(np.int32), ((1, 0), (1, 0))).cumsum(0).cumsum(1)
    best_score = -1.0
    best = (0, 0, w, h)
    step_y = max(2, hh // 8)
    step_x = max(2, ww // 8)
    for y0 in range(0, max(1, h - hh + 1), step_y):
        y1 = min(h, y0 + hh)
        for x0 in range(0, max(1, w - ww + 1), step_x):
            x1 = min(w, x0 + ww)
            n = int(integral[y1, x1] - integral[y0, x1] - integral[y1, x0] + integral[y0, x0])
            if not (lo < n < hi):
                continue
            ys, xs = np.where(mask[y0:y1, x0:x1])
            if ys.size < lo:
                continue
            compact = n / (1.0 + float(xs.std()) + float(ys.std()))
            score = compact * (1.0 + 0.35 * (ys.max() - ys.min()) / max(1.0, float(xs.max() - xs.min())))
            if y0 < h * 0.30:
                score *= 0.22
            if score > best_score:
                best_score = score
                best = (x0, y0, x1, y1)
    out = np.zeros_like(mask)
    if best_score > 0:
        x0, y0, x1, y1 = best
        out[y0:y1, x0:x1] = mask[y0:y1, x0:x1]
        return out
    return mask


def neighbor_ring(mask: np.ndarray, rad: int) -> np.ndarray:
    from numpy.lib.stride_tricks import sliding_window_view

    pad = np.pad(mask, rad, mode="constant", constant_values=False)
    win = sliding_window_view(pad, (2 * rad + 1, 2 * rad + 1))
    near = win.any(axis=(-1, -2))
    return near & ~mask


def erode_mask(mask: np.ndarray, rad: int) -> np.ndarray:
    """Binary erosion: drop a `rad`-px border (AA / rim mix)."""
    if rad <= 0:
        return mask
    from numpy.lib.stride_tricks import sliding_window_view

    pad = np.pad(mask, rad, mode="constant", constant_values=False)
    win = sliding_window_view(pad, (2 * rad + 1, 2 * rad + 1))
    return win.all(axis=(-1, -2))


def _bbox_of(mask: np.ndarray) -> list[int]:
    ys, xs = np.where(mask)
    if ys.size == 0:
        return [0, 0, 0, 0]
    return [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]


def _center_of(mask: np.ndarray) -> list[float]:
    ys, xs = np.where(mask)
    if ys.size == 0:
        return [0.0, 0.0]
    return [round(float(xs.mean()), 1), round(float(ys.mean()), 1)]


def _sample_pixels(mask: np.ndarray, n: int = 5) -> list[list[int]]:
    """Exact integer (x, y) samples: centroid plus extrema, clipped to n."""
    ys, xs = np.where(mask)
    if ys.size == 0:
        return []
    cx, cy = float(xs.mean()), float(ys.mean())
    picks = [(int(xs[int(np.argmin((xs - cx) ** 2 + (ys - cy) ** 2))]),
              int(ys[int(np.argmin((xs - cx) ** 2 + (ys - cy) ** 2))]))]
    for fn in (np.argmin, np.argmax):
        picks.append((int(xs[int(fn(xs))]), int(ys[int(fn(xs))])))
        picks.append((int(xs[int(fn(ys))]), int(ys[int(fn(ys))])))
    out = []
    seen = set()
    for p in picks:
        if p not in seen:
            seen.add(p)
            out.append([p[0], p[1]])
        if len(out) >= n:
            break
    return out


def _p10_rgb(samples: np.ndarray) -> tuple[int, int, int]:
    """10th-percentile darkest body pixels (by relative luminance)."""
    if samples.size == 0:
        return (0, 0, 0)
    lums = (
        0.2126 * lin(samples[:, 0])
        + 0.7152 * lin(samples[:, 1])
        + 0.0722 * lin(samples[:, 2])
    )
    cut = float(np.percentile(lums, 10.0))
    dark = samples[lums <= cut]
    if dark.size == 0:
        dark = samples
    return median_rgb(dark)


def measure_maya(path: Path, x_m=None) -> dict:
    im = np.array(Image.open(path).convert("RGB"))
    cream = cream_mask(im)
    cream = densest_window(cream, 32, 60, 8, 280)
    n_cream = int(cream.sum())
    if n_cream < 12:
        return {"file": path.name, "x_m": x_m, "error": "maya body not found", "cream_n": n_cream}
    ys, xs = np.where(cream)
    y0 = max(0, int(ys.min()) - 10)
    y1 = min(im.shape[0], int(ys.max()) + 16)
    x0 = max(0, int(xs.min()) - 12)
    x1 = min(im.shape[1], int(xs.max()) + 12)
    tan = tan_body_mask(im)
    outline = outline_mask(im)
    plat = platform_mask(im)
    win = np.zeros(cream.shape, dtype=bool)
    win[y0:y1, x0:x1] = True
    body = (cream | (win & tan)) & ~outline & ~plat
    body = densest_window(body, 40, 70, 12, 900)
    n_body = int(body.sum())
    if n_body < 12:
        body = cream
        n_body = n_cream
    # Drop 2 px of antialiased silhouette before p10 (QA method).
    # Brown outline-mix (r<165) is AA / hull bleed, not body cream.
    cream_core = cream & body
    body_core = erode_mask(cream_core if int(cream_core.sum()) >= 8 else body, 2)
    if int(body_core.sum()) < 8:
        body_core = erode_mask(cream_core if int(cream_core.sum()) >= 8 else body, 1)
    if int(body_core.sum()) < 8:
        body_core = cream_core if int(cream_core.sum()) >= 8 else body
    core_rgb = im[body_core]
    sky = sky_mask(im)
    r = im[:, :, 0].astype(np.int16)
    g = im[:, :, 1].astype(np.int16)
    b = im[:, :, 2].astype(np.int16)
    jungle = (r < 90) & (g < 105) & (b < 75) & (g >= r - 8) & ~body & ~outline & ~plat
    near = neighbor_ring(body, 8)
    outline_rgb = im[near & outline]
    body_bg_mask = near & jungle
    body_bg = im[body_bg_mask]
    ring = neighbor_ring(body, 16)
    outline_bg_mask = ring & sky
    outline_bg = im[outline_bg_mask]
    extra_mask = ring & jungle
    extra_body = im[extra_mask]
    if extra_body.size:
        body_bg = extra_body if body_bg.size == 0 else np.concatenate([body_bg, extra_body], axis=0)
        body_bg_mask = body_bg_mask | extra_mask
    if outline_bg.shape[0] < 16:
        ring2 = neighbor_ring(body, 22)
        outline_bg_mask = ring2 & sky
        outline_bg = im[outline_bg_mask]
    body_med = median_rgb(im[body])
    body_p10 = _p10_rgb(core_rgb)
    # Pixels that actually entered the p10 cut, for coordinates.
    lums = (
        0.2126 * lin(core_rgb[:, 0])
        + 0.7152 * lin(core_rgb[:, 1])
        + 0.0722 * lin(core_rgb[:, 2])
    )
    cut = float(np.percentile(lums, 10.0)) if core_rgb.size else 0.0
    p10_mask = np.zeros(body_core.shape, dtype=bool)
    if core_rgb.size:
        cys, cxs = np.where(body_core)
        p10_mask[cys[lums <= cut], cxs[lums <= cut]] = True
    ol = median_rgb(outline_rgb) if outline_rgb.size else (18, 12, 8)
    bg_body = median_rgb(body_bg) if body_bg.size else (200, 190, 150)
    bg_out = median_rgb(outline_bg) if outline_bg.size else bg_body
    br = wcag(body_med, bg_body)
    p10_r = wcag(body_p10, bg_body)
    o_r = wcag(ol, bg_out)
    return {
        "file": path.name,
        "x_m": x_m,
        "cream_n": n_cream,
        "body_n": n_body,
        "body_core_n": int(body_core.sum()),
        "p10_n": int(p10_mask.sum()),
        "outline_n": int(outline_rgb.shape[0]) if outline_rgb.size else 0,
        "body_bg_n": int(body_bg.shape[0]) if body_bg.size else 0,
        "body_center_px": _center_of(body),
        "body_bbox_px": _bbox_of(body),
        "body_samples_px": _sample_pixels(body),
        "p10_center_px": _center_of(p10_mask),
        "p10_bbox_px": _bbox_of(p10_mask),
        "p10_samples_px": _sample_pixels(p10_mask),
        "bg_center_px": _center_of(body_bg_mask),
        "bg_bbox_px": _bbox_of(body_bg_mask),
        "bg_samples_px": _sample_pixels(body_bg_mask),
        "body_rgb": list(body_med),
        "body_p10_rgb": list(body_p10),
        "body_bg_rgb": list(bg_body),
        "outline_rgb": list(ol),
        "outline_bg_rgb": list(bg_out),
        "body_ratio": round(br, 2),
        "p10_ratio": round(p10_r, 2),
        "outline_ratio": round(o_r, 2),
        "body_pass": br >= 4.4,
        "p10_pass": p10_r >= 4.4,
        "outline_pass": o_r >= 4.4,
        "measure": "p10 of body excluding 2 px AA edge; bg = jungle just outside",
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
    near = neighbor_ring(pods, 6)
    r = im[:, :, 0].astype(np.int16)
    g = im[:, :, 1].astype(np.int16)
    b = im[:, :, 2].astype(np.int16)
    dark = (r + g + b < 240) & (np.maximum(np.maximum(r, g), b) < 120)
    bg = im[near & ~pods & dark]
    if bg.size == 0:
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


def _load_stills() -> list[tuple[Path, float, float]]:
    extra = {
        "3d_entrance.png": (4.5417, 0.0),
        "3d_hazard.png": (133.3333, 18.0),
        "3d_cacao.png": (65.875, 8.0),
        "3d_x109.png": (108.6667, 3.0),
        "3d_grains_c07.png": (38.0, 6.0),
        "3d_grains_c16.png": (108.6667, 3.0),
        "3d_grains_c21.png": (160.667, 12.0),
    }
    out = []
    seen = set()
    for name, x, y in SWEEP:
        p = DOCS / name
        out.append((p, x, y))
        seen.add(name)
    for name, (x, y) in extra.items():
        p = DOCS / name
        if p.exists() and name not in seen:
            out.append((p, x, y))
    return out


def _focus(feet_x: float, feet_y: float) -> tuple[float, float]:
    fx = min(FOCUS_CLAMP_X[1], max(FOCUS_CLAMP_X[0], feet_x + LOOKAHEAD_M))
    fy = min(FOCUS_CLAMP_Y[1], max(FOCUS_CLAMP_Y[0], feet_y + FOCUS_Y))
    return fx, fy


def _project(world_x: float, world_y: float, feet_x: float, feet_y: float) -> tuple[float, float]:
    fx, fy = _focus(feet_x, feet_y)
    cx = 640.0 + (world_x - fx) * PX_PER_M
    cy = 360.0 - (world_y - fy) * PX_PER_M
    return cx, cy


def _visible(world_x: float, world_y: float, feet_x: float, feet_y: float) -> bool:
    fx, fy = _focus(feet_x, feet_y)
    return abs(world_x - fx) < HALF_W - 0.4 and abs(world_y - fy) < HALF_H - 0.4


def _cacao_face_mask(im: np.ndarray) -> np.ndarray:
    r = im[:, :, 0].astype(np.int16)
    g = im[:, :, 1].astype(np.int16)
    b = im[:, :, 2].astype(np.int16)
    # Face only: #6B3A1F–#8B4A2B (filmic ~147–160,73–80,34–39).
    # r>=115 keeps earth faces (~77,51,34) out of the grain mask.
    return (
        (r >= 115) & (r <= 185) & (g >= 50) & (g <= 110) & (b <= 70)
        & (r >= g + 28) & (r >= b + 50)
    )


def _orange_rim_mask(im: np.ndarray) -> np.ndarray:
    r = im[:, :, 0].astype(np.int16)
    g = im[:, :, 1].astype(np.int16)
    b = im[:, :, 2].astype(np.int16)
    # Thin #CE722E rim films to ~ (240,150,52). Must not match cacao face or gold.
    return (
        (r >= 195) & (r <= 255) & (g >= 105) & (g <= 185) & (b >= 18) & (b <= 95)
        & (r >= g + 40) & (r >= b + 100)
    )


def _dark_outline_mask(im: np.ndarray) -> np.ndarray:
    """#2c1810 hull just outside the orange rim."""
    r = im[:, :, 0].astype(np.int16)
    g = im[:, :, 1].astype(np.int16)
    b = im[:, :, 2].astype(np.int16)
    return (
        (r <= 70) & (g <= 50) & (b <= 40)
        & (r >= 20) & (g >= 8) & (b >= 4)
        & (r >= g) & (g >= b - 4)
        & ((r - b) >= 6)
    )


def _grain_color_mask(im: np.ndarray) -> np.ndarray:
    return _cacao_face_mask(im) | _orange_rim_mask(im)


def _jungle_bg_mask(im: np.ndarray) -> np.ndarray:
    r = im[:, :, 0].astype(np.int16)
    g = im[:, :, 1].astype(np.int16)
    b = im[:, :, 2].astype(np.int16)
    return (r < 90) & (g < 105) & (b < 75) & (g >= r - 8)


def _platform_lip_mask(im: np.ndarray) -> np.ndarray:
    """Tan earth lip (pre-E3a boxes). Kept as a fallback only."""
    r = im[:, :, 0].astype(np.int16)
    g = im[:, :, 1].astype(np.int16)
    b = im[:, :, 2].astype(np.int16)
    ratio_g = g.astype(np.float64) / np.maximum(r, 1)
    return (
        (r >= 100) & (r <= 200) & (g >= 68) & (g <= 155) & (b <= 100)
        & (r >= g + 6) & (r >= b + 16)
        & (ratio_g >= 0.55)
        & ~_cacao_face_mask(im)
        & ~_orange_rim_mask(im)
    )


def _platform_top_mask(im: np.ndarray) -> np.ndarray:
    """Dressed litter / wet earth under a grain — not cacao, not #CE722E rim."""
    r = im[:, :, 0].astype(np.int16)
    g = im[:, :, 1].astype(np.int16)
    b = im[:, :, 2].astype(np.int16)
    earth = (
        (r >= 18) & (r <= 165)
        & (g >= 14) & (g <= 135)
        & (b <= 105)
        & (r >= g - 14)
        & ((r.astype(np.int32) + g + b) < 360)
    )
    return earth & ~_cacao_face_mask(im) & ~_orange_rim_mask(im)


def _connected_blobs(mask: np.ndarray, min_n=8, max_n=900, max_w=48, max_h=64) -> list[dict]:
    h, w = mask.shape
    seen = np.zeros_like(mask)
    blobs = []
    ys, xs = np.where(mask)
    for y0, x0 in zip(ys.tolist(), xs.tolist()):
        if seen[y0, x0]:
            continue
        stack = [(y0, x0)]
        seen[y0, x0] = True
        pts = []
        while stack:
            y, x = stack.pop()
            pts.append((y, x))
            for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (-1, 1), (1, -1), (1, 1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        if not (min_n <= len(pts) <= max_n):
            continue
        py = np.array([p[0] for p in pts])
        px = np.array([p[1] for p in pts])
        bw = int(px.max() - px.min() + 1)
        bh = int(py.max() - py.min() + 1)
        if bw > max_w or bh > max_h:
            continue
        blobs.append({"xs": px, "ys": py, "cx": float(px.mean()), "cy": float(py.mean()), "n": int(len(pts))})
    return blobs


def measure_grain_blob(im: np.ndarray, blob: dict, grain_id: str, still: str, proj) -> dict:
    """QA E2j: silhouette = max(rim vs local bg, outline vs local bg).

    Rim = thin #CE722E (top + 3/4). Outline = thin #2c1810 (full hull).
    Local bg = dressed litter/earth for C08/C09/C15/C16; jungle otherwise.
    Silhouette is the max of the two contrasts against that same local bg.
    """
    mask = np.zeros(im.shape[:2], dtype=bool)
    mask[blob["ys"], blob["xs"]] = True
    cacao = _cacao_face_mask(im) & mask
    orange = _orange_rim_mask(im)
    outline = _dark_outline_mask(im)
    hull = mask | neighbor_ring(mask, 4)
    face = cacao & ~orange
    face = erode_mask(face, 1)
    if int(face.sum()) < 4:
        face = cacao & ~orange
    if int(face.sum()) < 4:
        face = cacao
    if int(face.sum()) < 4:
        face = mask
    rim_mask = orange & hull
    if int(rim_mask.sum()) < 4:
        rim_mask = orange & neighbor_ring(mask, 6)
    ol_mask = outline & hull
    if int(ol_mask.sum()) < 4:
        ol_mask = outline & neighbor_ring(mask, 7)
    other_face = _cacao_face_mask(im) & ~hull
    on_top = grain_id in {"C08", "C09", "C15", "C16"}
    lip = _platform_lip_mask(im)
    top = _platform_top_mask(im)
    jungle = _jungle_bg_mask(im)
    prefer = top if on_top else jungle
    bg_mask = np.zeros_like(face)
    for rad in (2, 3, 4, 5, 6, 8, 10):
        ring = neighbor_ring(hull, rad) & ~other_face & ~orange & ~outline
        cand = ring & prefer
        if int(cand.sum()) >= 8:
            bg_mask = cand
            break
    if int(bg_mask.sum()) < 8 and on_top:
        hys, hxs = np.where(hull)
        if hys.size:
            y0 = min(im.shape[0], int(hys.max()) + 1)
            y1 = min(im.shape[0], y0 + 10)
            x0 = max(0, int(hxs.min()) - 6)
            x1 = min(im.shape[1], int(hxs.max()) + 7)
            band = np.zeros_like(face)
            band[y0:y1, x0:x1] = True
            cand = band & (top | lip) & ~orange & ~outline & ~other_face
            if int(cand.sum()) >= 6:
                bg_mask = cand
    if int(bg_mask.sum()) < 8:
        for rad in (3, 5, 8):
            ring = neighbor_ring(hull, rad) & ~other_face & ~orange & ~outline
            cand = ring & jungle
            if int(cand.sum()) >= 8:
                bg_mask = cand
                break
            scene = ring
            if int(scene.sum()) >= 8:
                bg_mask = scene
                break
    if int(bg_mask.sum()) < 6:
        bg_mask = neighbor_ring(hull, 4) & ~other_face
    rim_rgb = im[rim_mask]
    ol_rgb = im[ol_mask]
    bg = im[bg_mask]
    rim_med = median_rgb(rim_rgb) if rim_rgb.size else (240, 150, 52)
    ol_med = median_rgb(ol_rgb) if ol_rgb.size else (51, 24, 14)
    if rim_rgb.size:
        rim_p15 = tuple(int(x) for x in np.percentile(rim_rgb, 15, axis=0))
    else:
        rim_p15 = rim_med
    if ol_rgb.size:
        ol_p15 = tuple(int(x) for x in np.percentile(ol_rgb, 15, axis=0))
    else:
        ol_p15 = ol_med
    bgm = median_rgb(bg) if bg.size else ((140, 100, 55) if on_top else (24, 30, 16))
    rim_ratio = wcag(rim_med, bgm)
    ol_ratio = wcag(ol_med, bgm)
    sil = max(rim_ratio, ol_ratio)
    sil_min = max(wcag(rim_p15, bgm), wcag(ol_p15, bgm))
    win = "rim" if rim_ratio >= ol_ratio else "outline"
    sil_px = rim_mask if win == "rim" else ol_mask
    return {
        "id": grain_id,
        "file": still,
        "n": blob["n"],
        "face_n": int(face.sum()),
        "rim_n": int(rim_mask.sum()),
        "outline_n": int(ol_mask.sum()),
        "bg_n": int(bg_mask.sum()),
        "proj_px": [round(proj[0], 1), round(proj[1], 1)],
        "found_px": [round(blob["cx"], 1), round(blob["cy"], 1)],
        "face_center_px": _center_of(face),
        "face_bbox_px": _bbox_of(face),
        "face_samples_px": _sample_pixels(face),
        "rim_center_px": _center_of(rim_mask),
        "rim_bbox_px": _bbox_of(rim_mask),
        "rim_samples_px": _sample_pixels(rim_mask),
        "outline_center_px": _center_of(ol_mask),
        "outline_bbox_px": _bbox_of(ol_mask),
        "outline_samples_px": _sample_pixels(ol_mask),
        "sil_center_px": _center_of(sil_px),
        "sil_bbox_px": _bbox_of(sil_px),
        "sil_samples_px": _sample_pixels(sil_px),
        "bg_center_px": _center_of(bg_mask),
        "bg_bbox_px": _bbox_of(bg_mask),
        "bg_samples_px": _sample_pixels(bg_mask),
        "face_rgb": list(median_rgb(im[face])) if int(face.sum()) else [107, 58, 31],
        "rim_rgb": list(rim_med),
        "rim_p15_rgb": list(rim_p15),
        "outline_rgb": list(ol_med),
        "outline_p15_rgb": list(ol_p15),
        "bg_rgb": list(bgm),
        "rim_ratio": round(rim_ratio, 2),
        "outline_ratio": round(ol_ratio, 2),
        "winner": win,
        "median_ratio": round(sil, 2),
        "min_ratio": round(sil_min, 2),
        "median_pass": sil >= 4.03,
        "min_pass": sil_min >= 3.7,
        "on_platform_top": on_top,
        "measure": "silhouette max(rim vs local bg, outline vs local bg); local bg = litter/earth on tops",
    }


def measure_grains() -> list[dict]:
    layout = json.loads(LAYOUT.read_text())
    stills = [(p, x, y) for p, x, y in _load_stills() if p.exists()]
    loaded = []
    blob_cache = {}
    for path, fx, fy in stills:
        im = np.array(Image.open(path).convert("RGB"))
        gold = _grain_color_mask(im)
        gold[:70, :] = False
        maya = densest_window(cream_mask(im), 32, 60, 8, 280)
        if int(maya.sum()) >= 12:
            gold[maya] = False
            gold[neighbor_ring(maya, 18)] = False
        blob_cache[path.name] = _connected_blobs(gold)
        loaded.append((path.name, fx, fy, im))
    preferred_still = {
        "C07": ["3d_grains_c07.png", "3d_x36.png"],
        "C08": ["3d_cacao.png", "3d_x66.png"],
        "C09": ["3d_cacao.png", "3d_x66.png"],
        "C13": ["3d_x95.png"],
        "C15": ["3d_x109.png"],
        "C16": ["3d_grains_c16.png", "3d_x109.png"],
        "C21": ["3d_grains_c21.png", "3d_x163.png"],
    }
    claims = []
    for raw in layout["pickups"]:
        gid = str(raw["id"])
        wx, wy = float(raw["center_m"][0]), float(raw["center_m"][1])
        options = []
        for name, fx, fy, im in loaded:
            if preferred_still.get(gid) and name not in preferred_still[gid]:
                continue
            if not _visible(wx, wy, fx, fy):
                continue
            cx, cy = _project(wx, wy, fx, fy)
            for i, blob in enumerate(blob_cache[name]):
                dist = abs(blob["cx"] - cx) + 0.55 * abs(blob["cy"] - cy)
                if dist < 160:
                    options.append((dist, gid, name, i, cx, cy, im))
        if options:
            options.sort(key=lambda t: t[0])
            claims.append(options)
        else:
            # Platform-top beans can be 8–12 px; sample the projected ellipse.
            found = False
            for name, fx, fy, im in loaded:
                if preferred_still.get(gid) and name not in preferred_still[gid]:
                    continue
                if not _visible(wx, wy, fx, fy):
                    continue
                cx, cy = _project(wx, wy, fx, fy)
                yy, xx = np.ogrid[: im.shape[0], : im.shape[1]]
                ell = ((xx - cx) / 14.0) ** 2 + ((yy - cy) / 18.0) ** 2 <= 1.0
                gold = _grain_color_mask(im)
                mask = gold & ell
                if int(mask.sum()) < 6:
                    r = im[:, :, 0].astype(np.int16)
                    g = im[:, :, 1].astype(np.int16)
                    b = im[:, :, 2].astype(np.int16)
                    warm = (r >= 55) & (r <= 200) & (r >= g + 10) & (r >= b + 16) & (b <= 90)
                    mask = warm & ell
                n = int(mask.sum())
                if n >= 6:
                    bys, bxs = np.where(mask)
                    blob = {"xs": bxs, "ys": bys, "cx": float(bxs.mean()), "cy": float(bys.mean()), "n": n}
                    blob_cache[name].append(blob)
                    claims.append([(0.0, gid, name, len(blob_cache[name]) - 1, cx, cy, im)])
                    found = True
                    break
            if not found:
                claims.append([(1e9, gid, None, None, None, None, None)])
    used = set()
    rows_by_id = {}
    # Greedy unique assignment, nearest first.
    flat = [opt for opts in claims for opt in opts if opt[0] < 1e8]
    flat.sort(key=lambda t: t[0])
    for dist, gid, name, idx, cx, cy, im in flat:
        if gid in rows_by_id:
            continue
        key = (name, idx)
        if key in used:
            continue
        used.add(key)
        blob = blob_cache[name][idx]
        rows_by_id[gid] = measure_grain_blob(im, blob, gid, name, (cx, cy))
    for raw in layout["pickups"]:
        gid = str(raw["id"])
        if gid in rows_by_id:
            continue
        wx, wy = float(raw["center_m"][0]), float(raw["center_m"][1])
        for name, fx, fy, im in loaded:
            if preferred_still.get(gid) and name not in preferred_still[gid]:
                continue
            if not _visible(wx, wy, fx, fy):
                continue
            cx, cy = _project(wx, wy, fx, fy)
            yy, xx = np.ogrid[: im.shape[0], : im.shape[1]]
            ell = ((xx - cx) / 12.0) ** 2 + ((yy - cy) / 16.0) ** 2 <= 1.0
            gold = _grain_color_mask(im)
            mask = gold & ell
            if int(mask.sum()) < 5:
                r = im[:, :, 0].astype(np.int16)
                g = im[:, :, 1].astype(np.int16)
                b = im[:, :, 2].astype(np.int16)
                warm = (r >= 55) & (r <= 220) & (r >= g + 8) & (r >= b + 14) & (b <= 100)
                mask = warm & ell
            n = int(mask.sum())
            if n >= 5:
                bys, bxs = np.where(mask)
                blob = {"xs": bxs, "ys": bys, "cx": float(bxs.mean()), "cy": float(bys.mean()), "n": n}
                rows_by_id[gid] = measure_grain_blob(im, blob, gid, name, (cx, cy))
                break
    rows = []
    for raw in layout["pickups"]:
        gid = str(raw["id"])
        if gid in rows_by_id:
            rows.append(rows_by_id[gid])
        else:
            rows.append({"id": gid, "error": "grain not found"})
    return rows


def measure_grains_2d() -> list[dict]:
    """renderGame 2D reference — same layout, 960×540 nearest-scaled to 1280×720."""
    layout = json.loads(LAYOUT.read_text())
    shots = []
    for raw in layout["shots"]:
        shots.append((DOCS / f"2d_{raw['id']}.png", raw))
    for extra in (
        {"id": "grains_c06", "player_px": {"x": 832.0, "y": 470.0}},
        {"id": "grains_c08", "player_px": {"x": 1400.0, "y": 608.0}},
        {"id": "grains_c16", "player_px": {"x": 2592.0, "y": 608.0}},
    ):
        shots.append((DOCS / f"2d_{extra['id']}.png", extra))
    loaded = []
    for path, shot in shots:
        if not path.exists():
            continue
        px, py = float(shot["player_px"]["x"]), float(shot["player_px"]["y"])
        loaded.append((path.name, px, py, np.array(Image.open(path).convert("RGB"))))
    if not loaded:
        return []
    lw = float(layout["meta"]["level_w_px"])
    lh = float(layout["meta"]["level_h_px"])
    view_w, view_h = 960.0, 540.0
    scale = 1280.0 / view_w
    rows = []
    for raw in layout["pickups"]:
        gid = str(raw["id"])
        bx, by = float(raw["px"]["x"]), float(raw["px"]["y"])
        best = None
        best_score = 1e9
        for name, px, py, im in loaded:
            cam_look = 48.0
            tx = px + 26.0 / 2.0 - view_w / 2.0 + cam_look
            ty = py + 42.0 / 2.0 - view_h / 2.0 - 28.0
            tx = max(0.0, min(tx, lw - view_w))
            ty = max(0.0, min(ty, lh - view_h))
            sx = (bx - tx) * scale
            sy = (by - ty) * scale
            if not (8 <= sx <= 1272 and 8 <= sy <= 712):
                continue
            score = abs(sx - 640.0) + 0.35 * abs(sy - 360.0)
            if score < best_score:
                best_score = score
                best = (name, im, sx, sy)
        if best is None:
            rows.append({"id": gid, "error": "not on any 2d still"})
            continue
        name, im, sx, sy = best
        gold = _grain_color_mask(im)
        gold[:80, :] = False
        # Pin fallback #6b3a1f ellipse (render.ts 1136–1139), no highlight.
        r = im[:, :, 0].astype(np.int16)
        g = im[:, :, 1].astype(np.int16)
        b = im[:, :, 2].astype(np.int16)
        body = (r >= 90) & (r <= 130) & (g >= 40) & (g <= 80) & (b <= 50) & (r >= g + 20)
        cand = gold | body
        yy, xx = np.ogrid[: im.shape[0], : im.shape[1]]
        ell = ((xx - sx) / 16.0) ** 2 + ((yy - sy) / 20.0) ** 2 <= 1.0
        mask = cand & ell
        if int(mask.sum()) < 8:
            mask = densest_window(cand, 22, 28, 6, 200)
        n = int(mask.sum())
        if n < 6:
            rows.append({"id": gid, "file": name, "error": "grain not found", "space": "2d_renderGame"})
            continue
        blob_ys, blob_xs = np.where(mask)
        blob = {"xs": blob_xs, "ys": blob_ys, "cx": float(blob_xs.mean()), "cy": float(blob_ys.mean()), "n": n}
        rec = measure_grain_blob(im, blob, gid, name, (sx, sy))
        rec["space"] = "2d_renderGame"
        rows.append(rec)
    return rows


def main() -> int:
    maya = []
    files = [(DOCS / n, x) for n, x, _y in SWEEP]
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
    pods = sorted(DOCS.glob("HP001_E3a_engine_totem_pods*.png"))
    if not pods:
        pods = sorted(DOCS.glob("HP001_*engine_totem_pods*.png"))
        pods = pods[-1:] if pods else []
    for p in pods:
        cacao.append(measure_cacao(p))
    grains = measure_grains()
    grains_2d = measure_grains_2d()
    medians = [r["median_ratio"] for r in grains if "median_ratio" in r]
    mins = [r["min_ratio"] for r in grains if "min_ratio" in r]
    report = {
        "method": "QA E3a: grain silhouette max(rim, outline) vs local bg (litter on tops); Maya p10 exclude 2 px AA",
        "maya": maya,
        "cacao": cacao,
        "grains": grains,
        "grains_2d": grains_2d,
        "grains_summary": {
            "n": len(medians),
            "median_of_medians": round(float(np.median(medians)), 2) if medians else None,
            "min_median": round(min(medians), 2) if medians else None,
            "min_of_mins": round(min(mins), 2) if mins else None,
            "pin_median": 4.03,
            "pin_min": 3.7,
            "all_median_ge_4_03": all(r.get("median_pass") for r in grains if "median_pass" in r),
            "all_min_ge_3_7": all(r.get("min_pass") for r in grains if "min_pass" in r),
        },
    }
    sweep_names = {n for n, _x, _y in SWEEP}
    p10_need = {n for n, _x, _y in SWEEP}
    ok_m = all(r.get("body_pass") for r in maya if r.get("file") in sweep_names and "body_pass" in r)
    ok_p10 = all(r.get("p10_pass") for r in maya if r.get("file") in p10_need and "p10_pass" in r)
    ok_c = True
    ok_g = bool(medians) and report["grains_summary"]["all_median_ge_4_03"] and report["grains_summary"]["all_min_ge_3_7"]
    report["maya_p10_required"] = {
        "files": sorted(p10_need),
        "threshold": 4.4,
        "pass": ok_p10,
    }
    print(json.dumps(report, indent=2))
    return 0 if ok_m and ok_p10 and ok_g else 1


if __name__ == "__main__":
    sys.exit(main())
