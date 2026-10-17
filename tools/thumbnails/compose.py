"""Thumbnail compositor: background plate + chroma-keyed character layers captured in Studio.

Usage: python tools/thumbnails/compose.py <spec.json>

Spec (paths relative to the spec file):
{
  "out": "out.png", "size": [1920, 1080],
  "bg": {"path": "bg.jpg", "blur": 6, "brightness": 0.8, "tint": [0.85, 0.9, 1.15], "saturation": 0.8,
         "crop": [x0, y0, x1, y1]},             # optional crop in source pixels (default: centre 16:9)
  "spots": [{"at": [0.6, 0.55], "radius": 0.35, "color": [180, 200, 255], "strength": 0.5}],
  "layers": [{"path": "runner.jpg", "key": "green", "scale": 1.3, "offset": [0, 0], "anchor": "bottom",
              "saturation": 1.3, "contrast": 1.1, "brightness": 1.05,
              "outline": {"color": [255, 255, 255], "width": 8},
              "glow": {"color": [120, 170, 255], "width": 40, "strength": 0.8},
              "rim": {"color": [140, 180, 255], "side": "right", "strength": 0.5}}],
  "vignette": 0.55, "grade": {"contrast": 1.08, "saturation": 1.1}
}
A layer may instead give "at": [x, y] (fractions of the canvas) and "height" (fraction of the canvas height) to be
fitted by its own matte, plus "flip": true to mirror it. Layers are drawn in order (first = furthest back). Layer pixels share the background's source frame (same Studio
camera), so "offset" is in output pixels and "scale" grows the layer about its own bottom (or centre) point.
"""
import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


def load(path):
    return np.asarray(Image.open(path).convert("RGB")).astype(np.float32) / 255.0


def saturate(rgb, amount):
    grey = rgb.mean(axis=2, keepdims=True)
    return np.clip(grey + (rgb - grey) * amount, 0, 1)


def contrast(rgb, amount):
    return np.clip((rgb - 0.5) * amount + 0.5, 0, 1)


def key(rgb, colour="green", lo=0.3, hi=0.5, spill=7):
    """Chroma key against a green or magenta backdrop. Spill is cleaned only on the matte edge, so green or purple
    clothes inside the character keep their colour."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    if colour == "magenta":
        dominance = np.minimum(r, b) - g
    else:
        dominance = g - np.maximum(r, b)
    alpha = 1.0 - np.clip((dominance - lo) / (hi - lo), 0, 1)
    alpha = cv2.morphologyEx(alpha, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    edge = np.clip(cv2.GaussianBlur(1.0 - cv2.erode(alpha, np.ones((spill, spill), np.uint8)), (0, 0), 2), 0, 1)
    out = rgb.copy()
    if colour == "magenta":
        cap = np.minimum(np.minimum(r, b), g * 1.02 + 0.02)
        out[..., 0] = r * (1 - edge) + np.minimum(r, cap + (r - np.minimum(r, b))) * edge
        out[..., 2] = b * (1 - edge) + np.minimum(b, cap + (b - np.minimum(r, b))) * edge
    else:
        out[..., 1] = g * (1 - edge) + np.minimum(g, np.maximum(r, b) * 1.02) * edge
    alpha = cv2.GaussianBlur(alpha, (0, 0), 0.8)
    return out, alpha


def cover_crop(img, size, crop=None):
    h, w = img.shape[:2]
    tw, th = size
    if crop:
        x0, y0, x1, y1 = crop
    else:
        target = tw / th
        if w / h > target:
            cw = int(h * target)
            x0, y0, x1, y1 = (w - cw) // 2, 0, (w - cw) // 2 + cw, h
        else:
            ch = int(w / target)
            x0, y0, x1, y1 = 0, (h - ch) // 2, w, (h - ch) // 2 + ch
    return (x0, y0, x1, y1), cv2.resize(img[y0:y1, x0:x1], (tw, th), interpolation=cv2.INTER_CUBIC)


def radial(size, at, radius):
    tw, th = size
    yy, xx = np.mgrid[0:th, 0:tw].astype(np.float32)
    d = np.sqrt((xx / tw - at[0]) ** 2 * (tw / th) ** 2 + (yy / th - at[1]) ** 2)
    return np.clip(1.0 - d / radius, 0, 1) ** 2


def over(dst, src, alpha):
    a = alpha[..., None]
    return dst * (1 - a) + src * a


def place_at(canvas_size, rgb, alpha, at, height, anchor, flip=False):
    """Fit a layer by its own matte: its bounding box becomes `height` (fraction of the canvas height) and its anchor
    (bottom-centre or centre) lands on `at` (fractions of the canvas). For layers shot with their own camera."""
    tw, th = canvas_size
    if flip:
        rgb, alpha = rgb[:, ::-1].copy(), alpha[:, ::-1].copy()
    ys, xs = np.nonzero(alpha > 0.5)
    if len(xs) == 0:
        return np.zeros((th, tw, 3), np.float32), np.zeros((th, tw), np.float32)
    scale = height * th / (ys.max() - ys.min() + 1)
    cx = (xs.min() + xs.max()) / 2
    cy = ys.max() if anchor == "bottom" else (ys.min() + ys.max()) / 2
    m = np.float32([[scale, 0, at[0] * tw - scale * cx], [0, scale, at[1] * th - scale * cy]])
    rgb = cv2.warpAffine(rgb, m, (tw, th), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_CONSTANT)
    alpha = cv2.warpAffine(alpha, m, (tw, th), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT)
    return np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)


def place(canvas_size, rgb, alpha, crop, scale, offset, anchor):
    """Map a layer from the source frame onto the canvas (same crop as the background), then scale about its anchor."""
    tw, th = canvas_size
    x0, y0, x1, y1 = crop
    sx = tw / (x1 - x0)
    rgb = cv2.resize(rgb[y0:y1, x0:x1], (tw, th), interpolation=cv2.INTER_CUBIC)
    alpha = cv2.resize(alpha[y0:y1, x0:x1], (tw, th), interpolation=cv2.INTER_LINEAR)
    ys, xs = np.nonzero(alpha > 0.5)
    if len(xs) == 0:
        return rgb, alpha
    cx = (xs.min() + xs.max()) / 2
    cy = ys.max() if anchor == "bottom" else (ys.min() + ys.max()) / 2
    m = np.float32([[scale, 0, cx - scale * cx + offset[0]], [0, scale, cy - scale * cy + offset[1]]])
    rgb = cv2.warpAffine(rgb, m, (tw, th), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_CONSTANT)
    alpha = cv2.warpAffine(alpha, m, (tw, th), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT)
    return np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)


def dilate(alpha, width):
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * width + 1, 2 * width + 1))
    return cv2.dilate(alpha, k)


def main(spec_path):
    spec_path = Path(spec_path)
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    base = spec_path.parent
    size = tuple(spec.get("size", [1920, 1080]))
    tw, th = size

    bgs = spec["bg"]
    crop, bg = cover_crop(load(base / bgs["path"]), size, bgs.get("crop"))
    if bgs.get("blur"):
        bg = cv2.GaussianBlur(bg, (0, 0), bgs["blur"])
    bg = saturate(bg, bgs.get("saturation", 1.0))
    bg = bg * np.float32(bgs.get("tint", [1, 1, 1])) * bgs.get("brightness", 1.0)
    canvas = np.clip(bg, 0, 1)

    for spot in spec.get("spots", []):
        mask = radial(size, spot["at"], spot["radius"]) * spot.get("strength", 0.5)
        col = np.float32(spot["color"]) / 255.0
        canvas = np.clip(canvas + mask[..., None] * col, 0, 1)

    for layer in spec["layers"]:
        rgb, alpha = key(load(base / layer["path"]), layer.get("key", "green"), spill=layer.get("spill", 7))
        rgb = saturate(rgb, layer.get("saturation", 1.0))
        rgb = contrast(rgb, layer.get("contrast", 1.0))
        rgb = np.clip(rgb * layer.get("brightness", 1.0), 0, 1)
        if "at" in layer:
            rgb, alpha = place_at(size, rgb, alpha, layer["at"], layer.get("height", 0.8), layer.get("anchor", "bottom"),
                                  layer.get("flip", False))
        else:
            rgb, alpha = place(size, rgb, alpha, crop, layer.get("scale", 1.0), layer.get("offset", [0, 0]),
                               layer.get("anchor", "bottom"))

        glow = layer.get("glow")
        if glow:
            g = cv2.GaussianBlur(dilate(alpha, max(1, glow["width"] // 3)), (0, 0), glow["width"] / 2)
            col = np.float32(glow["color"]) / 255.0
            canvas = np.clip(canvas + (g * glow.get("strength", 0.8))[..., None] * col, 0, 1)

        outline = layer.get("outline")
        if outline:
            ring = np.clip(dilate(alpha, outline["width"]), 0, 1)
            ring = cv2.GaussianBlur(ring, (0, 0), 0.8)
            canvas = over(canvas, np.ones_like(canvas) * (np.float32(outline["color"]) / 255.0), ring)

        rim = layer.get("rim")
        if rim:
            shift = 10 if rim.get("side", "right") == "right" else -10
            inner = alpha - np.roll(alpha, shift, axis=1)
            inner = cv2.GaussianBlur(np.clip(inner, 0, 1), (0, 0), 4) * rim.get("strength", 0.5)
            rgb = np.clip(rgb + inner[..., None] * (np.float32(rim["color"]) / 255.0), 0, 1)

        canvas = over(canvas, rgb, alpha)

    grade = spec.get("grade", {})
    canvas = contrast(saturate(canvas, grade.get("saturation", 1.0)), grade.get("contrast", 1.0))

    vig = spec.get("vignette", 0)
    if vig:
        yy, xx = np.mgrid[0:th, 0:tw].astype(np.float32)
        d = np.sqrt(((xx / tw - 0.5) * 2) ** 2 + ((yy / th - 0.5) * 2) ** 2) / np.sqrt(2)
        canvas = canvas * (1 - vig * np.clip(d, 0, 1) ** 2)[..., None]

    out = base / spec.get("out", "thumbnail.png")
    Image.fromarray((np.clip(canvas, 0, 1) * 255).astype(np.uint8)).save(out)
    print(out)


if __name__ == "__main__":
    main(sys.argv[1])
