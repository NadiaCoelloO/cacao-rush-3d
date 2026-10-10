#!/usr/bin/env python3
"""Draw selva-1 like Cacao.Game renderGame (960×540), then nearest-scale to 1280×720.

followCam at time=0 with camLook=48 (facing right, settled). Same 2D AABB as
levels.ts after sitSpikes/freeCoins. No sprites: Maya is the teal preview box
(#3d8a72) used when art.character is missing.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
LAYOUT = ROOT / "runtime" / "data" / "selva1_layout.json"
SKY = ROOT / "runtime" / "textures" / "hp001_jungle_sky_2d.jpg"
OUT_DIR = ROOT / "docs" / "hp001"

VIEW_W, VIEW_H = 960, 540
PH, PW = 42, 26
FOG = (16, 32, 24)
MAYA = (61, 138, 114)
EARTH = (62, 44, 28)
EARTH_TOP = (86, 62, 36)
CRUMBLE = (48, 34, 22)
CRATE = (107, 66, 40)
ONEWAY = (243, 230, 208)
SPIKE = (201, 196, 188)
FROG = (62, 118, 56)
ROCK = (96, 76, 56)
WIND = (200, 220, 184)
BEAN = (107, 58, 31)
POLE = (106, 90, 74)
GOAL = (166, 106, 42)


def follow_cam(px, py):
    cam_look = 48.0
    tx = px + PW / 2.0 - VIEW_W / 2.0 + cam_look
    ty = py + PH / 2.0 - VIEW_H / 2.0 - 28.0
    layout = json.loads(LAYOUT.read_text())
    lw = layout["meta"]["level_w_px"]
    lh = layout["meta"]["level_h_px"]
    tx = max(0.0, min(tx, lw - VIEW_W))
    ty = max(0.0, min(ty, lh - VIEW_H))
    return tx, ty


def draw_shot(layout, shot, out_path: Path) -> None:
    px, py = shot["player_px"]["x"], shot["player_px"]["y"]
    cam_x, cam_y = follow_cam(px, py)
    img = Image.new("RGB", (VIEW_W, VIEW_H), FOG)
    if SKY.exists():
        sky = Image.open(SKY).convert("RGB")
        # Crop the cloud band; Cuyabeno is flat — drop distant hills/falls.
        w, h = sky.size
        band = sky.crop((0, int(h * 0.08), w, int(h * 0.62)))
        band = band.resize((VIEW_W + 80, VIEW_H + 70), Image.BILINEAR)
        img.paste(band, (-40, -30))
    d = ImageDraw.Draw(img, "RGBA")

    def vis(x, y, w, h, pad=64):
        return x + w >= cam_x - pad and x <= cam_x + VIEW_W + pad and y + h >= cam_y - pad and y <= cam_y + VIEW_H + pad

    for p in layout["platforms"]:
        box = p["px"]
        x, y, w, h = box["x"], box["y"], box["w"], box["h"]
        if not vis(x, y, w, h):
            continue
        sx, sy = x - cam_x, y - cam_y
        kind = p["kind"]
        if kind == "oneway":
            d.rectangle([sx, sy, sx + w, sy + min(14, h)], fill=(243, 230, 208, 46))
            d.rectangle([sx + 2, sy, sx + w - 2, sy + 4], fill=(243, 230, 208, 160))
        elif kind == "crate":
            d.rounded_rectangle([sx, sy, sx + w, sy + h], radius=4, fill=CRATE, outline=(44, 24, 16))
        elif kind == "crumble":
            d.rectangle([sx, sy, sx + w, sy + h], fill=CRUMBLE)
            d.rectangle([sx, sy, sx + w, sy + 5], fill=EARTH_TOP)
        elif kind == "moving":
            d.rectangle([sx, sy, sx + w, sy + h], fill=EARTH_TOP)
            d.rectangle([sx, sy, sx + w, sy + 4], fill=ONEWAY)
        else:
            d.rectangle([sx, sy, sx + w, sy + h], fill=EARTH)
            d.rectangle([sx, sy, sx + w, sy + 6], fill=EARTH_TOP)

    for h in layout["hazards"]:
        box = h["px"]
        x, y, w, hh = box["x"], box["y"], box["w"], box["h"]
        if not vis(x, y, w, hh):
            continue
        sx, sy = x - cam_x, y - cam_y
        kind = h["kind"]
        if kind == "spikes":
            n = max(1, int(round(w / 16)))
            bw = w / n
            for i in range(n):
                x0 = sx + i * bw
                d.polygon([(x0, sy + hh), (x0 + bw, sy + hh), (x0 + bw * 0.5, sy)], fill=SPIKE)
        elif kind == "frog":
            d.ellipse([sx, sy, sx + w, sy + hh], fill=FROG)
        elif kind == "rock":
            d.ellipse([sx, sy, sx + w, sy + hh], fill=ROCK)
        elif kind == "wind":
            d.rectangle([sx, sy, sx + w, sy + hh], fill=(200, 220, 184, 28))
            for row in range(8, int(hh), 24):
                for col in range(-20, int(w) + 20, 48):
                    x0 = sx + col + (row % 36)
                    y0 = sy + row
                    d.line([(x0, y0), (x0 + 14, y0)], fill=(243, 230, 208, 150), width=2)

    for c in layout["pickups"]:
        x, y, r = c["px"]["x"], c["px"]["y"], c["px"]["r"]
        if not vis(x - r, y - r, r * 2, r * 2):
            continue
        sx, sy = x - cam_x, y - cam_y
        d.ellipse([sx - 8, sy - 11, sx + 8, sy + 11], fill=BEAN)

    for k in layout["checkpoints"]:
        box = k["px"]
        sx, sy = box["x"] - cam_x, box["y"] - cam_y
        d.rectangle([sx, sy, sx + box["w"], sy + box["h"]], fill=POLE)

    g = layout["goal"]["px"]
    sx, sy = g["x"] - cam_x, g["y"] - cam_y
    d.ellipse([sx, sy, sx + g["w"], sy + g["h"]], fill=GOAL)

    mx, my = px - cam_x, py - cam_y
    d.rounded_rectangle([mx, my, mx + PW, my + PH], radius=6, fill=MAYA)

    out = img.resize((1280, 720), Image.NEAREST)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out.save(out_path)
    print(f"wrote {out_path} cam=({cam_x:.1f},{cam_y:.1f}) player=({px},{py})")


def main():
    layout = json.loads(LAYOUT.read_text())
    for shot in layout["shots"]:
        draw_shot(layout, shot, OUT_DIR / f"2d_{shot['id']}.png")


if __name__ == "__main__":
    main()
