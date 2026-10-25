"""thumb.py - Roblox thumbnail compositor (16:9 thumbnails and square icons).

One CLI, three jobs:

  python thumb.py compose spec.json          # build a thumbnail / icon from a JSON spec (see references/spec.md)
  python thumb.py check out.png [--icon]     # legibility report: 250 px / 150 px preview, greyscale, metrics
  python thumb.py batch spec.json --vary ... # cartesian A/B variations, contact sheet

Spec (paths relative to the spec file):
{
  "out": "thumb.png", "size": [1920, 1080],                 # [512, 512] for an icon
  "bg": {"path": "bg.jpg", "crop": [x0,y0,x1,y1],           # crop optional (default: centre cover)
         "blur": 4, "saturation": 0.7, "brightness": 0.85,
         "tint": [0.8, 0.9, 1.2], "lift": [12, 20, 40],      # colour cast / raise blacks (RGB)
         "gradient": {"color": [20, 30, 60], "strength": 0.4, "from": "bottom"}},
  "spots": [{"at": [0.6, 0.4], "radius": 0.4, "color": [255, 200, 120], "strength": 0.3}],
  "layers": [                                               # back to front
    {"path": "monster.png", "key": "green" | "magenta" | "alpha" | "none",
     "mask": "monster_mask.png", "mask_color": [255, 0, 255],   # optional: flat-colour matte render instead of key
     "at": [0.68, 0.45], "height": 0.9, "anchor": "bottom" | "center", "flip": false, "rotate": 0,
     "saturation": 1.2, "contrast": 1.1, "brightness": 1.0, "tint": [1, 1, 1], "tint_amount": 0,
     "outline": {"color": [20, 15, 25], "width": 10},        # uniform (distance-transform) outline
     "outline2": {"color": [255, 255, 255], "width": 6},     # inner second outline (sticker look)
     "glow": {"color": [255, 40, 80], "width": 60, "strength": 0.8},
     "shadow": {"offset": [18, 24], "blur": 20, "opacity": 0.5},
     "rim": {"color": [140, 180, 255], "side": "right", "width": 8, "strength": 0.6},
     "sharpen": 0.6}
  ],
  "text": [{"text": "DON'T LOOK", "font": "LuckiestGuy-Regular.ttf", "size": 0.16,   # size = fraction of height
            "at": [0.5, 0.12], "align": "center", "color": [255, 255, 255],
            "stroke": {"color": [0, 0, 0], "width": 0.011}, "stroke2": {"color": [255, 255, 255], "width": 0.02},
            "shadow": {"offset": [0.006, 0.008], "color": [0, 0, 0], "opacity": 0.7},
            "gradient": [[255, 230, 80], [255, 140, 0]], "rotate": -6, "max_width": 0.9}],
  "grade": {"saturation": 1.1, "contrast": 1.06, "warm_cool": 0.15, "split": {"shadows": [30, 50, 110], "highlights": [255, 225, 190], "amount": 0.12}},
  "vignette": {"strength": 0.35, "bottom_bias": 0.3},
  "sharpen": 0.4,
  "safe_bottom": 0.15                                       # draw nothing essential below this line (check warns)
}

Everything is optional except out, size, and either bg or layers.
"""
from __future__ import annotations

import argparse
import itertools
import json
import os
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
FONT_DIRS = [HERE.parent / "assets" / "fonts", Path(os.environ.get("WINDIR", "C:/Windows")) / "Fonts"]


# ------------------------------------------------------------------ helpers

def load_rgba(path: Path) -> np.ndarray:
    im = Image.open(path).convert("RGBA")
    return np.asarray(im).astype(np.float32) / 255.0


def saturate(rgb, amount):
    grey = rgb.mean(axis=2, keepdims=True)
    return np.clip(grey + (rgb - grey) * amount, 0, 1)


def contrast(rgb, amount):
    return np.clip((rgb - 0.5) * amount + 0.5, 0, 1)


def disc(w):
    w = max(1, int(round(w)))
    return cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * w + 1, 2 * w + 1))


def ring(alpha, width, soft=1.0):
    """Uniform-width band just outside the matte (distance field, so corners stay round and width is exact).
    Computed on a crop around the matte: a 1080p distance transform over the whole frame is the slow part."""
    width = int(round(width))
    solid = (alpha > 0.5).astype(np.uint8)
    ys, xs = np.nonzero(solid)
    out = np.zeros(alpha.shape, np.float32)
    if len(xs) == 0:
        return out
    pad = width + 4
    y0, y1 = max(0, ys.min() - pad), min(alpha.shape[0], ys.max() + pad + 1)
    x0, x1 = max(0, xs.min() - pad), min(alpha.shape[1], xs.max() + pad + 1)
    d = cv2.distanceTransform(1 - solid[y0:y1, x0:x1], cv2.DIST_L2, 5)
    r = np.clip(width + 0.5 - d, 0, 1) * (1 - solid[y0:y1, x0:x1])
    out[y0:y1, x0:x1] = cv2.GaussianBlur(r.astype(np.float32), (0, 0), soft) if soft else r
    return out


def over(dst, src, a):
    return dst * (1 - a[..., None]) + src * a[..., None]


def unsharp(rgb, amount, radius=1.2):
    if amount <= 0:
        return rgb
    blur = cv2.GaussianBlur(rgb, (0, 0), radius)
    return np.clip(rgb + (rgb - blur) * amount, 0, 1)


def key_matte(rgba, mode, lo=0.28, hi=0.5, spill=7):
    rgb = rgba[..., :3].copy()
    if mode == "alpha":
        return rgb, rgba[..., 3]
    if mode == "none":
        return rgb, np.ones(rgb.shape[:2], np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    dom = (np.minimum(r, b) - g) if mode == "magenta" else (g - np.maximum(r, b))
    alpha = 1.0 - np.clip((dom - lo) / (hi - lo), 0, 1)
    alpha = cv2.morphologyEx(alpha, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    edge = np.clip(cv2.GaussianBlur(1.0 - cv2.erode(alpha, np.ones((spill, spill), np.uint8)), (0, 0), 2), 0, 1)
    if mode == "magenta":
        cap = np.minimum(np.minimum(r, b), g * 1.02 + 0.02)
        rgb[..., 0] = r * (1 - edge) + np.minimum(r, cap + (r - np.minimum(r, b))) * edge
        rgb[..., 2] = b * (1 - edge) + np.minimum(b, cap + (b - np.minimum(r, b))) * edge
    else:
        rgb[..., 1] = g * (1 - edge) + np.minimum(g, (r + b) / 2 + 0.02) * edge
    return rgb, cv2.GaussianBlur(alpha, (0, 0), 0.8)


def mask_from_render(path: Path, colour, tol=0.22):
    m = load_rgba(path)[..., :3]
    d = np.linalg.norm(m - np.float32(colour) / 255.0, axis=2)
    a = (d < tol).astype(np.float32)
    return cv2.morphologyEx(a, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))


def cover(img, size, crop=None):
    h, w = img.shape[:2]
    tw, th = size
    if crop:
        x0, y0, x1, y1 = crop
    else:
        t = tw / th
        if w / h > t:
            cw = int(h * t)
            x0, y0, x1, y1 = (w - cw) // 2, 0, (w - cw) // 2 + cw, h
        else:
            ch = int(w / t)
            x0, y0, x1, y1 = 0, (h - ch) // 2, w, (h - ch) // 2 + ch
    return cv2.resize(img[y0:y1, x0:x1], (tw, th), interpolation=cv2.INTER_CUBIC)


def place(size, rgb, alpha, at, height, anchor="bottom", flip=False, rotate=0.0, extra=None):
    """Fit a layer by its matte bounding box: box height = `height` x canvas height, anchor lands at `at`."""
    tw, th = size
    if flip:
        rgb, alpha = rgb[:, ::-1].copy(), alpha[:, ::-1].copy()
    ys, xs = np.nonzero(alpha > 0.5)
    if len(xs) == 0:
        return np.zeros((th, tw, 3), np.float32), np.zeros((th, tw), np.float32)
    s = height * th / (ys.max() - ys.min() + 1)
    cx = (xs.min() + xs.max()) / 2
    cy = ys.max() if anchor == "bottom" else (ys.min() + ys.max()) / 2
    M = cv2.getRotationMatrix2D((float(cx), float(cy)), rotate, s)
    M[0, 2] += at[0] * tw - cx
    M[1, 2] += at[1] * th - cy
    rgb = cv2.warpAffine(rgb, M, (tw, th), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_CONSTANT)
    alpha = cv2.warpAffine(alpha, M, (tw, th), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT)
    if extra is not None:
        if flip:
            extra = extra[:, ::-1].copy()
        extra = np.clip(cv2.warpAffine(extra, M, (tw, th), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT), 0, 1)
        return np.clip(rgb, 0, 1), np.clip(alpha, 0, 1), extra
    return np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)


def find_font(name):
    p = Path(name)
    if p.exists():
        return str(p)
    for d in FONT_DIRS:
        if (d / name).exists():
            return str(d / name)
    raise FileNotFoundError(f"font not found: {name} (looked in {FONT_DIRS})")


# ------------------------------------------------------------------ text

def draw_text(canvas, spec, size):
    tw, th = size
    txt = spec["text"]
    px = int(spec.get("size", 0.14) * th)
    font = ImageFont.truetype(find_font(spec.get("font", "LuckiestGuy-Regular.ttf")), px)
    # shrink to fit max_width
    maxw = spec.get("max_width", 0.92) * tw
    while font.getlength(txt) > maxw and px > 10:
        px -= 2
        font = ImageFont.truetype(find_font(spec.get("font", "LuckiestGuy-Regular.ttf")), px)
    pad = int(px * 0.6)
    w = int(font.getlength(txt)) + pad * 2
    h = int(px * 1.4) + pad * 2
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    sw2 = int(spec.get("stroke2", {}).get("width", 0) * th)
    sw = int(spec.get("stroke", {"width": 0.011}).get("width", 0.011) * th)
    origin = (pad, pad)
    if sw2:
        d.text(origin, txt, font=font, fill=tuple(spec["stroke2"].get("color", [255, 255, 255])) + (255,),
               stroke_width=sw + sw2, stroke_fill=tuple(spec["stroke2"].get("color", [255, 255, 255])) + (255,))
    fill = tuple(spec.get("color", [255, 255, 255])) + (255,)
    d.text(origin, txt, font=font, fill=fill, stroke_width=sw,
           stroke_fill=tuple(spec.get("stroke", {}).get("color", [0, 0, 0])) + (255,))
    arr = np.asarray(layer).astype(np.float32) / 255.0
    # vertical gradient inside the fill only
    grad = spec.get("gradient")
    if grad:
        fill_mask = Image.new("L", (w, h), 0)
        ImageDraw.Draw(fill_mask).text(origin, txt, font=font, fill=255)
        fm = np.asarray(fill_mask).astype(np.float32) / 255.0
        ys, xs = np.nonzero(fm > 0.5)
        if len(ys):
            t = ((np.arange(h) - ys.min()) / max(1, ys.max() - ys.min()))[:, None]
            t = np.clip(t, 0, 1)
            c0, c1 = np.float32(grad[0]) / 255.0, np.float32(grad[1]) / 255.0
            g = (c0 * (1 - t) + c1 * t)[:, None, :].repeat(w, axis=1)
            arr[..., :3] = arr[..., :3] * (1 - fm[..., None]) + g * fm[..., None]
    rgb, a = arr[..., :3], arr[..., 3]
    if spec.get("rotate"):
        M = cv2.getRotationMatrix2D((w / 2, h / 2), spec["rotate"], 1.0)
        rgb = cv2.warpAffine(rgb, M, (w, h), flags=cv2.INTER_CUBIC)
        a = cv2.warpAffine(a, M, (w, h), flags=cv2.INTER_LINEAR)
    # position
    ax, ay = spec.get("at", [0.5, 0.12])
    align = spec.get("align", "center")
    x = int(ax * tw - (w / 2 if align == "center" else (w if align == "right" else 0)))
    y = int(ay * th - h / 2)
    full_rgb = np.zeros((th, tw, 3), np.float32)
    full_a = np.zeros((th, tw), np.float32)
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(tw, x + w), min(th, y + h)
    if x1 > x0 and y1 > y0:
        full_rgb[y0:y1, x0:x1] = rgb[y0 - y:y1 - y, x0 - x:x1 - x]
        full_a[y0:y1, x0:x1] = a[y0 - y:y1 - y, x0 - x:x1 - x]
    sh = spec.get("shadow")
    if sh:
        dx, dy = int(sh.get("offset", [0.006, 0.008])[0] * tw), int(sh.get("offset", [0.006, 0.008])[1] * th)
        sa = np.roll(np.roll(full_a, dy, axis=0), dx, axis=1)
        if sh.get("blur"):
            sa = cv2.GaussianBlur(sa, (0, 0), sh["blur"])
        sc = np.float32(sh.get("color", [0, 0, 0])) / 255.0
        canvas = over(canvas, np.ones_like(canvas) * sc, sa * sh.get("opacity", 0.7))
    return over(canvas, full_rgb, full_a)


# ------------------------------------------------------------------ compose

def compose(spec: dict, base: Path, out_override: Path | None = None) -> Path:
    size = tuple(spec.get("size", [1920, 1080]))
    tw, th = size
    canvas = np.zeros((th, tw, 3), np.float32)

    bg = spec.get("bg")
    if bg:
        img = load_rgba(base / bg["path"])[..., :3]
        canvas = cover(img, size, bg.get("crop"))
        if bg.get("blur"):
            canvas = cv2.GaussianBlur(canvas, (0, 0), bg["blur"])
        canvas = saturate(canvas, bg.get("saturation", 1.0)) * bg.get("brightness", 1.0)
        if bg.get("tint"):
            canvas = canvas * np.float32(bg["tint"])
        if bg.get("lift"):
            lift = np.float32(bg["lift"]) / 255.0
            canvas = canvas + (1 - canvas) * lift * (1 - canvas.mean(axis=2, keepdims=True))
        g = bg.get("gradient")
        if g:
            yy = np.linspace(0, 1, th, dtype=np.float32)[:, None]
            ramp = yy if g.get("from", "bottom") == "bottom" else 1 - yy
            ramp = np.clip(ramp, 0, 1) ** 1.5 * g.get("strength", 0.4)
            col = np.float32(g.get("color", [0, 0, 0])) / 255.0
            canvas = canvas * (1 - ramp[..., None]) + col * ramp[..., None]
        canvas = np.clip(canvas, 0, 1)
    elif spec.get("bg_color"):
        canvas[:] = np.float32(spec["bg_color"]) / 255.0

    yy, xx = np.mgrid[0:th, 0:tw].astype(np.float32)
    for sp in spec.get("spots", []):
        d = np.sqrt(((xx / tw - sp["at"][0]) * (tw / th)) ** 2 + (yy / th - sp["at"][1]) ** 2)
        m = np.clip(1 - d / sp.get("radius", 0.4), 0, 1) ** 2 * sp.get("strength", 0.3)
        canvas = np.clip(canvas + m[..., None] * (np.float32(sp["color"]) / 255.0), 0, 1)

    subjects = np.zeros((th, tw), np.float32)
    for layer in spec.get("layers", []):
        rgba = load_rgba(base / layer["path"])
        if layer.get("mask"):
            rgb = rgba[..., :3]
            alpha = mask_from_render(base / layer["mask"], layer.get("mask_color", [255, 0, 255]))
            alpha = cv2.GaussianBlur(alpha, (0, 0), 0.8)
        else:
            rgb, alpha = key_matte(rgba, layer.get("key", "alpha" if rgba.shape[2] == 4 and rgba[..., 3].min() < 0.99 else "green"),
                                   lo=layer.get("key_lo", 0.28), hi=layer.get("key_hi", 0.5), spill=layer.get("spill", 7))
            if layer.get("crop"):
                # keep only this region of the source matte (drop stray non-key pixels at the frame edges)
                x0, y0, x1, y1 = layer["crop"]
                keep = np.zeros_like(alpha); keep[y0:y1, x0:x1] = 1; alpha = alpha * keep
        if layer.get("choke"):
            # shrink the matte N px: drops the half-transparent rim where the key colour is mixed in
            k = int(layer["choke"])
            alpha = cv2.erode(alpha, disc(k)) if k > 0 else alpha
            alpha = cv2.GaussianBlur(alpha, (0, 0), 0.7)
        if layer.get("despill"):
            # kill green casts anywhere inside the matte (Studio gizmo lines, bounce from the green walls):
            # any pixel whose green exceeds the brighter of red/blue gets pulled down to it
            r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
            cap = np.maximum(r, b) * (1 + layer["despill"] * 0.1)
            rgb[..., 1] = np.minimum(g, cap)
        rgb = saturate(rgb, layer.get("saturation", 1.0))
        rgb = contrast(rgb, layer.get("contrast", 1.0)) * layer.get("brightness", 1.0)
        if layer.get("tint") and layer.get("tint_amount", 0) > 0:
            k = layer["tint_amount"]
            rgb = rgb * (1 - k) + rgb * np.float32(layer["tint"]) * k
        rgb = np.clip(rgb, 0, 1)
        hl = layer.get("highlight")
        sub = None
        if hl:
            # one character inside a group pass: source-pixel box (or a flat-colour mask render) picks it out
            if hl.get("mask"):
                sub = mask_from_render(base / hl["mask"], hl.get("mask_color", [255, 0, 255])) * (alpha > 0.5)
            else:
                x0, y0, x1, y1 = hl["region"]
                sub = np.zeros_like(alpha); sub[y0:y1, x0:x1] = alpha[y0:y1, x0:x1]
                # neighbours' ears/arms poking into the box are separate blobs: keep the biggest one
                n, lab, st, _ = cv2.connectedComponentsWithStats((sub > 0.5).astype(np.uint8), 8)
                if n > 2:
                    big = 1 + int(np.argmax(st[1:, cv2.CC_STAT_AREA]))
                    sub = sub * cv2.dilate((lab == big).astype(np.float32), np.ones((3, 3), np.uint8))
        placed = place(size, rgb, alpha, layer.get("at", [0.5, 1.0]), layer.get("height", 0.8),
                       layer.get("anchor", "bottom"), layer.get("flip", False), layer.get("rotate", 0.0), extra=sub)
        rgb, alpha = placed[0], placed[1]
        sub = placed[2] if sub is not None else None
        subjects = np.maximum(subjects, alpha)

        sh = layer.get("shadow")
        if sh:
            sa = np.roll(np.roll(alpha, int(sh.get("offset", [18, 24])[1]), 0), int(sh.get("offset", [18, 24])[0]), 1)
            sa = cv2.GaussianBlur(sa, (0, 0), sh.get("blur", 20)) * sh.get("opacity", 0.5)
            canvas = canvas * (1 - sa[..., None])
        gl = layer.get("glow")
        if gl:
            g = cv2.GaussianBlur(cv2.dilate(alpha, disc(gl.get("width", 50) // 3)), (0, 0), gl.get("width", 50) / 2)
            canvas = np.clip(canvas + (g * gl.get("strength", 0.8))[..., None] * (np.float32(gl["color"]) / 255.0), 0, 1)
        o2 = layer.get("outline2")
        o1 = layer.get("outline")
        if o1:
            w1 = o1.get("width", 10) + (o2.get("width", 0) if o2 else 0)
            r1 = ring(alpha, w1)
            canvas = over(canvas, np.ones_like(canvas) * (np.float32(o1["color"]) / 255.0), r1)
        if o2:
            r2 = ring(alpha, o2.get("width", 6))
            canvas = over(canvas, np.ones_like(canvas) * (np.float32(o2["color"]) / 255.0), r2)
        rim = layer.get("rim")
        if rim:
            shift = rim.get("width", 8) * (1 if rim.get("side", "right") == "right" else -1)
            inner = np.clip(alpha - np.roll(alpha, shift, axis=1), 0, 1)
            inner = cv2.GaussianBlur(inner, (0, 0), 3) * rim.get("strength", 0.6)
            rgb = np.clip(rgb + inner[..., None] * (np.float32(rim["color"]) / 255.0), 0, 1)
        if layer.get("sharpen"):
            rgb = unsharp(rgb, layer["sharpen"])
        if sub is not None and hl.get("glow"):
            gw = hl["glow"]
            g = cv2.GaussianBlur(cv2.dilate(sub, disc(gw.get("width", 40) // 3)), (0, 0), gw.get("width", 40) / 2)
            canvas = np.clip(canvas + (g * gw.get("strength", 0.6))[..., None] * (np.float32(hl["color"]) / 255.0), 0, 1)
        canvas = over(canvas, rgb, alpha)
        if sub is not None:
            # Roblox-Highlight look, drawn on top of the group so neighbours do not hide it
            col = np.float32(hl.get("color", [255, 30, 50])) / 255.0
            if hl.get("fill"):
                canvas = over(canvas, np.ones_like(canvas) * col, sub * hl["fill"])
            canvas = over(canvas, np.ones_like(canvas) * col, ring(sub, hl.get("width", 8)))

    for t in spec.get("text", []):
        canvas = draw_text(canvas, t, size)

    gr = spec.get("grade", {})
    canvas = contrast(saturate(canvas, gr.get("saturation", 1.0)), gr.get("contrast", 1.0))
    if gr.get("warm_cool"):
        # teal & orange: push shadows cool, highlights warm, by luminance
        k = gr["warm_cool"]
        lum = canvas.mean(axis=2, keepdims=True)
        canvas = canvas + (np.float32([0.05, 0.12, 0.30]) - 0.157) * (1 - lum) * k + (np.float32([0.30, 0.18, 0.02]) - 0.167) * lum * k
    sp = gr.get("split")
    if sp:
        lum = canvas.mean(axis=2, keepdims=True)
        canvas = canvas + (np.float32(sp["shadows"]) / 255.0 - 0.5) * (1 - lum) * sp.get("amount", 0.12) \
                        + (np.float32(sp["highlights"]) / 255.0 - 0.5) * lum * sp.get("amount", 0.12)
    canvas = np.clip(canvas, 0, 1)

    vg = spec.get("vignette")
    if vg:
        s = vg if isinstance(vg, (int, float)) else vg.get("strength", 0.35)
        bias = 0 if isinstance(vg, (int, float)) else vg.get("bottom_bias", 0.0)
        d = np.sqrt(((xx / tw - 0.5) * 2) ** 2 + ((yy / th - 0.5) * 2) ** 2) / np.sqrt(2)
        d = d + bias * np.clip(yy / th - 0.5, 0, 1)
        canvas = canvas * (1 - s * np.clip(d, 0, 1) ** 2)[..., None]
    if spec.get("sharpen"):
        canvas = unsharp(canvas, spec["sharpen"], 1.0)

    out = out_override or (base / spec.get("out", "thumbnail.png"))
    Image.fromarray((np.clip(canvas, 0, 1) * 255).astype(np.uint8)).save(out)
    return out


# ------------------------------------------------------------------ check

def metrics(path: Path):
    im = np.asarray(Image.open(path).convert("RGB")).astype(np.float32) / 255.0
    hsv = cv2.cvtColor((im * 255).astype(np.uint8), cv2.COLOR_RGB2HSV).astype(np.float32)
    L, S, H = im.mean(axis=2), hsv[..., 1] / 255.0, hsv[..., 0] * 2
    warm = (((H < 60) | (H > 320)) & (S > 0.35)).mean()
    cool = (((H > 170) & (H < 270)) & (S > 0.35)).mean()
    small = cv2.resize(im, (384, 216), interpolation=cv2.INTER_AREA)
    edges = cv2.Canny((small.mean(axis=2) * 255).astype(np.uint8), 80, 160).mean() / 255
    return dict(dark=float((L < 0.2).mean()), bright=float((L > 0.8).mean()), contrast=float(L.std()),
                sat=float(S.mean()), warm=float(warm), cool=float(cool), edges=float(edges),
                bottom_band=float(L[int(L.shape[0] * 0.85):].mean()))


# reference bands from the 2026-10 study of 178 top Roblox thumbnails (see references/market-study.md)
BANDS = {"dark": (0.10, 0.45), "bright": (0.06, 0.30), "contrast": (0.18, 0.30), "sat": (0.40, 0.65),
         "warm": (0.15, 0.50), "cool": (0.10, 0.45), "edges": (0.09, 0.20)}
# measured winners that break the market bands (Sell Hotdogs ads, 2026-10): "cinematic" = A06 Janela Sorriso
# (raw in-engine frame, dark, warm inside x night outside, monster eyes the only white; 4.5 % CTR and rising),
# "island" = A09 Fica na Luz (one pool of light in the dark). Pick with --profile or spec "profile".
PROFILES = {
    "market": BANDS,
    "cinematic": {"dark": (0.35, 0.60), "bright": (0.0, 0.03), "sat": (0.50, 0.72), "warm": (0.55, 0.92),
                  "edges": (0.05, 0.10)},
    "island": {"dark": (0.60, 0.95), "bright": (0.0, 0.03), "sat": (0.30, 0.72), "edges": (0.015, 0.10)},
}


def check(path: Path, icon=False, profile="market"):
    m = metrics(path)
    im = Image.open(path).convert("RGB")
    w = 150 if icon else 250
    h = w if icon else int(w * 9 / 16)
    small = im.resize((w, h), Image.LANCZOS)
    sheet = Image.new("RGB", (w * 2 + 30, h + 20), (30, 30, 30))
    sheet.paste(small, (10, 10))
    sheet.paste(small.convert("L").convert("RGB"), (w + 20, 10))
    prev = path.with_name(path.stem + "_check.png")
    sheet.save(prev)
    notes = []
    for k, (lo, hi) in PROFILES[profile].items():
        v = m[k]
        if v < lo:
            notes.append(f"{k} {v:.2f} < {lo} (low)")
        elif v > hi:
            notes.append(f"{k} {v:.2f} > {hi} (high)")
    if profile == "market":
        if m["warm"] > 0.4 and m["cool"] < 0.08:
            notes.append("monochrome warm: no cool counter-colour -> no temperature contrast")
        if m["bright"] < 0.04:
            notes.append("no bright anchor: add pure-white eyes/text/highlight")
    elif m["bright"] < 0.0005:
        notes.append("no white at all: the monster eyes / light strip must be the brightest pixels")
    print(json.dumps({"file": str(path), "profile": profile, "metrics": {k: round(v, 3) for k, v in m.items()},
                      "warnings": notes, "preview": str(prev)}, indent=1))
    return m, notes


# ------------------------------------------------------------------ batch

def set_path(d, dotted, value):
    keys = dotted.split(".")
    for k in keys[:-1]:
        d = d[int(k)] if isinstance(d, list) else d.setdefault(k, {})
    last = keys[-1]
    if isinstance(d, list):
        d[int(last)] = value
    else:
        d[last] = value


def batch(spec_path: Path, varies: list[str], sheet=True):
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    base = spec_path.parent
    axes = []
    for v in varies:  # form: path.to.key=val1|val2|val3   (JSON values)
        key, vals = v.split("=", 1)
        axes.append((key, [json.loads(x) for x in vals.split("|")]))
    outs = []
    for combo in itertools.product(*[a[1] for a in axes]):
        s = json.loads(json.dumps(spec))
        tag = []
        for (key, _), val in zip(axes, combo):
            set_path(s, key, val)
            tag.append(f"{key.split('.')[-1]}-{str(val).replace(' ', '')[:12]}")
        out = base / f"{Path(spec.get('out', 'thumb.png')).stem}__{'__'.join(tag)}.png"
        compose(s, base, out)
        outs.append(out)
        print(out.name)
    if sheet and outs:
        tiles = [Image.open(o).convert("RGB").resize((320, 180), Image.LANCZOS) for o in outs]
        cols = min(4, len(tiles))
        rows = (len(tiles) + cols - 1) // cols
        S = Image.new("RGB", (cols * 330 + 10, rows * 190 + 10), (30, 30, 30))
        for i, t in enumerate(tiles):
            r, c = divmod(i, cols)
            S.paste(t, (10 + c * 330, 10 + r * 190))
        sp = base / f"{Path(spec.get('out', 'thumb.png')).stem}__sheet.png"
        S.save(sp)
        print(sp.name)
    return outs


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("compose"); c.add_argument("spec"); c.add_argument("--out")
    k = sub.add_parser("check"); k.add_argument("image"); k.add_argument("--icon", action="store_true")
    k.add_argument("--profile", choices=sorted(PROFILES), default="market")
    b = sub.add_parser("batch"); b.add_argument("spec"); b.add_argument("--vary", action="append", default=[])
    a = ap.parse_args()
    if a.cmd == "compose":
        p = Path(a.spec)
        spec = json.loads(p.read_text(encoding="utf-8"))
        out = compose(spec, p.parent, Path(a.out) if a.out else None)
        print(out)
        sz = spec.get("size", [1920, 1080])
        check(out, icon=sz[0] == sz[1], profile=spec.get("profile", "market"))
    elif a.cmd == "check":
        check(Path(a.image), a.icon, a.profile)
    else:
        batch(Path(a.spec), a.vary)


if __name__ == "__main__":
    main()
