"""The Ashen Reliquary — RPG inventory mockup (1920x1080). Ornaments are vector UI (drawn); item art and the
character are labelled placeholders. Ids: asset-* (exported PNGs), frame-*/text-* (native), guide-* (ignored)."""
import math
import os
import subprocess
import sys

SKILL = os.path.expanduser("~/.claude/skills/roblox-vide-ui/scripts")
FONTS = subprocess.run([sys.executable, f"{SKILL}/roblox_fonts.py", "Grenze Gotisch", "Merriweather", "Fondamento",
                        "Source Sans Pro"], capture_output=True, text=True).stdout.strip()

# palette
BG0, BG1 = "#120E0B", "#1E1712"
GOLD, GOLD_HI, GOLD_LO = "#C9A45C", "#F3D88B", "#6B4E24"
EMBER = "#E0662A"
TXT, TXT2, TXT3 = "#EDE3CF", "#A89A82", "#6E6353"
RAR = {"common": "#C8C8C8", "magic": "#6E8BFF", "rare": "#FFE15C", "epic": "#B86BFF", "legendary": "#FF8A1F"}
HP, MP, ST = ("#E0453A", "#8E1B1B"), ("#4F7BFF", "#1E3A9E"), ("#C9D84A", "#5E7A1C")

DEFS = f"""<defs>
<linearGradient id="gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{GOLD_HI}"/>
<stop offset="0.45" stop-color="{GOLD}"/><stop offset="1" stop-color="{GOLD_LO}"/></linearGradient>
<linearGradient id="goldH" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="{GOLD}" stop-opacity="0"/>
<stop offset="0.5" stop-color="{GOLD_HI}"/><stop offset="1" stop-color="{GOLD}" stop-opacity="0"/></linearGradient>
<linearGradient id="panelBg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{BG1}"/><stop offset="1" stop-color="{BG0}"/></linearGradient>
</defs>"""


def g(id_, body, extra=""):
    return f'<g id="{id_}" {extra}>{body}</g>'


def kc(id_, body, extra=""):
    return g(id_, body, 'data-keep-color="true" ' + extra)


def rect(x, y, w, h, fill, extra=""):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" {extra}/>'


def text(id_, x, y, s, size, fam, fill, weight=400, anchor="start", style="normal", spacing=0, extra=""):
    ls = f'letter-spacing="{spacing}"' if spacing else ""
    return (f'<text id="{id_}" x="{x}" y="{y}" font-family="{fam}" font-weight="{weight}" font-style="{style}" '
            f'font-size="{size}" fill="{fill}" text-anchor="{anchor}" {ls} {extra}>{s}</text>')


def diamond(cx, cy, r, fill="url(#gold)", stroke=None):
    st = f'stroke="{stroke}" stroke-width="1.5"' if stroke else ""
    return f'<path d="M{cx},{cy - r} L{cx + r},{cy} L{cx},{cy + r} L{cx - r},{cy} Z" fill="{fill}" {st}/>'


# ---------------- ornaments (vector UI) ----------------
def corner_ornament(x, y, sx=1, sy=1):
    """Top-left filigree, mirrored by sx/sy. 64x64 box anchored at the frame corner."""
    t = f'transform="translate({x},{y}) scale({sx},{sy})"'
    return (f'<g {t}>'
            f'<path d="M6,58 L6,14 Q6,6 14,6 L58,6" fill="none" stroke="url(#gold)" stroke-width="3"/>'
            f'<path d="M14,58 L14,20 Q14,14 20,14 L58,14" fill="none" stroke="{GOLD}" stroke-width="1.2" opacity="0.8"/>'
            f'<path d="M22,40 C22,26 30,22 40,22 C34,26 30,30 30,38 C30,44 34,46 38,44" fill="none" stroke="url(#gold)" stroke-width="2.2" stroke-linecap="round"/>'
            f'<path d="M40,22 C46,22 50,26 48,30" fill="none" stroke="url(#gold)" stroke-width="2.2" stroke-linecap="round"/>'
            f'{diamond(6, 6, 7, stroke=GOLD_LO)}'
            f'<circle cx="38" cy="44" r="2.4" fill="{GOLD_HI}"/><circle cx="48" cy="30" r="2" fill="{GOLD_HI}"/>'
            f'</g>')


def panel_frame(x, y, w, h):
    """Ornate frame drawn at real size; exported as 9-slice (corners 64 px)."""
    body = (f'<rect x="{x + 3}" y="{y + 3}" width="{w - 6}" height="{h - 6}" fill="none" stroke="url(#gold)" stroke-width="3"/>'
            f'<rect x="{x + 11}" y="{y + 11}" width="{w - 22}" height="{h - 22}" fill="none" stroke="{GOLD}" stroke-width="1.2" opacity="0.7"/>')
    body += corner_ornament(x, y) + corner_ornament(x + w, y, -1, 1)
    body += corner_ornament(x, y + h, 1, -1) + corner_ornament(x + w, y + h, -1, -1)
    return body


def divider_h(cx, cy, w):
    return (f'<rect x="{cx - w / 2}" y="{cy - 0.75}" width="{w}" height="1.5" fill="url(#goldH)"/>'
            + diamond(cx, cy, 6, stroke=GOLD_LO) + diamond(cx - 16, cy, 2.5, GOLD) + diamond(cx + 16, cy, 2.5, GOLD))


def divider_v(cx, cy, h):
    return (f'<g transform="rotate(90 {cx} {cy})">{divider_h(cx, cy, h)}</g>')


def cartouche(cx, cy, w, h):
    x0, x1, y0, y1, p = cx - w / 2, cx + w / 2, cy - h / 2, cy + h / 2, h / 2
    outer = f"M{x0},{cy} L{x0 + p},{y0} L{x1 - p},{y0} L{x1},{cy} L{x1 - p},{y1} L{x0 + p},{y1} Z"
    i = 6
    inner = f"M{x0 + i},{cy} L{x0 + p + i * 0.4},{y0 + i} L{x1 - p - i * 0.4},{y0 + i} L{x1 - i},{cy} L{x1 - p - i * 0.4},{y1 - i} L{x0 + p + i * 0.4},{y1 - i} Z"
    return (f'<path d="{outer}" fill="{BG0}" stroke="url(#gold)" stroke-width="3" stroke-linejoin="miter"/>'
            f'<path d="{inner}" fill="none" stroke="{GOLD}" stroke-width="1" opacity="0.7"/>'
            + diamond(x0 - 4, cy, 5) + diamond(x1 + 4, cy, 5))


def slot_frame(x, y, s):
    """Thin gold border + corner ticks; exported once as a 9-slice (slice 10)."""
    c = 9
    ticks = "".join(f'<path d="{d}" fill="none" stroke="{GOLD_HI}" stroke-width="2"/>' for d in [
        f"M{x},{y + c} L{x},{y} L{x + c},{y}", f"M{x + s - c},{y} L{x + s},{y} L{x + s},{y + c}",
        f"M{x},{y + s - c} L{x},{y + s} L{x + c},{y + s}", f"M{x + s - c},{y + s} L{x + s},{y + s} L{x + s},{y + s - c}"])
    return f'<rect x="{x + 1}" y="{y + 1}" width="{s - 2}" height="{s - 2}" fill="none" stroke="{GOLD_LO}" stroke-width="1.5"/>' + ticks


def close_diamond(cx, cy, r):
    return (diamond(cx, cy, r, BG0, None) + f'<path d="M{cx},{cy - r} L{cx + r},{cy} L{cx},{cy + r} L{cx - r},{cy} Z" fill="none" stroke="url(#gold)" stroke-width="3"/>'
            + f'<path d="M{cx - 8},{cy - 8} L{cx + 8},{cy + 8} M{cx + 8},{cy - 8} L{cx - 8},{cy + 8}" stroke="{TXT}" stroke-width="3" stroke-linecap="round"/>')


def bar_frame(x, y, w, h):
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="2" fill="none" stroke="url(#gold)" stroke-width="1.8"/>'
            + diamond(x - 2, y + h / 2, 6, stroke=GOLD_LO) + diamond(x + w + 2, y + h / 2, 6, stroke=GOLD_LO))


# slot-type glyphs (geometric UI hints, white, 100x100)
GLYPH = {
    "head": "M20,62 C20,30 36,16 50,16 C64,16 80,30 80,62 L80,80 L62,80 L62,58 L38,58 L38,80 L20,80 Z",
    "amulet": "M24,14 C30,44 70,44 76,14 M50,44 L50,52 M50,52 L66,70 L50,90 L34,70 Z",
    "chest": "M30,14 L42,22 L58,22 L70,14 L88,28 L80,48 L72,44 L72,88 L28,88 L28,44 L20,48 L12,28 Z",
    "hands": "M34,88 L34,46 L28,22 M42,46 L40,14 M50,46 L50,12 M58,46 L60,16 M66,50 L78,34 M34,46 L66,46 L66,88 Z",
    "ring": "M50,30 A26,26 0 1 1 49.9,30 Z M50,40 A16,16 0 1 0 50.1,40 Z M42,18 L50,8 L58,18 L50,26 Z",
    "legs": "M28,12 L72,12 L72,30 L62,90 L52,90 L50,40 L48,90 L38,90 L28,30 Z",
    "feet": "M30,12 L52,12 L52,64 L82,74 L82,88 L22,88 L22,70 L30,64 Z",
    "weapon": "M50,6 L58,18 L58,66 L50,72 L42,66 L42,18 Z M26,66 L74,66 L74,74 L26,74 Z M46,74 L54,74 L54,92 L46,92 Z",
    "offhand": "M50,8 L84,20 C84,56 70,80 50,92 C30,80 16,56 16,20 Z",
}


def glyph(id_, x, y, s, kind):
    k = s / 100
    return g(id_, f'<path transform="translate({x},{y}) scale({k})" d="{GLYPH[kind]}" fill="#FFFFFF" fill-rule="evenodd"/>',
             'opacity="0.18"')


def coin(cx, cy, r):
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#gold)" stroke="{GOLD_LO}" stroke-width="2"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r * 0.62}" fill="none" stroke="{GOLD_LO}" stroke-width="1.6"/>'
            + diamond(cx, cy, r * 0.32, GOLD_LO))


# ---------------- layout ----------------
B = rect(0, 0, 1920, 1080, "#2A2F38", 'id="bg"')  # world stand-in
PX, PY, PW, PH = 300, 150, 1320, 780
B += '<g id="group-inventory" data-anchor="mc">'
B += ('<radialGradient id="ember" cx="0.5" cy="1.05" r="0.75"><stop offset="0" stop-color="#7A2E12" stop-opacity="0.55"/>'
      '<stop offset="1" stop-color="#7A2E12" stop-opacity="0"/></radialGradient>'
      '<radialGradient id="vig" cx="0.5" cy="0.45" r="0.75"><stop offset="0.55" stop-color="#000" stop-opacity="0"/>'
      '<stop offset="1" stop-color="#000" stop-opacity="0.55"/></radialGradient>')
B += f'<rect id="frame-panel_bg" x="{PX}" y="{PY}" width="{PW}" height="{PH}" fill="{BG0}"/>'
B += f'<rect id="guide-ember" x="{PX}" y="{PY}" width="{PW}" height="{PH}" fill="url(#ember)"/>'
B += f'<rect id="guide-vig" x="{PX}" y="{PY}" width="{PW}" height="{PH}" fill="url(#vig)"/>'
B += g("guide-panel_frame", panel_frame(PX, PY, PW, PH))
B += kc("asset-panel_frame9", panel_frame(20, 20, 200, 200), 'data-slice="64"')  # 9-slice source, small
B += kc("asset-title_plate", cartouche(960, PY + 2, 440, 64))
B += text("text-title", 960, PY + 18, "Inventory", 46, "Grenze Gotisch", GOLD_HI, 700, "middle")
B += kc("asset-close", close_diamond(PX + PW - 6, PY + 6, 26))

# left: character
B += text("text-char_name", 600, 236, "Kaelen Ashbound", 30, "Merriweather", TXT, 700, "middle")
B += text("text-char_class", 600, 262, "LEVEL 42  ·  TEMPLAR OF THE PYRE", 14, "Source Sans Pro", TXT2, 600, "middle", 2)
B += kc("asset-divider_char", divider_h(600, 284, 420))
# character viewport placeholder (arched)
B += ('<path id="guide-char_arch" d="M480,610 L480,380 C480,320 540,300 600,300 C660,300 720,320 720,380 L720,610 Z" '
      f'fill="{BG1}" stroke="{GOLD_LO}" stroke-width="1.5"/>')
B += text("text-ph_char", 600, 462, "CHARACTER", 14, "Source Sans Pro", TXT3, 600, "middle", 3)
B += text("text-ph_char2", 600, 482, "viewport placeholder", 13, "Source Sans Pro", TXT3, 400, "middle")
SLOT = 76
left = [("head", 300), ("amulet", 386), ("chest", 472), ("hands", 558)]
right = [("ring", 300), ("ring", 386), ("legs", 472), ("feet", 558)]
equipped = {("head", 300): "epic", ("chest", 472): "rare", ("ring", 386): "magic", ("feet", 558): "common"}
for (kind, y) in left:
    B += f'<rect id="frame-eq_{kind}" x="386" y="{y}" width="{SLOT}" height="{SLOT}" fill="{BG1}"/>'
for (kind, y) in right:
    B += f'<rect id="frame-eq_{kind}{y}" x="738" y="{y}" width="{SLOT}" height="{SLOT}" fill="{BG1}"/>'
for (kind, x) in [("weapon", 516), ("offhand", 608)]:
    B += f'<rect id="frame-eq_{kind}" x="{x}" y="630" width="{SLOT}" height="{SLOT}" fill="{BG1}"/>'
B += kc("asset-slot_frame", slot_frame(386, 300, SLOT), 'data-slice="12"')
eq_slots = [(k, 386, y) for k, y in left] + [(k, 738, y) for k, y in right] + [("weapon", 516, 630), ("offhand", 608, 630)]
for k, x, y in eq_slots:
    rar = equipped.get((k, y)) if x == 386 or x == 738 else None
    if (k, y) in equipped and ((x == 386 and (k, y) in [(a, b) for a, b in left]) or (x == 738 and (k, y) in [(a, b) for a, b in right])):
        col = RAR[equipped[(k, y)]]
        B += f'<rect id="guide-eqr_{k}{y}" x="{x + 2}" y="{y + 2}" width="{SLOT - 4}" height="{SLOT - 4}" fill="{col}" opacity="0.14"/>'
        B += f'<rect id="guide-eqb_{k}{y}" x="{x + 2}" y="{y + SLOT - 5}" width="{SLOT - 4}" height="3" fill="{col}"/>'
        B += text(f"guide-eqt_{k}{y}", x + SLOT / 2, y + SLOT / 2 + 4, k.upper(), 10, "Source Sans Pro", TXT3, 600, "middle", 1)
    else:
        kk = GLYPH[k]
        B += f'<path id="guide-eqg_{k}{x}{y}" transform="translate({x + 14},{y + 14}) scale(0.48)" d="{kk}" fill="#FFFFFF" fill-rule="evenodd" opacity="0.13"/>'
    B += f'<g id="guide-sf_{k}{x}{y}">{slot_frame(x, y, SLOT)}</g>'
for kind in GLYPH:
    B += glyph(f"asset-glyph_{kind}", 1700 + list(GLYPH).index(kind) * 0, 40 + list(GLYPH).index(kind) * 70, 56, kind)

# bars
for i, (name, (c0, c1), cur, mx) in enumerate([("Health", HP, 1840, 2210), ("Mana", MP, 620, 980), ("Stamina", ST, 410, 410)]):
    y = 744 + i * 40
    B += text(f"text-bar_{name.lower()}", 380, y + 13, name.upper(), 13, "Source Sans Pro", TXT2, 600, "start", 2)
    B += f'<rect id="frame-bar_{name.lower()}_track" x="476" y="{y}" width="300" height="16" fill="#0A0806"/>'
    B += text(f"text-bar_{name.lower()}_val", 820, y + 13, f"{cur} / {mx}", 13, "Source Sans Pro", TXT, 600, "end")
    fw = 296 * cur / mx
    B += f'<rect id="frame-bar_{name.lower()}_fill" x="478" y="{y + 2}" width="{fw:.0f}" height="12" fill="{c0}"/>'
    B += f'<rect id="guide-bar_{name.lower()}_shade" x="478" y="{y + 8}" width="{fw:.0f}" height="6" fill="{c1}" opacity="0.6"/>'
    if i: B += g(f"guide-bar_frame{i}", bar_frame(476, y, 300, 16))
B += kc("asset-bar_frame", bar_frame(476, 744, 300, 16), 'data-slice="10"')
# attributes
for i, (k, v) in enumerate([("STR", 48), ("DEX", 31), ("INT", 22), ("VIT", 40)]):
    x = 388 + i * 110
    B += f'<rect id="frame-attr_{k.lower()}" x="{x}" y="862" width="96" height="44" fill="{BG1}"/>'
    B += text(f"text-attr_{k.lower()}", x + 12, 890, k, 13, "Source Sans Pro", TXT2, 600, "start", 2)
    B += text(f"text-attr_{k.lower()}_v", x + 84, 892, str(v), 22, "Merriweather", TXT, 900, "end")

B += kc("asset-divider_v", divider_v(880, 540, 640))

# right: tabs + grid
tabs = ["All", "Weapons", "Armor", "Potions", "Materials"]
for i, t in enumerate(tabs):
    x = 925 + i * 131
    B += f'<rect id="frame-tab_{t.lower()}" x="{x}" y="206" width="123" height="38" fill="{BG1 if i else "#3A2216"}"/>'
    if i == 0:
        B += f'<rect id="guide-tab_active" x="{x + 0.75}" y="206.75" width="121.5" height="36.5" fill="none" stroke="{GOLD}" stroke-width="1.5"/>'
        B += f'<rect id="guide-tab_line" x="{x}" y="242" width="123" height="2" fill="{EMBER}"/>'
    B += text(f"text-tab_{t.lower()}", x + 61.5, 231, t.upper(), 14, "Source Sans Pro", GOLD_HI if i == 0 else TXT2, 600, "middle", 2)
GX, GY, GS, GG, COLS, ROWS = 925, 266, 76, 6, 8, 6
items = {(0, 0): ("legendary", "Greatsword", ""), (1, 0): ("rare", "Helm", ""), (2, 0): ("magic", "Potion", "x12"),
         (3, 0): ("magic", "Potion", "x4"), (4, 0): ("common", "Ore", "x37"), (5, 0): ("epic", "Staff", ""),
         (0, 1): ("rare", "Gloves", ""), (1, 1): ("common", "Hide", "x9"), (2, 1): ("epic", "Amulet", ""),
         (3, 1): ("common", "Herb", "x21"), (4, 1): ("magic", "Ring", ""), (0, 2): ("common", "Bread", "x3"),
         (1, 2): ("rare", "Bow", ""), (2, 2): ("legendary", "Rune", "")}
B += kc("asset-hatch", "".join(f'<path d="M{i * 8},0 L{i * 8 - 64},64" stroke="#FFFFFF" stroke-width="2"/>'
                               for i in range(0, 17)), 'transform="translate(1700,700)" opacity="0.06"')
for r in range(ROWS):
    for c in range(COLS):
        x, y = GX + c * (GS + GG), GY + r * (GS + GG)
        B += f'<rect id="frame-cell_{c}_{r}" x="{x}" y="{y}" width="{GS}" height="{GS}" fill="{BG1}"/>'
        if (c, r) in items:
            rar, name, count = items[(c, r)]
            B += f'<rect id="frame-cellr_{c}_{r}" x="{x + 2}" y="{y + 2}" width="{GS - 4}" height="{GS - 4}" fill="{RAR[rar]}" opacity="0.12"/>'
            B += f'<rect id="frame-cellbar_{c}_{r}" x="{x + 2}" y="{y + GS - 5}" width="{GS - 4}" height="3" fill="{RAR[rar]}"/>'
            B += text(f"text-cell_{c}_{r}", x + GS / 2, y + GS / 2 + 4, name.upper(), 10, "Source Sans Pro", TXT3, 600, "middle", 1)
            if count:
                B += text(f"text-cnt_{c}_{r}", x + GS - 6, y + GS - 6, count, 14, "Merriweather", TXT, 700, "end")
# selection glow on the legendary (sibling glow, ember)
B += g("asset-sel_glow", f'<rect x="{GX - 3}" y="{GY - 3}" width="{GS + 6}" height="{GS + 6}" rx="5" fill="none" stroke="{EMBER}" stroke-width="3"/>', 'data-glow="8"')

# footer
B += kc("asset-coin", coin(942, 826, 13))
B += text("text-gold", 964, 834, "12,480", 24, "Merriweather", GOLD_HI, 900)
B += text("text-weight_l", 1180, 816, "WEIGHT", 13, "Source Sans Pro", TXT2, 600, "start", 2)
B += f'<rect id="frame-weight_track" x="1180" y="826" width="260" height="10" fill="#0A0806"/>'
B += text("text-weight_v", 1440, 816, "86 / 120", 13, "Source Sans Pro", TXT, 600, "end")
B += f'<rect id="frame-sort" x="1470" y="804" width="108" height="40" fill="{BG1}"/>'
B += text("text-sort", 1524, 830, "SORT", 14, "Source Sans Pro", GOLD_HI, 600, "middle", 3)

# tooltip (hover on the legendary greatsword)
TX, TY, TW, TH = 1018, 256, 380, 404
B += f'<rect id="frame-tip_bg" x="{TX}" y="{TY}" width="{TW}" height="{TH}" fill="#0D0A08"/>'
B += ('<linearGradient id="band" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FF8A1F" stop-opacity="0.35"/>'
      '<stop offset="1" stop-color="#FF8A1F" stop-opacity="0"/></linearGradient>')
B += f'<rect id="frame-tip_band" x="{TX}" y="{TY}" width="{TW}" height="92" fill="url(#band)"/>'
B += kc("asset-tip_frame9", f'<rect x="21" y="261" width="118" height="118" fill="none" stroke="{RAR["legendary"]}" stroke-width="2"/>' + slot_frame(20, 260, 120), 'data-slice="12"')
B += g("guide-tip_frame", f'<rect x="{TX + 1}" y="{TY + 1}" width="{TW - 2}" height="{TH - 2}" fill="none" stroke="{RAR["legendary"]}" stroke-width="2"/>' + slot_frame(TX, TY, TW).replace(f'width="{TW - 2}" height="{TW - 2}"', 'width="0" height="0"'))
B += text("text-tip_name", TX + 20, TY + 38, "Emberfall, Oath of the", 21, "Merriweather", RAR["legendary"], 700)
B += text("text-tip_name2", TX + 20, TY + 64, "Last Pyre", 21, "Merriweather", RAR["legendary"], 700)
B += text("text-tip_type", TX + 20, TY + 108, "LEGENDARY GREATSWORD", 13, "Source Sans Pro", TXT2, 600, "start", 2)
B += text("text-tip_ilvl", TX + TW - 20, TY + 108, "ITEM LV 40", 13, "Source Sans Pro", TXT3, 600, "end", 2)
B += kc("asset-divider_tip", divider_h(TX + TW / 2, TY + 128, TW - 40))
B += text("text-tip_dmg", TX + 20, TY + 168, "184 – 231", 30, "Merriweather", TXT, 900)
B += text("text-tip_dmgl", TX + 160, TY + 166, "DAMAGE", 13, "Source Sans Pro", TXT2, 600, "start", 2)
for i, (s, col) in enumerate([("+42 Strength", "#7CDB6A"), ("+18% Fire Damage", "#7CDB6A"), ("+6% Critical Chance", "#7CDB6A"),
                              ("Ignites foes on critical hits", RAR["legendary"])]):
    B += text(f"text-tip_s{i}", TX + 36, TY + 204 + i * 26, s, 16, "Source Sans Pro", col, 600)
B += kc("asset-divider_tip2", divider_h(TX + TW / 2, TY + 318, TW - 40))
B += text("text-tip_lore", TX + 20, TY + 348, "“The last pyre burned for a hundred", 15, "Fondamento", TXT2, 400, "start", 0, 'font-style="italic"')
B += text("text-tip_lore2", TX + 20, TY + 368, "years. So shall its oath.”", 15, "Fondamento", TXT2, 400, "start", 0, 'font-style="italic"')
B += kc("asset-coin_s", coin(TX + TW - 86, TY + TH - 22, 7))
B += text("text-tip_sell", TX + TW - 20, TY + TH - 16, "3,420", 15, "Merriweather", GOLD_HI, 700, "end")
B += text("text-tip_sell_l", TX + 20, TY + TH - 16, "SELL VALUE", 12, "Source Sans Pro", TXT3, 600, "start", 2)
B += "</g>"

svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">'
       f"{FONTS}{DEFS}{B}</svg>")
open("mock.svg", "w", encoding="utf-8").write(svg)
print("ok")
