"""Generates the ticket sprites (AST-109/110/111/112) as SVG (Assets/ui/source/*.svg) and renders PNGs (Assets/ui/ticket/*.png).
Original art, flat toy style: Ink outline, Cream/Mustard/Teal palette. Run: python build_ticket.py
Needs playwright + chromium. Tintable sprites are drawn in neutral white/grey (ImageColor3 does the colour)."""
import math, os, random
from playwright.sync_api import sync_playwright

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "ticket")
INK = "#2B2233"
S = {}  # name -> (w, h, svg)


def svg(w, h, body, defs=""):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><defs>{defs}</defs>{body}</svg>'


def grad(id, top, bot):
    return f'<linearGradient id="{id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bot}"/></linearGradient>'


# ---- AST-110 bun ----
S["bun_base"] = (256, 96, svg(256, 96,
    f'<rect x="8" y="8" width="240" height="80" rx="38" fill="url(#c)" stroke="{INK}" stroke-width="4"/>'
    f'<rect x="26" y="22" width="204" height="48" rx="24" fill="url(#w)" stroke="#B07A3C" stroke-width="3"/>'
    '<rect x="40" y="28" width="176" height="8" rx="4" fill="#FFF1D6" opacity=".7"/>'
    '<rect x="26" y="74" width="204" height="6" rx="3" fill="#B97F3E" opacity=".55"/>',
    grad("c", "#F4D9A0", "#D9A35E") + grad("w", "#E5BE80", "#F6DDA8")))
seeds = [(60, 30, -20), (100, 24, 15), (140, 32, -5), (180, 26, 25), (214, 34, -30), (82, 56, 10), (122, 62, -25), (160, 58, 20), (198, 60, -10), (44, 54, 30)]
S["bun_lid"] = (256, 96, svg(256, 96,
    f'<rect x="8" y="8" width="240" height="80" rx="40" fill="url(#c)" stroke="{INK}" stroke-width="4"/>'
    '<rect x="24" y="14" width="140" height="10" rx="5" fill="#FFF3CF" opacity=".8"/>'
    + "".join(f'<ellipse cx="{x+8}" cy="{y+10}" rx="6" ry="3" fill="#FFF8EA" stroke="#B07A3C" stroke-width="1.5" transform="rotate({r} {x+8} {y+10})"/>' for x, y, r in seeds)
    + '<rect x="26" y="74" width="204" height="6" rx="3" fill="#B97F3E" opacity=".45"/>',
    grad("c", "#F6DEA6", "#D9A35E")))


# ---- AST-109 sausage ----
def sausage(top, bot, marks):
    m = ""
    if marks:
        for x in range(46, 220, 32):
            m += f'<path d="M{x} 18 L{x+16} 46" stroke="#4E2210" stroke-width="7" stroke-linecap="round" opacity=".85"/>'
    return svg(256, 64,
        '<clipPath id="k"><rect x="8" y="10" width="240" height="44" rx="22"/></clipPath>'
        f'<rect x="8" y="10" width="240" height="44" rx="22" fill="url(#c)" stroke="{INK}" stroke-width="4"/>'
        f'<g clip-path="url(#k)">{m}</g>'
        '<rect x="26" y="17" width="150" height="6" rx="3" fill="#FFFFFF" opacity=".35"/>',
        grad("c", top, bot))


S["sausage_grilled"] = (256, 64, sausage("#C2602F", "#7E3519", True))
S["sausage_raw"] = (256, 64, sausage("#E9A08F", "#C9706A", False))


# ---- AST-111 toppings ----
def wave(x0, x1, cy, amp, n, step=4):
    pts = []
    x = x0
    while x <= x1:
        t = (x - x0) / (x1 - x0)
        pts.append((x, cy + amp * math.sin(t * n * 2 * math.pi)))
        x += step
    return "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in pts)


wv = wave(26, 230, 32, 15, 4)
S["sauce_zigzag"] = (256, 64, svg(256, 64,
    f'<path d="{wv}" fill="none" stroke="{INK}" stroke-width="28" stroke-linecap="round" stroke-linejoin="round"/>'
    f'<path d="{wv}" fill="none" stroke="#C9CCD8" stroke-width="20" stroke-linecap="round" stroke-linejoin="round"/>'
    f'<path d="{wv}" fill="none" stroke="#FFFFFF" stroke-width="14" stroke-linecap="round" stroke-linejoin="round" transform="translate(0 -2)"/>'))
S["medallion"] = (128, 128, svg(128, 128,
    f'<circle cx="64" cy="64" r="58" fill="#FFF8EA" stroke="{INK}" stroke-width="6"/>'
    '<circle cx="64" cy="64" r="46" fill="#FFF1D6" stroke="#3FA7B5" stroke-width="6"/>'
    '<path d="M30 52 A38 38 0 0 1 58 28" fill="none" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round" opacity=".8"/>'))


def strands(seed, n, lo, hi, w, cols, xr, yr, bend, angle_jit):
    r = random.Random(seed)
    items = []
    for _ in range(n):
        cx = r.uniform(*xr)
        cy = r.uniform(*yr)
        L = r.uniform(lo, hi)
        a = r.uniform(-angle_jit, angle_jit) + r.choice([0, 180])
        dx = math.cos(math.radians(a)) * L / 2
        dy = math.sin(math.radians(a)) * L / 2
        b = r.uniform(-bend, bend)
        d = f"M{cx-dx:.1f} {cy-dy:.1f} Q{cx+b:.1f} {cy+b*0.6:.1f} {cx+dx:.1f} {cy+dy:.1f}"
        items.append((d, r.choice(cols)))
    ink = "".join(f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="{w+5}" stroke-linecap="round"/>' for d, _ in items)
    col = "".join(f'<path d="{d}" fill="none" stroke="{c}" stroke-width="{w}" stroke-linecap="round"/>' for d, c in items)
    return ink + col


S["cheese_shred"] = (256, 64, svg(256, 64, strands(7, 34, 22, 34, 7, ["#FFD45A", "#FFD45A", "#F2BC3C", "#E8A92A"], (44, 212), (16, 48), 6, 40)))
S["potato_sticks"] = (256, 64, svg(256, 64, strands(11, 20, 46, 66, 7, ["#F7D27A", "#F7D27A", "#E9B95C", "#D9A440"], (60, 196), (16, 48), 8, 24)))


def bacon():
    def y(base, x, ph):
        return base + 5 * math.sin((x / 256) * 5 * math.pi * 2 + ph)
    xs = list(range(14, 243, 4))
    path = "M" + " L".join(f"{x} {y(14, x, 0):.1f}" for x in xs) + " L" + " L".join(f"{x} {y(50, x, .8):.1f}" for x in reversed(xs)) + " Z"
    stripes = "".join(
        f'<path d="M' + " L".join(f"{x} {y(yy, x, .4):.1f}" for x in xs) + '" fill="none" stroke="#F3B7A0" stroke-width="7" stroke-linecap="round"/>'
        for yy in (26, 38))
    return svg(256, 64, f'<clipPath id="k"><path d="{path}"/></clipPath><path d="{path}" fill="#C9533E" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/><g clip-path="url(#k)">{stripes}</g>')


S["bacon_strip"] = (256, 64, bacon())


# ---- AST-112 ticket ----
def chamfer(x, y, w, h, c):
    return f"{x+c},{y} {x+w-c},{y} {x+w},{y+c} {x+w},{y+h-c} {x+w-c},{y+h} {x+c},{y+h} {x},{y+h-c} {x},{y+c}"


S["ticket_paper"] = (128, 128, svg(128, 128,
    f'<polygon points="{chamfer(8,13,112,108,20)}" fill="{INK}" opacity=".18"/>'
    f'<polygon points="{chamfer(8,8,112,108,20)}" fill="url(#p)" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>',
    grad("p", "#FFF8EA", "#FBE3B8")))
S["ticket_pin"] = (64, 64, svg(64, 64,
    f'<circle cx="32" cy="35" r="24" fill="{INK}" opacity=".2"/>'
    f'<circle cx="32" cy="32" r="24" fill="url(#t)" stroke="{INK}" stroke-width="4"/>'
    '<ellipse cx="25" cy="23" rx="8" ry="5" fill="#FFFFFF" opacity=".6" transform="rotate(-30 25 23)"/>',
    grad("t", "#63C8D4", "#3FA7B5")))


def band(fill, line):
    return svg(64, 64, f'<rect width="64" height="64" fill="{fill}"/><rect y="0" width="64" height="3" fill="{line}"/><rect y="61" width="64" height="3" fill="{line}"/>')


S["ticket_band_cream"] = (64, 64, band("#FFF8EA", "#EBD8AE"))
S["ticket_band_mustard"] = (64, 64, band("#FCE7A6", "#E9C766"))

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_page()
        for name, (w, h, body) in S.items():
            open(os.path.join(HERE, f"{name}.svg"), "w", encoding="utf-8").write(body)
            pg.set_viewport_size({"width": w, "height": h})
            pg.set_content(f'<html><body style="margin:0;background:transparent">{body}</body></html>')
            pg.screenshot(path=os.path.join(OUT, f"{name}.png"), omit_background=True, clip={"x": 0, "y": 0, "width": w, "height": h})
            print(name, w, h)
        b.close()
