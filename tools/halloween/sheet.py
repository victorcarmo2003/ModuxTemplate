"""Contact sheet of kit renders: python sheet.py out.png file1.png file2.png ... (3 per row: front/side/q34)."""
import sys
from PIL import Image, ImageDraw
out, files = sys.argv[1], sys.argv[2:]
W = 240
rows = [files[i:i + 3] for i in range(0, len(files), 3)]
img = Image.new("RGB", (W * 3, (W + 16) * len(rows)), (30, 28, 40))
d = ImageDraw.Draw(img)
for r, row in enumerate(rows):
    for c, f in enumerate(row):
        im = Image.open(f).convert("RGB").resize((W, W))
        img.paste(im, (c * W, r * (W + 16) + 16))
    d.text((4, r * (W + 16) + 2), row[0].split("/")[-1].rsplit("_", 1)[0], fill=(240, 230, 200))
img.save(out)
