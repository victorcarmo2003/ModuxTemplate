"""Jumpscare face (DEC-256): a cartoon monster face, Mild, no gore, in the game's UI sticker style.

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
    fur = ic.two("#8E78D6", "#5B47A3", 0.58)
    mouth = ic.soft("#3A1F3F", "#1E0F22")
    tongue = ic.two("#FF9DBA", "#E06E92", 0.55)
    eye = ic.two("#FFFFFF", "#E6E2F2", 0.6)
    horn = ic.two("#FFE07A", "#E9A81C", 0.55)
    # mouth: a wide grin below the eyes; teeth hang from its top edge and rise from its bottom edge
    mouth_path = "M280,610 Q512,560 744,610 Q770,820 512,870 Q254,820 280,610 Z"
    teeth_top = "".join(
        f'<path d="M{x},{596 + abs(x - 512) * 0.06:.0f} L{x + 26},{668 + abs(x - 512) * 0.05:.0f} L{x + 52},{596 + abs(x - 512) * 0.06:.0f} Z" '
        f'fill="{WHITE}" {ol(8)}/>'
        for x in range(316, 690, 52)
    )
    teeth_bottom = "".join(
        f'<path d="M{x},{842 - abs(x - 492) * 0.12:.0f} L{x + 20},{790 - abs(x - 492) * 0.1:.0f} L{x + 40},{842 - abs(x - 492) * 0.12:.0f} Z" '
        f'fill="{WHITE}" {ol(7)}/>'
        for x in (392, 452, 532, 592)
    )
    return (
        # horns
        f'<path d="M300,250 Q230,120 270,40 Q330,140 390,215 Z" fill="{horn}" {ol(18)}/>'
        f'<path d="M724,250 Q794,120 754,40 Q694,140 634,215 Z" fill="{horn}" {ol(18)}/>'
        # furry head
        f'<polygon points="{spiky_head(512, 540, 410, 26, 34)}" fill="{fur}" {ol(22)} stroke-linejoin="round"/>'
        # angry brows
        f'<path d="M260,268 L450,330" {ol(34)}/><path d="M764,268 L574,330" {ol(34)}/>'
        # eyes, huge, tiny pupils
        f'<ellipse cx="375" cy="430" rx="96" ry="108" fill="{eye}" {ol(16)}/>'
        f'<ellipse cx="649" cy="430" rx="96" ry="108" fill="{eye}" {ol(16)}/>'
        f'<circle cx="392" cy="450" r="24" fill="{INK}"/><circle cx="632" cy="450" r="24" fill="{INK}"/>'
        + gloss(335, 375, 24, 13, -25, 0.9)
        + gloss(609, 375, 24, 13, -25, 0.9)
        # gaping mouth, tongue, teeth
        + f'<path d="{mouth_path}" fill="{mouth}" {ol(20)}/>'
        + f'<ellipse cx="512" cy="815" rx="130" ry="48" fill="{tongue}" {ol(10)}/>'
        + teeth_top
        + teeth_bottom
        + f'<path d="{mouth_path}" fill="none" {ol(20)}/>'
        # gloss on the fur
        + gloss(250, 600, 40, 18, -40, 0.35)
    )


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    ic = Icon()
    body = face(ic)
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
