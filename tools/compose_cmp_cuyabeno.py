#!/usr/bin/env python3
"""Compose docs/hp001/cmp_cuyabeno_2d_3d.png.

Row 1: painted 2D jungle-sky (cloud band) vs 3D distant selva / gameplay sky.
Row 2: renderGame-style 2D vs 3D, same entrance stretch.
Row 3: hazard stretch. Row 4: cacao stretch.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs" / "hp001"
SKY = ROOT / "runtime" / "textures" / "hp001_jungle_sky_2d.jpg"
W, H = 1280, 720
GAP = 8
LABEL_H = 28


def load(path: Path, size=(W, H)) -> Image.Image:
    if not path.exists():
        img = Image.new("RGB", size, (24, 28, 22))
        ImageDraw.Draw(img).text((24, 24), f"missing {path.name}", fill=(220, 220, 200))
        return img
    im = Image.open(path).convert("RGB")
    if im.size != size:
        im = im.resize(size, Image.NEAREST)
    return im


def label_bar(text: str, width: int) -> Image.Image:
    bar = Image.new("RGB", (width, LABEL_H), (10, 12, 10))
    ImageDraw.Draw(bar).text((10, 6), text, fill=(230, 228, 214))
    return bar


def pair(left: Image.Image, right: Image.Image, lcap: str, rcap: str) -> Image.Image:
    row = Image.new("RGB", (W * 2 + GAP, H + LABEL_H), (0, 0, 0))
    row.paste(label_bar(lcap, W), (0, 0))
    row.paste(label_bar(rcap, W), (W + GAP, 0))
    row.paste(left, (0, LABEL_H))
    row.paste(right, (W + GAP, LABEL_H))
    return row


def sky_card() -> Image.Image:
    if not SKY.exists():
        return Image.new("RGB", (W, H), (140, 170, 190))
    sky = Image.open(SKY).convert("RGB")
    w, h = sky.size
    band = sky.crop((0, int(h * 0.08), w, int(h * 0.58)))
    return band.resize((W, H), Image.BILINEAR)


def main():
    rows = [
        pair(
            sky_card(),
            load(DOCS / "HP001_E2c_engine_cmp_bg.png") if (DOCS / "HP001_E2c_engine_cmp_bg.png").exists()
            else load(DOCS / "HP001_E2b_engine_cmp_bg.png"),
            "2D  ·  jungle-sky (nube, Cuyabeno plano)",
            "3D  ·  cielo + silueta plana (misma cámara de fondo)",
        ),
        pair(
            load(DOCS / "2d_entrance.png"),
            load(DOCS / "3d_entrance.png"),
            "2D renderGame  ·  entrada selva-1  ·  pies (96, 662)",
            "3D gameplay  ·  mismo tramo  ·  pies (4.5417, 0, 0)",
        ),
        pair(
            load(DOCS / "2d_hazard.png"),
            load(DOCS / "3d_hazard.png"),
            "2D renderGame  ·  pinchos H00  ·  pies (1504, 598)",
            "3D gameplay  ·  mismo tramo  ·  pies (63.2083, 2.6667, 0)",
        ),
        pair(
            load(DOCS / "2d_cacao.png"),
            load(DOCS / "3d_cacao.png"),
            "2D renderGame  ·  cacao + oneway  ·  pies (1568, 470)",
            "3D gameplay  ·  mismo tramo  ·  pies (65.875, 8.0, 0)",
        ),
    ]
    canvas = Image.new("RGB", (rows[0].size[0], sum(r.size[1] for r in rows) + GAP * (len(rows) - 1)), (0, 0, 0))
    y = 0
    for r in rows:
        canvas.paste(r, (0, y))
        y += r.size[1] + GAP
    out = DOCS / "cmp_cuyabeno_2d_3d.png"
    canvas.save(out)
    print(f"wrote {out} {canvas.size}")


if __name__ == "__main__":
    main()
