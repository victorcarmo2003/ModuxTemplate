#!/usr/bin/env python3
"""Extract the UI palette from a reference image (k-means, numpy only).

  python palette.py ref.jpg -k 8                          # whole image
  python palette.py ref.jpg -k 6 --crop 550,320,820,470   # only the HUD region (x,y,w,h)
  python palette.py ref.jpg --ui-only                     # drop dark/low-saturation background pixels first
  python palette.py ref.jpg --swatch pal.png              # also save a swatch strip

HUD palettes live in the bright/saturated minority of pixels, so --ui-only usually gives the useful answer
for screenshots over a game world. Output: hex, share, luminance, a role guess (bg / ui-neutral / accent).
"""
from __future__ import annotations

import argparse

import numpy as np
from PIL import Image, ImageDraw


def kmeans(x: np.ndarray, k: int, iters: int = 25, seed: int = 0) -> tuple[np.ndarray, np.ndarray]:
    rng = np.random.default_rng(seed)
    c = x[rng.choice(len(x), k, replace=False)]
    lab = np.zeros(len(x), dtype=int)
    for _ in range(iters):
        d = ((x[:, None, :] - c[None, :, :]) ** 2).sum(-1)
        lab = d.argmin(1)
        new = np.array([x[lab == i].mean(0) if (lab == i).any() else c[i] for i in range(k)])
        if np.allclose(new, c, atol=0.5):
            break
        c = new
    return c, lab


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("image")
    ap.add_argument("-k", type=int, default=8)
    ap.add_argument("--crop", help="x,y,w,h")
    ap.add_argument("--ui-only", action="store_true", help="keep only bright or saturated pixels")
    ap.add_argument("--swatch")
    a = ap.parse_args()

    img = Image.open(a.image).convert("RGB")
    if a.crop:
        x, y, w, h = map(int, a.crop.split(","))
        img = img.crop((x, y, x + w, y + h))
    img.thumbnail((480, 480))
    px = np.asarray(img, dtype=np.float32).reshape(-1, 3)
    if a.ui_only:
        mx, mn = px.max(1), px.min(1)
        sat = (mx - mn) / np.maximum(mx, 1)
        keep = (mx > 170) | ((sat > 0.45) & (mx > 90))
        if keep.sum() > a.k * 20:
            px = px[keep]
    cents, lab = kmeans(px, min(a.k, len(px)))
    counts = np.bincount(lab, minlength=len(cents))
    order = counts.argsort()[::-1]
    print(f"{'hex':8} {'share':>6} {'lum':>5}  role")
    rows = []
    for i in order:
        r, g, b = cents[i]
        share = counts[i] / counts.sum()
        lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
        sat = (max(r, g, b) - min(r, g, b)) / max(max(r, g, b), 1)
        role = "accent" if sat > 0.4 and lum > 0.25 else ("bg" if lum < 0.18 else "ui-neutral")
        hx = "#%02X%02X%02X" % (int(r), int(g), int(b))
        rows.append(hx)
        print(f"{hx:8} {share:6.1%} {lum:5.2f}  {role}")
    if a.swatch:
        sw = Image.new("RGB", (80 * len(rows), 100), "black")
        d = ImageDraw.Draw(sw)
        for j, hx in enumerate(rows):
            d.rectangle([j * 80, 0, j * 80 + 79, 79], fill=hx)
            d.text((j * 80 + 4, 84), hx, fill="white")
        sw.save(a.swatch)
        print("wrote", a.swatch)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
