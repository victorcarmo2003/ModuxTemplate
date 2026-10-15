"""ANM-001 "blank folks" (AST-060) and ANM-004 "copies" (AST-062) face/skin textures. Pillow + numpy only (no Blender).

Writes (repo root):  python tools/assetplace/gen_blank_textures.py
  Assets/textures/character/blank/T_Head_<A>_Blank.png            opaque 512^2, species fur colour, NO features
  Assets/textures/character/blank/T_Atlas_Kitchen_<Pack>_Blank_<A>.png
        copy of T_Atlas_Kitchen_<Day|Mid|Night> with the texels used by the species' Ears/Tail (+ Nose/Snout/Beak/
        EyeBumps: face parts) painted flat in the same fur colour. One atlas per species and pack.
  Assets/textures/character/face/T_Expr_Blank.png                 512^2 fully transparent (head carries the colour)
  Assets/textures/character/face/T_Expr_EyesWhite.png             T_Expr_Normal with plain white eyes (no pupil)
Part UVs: tools/assetplace/data/crew_part_uv.json (triangles of Assets/models/character/AST-053_Animal_<A>.fbx,
dumped with Blender headless; Head_/Face_ excluded). Fur = gen_crew_looks.fur_hex (RGB under alpha-0 of T_Head_<A>).
"""
import json, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).parent))
import gen_crew_looks as G

ROOT = G.ROOT
TEX = G.TEX_DIR
OUT = TEX / "blank"
FACE = TEX / "face"
UV = json.loads((Path(__file__).parent / "data/crew_part_uv.json").read_text())
TINT = ("Ears", "Tail", "Nose", "Snout", "Beak", "EyeBumps")  # Wool/Mane/Shell are kept (hair / body shell)


_DAY = None


def mask_for(species: str, size: int) -> Image.Image:
    """The atlas is a patchwork of colour swatches (vertical gradients) and the parts sample single texel lines
    inside them (degenerate UV triangles). Unit to repaint = the whole swatch under every vertex of a face part:
    flood fill on the Day atlas (step-to-step colour jump > JUMP = swatch border), limited to its 128px column."""
    global _DAY
    if _DAY is None:
        _DAY = np.asarray(Image.open(TEX / "T_Atlas_Kitchen_Day.png").convert("RGB")).astype(np.int16)
    img = _DAY
    seeds = set()
    for part, flat in UV[species].items():
        if part.split("_")[0] not in TINT:
            continue
        for i in range(0, len(flat), 2):
            x = min(size - 1, int(flat[i] * size))
            y = min(size - 1, max(0, int((1 - flat[i + 1]) * size)))
            seeds.add((x, y))
    mask = np.zeros((size, size), bool)
    cw = size // 8
    JUMP = 14
    for sx, sy in seeds:
        if mask[sy, sx]:
            continue
        lo, hi = (sx // cw) * cw, (sx // cw + 1) * cw
        stack = [(sx, sy)]
        mask[sy, sx] = True
        while stack:
            x, y = stack.pop()
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if lo <= nx < hi and 0 <= ny < size and not mask[ny, nx] and np.abs(img[ny, nx] - img[y, x]).max() <= JUMP:
                    mask[ny, nx] = True
                    stack.append((nx, ny))
    return Image.fromarray((mask * 255).astype(np.uint8))


def blank_assets() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    atlases = {p: Image.open(TEX / f"T_Atlas_Kitchen_{p}.png").convert("RGBA") for p in ("Day", "Mid", "Night")}
    for asset in G.SPECIES.values():
        fur = tuple(int(G.fur_hex(asset)[i:i + 2], 16) for i in (0, 2, 4))
        Image.new("RGBA", (512, 512), fur + (255,)).save(OUT / f"T_Head_{asset}_Blank.png")
        for pack, atlas in atlases.items():
            m = np.asarray(mask_for(asset, atlas.size[0])) > 0
            a = np.asarray(atlas).copy()
            a[m, :3] = fur
            a[m, 3] = 255
            Image.fromarray(a).save(OUT / f"T_Atlas_Kitchen_{pack}_Blank_{asset}.png")
        print("blank", asset, "#%02X%02X%02X" % fur)


def expr_assets() -> None:
    Image.new("RGBA", (512, 512), (0, 0, 0, 0)).save(FACE / "T_Expr_Blank.png")
    im = Image.open(FACE / "T_Expr_Normal.png").convert("RGBA")
    a = np.asarray(im)
    dark = (a[..., 3] > 128) & (a[..., :3].max(-1) < 90)
    dark[230:] = False  # eyes only (mouth/blush are lower)
    out = im.copy()
    d = ImageDraw.Draw(out)
    for x0, x1 in ((0, 256), (256, 512)):
        ys, xs = np.nonzero(dark[:, x0:x1])
        box = [xs.min() + x0 - 1, ys.min() - 1, xs.max() + x0 + 1, ys.max() + 1]
        # wipe the old pupil + highlight, then a plain white oval with a thin grey rim (reads on pale fur)
        d.ellipse(box, fill=(255, 255, 255, 255), outline=(70, 70, 84, 255), width=3)
        print("eye", box)
    out.save(FACE / "T_Expr_EyesWhite.png")


if __name__ == "__main__":
    blank_assets()
    expr_assets()
