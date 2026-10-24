"""AST-053 CrewTex step 2: paint the outfit / face sheets procedurally (numpy + PIL, system Python).

Every texel is rasterised from layout.json back to its world-space rest position (studs, Blender axes:
+X = character's right, +Y = front, +Z = up) and normal, so all painting below is written in 3D body space.

Alpha convention (fur):  alpha 0 = animal fur -> Roblox shows MeshPart.Color there
(SurfaceAppearance AlphaMode=Overlay, or plain MeshPart.TextureID). RGB under alpha 0 = neutral fur grey.
Semi-transparent dark pixels over fur = shading / night grime that darkens any fur colour.
"""
import os as _os
WORK = _os.environ.get("CHAR_WORK", _os.getcwd()).replace("\\", "/")
PROJECT = _os.environ.get("CHAR_PROJECT", "").replace("\\", "/").rstrip("/") + "/"
import json, math, os, sys
import numpy as np
from PIL import Image

SP = WORK
ROOT = PROJECT
OUT = ROOT + "Assets/textures/character/"
os.makedirs(OUT, exist_ok=True)
L = json.load(open(WORK + "/crewtex/layout.json"))
S = L["size"]
ISL = L["islands"]
FUR_NEUTRAL = np.array([206, 196, 182]) / 255


# ------------------------------------------------------------------ raster
def raster(sheet):
    P = np.zeros((S, S, 3), np.float32); N = np.zeros((S, S, 3), np.float32); I = -np.ones((S, S), np.int32)
    ys, xs = np.mgrid[0:S, 0:S]
    cx, cy = xs + 0.5, ys + 0.5
    for t in L["tris"][sheet]:
        (x0, y0), (x1, y1), (x2, y2) = t["uv"]
        bx0, bx1 = max(0, int(min(x0, x1, x2)) - 1), min(S, int(max(x0, x1, x2)) + 2)
        by0, by1 = max(0, int(min(y0, y1, y2)) - 1), min(S, int(max(y0, y1, y2)) + 2)
        px, py = cx[by0:by1, bx0:bx1], cy[by0:by1, bx0:bx1]
        den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
        if abs(den) < 1e-12:
            continue
        a = ((y1 - y2) * (px - x2) + (x2 - x1) * (py - y2)) / den
        b = ((y2 - y0) * (px - x2) + (x0 - x2) * (py - y2)) / den
        c = 1 - a - b
        m = (a >= -1e-4) & (b >= -1e-4) & (c >= -1e-4)
        if not m.any():
            continue
        p = np.array(t["p"], np.float32)
        pos = a[..., None] * p[0] + b[..., None] * p[1] + c[..., None] * p[2]
        sub = P[by0:by1, bx0:bx1]; sub[m] = pos[m]
        N[by0:by1, bx0:bx1][m] = np.array(t["n"], np.float32)
        I[by0:by1, bx0:bx1][m] = t["i"]
    # dilate 8 px (island padding is 4 px each side): extrapolate position linearly-ish by copying
    for _ in range(8):
        empty = I < 0
        if not empty.any():
            break
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            sI = np.roll(I, (dy, dx), (0, 1)); sP = np.roll(P, (dy, dx), (0, 1)); sN = np.roll(N, (dy, dx), (0, 1))
            take = empty & (sI >= 0) & (I < 0)
            I[take] = sI[take]; P[take] = sP[take]; N[take] = sN[take]
    return P, N, I


class Ctx:
    def __init__(self, sheet):
        self.P, self.N, self.I = raster(sheet)
        self.x, self.y, self.z = self.P[..., 0], self.P[..., 1], self.P[..., 2]
        self.nx, self.ny, self.nz = self.N[..., 0], self.N[..., 1], self.N[..., 2]
        names = np.array([m["obj"] for m in ISL] + ["none"])
        inames = np.array([m["name"] for m in ISL] + ["none"])
        pps = np.array([m["px_per_stud"] for m in ISL] + [50.0], np.float32)
        idx = np.where(self.I < 0, len(ISL), self.I)
        self.obj = names[idx]; self.isl = inames[idx]
        self.aa = 1.0 / pps[idx]           # one pixel in studs
        self.valid = self.I >= 0
        self.rgb = np.zeros((S, S, 3), np.float32); self.rgb[:] = FUR_NEUTRAL
        self.a = np.ones((S, S), np.float32)
        self.shade = np.ones((S, S), np.float32)

    def part(self, *objs):
        return np.isin(self.obj, objs)

    def put(self, mask, col, k=1.0):
        """blend colour into rgb where mask (0..1 float or bool)"""
        m = (mask.astype(np.float32) * k)[..., None]
        self.rgb = self.rgb * (1 - m) + np.array(col, np.float32)[None, None, :] / 255 * m


# ------------------------------------------------------------------ helpers
def sm(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def fill(d, aa):
    """signed distance (neg inside) -> coverage"""
    return np.clip(0.5 - d / (aa * 1.2), 0, 1)


def line(d, w, aa):
    return fill(np.abs(d) - w, aa)


def sd_ellipse(px, py, rx, ry):
    k = np.sqrt((px / rx) ** 2 + (py / ry) ** 2)
    return (k - 1) * min(rx, ry)


def sd_capsule(px, py, a, b, r):
    ax, ay = a; bx, by = b
    vx, vy = bx - ax, by - ay
    h = np.clip(((px - ax) * vx + (py - ay) * vy) / (vx * vx + vy * vy), 0, 1)
    return np.hypot(px - ax - vx * h, py - ay - vy * h) - r


def sd_box(px, py, hx, hy, r=0.0):
    qx, qy = np.abs(px) - hx + r, np.abs(py) - hy + r
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r


def sd_polyline(px, py, pts):
    d = np.full(px.shape, 1e9, np.float32)
    for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
        d = np.minimum(d, sd_capsule(px, py, (ax, ay), (bx, by), 0))
    return d


def sd_polygon(px, py, pts):
    d = sd_polyline(px, py, pts + [pts[0]])
    inside = np.zeros(px.shape, bool)
    n = len(pts)
    for i in range(n):
        (ax, ay), (bx, by) = pts[i], pts[(i + 1) % n]
        c = ((ay > py) != (by > py)) & (px < (bx - ax) * (py - ay) / (by - ay + 1e-12) + ax)
        inside ^= c
    return np.where(inside, -d, d)


def rot2(px, py, deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return c * px + s * py, -s * px + c * py


def hash3(ix, iy, iz, seed):
    h = np.sin(ix * 127.1 + iy * 311.7 + iz * 74.7 + seed * 17.13) * 43758.5453
    return h - np.floor(h)


def vnoise(x, y, z, f, seed=0):
    x, y, z = x * f, y * f, z * f
    ix, iy, iz = np.floor(x), np.floor(y), np.floor(z)
    fx, fy, fz = x - ix, y - iy, z - iz
    fx, fy, fz = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy), fz * fz * (3 - 2 * fz)
    out = 0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (fx if dx else 1 - fx) * (fy if dy else 1 - fy) * (fz if dz else 1 - fz)
                out = out + w * hash3(ix + dx, iy + dy, iz + dz, seed)
    return out


def fbm(c, f, seed=0, oct=3):
    v, amp, tot = 0, 1.0, 0
    for o in range(oct):
        v = v + amp * vnoise(c.x, c.y, c.z, f * 2 ** o, seed + o * 7)
        tot += amp; amp *= 0.5
    return v / tot


def dashes(s, period=0.09, duty=0.55):
    return ((s / period) % 1.0) < duty


def stitch(c, d, w=0.012, period=0.085, along=None):
    s = along if along is not None else (c.x * 1.0 + c.y * 0.83 + c.z * 0.61)
    return line(d, w, c.aa) * dashes(s, period)


ZR = {"Torso": (2.0, 4.0), "Right Arm": (2.0, 4.0), "Left Arm": (2.0, 4.0), "Right Leg": (0.0, 2.0),
      "Left Leg": (0.0, 2.0), "Cap": (5.02, 6.0), "Apron": (1.7, 4.05), "Head": (3.95, 5.7)}


def base_shade(c):
    t = np.zeros((S, S), np.float32)
    for o, (z0, z1) in ZR.items():
        m = c.obj == o
        t[m] = np.clip((c.z[m] - z0) / (z1 - z0), 0, 1)
    c.shade = (0.84 + 0.20 * t + 0.05 * c.nz) * c.shade


def fold(c, d, w, k=0.16):
    """soft cloth crease: darken along a distance field"""
    c.shade = c.shade * (1 - k * np.exp(-(d / w) ** 2))


def armx(c):
    """local x of arm/leg (outer side positive)"""
    cx = np.where(np.isin(c.obj, ["Right Arm"]), 1.5, np.where(np.isin(c.obj, ["Left Arm"]), -1.5,
                  np.where(np.isin(c.obj, ["Right Leg"]), 0.5, np.where(np.isin(c.obj, ["Left Leg"]), -0.5, 0))))
    sgn = np.where(np.isin(c.obj, ["Left Arm", "Left Leg"]), -1.0, 1.0)
    return (c.x - cx) * sgn, sgn


# ------------------------------------------------------------------ hot dog logo (viewer coords: X right, Z up)
def hotdog_logo(c, X, Z, mask, s=1.0, faded=0.0, outline=(250, 236, 214)):
    X, Z = X / s, Z / s
    aa = c.aa / s
    Xr, Zr = rot2(X, Z, 12)                               # rises to the viewer's right
    bun = sd_capsule(Xr, Zr, (-0.36, -0.02), (0.36, -0.02), 0.15)
    saus = sd_capsule(Xr, Zr, (-0.47, 0.06), (0.47, 0.06), 0.085)
    front_bun = np.maximum(sd_capsule(Xr, Zr, (-0.38, -0.07), (0.38, -0.07), 0.12), Zr - 0.0)
    union = np.minimum(bun, saus)
    keep = 1 - faded
    c.put(mask * fill(union - 0.05, aa), outline, keep)              # sticker outline
    c.put(mask * fill(union - 0.018, aa), (120, 40, 20), keep)       # dark contour
    c.put(mask * fill(bun, aa), (236, 160, 72), keep)
    c.put(mask * fill(bun, aa) * sm(-0.02, 0.10, Zr) * 0.6, (252, 204, 120), keep)
    c.put(mask * fill(saus, aa), (186, 66, 38), keep)
    c.put(mask * line(Zr - 0.10, 0.012, aa) * fill(saus + 0.02, aa), (232, 128, 96), keep)        # highlight
    # front half of the bun over the sausage
    c.put(mask * fill(front_bun, aa), (226, 148, 62), keep)
    c.put(mask * line(front_bun, 0.012, aa) * fill(bun - 0.005, aa) * (Zr > -0.05), (150, 70, 30), keep)
    # mustard zig-zag along the sausage top
    zz = [(-0.40 + i * 0.1, 0.075 + (0.035 if i % 2 else -0.025)) for i in range(9)]
    c.put(mask * line(sd_polyline(Xr, Zr, zz), 0.022, aa), (255, 214, 48), keep)


# ------------------------------------------------------------------ outfit painters
def shoe(c, legs, body, sole, accent=None, laces=(230, 225, 215), toe=None):
    lx, _ = armx(c)
    m = legs & (c.z < 0.462)
    c.put(m, body)
    if toe is not None:
        c.put(m & (c.ny > 0.5) & (c.z < 0.30), toe)
        c.put(m * (c.ny > 0.5) * line(c.z - 0.30, 0.012, c.aa), tuple(int(v * 0.7) for v in toe))
    if accent is not None:   # side stripe
        d = sd_capsule(c.y, c.z, (-0.35, 0.16), (0.30, 0.34), 0.035)
        c.put(m * (np.abs(c.nx) > 0.5) * fill(d, c.aa), accent)
    c.put(m & (c.z < 0.09) | (legs & (c.nz < -0.5)), sole)
    c.put(m * line(c.z - 0.09, 0.008, c.aa), tuple(int(v * 0.75) for v in sole))
    # laces on the front
    fr = m & (c.ny > 0.5) & (c.z > 0.30) & (c.z < 0.44)
    for zl in (0.33, 0.38, 0.43):
        c.put(fr * line(c.z - zl, 0.012, c.aa) * (np.abs(lx) < 0.16), laces)
    # tread on the sole bottom
    bot = legs & (c.nz < -0.5)
    c.put(bot * (((c.y * 9) % 1.0) < 0.35), tuple(int(v * 0.8) for v in sole))
    fold(c, np.where(legs, c.z - 0.462, 9), 0.03, 0.22)          # shadow under the trouser hem


def pants_legs(c, legs, col, crease=True):
    lx, _ = armx(c)
    c.put(legs & (c.z >= 0.462), col)
    # knee folds (front), ankle bunching
    fr = legs & (c.ny > 0.5)
    for zc, w in ((1.02, 0.18), (1.10, 0.14)):
        fold(c, np.where(fr, (c.z - zc - 0.05 * lx), 9), 0.025, 0.18 * (np.abs(lx) < w))
    fold(c, np.where(legs, c.z - 0.62 - 0.04 * np.sin(c.x * 9 + c.y * 7), 9), 0.03, 0.12)
    if crease:
        c.shade = c.shade * (1 + 0.06 * (fr * line(lx, 0.01, c.aa)))
    # outer side seam
    side = legs & (np.abs(c.nx) > 0.5)
    c.shade = c.shade * (1 - 0.12 * (side * line(c.y, 0.012, c.aa)))
    return lx


def torso_common(c, shirt_col, collar_col):
    T = c.part("Torso")
    c.put(T, shirt_col)
    c.put(T & (c.z > 3.885), collar_col)
    c.put(T * stitch(c, c.z - 3.86, 0.008, along=c.x + c.y), tuple(int(v * 0.8) for v in shirt_col))
    side = T & (np.abs(c.nx) > 0.5)
    c.put(side * stitch(c, c.y, 0.009, along=c.z), tuple(int(v * 0.78) for v in shirt_col))
    # armpit folds front/back, waist wrinkles
    for sx in (-1, 1):
        d = (c.z - 3.45) - 0.55 * (np.abs(c.x) - 0.75) * 1.0
        fold(c, np.where(T & (np.abs(c.ny) > 0.5) & (c.x * sx > 0.55) & (c.z > 3.1), d, 9), 0.03, 0.14)
    for zc in (2.47, 2.58):
        fold(c, np.where(T & (c.z > 2.32), c.z - zc - 0.03 * np.sin(c.x * 6 + c.y * 4), 9), 0.022, 0.10)
    fold(c, np.where(T & (c.z > 2.32), c.z - 2.34, 9), 0.035, 0.22)      # tuck shadow
    return T


def apron_paint(c, red, red_dk, logo=True, faded=0.0):
    A = c.part("Apron")
    c.put(A, red)
    back = c.isl == "Apron_back"
    c.put(back, red_dk)
    c.put(c.isl == "Apron_edge", tuple(int(v * 0.85) for v in red))
    front = c.isl == "Apron_front"
    X, Z = -c.x, c.z                                          # viewer coords on the front
    out2d = [(-0.58, 3.78), (0.58, 3.78), (0.58, 3.05), (0.90, 2.86), (0.92, 2.20), (0.92, 1.80), (0.84, 1.70),
             (-0.84, 1.70), (-0.92, 1.80), (-0.92, 2.20), (-0.90, 2.86), (-0.58, 3.05)]
    d = sd_polygon(c.x, c.z, out2d)
    c.put(front * stitch(c, d + 0.065, 0.010, period=0.07, along=c.x * 1.0 + c.z * 0.7), (238, 214, 196))
    c.shade = c.shade * (1 - 0.18 * front * np.exp(-((d + 0.0) / 0.035) ** 2))        # soft edge
    # top hem band of the bib
    c.put(front * (c.z > 3.70), tuple(int(v * 0.92) for v in red))
    # pocket
    pk = sd_box(X, Z - 1.99, 0.56, 0.16, 0.03)
    c.put(front * fill(pk, c.aa), tuple(int(v * 0.93) for v in red))
    c.put(front * stitch(c, pk + 0.03, 0.009, period=0.06, along=X + Z * 0.7), (238, 214, 196))
    c.put(front * line(Z - 2.15, 0.014, c.aa) * fill(pk, c.aa), tuple(int(v * 0.75) for v in red))
    c.put(front * line(X, 0.009, c.aa) * fill(pk + 0.02, c.aa), tuple(int(v * 0.75) for v in red))
    # waist bend fold
    fold(c, np.where(front, c.z - 2.2, 9), 0.04, 0.10)
    if logo:
        hotdog_logo(c, X, Z - 2.74, front, s=1.0, faded=faded)
    # straps: a bit darker, lighter top edge
    st = np.char.startswith(c.isl, "Apron_strap")
    c.put(st, tuple(int(v * 0.95) for v in red))
    return A


def cap_paint(c, col, col_dk, under, badge=None, badge_col=(250, 236, 214)):
    C = c.part("Cap")
    c.put(C, col)
    crown = np.char.startswith(c.isl, "CapCrown")
    theta = np.degrees(np.arctan2(c.x, c.y))                 # 0 = front
    dth = np.abs(((theta - 30) % 60) - 30)                    # distance to a panel seam (deg)
    r = np.hypot(c.x, c.y) + 1e-3
    seam_d = np.radians(dth) * r
    sm_ = crown & (c.z > 5.08)
    c.put(sm_ * line(seam_d, 0.014, c.aa), col_dk)
    c.put(sm_ * line(seam_d - 0.045, 0.008, c.aa) * dashes(c.z, 0.06), col_dk)
    c.put(c.isl == "CapCrown_bottom", under)
    c.put(np.char.startswith(c.isl, "CapButton"), col_dk)
    c.put(crown * line(c.z - 5.1, 0.014, c.aa), col_dk)               # sweat band seam
    # brim (local coords)
    brim = np.char.startswith(c.isl, "CapBrim")
    py, pz = c.y - 0.42, c.z - 5.14
    a = math.radians(10)
    qy = math.cos(a) * py - math.sin(a) * pz
    yl = qy + 0.55 - 0.55                                    # 0 at the crown edge
    e = np.where(yl > 0.65, np.sqrt((c.x / 0.86) ** 2 + ((yl - 0.65) / 0.62) ** 2), np.abs(c.x) / 0.86)
    top = c.isl == "CapBrim_top"
    for k in (0.90, 0.80, 0.70):
        c.put(top * stitch(c, (e - k) * 0.7, 0.008, period=0.06, along=c.x + yl), col_dk)
    c.put(c.isl == "CapBrim_bottom", under)
    c.put(c.isl == "CapBrim_edge", col_dk)
    if badge is not None:
        fr = crown & (c.ny > 0.35)
        X, Z = -c.x, c.z - 5.40
        b = sd_ellipse(X, Z, 0.22, 0.17)
        c.put(fr * fill(b, c.aa), badge_col)
        c.put(fr * line(b + 0.02, 0.008, c.aa), col_dk)
        badge(c, X, Z, fr * fill(b + 0.02, c.aa))
    return C


def mini_hotdog(c, X, Z, m):
    Xr, Zr = rot2(X, Z, 12)
    bun = sd_capsule(Xr, Zr, (-0.09, -0.02), (0.09, -0.02), 0.05)
    sa = sd_capsule(Xr, Zr, (-0.13, 0.02), (0.13, 0.02), 0.028)
    c.put(m * fill(bun, c.aa), (236, 160, 72))
    c.put(m * fill(sa, c.aa), (186, 66, 38))
    c.put(m * fill(np.maximum(sd_capsule(Xr, Zr, (-0.10, -0.03), (0.10, -0.03), 0.04), Zr + 0.005), c.aa), (226, 148, 62))
    zz = [(-0.11 + i * 0.0275, 0.03 + (0.012 if i % 2 else -0.008)) for i in range(9)]
    c.put(m * line(sd_polyline(Xr, Zr, zz), 0.008, c.aa), (255, 214, 48))


def fur(c, mask, night, shadow=None):
    """mask: fur region. Day: alpha 0 (pure MeshPart.Color); soft dark contact shadow overlay allowed."""
    c.rgb[mask] = FUR_NEUTRAL
    c.a[mask] = 0.0
    if shadow is not None:
        s = np.clip(shadow, 0, 1) * mask
        c.rgb = np.where((s > 0.003)[..., None], np.array([60, 44, 40], np.float32) / 255, c.rgb)
        c.a = np.where(mask, s * 0.30, c.a)


def finish(c, fur_mask, night, seed=0, grime_k=1.0):
    """apply shading to the cloth; night: darker/desaturated/bluish + grime blotches + fur overlay."""
    rgb = c.rgb * np.clip(c.shade, 0.4, 1.3)[..., None]
    cloth = ~fur_mask
    if night:
        g = rgb.mean(-1, keepdims=True)
        rgb = (rgb * 0.68 + g * 0.32) * 0.74 * np.array([0.86, 0.90, 1.08], np.float32)
        n = fbm(c, 2.2, seed)
        n2 = fbm(c, 7.0, seed + 31)
        grime = sm(0.55, 0.75, n) * 0.45 * grime_k + sm(0.62, 0.70, n2) * 0.22 * grime_k
        rgb = rgb * (1 - grime[..., None]) + np.array([62, 54, 46], np.float32)[None, None] / 255 * grime[..., None]
        # fur at night: darker, mottled, scruffy streaks (overlay alpha)
        streak = sm(0.6, 0.9, vnoise(c.x * 6, c.y * 6, c.z * 0.6, 4.0, seed + 5))
        fa = 0.26 + 0.18 * sm(0.4, 0.8, n) + 0.12 * streak
        a_old = c.a.copy()
        fur_rgb = np.array([30, 32, 54], np.float32) / 255
        newa = 1 - (1 - a_old) * (1 - fa)                      # stack over day shadow
        mixc = (c.rgb * a_old[..., None] * (1 - fa[..., None]) + fur_rgb * fa[..., None]) / np.maximum(newa, 1e-4)[..., None]
        c.a = np.where(fur_mask, newa, c.a)
        rgb = np.where(fur_mask[..., None], mixc, rgb)
    else:
        rgb = np.where(fur_mask[..., None], c.rgb, rgb)
    c.rgb = np.clip(rgb, 0, 1)


def save(c, name):
    img = np.dstack([c.rgb, c.a[..., None]])
    img = (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(img).save(OUT + name)
    print("saved", name)


LIMBS = ("Right Arm", "Left Arm")
LEGS = ("Right Leg", "Left Leg")


def crew(night):
    c = Ctx("outfit")
    T = torso_common(c, (245, 234, 216), (232, 220, 200))
    # waistband (trouser top) on the torso
    c.put(T & (c.z < 2.32), (42, 42, 50))
    c.put(T * line(c.z - 2.27, 0.01, c.aa), (30, 30, 36))
    # collar flaps (front)
    fr = T & (c.ny > 0.5)
    for sx in (-1, 1):
        flap = sd_polygon(c.x * sx, c.z, [(0.06, 3.99), (0.46, 3.99), (0.24, 3.66)])
        c.put(fr * fill(flap, c.aa), (250, 242, 228))
        c.put(fr * line(flap, 0.009, c.aa), (200, 186, 166))
    # back: crossed apron straps + waist ties with a bow
    bk = T & (c.ny < -0.5)
    red, red_dk = (198, 32, 44), (150, 22, 32)
    for sx in (-1, 1):
        d = sd_capsule(c.x, c.z, (sx * 0.52, 4.05), (-sx * 0.42, 2.50), 0.075)
        c.put(bk * fill(d, c.aa), red)
        c.put(bk * line(d, 0.008, c.aa), red_dk)
    tie = T & ~(fr & (np.abs(c.x) < 0.86)) & (np.abs(c.z - 2.46) < 0.065)
    c.put(tie, red)
    c.put(T * line(np.abs(c.z - 2.46) - 0.065, 0.007, c.aa) * ~(fr & (np.abs(c.x) < 0.86)), red_dk)
    for sx in (-1, 1):
        Xr, Zr = rot2(c.x - sx * 0.15, c.z - 2.50, sx * 12)
        lp = sd_ellipse(Xr, Zr, 0.15, 0.085)
        c.put(bk * fill(lp, c.aa), red); c.put(bk * line(lp, 0.008, c.aa), red_dk)
        c.put(bk * line(sd_ellipse(Xr - sx * 0.02, Zr, 0.07, 0.03), 0.007, c.aa), red_dk)
        tl = sd_capsule(c.x, c.z, (sx * 0.03, 2.44), (sx * 0.16, 2.16), 0.04)
        c.put(bk * fill(tl, c.aa), red); c.put(bk * line(tl, 0.007, c.aa), red_dk)
    kn = sd_ellipse(c.x, c.z - 2.48, 0.06, 0.07)
    c.put(bk * fill(kn, c.aa), (176, 26, 38)); c.put(bk * line(kn, 0.008, c.aa), red_dk)
    # arms: short cream sleeves, fur forearm
    arms = c.part(*LIMBS)
    lx, _ = armx(c)
    c.put(arms, (245, 234, 216))
    c.put(arms & (c.z < 3.30) & (c.z >= 3.155), (232, 220, 200))
    c.put(arms * stitch(c, c.z - 3.27, 0.008, along=c.x + c.y), (200, 186, 166))
    fold(c, np.where(arms & (lx < -0.3) & (c.z > 3.3), (c.z - 3.62) + 0.4 * (c.y), 9), 0.03, 0.16)
    fold(c, np.where(arms & (c.z > 3.3), (c.z - 3.45) - 0.3 * np.sin(c.y * 4), 9), 0.025, 0.08)
    fur_m = arms & (c.z < 3.155)
    # legs
    legs = c.part(*LEGS)
    pants_legs(c, legs, (42, 42, 50))
    shoe(c, legs, (44, 34, 32), (150, 142, 132), toe=(58, 46, 42))
    # side pocket slit
    c.put(legs * (np.abs(c.nx) > 0.5) * line(c.y - 0.25 * (c.z - 1.7), 0.01, c.aa) * (c.z > 1.6) * (c.z < 1.95) * (lx > 0), (24, 24, 30))
    apron_paint(c, (196, 30, 42), (140, 22, 32), faded=0.35 if night else 0.0)
    cap_paint(c, (200, 32, 44), (150, 22, 32), (112, 18, 26), badge=mini_hotdog)
    base_shade(c)
    if night:   # stains (brown sauce / grease, never red), worn hems, knee patch, torn apron hem
        S_ = fbm(c, 5.0, 77)
        st = c.part("Apron") & (c.isl == "Apron_front")
        for (sx, sz, r) in ((0.35, 2.05, 0.13), (-0.42, 2.95, 0.09), (0.05, 3.45, 0.07)):
            dd = sd_ellipse(-c.x - sx, c.z - sz, r * 1.2, r) + 0.03 * (S_ - 0.5)
            c.put(st * fill(dd, c.aa), (110, 66, 30), 0.55)
            c.put(st * line(dd, 0.012, c.aa), (80, 46, 24), 0.5)
        tear = st & (c.z < 1.70 + 0.05 + 0.04 * np.abs(((c.x * 9) % 2) - 1))
        c.put(tear, (100, 18, 26))
        sh = T & (c.ny > 0.5) & (np.abs(c.x) > 0.6)
        c.put(sh * fill(sd_ellipse(c.x - 0.8, c.z - 3.3, 0.09, 0.12), c.aa), (150, 126, 90), 0.5)
        pk = legs & (c.ny > 0.5)
        lx2, _ = armx(c)
        patch = sd_box(lx2 + 0.05, c.z - 1.05, 0.17, 0.15)
        m = pk & (c.obj == "Left Leg")
        c.put(m * fill(patch, c.aa), (70, 64, 80)); c.put(m * stitch(c, patch + 0.025, 0.009, 0.05, along=c.x + c.z), (170, 160, 150))
        c.put(arms * (c.z < 3.30) * (c.z >= 3.155) * sm(0.5, 0.8, fbm(c, 14, 3)), (200, 190, 170), 0.6)   # frayed hem
    fur(c, fur_m, night, shadow=np.exp(-((3.155 - c.z) / 0.08) ** 2) * fur_m)
    finish(c, fur_m, night, seed=11)
    return c


def civil_a(night):
    c = Ctx("outfit")
    tee, tee_l = (64, 168, 186), (120, 200, 212)
    T = torso_common(c, tee, tee_l)
    # chest stripes wrap around
    c.put(T & (np.abs(c.z - 3.32) < 0.075) & (c.z > 2.32), (246, 244, 236))
    c.put(T & (np.abs(c.z - 3.10) < 0.04), (255, 206, 72))
    # waist: jeans + belt + buckle
    jeans = (58, 92, 158)
    c.put(T & (c.z < 2.32), jeans)
    c.put(T & (c.z > 2.16) & (c.z < 2.29), (112, 72, 42))
    fr = T & (c.ny > 0.5)
    bk = sd_box(-c.x, c.z - 2.225, 0.09, 0.07, 0.015)
    c.put(fr * fill(bk, c.aa), (222, 192, 96)); c.put(fr * fill(bk + 0.03, c.aa), (112, 72, 42))
    for lx_ in (-0.62, 0.62):
        c.put(T * fill(sd_box(c.x - lx_, c.z - 2.225, 0.03, 0.085), c.aa) * (np.abs(c.ny) > 0.5), (48, 78, 140))
    arms = c.part(*LIMBS)
    lx, _ = armx(c)
    c.put(arms, tee)
    c.put(arms & (c.z < 3.30) & (c.z >= 3.155), tee_l)
    c.put(arms & (np.abs(c.z - 3.23) < 0.025), (246, 244, 236))
    fold(c, np.where(arms & (c.z > 3.3), (c.z - 3.55) - 0.3 * np.sin(c.y * 4), 9), 0.025, 0.1)
    fur_m = arms & (c.z < 3.155)
    legs = c.part(*LEGS)
    pants_legs(c, legs, jeans, crease=False)
    # fades + orange stitching + pockets + rolled cuffs
    fr_l = legs & (c.ny > 0.5)
    fade = np.exp(-(((c.z - 1.45) / 0.35) ** 2 + (lx / 0.3) ** 2)) + 0.8 * np.exp(-(((c.z - 1.0) / 0.12) ** 2 + (lx / 0.25) ** 2))
    c.put(fr_l, (100, 138, 196), np.clip(fade, 0, 1) * 0.6)
    side = legs & (np.abs(c.nx) > 0.5) & (lx > 0)
    c.put(side * stitch(c, c.y, 0.009, along=c.z), (214, 150, 66))
    pk = fr_l * line(np.hypot(lx - 0.5, c.z - 2.0) - 0.32, 0.01, c.aa) * (c.z > 1.6)
    c.put(pk, (214, 150, 66))
    bkp = legs & (c.ny < -0.5)
    pp = sd_polygon(lx, c.z, [(-0.28, 1.86), (0.28, 1.86), (0.26, 1.52), (0.0, 1.44), (-0.26, 1.52)])
    c.put(bkp * line(pp, 0.01, c.aa), (214, 150, 66))
    cuff = legs & (c.z >= 0.462) & (c.z < 0.62)
    c.put(cuff, (110, 150, 206))
    c.put(legs * line(c.z - 0.62, 0.012, c.aa), (40, 66, 120))
    shoe(c, legs, (238, 236, 230), (186, 186, 192), accent=(214, 54, 60), laces=(170, 170, 176), toe=(250, 250, 248))
    apron_paint(c, (190, 190, 196), (150, 150, 158), logo=False)
    cap_paint(c, (42, 58, 116), (28, 40, 84), (30, 34, 60), badge=lambda c, X, Z, m: c.put(m * fill(sd_ellipse(X, Z, 0.08, 0.08), c.aa), (255, 206, 72)), badge_col=(246, 244, 236))
    base_shade(c)
    if night:
        kn = legs & (c.ny > 0.5) & (c.obj == "Right Leg")
        rip = sd_ellipse(lx + 0.02, c.z - 1.05, 0.17, 0.06)
        c.put(kn * fill(rip, c.aa), (36, 30, 34))
        for k in range(4):
            c.put(kn * fill(rip, c.aa) * line(c.z - 1.02 - 0.025 * k + 0.035, 0.006, c.aa), (220, 220, 225))
        c.put(T * (c.ny > 0.5) * fill(sd_ellipse(c.x + 0.55, c.z - 2.75, 0.14, 0.1) + 0.02 * fbm(c, 9, 4), c.aa), (90, 80, 52), 0.45)
        c.put(T * (c.ny < -0.5) * fill(sd_box(c.x - 0.3, c.z - 2.9, 0.16, 0.12), c.aa), (52, 120, 132), 1.0)
        c.put(T * (c.ny < -0.5) * stitch(c, sd_box(c.x - 0.3, c.z - 2.9, 0.16, 0.12) + 0.02, 0.008, 0.05, c.x + c.z), (220, 210, 190))
    fur(c, fur_m, night, shadow=np.exp(-((3.155 - c.z) / 0.08) ** 2) * fur_m)
    finish(c, fur_m, night, seed=23)
    return c


def civil_b(night):
    c = Ctx("outfit")
    hood, hood_dk = (126, 88, 168), (98, 66, 136)
    T = torso_common(c, hood, hood_dk)
    fr = T & (c.ny > 0.5); bk = T & (c.ny < -0.5)
    # kangaroo pocket
    pk = sd_polygon(-c.x, c.z, [(-0.60, 2.92), (0.60, 2.92), (0.74, 2.46), (-0.74, 2.46)])
    c.put(fr * fill(pk, c.aa), (114, 78, 156))
    c.put(fr * line(pk, 0.012, c.aa), hood_dk)
    c.put(fr * stitch(c, pk + 0.035, 0.008, 0.06, c.x + c.z), (160, 128, 200))
    for sx in (-1, 1):
        c.put(fr * line(sd_capsule(c.x, c.z, (sx * 0.62, 2.88), (sx * 0.72, 2.52), 0.0) , 0.014, c.aa), (70, 46, 100))
    # drawstrings
    for sx in (-1, 1):
        d = sd_capsule(c.x, c.z, (sx * 0.16, 3.99), (sx * 0.20, 3.50), 0.02)
        c.put(fr * fill(d, c.aa), (246, 244, 240))
        c.put(fr * fill(sd_capsule(c.x, c.z, (sx * 0.20, 3.50), (sx * 0.205, 3.42), 0.026), c.aa), (170, 170, 176))
    # hood on the back
    hd = sd_ellipse(c.x, c.z - 3.95, 0.68, 0.62)
    c.put(bk * fill(hd, c.aa), (112, 76, 152))
    c.put(bk * line(hd, 0.014, c.aa), (70, 46, 100))
    c.put(bk * fill(sd_ellipse(c.x, c.z - 4.0, 0.36, 0.26), c.aa), (74, 50, 104))
    fold(c, np.where(bk, hd - 0.02, 9), 0.03, 0.2)
    # ribbed hem + shorts on the torso band
    shorts = (64, 120, 100)
    rib = T & (c.z >= 2.32) & (c.z < 2.48)
    c.put(rib, hood_dk)
    c.put(rib * line(((c.x + c.y) * 14 % 1.0) - 0.5, 0.12, 1 / 14.0), (84, 56, 118), 0.6)
    c.put(T & (c.z < 2.32), shorts)
    c.put(T * line(c.z - 2.28, 0.01, c.aa), (40, 84, 70))
    # sleeves: full length with ribbed cuff, fur hand below 2.10
    arms = c.part(*LIMBS)
    lx, _ = armx(c)
    c.put(arms, hood)
    cuff = arms & (c.z >= 2.10) & (c.z < 2.30)
    c.put(cuff, hood_dk)
    c.put(cuff * line(((c.x + c.y) * 14 % 1.0) - 0.5, 0.12, 1 / 14.0), (84, 56, 118), 0.6)
    for zc in (2.55, 2.75, 2.95):
        fold(c, np.where(arms & (c.z > 2.3), (c.z - zc) - 0.12 * np.sin(c.y * 6 + c.x * 3), 9), 0.025, 0.14)
    fur_m = arms & (c.z < 2.10)
    # legs: shorts to 1.22, fur shin, socks, sneakers
    legs = c.part(*LEGS)
    c.put(legs, shorts)
    c.put(legs & (c.z < 1.34) & (c.z >= 1.22), (84, 146, 122))
    c.put(legs * line(c.z - 1.34, 0.01, c.aa), (40, 84, 70))
    side = legs & (np.abs(c.nx) > 0.5) & (lx > 0)
    c.put(side * (np.abs(c.y) < 0.07) * (c.z > 1.22), (240, 240, 236))
    fold(c, np.where(legs & (c.z > 1.22), (c.z - 1.62) - 0.1 * np.sin(c.y * 5 + lx * 4), 9), 0.03, 0.14)
    sock = legs & (c.z >= 0.462) & (c.z < 0.64)
    c.put(sock, (244, 242, 236))
    c.put(sock & (np.abs(c.z - 0.585) < 0.018), (240, 140, 48))
    c.put(sock & (np.abs(c.z - 0.535) < 0.018), (240, 140, 48))
    shoe(c, legs, (62, 112, 204), (240, 240, 236), laces=(246, 246, 246), toe=(240, 240, 236))
    fur_m = fur_m | (legs & (c.z >= 0.64) & (c.z < 1.22))
    apron_paint(c, (190, 190, 196), (150, 150, 158), logo=False)
    cap_paint(c, (236, 146, 46), (184, 104, 30), (120, 70, 26), badge=None)
    base_shade(c)
    if night:
        el = arms & (lx < -0.2)
        p = sd_box(c.y, c.z - 2.75, 0.2, 0.16, 0.05)
        c.put(el * fill(p, c.aa), (78, 92, 70))
        c.put(el * stitch(c, p + 0.03, 0.009, 0.05, c.y + c.z), (190, 180, 160))
        hole = sd_ellipse(c.x - 0.45, c.z - 3.2, 0.07, 0.05) + 0.02 * fbm(c, 20, 2)
        c.put(fr * fill(hole, c.aa), (34, 26, 40))
        c.put(T * (c.ny > 0.5) * fill(sd_ellipse(c.x + 0.2, c.z - 2.7, 0.18, 0.1) + 0.03 * fbm(c, 8, 9), c.aa), (96, 80, 50), 0.45)
    shadow = np.exp(-((2.10 - c.z) / 0.08) ** 2) * fur_m + np.exp(-((1.22 - c.z) / 0.08) ** 2) * fur_m \
        + np.exp(-((c.z - 0.64) / 0.06) ** 2) * fur_m * 0.6
    fur(c, fur_m, night, shadow=shadow)
    finish(c, fur_m, night, seed=37)
    return c


# ------------------------------------------------------------------ face
def face(night):
    c = Ctx("face")
    H = c.part("Head")
    fr = c.isl == "Head_front"
    X, Z = -c.x, c.z + 0.07                             # viewer coords (features sit 0.07 lower than the numbers below)
    fur_m = H.copy()
    c.rgb[:] = FUR_NEUTRAL
    c.a[:] = 0.0
    def paint(cov, col, k=1.0):
        """standard 'over' compositing of a feature onto the (possibly transparent) fur layer"""
        cov = (np.clip(cov * k, 0, 1) * fr).astype(np.float32)
        col = np.array(col, np.float32) / 255
        na = cov + c.a * (1 - cov)
        c.rgb = (col * cov[..., None] + c.rgb * (c.a * (1 - cov))[..., None]) / np.maximum(na, 1e-5)[..., None]
        c.a = na
    if night:   # fur grime first (under the features)
        nz = fbm(c, 2.5, 51)
        streak = sm(0.6, 0.9, vnoise(c.x * 6, c.y * 6, c.z * 0.6, 4.0, 9))
        fa = ((0.24 + 0.18 * sm(0.4, 0.8, nz) + 0.10 * streak) * H).astype(np.float32)
        c.rgb[H] = np.array([30, 32, 54], np.float32) / 255
        c.a = fa
    EZ = 4.80
    for sx in (-1, 1):
        ex = sx * 0.40
        e = sd_ellipse(X - ex, Z - EZ, 0.18, 0.225)
        if not night:
            paint(fill(e, c.aa), (30, 22, 30))
            paint(fill(e, c.aa) * sm(0.0, -0.2, Z - EZ) * 0.85, (78, 52, 62))      # warm lower glow
            paint(fill(sd_ellipse(X - ex + 0.055, Z - EZ - 0.085, 0.062, 0.07), c.aa), (255, 255, 255))
            paint(fill(sd_ellipse(X - ex - 0.065, Z - EZ + 0.095, 0.03, 0.03), c.aa), (255, 255, 255))
            paint(line(sd_ellipse(X - ex, Z - EZ + 0.02, 0.12, 0.13) * 1, 0.006, c.aa) * (Z < EZ - 0.09) * fill(e + 0.02, c.aa), (150, 110, 140), 0.6)
            # blush
            b = sd_ellipse(X - sx * 0.63, Z - 4.54, 0.13, 0.075)
            paint(sm(0.02, -0.04, b), (250, 132, 146), 0.55)
        else:
            # sunken shadow around the eye, droopy lid, tiny glowing pupil
            paint(sm(0.10, -0.06, sd_ellipse(X - ex, Z - EZ + 0.03, 0.22, 0.27)), (36, 26, 52), 0.45)
            lid = (Z - EZ) - 0.07 + sx * 0.0 + 0.25 * (np.abs(X) - 0.40) * 1.0
            eye = np.maximum(e, lid)
            paint(fill(eye, c.aa), (14, 10, 20))
            paint(line(lid, 0.012, c.aa) * fill(e - 0.01, c.aa), (20, 14, 26))
            g = np.hypot(X - ex, Z - EZ + 0.05)
            paint(np.exp(-(g / 0.07) ** 2) * fill(eye, c.aa), (170, 210, 90), 0.8)
            paint(fill(g - 0.04, c.aa) * fill(eye, c.aa), (232, 246, 150))
            paint(fill(np.hypot(X - ex + 0.02, Z - EZ + 0.03) - 0.014, c.aa), (255, 255, 240))
            # brows: drooping toward the outside
            br = sd_capsule(X, Z, (sx * 0.22, 5.11), (sx * 0.60, 5.00), 0.025)
            paint(fill(br, c.aa), (34, 24, 40), 0.85)
    # nose + mouth
    n = sd_ellipse(X, Z - 4.57, 0.12, 0.075)
    n = np.maximum(n, -(Z - 4.49) - 0.02)
    paint(fill(n, c.aa), (44, 28, 32) if not night else (24, 16, 22))
    paint(fill(sd_ellipse(X + 0.035, Z - 4.595, 0.035, 0.018), c.aa), (140, 110, 120), 0.8)
    if not night:
        m1 = np.abs(np.hypot(X - 0.07, Z - 4.455) - 0.07) - 0.014
        m2 = np.abs(np.hypot(X + 0.07, Z - 4.455) - 0.07) - 0.014
        mm = np.minimum(np.where(Z < 4.455, m1, 9), np.where(Z < 4.455, m2, 9))
        paint(fill(mm, c.aa), (44, 28, 32))
        paint(fill(sd_capsule(X, Z, (0, 4.50), (0, 4.455), 0.013), c.aa), (44, 28, 32))
    else:
        pts = [(-0.20, 4.43), (-0.08, 4.39), (0.05, 4.40), (0.18, 4.37), (0.24, 4.40)]
        paint(fill(sd_polyline(X, Z, pts) - 0.014, c.aa), (24, 16, 22))
        paint(fill(sd_capsule(X, Z, (0, 4.50), (0.0, 4.40), 0.012), c.aa), (24, 16, 22))
        fang = sd_polygon(X, Z, [(0.06, 4.398), (0.12, 4.392), (0.09, 4.34)])
        paint(fill(fang, c.aa), (246, 244, 236))
    c.rgb = np.where((c.a <= 0.001)[..., None], FUR_NEUTRAL, c.rgb)
    return c


if __name__ == "__main__":
    for night, tag in ((False, "Day"), (True, "Night")):
        save(crew(night), f"T_Crew_Uniform_{tag}.png")
        save(civil_a(night), f"T_Civil_A_{tag}.png")
        save(civil_b(night), f"T_Civil_B_{tag}.png")
        save(face(night), f"T_Face_{tag}.png")
