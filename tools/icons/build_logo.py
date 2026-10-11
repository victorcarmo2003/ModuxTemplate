"""Standalone hot dog logo (DEC-206: the cartoon hot dog of the crew apron, AST-053_CrewTex) as a transparent PNG.

Same shapes and colours as hotdog_logo() in the roblox-cartoon-animal-char outfit painter, drawn flat in 2D, plus an
optional "CORNER DOGS" wordmark plate under it. Output: Assets/textures/props/AST-072_logo_hotdog.png (1024 x 640).
Run: python tools/icons/build_logo.py
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

W, H = 1024, 640
OUT = Path(__file__).resolve().parents[2] / "Assets" / "textures" / "props" / "AST-072_logo_hotdog.png"


def sd_capsule(x, y, a, b, r):
    ax, ay = a
    bx, by = b
    px, py = x - ax, y - ay
    vx, vy = bx - ax, by - ay
    h = np.clip((px * vx + py * vy) / (vx * vx + vy * vy), 0, 1)
    return np.hypot(px - vx * h, py - vy * h) - r


def sd_polyline(x, y, pts):
    d = np.full(x.shape, 1e9)
    for a, b in zip(pts[:-1], pts[1:]):
        d = np.minimum(d, sd_capsule(x, y, a, b, 0.0))
    return d


def rot(x, y, deg):
    t = np.radians(deg)
    return x * np.cos(t) + y * np.sin(t), -x * np.sin(t) + y * np.cos(t)


def main():
    # logo space: x in [-0.6, 0.6], y up; logo occupies the top 70 % of the canvas
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float64)
    scale = 1.6 / W
    X = (xs - W / 2) * scale
    Y = -(ys - H * 0.38) * scale
    aa = scale * 1.5
    Xr, Yr = rot(X, Y, 12)
    bun = sd_capsule(Xr, Yr, (-0.36, -0.02), (0.36, -0.02), 0.15)
    saus = sd_capsule(Xr, Yr, (-0.47, 0.06), (0.47, 0.06), 0.085)
    front_bun = np.maximum(sd_capsule(Xr, Yr, (-0.38, -0.07), (0.38, -0.07), 0.12), Yr)
    union = np.minimum(bun, saus)
    zz = [(-0.40 + i * 0.1, 0.075 + (0.035 if i % 2 else -0.025)) for i in range(9)]
    mustard = sd_polyline(Xr, Yr, zz) - 0.022

    img = np.zeros((H, W, 4))

    def put(sd, rgb, mask=None):
        a = np.clip(0.5 - sd / aa, 0, 1)
        if mask is not None:
            a = a * mask
        for i in range(3):
            img[..., i] = img[..., i] * (1 - a) + rgb[i] / 255 * a
        img[..., 3] = np.maximum(img[..., 3], a)

    put(union - 0.05, (250, 236, 214))          # sticker outline
    put(union - 0.018, (120, 40, 20))           # dark contour
    put(bun, (236, 160, 72))
    put(saus, (186, 66, 38))
    put(np.abs(Yr - 0.10) - 0.012, (232, 128, 96), np.clip(0.5 - (saus + 0.02) / aa, 0, 1))
    put(front_bun, (226, 148, 62))
    put(mustard, (255, 214, 48))

    out = Image.fromarray((img * 255).astype(np.uint8))
    # wordmark plate
    d = ImageDraw.Draw(out)
    try:
        font = ImageFont.truetype("arialbd.ttf", 92)
    except OSError:
        font = ImageFont.load_default()
    text = "CORNER DOGS"
    bx = d.textbbox((0, 0), text, font=font)
    tw, th = bx[2] - bx[0], bx[3] - bx[1]
    px, py = (W - tw) // 2, int(H * 0.72)
    d.rounded_rectangle([px - 40, py - 26, px + tw + 40, py + th + 40], radius=36, fill=(43, 36, 64, 255), outline=(250, 236, 214, 255), width=10)
    d.text((px - bx[0], py - bx[1] + 6), text, font=font, fill=(255, 200, 61, 255))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
