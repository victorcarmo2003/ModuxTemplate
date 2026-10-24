"""Approval board: python board.py rows.json out.png "Title" [--thumbs <dir>]
rows.json: [{"ast": "AST-001", "name": "Bun", "fit": "direct|edit|model", "note": "...", "thumbs": ["key1", ...]}, ...]
thumbs resolve to <dir>/<key>.png (default: ./thumbs, as written by scripts/blender/thumbs.py).
One row per sheet: colour bar (green direct / yellow edit / red model) + label + note + candidate thumbnails."""
import json, os, sys, textwrap
from PIL import Image, ImageDraw, ImageFont
F = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 13)
FB = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', 15)

HERE = os.path.dirname(os.path.abspath(__file__))
TH = sys.argv[sys.argv.index("--thumbs") + 1] if "--thumbs" in sys.argv else os.path.join(os.getcwd(), "thumbs")
rows = json.load(open(sys.argv[1], encoding="utf-8"))
out, title = sys.argv[2], sys.argv[3]
T, LW, PAD = 200, 300, 8
FIT = {"direct": (90, 200, 110), "edit": (240, 190, 60), "model": (220, 90, 90)}
maxn = max(1, max(len(r["thumbs"]) for r in rows))
W = LW + maxn * (T + PAD) + PAD
H = 40 + len(rows) * (T + PAD)
img = Image.new("RGB", (W, H), (32, 34, 38))
d = ImageDraw.Draw(img)
d.text((PAD, 10), title, fill=(255, 255, 255), font=FB)
for i, r in enumerate(rows):
    y = 40 + i * (T + PAD)
    d.rectangle([PAD, y, LW - PAD, y + T], fill=(44, 47, 53))
    d.rectangle([PAD, y, PAD + 6, y + T], fill=FIT.get(r.get("fit"), (150, 150, 150)))
    lines = [f'{r["ast"]}  {r["name"]}', f'[{r.get("fit", "?")}]'] + textwrap.wrap(r.get("note", ""), 40)
    for k, line in enumerate(lines[:11]):
        d.text((PAD + 14, y + 8 + k * 16), line, fill=(255, 220, 0) if k == 0 else (220, 220, 220), font=FB if k == 0 else F)
    for j, key in enumerate(r["thumbs"]):
        x = LW + j * (T + PAD)
        d.rectangle([x, y, x + T, y + T], fill=(190, 196, 204))
        p = os.path.join(TH, key + ".png")
        if os.path.exists(p):
            t = Image.open(p).convert("RGBA").resize((T, T - 18), Image.LANCZOS)
            img.paste(t, (x, y), t)
        d.text((x + 4, y + T - 16), key[:30], fill=(20, 20, 20), font=F)
img.save(out)
print(out, img.size)
