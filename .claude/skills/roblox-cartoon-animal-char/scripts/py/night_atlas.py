"""Night copy of a colour atlas for atlas-coloured accessories (ears, tail, shell, beak, cap with ear holes).

  python night_atlas.py <atlas.png> <out.png> [--navy 32,34,56] [--k 0.85]

Rules (match the night head and the night outfit as they render in Roblox):
  fur-like tones -> lerp k toward the night fur colour (navy by default)
  light, low-saturation (whites/creams) -> x0.74 with a cool tint (like the night head marks)
  saturated reds -> red channel x0.51 (like the night uniform reds)
  near-black -> unchanged
"""
import sys
import numpy as np
from PIL import Image

a = sys.argv[1:]
src, out = a[0], a[1]
navy = np.array([int(v) for v in (a[a.index("--navy") + 1] if "--navy" in a else "32,34,56").split(",")], np.float32) / 255
k = float(a[a.index("--k") + 1]) if "--k" in a else 0.85
im = np.asarray(Image.open(src).convert("RGBA")).astype(np.float32) / 255
rgb = im[..., :3]
mx, mn = rgb.max(-1), rgb.min(-1)
sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-5), 0)
r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
red = (r == mx) & (sat > 0.55) & (mx > 0.4) & (g < 0.45 * r + 0.05) & (b < 0.6 * r)
light = (mx > 0.78) & (sat < 0.25)
o = rgb * (1 - k) + navy * k
o = np.where(light[..., None], rgb * 0.74 * np.array([0.86, 0.90, 1.08]), o)
o = np.where(red[..., None], rgb * np.array([0.51, 1.0, 1.0]) + np.array([0, 4, 3]) / 255, o)
o = np.where((mx < 0.12)[..., None], rgb, o)
Image.fromarray((np.concatenate([np.clip(o, 0, 1), im[..., 3:]], -1) * 255 + 0.5).astype(np.uint8)).save(out)
print("night atlas", out, "red %.3f light %.3f" % (red.mean(), light.mean()))
