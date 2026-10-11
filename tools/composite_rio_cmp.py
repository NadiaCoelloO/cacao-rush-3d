#!/usr/bin/env python3
"""Side-by-side 2D|3D stills. 2D nearest-scaled 960x540 -> 1280x720."""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HONEY = (196, 160, 122)
BAR = (28, 22, 18)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

CAPTIONS = {
    "embarque": "embarque  ·  orilla, cacao y primera balsa",
    "pinchos": "pinchos  ·  S00 sobre la orilla",
    "secreto": "secreto  ·  tótem warpRandom K01",
    "viento": "viento  ·  S01 y corriente en contra",
    "meta": "meta  ·  orilla final y grano de oro",
}


def main():
    src2 = Path(sys.argv[1])
    src3 = Path(sys.argv[2])
    out = Path(sys.argv[3])
    out.mkdir(parents=True, exist_ok=True)
    font = ImageFont.truetype(FONT, 22)
    for shot, caption in CAPTIONS.items():
        a = Image.open(src2 / f"{shot}.png").convert("RGB").resize((1280, 720), Image.Resampling.NEAREST)
        b = Image.open(src3 / f"3d_{shot}.png").convert("RGB")
        if b.size != (1280, 720):
            b = b.resize((1280, 720), Image.Resampling.NEAREST)
        canvas = Image.new("RGB", (2560, 772), BAR)
        canvas.paste(a, (0, 0))
        canvas.paste(b, (1280, 0))
        draw = ImageDraw.Draw(canvas)
        draw.rectangle((1278, 0, 1282, 719), fill=HONEY)
        draw.rectangle((0, 720, 2559, 771), fill=BAR)
        draw.text((24, 734), "2D  " + caption, font=font, fill=HONEY)
        draw.text((1304, 734), "3D  " + caption, font=font, fill=HONEY)
        dest = out / f"cmp_{shot}.png"
        canvas.save(dest)
        print(dest)


if __name__ == "__main__":
    main()
