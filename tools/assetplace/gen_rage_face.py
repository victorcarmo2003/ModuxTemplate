"""ANM-011 rage face `T_Expr_Rage` (the shaker's tantrum, Content.PlateThrow.Rage.Face). Pillow + numpy only.

Writes (repo root):  python tools/assetplace/gen_rage_face.py [--preview out.png] [--rgba out.rgba]
  Assets/textures/character/face/T_Expr_Rage.png   512^2 RGBA, transparent background, same frontal face layout as every
                                                   T_Expr_* (Face_<A> shell UV v2: eye centres at px (174, 154) / (338, 154),
                                                   205 px per stud, image left = the character's right)
  --preview  side by side Angry x Rage over a fur disc, with the tantrum grin (T.addGrin / Tantrum buildGrin, cat head)
             projected frontally where it lands, to check that nothing important hides under it
  --rgba     raw 512x512 RGBA bytes (row 0 = top) for a local EditableImage preview in Studio (no upload)

Look (owner 2026-10-22, Provisional): macabre fury. Wide bloodshot eyes (cream sclera warming to red at the rim, thin
branching red veins, dark sunken shadow under them), tiny pinprick pupils with a dark red ring and two faint offset
echoes (they tremble), very low V brows that cut the inner top of each eye, furrow between the brows, dark red flushed
cheeks with hatching, one popping anger vein on the temple, tremor ticks beside the eyes. NO mouth: the 3D grin of teeth and
tongue (Tantrum) covers px x 92..420 / y 185..329 on a cat head, so the eyes sit RAISE = 12 px higher than Normal and
the cheeks go up and out (checked in Studio on cat and dog, 2026-10-22). Not the ANM-013 sign (plain white eyes, no pupil).
Strokes and the ink colour follow paint_heads.py (roblox-cartoon-animal-char skill): analytic anti-aliased SDF shapes,
eye outline 3.4 px half width in EYE_INK.
"""
from __future__ import annotations

import argparse
import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
FACE = ROOT / "Assets/textures/character/face"
OUT = FACE / "T_Expr_Rage.png"

S = 512
PX = 0.40 * S                      # px per stud (hcommon.K * FACE_RES)
EYE_CX = (174.08, 337.92)          # u = 0.5 -+ K * 0.40 stud
EYE_CY = 153.6                     # v = V_EYE = 0.30
EYE_INK = (20, 20, 36)
BROW_INK = (38, 14, 20)

ys, xs = np.mgrid[0:S, 0:S].astype(np.float32)
X, Y = xs + 0.5, ys + 0.5


# ------------------------------------------------------------------ sdf helpers (pixel space, y down)
def cov(d, aa=1.0):
    return np.clip(0.5 - d / aa, 0.0, 1.0)


def soft(d, w):
    t = np.clip(0.5 - d / w, 0.0, 1.0)
    return t * t * (3 - 2 * t)


def sd_ellipse(cx, cy, rx, ry):
    px, py = X - cx, Y - cy
    k = np.sqrt((px / rx) ** 2 + (py / ry) ** 2)
    g = np.sqrt((px / rx ** 2) ** 2 + (py / ry ** 2) ** 2) / np.maximum(k, 1e-6)
    return (k - 1) / np.maximum(g, 1e-6)


def sd_capsule(a, b, r):
    ax, ay = a
    bx, by = b
    vx, vy = bx - ax, by - ay
    h = np.clip(((X - ax) * vx + (Y - ay) * vy) / (vx * vx + vy * vy + 1e-9), 0, 1)
    return np.hypot(X - ax - vx * h, Y - ay - vy * h) - r


def sd_taper(pts, r0, r1):
    """polyline whose radius goes r0 -> r1 along its length"""
    seg = [math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(pts[:-1], pts[1:])]
    total = sum(seg) or 1.0
    d = np.full(X.shape, 1e9, np.float32)
    run = 0.0
    for (a, b), L in zip(zip(pts[:-1], pts[1:]), seg):
        ax, ay = a
        bx, by = b
        vx, vy = bx - ax, by - ay
        h = np.clip(((X - ax) * vx + (Y - ay) * vy) / (vx * vx + vy * vy + 1e-9), 0, 1)
        t = (run + h * L) / total
        r = r0 + (r1 - r0) * t
        d = np.minimum(d, np.hypot(X - ax - vx * h, Y - ay - vy * h) - r)
        run += L
    return d


def sd_halfplane(p0, p1):
    """> 0 above the line p0 -> p1 (smaller y), < 0 below"""
    (x0, y0), (x1, y1) = p0, p1
    nx, ny = y1 - y0, -(x1 - x0)          # normal pointing up when x1 > x0
    if ny > 0:
        nx, ny = -nx, -ny
    n = math.hypot(nx, ny)
    return ((X - x0) * nx + (Y - y0) * ny) / n


class Layer:
    """straight-alpha RGBA canvas with 'over' compositing (paint_heads.Layer)"""

    def __init__(self):
        self.rgb = np.zeros((S, S, 3), np.float32)
        self.a = np.zeros((S, S), np.float32)

    def paint(self, c, col, k=1.0, mask=None):
        c = np.clip(c * k, 0, 1).astype(np.float32)
        if mask is not None:
            c = c * mask
        col = np.asarray(col, np.float32) / 255
        if col.ndim == 1:
            col = np.broadcast_to(col, (S, S, 3))
        na = c + self.a * (1 - c)
        self.rgb = (col * c[..., None] + self.rgb * (self.a * (1 - c))[..., None]) / np.maximum(na, 1e-5)[..., None]
        self.a = na

    def image(self, under=(40, 30, 34)):
        rgb = np.where((self.a <= 0.002)[..., None], np.asarray(under, np.float32) / 255, self.rgb)
        arr = (np.clip(np.dstack([rgb, self.a[..., None]]), 0, 1) * 255 + 0.5).astype(np.uint8)
        return Image.fromarray(arr)


# ------------------------------------------------------------------ pieces
RX, RY = 40.0, 50.0                # wide open (Normal 33.8 x 48.4)
RAISE = 12.0                       # px the eyes sit higher than Normal: the grin's top edge reaches px y 185..195 there
LID_IN, LID_OUT = 0.22, 0.95       # lid line height at the inner / outer edge, in RY above the centre


def eye_geom(i):
    cx = EYE_CX[i]
    inward = 1 if i == 0 else -1   # image left eye: the nose is to its right
    cy = EYE_CY - RAISE
    inner = (cx + inward * (RX + 4), cy - RY * LID_IN)
    outer = (cx - inward * (RX + 4), cy - RY * LID_OUT)
    e = sd_ellipse(cx, cy, RX, RY)
    lid = sd_halfplane(outer, inner)
    eye = np.maximum(e, lid)       # the ellipse below the lid line
    return cx, cy, inward, inner, outer, e, lid, eye


def veins(L, rng, cx, cy, eye_mask, pupil_d):
    col = (196, 26, 40)
    keep = eye_mask * cov(6.0 - pupil_d)
    for k in range(10):
        ang = math.radians(rng.uniform(-10, 190) if k % 3 else rng.uniform(170, 370))
        x, y = cx + RX * 0.98 * math.cos(ang), cy + RY * 0.98 * math.sin(ang)
        pts = [(x, y)]
        head = math.atan2(cy - y, cx - x) + rng.uniform(-0.35, 0.35)
        for _ in range(int(rng.integers(4, 7))):
            step = rng.uniform(4.0, 6.5)
            head += rng.uniform(-0.55, 0.55)
            x, y = x + step * math.cos(head), y + step * math.sin(head)
            pts.append((x, y))
        L.paint(cov(sd_taper(pts, 1.1, 0.35)), col, 0.9, mask=keep)
        if rng.random() < 0.7:     # one branch
            j = int(rng.integers(1, len(pts) - 1))
            bx, by = pts[j]
            bh = head + (0.9 if rng.random() < 0.5 else -0.9)
            bpts = [(bx, by)]
            for _ in range(3):
                bx, by = bx + 4.0 * math.cos(bh), by + 4.0 * math.sin(bh)
                bh += rng.uniform(-0.4, 0.4)
                bpts.append((bx, by))
            L.paint(cov(sd_taper(bpts, 0.7, 0.25)), col, 0.8, mask=keep)


def anger_mark(L, cx, cy, r=11.0, off=13.5, rot=15.0):
    """the cartoon popping vein (four bulging arcs, as Stressed / Angry), bigger and blood dark"""
    for a in (0, 90, 180, 270):
        a2 = a + rot
        ca, sa = math.cos(math.radians(a2)), math.sin(math.radians(a2))
        ox, oy = cx + off * ca, cy + off * sa
        pts = [(ox + r * math.cos(math.radians(t)), oy + r * math.sin(math.radians(t))) for t in range(int(a2 + 100), int(a2 + 261), 10)]
        d = sd_taper(pts, 1.9, 1.9)
        L.paint(cov(d - 0.9), (84, 6, 18))
        L.paint(cov(d), (188, 22, 40))


def cheek(L, cx_eye, inward):
    s = -inward
    ccx, ccy = cx_eye + s * 88, 198.0
    d = sd_ellipse(ccx, ccy, 31, 17)
    L.paint(soft(d, 12), (124, 10, 26), 0.85)
    L.paint(soft(d + 6, 10), (150, 16, 32), 0.55)
    for k in (-1, 0, 1):            # anger hatching
        a = (ccx + k * 12 - 4.5, ccy + 6.5)
        b = (ccx + k * 12 + 4.5, ccy - 6.5)
        L.paint(cov(sd_capsule(a, b, 1.5)), (74, 4, 16), 0.85)


def tremor_ticks(L, cx, cy, inward):
    s = -inward
    for k, (off, h) in enumerate(((13, 13), (22, 9))):
        x = cx + s * (RX + off)
        pts = [(x - s * 2.5, cy - h), (x + s * 1.2, cy - h * 0.35), (x + s * 1.2, cy + h * 0.35), (x - s * 2.5, cy + h)]
        L.paint(cov(sd_taper(pts, 2.0, 1.1)), BROW_INK, 0.9 - 0.15 * k)


def furrow(L, cy):
    for s in (-1, 1):
        pts = [(256 + s * 6.5, cy - 14), (256 + s * 8.5, cy - 28)]
        L.paint(cov(sd_taper(pts, 2.2, 0.9)), BROW_INK, 0.85)


def rage() -> Image.Image:
    L = Layer()
    rng = np.random.default_rng(1101)
    cy0 = EYE_CY - RAISE

    # sunken dark shadow around / under the eyes (drawn first, under everything)
    for i in range(2):
        L.paint(soft(sd_ellipse(EYE_CX[i], cy0 + 20, RX + 16, RY + 6), 22), (58, 6, 26), 0.42)

    for i in range(2):
        cheek(L, EYE_CX[i], 1 if i == 0 else -1)

    for i in range(2):
        cx, cy, inward, inner, outer, e, lid, eye = eye_geom(i)
        inside = cov(eye)
        # sclera: cream warming to blood red at the rim
        k = np.sqrt(((X - cx) / RX) ** 2 + ((Y - cy) / RY) ** 2)
        t = np.clip((k - 0.35) / 0.65, 0, 1) ** 1.6
        base = np.asarray((246, 238, 214), np.float32)
        rim = np.asarray((214, 104, 98), np.float32)
        sclera = base * (1 - t[..., None]) + rim * t[..., None]
        L.paint(inside, sclera)
        # lid shadow under the lid line
        L.paint(soft(-lid - 7, 12) * inside, (120, 40, 52), 0.55)
        # pupil: tiny, dark red ring, two faint trembling echoes
        px_, py_ = cx + inward * 3.0, cy + 3.0
        pupil = sd_ellipse(px_, py_, 6.0, 6.4)
        veins(L, rng, cx, cy, inside, pupil)
        for dx, dy, a in ((-5.5, 1.2, 0.36), (5.0, -1.0, 0.30)):
            L.paint(cov(sd_ellipse(px_ + dx, py_ + dy, 10.0, 10.4)), (110, 10, 24), a, mask=inside)
        L.paint(cov(sd_ellipse(px_, py_, 11.0, 11.4)), (142, 12, 28), mask=inside)
        L.paint(cov(pupil), (10, 4, 8), mask=inside)
        # outline + lower-lid crease
        L.paint(cov(np.abs(eye) - 3.4), EYE_INK)
        crease = [(cx + (RX + 3) * math.cos(math.radians(a)), cy + (RY + 7) * math.sin(math.radians(a))) for a in range(35, 150, 8)]
        L.paint(cov(sd_taper(crease, 0.9, 1.6)), EYE_INK, 0.75)
        tremor_ticks(L, cx, cy, inward)
        # very low V brow, sitting on the lid line, thicker at the inner end
        bo = (outer[0] - inward * 10, outer[1] - 8)
        bi = (inner[0] + inward * 4, inner[1] - 2)
        mid = ((bo[0] + bi[0]) / 2, (bo[1] + bi[1]) / 2 - 2)
        L.paint(cov(sd_taper([bo, mid, bi], 5.5, 10.0)), BROW_INK)

    furrow(L, cy0)
    anger_mark(L, EYE_CX[1] + RX + 34, cy0 - 50)
    return L.image()


# ------------------------------------------------------------------ preview
def grin_layer() -> Image.Image:
    """Tantrum buildGrin / T.addGrin seen from the front on a cat head (HeadWidth 3.2, s = 1): W 1.6, H 0.7, 0.62 under
    the head centre (world z 4.975) -> centre z 4.355 -> v 0.502."""
    L = Layer()
    cx, cy = 256.0, (0.30 + 0.40 * (4.86 - 4.355)) * S
    w, h = 1.6 * PX, 0.7 * PX
    L.paint(cov(sd_ellipse(cx, cy, w / 2, h / 2)), (42, 5, 8))
    iw, ih = w * 0.9, h * 0.82
    L.paint(cov(sd_ellipse(cx, cy, iw / 2, ih / 2)), (196, 20, 46))
    L.paint(cov(sd_ellipse(cx, cy + ih * 0.05, iw * 0.225, ih * 0.2)), (90, 6, 18))
    L.paint(cov(sd_ellipse(cx, cy + ih * 0.26, iw * 0.175, ih * 0.14)), (255, 79, 163))
    a, b = iw / 2, ih / 2
    for n, x0, span, ln, up in ((8, 0.86, 1.72, 0.32, True), (7, 0.78, 1.56, 0.28, False)):
        for i in range(n):
            x = -a * x0 + i * (a * span / (n - 1))
            edge = b * math.sqrt(max(0.0, 1 - (x / a) ** 2))
            tl = ln * PX * (0.6 + 0.4 * edge / b)
            tw = a * span / (n - 1) * 0.85
            if up:
                p = [(cx + x - tw / 2, cy - edge - 0.02 * PX), (cx + x + tw / 2, cy - edge - 0.02 * PX), (cx + x, cy - edge + tl)]
            else:
                p = [(cx + x - tw / 2, cy + edge + 0.02 * PX), (cx + x + tw / 2, cy + edge + 0.02 * PX), (cx + x, cy + edge - tl)]
            # triangle sdf via three half planes
            d = np.full(X.shape, -1e9, np.float32)
            for j in range(3):
                (x1, y1), (x2, y2) = p[j], p[(j + 1) % 3]
                nx, ny = y2 - y1, -(x2 - x1)
                ox, oy = p[(j + 2) % 3]
                if (ox - x1) * nx + (oy - y1) * ny > 0:
                    nx, ny = -nx, -ny
                d = np.maximum(d, ((X - x1) * nx + (Y - y1) * ny) / math.hypot(nx, ny))
            L.paint(cov(d), (255, 255, 255))
    return L.image()


def preview(face: Image.Image, path: Path) -> None:
    fur = (226, 170, 112)                                    # a warm fur so the dark reds read
    grin = grin_layer()
    tiles = []
    for name, img in (("Angry", Image.open(FACE / "T_Expr_Angry.png").convert("RGBA")), ("Rage", face)):
        for with_grin in (False, True):
            t = Image.new("RGBA", (S, S), (24, 22, 30, 255))
            head = Layer()
            head.paint(cov(sd_ellipse(256, 200, 250, 210)), fur)
            t.alpha_composite(head.image())
            t.alpha_composite(img)
            if with_grin:
                t.alpha_composite(grin)
            tiles.append(t)
    board = Image.new("RGBA", (S * 4 + 30, S + 10), (24, 22, 30, 255))
    for i, t in enumerate(tiles):
        board.alpha_composite(t, (5 + i * (S + 7), 5))
    board.convert("RGB").save(path)
    print("preview", path)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview")
    ap.add_argument("--rgba")
    args = ap.parse_args()
    face = rage()
    face.save(OUT)
    print("wrote", OUT.relative_to(ROOT))
    if args.preview:
        preview(face, Path(args.preview))
    if args.rgba:
        Path(args.rgba).write_bytes(face.tobytes())
        print("rgba", args.rgba)
