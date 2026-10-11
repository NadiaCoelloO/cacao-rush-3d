#!/usr/bin/env python3
"""p10 contrast of Maya's interior pixels against the player-hidden frame."""

import sys
from pathlib import Path

from PIL import Image, ImageFilter


def lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lum(rgb):
    r, g, b = rgb
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)


def contrast(a, b):
    l1, l2 = lum(a), lum(b)
    return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)


def main(folder):
    folder = Path(folder)
    for shot in ["embarque", "pinchos", "secreto", "viento", "meta"]:
        fg = Image.open(folder / f"3d_{shot}.png").convert("RGB")
        bg = Image.open(folder / f"3d_{shot}_bg.png").convert("RGB")
        w, h = fg.size
        fpx, bpx = fg.load(), bg.load()
        mask = Image.new("L", (w, h), 0)
        mp = mask.load()
        for y in range(h):
            for x in range(w):
                a, b = fpx[x, y], bpx[x, y]
                if abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2]) > 36:
                    mp[x, y] = 255
        # Drop the antialiased rim. Two erosions, then keep pixels whose
        # 3x3 neighborhood is still body.
        eroded = mask.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MinFilter(3))
        ep = eroded.load()
        ratios = []
        colors = []
        backs = []
        for y in range(1, h - 1):
            for x in range(1, w - 1):
                if ep[x, y] < 128:
                    continue
                if ep[x - 1, y] < 128 or ep[x + 1, y] < 128 or ep[x, y - 1] < 128 or ep[x, y + 1] < 128:
                    continue
                ratios.append(contrast(fpx[x, y], bpx[x, y]))
                colors.append(fpx[x, y])
                backs.append(bpx[x, y])
        ratios.sort()
        if not ratios:
            print(f"{shot} interior=0")
            continue
        p10 = ratios[max(0, int(len(ratios) * 0.10))]
        colors.sort(key=lum)
        backs.sort(key=lum)
        body = colors[len(colors) // 2]
        back = backs[len(backs) // 10]
        print(
            f"{shot} interior={len(ratios)} p10={p10:.2f} min={ratios[0]:.2f} "
            f"body_med={body} bg_p10={back}"
        )


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/rio-3d")
