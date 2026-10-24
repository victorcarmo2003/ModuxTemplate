"""Paint each species' single nose into its head sheets (T_Head_<A>.png and _Night.png), on top of the existing marks.

The shared expression sheets carry no nose (EXPR_NOSE off in paint_heads.py). Species with a modelled nose (pig disc,
mouse bead, beaks) or their own painted nose (koala's big nose, pink noses of rabbit/hamster/sheep) are skipped.

  python nosefix.py <species> <layout_<A>.json> [--col r,g,b]      (system Python; env CHAR_PROJECT)
Same nose shape as the old expression nose: rounded dark oval + lower lobe + small light glint, at NOSE_Z.
"""
import os, sys, json
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hcommon import TEX, w2d, D_NOSE_Z
from paint_heads import raster, fill, sd_ellipse, sm

an, lay_path = sys.argv[1], sys.argv[2]
a = sys.argv[3:]
col = np.array([int(v) for v in (a[a.index("--col") + 1] if "--col" in a else "30,22,28").split(",")], np.float32) / 255
lay = json.load(open(lay_path))
P, N, I = raster(lay)
x, z = w2d(P[..., 0], P[..., 2])
front = sm(0.25, 0.45, N[..., 1]) * (P[..., 1] > 0) * (I >= 0)
aa = 0.014
n = sd_ellipse(x, z - D_NOSE_Z, 0.115, 0.078)
n2 = sd_ellipse(x, z - (D_NOSE_Z - 0.028), 0.07, 0.06)
body = fill(np.minimum(n, n2), aa) * front
glint = fill(sd_ellipse(x + 0.035, z - D_NOSE_Z - 0.03, 0.026, 0.016), aa) * front * 0.9
for suffix, c in (("", col), ("_Night", col * 0.85)):
    p = TEX + f"T_Head_{an}{suffix}.png"
    im = np.asarray(Image.open(p).convert("RGBA")).astype(np.float32) / 255
    rgb, al = im[..., :3], im[..., 3]
    for cov, cc in ((body, c), (glint, np.array([235, 228, 236], np.float32) / 255)):
        out_a = cov + al * (1 - cov)
        mixed = (cc * cov[..., None] + rgb * (al * (1 - cov))[..., None]) / np.maximum(out_a, 1e-5)[..., None]
        # keep the original RGB under transparent texels: Roblox shows it (alpha 0 is NOT a pure "Color" window)
        rgb = np.where((cov > 1e-4)[..., None], mixed, rgb)
        al = out_a
    Image.fromarray((np.concatenate([np.clip(rgb, 0, 1), al[..., None]], -1) * 255 + 0.5).astype(np.uint8)).save(p)
    print("nose", an, suffix or "_Day", "texels", int((body > 0.5).sum()))
