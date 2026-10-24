#!/usr/bin/env python3
"""Compute (or verify) the 9-slice SliceCenter for a frame PNG, and preview it stretched.

  python nineslice.py frame.png                       # auto: finds where the borders stop changing
  python nineslice.py frame.png --margin 24           # fixed margin (px of the PNG)
  python nineslice.py frame.png --preview 900x300 -o stretched.png   # simulate Roblox stretching

Prints Luau: ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(l, t, r, b), SliceScale hint.
Rule: the center region must be a uniform (or vertically/horizontally constant) band, otherwise it smears.
Cut corners/chamfers must sit fully inside the margin.
"""
from __future__ import annotations

import argparse

import numpy as np
from PIL import Image


def auto_margin(alpha: np.ndarray, axis: int) -> tuple[int, int]:
    """First/last index from each side where the profile becomes identical to the middle profile."""
    n = alpha.shape[axis]
    mid = n // 2
    prof = alpha.take(mid, axis=axis).astype(np.int16)

    def same(i: int) -> bool:
        return int(np.abs(alpha.take(i, axis=axis).astype(np.int16) - prof).max()) <= 8

    lo = 0
    while lo < mid and not same(lo):
        lo += 1
    hi = n - 1
    while hi > mid and not same(hi):
        hi -= 1
    return lo + 1, hi


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("png")
    ap.add_argument("--margin", type=int)
    ap.add_argument("--preview", help="WxH stretched preview size")
    ap.add_argument("-o", "--out", default="nineslice_preview.png")
    a = ap.parse_args()

    img = Image.open(a.png).convert("RGBA")
    W, H = img.size
    if a.margin is not None:
        l = t = a.margin
        r, b = W - a.margin, H - a.margin
    else:
        arr = np.asarray(img)
        l, r = auto_margin(arr[..., 3], axis=1)
        t, b = auto_margin(arr[..., 3], axis=0)
        pad = 2
        l, t, r, b = min(l + pad, W // 2 - 1), min(t + pad, H // 2 - 1), max(r - pad, W // 2 + 1), max(b - pad, H // 2 + 1)
    print(f"size {W}x{H}")
    print("ScaleType = Enum.ScaleType.Slice,")
    print(f"SliceCenter = Rect.new({l}, {t}, {r}, {b}),")
    print("-- exported at 2x? use SliceScale = 0.5 so borders keep their 1x thickness")

    if a.preview:
        pw, ph = map(int, a.preview.lower().split("x"))
        src = np.asarray(img)
        xs = [0, l, r, W]
        ys = [0, t, b, H]
        dx = [0, l, pw - (W - r), pw]
        dy = [0, t, ph - (H - b), ph]
        out = Image.new("RGBA", (pw, ph), (40, 40, 40, 255))
        for i in range(3):
            for j in range(3):
                piece = Image.fromarray(src[ys[i]:ys[i + 1], xs[j]:xs[j + 1]])
                tw, th = dx[j + 1] - dx[j], dy[i + 1] - dy[i]
                if tw > 0 and th > 0 and piece.size[0] > 0 and piece.size[1] > 0:
                    out.alpha_composite(piece.resize((tw, th), Image.BILINEAR), (dx[j], dy[i]))
        out.save(a.out)
        print("wrote", a.out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
