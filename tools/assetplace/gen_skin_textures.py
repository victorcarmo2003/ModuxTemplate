"""Class skin outfit sheets (AST-123; design/skins-proposal.md §1). Pillow + numpy only (no Blender, no upload).

    python tools/assetplace/gen_skin_textures.py            # every skin
    python tools/assetplace/gen_skin_textures.py pumpkin    # only skins whose key contains "pumpkin"

Writes Assets/textures/character/skins/T_Skin_<Name>_<Day|Mid|Night>.png (512^2, same UV as T_Crew_Uniform_*) and a
preview board Assets/textures/character/skins/_board.png.

Method: a recolour of the crew uniform, so every seam, crease and stitch of the original sheet is kept.
  - the texels of T_Crew_Uniform_Day are split into families: red (cap, apron, straps, cuffs), cream (shirt),
    dark (pants); everything else (soles, belt, the grey padding) stays as it is
  - each family is mapped to the skin colour keeping its shading: new = target * (luma / reference luma of the family)
  - the hot dog logo of the apron and the badge of the cap are wiped (apron colour) and the skin emblem is drawn there
    (sticker look: cream rim + Ink outline, like the logo)
  - optional apron pattern (stars, stitches, ribs), clipped to the apron block
  - Mid / Night: the per-texel luma ratio of the crew's own Mid / Night sheet (darkening + grime) times a cool tint, and
    the crew sheet's alpha (the Night fur overlay rows are copied as they are)
Fur stays alpha 0: the rig's fur colour shows through (the skin may set its own fur colour, Content.Skins Fur).
Palette: style guide (Ink #2B2233, Cream #FFF1D6, Mustard #F6C12B); no alert red, no blood (kids' light horror).
"""
from __future__ import annotations

import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
TEX = ROOT / "Assets" / "textures" / "character"
OUT = TEX / "skins"

INK = (43, 34, 51)
CREAM = (255, 241, 214)
MUSTARD = (246, 193, 43)
WHITE = (255, 255, 255)

APRON = (316, 282, 492, 446)  # x0, y0, x1, y1 of the apron front block (512 px)
LOGO_SEED = (405, 357)  # inside the hot dog logo of the apron
LOGO_BOX = (377, 305, 436, 416)  # x0, y0, x1, y1 around the logo (its cream rim included)
CAP_SEED = (164, 33)  # inside the hot dog badge of the cap
EMBLEM_AT = (405, 357)  # emblem centre on the apron
EMBLEM_R = 30  # emblem radius (px of 512)
CAP_EMBLEM_R = 11

# Mid / Night cool tint on top of the crew luma ratio (crew cream went 0.58 / 0.61 / 0.74 at Night)
PACK_RATIO = {"Mid": 0.8, "Night": 0.62}  # crew cream went ~0.79 (Mid) / ~0.6 (Night)
TINT = {"Mid": (0.97, 0.98, 1.04), "Night": (0.9, 0.94, 1.1)}

SKINS = {
    # key: name, red -> primary, cream -> secondary, dark -> pants, emblem, pattern
    "skin_dog_pumpkin": dict(
        name="Pumpkin", primary=(242, 140, 40), secondary=(58, 50, 66), pants=(70, 128, 62), emblem="pumpkin",
        pattern=None, sleeve=(58, 50, 66), stripes=(242, 140, 40), cuff=(242, 140, 40), glove=None,
    ),
    "skin_rabbit_ghost": dict(
        name="Ghost", primary=(236, 238, 250), secondary=(214, 218, 238), pants=(139, 147, 181), emblem="ghost", species="Rabbit", fur=(233, 238, 248), fur_cells=((0, 4),),
        pattern="dots", sleeve=(236, 238, 250), cuff=(190, 196, 228), glove=(236, 238, 250),
    ),
    "skin_cat_witch": dict(
        name="Witch", primary=(123, 79, 194), secondary=(52, 46, 60), pants=(74, 46, 110), emblem="moon", species="Cat", fur=(58, 54, 64), fur_cells=((0, 3),),
        pattern="stars", sleeve=(52, 46, 60), cuff=(123, 79, 194), glove=(74, 46, 110),
    ),
    "skin_bear_franken": dict(
        name="Franken", primary=(96, 104, 114), secondary=(110, 154, 85), pants=(46, 42, 54), emblem="bolt", species="Bear", fur=(134, 184, 106), fur_cells=((0, 6),),
        pattern="stitches", sleeve=None, cuff=None, glove=(70, 74, 82),
    ),
    "skin_fox_vampire": dict(
        name="Vampire", primary=(52, 44, 60), secondary=(246, 242, 236), pants=(110, 30, 62), emblem="bat",
        pattern="trim", sleeve=(246, 242, 236), cuff=(110, 30, 62), glove=(250, 250, 250),
    ),
    "skin_owl_skeleton": dict(
        name="Skeleton", primary=(50, 44, 58), secondary=(64, 58, 74), pants=(44, 40, 52), emblem="skull", species="Owl", fur=(74, 70, 80), fur_cells=((0, 7),),
        pattern="ribs", sleeve=(50, 44, 58), stripes=(236, 226, 200), cuff=(50, 44, 58), glove=(236, 226, 200),
    ),
}


def luma(rgb: np.ndarray) -> np.ndarray:
    return rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114


def families(src: np.ndarray) -> dict[str, np.ndarray]:
    r, g, b, a = (src[..., i].astype(int) for i in range(4))
    opaque = a > 0
    red = opaque & (r > g * 1.5) & (r > b * 1.25) & (r > 50)
    cream = opaque & ~red & (r > 196) & (g > 186) & (b > 150)
    dark = opaque & ~red & (np.maximum(np.maximum(r, g), b) < 82)
    return {"red": red, "cream": cream, "dark": dark}


def flood(mask: np.ndarray, seed: tuple[int, int]) -> np.ndarray:
    """4-connected component of `mask` holding `seed` (x, y)."""
    out = np.zeros_like(mask)
    x, y = seed
    if not mask[y, x]:
        return out
    queue = deque([(x, y)])
    out[y, x] = True
    h, w = mask.shape
    while queue:
        cx, cy = queue.popleft()
        for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
            if 0 <= nx < w and 0 <= ny < h and mask[ny, nx] and not out[ny, nx]:
                out[ny, nx] = True
                queue.append((nx, ny))
    return out


def grow(mask: np.ndarray, n: int) -> np.ndarray:
    out = mask.copy()
    for _ in range(n):
        g = out.copy()
        g[1:] |= out[:-1]
        g[:-1] |= out[1:]
        g[:, 1:] |= out[:, :-1]
        g[:, :-1] |= out[:, 1:]
        out = g
    return out


def recolour(rgb: np.ndarray, mask: np.ndarray, target: tuple[int, int, int], ref: float) -> None:
    lum = luma(rgb[mask])
    s = np.clip(lum / max(ref, 1.0), 0.45, 1.45)
    t = np.array(target, dtype=np.float32)
    # dark targets: shading as an additive offset (a multiply would flatten black); light ones: multiply
    dark = luma(t[None])[0] < 90
    if dark:
        col = t[None] + (s[:, None] - 1.0) * 60.0
    else:
        col = t[None] * s[:, None]
    rgb[mask] = np.clip(col, 0, 255)


# --- emblems (drawn 4x, downsampled) ----------------------------------------------------------------------------------

SS = 4


def sticker(d: ImageDraw.ImageDraw, cx: float, cy: float, r: float, fill) -> None:
    """Round badge: Ink outline, cream rim, coloured disc (the hot dog logo is a sticker too)."""
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=INK)
    r1 = r - 2.2 * SS
    d.ellipse((cx - r1, cy - r1, cx + r1, cy + r1), fill=CREAM)
    r2 = r1 - 3 * SS
    d.ellipse((cx - r2, cy - r2, cx + r2, cy + r2), fill=INK)
    r3 = r2 - 1.6 * SS
    d.ellipse((cx - r3, cy - r3, cx + r3, cy + r3), fill=fill)


def emblem_pumpkin(d, cx, cy, r):
    sticker(d, cx, cy, r, (58, 50, 66))
    k = r / 30
    w, h = 21 * k, 17 * k
    d.rectangle((cx - 2.5 * k, cy - h - 6 * k, cx + 2.5 * k, cy - h + 3 * k), fill=(70, 128, 62), outline=INK, width=int(SS))
    for dx, rx in ((-9 * k, 10 * k), (9 * k, 10 * k), (0, 11 * k)):
        d.ellipse((cx + dx - rx, cy - h, cx + dx + rx, cy + h), fill=(242, 140, 40), outline=INK, width=int(1.4 * SS))
    # face: triangle eyes + toothy grin (cute)
    for ex in (-8 * k, 8 * k):
        d.polygon([(cx + ex - 4 * k, cy - 2 * k), (cx + ex + 4 * k, cy - 2 * k), (cx + ex, cy - 9 * k)], fill=INK)
    d.chord((cx - 12 * k, cy - 4 * k, cx + 12 * k, cy + 12 * k), 10, 170, fill=INK)
    d.rectangle((cx - 3 * k, cy + 4 * k, cx + 3 * k, cy + 7 * k), fill=(242, 140, 40))


def emblem_ghost(d, cx, cy, r):
    sticker(d, cx, cy, r, (139, 147, 181))
    k = r / 30
    top, bottom, half = cy - 17 * k, cy + 14 * k, 13 * k
    pts = [(cx - half, cy - 2 * k)]
    waves = 4
    for i in range(waves * 2 + 1):
        x = cx - half + i * (2 * half) / (waves * 2)
        pts.append((x, bottom - (4 * k if i % 2 else 0)))
    pts.append((cx + half, cy - 2 * k))
    d.polygon(pts, fill=WHITE, outline=INK)
    d.ellipse((cx - half, top, cx + half, cy + 9 * k), fill=WHITE)
    d.arc((cx - half, top, cx + half, cy + 9 * k), 180, 360, fill=INK, width=int(1.4 * SS))
    for ex in (-5 * k, 5 * k):
        d.ellipse((cx + ex - 2.6 * k, cy - 7 * k, cx + ex + 2.6 * k, cy - 1 * k), fill=INK)
    d.ellipse((cx - 3 * k, cy + 1 * k, cx + 3 * k, cy + 6 * k), fill=INK)


def star(d, cx, cy, r, fill, outline=None):
    import math

    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts, fill=fill, outline=outline)


def emblem_moon(d, cx, cy, r):
    sticker(d, cx, cy, r, (52, 46, 60))
    k = r / 30
    d.ellipse((cx - 15 * k, cy - 15 * k, cx + 13 * k, cy + 13 * k), fill=MUSTARD)
    d.ellipse((cx - 7 * k, cy - 19 * k, cx + 19 * k, cy + 7 * k), fill=(52, 46, 60))
    star(d, cx + 9 * k, cy + 7 * k, 6.5 * k, CREAM)
    star(d, cx + 3 * k, cy - 6 * k, 3.5 * k, CREAM)


def emblem_bolt(d, cx, cy, r):
    sticker(d, cx, cy, r, (110, 154, 85))
    k = r / 30
    pts = [(-3, -18), (9, -18), (3, -4), (11, -4), (-5, 19), (-1, 2), (-9, 2)]
    d.polygon([(cx + x * k, cy + y * k) for x, y in pts], fill=MUSTARD, outline=INK)
    d.line([(cx + x * k, cy + y * k) for x, y in pts + [pts[0]]], fill=INK, width=int(1.3 * SS))


def emblem_bat(d, cx, cy, r):
    sticker(d, cx, cy, r, (110, 30, 62))
    k = r / 30
    wing = [(-21, -2), (-14, -9), (-9, -3), (-5, -7), (0, -4), (5, -7), (9, -3), (14, -9), (21, -2), (16, 2), (12, 7),
            (7, 4), (3, 9), (0, 6), (-3, 9), (-7, 4), (-12, 7), (-16, 2)]
    d.polygon([(cx + x * k, cy + y * k) for x, y in wing], fill=(52, 44, 60), outline=CREAM)
    d.ellipse((cx - 5 * k, cy - 9 * k, cx + 5 * k, cy + 3 * k), fill=(52, 44, 60))
    d.polygon([(cx - 5 * k, cy - 6 * k), (cx - 3 * k, cy - 13 * k), (cx - 1 * k, cy - 7 * k)], fill=(52, 44, 60))
    d.polygon([(cx + 5 * k, cy - 6 * k), (cx + 3 * k, cy - 13 * k), (cx + 1 * k, cy - 7 * k)], fill=(52, 44, 60))
    for ex in (-2.2 * k, 2.2 * k):
        d.ellipse((cx + ex - 1.3 * k, cy - 5 * k, cx + ex + 1.3 * k, cy - 2.4 * k), fill=MUSTARD)


def emblem_skull(d, cx, cy, r):
    sticker(d, cx, cy, r, (110, 30, 62) if False else (64, 58, 74))
    k = r / 30
    d.ellipse((cx - 14 * k, cy - 16 * k, cx + 14 * k, cy + 10 * k), fill=CREAM, outline=INK, width=int(1.2 * SS))
    d.rounded_rectangle((cx - 8 * k, cy + 4 * k, cx + 8 * k, cy + 15 * k), radius=3 * k, fill=CREAM, outline=INK,
                        width=int(1.2 * SS))
    d.rectangle((cx - 7 * k, cy + 3 * k, cx + 7 * k, cy + 7 * k), fill=CREAM)
    for ex in (-6 * k, 6 * k):
        d.ellipse((cx + ex - 4.5 * k, cy - 7 * k, cx + ex + 4.5 * k, cy + 2 * k), fill=INK)
        d.ellipse((cx + ex + 0.5 * k, cy - 5.5 * k, cx + ex + 2.5 * k, cy - 3.5 * k), fill=WHITE)
    d.polygon([(cx - 2 * k, cy + 5 * k), (cx + 2 * k, cy + 5 * k), (cx, cy + 2 * k)], fill=INK)
    for tx in (-3.5 * k, 0, 3.5 * k):
        d.line([(cx + tx, cy + 8 * k), (cx + tx, cy + 14 * k)], fill=INK, width=int(0.9 * SS))


EMBLEMS = {
    "pumpkin": emblem_pumpkin,
    "ghost": emblem_ghost,
    "moon": emblem_moon,
    "bolt": emblem_bolt,
    "bat": emblem_bat,
    "skull": emblem_skull,
}


def draw_emblem(img: Image.Image, kind: str, cx: int, cy: int, r: int) -> None:
    size = (2 * r + 4) * SS
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    EMBLEMS[kind](d, size / 2, size / 2, r * SS)
    small = layer.resize((2 * r + 4, 2 * r + 4), Image.LANCZOS)
    img.alpha_composite(small, (cx - r - 2, cy - r - 2))


def pattern_layer(kind: str) -> Image.Image:
    """Pattern over the apron block (4x), clipped to the apron texels by the caller."""
    x0, y0, x1, y1 = APRON
    w, h = (x1 - x0) * SS, (y1 - y0) * SS
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    rng = np.random.default_rng(7)
    if kind == "stars":
        for _ in range(26):
            star(d, rng.uniform(0, w), rng.uniform(0, h), rng.uniform(2.5, 4.5) * SS, MUSTARD + (235,))
    elif kind == "dots":
        for _ in range(30):
            cx, cy, rr = rng.uniform(0, w), rng.uniform(0, h), rng.uniform(1.5, 3) * SS
            d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=(190, 196, 228, 255))
    elif kind == "stitches":
        for i in range(7):
            sx, sy = rng.uniform(0.05, 0.9) * w, rng.uniform(0.05, 0.9) * h
            length = rng.uniform(18, 34) * SS
            horiz = i % 2 == 0
            ex, ey = (sx + length, sy) if horiz else (sx, sy + length)
            d.line([(sx, sy), (ex, ey)], fill=INK + (255,), width=int(1.4 * SS))
            n = int(length / (5 * SS))
            for j in range(n + 1):
                t = j / max(n, 1)
                px, py = sx + (ex - sx) * t, sy + (ey - sy) * t
                if horiz:
                    d.line([(px, py - 3 * SS), (px, py + 3 * SS)], fill=INK + (255,), width=int(1.1 * SS))
                else:
                    d.line([(px - 3 * SS, py), (px + 3 * SS, py)], fill=INK + (255,), width=int(1.1 * SS))
    elif kind == "ribs":
        cx = (EMBLEM_AT[0] - x0) * SS
        for i in range(4):
            y = (EMBLEM_AT[1] - y0 + 42 + i * 12) * SS
            for side in (-1, 1):
                d.rounded_rectangle(
                    (cx + side * 6 * SS if side > 0 else cx - 40 * SS, y,
                     cx + 40 * SS if side > 0 else cx - 6 * SS, y + 5 * SS),
                    radius=2.5 * SS, fill=CREAM + (255,),
                )
        d.rounded_rectangle((cx - 3 * SS, (EMBLEM_AT[1] - y0 + 36) * SS, cx + 3 * SS, (EMBLEM_AT[1] - y0 + 92) * SS),
                            radius=3 * SS, fill=CREAM + (255,))
    elif kind == "trim":
        # wine lining along the apron's top and bottom edges
        d.rectangle((0, 0, w, 7 * SS), fill=(110, 30, 62, 255))
        d.rectangle((0, h - 9 * SS, w, h), fill=(110, 30, 62, 255))
    return layer.resize((x1 - x0, y1 - y0), Image.LANCZOS)


def paint_day(spec: dict) -> np.ndarray:
    src = np.asarray(Image.open(TEX / "T_Crew_Uniform_Day.png").convert("RGBA")).astype(np.float32)
    fam = families(src)
    rgb = src[..., :3].copy()
    # logo + cap badge: every texel that is not apron red around the seed (rim, bun, sausage, mustard), kept inside the
    # logo box (the dashed stitches of the apron must not join it), grown 1 px (anti-aliased rim)
    base_red = np.median(src[300:440, 330:370, :3].reshape(-1, 3), axis=0)
    differs = (np.abs(src[..., :3] - base_red).sum(-1) > 45) & (src[..., 3] > 0)
    logo_box = np.zeros_like(differs)
    lx0, ly0, lx1, ly1 = LOGO_BOX
    logo_box[ly0:ly1, lx0:lx1] = True
    logo = grow(flood(differs & logo_box, LOGO_SEED), 2) & logo_box & (src[..., 3] > 0)
    nonred = (src[..., 3] > 0) & ~fam["red"]
    badge = grow(flood(nonred, CAP_SEED), 1) & (src[..., 3] > 0)
    ref = {k: float(np.median(luma(src[..., :3][m]))) for k, m in fam.items()}
    apron_red = fam["red"].copy()
    x0, y0, x1, y1 = APRON
    box = np.zeros_like(apron_red)
    box[y0:y1, x0:x1] = True
    base_apron = np.median(src[..., :3][apron_red & box & ~logo], axis=0)
    for m in (logo, badge):
        rgb[m] = base_apron
        fam["red"] |= m
        fam["cream"] &= ~m
        fam["dark"] &= ~m
    recolour(rgb, fam["red"], spec["primary"], ref["red"])
    recolour(rgb, fam["cream"], spec["secondary"], ref["cream"])
    recolour(rgb, fam["dark"], spec["pants"], ref["dark"])
    out = np.concatenate([rgb, src[..., 3:4]], axis=-1).clip(0, 255).astype(np.uint8)
    img = Image.fromarray(out)
    if spec["pattern"]:
        pat = pattern_layer(spec["pattern"])
        clip = (fam["red"] & box)[y0:y1, x0:x1]
        pa = np.asarray(pat).copy()
        pa[..., 3] = (pa[..., 3] * clip).astype(np.uint8)
        # keep the pattern off the emblem disc
        yy, xx = np.mgrid[y0:y1, x0:x1]
        off = (xx - EMBLEM_AT[0]) ** 2 + (yy - EMBLEM_AT[1]) ** 2 < (EMBLEM_R + 3) ** 2
        pa[..., 3][off] = 0
        img.alpha_composite(Image.fromarray(pa), (x0, y0))
    draw_emblem(img, spec["emblem"], *EMBLEM_AT, EMBLEM_R)
    draw_emblem(img, spec["emblem"], *CAP_SEED, CAP_EMBLEM_R)
    arr = np.asarray(img).copy()
    arr[..., 3] = src[..., 3].astype(np.uint8)  # fur texels stay fur, except the ones the arms paint below
    paint_arms(arr, spec)
    return arr


# --- arms (owner 2026-10-17: "roupa que vai até o braço, com mangas ou luvinhas") -----------------------------------------
# The crew sleeve ends at the shoulder; below it each arm is fur (alpha 0): FUR_R / FUR_L rows (4 faces of ~48 px across,
# the forearm first, the hand last: the paw pad sits on the hand rows) and the hand-end caps (HAND_CAPS). A skin may cover
# the forearm with a long sleeve (`sleeve`: colour, ends in a `cuff` band) and the hand with a glove (`glove`), which also
# covers the hand-end cap. Painted texels become opaque (the fur colour no longer shows there).
FUR_R = (266, 219, 465, 281)  # x0, y0, x1, y1
FUR_L = (120, 331, 316, 397)
HAND_CAPS = ((232, 96, 272, 136), (280, 416, 320, 456))
FOREARM = 0.5  # share of the fur rows that is forearm (the rest is the hand)
FACE = 48.5  # px per arm face across the rows


def shade_rows(arr: np.ndarray, x0: int, x1: int, y0: int, y1: int, colour, top_dark: bool = True) -> None:
    """Flat colour with the house soft shading: a darker first row, a light band, faint face seams."""
    c = np.array(colour, dtype=np.float32)
    for y in range(y0, y1):
        t = (y - y0) / max(y1 - y0 - 1, 1)
        k = 1.0 + 0.08 * np.sin(t * np.pi) - (0.12 if top_dark and y == y0 else 0.0)
        arr[y, x0:x1, :3] = np.clip(c * k, 0, 255).astype(np.uint8)
        arr[y, x0:x1, 3] = 255
    for i in range(1, 4):
        sx = int(round(x0 + FACE * i))
        if x0 < sx < x1:
            arr[y0:y1, sx, :3] = (arr[y0:y1, sx, :3] * 0.9).astype(np.uint8)


def paint_arms(arr: np.ndarray, spec: dict) -> None:
    sleeve, cuff, glove = spec.get("sleeve"), spec.get("cuff"), spec.get("glove")
    for x0, y0, x1, y1 in (FUR_R, FUR_L):
        split = y0 + int(round((y1 - y0) * FOREARM))
        if sleeve is not None:
            shade_rows(arr, x0, x1, y0, split, sleeve, top_dark=False)
            if spec.get("stripes"):
                for y in range(y0 + 4, split - 4, 7):
                    arr[y:y + 3, x0:x1, :3] = np.array(spec["stripes"], dtype=np.uint8)
            if cuff is not None:
                arr[split - 5:split, x0:x1, :3] = np.array(cuff, dtype=np.uint8)
                arr[split - 5:split, x0:x1, 3] = 255
                arr[split - 1, x0:x1, :3] = (np.array(cuff) * 0.75).astype(np.uint8)
        if glove is not None:
            shade_rows(arr, x0, x1, split, y1, glove)
            # glove cuff: a lighter rolled band at the wrist
            arr[split:split + 4, x0:x1, :3] = np.clip(np.array(glove) * 1.15 + 12, 0, 255).astype(np.uint8)
    if glove is not None:
        for x0, y0, x1, y1 in HAND_CAPS:
            region = arr[y0:y1, x0:x1]
            hole = region[..., 3] == 0
            region[hole, :3] = np.array(glove, dtype=np.uint8)
            region[hole, 3] = 255


def pack_from(day: np.ndarray, pack: str) -> np.ndarray:
    d0 = np.asarray(Image.open(TEX / "T_Crew_Uniform_Day.png").convert("RGBA")).astype(np.float32)
    p0 = np.asarray(Image.open(TEX / f"T_Crew_Uniform_{pack}.png").convert("RGBA")).astype(np.float32)
    ratio = np.clip(luma(p0[..., :3]) / np.maximum(luma(d0[..., :3]), 8.0), 0.2, 1.3)
    rgb = day[..., :3].astype(np.float32) * ratio[..., None] * np.array(TINT[pack], dtype=np.float32)
    # texels the skin painted over fur (sleeves, gloves): no crew value there, a flat pack ratio
    covered = (day[..., 3] == 255) & (d0[..., 3] == 0)
    rgb[covered] = day[covered][:, :3].astype(np.float32) * PACK_RATIO[pack] * np.array(TINT[pack], dtype=np.float32)
    out = np.concatenate([rgb, p0[..., 3:4]], axis=-1).clip(0, 255).astype(np.uint8)
    partial = (p0[..., 3] > 0) & (p0[..., 3] < 255) & ~covered
    out[partial] = p0[partial].astype(np.uint8)  # Night fur overlay rows as the crew has them
    out[covered, 3] = 255
    return out


# --- skin atlas (ears-up cap, ears, tail) ------------------------------------------------------------------------------
# The atlas pieces of a rig (Assets.Crew.CapEarsUp, Ears_<A>, Tail_<A>, beak...) are UV'd on the character colour atlas
# (T_Atlas_Kitchen_<Pack>, 4 x 8 cells of 256 x 128 px gradients), not on the outfit sheet. The skin gets its own copy of
# the atlas: the cap cells in the skin colour and, for a skin with its own fur, the species' fur cell in that fur. Every
# atlas piece of that rig wears it (CrewRig.Dress, SkinLooks Atlas). Cells read from the mesh UVs in Studio (2026-10-17):
# CapEarsUp (2,6); fur: dog / bear (0,6), cat (0,3), owl (0,7), rabbit (0,4), fox (0,5) + (0,4); inner ears (1,5), (2,5).
CAP_CELLS = ((1, 1), (2, 6), (2, 7))  # (row, col) of the red cells
ATLAS_OUT = 512


def cap_atlas(spec: dict, pack: str) -> np.ndarray:
    day = np.asarray(Image.open(TEX / "T_Atlas_Kitchen_Day.png").convert("RGBA")).astype(np.float32)
    src = np.asarray(Image.open(TEX / f"T_Atlas_Kitchen_{pack}.png").convert("RGBA")).astype(np.float32)
    rgb = src[..., :3].copy()
    for r, c in CAP_CELLS:
        ys, xs = slice(r * 256, (r + 1) * 256), slice(c * 128, (c + 1) * 128)
        ref = float(luma(day[ys, xs, :3]).mean())
        mask = np.zeros(rgb.shape[:2], bool)
        mask[ys, xs] = True
        recolour(rgb, mask, spec.get("cap", spec["primary"]), ref)
    fur = spec.get("fur")
    if fur is not None:
        for r, c in spec["fur_cells"]:
            ys, xs = slice(r * 256, (r + 1) * 256), slice(c * 128, (c + 1) * 128)
            ref = float(luma(day[ys, xs, :3]).mean())
            mask = np.zeros(rgb.shape[:2], bool)
            mask[ys, xs] = True
            recolour(rgb, mask, fur, ref)
    out = np.concatenate([rgb, src[..., 3:4]], axis=-1).clip(0, 255).astype(np.uint8)
    return np.asarray(Image.fromarray(out).resize((ATLAS_OUT, ATLAS_OUT), Image.LANCZOS))


# --- head (skins with their own fur) -----------------------------------------------------------------------------------
# The uploaded heads carry the species fur baked in (the part Color only tints them), so a skin with its own fur needs its
# own head: T_Head_<A>[_Mid|_Night].png composited over the skin fur (fur under the alpha, the Mid / Night overlay on
# top), opaque. CrewRig.Dress puts it on the Head (SkinLooks Head).
def head(spec: dict, pack: str) -> np.ndarray:
    suffix = "" if pack == "Day" else f"_{pack}"
    src = np.asarray(Image.open(TEX / f"T_Head_{spec['species']}{suffix}.png").convert("RGBA")).astype(np.float32)
    a = src[..., 3:4] / 255.0
    fur = np.array(spec["fur"], dtype=np.float32)[None, None, :]
    rgb = src[..., :3] * a + fur * (1.0 - a)
    out = np.concatenate([rgb, np.full_like(src[..., 3:4], 255)], axis=-1).clip(0, 255).astype(np.uint8)
    return out


def board(paths: list[Path]) -> None:
    tiles = [Image.open(p).convert("RGBA") for p in paths]
    cols = 3
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * 256, rows * 256), (255, 0, 255, 255))
    for i, t in enumerate(tiles):
        bg = Image.new("RGBA", t.size, (255, 0, 255, 255))
        bg.alpha_composite(t)
        sheet.paste(bg.resize((256, 256)), ((i % cols) * 256, (i // cols) * 256))
    sheet.save(OUT / "_board.png")


def main() -> None:
    only = sys.argv[1:]
    OUT.mkdir(parents=True, exist_ok=True)
    days: list[Path] = []
    for key, spec in SKINS.items():
        if only and not any(o in key for o in only):
            continue
        day = paint_day(spec)
        for pack in ("Day", "Mid", "Night"):
            arr = day if pack == "Day" else pack_from(day, pack)
            path = OUT / f"T_Skin_{spec['name']}_{pack}.png"
            Image.fromarray(arr).save(path)
            print(path.relative_to(ROOT))
            if pack == "Day":
                days.append(path)
            if spec.get("fur") is not None:
                hp = OUT / f"T_Skin_{spec['name']}Head_{pack}.png"
                Image.fromarray(head(spec, pack)).save(hp)
                print(hp.relative_to(ROOT))
            cap = OUT / f"T_Skin_{spec['name']}Atlas_{pack}.png"
            Image.fromarray(cap_atlas(spec, pack)).save(cap)
            print(cap.relative_to(ROOT))
    if days:
        board(days)


if __name__ == "__main__":
    main()
