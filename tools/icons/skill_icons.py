"""Class skill icons (TASK-302), 512x512 PNG, in the game's UI style (same language as shop_icons.py).

One rounded-square sticker tile per passive skill of Content.Classes (Skills[].Icon): perks on green / teal / violet
tiles, drawbacks on mustard / orange tiles (the card adds the yellow warning mark on top). Only presentation of rules
that already exist (DEC-069); no text in the art, so the icons read at 40 px.

    python tools/icons/skill_icons.py            # writes Assets/textures/ui/skills/<key>.png (+ .svg sources)
"""
from __future__ import annotations

import math
from pathlib import Path

from playwright.sync_api import sync_playwright

from shop_icons import CREAM, INK, MUSTARD, PAGE, PINK, WHITE, Icon, gloss, ground, ol, text, tile, w

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Assets" / "textures" / "ui" / "skills"

BROWN = "#B07A4E"
SAUSAGE = ("#E8875A", "#C2553A")
FLAME = ("#FFD86B", "#F08A3C")


def speed_lines(x: float, y: float, n: int = 3, gap: float = 46, length: float = 90) -> str:
    return "".join(
        f'<path d="M{x},{y + i * gap} L{x + length - i * 18},{y + i * gap}" {ol(14)}/>' for i in range(n)
    )


def paw(ic: Icon, x: float, y: float, k: float = 1.0, rot: float = 0) -> str:
    pad = ic.two(WHITE, "#E9E1F2", 0.6)
    toes = "".join(
        f'<ellipse cx="{dx}" cy="{dy}" rx="20" ry="24" fill="{pad}" {ol(w)}/>'
        f'<ellipse cx="{dx}" cy="{dy + 4}" rx="9" ry="11" fill="{PINK}"/>'
        for dx, dy in ((-46, -58), (0, -76), (46, -58))
    )
    return (
        f'<g transform="translate({x} {y}) rotate({rot}) scale({k})">'
        f'<ellipse cx="0" cy="0" rx="52" ry="44" fill="{pad}" {ol(w)}/>'
        f'<ellipse cx="0" cy="6" rx="26" ry="20" fill="{PINK}"/>{toes}</g>'
    )


def star_points(cx: float, cy: float, outer: float, inner: float) -> str:
    pts = []
    for i in range(10):
        r = outer if i % 2 == 0 else inner
        a = math.radians(-90 + i * 36)
        pts.append(f"{cx + r * math.cos(a):.1f},{cy + r * math.sin(a):.1f}")
    return " ".join(pts)


def box(ic: Icon, x: float, y: float, bw: float, bh: float) -> str:
    fill = ic.two("#E6B98A", "#C99460", 0.55)
    return (
        f'<rect x="{x}" y="{y}" width="{bw}" height="{bh}" rx="10" fill="{fill}" {ol(w)}/>'
        f'<rect x="{x + bw / 2 - 16}" y="{y}" width="32" height="{bh}" fill="{MUSTARD}" opacity="0.9"/>'
        f'<rect x="{x}" y="{y}" width="{bw}" height="{bh}" rx="10" fill="none" {ol(w)}/>'
    )


# --- perks / drawbacks ---------------------------------------------------------------------------------------------


def skill_all_round(ic: Icon) -> str:
    fill = ic.two("#FFE58A", "#F6C12B", 0.58)
    return (
        tile(ic, "teal")
        + ground(256, 432, 130)
        + f'<polygon points="{star_points(256, 256, 176, 76)}" fill="{fill}" {ol()}/>'
        + gloss(206, 196, 26, 12)
    )


def skill_quick_legs(ic: Icon) -> str:
    return (
        tile(ic, "green")
        + speed_lines(56, 214, 3, 50, 110)
        + paw(ic, 236, 356, 1.05, -18)
        + paw(ic, 362, 216, 1.05, -18)
        + gloss(200, 340, 14, 7)
    )


def skill_jumpy(ic: Icon) -> str:
    """Runner drawback (90 sanity at night): a startled bunny, ears stiff, eyes wide, sweat drop, "!" and shakes."""
    fur = ic.two(WHITE, "#E2DCEA", 0.62)
    drop = ic.two("#C9F1F6", "#63C8D4", 0.55)
    shakes = "".join(
        f'<path d="M{x},{y} q{d * 14},18 0,36 q{-d * 14},18 0,36" fill="none" {ol(10)}/>'
        for x, y, d in ((70, 250, 1), (96, 330, 1), (442, 250, -1), (416, 330, -1))
    )
    return (
        tile(ic, "orange")
        + shakes
        # ears straight up and stretched
        + f'<ellipse cx="196" cy="140" rx="36" ry="108" fill="{fur}" {ol()} transform="rotate(-4 196 140)"/>'
        f'<ellipse cx="316" cy="140" rx="36" ry="108" fill="{fur}" {ol()} transform="rotate(4 316 140)"/>'
        f'<ellipse cx="196" cy="150" rx="14" ry="74" fill="{PINK}" transform="rotate(-4 196 150)"/>'
        f'<ellipse cx="316" cy="150" rx="14" ry="74" fill="{PINK}" transform="rotate(4 316 150)"/>'
        # head
        + f'<ellipse cx="256" cy="330" rx="146" ry="124" fill="{fur}" {ol()}/>'
        # wide eyes, tiny pupils
        + f'<circle cx="200" cy="312" r="42" fill="{WHITE}" {ol(w)}/><circle cx="312" cy="312" r="42" fill="{WHITE}" {ol(w)}/>'
        f'<circle cx="200" cy="316" r="12" fill="{INK}"/><circle cx="312" cy="316" r="12" fill="{INK}"/>'
        # worried brows
        + f'<path d="M166,262 L222,244" fill="none" {ol(10)}/><path d="M346,262 L290,244" fill="none" {ol(10)}/>'
        # nose + small open "o" mouth
        + f'<path d="M244,364 L268,364 L256,378 Z" fill="{PINK}" {ol(6)}/>'
        f'<ellipse cx="256" cy="408" rx="18" ry="20" fill="{INK}"/>'
        # sweat drop on the side of the head
        + f'<path d="M392,214 Q424,262 410,284 Q396,302 376,284 Q362,262 392,214 Z" fill="{drop}" {ol(w)}/>'
        # "!" over the head
        + text("!", 440, 150, 130, MUSTARD)
        + gloss(172, 292, 18, 8)
    )


def skill_grill_master(ic: Icon) -> str:
    sausage = ic.two(*SAUSAGE, 0.55)
    flame = ic.two(*FLAME, 0.5)
    bars = "".join(f'<path d="M{x},230 L{x},330" stroke="{INK}" stroke-width="12" stroke-linecap="round"/>' for x in (140, 200, 260, 320, 380))
    return (
        tile(ic, "violet")
        + "".join(
            f'<path d="M{x},440 Q{x - 34},392 {x},350 Q{x + 8},384 {x + 26},372 Q{x + 40},410 {x},440 Z" fill="{flame}" {ol(w)}/>'
            for x in (160, 256, 352)
        )
        + f'<rect x="96" y="226" width="320" height="110" rx="20" fill="#5D6173" {ol()}/>'
        + bars
        + f'<rect x="120" y="188" width="272" height="76" rx="38" fill="{sausage}" {ol()}/>'
        + "".join(f'<path d="M{x},204 L{x + 26},248" stroke="#8A3524" stroke-width="10" stroke-linecap="round"/>' for x in (184, 240, 296))
        + gloss(160, 206, 22, 8, -10)
    )


def skill_short_strides(ic: Icon) -> str:
    shell = ic.two("#FFC48A", "#E0803C", 0.58)
    body = ic.two("#CDE8A8", "#9CC774", 0.6)
    return (
        tile(ic, "mustard")
        + ground(256, 420, 170)
        + f'<path d="M90,396 Q90,350 150,350 L380,350 Q420,350 430,300 L446,250 Q458,232 470,250 L454,330 Q440,400 380,402 L120,402 Q90,402 90,396 Z" fill="{body}" {ol()}/>'
        + f'<circle cx="236" cy="262" r="118" fill="{shell}" {ol()}/>'
        + f'<path d="M236,262 m-14,0 a14,14 0 1 1 28,0 a40,40 0 1 1 -80,0 a66,66 0 1 1 132,0" fill="none" {ol(12)}/>'
        + f'<circle cx="452" cy="244" r="10" fill="{INK}"/>'
        + gloss(188, 196, 26, 12)
    )


def skill_bear_hug(ic: Icon) -> str:
    return (
        tile(ic, "green")
        + ground(256, 444, 170)
        + box(ic, 96, 320, 160, 112)
        + box(ic, 256, 320, 160, 112)
        + box(ic, 176, 196, 160, 120)
        + gloss(206, 222, 18, 8, -10)
    )


def skill_heavy_load(ic: Icon) -> str:
    bell = ic.two("#8A8FA3", "#5D6173", 0.55)
    return (
        tile(ic, "orange")
        + ground(256, 440, 150)
        + f'<path d="M180,236 Q180,120 256,120 Q332,120 332,236" fill="none" stroke="{INK}" stroke-width="64" stroke-linecap="round"/>'
        + f'<path d="M180,236 Q180,120 256,120 Q332,120 332,236" fill="none" stroke="#A9AEBF" stroke-width="34" stroke-linecap="round"/>'
        + f'<ellipse cx="256" cy="320" rx="150" ry="116" fill="{bell}" {ol()}/>'
        + text("3", 256, 366, 136)
        + gloss(170, 272, 26, 12)
    )


def skill_sweet_talk(ic: Icon) -> str:
    bubble = ic.two(WHITE, "#F1ECE4", 0.6)
    coin = ic.two("#FFE58A", "#F6C12B", 0.55)
    return (
        tile(ic, "teal")
        + f'<path d="M86,110 L426,110 Q456,110 456,140 L456,280 Q456,310 426,310 L230,310 L150,380 L166,310 L86,310 Q56,310 56,280 L56,140 Q56,110 86,110 Z" fill="{bubble}" {ol()}/>'
        + "".join(f'<circle cx="{x}" cy="210" r="22" fill="{PINK}" {ol(w)}/>' for x in (176, 256, 336))
        + f'<circle cx="382" cy="384" r="84" fill="{coin}" {ol()}/>'
        + text("$", 382, 418, 104)
        + gloss(110, 146, 22, 10, -15)
    )


def skill_short_fuse(ic: Icon) -> str:
    face = ic.two(WHITE, "#F1ECE4", 0.6)
    rim = ic.two("#FFE58A", "#F6C12B", 0.55)
    return (
        tile(ic, "mustard")
        + f'<rect x="226" y="62" width="60" height="44" rx="12" fill="{rim}" {ol(w)}/>'
        + f'<circle cx="256" cy="280" r="170" fill="{rim}" {ol()}/>'
        + f'<circle cx="256" cy="280" r="128" fill="{face}" {ol(w)}/>'
        + f'<path d="M256,280 L256,180" stroke="{INK}" stroke-width="16" stroke-linecap="round"/>'
        + f'<path d="M256,280 L326,320" stroke="{INK}" stroke-width="16" stroke-linecap="round"/>'
        + f'<path d="M256,152 A128,128 0 0 1 367,216 L256,280 Z" fill="#F08A3C" opacity="0.55"/>'
        + f'<circle cx="256" cy="280" r="14" fill="{INK}"/>'
        + gloss(168, 184, 24, 10)
    )


def skill_wide_awake(ic: Icon) -> str:
    white = ic.two(WHITE, "#E9E1F2", 0.6)
    iris = ic.two("#A99BFF", "#6A5ACD", 0.55)
    moon = ic.two("#FFF3B8", "#F6C12B", 0.6)
    return (
        tile(ic, "violet")
        + f'<path d="M378,70 A60,60 0 1 0 446,150 A48,48 0 1 1 378,70 Z" fill="{moon}" {ol(w)}/>'
        + f'<path d="M60,290 Q256,90 452,290 Q256,470 60,290 Z" fill="{white}" {ol()}/>'
        + f'<circle cx="256" cy="290" r="88" fill="{iris}" {ol(w)}/>'
        + f'<circle cx="256" cy="290" r="40" fill="{INK}"/>'
        + f'<circle cx="282" cy="262" r="16" fill="{WHITE}"/>'
        + gloss(150, 244, 22, 9, -20)
    )


def skill_daydreamer(ic: Icon) -> str:
    sun = ic.two("#FFE58A", "#F6C12B", 0.58)
    rays = "".join(
        f'<path d="M{256 + 150 * math.cos(math.radians(a)):.1f},{300 + 150 * math.sin(math.radians(a)):.1f} '
        f'L{256 + 200 * math.cos(math.radians(a)):.1f},{300 + 200 * math.sin(math.radians(a)):.1f}" {ol(20)}/>'
        for a in range(0, 360, 45)
    )
    rays_fill = rays.replace(f'stroke="{INK}" stroke-width="20"', f'stroke="{MUSTARD}" stroke-width="8"')
    return (
        tile(ic, "orange")
        + rays
        + rays_fill
        + f'<circle cx="256" cy="300" r="118" fill="{sun}" {ol()}/>'
        + f'<path d="M196,300 Q216,318 236,300 M276,300 Q296,318 316,300" fill="none" {ol(12)}/>'
        + f'<path d="M226,348 Q256,364 286,348" fill="none" {ol(10)}/>'
        + text("z", 400, 128, 84)
        + text("z", 340, 86, 60)
        + gloss(206, 240, 24, 10)
    )


def skill_double_shot(ic: Icon) -> str:
    cup = ic.two(WHITE, "#F1ECE4", 0.6)
    sleeve = ic.two("#E6B98A", "#B07A4E", 0.55)
    steam = "".join(
        f'<path d="M{x},150 Q{x - 24},118 {x},86 Q{x + 24},54 {x},26" fill="none" {ol(14)}/>' for x in (206, 306)
    )
    return (
        tile(ic, "teal")
        + steam
        + ground(256, 452, 130)
        + f'<path d="M140,176 L372,176 L346,436 Q344,450 330,450 L182,450 Q168,450 166,436 Z" fill="{cup}" {ol()}/>'
        + f'<path d="M154,268 L358,268 L348,370 L164,370 Z" fill="{sleeve}" {ol(w)}/>'
        + f'<rect x="124" y="150" width="264" height="44" rx="16" fill="{BROWN}" {ol()}/>'
        + gloss(186, 220, 18, 8, -10)
    )


def skill_spooked(ic: Icon) -> str:
    ghost = ic.two(WHITE, "#E2DDF0", 0.6)
    return (
        tile(ic, "mustard")
        + f'<path d="M116,420 L116,250 Q116,96 256,96 Q396,96 396,250 L396,420 Q372,392 348,420 Q324,448 302,420 Q278,392 256,420 Q232,448 210,420 Q186,392 162,420 Q138,448 116,420 Z" fill="{ghost}" {ol()}/>'
        + f'<ellipse cx="208" cy="240" rx="26" ry="36" fill="{INK}"/><ellipse cx="304" cy="240" rx="26" ry="36" fill="{INK}"/>'
        + f'<ellipse cx="256" cy="318" rx="30" ry="36" fill="{INK}"/>'
        + gloss(170, 170, 26, 12)
    )


def skill_rally_cry(ic: Icon) -> str:
    horn = ic.two("#FFE58A", "#F6C12B", 0.55)
    return (
        tile(ic, "green")
        + f'<path d="M110,220 L250,150 L250,380 L110,310 Z" fill="{horn}" {ol()}/>'
        + f'<rect x="64" y="212" width="58" height="106" rx="14" fill="#5D6173" {ol()}/>'
        + f'<path d="M150,316 L170,410 L222,410 L206,338" fill="#5D6173" {ol(w)}/>'
        + "".join(
            f'<path d="M{300 + i * 46},{190 - i * 22} Q{350 + i * 56},265 {300 + i * 46},{340 + i * 22}" fill="none" {ol(16)}/>'
            for i in range(3)
        )
        + gloss(170, 216, 20, 9, -25)
    )


def skill_big_ego(ic: Icon) -> str:
    gold = ic.two("#FFE58A", "#F6C12B", 0.58)
    return (
        tile(ic, "orange")
        + ground(256, 424, 160)
        + f'<path d="M86,380 L66,160 L170,250 L256,110 L342,250 L446,160 L426,380 Z" fill="{gold}" {ol()}/>'
        + f'<rect x="86" y="360" width="340" height="56" rx="16" fill="{gold}" {ol()}/>'
        + f'<circle cx="256" cy="300" r="30" fill="{PINK}" {ol(w)}/>'
        + f'<circle cx="160" cy="316" r="20" fill="#63C8D4" {ol(w)}/><circle cx="352" cy="316" r="20" fill="#63C8D4" {ol(w)}/>'
        + gloss(150, 214, 20, 9)
    )


ICONS = {
    "skill_all_round": skill_all_round,
    "skill_quick_legs": skill_quick_legs,
    "skill_jumpy": skill_jumpy,
    "skill_grill_master": skill_grill_master,
    "skill_short_strides": skill_short_strides,
    "skill_bear_hug": skill_bear_hug,
    "skill_heavy_load": skill_heavy_load,
    "skill_sweet_talk": skill_sweet_talk,
    "skill_short_fuse": skill_short_fuse,
    "skill_wide_awake": skill_wide_awake,
    "skill_daydreamer": skill_daydreamer,
    "skill_double_shot": skill_double_shot,
    "skill_spooked": skill_spooked,
    "skill_rally_cry": skill_rally_cry,
    "skill_big_ego": skill_big_ego,
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        page = browser.new_page(viewport={"width": 512, "height": 512})
        for key, build in ICONS.items():
            ic = Icon()
            svg = ic.svg(build(ic))
            (OUT / f"{key}.svg").write_text(svg, encoding="utf-8")
            page.set_content(PAGE.format(svg=svg))
            page.evaluate("document.fonts.ready")
            page.wait_for_timeout(150)
            page.screenshot(path=str(OUT / f"{key}.png"), clip={"x": 0, "y": 0, "width": 512, "height": 512}, omit_background=True)
            print(OUT / f"{key}.png")
        browser.close()


if __name__ == "__main__":
    main()
