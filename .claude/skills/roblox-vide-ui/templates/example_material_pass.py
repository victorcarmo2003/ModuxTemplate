"""Material pass for the RPG screen: post-process Blender renders + build textures/shadows (all PNG, Roblox-ready)."""
import glob
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, os.path.expanduser("~/.claude/skills/roblox-vide-ui/scripts"))
from export_layers import bleed  # noqa: E402

B3D = "b3d"
OUT = "mat"
os.makedirs(OUT, exist_ok=True)


def save(img: Image.Image, name: str, white: bool = False) -> str:
    p = os.path.join(OUT, name)
    img.save(p)
    bleed(__import__("pathlib").Path(p), white=white)
    return p


# 1) 3D ornaments: copy + bleed; divider gets faded ends
for f in ["panel_frame9_3d", "title_plate_3d", "close_3d", "bar_frame_3d", "tip_frame9_3d", "divider_3d"]:
    im = Image.open(os.path.join(B3D, f + ".png")).convert("RGBA")
    if f == "divider_3d":
        a = np.asarray(im).astype(np.float32)
        w = a.shape[1]
        x = np.linspace(0, 1, w)
        fade = np.clip(np.minimum(x, 1 - x) / 0.28, 0, 1) ** 1.4
        a[..., 3] *= fade[None, :]
        im = Image.fromarray(a.astype(np.uint8))
    save(im, f + ".png")

# 2) drop shadows (black, blurred alpha) for raised ornaments; offset is applied in Roblox
def shadow(src: str, name: str, blur: float, strength: float = 0.85):
    im = Image.open(os.path.join(B3D, src)).convert("RGBA")
    pad = int(blur * 3)
    a = Image.new("L", (im.width + 2 * pad, im.height + 2 * pad), 0)
    a.paste(im.getchannel("A"), (pad, pad))
    a = a.filter(ImageFilter.GaussianBlur(blur)).point(lambda v: int(v * strength))
    out = Image.new("RGBA", a.size, (0, 0, 0, 0))
    out.putalpha(a)
    # NO white bleed here: bleed(white=True) sets RGB to 255 and turns the shadow into a white halo (seen in
    # Studio). Shadows keep black RGB everywhere, which is already "bled".
    out.save(os.path.join(OUT, name))
    return pad

pads = {n: shadow(s, n, b) for s, n, b in [("title_plate_3d.png", "title_plate_shadow.png", 8),
                                            ("close_3d.png", "close_shadow.png", 6)]}

# 3) leather tile from Poly Haven brown_leather (CC0): darken + warm grade + relief from the normal map.
# saved from Blender (the MCP's Poly Haven temp folder is deleted right after import)
src = os.path.join(B3D, "brown_leather_Diffuse.png")
nrm = os.path.join(B3D, "brown_leather_nor_gl.png")
d = np.asarray(Image.open(src).convert("RGB").resize((512, 512), Image.LANCZOS)).astype(np.float32) / 255
n = np.asarray(Image.open(nrm).convert("RGB").resize((512, 512), Image.LANCZOS)).astype(np.float32) / 255 * 2 - 1
lum = d.mean(axis=2)
light = np.array([-0.45, 0.55, 0.70]); light /= np.linalg.norm(light)  # top-left, matches the Blender key light
shade = np.clip((n * light).sum(axis=2), 0, 1)
z = (lum - lum.mean()) / (lum.std() + 1e-6)          # normalized grain (creases, pores)
relief = (shade - shade.mean()) / (shade.std() + 1e-6)  # normal-map relief lit from top-left
v = 1.0 + 0.16 * np.clip(z, -3, 3) + 0.14 * np.clip(relief, -3, 3)
base = np.array([0.125, 0.090, 0.064])  # dark warm leather
tile = np.clip(base[None, None, :] * v[..., None], 0, 1)
print("leather lum mean/std", round(float(tile.mean()), 4), round(float(tile.mean(axis=2).std()), 4))
Image.fromarray((tile * 255).astype(np.uint8)).save(os.path.join(OUT, "leather_tile.png"))
# seam check: wrap-around difference must be tiny (texture is seamless by source)
seam = np.abs(tile[:, 0] - tile[:, -1]).mean() + np.abs(tile[0] - tile[-1]).mean()
print("leather seam delta", round(float(seam), 4))

# 4) recessed-slot inner shadow, 9-slice (64x64, margin 20): dark edges fading inward, top darker (light from top)
S, M = 128, 40  # 2x
yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
dist = np.minimum.reduce([xx, yy, S - 1 - xx, S - 1 - yy])
inner = np.clip(1 - dist / (M * 0.9), 0, 1) ** 1.6
top = np.clip(1 - yy / (S * 0.45), 0, 1) ** 2 * 0.35
alpha = np.clip(inner * 0.85 + top, 0, 1)
im = np.zeros((S, S, 4), np.uint8); im[..., 3] = (alpha * 255).astype(np.uint8)
Image.fromarray(im).save(os.path.join(OUT, "inset_shadow9.png"))
# bottom-edge highlight (the lip of the recess catches light)
hl = np.zeros((S, S, 4), np.uint8); hl[..., :3] = 255
hl[..., 3] = (np.clip(1 - (S - 1 - yy) / 6, 0, 1) * 70).astype(np.uint8)
Image.fromarray(hl).save(os.path.join(OUT, "inset_lip9.png"))

# 5) panel outer soft shadow, 9-slice (256x256, margin 96)
S2 = 256
yy, xx = np.mgrid[0:S2, 0:S2].astype(np.float32)
dist = np.minimum.reduce([xx, yy, S2 - 1 - xx, S2 - 1 - yy])
a = np.clip(dist / 96, 0, 1) ** 1.8
im = np.zeros((S2, S2, 4), np.uint8); im[..., 3] = (a * 200).astype(np.uint8)
Image.fromarray(im).save(os.path.join(OUT, "drop_shadow9.png"))

# 6) ember specks tile (256x256): sparse glowing dots, tinted in Roblox, scrolled upward
rng = np.random.default_rng(7)
E = np.zeros((256, 256), np.float32)
for _ in range(38):
    x, y, r = rng.integers(0, 256), rng.integers(0, 256), rng.uniform(0.8, 2.2)
    yy, xx = np.mgrid[0:256, 0:256]
    dx = np.minimum(np.abs(xx - x), 256 - np.abs(xx - x)); dy = np.minimum(np.abs(yy - y), 256 - np.abs(yy - y))
    E = np.maximum(E, np.exp(-(dx ** 2 + dy ** 2) / (2 * r * r)) * rng.uniform(0.4, 1.0))
im = np.zeros((256, 256, 4), np.uint8); im[..., :3] = 255; im[..., 3] = (np.clip(E, 0, 1) * 255).astype(np.uint8)
Image.fromarray(im).save(os.path.join(OUT, "embers_tile.png"))

for f in sorted(os.listdir(OUT)):
    print(f, Image.open(os.path.join(OUT, f)).size)
print("shadow pads", pads)
