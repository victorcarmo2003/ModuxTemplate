"""Sunburst rays texture for the shop menus (owner request 2026-10-15): the alternating rays of the retro icon tiles,
as a white 1024x1024 PNG with alpha (tinted and faded in Roblox with ImageColor3 / ImageTransparency) that fades out
towards a circle, so a square ImageLabel can spin behind the cards without its corners showing.

    python tools/icons/fx_sunburst.py            # writes Assets/textures/ui/fx/sunburst.png (+ .svg source)
"""
from __future__ import annotations

import math
from pathlib import Path

from playwright.sync_api import sync_playwright

from shop_icons import PAGE

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Assets" / "textures" / "ui" / "fx"
SIZE = 1024
RAYS = 16  # same count as the icon tiles (shop_icons.RAYS)


def svg() -> str:
    c = SIZE / 2
    wedges = []
    step = 360 / RAYS
    for i in range(0, RAYS, 2):
        a0, a1 = math.radians(-90 + i * step), math.radians(-90 + (i + 1) * step)
        wedges.append(
            f'<path d="M{c},{c} L{c + c * 1.5 * math.cos(a0):.1f},{c + c * 1.5 * math.sin(a0):.1f} '
            f'L{c + c * 1.5 * math.cos(a1):.1f},{c + c * 1.5 * math.sin(a1):.1f} Z" fill="#FFFFFF"/>'
        )
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">'
        '<defs><radialGradient id="fade" cx="0.5" cy="0.5" r="0.5">'
        '<stop offset="0" stop-color="#fff" stop-opacity="1"/><stop offset="0.7" stop-color="#fff" stop-opacity="0.9"/>'
        '<stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>'
        f'<mask id="m"><rect width="{SIZE}" height="{SIZE}" fill="url(#fade)"/></mask></defs>'
        f'<g mask="url(#m)">{"".join(wedges)}</g></svg>'
    )


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    source = svg()
    (OUT / "sunburst.svg").write_text(source, encoding="utf-8")
    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        page = browser.new_page(viewport={"width": SIZE, "height": SIZE})
        page.set_content(PAGE.format(svg=source))
        page.wait_for_timeout(150)
        page.screenshot(path=str(OUT / "sunburst.png"), clip={"x": 0, "y": 0, "width": SIZE, "height": SIZE}, omit_background=True)
        browser.close()
    print(OUT / "sunburst.png")


if __name__ == "__main__":
    main()
