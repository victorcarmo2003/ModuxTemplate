"""Outline characters that are staged inside a real Studio scene (props in front of them keep covering them).

Three captures from the same Studio camera:
  beauty   the scene as it renders
  visible  each character drawn as a flat Highlight colour, DepthMode Occluded (only the parts the camera sees)
  full     the same Highlights with DepthMode AlwaysOnTop (the whole character, through props)

The outline is drawn around the visible part, except where the character continues behind a prop: there the edge is
the prop's, not the character's, so no line is drawn.

Usage: python tools/thumbnails/scene_outline.py <spec.json>
{
  "out": "thumb.png", "size": [1920, 1080],
  "beauty": "beauty.jpg", "visible": "vis.jpg", "full": "full.jpg",
  "crop": [x0, y0, x1, y1],                      # optional, source pixels (default: centre 16:9)
  "characters": [{"key": [255, 0, 255], "outline": [255, 255, 255], "width": 9,      # back to front
                  "saturation": 1.25, "contrast": 1.08, "brightness": 1.0}],
  "background": {"saturation": 1.0, "brightness": 1.0, "blur": 0},
  "grade": {"saturation": 1.05, "contrast": 1.04}
}
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


def key_mask(img, colour, tolerance=0.22):
    distance = np.linalg.norm(img - np.float32(colour) / 255.0, axis=2)
    mask = (distance < tolerance).astype(np.float32)
    return cv2.morphologyEx(mask, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))


def disc(width):
    return cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * width + 1, 2 * width + 1))


def crop_box(shape, size, crop):
    h, w = shape[:2]
    if crop:
        return crop
    target = size[0] / size[1]
    if w / h > target:
        cw = int(h * target)
        return (w - cw) // 2, 0, (w - cw) // 2 + cw, h
    ch = int(w / target)
    return 0, (h - ch) // 2, w, (h - ch) // 2 + ch


def main(spec_path):
    spec_path = Path(spec_path)
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    base = spec_path.parent
    size = tuple(spec.get("size", [1920, 1080]))

    beauty = load(base / spec["beauty"])
    visible = load(base / spec["visible"])
    full = load(base / spec["full"])
    x0, y0, x1, y1 = crop_box(beauty.shape, size, spec.get("crop"))

    def fit(img, interp=cv2.INTER_CUBIC):
        return cv2.resize(img[y0:y1, x0:x1], size, interpolation=interp)

    beauty, visible, full = fit(beauty), fit(visible, cv2.INTER_NEAREST), fit(full, cv2.INTER_NEAREST)

    characters = spec["characters"]
    masks = []
    for ch in characters:
        vis = key_mask(visible, ch["key"])
        whole = np.maximum(key_mask(full, ch["key"]), vis)
        masks.append((vis, whole))
    subjects = np.clip(sum(v for v, _ in masks), 0, 1)

    bg = spec.get("background", {})
    canvas = beauty.copy()
    if bg.get("blur"):
        canvas = cv2.GaussianBlur(canvas, (0, 0), bg["blur"])
    focus = bg.get("focus")
    if focus:
        # depth-of-field look: the further a pixel is from the characters, the blurrier it gets
        distance = cv2.distanceTransform((1 - subjects).astype(np.uint8), cv2.DIST_L2, 5)
        ramp = np.clip((distance - focus.get("near", 20)) / max(1, focus.get("far", 500)), 0, 1)[..., None]
        canvas = canvas * (1 - ramp) + cv2.GaussianBlur(canvas, (0, 0), focus.get("blur", 10)) * ramp
    canvas = np.clip(saturate(canvas, bg.get("saturation", 1.0)) * bg.get("brightness", 1.0), 0, 1)
    if bg.get("tint"):
        # colour cast on the environment only (e.g. cool blue so warm characters pop)
        canvas = np.clip(canvas * np.float32(bg["tint"]), 0, 1)
    if bg.get("lift"):
        # raise the blacks toward a colour (deep navy instead of pure black)
        lift = np.float32(bg["lift"]) / 255.0
        canvas = canvas + (1 - canvas) * lift * (1 - canvas.mean(axis=2, keepdims=True))
        canvas = np.clip(canvas, 0, 1)

    # characters keep their own (sharp) pixels, with their own colour boost and optional cel bands
    for ch, (vis, _) in zip(characters, masks):
        # "pixels": take this character from another capture of the same camera (e.g. a lit pass)
        source = fit(load(base / ch["pixels"])) if ch.get("pixels") else beauty
        px = saturate(source, ch.get("saturation", 1.2))
        px = contrast(px, ch.get("contrast", 1.06)) * ch.get("brightness", 1.0)
        cel = ch.get("cel")
        if cel:
            lum = px.mean(axis=2, keepdims=True) + 1e-4
            smooth = cv2.bilateralFilter(lum[..., 0].astype(np.float32), 9, 0.1, 6)[..., None]
            bands = cel.get("bands", 4)
            stepped = np.floor(smooth * bands + 0.5) / bands
            shaded = np.clip(px * (stepped / lum), 0, 1)
            px = px * (1 - cel.get("strength", 0.5)) + shaded * cel.get("strength", 0.5)
        if ch.get("tint"):
            # take on part of the environment's colour so the character sits in the same light
            amount = ch.get("tint_amount", 0.4)
            px = px * (1 - amount) + px * np.float32(ch["tint"]) * amount
        rim = ch.get("rim")
        if rim:
            # light wrapping the silhouette from behind (e.g. headlights): bright band just inside the edge
            band = np.clip(vis - cv2.erode(vis, disc(rim.get("width", 6))), 0, 1)
            band = cv2.GaussianBlur(band, (0, 0), rim.get("soft", 3))
            px = px + band[..., None] * (np.float32(rim.get("color", [255, 236, 200])) / 255.0) * rim.get("strength", 0.6)
        soft = cv2.GaussianBlur(vis, (0, 0), 0.7)[..., None]
        canvas = canvas * (1 - soft) + np.clip(px, 0, 1) * soft

    key = spec.get("key_light")
    if key:
        # soft light pooled on the characters, the rest of the frame a little darker
        glow = cv2.GaussianBlur(subjects, (0, 0), key.get("spread", 120))
        glow = glow / max(glow.max(), 1e-4)
        tint = np.float32(key.get("color", [255, 240, 220])) / 255.0
        canvas = canvas * (1 - key.get("dim", 0.25) * (1 - glow[..., None]))
        canvas = np.clip(canvas + glow[..., None] * tint * key.get("strength", 0.12), 0, 1)

    # outlines, back to front as listed: a character's line never covers the ones listed after it (in front of it).
    # The matte is smoothed first (blur + threshold) and the ring comes from a distance field, so the line has an even
    # width and an anti-aliased edge instead of following the jagged capture pixels.
    for index, (ch, (vis, whole)) in enumerate(zip(characters, masks)):
        width = ch.get("width", 9)
        if width <= 0:
            continue
        smooth =(cv2.GaussianBlur(vis, (0, 0), ch.get("smooth", 2.5)) > 0.5).astype(np.uint8)
        outside = cv2.distanceTransform(1 - smooth, cv2.DIST_L2, 5)
        ring = np.clip(width + 0.5 - outside, 0, 1) * (1 - smooth)
        hidden = np.clip(whole - vis, 0, 1)
        block = cv2.dilate(hidden, disc(width + 3))
        for front_vis, _ in masks[index + 1:]:
            block = np.maximum(block, front_vis)
        ring = ring * (1 - cv2.GaussianBlur(block, (0, 0), 1.5))
        border = ch.get("border")
        if border:
            # thin dark line outside the main one (sticker look)
            edge = np.clip(width + border.get("width", 3) + 0.5 - outside, 0, 1) * (1 - smooth) - ring
            edge = np.clip(edge, 0, 1) * (1 - cv2.GaussianBlur(block, (0, 0), 1.5))
            dark = np.float32(border.get("color", [20, 15, 25])) / 255.0
            canvas = canvas * (1 - edge[..., None]) + dark * edge[..., None]
        colour = np.float32(ch.get("outline", [255, 255, 255])) / 255.0
        canvas = canvas * (1 - ring[..., None]) + colour * ring[..., None]

    # lamps: bright pixels inside a character's visible mask (e.g. headlights) get a white core and a tight glow
    for ch, (vis, _) in zip(characters, masks):
        lamp = ch.get("lamps")
        if not lamp:
            continue
        lum = beauty.mean(axis=2)
        core = (lum > lamp.get("threshold", 0.8)).astype(np.float32) * cv2.dilate(vis, disc(4))
        core = cv2.morphologyEx(core, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
        colour = np.float32(lamp.get("color", [255, 240, 200])) / 255.0
        canvas = np.clip(canvas + core[..., None] * lamp.get("core", 0.35), 0, 1)
        for sigma, amount in ((lamp.get("size", 14), lamp.get("strength", 0.9)), (lamp.get("size", 14) * 3, lamp.get("strength", 0.9) * 0.35)):
            halo = cv2.GaussianBlur(core, (0, 0), sigma)
            halo = halo / max(halo.max(), 1e-4)
            canvas = np.clip(canvas + halo[..., None] * colour * amount, 0, 1)

    bloom = spec.get("bloom")
    if bloom:
        bright = np.clip((canvas - bloom.get("threshold", 0.8)) / (1 - bloom.get("threshold", 0.8)), 0, 1)
        canvas = np.clip(canvas + cv2.GaussianBlur(bright, (0, 0), bloom.get("size", 25)) * bloom.get("strength", 0.5), 0, 1)

    grade = spec.get("grade", {})
    canvas = contrast(saturate(canvas, grade.get("saturation", 1.0)), grade.get("contrast", 1.0))
    split = grade.get("split")
    if split:
        # split toning: shadows pulled to one colour, highlights to another
        lum = canvas.mean(axis=2, keepdims=True)
        shadow = np.float32(split.get("shadows", [40, 60, 120])) / 255.0
        high = np.float32(split.get("highlights", [255, 225, 190])) / 255.0
        amount = split.get("amount", 0.12)
        canvas = canvas + (shadow - 0.5) * (1 - lum) * amount + (high - 0.5) * lum * amount
        canvas = np.clip(canvas, 0, 1)
    vignette = spec.get("vignette", 0)
    if vignette:
        h, w = canvas.shape[:2]
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        d = np.sqrt(((xx / w - 0.5) * 2) ** 2 + ((yy / h - 0.5) * 2) ** 2) / np.sqrt(2)
        canvas = canvas * (1 - vignette * np.clip(d, 0, 1) ** 2)[..., None]
    out = base / spec.get("out", "thumbnail.png")
    Image.fromarray((np.clip(canvas, 0, 1) * 255).astype(np.uint8)).save(out)
    print(out)


if __name__ == "__main__":
    main(sys.argv[1])
