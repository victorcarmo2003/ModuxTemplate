"""ANM-005 Raincoat Lady (AST-059) textures. Pillow + numpy only (no Blender, no upload).

Writes (repo root):  python tools/assetplace/gen_raincoat_textures.py
  Assets/textures/character/T_Civil_Raincoat_<Day|Mid|Night>.png   512^2 outfit sheet, same UV as T_Civil_*
  Assets/textures/character/face/T_Expr_EyesClosed.png             512^2 face, same layout as T_Expr_Normal

Sheet layout (UV of AST-053_CrewBase Torso/legs and AST-053_CivilArms, read from the FBX; sizes in px of 512):
  Torso   samples column x=288 (y 136..174: collar/top -> body -> hem) and x=96 (y 103..109: underside)
  Legs    column x=96 (y 70..100: coat skirt -> boot shaft) and x=32 (y 102..115: boot, sole)
  Arms    boxes R x269..461 y168..217 and L x123..315 y281..330 (sleeve), fur + paws below (alpha 0, copied from T_Civil_A)
  Caps    arm top squares x470..497 y4..31 and y40..67
Everything else is left empty (alpha 0). Day/Mid keep alpha 0 or 255 only (fur colour shows through alpha 0, see
gen_crew_looks.sheet_alpha_problems); Night keeps the navy alpha overlay on the fur rows copied from T_Civil_A_Night.
Palette: coat Yellow #F2C230 (style guide s.2.4), boots green from the Vegetation ramp (#6DBE6A -> #3E8A4A), reflective
tape Cream #FFF1D6; shading is flat bands (the project sheets have no painted outline, only soft creases).
"""
from __future__ import annotations

import sys
from pathlib import Path

import math
import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
import gen_crew_looks as G

TEX = G.TEX_DIR
FACE = TEX / "face"

YELLOW = (242, 194, 48)
YEL_HI = (250, 214, 84)
YEL_SH = (224, 170, 38)
YEL_DK = (178, 122, 22)
CREAM = (255, 241, 214)
GREEN = (62, 138, 74)
GREEN_HI = (109, 190, 106)
GREEN_DK = (34, 92, 52)

# pack tint: per-channel multiplier + additive lift (Night colder/darker but the coat stays yellow)
TINT = {
    "Day": ((1.0, 1.0, 1.0), (0, 0, 0)),
    "Mid": ((0.90, 0.88, 0.95), (2, 3, 8)),
    "Night": ((0.84, 0.84, 0.92), (6, 8, 22)),
}

ARM_R = (269, 168, 462, 218)  # x0, y0, x1, y1 (sleeve rows; fur below is copied)
ARM_L = (123, 281, 316, 331)
CAPS = ((470, 4, 498, 32), (470, 40, 498, 68))
WIN_T = (274, 302)   # torso column window x
WIN_B = (84, 108)    # legs column x=96 / torso underside
WIN_BOOT = (20, 44)  # boots column x=32


def ramp(stops: list[tuple[float, tuple[int, int, int]]], y: float) -> tuple[float, float, float]:
    if y <= stops[0][0]:
        return stops[0][1]
    for (y0, c0), (y1, c1) in zip(stops, stops[1:]):
        if y <= y1:
            t = (y - y0) / (y1 - y0) if y1 > y0 else 0.0
            return tuple(c0[i] + (c1[i] - c0[i]) * t for i in range(3))  # type: ignore[return-value]
    return stops[-1][1]


def fill_rows(arr: np.ndarray, x0: int, x1: int, y0: int, y1: int, stops) -> None:
    for y in range(y0, y1):
        c = ramp(stops, y + 0.5)
        arr[y, x0:x1, :3] = np.round(c).astype(np.uint8)
        arr[y, x0:x1, 3] = 255


def sleeve(arr: np.ndarray, box: tuple[int, int, int, int]) -> None:
    x0, y0, x1, y1 = box
    t = y0
    stops = [
        (t, YEL_SH), (t + 1, YELLOW), (t + 8, YELLOW), (t + 17, YEL_HI), (t + 22, YELLOW), (t + 37, YELLOW),
        (t + 39, YEL_SH),
    ]
    fill_rows(arr, x0, x1, y0, y1, stops)
    # elastic cuff: dark crease, ribbed band, cream reflective tape, outline on the last row
    arr[t + 39, x0:x1, :3] = YEL_DK
    arr[t + 40:t + 50, x0:x1, :3] = YEL_SH
    arr[t + 42:t + 44, x0:x1, :3] = CREAM
    arr[t + 46, x0:x1, :3] = YELLOW
    arr[t + 49, x0:x1, :3] = YEL_DK
    arr[t:t + 50, x0:x1, 3] = 255
    # faint face seams (4 faces of 48 px): a slightly darker column
    for k in range(1, 4):
        sx = x0 + 48 * k
        arr[t + 1:t + 49, sx:sx + 1, :3] = (arr[t + 1:t + 49, sx:sx + 1, :3] * 0.93).astype(np.uint8)


def paint(pack: str) -> Image.Image:
    src = np.asarray(Image.open(TEX / f"T_Civil_A_{pack}.png").convert("RGBA")).copy()
    arr = np.zeros_like(src)
    # fur rows below each sleeve: keep only the partial-alpha overlay (Night) and the pink paw pads of T_Civil_A
    r, g, b_, al = (src[..., i].astype(int) for i in range(4))
    keep = (al > 0) & (al < 255)  # Night overlay
    for px0, py0, px1, py1 in ((365, 250, 403, 277), (129, 362, 166, 391)):  # paw pads (all packs)
        keep[py0:py1, px0:px1] |= al[py0:py1, px0:px1] > 0
    for x0, y0, x1, y1 in (ARM_R, ARM_L):
        reg = np.zeros(keep.shape, bool)
        reg[y1 + 1:y1 + 62, x0 + 1:x1 - 1] = True
        arr[keep & reg] = src[keep & reg]
    base = arr.copy()
    sleeve(arr, ARM_R)
    sleeve(arr, ARM_L)
    for x0, y0, x1, y1 in CAPS:
        arr[y0:y1, x0:x1] = (*YEL_SH, 255)
        arr[y0 + 2:y1 - 2, x0 + 2:x1 - 2, :3] = YELLOW
    # torso column x=288: y136..138 top cap, 138..174 shoulder->hem (z .9 -> -.68)
    fill_rows(arr, *WIN_T, 128, 168, [
        (128, YEL_SH), (136, YEL_SH), (138, YEL_SH), (146, YEL_SH),     # hood-collar band
        (147, YEL_DK), (148.5, YEL_DK), (149.5, YELLOW),               # collar outline
        (153, YEL_HI), (158, YELLOW), (168, YELLOW),
    ])
    # torso rows 168..176 live inside the right-arm box (shared texels): plain coat yellow
    arr[168:176, 274:302, :3] = YELLOW
    arr[168:176, 274:302, 3] = 255
    # torso underside + legs column x=96
    fill_rows(arr, *WIN_B, 101, 112, [(101, YEL_SH), (107, YEL_SH), (108.5, YEL_DK), (112, YEL_DK)])
    fill_rows(arr, *WIN_B, 66, 100, [
        (66, YEL_SH), (72, YEL_SH), (74, YELLOW), (82, YEL_HI), (86, YELLOW), (90, YEL_SH),  # coat skirt
        (90.5, YEL_DK), (91.8, YEL_DK), (92.2, GREEN_HI), (94.5, GREEN_HI), (95, GREEN),      # boot shaft rim
        (100, GREEN),
    ])
    # boots column x=32: y102..113 body, 113..115 sole
    fill_rows(arr, *WIN_BOOT, 100, 118, [
        (100, GREEN), (108, GREEN), (112.5, GREEN_HI), (113.2, GREEN_DK), (118, GREEN_DK),
    ])
    # tint only what was painted (sleeves/torso/legs/boots/caps); fur rows + paws keep the source colour/overlay
    mul, add = TINT[pack]
    painted = (arr != base).any(-1)
    rgb = arr[..., :3].astype(np.float32)
    for i in range(3):
        rgb[..., i] = np.where(painted, rgb[..., i] * mul[i] + add[i], rgb[..., i])
    arr[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    return Image.fromarray(arr)


def face_closed() -> Image.Image:
    im = Image.open(FACE / "T_Expr_Normal.png").convert("RGBA")
    a = np.asarray(im).copy()
    dark = (a[..., 3] > 128) & (a[..., :3].max(-1) < 120)
    dark[230:] = False
    # wipe each eye oval (+ its highlight) and the paw-shaped mouth, keep the blush
    for x0, x1 in ((0, 256), (256, 512)):
        ys, xs = np.nonzero(dark[:, x0:x1])
        a[ys.min() - 3:ys.max() + 4, xs.min() + x0 - 3:xs.max() + x0 + 4] = (0, 0, 0, 0)
    a[232:280, 205:310] = (0, 0, 0, 0)
    out = Image.fromarray(a)
    S = 4  # supersample the strokes
    big = Image.new("RGBA", (512 * S, 512 * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    ink = (28, 24, 44, 255)

    def stroke(cx, cy, w, h, a0, a1, r_end, r_mid):
        n = 80
        for i in range(n + 1):
            t = i / n
            ang = math.radians(a0 + (a1 - a0) * t)
            px = cx + w * math.cos(ang)
            py = cy + h * math.sin(ang)
            r = (r_end + (r_mid - r_end) * math.sin(math.pi * t)) * S
            d.ellipse([px * S - r, py * S - r, px * S + r, py * S + r], fill=ink)

    # closed eyes: calm downward arcs (u-shape), tapered rounded ends
    for cx in (174, 338):
        stroke(cx, 138, 36, 26, 20, 160, 3.5, 6.0)
        side = -1 if cx < 256 else 1  # tiny outer lash flick, same stroke family
        ex = cx + side * 36 * math.cos(math.radians(20)); ey = 138 + 26 * math.sin(math.radians(20))
        for i in range(11):
            t = i / 10
            px = ex + side * 11 * t; py = ey - 7 * t
            r = (3.2 - 1.6 * t) * S
            d.ellipse([px * S - r, py * S - r, px * S + r, py * S + r], fill=ink)
    # mouth: calm small smile
    stroke(256, 244, 24, 13, 25, 155, 2.6, 4.2)
    big = big.resize((512, 512), Image.LANCZOS)
    out.alpha_composite(big)
    return out


if __name__ == "__main__":
    for pack in ("Day", "Mid", "Night"):
        paint(pack).save(TEX / f"T_Civil_Raincoat_{pack}.png")
        print("wrote T_Civil_Raincoat_" + pack)
    face_closed().save(FACE / "T_Expr_EyesClosed.png")
    print("wrote face/T_Expr_EyesClosed.png")
