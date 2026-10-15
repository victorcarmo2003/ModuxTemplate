"""Anomaly Book "photos" (TASK-335), 512x352 PNG, one per Content.Journal page, in the game's sticker style.

Same language as shop_icons.py (style guide §7.1): thick Ink outline, hard two-tone shading, white gloss blobs,
Fredoka One text with an Ink stroke, never the alert red. Each photo is a full-bleed night scene (the AnomalyBook
page puts it inside a white print, ScaleType Crop): spooky but cute, readable at ~180 px wide on a phone.

    python tools/icons/journal_art.py                    # writes Assets/textures/ui/journal/<key>.png (+ .svg)
    python tools/icons/journal_art.py anm_007_walker     # only these keys

Upload: Roblox Studio MCP upload_image (served by `python -m http.server` on 127.0.0.1), ids into
src/Interface/client/Components/AnomalyBook/Images.luau and Assets/textures/ui/_texture_ids.json ("journal/<key>").
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from playwright.sync_api import sync_playwright  # noqa: E402
from shop_icons import CREAM, INK, MUSTARD, PINK, WHITE, Icon, gloss, ol, text, w  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Assets" / "textures" / "ui" / "journal"
WIDTH, HEIGHT = 512, 352

NIGHT_TOP = "#3B3160"
NIGHT_BOTTOM = "#211A33"
ROAD = "#3A3448"
GOLD = "#FFD86B"
TEAL = "#3FA7B5"
GREEN = "#5FA36A"
SLATE = "#8A8FA3"
FUR = ("#E6B98A", "#B07A4E")  # dog-ish fur, top / bottom
SHIRT = ("#7FD1DC", "#3FA7B5")


class Photo(Icon):
    def svg(self, body: str) -> str:  # 512 x 352 instead of the 512 square
        return (
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}">'
            f'<defs>{"".join(self.defs)}</defs>{body}</svg>'
        )


# --- scene pieces ---------------------------------------------------------------------------------------------------


def night(ic: Photo, top: str = NIGHT_TOP, bottom: str = NIGHT_BOTTOM, stars: bool = True, road: bool = True) -> str:
    out = f'<rect x="0" y="0" width="{WIDTH}" height="{HEIGHT}" fill="{ic.soft(top, bottom)}"/>'
    if stars:
        for x, y, r in ((40, 40, 4), (120, 70, 3), (210, 30, 4), (300, 60, 3), (420, 34, 5), (470, 90, 3), (360, 110, 2)):
            out += f'<circle cx="{x}" cy="{y}" r="{r}" fill="{CREAM}" opacity="0.8"/>'
        out += f'<circle cx="460" cy="62" r="26" fill="{CREAM}" opacity="0.9"/><circle cx="472" cy="54" r="22" fill="{top}"/>'
    if road:
        out += f'<rect x="0" y="286" width="{WIDTH}" height="66" fill="{ROAD}"/>'
        out += "".join(f'<rect x="{x}" y="314" width="40" height="8" rx="4" fill="{GOLD}" opacity="0.5"/>' for x in range(16, 512, 90))
    return out


def lamp(x: float, on: bool = True, base: float = 290) -> str:
    out = f'<rect x="{x - 5}" y="{base - 190}" width="10" height="190" fill="#4A4458" {ol(6)}/>'
    out += f'<path d="M{x - 26},{base - 186} L{x + 26},{base - 186} L{x + 16},{base - 206} L{x - 16},{base - 206} Z" fill="#5B6270" {ol(6)}/>'
    if on:
        out += f'<path d="M{x - 22},{base - 186} L{x - 70},{base} L{x + 70},{base} L{x + 22},{base - 186} Z" fill="{GOLD}" opacity="0.18"/>'
        out += f'<ellipse cx="{x}" cy="{base - 182}" rx="16" ry="7" fill="{GOLD}"/>'
    else:
        out += f'<ellipse cx="{x}" cy="{base - 182}" rx="16" ry="7" fill="#2B2233"/>'
    return out


def body(ic: Photo, x: float, y: float, s: float = 1.0, shirt: tuple[str, str] = SHIRT, label: str = "") -> str:
    """Torso + arms of a customer standing at (x, y) = the neck."""
    fill = ic.two(*shirt, 0.55)
    out = (
        f'<g transform="translate({x} {y}) scale({s})">'
        f'<path d="M-54,4 Q-62,60 -58,120 L58,120 Q62,60 54,4 Q0,-10 -54,4Z" fill="{fill}" {ol(10)}/>'
        f'<path d="M-54,10 Q-82,50 -74,96" fill="none" {ol(22)}/><path d="M-54,10 Q-82,50 -74,96" fill="none" stroke="{shirt[1]}" stroke-width="12" stroke-linecap="round"/>'
        f'<path d="M54,10 Q82,50 74,96" fill="none" {ol(22)}/><path d="M54,10 Q82,50 74,96" fill="none" stroke="{shirt[1]}" stroke-width="12" stroke-linecap="round"/>'
    )
    if label:
        out += text(label, 0, 66, 34, WHITE)
    return out + "</g>"


def head(ic: Photo, x: float, y: float, s: float = 1.0, face: str = "normal", back: bool = False) -> str:
    """Round dog-ish head centred at (x, y). face: normal | blank | white | stare | closed | none."""
    fur = ic.two(*FUR, 0.6)
    out = f'<g transform="translate({x} {y}) scale({s})">'
    out += f'<path d="M-58,-30 Q-86,-74 -60,-86 Q-34,-70 -30,-48 Z" fill="{FUR[1]}" {ol(10)}/>'
    out += f'<path d="M58,-30 Q86,-74 60,-86 Q34,-70 30,-48 Z" fill="{FUR[1]}" {ol(10)}/>'
    out += f'<ellipse cx="0" cy="0" rx="66" ry="60" fill="{fur}" {ol(10)}/>'
    if back:  # the back of the head: a tuft and the collar, no face
        out += f'<path d="M-20,-50 Q0,-70 20,-50" fill="none" stroke="{FUR[1]}" stroke-width="10" stroke-linecap="round"/>'
        out += f'<path d="M-30,10 Q0,28 30,10" fill="none" stroke="{FUR[1]}" stroke-width="8" stroke-linecap="round"/>'
        return out + gloss(-34, -26, 12, 6) + "</g>"
    if face != "blank":
        out += f'<ellipse cx="0" cy="22" rx="34" ry="24" fill="{CREAM}"/>'
        out += f'<ellipse cx="0" cy="12" rx="11" ry="8" fill="{INK}"/>'
    if face == "normal":
        out += f'<circle cx="-24" cy="-10" r="9" fill="{INK}"/><circle cx="24" cy="-10" r="9" fill="{INK}"/>'
        out += f'<circle cx="-21" cy="-13" r="3" fill="{WHITE}"/><circle cx="27" cy="-13" r="3" fill="{WHITE}"/>'
        out += f'<path d="M-12,30 Q0,40 12,30" fill="none" {ol(6)}/>'
    elif face == "white":
        out += f'<circle cx="-26" cy="-12" r="17" fill="{WHITE}" {ol(6)}/><circle cx="26" cy="-12" r="17" fill="{WHITE}" {ol(6)}/>'
        out += f'<path d="M-40,26 Q0,64 40,26 Q0,40 -40,26Z" fill="{WHITE}" {ol(6)}/>'
        out += "".join(f'<path d="M{x0},{30 + abs(x0) * -0.1} L{x0},{44 - abs(x0) * 0.2}" {ol(3)}/>' for x0 in (-24, -12, 0, 12, 24))
    elif face == "stare":
        out += f'<circle cx="-26" cy="-12" r="16" fill="{WHITE}" {ol(6)}/><circle cx="26" cy="-12" r="16" fill="{WHITE}" {ol(6)}/>'
        out += f'<circle cx="-26" cy="-10" r="6" fill="{INK}"/><circle cx="26" cy="-10" r="6" fill="{INK}"/>'
        out += f'<path d="M-12,34 L12,34" {ol(6)}/>'
    elif face == "closed":
        out += f'<path d="M-34,-10 Q-24,-2 -14,-10" fill="none" {ol(6)}/><path d="M14,-10 Q24,-2 34,-10" fill="none" {ol(6)}/>'
        out += f'<path d="M-10,32 Q0,38 10,32" fill="none" {ol(6)}/>'
    return out + gloss(-34, -26, 12, 6) + "</g>"


def customer(ic: Photo, x: float, s: float = 1.0, face: str = "normal", label: str = "", shirt=SHIRT, lift: float = 0) -> str:
    y = 186 - lift
    return body(ic, x, y + 40 * s, s, shirt, label) + head(ic, x, y, s, face)


def counter() -> str:
    """The serving window edge of the trailer at the bottom (the photo is taken from inside)."""
    return (
        f'<rect x="-10" y="300" width="532" height="70" fill="#F3E6C8" {ol(10)}/>'
        f'<rect x="-10" y="300" width="532" height="14" fill="{MUSTARD}" {ol(8)}/>'
    )


def mark(t: str, x: float, y: float, size: int = 44, fill: str = MUSTARD) -> str:
    return text(t, x, y, size, fill)


# --- photos ---------------------------------------------------------------------------------------------------------


def blank_folks(ic: Photo) -> str:
    return night(ic) + customer(ic, 256, 1.1, "blank") + counter() + mark("?", 360, 120)


def shaker(ic: Photo) -> str:
    lines = "".join(
        f'<path d="M{x},{y} q-10,8 0,16 q10,8 0,16" fill="none" stroke="{CREAM}" stroke-width="7" stroke-linecap="round"/>'
        for x, y in ((150, 150), (128, 210), (362, 150), (384, 210))
    )
    ghost = f'<g opacity="0.35">{customer(ic, 244, 1.1)}</g>'
    return night(ic) + ghost + customer(ic, 262, 1.1) + lines + counter()


def wrong_food(ic: Photo) -> str:
    bun = ic.two("#F7C77E", "#D8913F", 0.55)
    sausage = ic.two("#9BE08F", "#4FA35E", 0.5)
    puff = "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#C9C3D6" opacity="0.85" {ol(6)}/>' for x, y, r in ((300, 120, 30), (336, 92, 24), (270, 92, 20)))
    stink = "".join(
        f'<path d="M{x},150 q-12,-20 0,-40 q12,-20 0,-40" fill="none" stroke="{GREEN}" stroke-width="8" stroke-linecap="round"/>'
        for x in (190, 236)
    )
    return (
        night(ic, "#5B4A6E", "#3A2E4A", stars=False, road=False)
        + f'<rect x="0" y="230" width="512" height="122" fill="#C9B79A" {ol(10)}/>'
        + f'<ellipse cx="256" cy="232" rx="170" ry="40" fill="{bun}" {ol()}/>'
        + f'<rect x="96" y="186" width="320" height="50" rx="25" fill="{sausage}" {ol()}/>'
        + f'<ellipse cx="256" cy="246" rx="176" ry="34" fill="{bun}" {ol()}/>'
        + gloss(170, 198, 30, 8, -5)
        + stink
        + puff
    )


def turned_neck(ic: Photo) -> str:
    arcs = f'<path d="M190,90 Q256,40 322,90" fill="none" stroke="{CREAM}" stroke-width="8" stroke-linecap="round" stroke-dasharray="14 12"/>'
    arcs += f'<path d="M322,90 l-4,-22 l22,8 Z" fill="{CREAM}"/>'
    return night(ic) + body(ic, 256, 226, 1.1) + head(ic, 256, 186, 1.1, back=True) + arcs + counter()


def blackout(ic: Photo) -> str:
    box = (
        f'<rect x="300" y="120" width="120" height="150" rx="10" fill="#5B6270" {ol()}/>'
        f'<rect x="318" y="140" width="84" height="40" rx="6" fill="{CREAM}" {ol(6)}/>'
        + text("BREAKER", 360, 168, 18, INK)
        + f'<rect x="350" y="196" width="20" height="56" rx="8" fill="{MUSTARD}" {ol(8)}/>'
    )
    eyes = f'<ellipse cx="100" cy="140" rx="16" ry="10" fill="{GOLD}"/><ellipse cx="146" cy="140" rx="16" ry="10" fill="{GOLD}"/>'
    shade = f'<path d="M40,352 Q60,120 124,100 Q190,120 210,352 Z" fill="#000000" opacity="0.55"/>'
    beam = f'<path d="M0,352 L330,190 L360,230 L40,352 Z" fill="{GOLD}" opacity="0.16"/>'
    return f'<rect x="0" y="0" width="{WIDTH}" height="{HEIGHT}" fill="#120E1A"/>' + shade + eyes + beam + box + mark("!", 450, 110, 56)


def white_eyes(ic: Photo) -> str:
    return night(ic) + customer(ic, 256, 1.15, "white") + counter()


def copies(ic: Photo) -> str:
    return night(ic) + customer(ic, 160, 0.95, "normal", "HI") + customer(ic, 352, 0.95, "normal", "IH") + counter() + mark("?", 352, 70, 40)


def raincoat(ic: Photo) -> str:
    coat = ("#FFE07A", "#F2C230")
    hood = ic.two(*coat, 0.6)
    drops = "".join(
        f'<path d="M{x},{y} q-7,12 0,16 q7,-4 0,-16Z" fill="#8BE3EE" {ol(4)}/>' for x, y in ((160, 210), (350, 240), (186, 280), (330, 180), (380, 290))
    )
    return (
        night(ic)
        + body(ic, 256, 226, 1.1, coat)
        + f'<path d="M180,190 Q180,96 256,92 Q332,96 332,190 Q256,170 180,190Z" fill="{hood}" {ol()}/>'
        + head(ic, 256, 186, 0.92, "closed")
        + f'<path d="M190,170 Q256,120 322,170" fill="none" stroke="{coat[1]}" stroke-width="16"/>'
        + drops
        + counter()
    )


def bell(ic: Photo) -> str:
    metal = ic.two("#FFE58A", "#E0A21E", 0.55)
    waves = "".join(
        f'<path d="M{170 - d},{90 + d * 0.4} Q{150 - d},{140} {170 - d},{190 - d * 0.4}" fill="none" stroke="{CREAM}" stroke-width="7" stroke-linecap="round"/>'
        f'<path d="M{342 + d},{90 + d * 0.4} Q{362 + d},{140} {342 + d},{190 - d * 0.4}" fill="none" stroke="{CREAM}" stroke-width="7" stroke-linecap="round"/>'
        for d in (0, 26)
    )
    moth = "".join(
        f'<g transform="translate({x} {y})"><path d="M0,0 q-18,-16 -22,4 q8,10 22,-4 q18,-16 22,4 q-8,10 -22,-4Z" fill="{SLATE}" {ol(4)}/></g>'
        for x, y in ((80, 250), (430, 230), (120, 300))
    )
    return (
        night(ic)
        + lamp(60, False)
        + lamp(452, False)
        + f'<path d="M206,190 Q206,84 256,80 Q306,84 306,190 L320,206 L192,206 Z" fill="{metal}" {ol()}/>'
        + f'<circle cx="256" cy="214" r="14" fill="{metal}" {ol(8)}/><rect x="248" y="58" width="16" height="24" rx="6" fill="{metal}" {ol(8)}/>'
        + gloss(230, 130, 10, 26, 0)
        + waves
        + moth
        + mark("3", 256, 290, 58, CREAM)
    )


def big_head(ic: Photo) -> str:
    return night(ic) + body(ic, 256, 236, 0.85) + head(ic, 256, 150, 1.65) + counter()


def walker(ic: Photo) -> str:
    figure = (
        f'<rect x="300" y="60" width="44" height="230" rx="20" fill="#120E1A" {ol(8)}/>'
        f'<ellipse cx="322" cy="54" rx="26" ry="30" fill="#120E1A" {ol(8)}/>'
        f'<circle cx="314" cy="52" r="4" fill="{GOLD}"/><circle cx="330" cy="52" r="4" fill="{GOLD}"/>'
        f'<path d="M300,90 L270,250" {ol(14)}/><path d="M344,90 L374,250" {ol(14)}/>'
    )
    buzz = "".join(f'<path d="M{x},60 l10,-14 l6,12 l10,-16" fill="none" stroke="{GOLD}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>' for x in (90,))
    return night(ic) + lamp(110) + buzz + figure + mark("ZZT", 140, 200, 30, GOLD)


def floater(ic: Photo) -> str:
    gap = f'<path d="M210,330 L302,330" stroke="{CREAM}" stroke-width="6" stroke-dasharray="10 10" stroke-linecap="round"/>'
    arrows = f'<path d="M150,250 l0,-40 m-12,14 l12,-14 l12,14" fill="none" stroke="{CREAM}" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>'
    legs = f'<rect x="222" y="300" width="22" height="20" fill="{INK}"/><rect x="268" y="300" width="22" height="20" fill="{INK}"/>'
    return night(ic) + f'<g transform="translate(0 -30)">{legs}{customer(ic, 256, 0.95)}</g>' + gap + arrows


def crawler(ic: Photo) -> str:
    rim = 'stroke="#7A6E9C" stroke-width="6" stroke-linejoin="round" stroke-linecap="round"'
    beast = (
        "".join(f'<path d="M{x},{236} L{x - 22},{292}" {rim}/><path d="M{x},{236} L{x - 22},{292}" stroke="#120E1A" stroke-width="10" stroke-linecap="round"/>' for x in (140, 196, 318, 376))
        + f'<path d="M90,262 Q150,176 262,186 Q370,178 424,246 Q340,236 262,244 Q160,240 90,262Z" fill="#120E1A" {rim}/>'
        + f'<circle cx="430" cy="232" r="30" fill="#120E1A" {rim}/>'
        + f'<circle cx="420" cy="226" r="7" fill="{GOLD}"/><circle cx="442" cy="226" r="7" fill="{GOLD}"/>'
    )
    scratch = "".join(f'<path d="M{x},120 l30,-40" stroke="{CREAM}" stroke-width="8" stroke-linecap="round"/>' for x in (70, 92, 114))
    return night(ic) + beast + scratch + mark("SKRR", 380, 120, 32, CREAM)


def starer(ic: Photo) -> str:
    rays = "".join(f'<path d="M256,186 L{x},{y}" stroke="{CREAM}" stroke-width="3" opacity="0.3"/>' for x, y in ((0, 0), (512, 0), (0, 352), (512, 352)))
    return night(ic) + rays + customer(ic, 256, 1.1, "stare") + counter() + mark("...", 380, 110, 40, CREAM)


def grin(ic: Photo) -> str:
    window = f'<rect x="40" y="30" width="432" height="270" rx="16" fill="none" {ol(18)}/>'
    face = (
        f'<ellipse cx="256" cy="180" rx="210" ry="150" fill="#120E1A"/>'
        f'<circle cx="180" cy="130" r="22" fill="{WHITE}" {ol(6)}/><circle cx="332" cy="130" r="22" fill="{WHITE}" {ol(6)}/>'
        f'<path d="M120,190 Q256,330 392,190 Q256,240 120,190Z" fill="{WHITE}" {ol(8)}/>'
        + "".join(f'<path d="M{x},205 L{x},{240 if 170 < x < 342 else 222}" {ol(5)}/>' for x in range(150, 380, 30))
    )
    whispers = "".join(text("hide", x, y, s, CREAM) for x, y, s in ((70, 330, 26), (440, 320, 30), (120, 60, 20), (420, 70, 22)))
    return night(ic, stars=False, road=False) + face + window + whispers


def long_car(ic: Photo) -> str:
    paint = ic.two("#6E7584", "#4A4458", 0.5)
    car = (
        f'<rect x="20" y="200" width="420" height="70" rx="22" fill="{paint}" {ol()}/>'
        f'<path d="M90,200 L130,150 L330,150 L370,200 Z" fill="{paint}" {ol()}/>'
        f'<path d="M140,160 L200,160 L200,198 L110,198 Z" fill="#2B2233" {ol(6)}/><path d="M214,160 L320,160 L350,198 L214,198 Z" fill="#2B2233" {ol(6)}/>'
        f'<circle cx="110" cy="276" r="28" fill="{INK}"/><circle cx="350" cy="276" r="28" fill="{INK}"/>'
        f'<ellipse cx="434" cy="228" rx="14" ry="12" fill="{GOLD}" {ol(6)}/>'
    )
    beam = f'<path d="M440,220 L512,150 L512,320 L440,236 Z" fill="{GOLD}" opacity="0.55"/>'
    return night(ic) + car + beam + mark("!", 470, 120, 52)


def roof_walker(ic: Photo) -> str:
    roof = f'<rect x="-10" y="210" width="532" height="160" fill="#F3E6C8" {ol(10)}/><rect x="-10" y="196" width="532" height="22" rx="8" fill="{MUSTARD}" {ol(8)}/>'
    steps = "".join(
        f'<ellipse cx="{x}" cy="{y}" rx="22" ry="12" fill="#120E1A" transform="rotate(-12 {x} {y})"/>' for x, y in ((90, 180), (190, 160), (290, 180), (390, 160))
    )
    return night(ic, road=False) + roof + steps + mark("THUD", 256, 90, 40, CREAM)


def knock(ic: Photo) -> str:
    door = (
        f'<rect x="150" y="40" width="212" height="312" rx="10" fill="#B07A4E" {ol()}/>'
        f'<rect x="176" y="70" width="160" height="110" rx="8" fill="#8E5E38" {ol(8)}/>'
        f'<circle cx="330" cy="230" r="12" fill="{MUSTARD}" {ol(6)}/>'
    )
    bursts = text("KNOCK", 90, 120, 30, CREAM) + text("KNOCK", 430, 200, 30, CREAM) + text("KNOCK", 110, 290, 26, CREAM)
    return f'<rect x="0" y="0" width="{WIDTH}" height="{HEIGHT}" fill="#4A3D57"/>' + door + bursts


def hush(ic: Photo) -> str:
    fog = "".join(
        f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="26" fill="{CREAM}" opacity="0.32"/>' for x, y, rx in ((100, 290, 160), (360, 300, 180), (240, 260, 200), (60, 250, 120))
    )
    mart = (
        f'<rect x="330" y="120" width="170" height="170" fill="{TEAL}" {ol()}/>'
        f'<rect x="350" y="180" width="60" height="110" fill="{GOLD}" {ol(8)}/>'
        + text("MART", 415, 160, 30, WHITE)
    )
    return night(ic) + lamp(70, False) + lamp(190, False) + lamp(300, True) + mart + fog


PHOTOS = {
    "anm_001_blank_folks": blank_folks,
    "anm_011_shaker": shaker,
    "anm_002_wrong_food": wrong_food,
    "anm_012_turned_neck": turned_neck,
    "anm_020_blackout": blackout,
    "anm_013_white_eyes": white_eyes,
    "anm_004_copies": copies,
    "anm_005_raincoat_lady": raincoat,
    "anm_003_stopped_clock": bell,
    "anm_014_big_head": big_head,
    "anm_007_walker": walker,
    "anm_015_floater": floater,
    "anm_017_crawler": crawler,
    "anm_016_starer": starer,
    "anm_018_grin": grin,
    "anm_008_long_car": long_car,
    "anm_019_roof_walker": roof_walker,
    "anm_009_knock": knock,
    "anm_010_hush": hush,
}

PAGE = """<!doctype html><html><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Fredoka+One&display=block" rel="stylesheet">
<style>html,body{{margin:0;background:transparent}}</style></head><body>{svg}</body></html>"""


def main() -> None:
    only = set(sys.argv[1:])
    OUT.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        page = browser.new_page(viewport={"width": WIDTH, "height": HEIGHT})
        for key, build in PHOTOS.items():
            if only and key not in only:
                continue
            ic = Photo()
            svg = ic.svg(build(ic))
            (OUT / f"{key}.svg").write_text(svg, encoding="utf-8")
            page.set_content(PAGE.format(svg=svg))
            page.evaluate("document.fonts.ready")
            page.wait_for_timeout(150)
            page.screenshot(path=str(OUT / f"{key}.png"), clip={"x": 0, "y": 0, "width": WIDTH, "height": HEIGHT})
            print(OUT / f"{key}.png")
        browser.close()


if __name__ == "__main__":
    main()
