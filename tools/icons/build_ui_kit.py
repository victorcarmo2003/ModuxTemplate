"""AST-091 UI kit images: RhosGFX vector icons with the AST-071 Ink outline, packed in a 1024 atlas, plus the
tileable studs texture for the cartoon panels.

   python build_ui_kit.py "<Rhos Vectors folder>" <repo_root>

Writes (repo):
  Assets/textures/ui/rhos/<Icon> 256.png      untouched copies of the icons used (RhosGFX licence: use in our game,
                                              never resell/redistribute; see docs/art/credits.md)
  Assets/textures/ui/AST-091_ui_icons.png     1024² atlas, 128² cells, Ink outline 4 px (same as AST-071)
  Assets/textures/ui/AST-091_ui_icons.json    name -> ImageRectOffset / ImageRectSize, source file
  Assets/textures/ui/AST-091_studs.png        128² tileable stud (white highlight + dark rim on transparent)
and prints the Luau rect table for src/Interface/client/Components/Icons/init.luau (UI_RECTS).
"""
import json, os, shutil, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

RHOS, ROOT = sys.argv[1], sys.argv[2]
OUT = os.path.join(ROOT, "Assets", "textures", "ui")
CELL = 128
SS = 4
W = CELL * SS
OUTLINE = 4 * SS
MARGIN = 4 * SS
BOX = W - 2 * (OUTLINE + MARGIN)
INK = (0x2B, 0x22, 0x33)

# atlas name -> (Rhos folder, variant suffix). Flat White = white silhouette (arrows, close) that the UI tints.
ICONS = [
    ("Ui/close", "X", "Flat White"),
    ("Ui/check", "Check Mark", ""),
    ("Ui/arrow_left", "Arrow Left", ""),
    ("Ui/arrow_right", "Arrow Right", ""),
    ("Ui/spectate", "Spectate", ""),
    ("Ui/hourglass", "Hourglass", ""),
    ("Ui/info", "Info", ""),
    ("Ui/warning", "Warning", ""),
    ("Ui/sparkle", "Sparkle", ""),
    ("Ui/trophy", "Trophy", ""),
    ("Ui/calendar", "Calendar", ""),
    ("Ui/cash", "Cash", ""),
    ("Ui/tip_jar", "Tip Jar", ""),
    ("Ui/friends", "Friends", ""),
    ("Ui/paw", "Paw", ""),
    ("Ui/thumbs_up", "Thumbs Up", ""),
    ("Ui/clock", "Clock", ""),
    ("Ui/lantern", "Lantern", ""),
    ("Ui/megaphone", "Megaphone", ""),
    ("Ui/bell", "Bell", ""),
]


def source(folder, variant):
    name = f"{folder} {variant} 256.png" if variant else f"{folder} 256.png"
    return os.path.join(RHOS, folder, name), name


def fit(im):
    a = np.array(im)[..., 3]
    ys, xs = np.where(a > 8)
    im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    k = BOX / max(im.size)
    im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
    out = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    out.alpha_composite(im, ((W - im.width) // 2, (W - im.height) // 2))
    return out


def outline(im):
    a = np.array(im)[..., 3].astype(np.float32) / 255
    solid = ndimage.binary_fill_holes(a > 0.08)
    dist = ndimage.distance_transform_edt(~solid)
    ring = np.clip(OUTLINE + 0.5 - dist, 0, 1)
    base = np.zeros((im.height, im.width, 4), np.float32)
    base[..., :3] = INK
    base[..., 3] = ring * 255
    out = Image.fromarray(base.astype(np.uint8))
    out.alpha_composite(im)
    return out


def bleed(im):
    """Transparent pixels get the Ink colour (the outer edge), so bilinear filtering never shows a black/white halo."""
    arr = np.array(im)
    clear = arr[..., 3] == 0
    arr[clear, 0], arr[clear, 1], arr[clear, 2] = INK
    return Image.fromarray(arr)


def studs():
    """One round stud per 128² tile: soft dark rim at the bottom right, white highlight at the top left. Tinted and
    faded in engine (ImageColor3 / ImageTransparency); tiles seamlessly because the stud never touches the edge."""
    s = 128 * SS
    c, r = s / 2, s * 0.30
    img = Image.new("RGBA", (s, s), (255, 255, 255, 0))
    shadow = Image.new("L", (s, s), 0)
    ImageDraw.Draw(shadow).ellipse((c - r + 6 * SS, c - r + 8 * SS, c + r + 6 * SS, c + r + 8 * SS), fill=150)
    shadow = shadow.filter(ImageFilter.GaussianBlur(4 * SS))
    dark = Image.new("RGBA", (s, s), INK + (0,))
    dark.putalpha(shadow)
    img.alpha_composite(dark)
    face = Image.new("L", (s, s), 0)
    ImageDraw.Draw(face).ellipse((c - r, c - r, c + r, c + r), fill=110)
    top = Image.new("RGBA", (s, s), (255, 255, 255, 0))
    top.putalpha(face)
    img.alpha_composite(top)
    shine = Image.new("L", (s, s), 0)
    ImageDraw.Draw(shine).ellipse((c - r * 0.75, c - r * 0.8, c + r * 0.1, c - r * 0.05), fill=200)
    shine = shine.filter(ImageFilter.GaussianBlur(3 * SS))
    light = Image.new("RGBA", (s, s), (255, 255, 255, 0))
    light.putalpha(shine)
    img.alpha_composite(light)
    out = img.resize((128, 128), Image.LANCZOS)
    arr = np.array(out)
    arr[arr[..., 3] == 0, :3] = 255
    return Image.fromarray(arr)


def main():
    os.makedirs(os.path.join(OUT, "rhos"), exist_ok=True)
    sheet = Image.new("RGBA", (1024, 1024), INK + (0,))
    meta = {}
    lines = []
    for i, (key, folder, variant) in enumerate(ICONS):
        path, name = source(folder, variant)
        shutil.copyfile(path, os.path.join(OUT, "rhos", name))
        icon = Image.open(path).convert("RGBA")
        cell = outline(fit(icon)).convert("RGBa").resize((CELL, CELL), Image.LANCZOS).convert("RGBA")
        x, y = (i % 8) * CELL, (i // 8) * CELL
        sheet.alpha_composite(cell, (x, y))
        meta[key] = {"ImageRectOffset": [x, y], "ImageRectSize": [CELL, CELL], "source": f"Rhos Vectors/{folder}/{name}"}
        lines.append(f'\t["{key}"] = {{ {x}, {y}, {CELL}, {CELL} }},')
    bleed(sheet).save(os.path.join(OUT, "AST-091_ui_icons.png"))
    with open(os.path.join(OUT, "AST-091_ui_icons.json"), "w", encoding="utf-8") as f:
        json.dump({"image": "AST-091_ui_icons.png", "cell": CELL, "icons": meta,
                   "license": "RhosGFX Vector Icon Pack: use in this game only, never resell or redistribute"},
                  f, indent=2)
    studs().save(os.path.join(OUT, "AST-091_studs.png"))
    print("\n".join(sorted(lines)))


if __name__ == "__main__":
    main()
