"""Cinematic post for in-engine thumbnail frames (lote 3, the A06 "Janela Sorriso" recipe).

The A06 is a raw Studio frame: no outline, no text, no glow on the hero. This only adds what that frame has:
16:9 crop + upscale to 1920x1080, an optional soft glow behind the threat (so a black silhouette reads against a dark
street), blurred edges, a vignette and a light warm grade. Spec (JSON):

  {"beauty": "l301_beauty.jpg", "matte": "l301_matte.jpg", "out": "L3-01.png",
   "crop_y": 0.5,                       # 0 = keep top, 1 = keep bottom when cutting to 16:9
   "glow": {"key": "magenta", "color": [150, 90, 255], "radius": 0.22, "strength": 0.55},
   "edge_blur": 0.6, "vignette": 0.45, "warm": 0.06, "sharpen": 0.4, "gain": 1.2,
   "lift": [x, y, r, amount]}          # optional: brighten a spot (normalised coords), e.g. the hero face

Matte colours: magenta = threat, cyan = hero (the Studio Highlight pass of T.matte, mode "visible").
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

W, H = 1920, 1080


def load(path, size=None):
    im = Image.open(path).convert("RGB")
    return im


def crop169(im, cy):
    w, h = im.size
    th = round(w * 9 / 16)
    if th <= h:
        top = round((h - th) * cy)
        return im.crop((0, top, w, top + th))
    tw = round(h * 16 / 9)
    left = (w - tw) // 2
    return im.crop((left, 0, left + tw, h))


def key_mask(im, key):
    a = np.asarray(im).astype(np.float32) / 255
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    if key == "magenta":
        m = (r > 0.75) & (b > 0.75) & (g < 0.35)
    elif key == "cyan":
        m = (g > 0.75) & (b > 0.75) & (r < 0.35)
    else:
        raise ValueError(key)
    return m.astype(np.float32)


def radial(shape, cx, cy, r):
    h, w = shape
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt(((xx / w - cx) * (w / h)) ** 2 + (yy / h - cy) ** 2)
    return np.clip(1 - d / r, 0, 1) ** 1.6


def inpaint(im, lines):
    """Erase thin Studio gizmo lines: [[x1, y1, x2, y2, width], ...] in source pixels."""
    import cv2
    a = np.asarray(im)
    mask = np.zeros(a.shape[:2], np.uint8)
    for x1, y1, x2, y2, w in lines:
        cv2.line(mask, (int(x1), int(y1)), (int(x2), int(y2)), 255, int(w))
    return Image.fromarray(cv2.inpaint(a, mask, 5, cv2.INPAINT_TELEA))


def main(spec_path):
    p = Path(spec_path)
    s = json.loads(p.read_text(encoding="utf-8-sig"))
    base = p.parent
    cy = s.get("crop_y", 0.5)
    src = load(base / s["beauty"])
    if s.get("inpaint"):
        src = inpaint(src, s["inpaint"])
    beauty = crop169(src, cy).resize((W, H), Image.LANCZOS)
    img = np.asarray(beauty).astype(np.float32) / 255

    masks = {}
    if s.get("matte"):
        matte = crop169(load(base / s["matte"]), cy).resize((W, H), Image.NEAREST)
        for k in ("magenta", "cyan"):
            m = key_mask(matte, k)
            masks[k] = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2))) / 255

    g = s.get("glow")
    if g and g["key"] in masks and masks[g["key"]].sum() > 0:
        m = masks[g["key"]]
        ys, xs = np.nonzero(m > 0.5)
        cx, cyy = xs.mean() / W, ys.min() / H + (ys.max() - ys.min()) / H * g.get("y_bias", 0.35)
        blob = radial((H, W), cx, cyy, g.get("radius", 0.22))
        keep = (1 - m)
        if "cyan" in masks:
            keep *= (1 - masks["cyan"])
        dark = np.clip(1 - img.mean(axis=2) * 2.2, 0, 1)  # light the dark background, not the lit interior
        col = np.array(g.get("color", [150, 90, 255]), np.float32) / 255
        img = img + (blob * keep * dark * g.get("strength", 0.5))[..., None] * col

    gain = s.get("gain", 1.0)  # exposure in post: >1 opens the shadows (gamma), keeps the white eyes from clipping more
    if gain != 1.0:
        img = np.clip(img, 0, 1) ** (1 / gain)

    lift = s.get("lift")
    if lift:
        x, y, r, a = lift
        img = img * (1 + radial((H, W), x, y, r)[..., None] * a)

    warm = s.get("warm", 0.0)
    if warm:
        img = img * np.array([1 + warm, 1 + warm * 0.35, 1 - warm * 0.6], np.float32)

    out = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))
    eb = s.get("edge_blur", 0.0)
    if eb:
        blurred = out.filter(ImageFilter.GaussianBlur(7))
        h, w = H, W
        yy, xx = np.mgrid[0:h, 0:w]
        d = np.sqrt(((xx / w - 0.5) * 1.35) ** 2 + ((yy / h - 0.5) * 1.1) ** 2)
        if masks.get("cyan") is not None:
            pass
        t = np.clip((d - 0.38) / 0.32, 0, 1) * eb
        if "cyan" in masks:
            t *= (1 - masks["cyan"] * 0.85)  # the hero stays sharp even at the edge
        a = np.asarray(out).astype(np.float32)
        b = np.asarray(blurred).astype(np.float32)
        out = Image.fromarray((a * (1 - t[..., None]) + b * t[..., None]).astype(np.uint8))
    vg = s.get("vignette", 0.0)
    if vg:
        yy, xx = np.mgrid[0:H, 0:W]
        d = np.sqrt(((xx / W - 0.5) * 1.2) ** 2 + ((yy / H - 0.5) * 1.0) ** 2)
        v = 1 - np.clip((d - 0.3) / 0.5, 0, 1) ** 1.5 * vg
        out = Image.fromarray((np.asarray(out).astype(np.float32) * v[..., None]).clip(0, 255).astype(np.uint8))
    sh = s.get("sharpen", 0.0)
    if sh:
        out = out.filter(ImageFilter.UnsharpMask(radius=2, percent=int(sh * 150), threshold=2))
    dest = base / s["out"]
    out.save(dest, optimize=True)
    print(dest)


if __name__ == "__main__":
    main(sys.argv[1])
