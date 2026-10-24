#!/usr/bin/env python3
"""Overlay a labelled pixel grid on a reference so positions/sizes are measured, not guessed.

  python grid.py ref.jpg -o grid.png                                    # 1920x1080 space, 40 px grid
  python grid.py ref.jpg --crop 1400,850,500,230 --zoom 3 -o zoom.png   # zoom into one HUD element
  python grid.py ref.jpg --normalize 1920x1080                          # resize first (default)

Coordinates printed on the grid are always in the normalized full-image space, also inside crops,
so numbers read off a zoom go straight into the mockup SVG.
"""
from __future__ import annotations

import argparse

from PIL import Image, ImageDraw


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("image")
    ap.add_argument("-o", "--out", default="grid.png")
    ap.add_argument("--step", type=int, default=40)
    ap.add_argument("--label", type=int, default=200, help="label every N px (full view)")
    ap.add_argument("--crop", help="x,y,w,h in normalized space")
    ap.add_argument("--zoom", type=float, default=1)
    ap.add_argument("--normalize", default="1920x1080")
    a = ap.parse_args()

    img = Image.open(a.image).convert("RGB")
    nw, nh = map(int, a.normalize.lower().split("x"))
    if img.size != (nw, nh):
        img = img.resize((nw, nh), Image.LANCZOS)
    ox = oy = 0
    step, label = a.step, a.label
    if a.crop:
        ox, oy, w, h = map(int, a.crop.split(","))
        img = img.crop((ox, oy, ox + w, oy + h))
        step, label = max(2, a.step // 4), max(10, a.label // 4)
    z = a.zoom
    if z != 1:
        img = img.resize((int(img.width * z), int(img.height * z)), Image.NEAREST)
    over = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for gx in range((-ox) % step, int(img.width / z) + 1, step):
        X = ox + gx
        major = X % label == 0
        d.line([(gx * z, 0), (gx * z, img.height)], fill=(255, 0, 255, 150 if major else 55), width=1)
        if major:
            d.text((gx * z + 2, 2), str(X), fill=(255, 255, 0, 255))
    for gy in range((-oy) % step, int(img.height / z) + 1, step):
        Y = oy + gy
        major = Y % label == 0
        d.line([(0, gy * z), (img.width, gy * z)], fill=(0, 255, 255, 150 if major else 55), width=1)
        if major:
            d.text((2, gy * z + 2), str(Y), fill=(255, 255, 0, 255))
    Image.alpha_composite(img.convert("RGBA"), over).convert("RGB").save(a.out)
    print(f"wrote {a.out} (origin {ox},{oy}; minor {step}px; labels every {label}px)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
