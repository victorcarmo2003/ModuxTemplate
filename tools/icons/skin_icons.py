"""Class skin icons (AST-124; design/skins-proposal.md), 512x512 PNG, same language as shop_icons.py (round tile like the
class Game Passes, sticker animal head, Ink outline, Fredoka One). Each skin: the class animal in the skin's fur, the crew
cap recoloured to the skin with its emblem (or a themed hat), and a "LIMITED" ribbon for a limited skin.

    python tools/icons/skin_icons.py        # Assets/textures/ui/shop/<key>.png (+ .svg): Creator Hub product images
                                            # Assets/textures/ui/shop/art/<key>.png: no ribbon, for the skin circles

Reuses the class heads of shop_icons.py: the cap and the tile are swapped and the class fur colours replaced by the
skin's. The dog (the free class has no pass icon) is drawn here.
"""
from __future__ import annotations

from pathlib import Path

from playwright.sync_api import sync_playwright

import shop_icons as S
from shop_icons import CREAM, INK, MUSTARD, WHITE, Icon, face, gloss, ol, smile, text, w

OUT = S.OUT
ORIG_TILE = S.tile
ORIG_CAP = S.crew_cap

S.TONES.update({
    "night": ("#8C7BC9", "#4B3A7A", "#2E2350"),
    "pumpkin": ("#FFC27A", "#F08A28", "#A8560F"),
    "ghost": ("#E6ECFF", "#A9B4E0", "#6F79A8"),
    "moss": ("#B9E09A", "#6E9A55", "#47683A"),
    "wine": ("#C0587E", "#7A2148", "#4E1530"),
    "bone": ("#6A6278", "#3A3444", "#211C28"),
})


def ribbon() -> str:
    return (
        '<path d="M70,404 L442,404 L470,436 L442,468 L70,468 L42,436 Z" fill="#6A5ACD" '
        f'{ol()}/>' + text("LIMITED", 256, 452, 46, "#FFD86B")
    )


def emblem(kind: str, x: float, y: float, k: float) -> str:
    g = f'<g transform="translate({x} {y}) scale({k})">'
    if kind == "pumpkin":
        body = (
            f'<rect x="-5" y="-34" width="10" height="16" rx="3" fill="#467E3E" {ol(6)}/>'
            f'<ellipse cx="-14" cy="0" rx="20" ry="24" fill="#F28C28" {ol(6)}/>'
            f'<ellipse cx="14" cy="0" rx="20" ry="24" fill="#F28C28" {ol(6)}/>'
            f'<ellipse cx="0" cy="0" rx="20" ry="25" fill="#F79A3A" {ol(6)}/>'
            f'<path d="M-16,-6 L-6,-6 L-11,-16Z M6,-6 L16,-6 L11,-16Z" fill="{INK}"/>'
            f'<path d="M-16,4 Q0,20 16,4 L8,8 L0,4 L-8,8 Z" fill="{INK}"/>'
        )
    elif kind == "ghost":
        body = (
            f'<path d="M-22,24 L-22,-6 Q-22,-30 0,-30 Q22,-30 22,-6 L22,24 L13,16 L4,24 L-4,16 L-13,24 Z" fill="{WHITE}" {ol(6)}/>'
            f'<ellipse cx="-8" cy="-6" rx="4" ry="6" fill="{INK}"/><ellipse cx="8" cy="-6" rx="4" ry="6" fill="{INK}"/>'
            f'<ellipse cx="0" cy="8" rx="5" ry="6" fill="{INK}"/>'
        )
    elif kind == "moon":
        body = (
            f'<circle cx="-2" cy="0" r="24" fill="{MUSTARD}" {ol(6)}/><circle cx="12" cy="-10" r="22" fill="#4B3A7A"/>'
            f'<path d="M14,10 l4,9 l10,1 l-8,6 l3,10 l-9,-6 l-9,6 l3,-10 l-8,-6 l10,-1 Z" fill="{CREAM}"/>'
        )
    elif kind == "bolt":
        body = f'<path d="M-6,-30 L16,-30 L4,-6 L18,-6 L-10,32 L-2,4 L-16,4 Z" fill="{MUSTARD}" {ol(6)}/>'
    elif kind == "bat":
        body = (
            f'<path d="M-36,-2 L-24,-14 L-16,-4 L-8,-12 L0,-6 L8,-12 L16,-4 L24,-14 L36,-2 L26,4 L20,12 L12,6 L4,14 L0,8 '
            f'L-4,14 L-12,6 L-20,12 L-26,4 Z" fill="#3A3444" {ol(5)}/>'
            f'<circle cx="-4" cy="-4" r="2.6" fill="{MUSTARD}"/><circle cx="4" cy="-4" r="2.6" fill="{MUSTARD}"/>'
        )
    else:  # skull
        body = (
            f'<path d="M-22,-4 Q-22,-30 0,-30 Q22,-30 22,-4 Q22,10 12,14 L12,24 L-12,24 L-12,14 Q-22,10 -22,-4Z" '
            f'fill="{CREAM}" {ol(6)}/>'
            f'<circle cx="-9" cy="-6" r="7" fill="{INK}"/><circle cx="9" cy="-6" r="7" fill="{INK}"/>'
            f'<path d="M-3,8 L3,8 L0,3Z" fill="{INK}"/><path d="M-6,16 L-6,24 M0,16 L0,24 M6,16 L6,24" stroke="{INK}" stroke-width="3"/>'
        )
    return g + body + "</g>"


def themed_cap(paper: tuple[str, str], band: str, mark: str):
    """crew_cap with the skin's colours and emblem."""

    def cap(ic: Icon, x: float, y: float, k: float = 1.0) -> str:
        fill = ic.two(*paper, 0.6)
        return (
            f'<g transform="translate({x} {y}) scale({k})">'
            f'<path d="M-110,30 L-86,-52 Q0,-80 86,-52 L110,30 Z" fill="{fill}" {ol()}/>'
            f'<path d="M-110,30 L110,30 L104,6 L-104,6 Z" fill="{band}" {ol(w)}/>'
            + emblem(mark, 0, -26, 0.95)
            + "</g>"
        )

    return cap


def witch_hat(ic: Icon, x: float, y: float, k: float = 1.0) -> str:
    cone = ic.two("#9A6BE0", "#6A3FB0", 0.6)
    return (
        f'<g transform="translate({x} {y}) scale({k})">'
        f'<ellipse cx="0" cy="22" rx="150" ry="28" fill="{cone}" {ol()}/>'
        f'<path d="M-82,18 Q-40,-90 30,-170 Q46,-178 40,-150 Q30,-60 82,18 Z" fill="{cone}" {ol()}/>'
        f'<path d="M-80,10 Q0,26 80,10 L76,-12 Q0,4 -76,-12 Z" fill="{MUSTARD}" {ol(w)}/>'
        + emblem("moon", 0, -50, 0.9)
        + "</g>"
    )


def dog_head(ic: Icon, fur: tuple[str, str]) -> str:
    f = ic.two(*fur, 0.62)
    muzzle = ic.two("#F6E2C6", "#E2C29A", 0.6)
    return (
        f'<path d="M118,190 Q74,236 96,344 Q130,362 156,306 Z" fill="{f}" {ol()}/>'
        f'<path d="M394,190 Q438,236 416,344 Q382,362 356,306 Z" fill="{f}" {ol()}/>'
        f'<ellipse cx="256" cy="300" rx="150" ry="132" fill="{f}" {ol()}/>'
        f'<ellipse cx="256" cy="352" rx="70" ry="50" fill="{muzzle}" {ol(w)}/>'
        + face(292, gap=62)
        + f'<ellipse cx="256" cy="334" rx="24" ry="16" fill="{INK}"/>'
        + smile(360)
        + gloss(170, 252, 20, 9)
    )


SKINS = {
    # key: class head, tile tone, fur recolour (class hex -> skin hex), cap or hat
    "skin_dog_pumpkin": dict(head="dog", tone="pumpkin", fur=("#C98C64", "#A26A45"),
                             cap=themed_cap(("#FFB060", "#E07818"), "#3A3242", "pumpkin")),
    "skin_rabbit_ghost": dict(head="rabbit", tone="ghost", recolour={"#E2DCEA": "#D6DEF5"},
                              cap=themed_cap(("#FFFFFF", "#DCE2F4"), "#8B93B5", "ghost")),
    "skin_cat_witch": dict(head="cat", tone="night", recolour={"#FFB870": "#4A4552", "#E88A3A": "#2F2B36"},
                           cap=witch_hat, cap_y=150),
    "skin_bear_franken": dict(head="bear", tone="moss", recolour={"#B9805A": "#9BCB7D", "#8E5A38": "#6E9A55"},
                              cap=themed_cap(("#8A929C", "#5E6670"), "#2F2A36", "bolt"), bolts=True),
    "skin_fox_vampire": dict(head="fox", tone="wine",
                             cap=themed_cap(("#4A4256", "#2C2634"), "#7A2148", "bat"), fangs=True),
    "skin_owl_skeleton": dict(head="owl", tone="bone", recolour={"#A88466": "#5A5466", "#7A5A40": "#3E3948"},
                              cap=themed_cap(("#4A4256", "#2C2634"), "#ECE2C8", "skull")),
}

HEADS = {"rabbit": S.class_rabbit, "cat": S.class_cat, "bear": S.class_bear, "fox": S.class_fox, "owl": S.class_owl}


def build(spec: dict, limited: bool):
    def draw(ic: Icon) -> str:
        S.tile = lambda ic_, _tone, _round=False: ORIG_TILE(ic_, spec["tone"], True)
        cap_y = spec.get("cap_y")
        if cap_y is not None:
            S.crew_cap = lambda ic_, x, _y, k=1.0: spec["cap"](ic_, x, cap_y, k)
        else:
            S.crew_cap = spec["cap"]
        try:
            if spec["head"] == "dog":
                body = S.tile(ic, spec["tone"], True) + dog_head(ic, spec["fur"]) + S.crew_cap(ic, 256, 196, 0.95)
            else:
                body = HEADS[spec["head"]](ic)
        finally:
            S.tile = ORIG_TILE
            S.crew_cap = ORIG_CAP
        for old, new in spec.get("recolour", {}).items():
            body = body.replace(old, new)
            ic.defs = [d.replace(old, new) for d in ic.defs]
        if spec.get("bolts"):
            for x in (98, 414):
                body += f'<rect x="{x - 16}" y="296" width="32" height="22" rx="5" fill="#9AA2AC" {ol(8)}/>'
        if spec.get("fangs"):
            body += f'<path d="M238,384 L246,402 L252,386Z M260,386 L266,402 L274,384Z" fill="{WHITE}" {ol(5)}/>'
        if limited:
            body += ribbon()
        return body

    return draw


def main() -> None:
    import sys

    only = sys.argv[1:]
    (OUT / "art").mkdir(parents=True, exist_ok=True)
    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        page = browser.new_page(viewport={"width": 512, "height": 512})
        for key, spec in SKINS.items():
            if only and not any(o in key for o in only):
                continue
            for folder, limited in ((OUT, True), (OUT / "art", False)):
                ic = Icon()
                svg = ic.svg(build(spec, limited)(ic))
                (folder / f"{key}.svg").write_text(svg, encoding="utf-8")
                page.set_content(S.PAGE.format(svg=svg))
                page.evaluate("document.fonts.ready")
                page.wait_for_timeout(150)
                page.screenshot(path=str(folder / f"{key}.png"), clip={"x": 0, "y": 0, "width": 512, "height": 512},
                                omit_background=True)
                print(folder / f"{key}.png")
        browser.close()


if __name__ == "__main__":
    main()
