#!/usr/bin/env python3
"""Detail pass: per-element zoomed side-by-side of reference vs capture (or mockup), one tile per element.

Whole-HUD scores hide small mistakes (a missing 2 px stem that makes an icon unreadable, a dot 1.5 px off
center, square corners where the reference is rounded). This board puts every element under a magnifier.

  python detail_board.py ref.jpg capture.png --layout out/layout.json -o details.png
  python detail_board.py ref.jpg mock.png --layout out/layout.json --only "asset-*" --zoom 5
  python detail_board.py ref.jpg cap.png --box "drone:1085,470,200,160" --box "battery:605,585,65,115"

Boxes are in reference pixels; the candidate is resized to the reference size (capture = cropped stage). Each tile:
reference | candidate | 50% overlay, magnified with nearest-neighbour + a 10 px grid labelled in full-image px.
Read each tile against the DETAIL CHECKLIST in references/verification.md.
"""
from __future__ import annotations

import argparse
import fnmatch
import json

from PIL import Image, ImageDraw

PAD = 8


def norm(path: str, size: tuple[int, int] | None = None) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    bg = Image.new("RGBA", im.size, (90, 95, 100, 255))
    bg.alpha_composite(im)
    im = bg.convert("RGB")
    return im if size is None or im.size == size else im.resize(size, Image.LANCZOS)


def tile(ref: Image.Image, cand: Image.Image, box: tuple[int, int, int, int], zoom: int, label: str) -> Image.Image:
    x, y, w, h = box
    crop = (x, y, x + w, y + h)
    parts = [ref.crop(crop), cand.crop(crop)]
    parts.append(Image.blend(parts[0], parts[1], 0.5))
    W, H = w * zoom, h * zoom
    out = Image.new("RGB", (W * 3 + PAD * 2, H + 22), (25, 25, 25))
    d = ImageDraw.Draw(out)
    d.text((4, 4), f"{label}   box {x},{y},{w},{h}   ref | candidate | overlay", fill=(255, 255, 0))
    for i, p in enumerate(parts):
        big = p.resize((W, H), Image.NEAREST)
        g = ImageDraw.Draw(big)
        for gx in range((10 - x % 10) % 10, w + 1, 10):
            g.line([(gx * zoom, 0), (gx * zoom, H)], fill=(255, 0, 255) if (x + gx) % 50 == 0 else (90, 40, 90))
        for gy in range((10 - y % 10) % 10, h + 1, 10):
            g.line([(0, gy * zoom), (W, gy * zoom)], fill=(0, 255, 255) if (y + gy) % 50 == 0 else (30, 80, 80))
        out.paste(big, (i * (W + PAD), 22))
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("ref")
    ap.add_argument("cand")
    ap.add_argument("--layout", help="layout.json from export_layers.py (uses item boxes)")
    ap.add_argument("--only", action="append", default=[], help="fnmatch on item id (default: asset-* and text-*)")
    ap.add_argument("--box", action="append", default=[], help="name:x,y,w,h (extra/manual boxes)")
    ap.add_argument("--zoom", type=int, default=4)
    ap.add_argument("--margin", type=int, default=6, help="px added around each layout box")
    ap.add_argument("--max-width", type=int, default=1800, help="downscale tiles wider than this")
    ap.add_argument("-o", "--out", default="details.png")
    a = ap.parse_args()

    ref = norm(a.ref)
    cand = norm(a.cand, ref.size)  # boxes are in reference pixels; the candidate is resized to match
    boxes: list[tuple[str, tuple[int, int, int, int]]] = []
    if a.layout:
        pats = a.only or ["asset-*", "text-*"]
        for it in json.load(open(a.layout, encoding="utf-8"))["items"]:
            if any(fnmatch.fnmatch(it["id"], p) for p in pats):
                x, y, w, h = it["box"]
                m = a.margin
                boxes.append((it["id"], (int(x - m), int(y - m), int(w + 2 * m), int(h + 2 * m))))
    for b in a.box:
        name, rest = b.split(":", 1)
        boxes.append((name, tuple(int(v) for v in rest.split(","))))  # type: ignore[arg-type]
    if not boxes:
        raise SystemExit("no boxes: pass --layout and/or --box")

    tiles = []
    for name, box in boxes:
        t = tile(ref, cand, box, a.zoom, name)
        if t.width > a.max_width:
            k = a.max_width / t.width
            t = t.resize((a.max_width, int(t.height * k)), Image.NEAREST)
        tiles.append(t)
    W = max(t.width for t in tiles)
    board = Image.new("RGB", (W, sum(t.height + 10 for t in tiles)), (12, 12, 12))
    y = 0
    for t in tiles:
        board.paste(t, (0, y))
        y += t.height + 10
    board.save(a.out)
    print(f"wrote {a.out} ({len(tiles)} tiles)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
