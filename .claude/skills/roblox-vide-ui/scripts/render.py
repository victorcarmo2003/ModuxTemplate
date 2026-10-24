#!/usr/bin/env python3
"""Render an SVG (or HTML) mockup to PNG with headless Chromium (Playwright).

  python render.py mock.svg -o mock.png                      # transparent background, native size
  python render.py mock.svg -o mock.png --scale 2            # 2x
  python render.py mock.svg -o over.png --bg ref.jpg --opacity 0.55   # mockup over the reference (alignment check)
  python render.py mock.svg -o mock.png --hide guide          # hide elements whose id starts with "guide"

Fonts: the mockup may use @font-face with a local file url (file:///C:/.../Font.ttf) or any font installed on
the machine. Use the same family you will use in Roblox (see references/roblox-ui-fundamentals.md, Fonts).
"""
from __future__ import annotations

import argparse
import base64
import re
from pathlib import Path

from playwright.sync_api import sync_playwright


def svg_size(text: str) -> tuple[int, int]:
    m = re.search(r'viewBox="\s*[-\d.]+\s+[-\d.]+\s+([\d.]+)\s+([\d.]+)', text)
    if m:
        return int(float(m.group(1))), int(float(m.group(2)))
    w = re.search(r'<svg[^>]*\bwidth="([\d.]+)', text)
    h = re.search(r'<svg[^>]*\bheight="([\d.]+)', text)
    return (int(float(w.group(1))) if w else 1920, int(float(h.group(1))) if h else 1080)


def page_html(src: Path, bg: Path | None, opacity: float, hide: list[str]) -> tuple[str, int, int]:
    text = src.read_text(encoding="utf-8")
    if src.suffix.lower() == ".html":
        return text, 1920, 1080
    w, h = svg_size(text)
    bg_css = ""
    if bg is not None:
        mime = "image/png" if bg.suffix.lower() == ".png" else "image/jpeg"
        data = base64.b64encode(bg.read_bytes()).decode()
        bg_css = f"background:url(data:{mime};base64,{data}) 0 0/{w}px {h}px no-repeat;"
    hide_css = "".join(f'[id^="{p}"]{{display:none!important}}' for p in hide)
    svg_op = f"opacity:{opacity};" if bg is not None else ""
    html = (f"<!doctype html><html><head><meta charset='utf-8'><style>html,body{{margin:0;background:transparent}}"
            f"#stage{{width:{w}px;height:{h}px;{bg_css}}}#stage>svg{{display:block;{svg_op}}}{hide_css}</style>"
            f"</head><body><div id='stage'>{text}</div></body></html>")
    return html, w, h


def render(src: Path, out: Path, scale: float = 1, bg: Path | None = None, opacity: float = 0.55,
           hide: list[str] | None = None) -> Path:
    html, w, h = page_html(src, bg, opacity, hide or [])
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={"width": w, "height": h}, device_scale_factor=scale)
        # file:// base so relative font/image urls inside the mockup resolve next to it
        tmp = src.with_suffix(".render.html")
        tmp.write_text(html, encoding="utf-8")
        try:
            page.goto(tmp.resolve().as_uri())
            page.wait_for_timeout(150)
            page.locator("#stage" if src.suffix.lower() != ".html" else "body").screenshot(
                path=str(out), omit_background=True)
        finally:
            tmp.unlink(missing_ok=True)
            browser.close()
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("src", type=Path)
    ap.add_argument("-o", "--out", type=Path, required=True)
    ap.add_argument("--scale", type=float, default=1)
    ap.add_argument("--bg", type=Path, help="reference image drawn under the mockup")
    ap.add_argument("--opacity", type=float, default=0.55, help="mockup opacity when --bg is given")
    ap.add_argument("--hide", action="append", default=[], help="hide ids starting with this prefix (repeatable)")
    a = ap.parse_args()
    render(a.src, a.out, a.scale, a.bg, a.opacity, a.hide)
    print(f"wrote {a.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
