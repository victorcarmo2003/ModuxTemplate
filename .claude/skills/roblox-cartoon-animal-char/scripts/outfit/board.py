import json, sys, os
from PIL import Image, ImageDraw, ImageFont
SP = sys.argv[1]
tiles = json.load(open(SP + "/previews/crewtex/tiles.json"))
TW, TH = 330, 440
labels = []
for l, v, p in tiles:
    if l not in labels: labels.append(l)
W = TW * len(labels); H = 60 + TH * 2
out = Image.new("RGB", (W, H), (28, 32, 44))
d = ImageDraw.Draw(out)
try: f = ImageFont.truetype("arialbd.ttf", 20); fs = ImageFont.truetype("arial.ttf", 15)
except Exception: f = fs = ImageFont.load_default()
d.text((12, 6), "AST-053 CrewTex - corpo base vestido (pelo = MeshPart.Color: crew cao caramelo, civil A gato cinza, civil B raposa)", fill=(235, 235, 240), font=fs)
for l, v, p in tiles:
    c = labels.index(l); r = 0 if v == "front" else 1
    im = Image.open(p).convert("RGB"); im = im.resize((TW, int(im.height * TW / im.width)))
    im = im.crop((0, (im.height - TH) // 2, TW, (im.height - TH) // 2 + TH))
    out.paste(im, (c * TW, 60 + r * TH))
    if r == 0: d.text((c * TW + 10, 32), l, fill=(255, 220, 160) if "dia" in l else (160, 190, 255), font=f)
out.save(SP + "/previews/AST-053_CrewTex_board.png")
cl = [SP + f"/previews/crewtex/close{i}_{v}.png" for v in ("face", "back") for i in (0, 1)]
ims = [Image.open(p).convert("RGB").resize((450, 600)) for p in cl]
o2 = Image.new("RGB", (1800, 600))
for i, im in enumerate(ims): o2.paste(im, (450 * i, 0))
o2.save(SP + "/previews/AST-053_CrewTex_close.png")
