"""AST-053 round heads, step 2 (system Python, numpy + PIL).

T_Head_<A>[_Night].png : head marks. Alpha 0 = main fur (Roblox shows MeshPart.Color), opaque = marks.
T_Expr_<Name>.png       : expression sheets for the Face_<A> shell (transparent background), shared by all animals
                          through the standard frontal UV layout of hcommon.face_uv.
"""
import json, math, os, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from hcommon import *
# all drawing below is in DESIGN coordinates (hcommon.w2d maps the world into them)
EYE_X, EYE_Z, NOSE_Z, MOUTH_Z = D_EYE_X, D_EYE_Z, D_NOSE_Z, D_MOUTH_Z

FACE_DIR = TEX + "face/"
os.makedirs(FACE_DIR, exist_ok=True)
COL = json.load(open(HERE + "/colors.json"))
ONLY = [a for a in os.environ.get("ANIMAL", "").split(",") if a]


# ------------------------------------------------------------------ sdf helpers
def sm(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def fill(d, aa):
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
    a = math.radians(deg)
    return px * math.cos(a) - py * math.sin(a), px * math.sin(a) + py * math.cos(a)


def arc_pts(cx, cz, r, a0, a1, n=24, rz=None):
    rz = r if rz is None else rz
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cz + rz * math.sin(math.radians(a0 + (a1 - a0) * i / n)))
            for i in range(n + 1)]


def hash3(ix, iy, iz, seed):
    h = (ix * 374761393 + iy * 668265263 + iz * 1274126177 + seed * 974711) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return (h & 0xFFFF) / 65535.0


def vnoise(x, y, z, f, seed=0):
    x, y, z = x * f, y * f, z * f
    ix, iy, iz = np.floor(x).astype(np.int64), np.floor(y).astype(np.int64), np.floor(z).astype(np.int64)
    fx, fy, fz = x - ix, y - iy, z - iz
    fx, fy, fz = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy), fz * fz * (3 - 2 * fz)
    out = 0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (fx if dx else 1 - fx) * (fy if dy else 1 - fy) * (fz if dz else 1 - fz)
                out = out + w * hash3(ix + dx, iy + dy, iz + dz, seed)
    return out


class Layer:
    """straight-alpha RGBA canvas with 'over' compositing"""
    def __init__(self, shape):
        self.rgb = np.zeros(shape + (3,), np.float32)
        self.a = np.zeros(shape, np.float32)

    def paint(self, cov, col, k=1.0, mask=None):
        cov = np.clip(cov * k, 0, 1).astype(np.float32)
        if mask is not None:
            cov = cov * mask
        col = np.array(col, np.float32) / 255
        na = cov + self.a * (1 - cov)
        self.rgb = (col * cov[..., None] + self.rgb * (self.a * (1 - cov))[..., None]) / np.maximum(na, 1e-5)[..., None]
        self.a = na

    def save(self, path, fur_rgb=None):
        rgb = self.rgb.copy()
        if fur_rgb is not None:   # RGB under alpha 0 = neutral fur colour (no dark fringes when filtered)
            rgb = np.where((self.a <= 0.002)[..., None], np.array(fur_rgb, np.float32) / 255, rgb)
        img = (np.clip(np.dstack([rgb, self.a[..., None]]), 0, 1) * 255 + 0.5).astype(np.uint8)
        Image.fromarray(img).save(path)
        print("saved", os.path.basename(path), flush=True)


# ------------------------------------------------------------------ raster of the head layout (texel -> 3D)
def raster(layout):
    S = layout["size"]
    P = np.zeros((S, S, 3), np.float32); N = np.zeros((S, S, 3), np.float32); I = -np.ones((S, S), np.int32)
    ys, xs = np.mgrid[0:S, 0:S]
    cx, cy = xs + 0.5, ys + 0.5
    for t in layout["tris"]:
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
        p = np.array(t["p"], np.float32); n = np.array(t["n"], np.float32)
        pos = a[..., None] * p[0] + b[..., None] * p[1] + c[..., None] * p[2]
        nor = a[..., None] * n[0] + b[..., None] * n[1] + c[..., None] * n[2]
        P[by0:by1, bx0:bx1][m] = pos[m]; N[by0:by1, bx0:bx1][m] = nor[m]; I[by0:by1, bx0:bx1][m] = t["i"]
    for _ in range(6):
        empty = I < 0
        if not empty.any():
            break
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            sI = np.roll(I, (dy, dx), (0, 1)); sP = np.roll(P, (dy, dx), (0, 1)); sN = np.roll(N, (dy, dx), (0, 1))
            take = empty & (sI >= 0) & (I < 0)
            I[take] = sI[take]; P[take] = sP[take]; N[take] = sN[take]
    nl = np.linalg.norm(N, axis=-1, keepdims=True)
    N = N / np.maximum(nl, 1e-6)
    return P, N, I


# ------------------------------------------------------------------ head marks
AA = 0.014   # soft edge (studs) of the marks


def marks(an, x, y, z, nx, ny, nz, L):
    S2 = COL[an]["second"]
    front = sm(0.05, 0.25, ny)
    if an == "Dog":
        muz = fill(sd_ellipse(x, z - 4.25, 0.45, 0.26), AA)
        blaze = fill(np.abs(x) - (0.09 + 0.20 * np.clip(z - 4.45, 0, 1)), AA) * (z > 4.30)
        chin = fill(sd_ellipse(x, z - 4.02, 0.62, 0.20), AA)
        L.paint(np.maximum(np.maximum(muz, blaze), chin), S2, mask=front)
    elif an == "Cat":
        lob = np.maximum(fill(sd_ellipse(x - 0.17, z - 4.29, 0.26, 0.20), AA), fill(sd_ellipse(x + 0.17, z - 4.29, 0.26, 0.20), AA))
        chin = fill(sd_ellipse(x, z - 4.10, 0.40, 0.20), AA)
        L.paint(np.maximum(lob, chin), S2, mask=front)
        dark = [int(c * 0.62) for c in COL[an]["fur"]]
        side = sm(0.75, 0.95, np.abs(x))
        for k, zz in enumerate((4.66, 4.54)):
            st = fill(np.abs(z - zz - 0.10 * (np.abs(x) - 1.0)) - 0.022, AA) * sm(1.0, 1.08, np.abs(x)) * sm(-0.25, -0.05, y) * sm(0.75, 0.55, y)
            L.paint(st, dark, 0.9)
        for k, xx in enumerate((-0.16, 0.0, 0.16)):   # forehead tabby stripes (peek under the cap rim)
            st = fill(np.abs(x - xx) - 0.035, AA) * sm(4.80, 4.86, z) * (ny > 0.2)
            L.paint(st, dark, 0.9)
    elif an == "Rabbit":
        lob = np.maximum(fill(sd_ellipse(x - 0.15, z - 4.28, 0.22, 0.17), AA), fill(sd_ellipse(x + 0.15, z - 4.28, 0.22, 0.17), AA))
        L.paint(lob, S2, mask=front)
        L.paint(fill(sd_ellipse(x, z - 4.36, 0.11, 0.08), AA), COL["_PINK"], mask=front)   # pink nose under the drawn one
    elif an == "Fox":
        white = fill(z - (4.27 + 0.26 * np.abs(x)), AA) * sm(-0.35, -0.15, ny)
        L.paint(white, S2)
    elif an == "Bear":
        L.paint(fill(sd_ellipse(x, z - 4.27, 0.50, 0.30), AA), S2, mask=front)
    elif an == "Panda":
        for sx in (-1, 1):
            px, pz = rot2(x - sx * (EYE_X + 0.04), z - (EYE_Z - 0.07), -sx * 30)
            L.paint(fill(sd_ellipse(px, pz, 0.25, 0.35), AA), (46, 44, 52), mask=front)
    elif an == "Turtle":
        L.paint(fill(z - 4.27 + 0.08 * np.abs(x), AA * 2) * sm(-0.6, -0.3, ny), S2)
        dk = (0, 118, 70)
        for (sx, sz, r) in ((0.55, 4.55, .13), (0.85, 4.32, .10), (0.25, 4.75, .09), (0.70, 4.78, .08), (0.0, 4.45, .12)):
            for sg in (-1, 1):
                d = np.sqrt((x - sg * sx) ** 2 + (z - sz) ** 2) - r
                L.paint(fill(d, AA) * (ny < -0.35), dk, 0.85)
        L.paint(fill(np.sqrt(x ** 2 + (z - 4.62) ** 2) - 0.16, AA) * (ny < -0.35), dk, 0.85)
    elif an == "Owl":
        disc = np.maximum(fill(sd_ellipse(x - (EYE_X - 0.01), z - (EYE_Z - 0.04), 0.38, 0.38), AA), fill(sd_ellipse(x + (EYE_X - 0.01), z - (EYE_Z - 0.04), 0.38, 0.38), AA))
        wedge = fill(sd_polygon(x, z, [(-0.55, 4.45), (0.55, 4.45), (0.0, 4.05)]), AA)
        L.paint(np.maximum(disc, wedge), S2, mask=front)
        for sx in (-1, 1):   # amber iris rings around the drawn eyes
            L.paint(fill(sd_ellipse(x - sx * EYE_X, z - EYE_Z, 0.20, 0.275), AA), (238, 176, 64), mask=front)
            L.paint(line(sd_ellipse(x - sx * EYE_X, z - EYE_Z, 0.20, 0.275), 0.012, AA), (150, 110, 70), 0.8, mask=front)


def head_sheet(an, night):
    lay = json.load(open(HD + f"/layout_{an}.json"))
    P, N, I = raster(lay)
    x, y, z = P[..., 0], P[..., 1], P[..., 2]
    x, z = w2d(x, z)
    nx, ny, nz = N[..., 0], N[..., 1], N[..., 2]
    S = lay["size"]
    L = Layer((S, S))
    if night:
        # worn / darker fur overlay (semi-transparent over MeshPart.Color), under the marks
        n1 = vnoise(x, y, z, 2.5, 51)
        streak = sm(0.6, 0.9, vnoise(x * 6, y * 6, z * 0.6, 4.0, 9))
        fa = (0.22 + 0.16 * sm(0.4, 0.8, n1) + 0.10 * streak).astype(np.float32)
        L.rgb[:] = np.array([30, 32, 54], np.float32) / 255
        L.a = fa
    M = Layer((S, S))
    marks(an, x, y, z, nx, ny, nz, M)
    if night:
        g = M.rgb.mean(-1, keepdims=True)
        M.rgb = (M.rgb * 0.68 + g * 0.32) * 0.74 * np.array([0.86, 0.90, 1.08], np.float32)
        gr = sm(0.55, 0.75, vnoise(x, y, z, 3.0, 77)) * 0.35
        M.rgb = M.rgb * (1 - gr[..., None]) + np.array([62, 54, 46], np.float32) / 255 * gr[..., None]
    # composite marks over the (night) fur layer
    na = M.a + L.a * (1 - M.a)
    L.rgb = (M.rgb * M.a[..., None] + L.rgb * (L.a * (1 - M.a))[..., None]) / np.maximum(na, 1e-5)[..., None]
    L.a = na
    L.a = np.where(I >= 0, L.a, 0.0).astype(np.float32)
    L.save(TEX + f"T_Head_{an}{'_Night' if night else ''}.png", fur_rgb=COL[an]["fur"])


# ------------------------------------------------------------------ expressions (frontal face layout)
def expr_canvas():
    S = FACE_RES
    ys, xs = np.mgrid[0:S, 0:S]
    u, v = (xs + 0.5) / S, (ys + 0.5) / S
    X, Z = w2d(*face_xz(u, v))
    return X.astype(np.float32), Z.astype(np.float32), Layer((S, S)), 1.0 / (K * S) / FS


INK = (34, 24, 30)


EYE_RX, EYE_RZ = 0.150, 0.215          # design units (world 0.165 x 0.2365), height = 1.43 x width
EYE_INK, EYE_LOW = (20, 20, 36), (46, 48, 84)


def glint(L, X, Z, aa, ex, ez, scale=1.0, mask=None):
    """the single small white dot, upper right of the eye as seen from the front (image right = -X)"""
    L.paint(fill(sd_ellipse(X - (ex - 0.052 * scale), Z - (ez + 0.090 * scale), 0.036 * scale, 0.040 * scale), aa), (255, 255, 255), mask=mask)


def eye_open(L, X, Z, aa, sx, scale=1.0):
    ex = sx * EYE_X
    e = sd_ellipse(X - ex, Z - EYE_Z, EYE_RX * scale, EYE_RZ * scale)
    L.paint(fill(e, aa), EYE_INK)
    L.paint(fill(e, aa) * sm(-0.02, -0.20, Z - EYE_Z) * 0.5, EYE_LOW)
    glint(L, X, Z, aa, ex, EYE_Z, scale)


def blush(L, X, Z, aa, k=0.55):
    for sx in (-1, 1):
        L.paint(sm(0.02, -0.05, sd_ellipse(X - sx * (EYE_X + 0.28), Z - (EYE_Z - 0.27), 0.13, 0.075)), (250, 128, 146), k)


# The nose is NOT on the shared expression sheets: each species carries exactly one nose, either painted in its
# T_Head (see head_nose / heads/nosefix.py) or modelled (pig disc, mouse bead, beaks) — otherwise species with their
# own nose showed two (user, 2026-10-10). EXPR_NOSE=1 restores the old behaviour.
EXPR_NOSE = os.environ.get("EXPR_NOSE") == "1"


def nose(L, X, Z, aa, col=(30, 22, 28), force=False):
    if not (EXPR_NOSE or force):
        return
    n = sd_ellipse(X, Z - NOSE_Z, 0.115, 0.078)
    n2 = sd_ellipse(X, Z - (NOSE_Z - 0.028), 0.07, 0.06)       # rounded lower lobe
    L.paint(fill(np.minimum(n, n2), aa), col)
    L.paint(fill(sd_ellipse(X + 0.035, Z - NOSE_Z - 0.03, 0.026, 0.016), aa), (235, 228, 236), 0.9)


def mouth_w(L, X, Z, aa, col=INK, w=0.014):
    c = MOUTH_Z + 0.045
    m1 = np.abs(np.hypot(X - 0.07, Z - c) - 0.07) - w
    m2 = np.abs(np.hypot(X + 0.07, Z - c) - 0.07) - w
    mm = np.minimum(np.where(Z < c, m1, 9), np.where(Z < c, m2, 9))
    L.paint(fill(mm, aa), col)
    L.paint(fill(sd_capsule(X, Z, (0, NOSE_Z - 0.06), (0, c), w), aa), col)


def expr(name):
    X, Z, L, aa = expr_canvas()
    if name == "Normal":
        for sx in (-1, 1):
            eye_open(L, X, Z, aa, sx)
        blush(L, X, Z, aa)
        nose(L, X, Z, aa)
        mouth_w(L, X, Z, aa)
    elif name == "Happy":
        for sx in (-1, 1):   # closed smiling eyes  ^ ^
            pts = arc_pts(sx * EYE_X, EYE_Z - 0.07, 0.13, 15, 165, rz=0.15)
            L.paint(fill(sd_polyline(X, Z, pts) - 0.034, aa), (28, 20, 28))
        blush(L, X, Z, aa, 0.75)
        nose(L, X, Z, aa)
        pts = arc_pts(0, MOUTH_Z + 0.07, 0.17, 200, 340, rz=0.12)
        L.paint(fill(sd_polyline(X, Z, pts) - 0.016, aa), INK)
        L.paint(fill(sd_capsule(X, Z, (0, NOSE_Z - 0.06), (0, MOUTH_Z - 0.04), 0.014), aa), INK)
    elif name == "Smile":
        for sx in (-1, 1):
            eye_open(L, X, Z, aa, sx, 1.04)
        blush(L, X, Z, aa, 0.7)
        cz = MOUTH_Z + 0.04
        mo = np.maximum(sd_ellipse(X, Z - cz, 0.19, 0.17), Z - cz)        # lower half-ellipse (D on its side)
        L.paint(fill(mo, aa), (96, 30, 42))
        L.paint(fill(np.maximum(sd_ellipse(X, Z - (cz - 0.17), 0.12, 0.08), mo), aa), (238, 112, 128))
        L.paint(line(mo, 0.010, aa), (40, 18, 24))
        nose(L, X, Z, aa)
        L.paint(fill(sd_capsule(X, Z, (0, NOSE_Z - 0.06), (0, cz), 0.014), aa), INK)
    elif name == "Sad":
        for sx in (-1, 1):
            ex = sx * EYE_X
            e = sd_ellipse(X - ex, Z - EYE_Z, EYE_RX, EYE_RZ * 0.93)
            lid = (Z - EYE_Z) - 0.12 + 0.70 * (np.abs(X) - EYE_X)      # droopy outer corner
            eye = np.maximum(e, lid)
            L.paint(fill(eye, aa), EYE_INK)
            L.paint(fill(eye, aa) * sm(-0.02, -0.20, Z - EYE_Z) * 0.5, EYE_LOW)
            glint(L, X, Z, aa, ex, EYE_Z - 0.035, 0.95, mask=fill(eye + 0.012, aa))
            L.paint(line(lid, 0.016, aa) * fill(e - 0.02, aa), EYE_INK)
            br = sd_capsule(X, Z, (sx * (EYE_X - 0.16), EYE_Z + 0.20), (sx * (EYE_X + 0.17), EYE_Z + 0.05), 0.02)
            L.paint(fill(br, aa), (40, 28, 34))
        # tear under the right eye
        tx, tz = EYE_X + 0.07, EYE_Z - 0.29
        tear = np.minimum(sd_ellipse(X - tx, Z - tz, 0.05, 0.06), sd_polygon(X, Z, [(tx - 0.045, tz + 0.02), (tx + 0.045, tz + 0.02), (tx, tz + 0.13)]))
        L.paint(fill(tear, aa), (120, 190, 250), 0.95)
        L.paint(fill(sd_ellipse(X - tx + 0.015, Z - tz + 0.01, 0.015, 0.02), aa), (240, 250, 255))
        nose(L, X, Z, aa)
        pts = arc_pts(0, MOUTH_Z - 0.10, 0.13, 35, 145, rz=0.09)
        L.paint(fill(sd_polyline(X, Z, pts) - 0.016, aa), INK)
    elif name == "Fainted":
        for sx in (-1, 1):
            ex = sx * EYE_X
            for d in (1, -1):
                L.paint(fill(sd_capsule(X, Z, (ex - 0.11, EYE_Z - 0.13 * d), (ex + 0.11, EYE_Z + 0.13 * d), 0.032), aa), EYE_INK)
        nose(L, X, Z, aa)
        zz = [(-0.17 + i * 0.0425, MOUTH_Z - 0.01 + (0.03 if i % 2 else -0.03)) for i in range(9)]
        L.paint(fill(sd_polyline(X, Z, zz) - 0.015, aa), INK)
        # little dizzy stars
        for (sx, sz, r, rot) in ((-0.72, EYE_Z + 0.12, 0.075, 10), (0.72, EYE_Z + 0.08, 0.085, -8), (0.84, EYE_Z - 0.15, 0.05, 20)):
            pts = []
            for i in range(10):
                ang = math.radians(90 + rot + 36 * i)
                rr = r if i % 2 == 0 else r * 0.45
                pts.append((sx + rr * math.cos(ang), sz + rr * math.sin(ang)))
            st = sd_polygon(X, Z, pts)
            L.paint(fill(st, aa), (255, 214, 64))
            L.paint(line(st, 0.006, aa), (176, 120, 30), 0.9)
    elif name == "Normal_Night":
        for sx in (-1, 1):
            ex = sx * EYE_X
            e = sd_ellipse(X - ex, Z - EYE_Z, EYE_RX * 1.03, 0.21)
            L.paint(sm(0.10, -0.06, sd_ellipse(X - ex, Z - EYE_Z + 0.04, 0.20, 0.27)), (40, 30, 58), 0.40)   # soft olheira
            lid = (Z - EYE_Z) - 0.08 + 0.22 * (np.abs(X) - EYE_X)
            eye = np.maximum(e, lid)
            L.paint(fill(eye, aa), (16, 12, 22))
            L.paint(line(lid, 0.012, aa) * fill(e - 0.01, aa), (24, 16, 30))
            g = np.hypot(X - ex, Z - EYE_Z + 0.04)
            L.paint(np.exp(-(g / 0.07) ** 2) * fill(eye, aa), (170, 210, 90), 0.8)
            L.paint(fill(g - 0.042, aa) * fill(eye, aa), (232, 246, 150))
            L.paint(fill(np.hypot(X - ex + 0.018, Z - EYE_Z + 0.022) - 0.013, aa), (255, 255, 240))
            br = sd_capsule(X, Z, (sx * (EYE_X - 0.16), EYE_Z + 0.175), (sx * (EYE_X + 0.18), EYE_Z + 0.085), 0.024)
            L.paint(fill(br, aa), (36, 26, 42), 0.85)
        nose(L, X, Z, aa, (26, 18, 24))
        pts = [(-0.18, MOUTH_Z + 0.01), (-0.07, MOUTH_Z - 0.025), (0.05, MOUTH_Z - 0.015), (0.16, MOUTH_Z - 0.04), (0.21, MOUTH_Z - 0.01)]
        L.paint(fill(sd_polyline(X, Z, pts) - 0.014, aa), (26, 18, 24))
        L.paint(fill(sd_capsule(X, Z, (0, NOSE_Z - 0.06), (0.0, MOUTH_Z - 0.02), 0.012), aa), (26, 18, 24))
        fang = sd_polygon(X, Z, [(0.06, MOUTH_Z - 0.022), (0.115, MOUTH_Z - 0.028), (0.088, MOUTH_Z - 0.075)])
        L.paint(fill(fang, aa), (246, 244, 236))
    elif name == "Skeptical":
        # one eye open with a raised brow, the other half-lidded under a flat low brow; mouth pulled to one side
        for sx in (-1, 1):
            ex = sx * EYE_X
            e = sd_ellipse(X - ex, Z - EYE_Z, EYE_RX, EYE_RZ)
            if sx == 1:
                eye = e
                L.paint(fill(eye, aa), EYE_INK)
                L.paint(fill(eye, aa) * sm(-0.02, -0.20, Z - EYE_Z) * 0.5, EYE_LOW)
                glint(L, X, Z, aa, ex, EYE_Z)
                br = arc_pts(ex, EYE_Z + 0.22, 0.17, 20, 160, n=12, rz=0.07)
                L.paint(fill(sd_polyline(X, Z, br) - 0.022, aa), (40, 28, 34))
            else:
                lid = (Z - EYE_Z) - 0.02
                eye = np.maximum(e, lid)
                L.paint(fill(eye, aa), EYE_INK)
                L.paint(line(lid, 0.016, aa) * fill(e - 0.02, aa), EYE_INK)
                glint(L, X, Z, aa, ex, EYE_Z - 0.10, 0.85, mask=fill(eye + 0.012, aa))
                br = sd_capsule(X, Z, (ex - 0.17, EYE_Z + 0.10), (ex + 0.17, EYE_Z + 0.13), 0.022)
                L.paint(fill(br, aa), (40, 28, 34))
        nose(L, X, Z, aa)
        pts = [(-0.16, MOUTH_Z + 0.005), (-0.02, MOUTH_Z + 0.0), (0.10, MOUTH_Z + 0.02), (0.17, MOUTH_Z + 0.05)]
        L.paint(fill(sd_polyline(X, Z, pts) - 0.015, aa), INK)
        L.paint(fill(sd_capsule(X, Z, (0, NOSE_Z - 0.06), (0, MOUTH_Z + 0.0), 0.013), aa), INK)
    elif name == "Exhausted":
        # depressed / worn out: heavy half-closed lids, dark bags, brows sloping down to the sides, small downturned mouth
        for sx in (-1, 1):
            ex = sx * EYE_X
            e = sd_ellipse(X - ex, Z - EYE_Z, EYE_RX, EYE_RZ * 0.95)
            lid = (Z - EYE_Z) + 0.03 - 0.10 * (np.abs(X) - EYE_X)
            eye = np.maximum(e, lid)
            L.paint(sm(0.06, -0.04, sd_ellipse(X - ex, Z - (EYE_Z - 0.20), 0.17, 0.07)), (92, 70, 110), 0.55)   # eye bags
            L.paint(fill(eye, aa), EYE_INK)
            L.paint(line(lid, 0.018, aa) * fill(e - 0.02, aa), EYE_INK)
            glint(L, X, Z, aa, ex, EYE_Z - 0.13, 0.7, mask=fill(eye + 0.012, aa))
            br = sd_capsule(X, Z, (sx * (EYE_X - 0.15), EYE_Z + 0.17), (sx * (EYE_X + 0.18), EYE_Z + 0.08), 0.018)
            L.paint(fill(br, aa), (40, 28, 34), 0.9)
        nose(L, X, Z, aa)
        pts = arc_pts(0, MOUTH_Z - 0.08, 0.09, 50, 130, rz=0.05)
        L.paint(fill(sd_polyline(X, Z, pts) - 0.014, aa), INK)
    elif name == "Stressed":
        # wide eyes with small pupils, furrowed brows, clenched zig-zag teeth, sweat drop, stress mark
        for sx in (-1, 1):
            ex = sx * EYE_X
            e = sd_ellipse(X - ex, Z - EYE_Z, EYE_RX * 1.05, EYE_RZ * 1.02)
            L.paint(fill(e, aa), (250, 248, 244))
            L.paint(line(e, 0.016, aa), EYE_INK)
            p = sd_ellipse(X - ex, Z - (EYE_Z - 0.01), 0.055, 0.075)
            L.paint(fill(p, aa), EYE_INK)
            L.paint(fill(sd_ellipse(X - (ex - 0.02), Z - (EYE_Z + 0.02), 0.016, 0.018), aa), (255, 255, 255))
            br = sd_capsule(X, Z, (sx * (EYE_X - 0.15), EYE_Z + 0.16), (sx * (EYE_X + 0.17), EYE_Z + 0.27), 0.024)
            L.paint(fill(br, aa), (40, 28, 34))
        nose(L, X, Z, aa)
        cz = MOUTH_Z - 0.01
        box = sd_box(X, Z - cz, 0.17, 0.055, 0.02) if "sd_box" in globals() else np.maximum(np.abs(X) - 0.17, np.abs(Z - cz) - 0.055)
        L.paint(fill(box, aa), (250, 248, 244))
        zz = [(-0.17 + i * 0.0425, cz + (0.022 if i % 2 else -0.022)) for i in range(9)]
        L.paint(fill(sd_polyline(X, Z, zz) - 0.008, aa) * fill(box, aa), INK)
        L.paint(line(box, 0.012, aa), INK)
        # sweat drop at the temple (viewer's right) and a stress mark on the other side
        tx, tz = -(EYE_X + 0.33), EYE_Z + 0.10
        drop = np.minimum(sd_ellipse(X - tx, Z - tz, 0.05, 0.065), sd_polygon(X, Z, [(tx - 0.045, tz + 0.02), (tx + 0.045, tz + 0.02), (tx, tz + 0.15)]))
        L.paint(fill(drop, aa), (120, 190, 250), 0.95)
        L.paint(fill(sd_ellipse(X - tx + 0.015, Z - tz + 0.012, 0.014, 0.02), aa), (240, 250, 255))
        sx0, sz0 = EYE_X + 0.36, EYE_Z + 0.16
        for a in (0, 90, 180, 270):
            ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
            pts = arc_pts(sx0 + 0.045 * ca, sz0 + 0.045 * sa, 0.04, a + 100, a + 260, n=8)
            L.paint(fill(sd_polyline(X, Z, pts) - 0.014, aa), (214, 60, 70))
    L.save(FACE_DIR + f"T_Expr_{name}.png", fur_rgb=(40, 30, 34))


EXPRS = ["Normal", "Happy", "Smile", "Sad", "Fainted", "Normal_Night", "Skeptical", "Exhausted", "Stressed"]

if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what in ("all", "heads"):
        for an in (ONLY or ORDER):
            head_sheet(an, False)
            head_sheet(an, True)
    if what in ("all", "expr"):
        for e in EXPRS:
            expr(e)
