#!/usr/bin/env python3
"""Compare a reference (or mockup) with a capture of the Roblox UI.

  python compare.py ref.jpg capture.png -o cmp.png
  python compare.py ref.jpg capture.png -o cmp.png --crop 550,320,820,470   # same region of both (ref space)
  python compare.py mock.png capture.png --edges                              # board shows line structure only

Writes a 2x2 board: reference | capture / 50% overlay | diff heat. Prints scores:
  ssim   structural similarity of luminance (1.0 = identical). >0.80 on a HUD crop is a good match.
  edge   overlap of edge maps with 2 px tolerance: are lines/shapes in the same places (best for thin HUD art).
  color  mean RGB distance of the 3 dominant colors (lower is better, <25 is close).
The capture is resized to the reference size first. Scores guide, eyes decide: always look at the board.
"""
from __future__ import annotations

import argparse

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps
from scipy.ndimage import binary_dilation, uniform_filter


def ssim(a: np.ndarray, b: np.ndarray) -> float:
    c1, c2 = (0.01 * 255) ** 2, (0.03 * 255) ** 2
    mu_a, mu_b = uniform_filter(a, 7), uniform_filter(b, 7)
    va = uniform_filter(a * a, 7) - mu_a ** 2
    vb = uniform_filter(b * b, 7) - mu_b ** 2
    cov = uniform_filter(a * b, 7) - mu_a * mu_b
    s = ((2 * mu_a * mu_b + c1) * (2 * cov + c2)) / ((mu_a ** 2 + mu_b ** 2 + c1) * (va + vb + c2))
    return float(s.mean())


def edges(img: Image.Image) -> np.ndarray:
    arr = np.asarray(img.convert("L").filter(ImageFilter.FIND_EDGES), dtype=np.float32)
    return arr > max(30.0, float(np.percentile(arr, 90)))


def dominant(img: Image.Image, k: int = 3) -> np.ndarray:
    q = img.convert("RGB").resize((160, 90)).quantize(k)
    pal = np.array(q.getpalette()[: k * 3], dtype=np.float32).reshape(-1, 3)
    counts = np.bincount(np.asarray(q).ravel(), minlength=len(pal))
    return pal[counts.argsort()[::-1]][:k]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("ref")
    ap.add_argument("cap")
    ap.add_argument("-o", "--out", default="compare.png")
    ap.add_argument("--crop", help="x,y,w,h in reference pixels")
    ap.add_argument("--edges", action="store_true")
    a = ap.parse_args()

    ref = Image.open(a.ref).convert("RGB")
    cap_raw = Image.open(a.cap)
    if cap_raw.mode in ("RGBA", "LA", "P") and cap_raw.convert("RGBA").getchannel("A").getextrema()[0] < 255:
        # transparent mockup/layer: put it over the reference so both show the UI on the same world
        cap = ref.convert("RGBA")
        cap.alpha_composite(cap_raw.convert("RGBA").resize(ref.size, Image.LANCZOS))
        cap = cap.convert("RGB")
        print("note: capture has transparency, composited over the reference")
    else:
        cap = cap_raw.convert("RGB").resize(ref.size, Image.LANCZOS)
    if a.crop:
        x, y, w, h = map(int, a.crop.split(","))
        ref, cap = ref.crop((x, y, x + w, y + h)), cap.crop((x, y, x + w, y + h))

    s = ssim(np.asarray(ref.convert("L"), np.float32), np.asarray(cap.convert("L"), np.float32))
    ea, eb = edges(ref), edges(cap)
    da, db = binary_dilation(ea, iterations=2), binary_dilation(eb, iterations=2)
    union = ea.sum() + eb.sum()
    iou = float(((ea & db).sum() + (eb & da).sum()) / union) if union else 1.0
    da_, db_ = dominant(ref), dominant(cap)
    n = min(len(da_), len(db_))
    dc = float(np.linalg.norm(da_[:n] - db_[:n], axis=1).mean())

    A, B = (ref, cap) if not a.edges else tuple(
        Image.fromarray((e * 255).astype("uint8")).convert("RGB") for e in (ea, eb))
    overlay = Image.blend(A, B, 0.5)
    diff = ImageOps.autocontrast(ImageChops.difference(ref, cap).convert("L"))
    heat = ImageOps.colorize(diff, black="black", white="red", mid="yellow")
    W, H = A.size
    board = Image.new("RGB", (W * 2 + 6, H * 2 + 40), (30, 30, 30))
    for im, pos in ((A, (0, 34)), (B, (W + 6, 34)), (overlay, (0, H + 40)), (heat, (W + 6, H + 40))):
        board.paste(im, pos)
    ImageDraw.Draw(board).text((6, 10), f"ref | capture  /  overlay | diff     ssim={s:.3f}  edge={iou:.3f}  color={dc:.1f}",
                               fill="white")
    board.save(a.out)
    print(f"ssim={s:.3f} edge={iou:.3f} color={dc:.1f} -> {a.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
