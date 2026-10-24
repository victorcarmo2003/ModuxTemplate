#!/usr/bin/env python3
"""Rank Roblox fonts against a text crop of the reference. Stops "close enough" font guessing.

  python font_match.py ref.jpg --crop 895,425,150,155 --text 25
  python font_match.py ref.jpg --crop 60,30,200,60 --text "UI STYLE GUIDE" --families "Oswald,Roboto Condensed,Titillium Web"
  python font_match.py ref.jpg --crop ... --text 120 --dark-text      # dark text on light background

The crop must contain only the text (a few px margin is fine). Every candidate (family x weight x italic) is
rendered, scaled so its ink height equals the reference ink height, aligned and scored:
  score = 0.6 * shape IoU (2 px tolerance) + 0.4 * (1 - width error)
Prints the ranking, the TextSize that reproduces the reference cap height, and writes font_match.png
(reference on top, best 6 candidates below). Uses Roblox local font files + Google Fonts twins (roblox_fonts.py).
"""
from __future__ import annotations

import argparse
import io
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from playwright.sync_api import sync_playwright
from scipy.ndimage import binary_dilation

import roblox_fonts as RF

DEFAULT_FAMILIES = ["Roboto Condensed", "Oswald", "Titillium Web", "Roboto", "Jura", "Michroma", "Sarpanch",
                    "Builder Sans", "Builder Mono", "Roboto Mono", "Zekton", "Source Sans Pro", "Montserrat",
                    "Ubuntu", "Arimo", "Highway Gothic", "Guru"]
RENDER_PX = 200


def ink(mask: np.ndarray) -> tuple[int, int, int, int] | None:
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        return None
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def binarize(img: Image.Image, dark_text: bool) -> np.ndarray:
    g = np.asarray(img.convert("L"), dtype=np.float32)
    if dark_text:
        g = 255 - g
    thr = (np.percentile(g, 5) + np.percentile(g, 99.5)) / 2  # midpoint between background and ink
    return g > thr


def candidates(fams: dict, wanted: list[str]) -> list[tuple[str, int, str]]:
    out = []
    for name in wanted:
        stem = next((s for s, f in fams.items() if name in (s, f["name"])), None)
        if stem is None:
            continue
        fam = fams[stem]
        g = RF.GOOGLE.get(stem)
        for face in fam["faces"]:
            local = face["assetId"].startswith("rbxasset://")
            reachable = local or (g is not None and (g in RF.WEIGHTS and str(face["weight"]) in RF.WEIGHTS[g]
                                                     or face["weight"] == 400))
            if reachable:
                out.append((fam["name"], face["weight"], face["style"]))
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("image")
    ap.add_argument("--crop", required=True, help="x,y,w,h around the text")
    ap.add_argument("--text", required=True)
    ap.add_argument("--families", help="comma list; default: sci-fi/UI friendly Roblox families")
    ap.add_argument("--dark-text", action="store_true")
    ap.add_argument("--uppercase", action="store_true")
    ap.add_argument("-o", "--out", default="font_match.png")
    a = ap.parse_args()

    x, y, w, h = map(int, a.crop.split(","))
    ref_img = Image.open(a.image).convert("RGB").crop((x, y, x + w, y + h))
    rmask = binarize(ref_img, a.dark_text)
    rb = ink(rmask)
    if rb is None:
        raise SystemExit("no ink found in crop; check --crop / --dark-text")
    rmask = rmask[rb[1]:rb[3], rb[0]:rb[2]]
    RH, RW = rmask.shape
    text = a.text.upper() if a.uppercase else a.text

    fd = RF.fonts_dir()
    fams = RF.families(fd) if fd else {}
    wanted = [s.strip() for s in a.families.split(",")] if a.families else DEFAULT_FAMILIES
    cands = candidates(fams, wanted)
    style = RF_css(fams, wanted)

    results = []
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={"width": 1600, "height": 400})
        spans = "".join(
            f'<div class="c" style="font-family:\'{f}\';font-weight:{wt};font-style:{st}">{text}</div>'
            for f, wt, st in cands)
        html = (f"<html><head>{style}<style>body{{margin:0;background:#000}}"
                         f".c{{color:#fff;font-size:{RENDER_PX}px;line-height:1.3;white-space:nowrap;"
                         f"padding:10px 20px;width:max-content}}</style></head><body>{spans}</body></html>")
        # file:// page: from about:blank (set_content) Chromium blocks the local Roblox font files -> silent fallback
        tmp = Path(a.out).resolve().with_suffix(".fontmatch.html")
        tmp.write_text(html, encoding="utf-8")
        page.goto(tmp.as_uri())
        page.wait_for_load_state("networkidle")
        page.evaluate("document.fonts.ready")
        page.wait_for_timeout(300)
        loaded = page.evaluate("[...document.fonts].filter(f => f.status === 'loaded').map(f => f.family)")
        # Roblox fits ascent+descent into TextSize; an inline span's content box at 100px measures that ratio
        ratios = page.evaluate("""(c) => c.map(([f, w, st]) => {
            const s = document.createElement('span');
            s.style.cssText = `font-family:'${f}';font-weight:${w};font-style:${st};font-size:100px;line-height:normal`;
            s.textContent = 'Hg'; document.body.appendChild(s);
            const h = s.getBoundingClientRect().height; s.remove(); return h / 100; })""", [list(c) for c in cands])
        for i, (f, wt, st) in enumerate(cands):
            png = page.locator(".c").nth(i).screenshot()
            cm = binarize(Image.open(io.BytesIO(png)).convert("RGB"), False)
            cb = ink(cm)
            if cb is None:
                continue
            cm = cm[cb[1]:cb[3], cb[0]:cb[2]]
            ch = cm.shape[0]
            k = RH / ch
            scaled = Image.fromarray((cm * 255).astype("uint8")).resize(
                (max(1, round(cm.shape[1] * k)), RH), Image.BILINEAR)
            sm = np.asarray(scaled) > 127
            width_err = abs(sm.shape[1] - RW) / RW
            Wc = max(sm.shape[1], RW)
            A = np.zeros((RH, Wc), bool)
            B = np.zeros((RH, Wc), bool)
            A[:, :RW] = rmask
            B[:, :sm.shape[1]] = sm
            da, db = binary_dilation(A, iterations=2), binary_dilation(B, iterations=2)
            iou = ((A & db).sum() + (B & da).sum()) / max(1, A.sum() + B.sum())
            score = 0.6 * iou + 0.4 * max(0.0, 1 - width_err)
            results.append((score, iou, width_err, f, wt, st, round(RENDER_PX * k * ratios[i]), sm))
        browser.close()
        tmp.unlink(missing_ok=True)

    results.sort(key=lambda r: r[0], reverse=True)
    missing = sorted({f for _, _, _, f, *_ in results} - {x.strip("'\"") for x in loaded})
    if missing:
        print("note: not confirmed loaded (may be a fallback face, offline?):", ", ".join(missing))
    print(f"reference ink {RW}x{RH}px, text {text!r}")
    print(f"{'score':>6} {'shape':>6} {'width':>6}  font")
    for s, iou, we, f, wt, st, size, _ in results[:12]:
        print(f"{s:6.3f} {iou:6.3f} {we:+6.1%}  {f} {wt}{' italic' if st == 'italic' else ''}  -> TextSize ~{size}")
    if results:
        s, _, _, f, wt, st, size, _ = results[0]
        enum = {100: "Thin", 200: "ExtraLight", 300: "Light", 400: "Regular", 500: "Medium", 600: "SemiBold",
                700: "Bold", 800: "ExtraBold", 900: "Heavy"}[wt]
        stem = next(sm for sm, fm in fams.items() if fm["name"] == f)
        print(f'\nFontFace = Font.new("rbxasset://fonts/families/{stem}.json", Enum.FontWeight.{enum}'
              f'{", Enum.FontStyle.Italic" if st == "italic" else ""}),')
        print(f"-- Roblox TextSize ~{size} (= line box; Roblox fits ascent+descent into TextSize, unlike CSS em).")
        print(f"-- TextLabel height >= {size}. TextSize caps at 100: above it use TextSize {size}/k + UIScale k.")

    # board
    top = Image.fromarray((rmask * 255).astype("uint8"))
    rows = [("REFERENCE", top)] + [(f"{r[3]} {r[4]}{' i' if r[5] == 'italic' else ''}  {r[0]:.3f}",
                                    Image.fromarray((r[7] * 255).astype("uint8"))) for r in results[:6]]
    bw = max(im.width for _, im in rows) + 260
    board = Image.new("L", (bw, sum(im.height + 12 for _, im in rows)), 20)
    d = ImageDraw.Draw(board)
    yy = 0
    for label, im in rows:
        board.paste(im, (250, yy + 6))
        d.text((6, yy + 6), label, fill=255)
        yy += im.height + 12
    board.save(a.out)
    print("wrote", a.out)
    return 0


def RF_css(fams: dict, wanted: list[str]) -> str:
    """Same CSS roblox_fonts.py prints, built in-process."""
    import subprocess
    import sys
    script = Path(__file__).with_name("roblox_fonts.py")
    return subprocess.run([sys.executable, str(script), *wanted], capture_output=True, text=True).stdout.strip()


if __name__ == "__main__":
    raise SystemExit(main())
