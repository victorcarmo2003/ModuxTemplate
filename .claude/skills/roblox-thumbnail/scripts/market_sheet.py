"""market_sheet.py - pull the current top Roblox thumbnails/icons and build genre contact sheets + metrics.

  python market_sheet.py --out ./market [--genre Survival] [--search "DOORS" "Adopt Me" ...] [--limit 160]

Uses only public endpoints (no login):
  games.roblox.com/v1/games?universeIds=        -> name, genre_l1/l2, playing
  thumbnails.roblox.com/v1/games/icons           -> 512 icon
  thumbnails.roblox.com/v1/games/multiget/thumbnails -> 768x432 thumbnails
  apis.roblox.com/search-api/omni-search         -> universeId by name

Universe ids for the charts come from a JSON you export from the browser (see references/market-study.md,
"Refreshing the study") or from --search names. Output: <out>/sheet_<genre>_icons.png, sheet_<genre>_thumbs.png,
<out>/stats.json (per-image metrics) and a printed genre table you can paste into the study.
"""
from __future__ import annotations

import argparse
import concurrent.futures as cf
import json
import os
import statistics as st
import sys
import urllib.parse
import urllib.request
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

UA = {"User-Agent": "Mozilla/5.0", "Accept": "application/json"}


def get(url):
    return json.load(urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30))


def search_ids(names):
    ids = {}
    for q in names:
        try:
            r = get("https://apis.roblox.com/search-api/omni-search?searchQuery=" + urllib.parse.quote(q) + "&sessionId=1&pageType=all")
            for grp in r.get("searchResults", []):
                for it in grp.get("contents", []):
                    if it.get("universeId"):
                        ids[str(it["universeId"])] = it.get("name")
                        break
                if ids:
                    break
        except Exception as e:
            print("search err", q, str(e)[:80])
    return ids


def fetch(ids, out: Path):
    meta, icons, thumbs = {}, {}, {}
    for i in range(0, len(ids), 50):
        b = ids[i:i + 50]
        for g in get("https://games.roblox.com/v1/games?universeIds=" + ",".join(b))["data"]:
            meta[str(g["id"])] = {"name": g["name"], "genre": g.get("genre_l1") or g.get("genre"), "sub": g.get("genre_l2"), "playing": g.get("playing")}
        for d in get("https://thumbnails.roblox.com/v1/games/icons?universeIds=" + ",".join(b) + "&size=512x512&format=Png&isCircular=false")["data"]:
            icons[str(d["targetId"])] = d.get("imageUrl")
        for d in get("https://thumbnails.roblox.com/v1/games/multiget/thumbnails?universeIds=" + ",".join(b) + "&countPerUniverse=3&defaults=true&size=768x432&format=Png")["data"]:
            thumbs[str(d["universeId"])] = [t.get("imageUrl") for t in d.get("thumbnails", []) if t.get("imageUrl")]
    (out / "icons").mkdir(parents=True, exist_ok=True)
    (out / "thumbs").mkdir(parents=True, exist_ok=True)

    def dl(u, p):
        if u and not p.exists():
            try:
                p.write_bytes(urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=30).read())
            except Exception as e:
                print("dl err", p.name, e)

    jobs = [(icons.get(u), out / "icons" / f"{u}.png") for u in ids]
    for u in ids:
        for k, t in enumerate(thumbs.get(u, [])[:3]):
            jobs.append((t, out / "thumbs" / f"{u}_{k}.png"))
    with cf.ThreadPoolExecutor(16) as ex:
        list(ex.map(lambda j: dl(*j), jobs))
    return meta


def metrics(path: Path, kind):
    im = np.asarray(Image.open(path).convert("RGB").resize((384, 216) if kind == "thumb" else (256, 256))).astype(np.float32) / 255
    hsv = cv2.cvtColor((im * 255).astype(np.uint8), cv2.COLOR_RGB2HSV).astype(np.float32)
    L, S, H = im.mean(axis=2), hsv[..., 1] / 255, hsv[..., 0] * 2
    warm = (((H < 60) | (H > 320)) & (S > 0.35)).mean()
    cool = (((H > 170) & (H < 270)) & (S > 0.35)).mean()
    edges = cv2.Canny((L * 255).astype(np.uint8), 80, 160).mean() / 255
    return dict(dark=float((L < 0.2).mean()), bright=float((L > 0.8).mean()), contrast=float(L.std()), sat=float(S.mean()),
                warm=float(warm), cool=float(cool), edges=float(edges), band=float(L[int(L.shape[0] * 0.85):].mean()))


def sheet(items, kind, cols, w, h, path, font):
    rows = (len(items) + cols - 1) // cols
    S = Image.new("RGB", (cols * (w + 8) + 8, rows * (h + 28) + 8), (24, 24, 28))
    d = ImageDraw.Draw(S)
    for i, (p, label) in enumerate(items):
        r, c = divmod(i, cols)
        x, y = 8 + c * (w + 8), 8 + r * (h + 28)
        if p.exists():
            S.paste(Image.open(p).convert("RGB").resize((w, h), Image.LANCZOS), (x, y))
        d.text((x, y + h + 4), f"{i + 1}. {label[:30]}", fill=(230, 230, 230), font=font)
    S.save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="market")
    ap.add_argument("--ids", help="JSON file: {universeId: anything} (e.g. exported from roblox.com/charts)")
    ap.add_argument("--search", nargs="*", default=[])
    ap.add_argument("--genre")
    ap.add_argument("--limit", type=int, default=160)
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    ids = {}
    if a.ids:
        ids.update({str(k): v for k, v in json.load(open(a.ids, encoding="utf-8")).items()})
    ids.update(search_ids(a.search))
    ids = list(ids.keys())[:a.limit]
    if not ids:
        print("no ids: pass --ids charts.json and/or --search names")
        return
    meta = fetch(ids, out)
    try:
        font = ImageFont.truetype("arial.ttf", 15)
    except OSError:
        font = ImageFont.load_default()
    groups = {}
    for u in ids:
        groups.setdefault(meta.get(u, {}).get("genre") or "?", []).append(u)
    rows = []
    for g, us in groups.items():
        if a.genre and g != a.genre:
            continue
        tag = g.replace(" ", "_").replace("&", "and")
        sheet([(out / "icons" / f"{u}.png", meta[u]["name"]) for u in us[:32]], "icon", 8, 150, 150, out / f"sheet_{tag}_icons.png", font)
        sheet([(out / "thumbs" / f"{u}_0.png", meta[u]["name"]) for u in us[:24]], "thumb", 4, 320, 180, out / f"sheet_{tag}_thumbs.png", font)
        for u in us:
            for kind, p in (("icon", out / "icons" / f"{u}.png"), ("thumb", out / "thumbs" / f"{u}_0.png")):
                if p.exists():
                    rows.append({"genre": g, "name": meta[u]["name"], "kind": kind, **metrics(p, kind)})
    json.dump(rows, open(out / "stats.json", "w", encoding="utf-8"), ensure_ascii=False)
    print(f"{'genre':28} n   dark  bright contr  sat  warm  cool  edges")
    for g in sorted(groups):
        sel = [r for r in rows if r["kind"] == "thumb" and r["genre"] == g]
        if sel:
            f = lambda k: f"{st.mean(r[k] for r in sel):.2f}"
            print(f"{g:28} {len(sel):3} {f('dark')}  {f('bright')}   {f('contrast')}  {f('sat')} {f('warm')}  {f('cool')}  {f('edges')}")
    print("sheets in", out)


if __name__ == "__main__":
    main()
