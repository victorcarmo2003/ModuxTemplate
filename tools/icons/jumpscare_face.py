"""Jumpscare face (DEC-256, TASK-329): an all-black face with white eyes and a macabre grin; cartoon, Mild, no gore.

Full-bleed 1024x1024 PNG with transparent corners, drawn as one sticker (Ink outline, two-tone shading, gloss) so it
reads at a glance when it fills the screen for ~0.6 s (Effects/Kit/Jumpscare.luau).

    python tools/icons/jumpscare_face.py        # writes Assets/textures/ui/fx/jumpscare_face.png (+ .svg)
"""
from __future__ import annotations

import math
from pathlib import Path

from playwright.sync_api import sync_playwright

from shop_icons import INK, PAGE, WHITE, Icon, gloss, ol

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Assets" / "textures" / "ui" / "fx"


def spiky_head(cx: float, cy: float, r: float, spikes: int, depth: float) -> str:
    """Furry head outline: a circle with soft spikes."""
    pts = []
    for i in range(spikes * 2):
        a = math.pi * i / spikes - math.pi / 2
        rr = r + (depth if i % 2 == 0 else 0)
        pts.append(f"{cx + rr * math.cos(a):.1f},{cy + rr * math.sin(a):.1f}")
    return " ".join(pts)


def face(ic: Icon) -> str:
    """TASK-329 (owner 2026-10-15): an all-black face, glowing white eyes and a wide macabre grin. Cartoon, Mild."""
    ic.defs.append(
        '<radialGradient id="head" cx="50%" cy="40%" r="60%">'
        '<stop offset="0" stop-color="#1C1424"/><stop offset="1" stop-color="#050307"/></radialGradient>'
        '<filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="14"/></filter>'
        '<filter id="soft" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="6"/></filter>'
    )
    # head: a black hood-like blob, rounded top, soft wavy bottom (no hard zigzag)
    head = (
        "M150,520 Q150,90 512,80 Q874,90 874,520 L874,860 "
        "Q812,960 750,880 Q690,970 630,890 Q570,975 512,895 Q454,975 394,890 Q334,970 274,880 Q212,960 150,860 Z"
    )
    # eyes: slanted almonds, pure white, with a soft glow behind
    left_eye = "M300,420 Q370,350 455,410 Q385,455 300,420 Z"
    right_eye = "M724,420 Q654,350 569,410 Q639,455 724,420 Z"
    # grin: a crescent from cheek to cheek, corners curling up
    grin = "M232,560 Q512,700 792,560 Q770,640 740,610 Q512,870 284,610 Q254,640 232,560 Z"
    teeth = "".join(
        f'<path d="M{x},{595 + 0.0009 * (x - 512) ** 2 * 1.0:.0f} L{x},{820 - 0.0021 * (x - 512) ** 2:.0f}" '
        f'stroke="#0B0710" stroke-width="7" stroke-linecap="round"/>'
        for x in range(300, 740, 34)
    )
    gum_line = '<path d="M262,600 Q512,720 762,600" fill="none" stroke="#0B0710" stroke-width="8" stroke-linecap="round"/>'
    return (
        f'<path d="{head}" fill="url(#head)"/>'
        # eye glow, then the eyes
        + f'<path d="{left_eye}" fill="{WHITE}" opacity="0.55" filter="url(#glow)"/>'
        + f'<path d="{right_eye}" fill="{WHITE}" opacity="0.55" filter="url(#glow)"/>'
        + f'<path d="{left_eye}" fill="{WHITE}"/><path d="{right_eye}" fill="{WHITE}"/>'
        # grin glow, grin, teeth
        + f'<path d="{grin}" fill="{WHITE}" opacity="0.35" filter="url(#soft)"/>'
        + f'<path d="{grin}" fill="#F4F0FA"/>'
        + f'<g clip-path="url(#grinclip)">{teeth}{gum_line}</g>'
    ), grin


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    ic = Icon()
    body, grin = face(ic)
    ic.defs.append(f'<clipPath id="grinclip"><path d="{grin}"/></clipPath>')
    svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">'
        f'<defs>{"".join(ic.defs)}</defs>{body}</svg>'
    )
    (OUT / "jumpscare_face.svg").write_text(svg, encoding="utf-8")
    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        page = browser.new_page(viewport={"width": 1024, "height": 1024})
        page.set_content(PAGE.format(svg=svg) if "{svg}" in PAGE else PAGE.replace("{body}", body))
        page.wait_for_timeout(150)
        page.screenshot(path=str(OUT / "jumpscare_face.png"), clip={"x": 0, "y": 0, "width": 1024, "height": 1024}, omit_background=True)
        browser.close()
    print(OUT / "jumpscare_face.png")


if __name__ == "__main__":
    main()
