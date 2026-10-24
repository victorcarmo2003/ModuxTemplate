import os as _os
WORK = _os.environ.get("CHAR_WORK", _os.getcwd()).replace("\\", "/")
PROJECT = _os.environ.get("CHAR_PROJECT", "").replace("\\", "/").rstrip("/") + "/"
import json
from PIL import Image
im = Image.open(PROJECT + r"Assets/KitchenPack/Assets/gltf/restaurantbits_texture.png").convert("RGB")
W, H = im.size
def band(b, t=0.5):
    r, c, lo, hi = b
    frac = lo + t * (hi - lo)
    return list(im.getpixel((int((c + 0.5) / 8 * W), min(H - 1, int((r + frac) / 4 * H)))))
WHITE=(0,4,0.0,0.28); WARMW=(1,4,0.0,0.25); PINK=(2,5,0.04,0.32); BLACK=(0,0,0.62,0.95)
B = {"Dog": dict(P=(0,6,.05,.45), S=WARMW, hand="P"),
     "Cat": dict(P=(0,3,.40,.85), S=WHITE, hand="S"),
     "Rabbit": dict(P=WHITE, S=WARMW, hand="P"),
     "Fox": dict(P=(0,5,.05,.40), S=WHITE, hand="P"),
     "Bear": dict(P=(0,6,.35,.80), S=(1,5,.10,.45), hand="P"),
     "Panda": dict(P=WHITE, S=(0,0,.60,.95), hand="S"),
     "Turtle": dict(P=(2,1,.10,.45), S=(2,0,.05,.35), hand="P"),
     "Owl": dict(P=(0,7,.05,.50), S=(1,4,.10,.45), hand="P")}
out = {}
for a, d in B.items():
    out[a] = {"fur": band(d["P"]), "second": band(d["S"]), "hand": band(d[d["hand"]])}
out["_PINK"] = band(PINK); out["_BLACK"] = band(BLACK); out["_BEAK"] = band((2,3,.55,.95))
out["_EARDOG"] = band((0,6,.35,.85))
json.dump(out, open("colors.json", "w"), indent=1)
print(json.dumps(out))
