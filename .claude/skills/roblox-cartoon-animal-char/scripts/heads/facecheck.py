# Face shell coverage + stretch check for every T_Expr sheet on every animal (system Python)
import json, sys, os, numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hcommon import *
from paint_heads import raster, EXPRS
FD = TEX + "face/"
A = {e: np.asarray(Image.open(FD + f"T_Expr_{e}.png"))[..., 3] / 255.0 for e in EXPRS}
def flatdot(lay):
    S = lay["size"]; D = np.full((S, S), -1.0, np.float32)
    # per-texel flat face-normal dot from the triangle the texel belongs to
    return D
for an in ORDER:
    lay = json.load(open(HD + f"/facelayout_{an}.json"))
    # store each tri's flat normal y as "n" so raster interpolates a constant
    fl = []
    for t in lay["tris"]:
        p = np.array(t["p"]); n = np.cross(p[1] - p[0], p[2] - p[0]); n /= np.linalg.norm(n)
        fl.append(dict(t, n=[list(n)] * 3))
    P, N, I = raster(dict(lay, tris=fl))
    # raster dilates 6 px; recompute the exact mask without dilation
    P0, N0, I0 = P, N, I
    S = lay["size"]
    exact = np.zeros((S, S), bool)
    ys, xs = np.mgrid[0:S, 0:S]; cx, cy = xs + 0.5, ys + 0.5
    for t in lay["tris"]:
        (x0, y0), (x1, y1), (x2, y2) = t["uv"]
        den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
        a = ((y1 - y2) * (cx - x2) + (x2 - x1) * (cy - y2)) / den
        b = ((y2 - y0) * (cx - x2) + (x0 - x2) * (cy - y2)) / den
        exact |= (a >= -1e-4) & (b >= -1e-4) & (1 - a - b >= -1e-4)
    dot = N[..., 1]
    out = []
    for e, al in A.items():
        tot = al.sum(); cut = al[~exact].sum()
        low = al[exact & (dot < 0.80)].sum()
        out.append(f"{e}: cut {cut/tot*100:.2f}% dot<0.8 {low/tot*100:.1f}% mindot {dot[exact & (al > 0.05)].min():.2f}")
    # stretch of the eye ellipse: surface length / designed length
    st = []
    for sx in (-1, 1):
        ex, ez = sx * EYE_X, EYE_Z
        rx, rz = 0.150 * FS, 0.215 * FS
        def p3(x, z):
            u, v = face_uv(x, z); return P[int(v * S), int(u * S)]
        h = np.linalg.norm(p3(ex + rx, ez) - p3(ex - rx, ez)) / (2 * rx)
        vv = np.linalg.norm(p3(ex, ez + rz) - p3(ex, ez - rz)) / (2 * rz)
        st.append((round(h, 3), round(vv, 3)))
    xs_ = [abs(p[0]) for t in lay["tris"] for p in t["p"]]
    print("FACE", an, "tris", len(lay["tris"]), "|x|max %.2f" % max(xs_), "eye stretch (h,v)", st)
    for o in out: print("    ", o)
