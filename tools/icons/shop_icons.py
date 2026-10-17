"""Shop icons (Developer Products + Game Passes), 512x512 PNG, in the game's UI style.

Same language as the AST-091 UI icon sheet and the CartoonPanel (Theme, style guide §7.1):
  - tile: two-tone vertical gradient, thick Ink outline, round corners, darker "lip" under it, thin white inner rim;
  - object: sticker look, Ink outline, hard two-tone shading (light top, darker bottom band), white gloss blobs;
  - text: Fredoka One, white or Mustard with a thick Ink stroke; never the alert red.
Developer products use a rounded square tile; game passes (classes) a round tile, because Roblox shows game passes
cropped to a circle.

    python tools/icons/shop_icons.py            # writes Assets/textures/ui/shop/<key>.png (+ .svg sources): the Creator
                                                # Hub product images (numbered tiles), and shop/art/gems_<n>.png: the
                                                # in-game gem art (no tile, no number; GemShop cards)
    python tools/icons/shop_icons.py gems_50 cash_100   # only these tiles ("art/gems_50" for an art file)
"""
from __future__ import annotations

import math
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Assets" / "textures" / "ui" / "shop"

INK = "#2B2233"
WHITE = "#FFFFFF"
CREAM = "#FFF1D6"
MUSTARD = "#F6C12B"
PINK = "#F4A7B9"
W = 16  # main outline
w = 10  # inner lines


class Icon:
    """Collects gradient defs while an icon is drawn."""

    def __init__(self, bare: bool = False) -> None:
        self.defs: list[str] = []
        self.n = 0
        self.bare = bare  # True: tile() draws nothing (the subject alone, reused inside the gift icons)

    def two(self, top: str, bottom: str, split: float = 0.6) -> str:
        """Hard two-tone vertical fill (the sticker shading)."""
        self.n += 1
        gid = f"g{self.n}"
        self.defs.append(
            f'<linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{top}"/><stop offset="{split}" stop-color="{top}"/>'
            f'<stop offset="{split}" stop-color="{bottom}"/><stop offset="1" stop-color="{bottom}"/></linearGradient>'
        )
        return f"url(#{gid})"

    def soft(self, top: str, bottom: str) -> str:
        self.n += 1
        gid = f"g{self.n}"
        self.defs.append(
            f'<linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient>'
        )
        return f"url(#{gid})"

    def svg(self, body: str) -> str:
        return (
            '<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">'
            f'<defs>{"".join(self.defs)}</defs>{body}</svg>'
        )


def ol(width: int = W) -> str:
    return f'stroke="{INK}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round"'


def gloss(x: float, y: float, rx: float, ry: float, rot: float = -25, op: float = 0.85) -> str:
    return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{WHITE}" opacity="{op}" transform="rotate({rot} {x} {y})"/>'


def text(t: str, x: float, y: float, size: int, fill: str = WHITE, anchor: str = "middle") -> str:
    return (
        f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-family="Fredoka One" font-size="{size}" fill="{fill}" '
        f'stroke="{INK}" stroke-width="{max(10, size // 5)}" paint-order="stroke" stroke-linejoin="round">{t}</text>'
    )


# --- tiles (CartoonPanel) ------------------------------------------------------------------------------------------

TONES = {
    # top, bottom, lip
    "violet": ("#A99BFF", "#6A5ACD", "#4A3E9A"),
    "green": ("#9BE08F", "#4FA35E", "#336E40"),
    "teal": ("#8BE3EE", "#3FA7B5", "#2A7480"),
    "mustard": ("#FFE58A", "#F6C12B", "#B9850F"),
    "cream": ("#FFF8E8", "#FFE2B0", "#D9A766"),
    "pink": ("#FFD3E0", "#F08FB0", "#B85E80"),
    "orange": ("#FFC48A", "#F08A3C", "#B05A1E"),
    "brown": ("#E6B98A", "#B07A4E", "#7A4E2E"),
}


RAYS = 16  # sunburst wedges (half of them light): the 90s soda-poster look (owner 2026-10-15)


def sunburst(cx: float, cy: float, light: str, opacity: float = 0.42) -> str:
    """Alternating rays out of the centre (every other wedge lighter)."""
    out = []
    step = 360 / RAYS
    for i in range(0, RAYS, 2):
        a0 = math.radians(-90 + i * step)
        a1 = math.radians(-90 + (i + 1) * step)
        x0, y0 = cx + 420 * math.cos(a0), cy + 420 * math.sin(a0)
        x1, y1 = cx + 420 * math.cos(a1), cy + 420 * math.sin(a1)
        out.append(f'<path d="M{cx},{cy} L{x0:.1f},{y0:.1f} L{x1:.1f},{y1:.1f} Z" fill="{light}" opacity="{opacity}"/>')
    return "".join(out)


def tile(ic: Icon, tone: str, round_: bool = False) -> str:
    """CartoonPanel tile with the retro look: alternating sunburst rays behind the subject (owner 2026-10-15)."""
    if ic.bare:
        return ""
    top, bottom, lip = TONES[tone]
    fill = ic.soft(top, bottom)
    ic.n += 1
    clip = f"c{ic.n}"
    shape = (
        '<circle cx="256" cy="250" r="236"/>' if round_ else '<rect x="24" y="24" width="464" height="448" rx="58"/>'
    )
    ic.defs.append(f'<clipPath id="{clip}">{shape}</clipPath>')
    if round_:
        return (
            f'<circle cx="256" cy="262" r="244" fill="{lip}" {ol()}/>'
            f'<circle cx="256" cy="250" r="244" fill="{fill}" {ol()}/>'
            f'<g clip-path="url(#{clip})">{sunburst(256, 260, CREAM)}</g>'
            f'<circle cx="256" cy="250" r="228" fill="none" stroke="{WHITE}" stroke-width="5" opacity="0.55"/>'
        )
    return (
        f'<rect x="10" y="22" width="492" height="480" rx="70" fill="{lip}" {ol()}/>'
        f'<rect x="10" y="10" width="492" height="476" rx="70" fill="{fill}" {ol()}/>'
        f'<g clip-path="url(#{clip})">{sunburst(256, 260, CREAM)}</g>'
        f'<rect x="26" y="26" width="460" height="444" rx="56" fill="none" stroke="{WHITE}" stroke-width="5" opacity="0.55"/>'
    )


def ground(cx: float = 256, cy: float = 420, rx: float = 150) -> str:
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="20" fill="{INK}" opacity="0.18"/>'


# --- shared props --------------------------------------------------------------------------------------------------


def hotdog_logo(ic: Icon, x: float, y: float, k: float = 1.0) -> str:
    """The crew's hot dog emblem (bun + sausage + mustard), centred at x, y."""
    bun = ic.two("#F7C98A", "#D9984E", 0.55)
    return (
        f'<g transform="translate({x} {y}) scale({k})">'
        f'<rect x="-46" y="-20" width="92" height="40" rx="20" fill="#B5502E" {ol(8)}/>'
        f'<path d="M-40,2 Q-40,22 -20,22 L20,22 Q40,22 40,2 Z" fill="{bun}" {ol(8)}/>'
        f'<path d="M-30,-4 L-20,-12 L-10,-4 L0,-12 L10,-4 L20,-12 L30,-4" fill="none" stroke="{MUSTARD}" stroke-width="7" '
        f'stroke-linecap="round" stroke-linejoin="round"/></g>'
    )


def coin(ic: Icon, x: float, y: float, r: float) -> str:
    return (
        f'<circle cx="{x}" cy="{y}" r="{r}" fill="{ic.two("#FFE07A", "#E9A81C", 0.55)}" {ol(w)}/>'
        f'<circle cx="{x}" cy="{y}" r="{r * 0.66}" fill="none" stroke="#C98A10" stroke-width="{max(4, r * 0.09)}"/>'
        f'<text x="{x}" y="{y + r * 0.36}" text-anchor="middle" font-family="Fredoka One" font-size="{r}" '
        f'fill="#C98A10">$</text>'
        + gloss(x - r * 0.45, y - r * 0.45, r * 0.22, r * 0.12)
    )


def gem(ic: Icon, x: float, y: float, s: float) -> str:
    t = y - s * 0.45
    outer = f"{x - s / 2},{t + s * 0.28} {x - s * 0.28},{t} {x + s * 0.28},{t} {x + s / 2},{t + s * 0.28} {x},{t + s * 0.9}"
    return (
        f'<polygon points="{outer}" fill="{ic.two("#7FE6F2", "#2E9FB0", 0.42)}" {ol(w)}/>'
        f'<polygon points="{x - s * 0.28},{t} {x},{t + s * 0.28} {x + s * 0.28},{t}" fill="#C9F7FC"/>'
        f'<polygon points="{x - s / 2},{t + s * 0.28} {x},{t + s * 0.28} {x},{t + s * 0.9}" fill="#5BC8D6" opacity="0.8"/>'
        f'<polyline points="{x - s / 2},{t + s * 0.28} {x + s / 2},{t + s * 0.28}" fill="none" stroke="{INK}" stroke-width="6"/>'
        f'<polygon points="{outer}" fill="none" {ol(w)}/>'
        + gloss(x - s * 0.18, t + s * 0.12, s * 0.07, s * 0.04, -20)
    )


def bottle(ic: Icon, x: float, y: float, base: str, dark: str, label: str = "", k: float = 1.0) -> str:
    body = ic.two(base, dark, 0.62)
    return (
        f'<g transform="translate({x} {y}) scale({k})">'
        f'<path d="M-12,-118 L12,-118 L18,-92 L-18,-92 Z" fill="{body}" {ol(w)}/>'
        f'<path d="M-46,-50 Q-46,-92 0,-92 Q46,-92 46,-50 L46,74 Q46,96 24,96 L-24,96 Q-46,96 -46,74 Z" fill="{body}" {ol(W)}/>'
        f'<rect x="-36" y="-8" width="72" height="50" rx="12" fill="{CREAM}" {ol(7)}/>'
        + (f'<text x="0" y="27" text-anchor="middle" font-family="Fredoka One" font-size="28" fill="{INK}">{label}</text>' if label else "")
        + gloss(-26, -46, 8, 22, 0, 0.8)
        + '</g>'
    )


def crew_cap(ic: Icon, x: float, y: float, k: float = 1.0) -> str:
    """The crew's paper cap with the hot dog emblem (sits on the animal's head)."""
    paper = ic.two("#FFFFFF", "#E8E2F0", 0.6)
    return (
        f'<g transform="translate({x} {y}) scale({k})">'
        f'<path d="M-110,30 L-86,-52 Q0,-80 86,-52 L110,30 Z" fill="{paper}" {ol(W)}/>'
        f'<path d="M-110,30 L110,30 L104,6 L-104,6 Z" fill="{MUSTARD}" {ol(w)}/>'
        + hotdog_logo(ic, 0, -30, 0.72)
        + '</g>'
    )


def face(eye_y: float, gap: float = 58, r: float = 20, cheek_y: float | None = None) -> str:
    out = (
        f'<circle cx="{256 - gap}" cy="{eye_y}" r="{r}" fill="{INK}"/><circle cx="{256 + gap}" cy="{eye_y}" r="{r}" fill="{INK}"/>'
        f'<circle cx="{256 - gap + 7}" cy="{eye_y - 8}" r="7" fill="{WHITE}"/><circle cx="{256 + gap + 7}" cy="{eye_y - 8}" r="7" fill="{WHITE}"/>'
    )
    if cheek_y is not None:
        out += (
            f'<ellipse cx="{256 - gap - 26}" cy="{cheek_y}" rx="22" ry="13" fill="{PINK}"/>'
            f'<ellipse cx="{256 + gap + 26}" cy="{cheek_y}" rx="22" ry="13" fill="{PINK}"/>'
        )
    return out


def smile(y: float) -> str:
    return f'<path d="M230,{y} Q243,{y + 18} 256,{y} Q269,{y + 18} 282,{y}" fill="none" {ol(8)}/>'


# --- developer products --------------------------------------------------------------------------------------------


def util_scare(ic: Icon) -> str:
    body = ic.two("#7E6BB8", "#54427F", 0.62)
    return (
        tile(ic, "violet")
        + ground(rx=140, cy=432)
        + f'<path d="M120,430 Q108,170 256,140 Q404,170 392,430 Q364,404 338,430 Q310,404 284,430 Q256,406 228,430 '
        f'Q200,404 174,430 Q146,404 120,430Z" fill="{body}" {ol()}/>'
        + f'<path d="M150,215 L210,240" {ol(12)}/><path d="M362,215 L302,240" {ol(12)}/>'
        + f'<ellipse cx="204" cy="282" rx="40" ry="46" fill="{WHITE}" {ol(w)}/><ellipse cx="308" cy="282" rx="40" ry="46" fill="{WHITE}" {ol(w)}/>'
        f'<circle cx="214" cy="294" r="15" fill="{INK}"/><circle cx="298" cy="294" r="15" fill="{INK}"/>'
        f'<path d="M188,350 Q256,410 324,350 Z" fill="{INK}" {ol(w)}/>'
        f'<path d="M202,354 L214,374 L228,357 L242,378 L256,358 L270,378 L284,357 L298,374 L310,354Z" fill="{WHITE}"/>'
        + gloss(170, 200, 26, 12)
        + text("BOO!", 256, 118, 104, MUSTARD)
    )


def util_radar(ic: Icon) -> str:
    rim = ic.two("#B9C2D6", "#7D86A0", 0.55)
    ghost = ic.two("#FFFFFF", "#DDE3F2", 0.6)
    return (
        tile(ic, "teal")
        + ground(rx=170, cy=438)
        + f'<circle cx="256" cy="256" r="190" fill="{rim}" {ol()}/>'
        + f'<circle cx="256" cy="256" r="152" fill="#1F4A4A" {ol(w)}/>'
        + "".join(f'<circle cx="256" cy="256" r="{r}" fill="none" stroke="#5FE0A8" stroke-width="5" opacity="0.55"/>' for r in (50, 100))
        + f'<path d="M256,256 L256,104 A152,152 0 0,1 388,180 Z" fill="#5FE0A8" opacity="0.5"/>'
        + f'<line x1="256" y1="256" x2="388" y2="180" stroke="#C8FFE4" stroke-width="9" stroke-linecap="round"/>'
        + f'<circle cx="256" cy="256" r="12" fill="#C8FFE4" {ol(6)}/>'
        + f'<circle cx="190" cy="320" r="13" fill="{MUSTARD}" {ol(6)}/><circle cx="330" cy="318" r="10" fill="{MUSTARD}" {ol(6)}/>'
        + f'<path d="M300,170 Q300,124 334,124 Q368,124 368,170 L368,212 Q358,202 350,212 Q342,202 334,212 Q326,202 318,212 '
        f'Q310,202 300,212Z" fill="{ghost}" {ol(w)}/><circle cx="322" cy="164" r="7" fill="{INK}"/><circle cx="346" cy="164" r="7" fill="{INK}"/>'
        + gloss(160, 120, 30, 12)
    )


def util_coffee(ic: Icon) -> str:
    cup = ic.two("#FFFFFF", "#EADFCB", 0.62)
    lid = ic.two("#6B4A3A", "#4A3226", 0.55)
    steam = "".join(
        f'<path d="M{x},120 Q{x - 20},96 {x},74 Q{x + 20},52 {x},30" fill="none" stroke="{WHITE}" stroke-width="14" '
        f'stroke-linecap="round" opacity="0.95"/>'
        for x in (214, 256, 298)
    )
    return (
        tile(ic, "orange")
        + ground(rx=130, cy=440)
        + steam
        + f'<path d="M150,190 L362,190 L338,420 Q336,436 318,436 L194,436 Q176,436 174,420 Z" fill="{cup}" {ol()}/>'
        + f'<path d="M160,264 L352,264 L344,350 L168,350 Z" fill="{MUSTARD}" {ol(w)}/>'
        + hotdog_logo(ic, 256, 307, 0.95)
        + f'<rect x="132" y="150" width="248" height="48" rx="20" fill="{lid}" {ol()}/>'
        + f'<rect x="196" y="128" width="120" height="30" rx="12" fill="{lid}" {ol(w)}/>'
        + gloss(186, 232, 10, 22, 0)
    )


def util_restock(ic: Icon) -> str:
    plus = ic.two("#9BE08F", "#4FA35E", 0.55)
    return (
        tile(ic, "mustard")
        + ground(rx=110, cy=432)
        + bottle(ic, 236, 290, "#FFD84A", "#E5A51A", "ANY", 1.35)
        + f'<circle cx="372" cy="170" r="62" fill="{plus}" {ol()}/>'
        + f'<path d="M372,138 L372,202 M340,170 L404,170" stroke="{WHITE}" stroke-width="20" stroke-linecap="round"/>'
        + gloss(348, 136, 14, 7)
    )


def util_pantry(ic: Icon) -> str:
    crate = ic.two("#D9A06A", "#A9693E", 0.5)
    bun = ic.two("#F7C98A", "#D9984E", 0.55)
    return (
        tile(ic, "cream")
        + ground(rx=190, cy=448)
        + bottle(ic, 160, 250, "#FFD84A", "#E5A51A", "", 0.95)
        + bottle(ic, 256, 232, "#FF8A6B", "#D9573C", "", 1.05)
        + bottle(ic, 352, 250, "#9BE08F", "#4FA35E", "", 0.95)
        + f'<rect x="96" y="290" width="160" height="56" rx="28" fill="{bun}" {ol(w)}/>'
        + f'<rect x="250" y="292" width="170" height="40" rx="20" fill="#B5502E" {ol(w)}/>'
        + f'<rect x="70" y="320" width="372" height="120" rx="20" fill="{crate}" {ol()}/>'
        + f'<line x1="70" y1="380" x2="442" y2="380" stroke="{INK}" stroke-width="8"/>'
        + f'<line x1="150" y1="320" x2="150" y2="440" stroke="{INK}" stroke-width="6" opacity="0.5"/>'
        f'<line x1="362" y1="320" x2="362" y2="440" stroke="{INK}" stroke-width="6" opacity="0.5"/>'
        + text("ALL FULL", 256, 120, 68, MUSTARD)
    )


def util_revive(ic: Icon) -> str:
    box = ic.two("#FFFFFF", "#E2E8F0", 0.6)
    lidc = ic.two("#7FD7E2", "#3FA7B5", 0.55)
    heart = ic.two("#FFC2D4", "#EE89A9", 0.6)
    return (
        tile(ic, "teal")
        + ground(rx=170, cy=444)
        + f'<path d="M200,170 L200,130 Q200,114 216,114 L296,114 Q312,114 312,130 L312,170" fill="none" stroke="{INK}" stroke-width="38" stroke-linecap="round"/>'
        f'<path d="M200,170 L200,130 Q200,114 216,114 L296,114 Q312,114 312,130 L312,170" fill="none" stroke="#B9C2D6" stroke-width="18" stroke-linecap="round"/>'
        + f'<rect x="96" y="160" width="320" height="262" rx="40" fill="{box}" {ol()}/>'
        + f'<path d="M96,226 L96,200 Q96,160 136,160 L376,160 Q416,160 416,200 L416,226 Z" fill="{lidc}" {ol(w)}/>'
        + f'<path d="M256,398 C178,344 158,306 182,280 C204,256 238,266 256,292 C274,266 308,256 330,280 C354,306 334,344 256,398Z" '
        f'fill="{heart}" {ol(w)}/>'
        + f'<path d="M256,302 L256,360 M227,331 L285,331" stroke="{WHITE}" stroke-width="16" stroke-linecap="round"/>'
        + gloss(136, 196, 18, 8, 0)
    )


def cash_100(ic: Icon) -> str:
    # the trailer's TIPS jar (AST-091 Tip Jar), full of coins
    glass = ic.two("#E6F6FF", "#B8DDF0", 0.6)
    lidc = ic.two("#C9D2E2", "#8D97AE", 0.5)
    return (
        tile(ic, "green")
        + ground(rx=140, cy=446)
        + f'<rect x="146" y="150" width="220" height="282" rx="44" fill="{glass}" {ol()}/>'
        + coin(ic, 206, 380, 34) + coin(ic, 286, 386, 34) + coin(ic, 246, 330, 34) + coin(ic, 312, 328, 30) + coin(ic, 190, 316, 28)
        + f'<rect x="146" y="150" width="220" height="282" rx="44" fill="none" {ol()}/>'
        + f'<rect x="166" y="210" width="180" height="62" rx="14" fill="#3FA7FF" {ol(w)}/>'
        + text("TIPS", 256, 258, 46, WHITE)
        + f'<rect x="134" y="112" width="244" height="54" rx="20" fill="{lidc}" {ol()}/>'
        + f'<rect x="226" y="128" width="60" height="12" rx="6" fill="{INK}"/>'
        + gloss(176, 300, 9, 30, 0, 0.7)
        + text("+$60", 256, 96, 84, MUSTARD)
    )


def chest(ic: Icon, heap_back: str, heap_front: str) -> str:
    """Open treasure chest, front view, overflowing: `heap_back` sits in the opening, `heap_front` spills over the rim."""
    wood = ic.two("#C98A55", "#94592E", 0.55)
    lid = ic.two("#A96B3C", "#7A4A26", 0.5)
    gold = ic.two("#FFE58A", "#E9A81C", 0.55)
    return (
        ground(rx=200, cy=452)
        + f'<polygon points="104,262 408,262 386,176 126,176" fill="{lid}" {ol()}/>'
        + f'<rect x="236" y="176" width="40" height="86" fill="{gold}" {ol(w)}/>'
        + heap_back
        + f'<rect x="96" y="276" width="320" height="164" rx="18" fill="{wood}" {ol()}/>'
        + f'<rect x="136" y="276" width="30" height="164" fill="{gold}" {ol(w)}/>'
        f'<rect x="346" y="276" width="30" height="164" fill="{gold}" {ol(w)}/>'
        + f'<rect x="230" y="306" width="52" height="56" rx="10" fill="{gold}" {ol(w)}/>'
        f'<circle cx="256" cy="326" r="8" fill="{INK}"/><rect x="252" y="328" width="8" height="18" rx="3" fill="{INK}"/>'
        + f'<rect x="86" y="262" width="340" height="30" rx="12" fill="{gold}" {ol()}/>'
        + heap_front
        + gloss(132, 312, 10, 26, 0, 0.5)
    )


def coin_pile(ic: Icon, rows: list[list[tuple[float, float]]], r: float) -> str:
    return "".join(coin(ic, x, y, r) for row in rows for x, y in row)


def gem_pile(ic: Icon, rows: list[list[tuple[float, float]]], s: float) -> str:
    return "".join(gem(ic, x, y, s) for row in rows for x, y in row)


def cash_300(ic: Icon) -> str:
    # a pile of the game's coins (in-run Cash, sold only during a run): 3 - 2 - 1
    return (
        tile(ic, "green")
        + ground(rx=180, cy=440)
        + coin_pile(ic, [[(150, 380), (256, 384), (362, 380)], [(203, 300), (309, 300)], [(256, 222)]], 58)
        + text("+$150", 256, 120, 96, MUSTARD)
    )


def cash_800(ic: Icon) -> str:
    back = coin_pile(ic, [[(150, 250), (210, 236), (270, 230), (330, 238), (372, 252)], [(180, 206), (246, 196), (312, 204)]], 34)
    front = coin_pile(ic, [[(118, 284), (392, 286)], [(330, 410)]], 30)
    return tile(ic, "green") + chest(ic, back, front) + text("+$330", 256, 120, 96, MUSTARD)


def gems_50(ic: Icon) -> str:
    # 1 gem
    return tile(ic, "teal") + ground(rx=120, cy=420) + gem(ic, 256, 300, 230) + text("1,000", 256, 120, 104, WHITE)


def gems_130(ic: Icon) -> str:
    # 3 gems: 2 + 1
    return (
        tile(ic, "teal")
        + ground(rx=170, cy=440)
        + gem_pile(ic, GEMS_130, 140)
        + text("2,400", 256, 120, 96, WHITE)
    )


def gems_300(ic: Icon) -> str:
    # 6 gems: 3 + 2 + 1
    return (
        tile(ic, "teal")
        + ground(rx=200, cy=446)
        + gem_pile(ic, GEMS_300, 112)
        + text("4,800", 256, 120, 96, WHITE)
    )


GEMS_130 = [[(190, 352), (322, 352)], [(256, 252)]]
GEMS_300 = [[(146, 376), (256, 376), (366, 376)], [(201, 298), (311, 298)], [(256, 220)]]


def gem_chest(ic: Icon) -> str:
    back = gem_pile(ic, [[(150, 252), (214, 240), (280, 236), (346, 246)], [(184, 206), (250, 196), (318, 204)]], 70)
    front = gem_pile(ic, [[(118, 290), (394, 292)], [(334, 414)]], 60)
    return chest(ic, back, front)


def gems_700(ic: Icon) -> str:
    # a chest overflowing with gems
    return tile(ic, "teal") + gem_chest(ic) + text("10,000", 256, 120, 96, WHITE)


# --- in-game gem art (owner 2026-10-15): the same objects with no tile and no number, centred and big, transparent ---
# The GemShop card draws its own spinning rays (Sunburst) behind them; the numbered tiles above stay the Creator Hub
# product images.


def centred(body: str, cx: float, cy: float, k: float) -> str:
    return f'<g transform="translate(256 256) scale({k}) translate({-cx} {-cy})">{body}</g>'


def art_gems_50(ic: Icon) -> str:
    return centred(gem(ic, 256, 300, 230), 256, 300, 1.75)


def art_gems_130(ic: Icon) -> str:
    return centred(gem_pile(ic, GEMS_130, 140), 256, 302, 1.6)


def art_gems_300(ic: Icon) -> str:
    return centred(gem_pile(ic, GEMS_300, 112), 256, 298, 1.35)


def art_gems_700(ic: Icon) -> str:
    return centred(gem_chest(ic), 256, 314, 1.3)


# In-game coin art (in-run shop cards, owner 2026-10-16: "trocar os vetores das moedas"): the three sizes read at a glance,
# small sack -> pile -> overflowing chest, all with the game's $ coin; no tile, no number (the card says "+60 Coins").
def coin_sack(ic: Icon) -> str:
    cloth = ic.two("#E2B57A", "#B9814A", 0.55)
    return (
        ground(rx=150, cy=440)
        # the sack body, tied at the neck
        + f'<path d="M256,176 C176,176 120,268 124,350 C128,420 190,438 256,438 C322,438 384,420 388,350 C392,268 336,176 256,176 Z" '
        f'fill="{cloth}" {ol()}/>'
        + f'<path d="M210,150 C222,128 290,128 302,150 L292,186 C276,196 236,196 220,186 Z" fill="{cloth}" {ol()}/>'
        + f'<rect x="208" y="176" width="96" height="22" rx="11" fill="#7A4A26" {ol(w)}/>'
        # a big $ coin stamped on the sack
        + coin(ic, 256, 320, 64)
        # coins spilled in front
        + coin(ic, 150, 412, 32) + coin(ic, 364, 414, 30) + coin(ic, 116, 384, 24)
        + gloss(172, 262, 14, 34, 20, 0.55)
    )


def art_cash_100(ic: Icon) -> str:
    return centred(coin_sack(ic), 256, 300, 1.2)


def art_cash_300(ic: Icon) -> str:
    pile = ground(rx=180, cy=440) + coin_pile(ic, [[(150, 380), (256, 384), (362, 380)], [(203, 300), (309, 300)], [(256, 222)]], 58)
    return centred(pile, 256, 320, 1.25)


def art_cash_800(ic: Icon) -> str:
    back = coin_pile(ic, [[(150, 250), (210, 236), (270, 230), (330, 238), (372, 252)], [(180, 206), (246, 196), (312, 204)]], 34)
    front = coin_pile(ic, [[(118, 284), (392, 286)], [(330, 410)]], 30)
    return centred(chest(ic, back, front), 256, 316, 1.25)

# --- game passes (classes): round tile, crew cap on every animal ---------------------------------------------------


def class_rabbit(ic: Icon) -> str:
    fur = ic.two("#FFFFFF", "#E2DCEA", 0.62)
    return (
        tile(ic, "pink", True)
        + f'<ellipse cx="192" cy="150" rx="40" ry="100" fill="{fur}" {ol()} transform="rotate(-12 192 150)"/>'
        f'<ellipse cx="320" cy="150" rx="40" ry="100" fill="{fur}" {ol()} transform="rotate(12 320 150)"/>'
        f'<ellipse cx="192" cy="158" rx="17" ry="66" fill="{PINK}" transform="rotate(-12 192 158)"/>'
        f'<ellipse cx="320" cy="158" rx="17" ry="66" fill="{PINK}" transform="rotate(12 320 158)"/>'
        f'<ellipse cx="256" cy="300" rx="146" ry="130" fill="{fur}" {ol()}/>'
        + crew_cap(ic, 256, 196, 0.95)
        + face(296, cheek_y=336)
        + f'<path d="M244,322 L268,322 L256,336 Z" fill="{PINK}" {ol(6)}/>'
        + smile(344)
        + gloss(170, 252, 20, 9)
    )


def class_cat(ic: Icon) -> str:
    fur = ic.two("#FFB870", "#E88A3A", 0.62)
    return (
        tile(ic, "orange", True)
        + f'<path d="M126,262 L140,104 L236,188 Z" fill="{fur}" {ol()}/><path d="M386,262 L372,104 L276,188 Z" fill="{fur}" {ol()}/>'
        f'<path d="M150,224 L156,146 L206,190 Z" fill="{PINK}"/><path d="M362,224 L356,146 L306,190 Z" fill="{PINK}"/>'
        f'<ellipse cx="256" cy="300" rx="150" ry="130" fill="{fur}" {ol()}/>'
        + crew_cap(ic, 256, 200, 0.92)
        + face(298, cheek_y=338)
        + f'<path d="M244,322 L268,322 L256,336 Z" fill="{PINK}" {ol(6)}/>'
        + smile(342)
        + "".join(
            f'<line x1="{a}" y1="{b}" x2="{c}" y2="{d}" stroke="{INK}" stroke-width="6" stroke-linecap="round"/>'
            for a, b, c, d in ((140, 318, 86, 306), (140, 336, 88, 348), (372, 318, 426, 306), (372, 336, 424, 348))
        )
        + gloss(176, 250, 20, 9)
    )


def class_bear(ic: Icon) -> str:
    fur = ic.two("#B9805A", "#8E5A38", 0.62)
    muzzle = ic.two("#F2D2A8", "#DDB27E", 0.6)
    return (
        tile(ic, "brown", True)
        + f'<circle cx="140" cy="186" r="54" fill="{fur}" {ol()}/><circle cx="372" cy="186" r="54" fill="{fur}" {ol()}/>'
        f'<circle cx="140" cy="186" r="26" fill="#DDB27E"/><circle cx="372" cy="186" r="26" fill="#DDB27E"/>'
        f'<ellipse cx="256" cy="300" rx="156" ry="136" fill="{fur}" {ol()}/>'
        + crew_cap(ic, 256, 196, 0.95)
        + f'<ellipse cx="256" cy="348" rx="70" ry="52" fill="{muzzle}" {ol(w)}/>'
        + face(292, gap=62)
        + f'<ellipse cx="256" cy="330" rx="24" ry="16" fill="{INK}"/>'
        + smile(356)
        + gloss(168, 252, 20, 9)
    )


def class_fox(ic: Icon) -> str:
    fur = ic.two("#FF9B52", "#E36E2A", 0.62)
    return (
        tile(ic, "mustard", True)
        + f'<path d="M118,250 L130,96 L230,176 Z" fill="{fur}" {ol()}/><path d="M394,250 L382,96 L282,176 Z" fill="{fur}" {ol()}/>'
        f'<path d="M142,214 L148,138 L198,180 Z" fill="{CREAM}"/><path d="M370,214 L364,138 L314,180 Z" fill="{CREAM}"/>'
        f'<path d="M104,276 Q114,170 256,170 Q398,170 408,276 Q404,366 256,436 Q108,366 104,276Z" fill="{fur}" {ol()}/>'
        f'<path d="M134,306 Q196,314 256,376 Q316,314 378,306 Q372,366 256,430 Q140,366 134,306Z" fill="{CREAM}"/>'
        f'<path d="M104,276 Q114,170 256,170 Q398,170 408,276 Q404,366 256,436 Q108,366 104,276Z" fill="none" {ol()}/>'
        + crew_cap(ic, 256, 196, 0.95)
        + face(290, gap=62)
        + f'<ellipse cx="256" cy="366" rx="20" ry="14" fill="{INK}"/>'
        + gloss(160, 256, 20, 9)
    )


def class_owl(ic: Icon) -> str:
    fur = ic.two("#A88466", "#7A5A40", 0.62)
    belly = ic.two("#E6CBA6", "#CFAE84", 0.6)
    return (
        tile(ic, "violet", True)
        + f'<path d="M140,210 L120,120 L206,176 Z" fill="{fur}" {ol()}/><path d="M372,210 L392,120 L306,176 Z" fill="{fur}" {ol()}/>'
        f'<ellipse cx="256" cy="300" rx="164" ry="146" fill="{fur}" {ol()}/>'
        f'<path d="M150,322 Q256,262 362,322 Q340,436 256,440 Q172,436 150,322Z" fill="{belly}"/>'
        + crew_cap(ic, 256, 184, 0.9)
        + f'<circle cx="196" cy="286" r="56" fill="{CREAM}" {ol(w)}/><circle cx="316" cy="286" r="56" fill="{CREAM}" {ol(w)}/>'
        f'<circle cx="196" cy="290" r="26" fill="{INK}"/><circle cx="316" cy="290" r="26" fill="{INK}"/>'
        f'<circle cx="206" cy="280" r="9" fill="{WHITE}"/><circle cx="326" cy="280" r="9" fill="{WHITE}"/>'
        f'<path d="M238,326 L274,326 L256,362 Z" fill="{MUSTARD}" {ol(7)}/>'
        + "".join(f'<path d="M{x},392 Q{x + 14},406 {x + 28},392" fill="none" stroke="#7A5A40" stroke-width="7" stroke-linecap="round"/>' for x in (200, 242, 284))
        + gloss(160, 250, 20, 9)
    )


# --- gifts (TASK-352, owner 2026-10-16): Developer Products bought for another player --------------------------------
# Violet tile (the GiftButton tone), an open Mustard box with a Teal ribbon (the GiftButton colours) and the item popping
# out of it; gem gifts keep their amount on top. "gift" alone = the closed box with a bow (generic gift image).

BOX = ("#FFE58A", "#F6C12B")
RIBBON = ("#8BE3EE", "#3FA7B5")


def placed(body: str, cx: float, cy: float, k: float, tx: float, ty: float) -> str:
    """`body` drawn around (cx, cy) moved to (tx, ty) and scaled by k."""
    return f'<g transform="translate({tx} {ty}) scale({k}) translate({-cx} {-cy})">{body}</g>'


def bow(ic: Icon, x: float, y: float, k: float = 1.0) -> str:
    rib = ic.two(*RIBBON, 0.55)
    return (
        f'<g transform="translate({x} {y}) scale({k})">'
        f'<path d="M0,0 C-30,-62 -104,-58 -92,-12 C-84,18 -34,14 0,0 Z" fill="{rib}" {ol(w)}/>'
        f'<path d="M0,0 C30,-62 104,-58 92,-12 C84,18 34,14 0,0 Z" fill="{rib}" {ol(w)}/>'
        f'<path d="M-10,4 L-40,58 L-18,52 L-8,72 L4,8 Z" fill="{RIBBON[1]}" {ol(8)}/>'
        f'<path d="M10,4 L40,58 L18,52 L8,72 L-4,8 Z" fill="{RIBBON[1]}" {ol(8)}/>'
        f'<circle cx="0" cy="0" r="20" fill="{RIBBON[0]}" {ol(w)}/>'
        + gloss(-56, -30, 12, 6, -30, 0.7)
        + "</g>"
    )


def gift_box(ic: Icon, open_: bool) -> str:
    """The box body (y 292..452); open = the lid tilted off to the left, else closed with a bow on top."""
    body = ic.two(*BOX, 0.55)
    lid = ic.two(*BOX, 0.6)
    rib = ic.two(*RIBBON, 0.55)
    out = ""
    out += (
        f'<rect x="112" y="292" width="288" height="160" rx="16" fill="{body}" {ol()}/>'
        f'<rect x="232" y="292" width="48" height="160" fill="{rib}" {ol(w)}/>'
        f'<rect x="112" y="292" width="288" height="160" rx="16" fill="none" {ol()}/>'
        + gloss(150, 326, 18, 9)
    )
    if not open_:
        out += (
            f'<rect x="96" y="246" width="320" height="62" rx="14" fill="{lid}" {ol()}/>'
            f'<rect x="232" y="246" width="48" height="62" fill="{rib}" {ol(w)}/>'
            f'<rect x="96" y="246" width="320" height="62" rx="14" fill="none" {ol()}/>'
            + bow(ic, 256, 236, 1.0)
        )
    return out


def gift_lid(ic: Icon) -> str:
    """The open lid, leaning back behind the item (drawn before it)."""
    lid = ic.two(*BOX, 0.6)
    rib = ic.two(*RIBBON, 0.55)
    return (
        f'<g transform="rotate(-28 400 292)">'
        f'<rect x="250" y="228" width="190" height="56" rx="14" fill="{lid}" {ol()}/>'
        f'<rect x="322" y="228" width="44" height="56" fill="{rib}" {ol(w)}/></g>'
    )


def gift_tile(ic: Icon, item: str, amount: str = "") -> str:
    return (
        tile(ic, "violet")
        + ground(rx=170, cy=458)
        + gift_lid(ic)
        + item
        + gift_box(ic, True)
        + (text(amount, 256, 112, 92, WHITE) if amount else "")
    )


def gift(ic: Icon) -> str:
    return tile(ic, "violet") + ground(rx=170, cy=458) + placed(gift_box(ic, False), 256, 330, 1.12, 256, 300)


def gift_gems(build, cx: float, cy: float, k: float, amount: str):
    def draw(ic: Icon) -> str:
        return gift_tile(ic, placed(build(ic), cx, cy, k, 256, 236), amount)

    return draw


def gift_class(build):
    def draw(ic: Icon) -> str:
        bare = Icon(bare=True)
        head = build(bare)
        ic.defs.extend(d.replace('id="g', 'id="hg').replace("url(#g", "url(#hg") for d in bare.defs)
        head = head.replace("url(#g", "url(#hg")
        return gift_tile(ic, placed(head, 256, 280, 0.7, 256, 176))

    return draw


GIFTS = {
    "gift": gift,
    "gift_gems_50": gift_gems(lambda ic: gem(ic, 256, 300, 230), 256, 300, 0.78, "1,000"),
    "gift_gems_130": gift_gems(lambda ic: gem_pile(ic, GEMS_130, 140), 256, 302, 0.72, "2,400"),
    "gift_gems_300": gift_gems(lambda ic: gem_pile(ic, GEMS_300, 112), 256, 298, 0.62, "4,800"),
    "gift_gems_700": gift_gems(gem_chest, 256, 314, 0.6, "10,000"),
    "gift_class_rabbit": gift_class(class_rabbit),
    "gift_class_cat": gift_class(class_cat),
    "gift_class_bear": gift_class(class_bear),
    "gift_class_fox": gift_class(class_fox),
    "gift_class_owl": gift_class(class_owl),
}

ICONS = {
    "util_scare": util_scare,
    "util_radar": util_radar,
    "util_coffee": util_coffee,
    "util_restock": util_restock,
    "util_pantry": util_pantry,
    "util_revive": util_revive,
    "cash_100": cash_100,
    "cash_300": cash_300,
    "cash_800": cash_800,
    "gems_50": gems_50,
    "gems_130": gems_130,
    "gems_300": gems_300,
    "gems_700": gems_700,
    "class_rabbit": class_rabbit,
    "class_cat": class_cat,
    "class_bear": class_bear,
    "class_fox": class_fox,
    "class_owl": class_owl,
    **GIFTS,
}

ART = {
    "gems_50": art_gems_50,
    "gems_130": art_gems_130,
    "gems_300": art_gems_300,
    "gems_700": art_gems_700,
    "cash_100": art_cash_100,
    "cash_300": art_cash_300,
    "cash_800": art_cash_800,
}

PAGE = """<!doctype html><html><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Fredoka+One&display=block" rel="stylesheet">
<style>html,body{{margin:0;background:transparent}}</style></head><body>{svg}</body></html>"""


def main() -> None:
    import sys

    only = set(sys.argv[1:])  # optional keys: render only these (e.g. gems_50 cash_100); none = everything
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "art").mkdir(parents=True, exist_ok=True)
    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        page = browser.new_page(viewport={"width": 512, "height": 512})
        jobs = [(OUT, key, build) for key, build in ICONS.items()] + [(OUT / "art", key, build) for key, build in ART.items()]
        for folder, key, build in jobs:
            name = key if folder == OUT else f"art/{key}"
            if only and name not in only:
                continue
            ic = Icon()
            svg = ic.svg(build(ic))
            (folder / f"{key}.svg").write_text(svg, encoding="utf-8")
            page.set_content(PAGE.format(svg=svg))
            page.evaluate("document.fonts.ready")
            page.wait_for_timeout(150)
            page.screenshot(path=str(folder / f"{key}.png"), clip={"x": 0, "y": 0, "width": 512, "height": 512}, omit_background=True)
            print(folder / f"{key}.png")
        browser.close()


if __name__ == "__main__":
    main()
