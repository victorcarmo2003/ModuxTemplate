"""Simulator shop: illustrated assets (keep-color stickers + white tintables), placed at reference coords (1275x769).
Each icon is drawn in a 100x100 local box, then translated/scaled into its measured box."""
OUT = "#1B1B1F"  # sticker outline


def place(id_, box, body, extra='data-keep-color="true"', vb=100):
    x, y, w, h = box
    s = min(w, h) / vb
    ox, oy = x + (w - vb * s) / 2, y + (h - vb * s) / 2
    return f'<g id="{id_}" {extra}><g transform="translate({ox:.2f},{oy:.2f}) scale({s:.4f})">{body}</g></g>'


def stroke(w=7):
    return f'stroke="{OUT}" stroke-width="{w}" stroke-linejoin="round" stroke-linecap="round" paint-order="stroke"'


# ---------- icons (100x100) ----------
BASKET = (
    f'<path d="M30,40 C30,10 70,10 72,38" fill="none" stroke="{OUT}" stroke-width="13" stroke-linecap="round"/>'
    f'<path d="M30,40 C30,10 70,10 72,38" fill="none" stroke="#B9C4CC" stroke-width="6" stroke-linecap="round"/>'
    f'<path d="M8,42 L56,30 L94,44 L82,84 L36,94 L18,80 Z" fill="#E83B4E" {stroke(7)}/>'
    '<path d="M8,42 L56,30 L94,44 L46,58 Z" fill="#9E1E33"/>'
    '<path d="M46,58 L94,44 L82,84 L36,94 Z" fill="#C82A3F"/>'
    '<path d="M14,47 L44,60 L36,88 L22,78 Z" fill="#F2566A"/>'
)
SWORD = (
    f'<path d="M86,8 L94,16 L46,64 L36,54 Z" fill="#E9EEF3" {stroke(7)}/>'
    '<path d="M86,8 L94,16 L66,44 L60,38 Z" fill="#FFFFFF"/>'
    '<path d="M40,58 L46,64 L94,16 L90,12 Z" fill="#AEB8C2"/>'
    f'<path d="M22,48 L30,40 L60,70 L52,78 Z" fill="#2E7CF6" {stroke(7)}/>'
    f'<path d="M36,62 L20,78" stroke="{OUT}" stroke-width="15" stroke-linecap="round"/>'
    '<path d="M36,62 L20,78" stroke="#1F5FD0" stroke-width="8" stroke-linecap="round"/>'
    f'<circle cx="14" cy="84" r="8" fill="#2E7CF6" {stroke(6)}/>'
)
MAP = (
    f'<path d="M10,14 C30,8 50,20 70,12 L90,16 C86,40 94,60 88,86 C66,92 46,80 26,90 L12,86 C16,62 6,38 10,14 Z" '
    f'fill="#F2C998" {stroke(7)}/>'
    '<path d="M18,22 C34,18 50,28 68,20 L82,24 C80,44 86,62 82,80 C64,84 46,74 30,82 L20,80 C22,60 14,40 18,22 Z" fill="#F7D9B0"/>'
    '<path d="M28,38 C38,30 52,40 46,52 C40,62 56,66 62,60" fill="none" stroke="#D49A6A" stroke-width="3" '
    'stroke-dasharray="5 4"/>'
    '<path d="M54,50 L68,64 M68,50 L54,64" stroke="#E2444A" stroke-width="6" stroke-linecap="round"/>'
)
FACES = (
    f'<rect x="44" y="20" width="44" height="46" rx="6" fill="#FFC21A" {stroke(7)}/>'
    f'<path d="M40,92 C40,70 92,70 92,92 Z" fill="#3B8CF0" {stroke(7)}/>'
    f'<rect x="8" y="10" width="50" height="54" rx="7" fill="#FFD21F" {stroke(7)}/>'
    f'<path d="M4,94 C4,66 62,66 62,94 Z" fill="#4AA0FF" {stroke(7)}/>'
    '<circle cx="24" cy="34" r="4" fill="#1B1B1F"/><circle cx="42" cy="34" r="4" fill="#1B1B1F"/>'
    '<path d="M22,46 C28,54 38,54 44,46" fill="none" stroke="#1B1B1F" stroke-width="3.5" stroke-linecap="round"/>'
    '<circle cx="62" cy="40" r="3.5" fill="#1B1B1F"/><circle cx="76" cy="40" r="3.5" fill="#1B1B1F"/>'
    '<path d="M60,50 C66,56 72,56 78,50" fill="none" stroke="#1B1B1F" stroke-width="3" stroke-linecap="round"/>'
)


def gear_path(cx=50, cy=50, r_out=44, r_in=34, teeth=8):
    import math
    pts = []
    for i in range(teeth * 4):
        a = math.radians(i * 360 / (teeth * 4) - 90)
        r = r_out if (i % 4) in (1, 2) else r_in
        pts.append(f"{cx + r * math.cos(a):.1f},{cy + r * math.sin(a):.1f}")
    return "M" + " L".join(pts) + " Z"


def lobe_gear(cx=50, cy=50, n=6, r_body=31, r_lobe=13, light="#E4E8EE"):
    """Chunky 6-lobe cartoon gear: dark union underneath (sticker outline), light union on top."""
    import math
    centers = [(cx + (r_body + 3) * math.cos(math.radians(i * 60 - 90)),
                cy + (r_body + 3) * math.sin(math.radians(i * 60 - 90))) for i in range(n)]

    def union(fill, grow):
        return (f'<circle cx="{cx}" cy="{cy}" r="{r_body + grow}" fill="{fill}"/>'
                + "".join(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r_lobe + grow}" fill="{fill}"/>' for x, y in centers))

    return union(OUT, 4.5) + union(light, 0) + '<path d="M26,64 A27,27 0 0 0 74,64" fill="none" stroke="#B8C2CE" stroke-width="7"/>'


GEAR = lobe_gear() + f'<circle cx="50" cy="50" r="11" fill="#7F8A98" {stroke(6)}/>'
GIFT = (
    f'<rect x="12" y="44" width="76" height="50" rx="4" fill="#E8304A" {stroke(7)}/>'
    f'<rect x="6" y="30" width="88" height="20" rx="4" fill="#F0485E" {stroke(7)}/>'
    '<rect x="43" y="30" width="14" height="64" fill="#FFC21A"/>'
    f'<path d="M50,30 C30,4 14,22 30,30 Z M50,30 C70,4 86,22 70,30 Z" fill="none" stroke="{OUT}" stroke-width="12" '
    'stroke-linejoin="round"/>'
    '<path d="M50,30 C30,4 14,22 30,30 Z M50,30 C70,4 86,22 70,30 Z" fill="none" stroke="#FFC21A" stroke-width="6" '
    'stroke-linejoin="round"/>'
)
EXCL = (f'<path d="M38,6 L66,10 L54,66 L36,62 Z" fill="#F01E2C" {stroke(7)}/>'
        f'<circle cx="40" cy="86" r="10" fill="#F01E2C" {stroke(7)}/>')


def robux(fill="#FFFFFF"):
    import math
    hexp = "M" + " L".join(f"{50 + 44 * math.cos(math.radians(a)):.1f},{50 + 44 * math.sin(math.radians(a)):.1f}"
                           for a in range(-90, 270, 60)) + " Z"
    hin = "M" + " L".join(f"{50 + 24 * math.cos(math.radians(a)):.1f},{50 + 24 * math.sin(math.radians(a)):.1f}"
                          for a in range(-90, 270, 60)) + " Z"
    return (f'<path d="{hexp}" fill="{fill}" {stroke(9)}/>'
            f'<path d="{hin}" fill="none" stroke="{OUT}" stroke-width="7" stroke-linejoin="round"/>'
            f'<rect x="41" y="41" width="18" height="18" fill="{fill}"/>')


CASH = ""
for (x, y) in [(10, 52), (40, 62), (26, 34), (56, 44), (44, 18)]:
    CASH += (f'<path d="M{x},{y + 10} L{x + 26},{y} L{x + 44},{y + 10} L{x + 18},{y + 20} Z" fill="#2FBE5C" {stroke(6)}/>'
             f'<path d="M{x},{y + 10} L{x + 18},{y + 20} L{x + 18},{y + 32} L{x},{y + 22} Z" fill="#1E8A40" {stroke(6)}/>'
             f'<path d="M{x + 18},{y + 20} L{x + 44},{y + 10} L{x + 44},{y + 22} L{x + 18},{y + 32} Z" fill="#26A64E" {stroke(6)}/>'
             f'<path d="M{x + 13},{y + 5} L{x + 22},{y + 1} L{x + 40},{y + 11} L{x + 31},{y + 15} Z" fill="#F7B21B"/>')
CATAPULT = (
    f'<path d="M10,78 L84,64 L88,74 L14,90 Z" fill="#8A4B22" {stroke(7)}/>'
    f'<path d="M28,80 L46,40 L56,42 L40,82 Z" fill="#A85C2B" {stroke(7)}/>'
    f'<path d="M50,72 L66,42 L74,46 L60,74 Z" fill="#A85C2B" {stroke(7)}/>'
    f'<path d="M30,62 L82,18" stroke="{OUT}" stroke-width="15" stroke-linecap="round"/>'
    '<path d="M30,62 L82,18" stroke="#C06A30" stroke-width="8" stroke-linecap="round"/>'
    f'<circle cx="84" cy="14" r="10" fill="#6B6F78" {stroke(6)}/>'
    f'<circle cx="22" cy="86" r="9" fill="#5A3416" {stroke(6)}/><circle cx="76" cy="74" r="9" fill="#5A3416" {stroke(6)}/>'
)
SPARKLE = '<path d="M50,0 C54,40 60,46 100,50 C60,54 54,60 50,100 C46,60 40,54 0,50 C40,46 46,40 50,0 Z" fill="#FFFFFF"/>'


def scallop(n=14, r_out=48, r_in=43, cx=50, cy=50):
    import math
    pts = []
    for i in range(n * 2):
        a = math.radians(i * 180 / n)
        r = r_out if i % 2 == 0 else r_in
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    d = f"M{pts[0][0]:.1f},{pts[0][1]:.1f}"
    for i in range(1, len(pts) + 1, 2):
        c = pts[i % len(pts)]
        e = pts[(i + 1) % len(pts)]
        d += f" Q{c[0]:.1f},{c[1]:.1f} {e[0]:.1f},{e[1]:.1f}"
    return d + " Z"


BADGE_RING = (
    '<defs><linearGradient id="bg_ring" x1="0" y1="0" x2="0" y2="1">'
    '<stop offset="0" stop-color="#FFFFFF"/><stop offset="0.28" stop-color="#FFC21A"/>'
    '<stop offset="0.62" stop-color="#FF7A1A"/><stop offset="1" stop-color="#F0501A"/></linearGradient></defs>'
    f'<path d="{scallop(14, 49, 44.5)}" fill="#A0281C" stroke="#A0281C" stroke-width="2"/>'
    f'<path d="{scallop(14, 46, 41.5)}" fill="url(#bg_ring)"/>'
    f'<path d="{scallop(14, 37, 33.5)}" fill="#A0281C"/>'
)
BADGE_INNER = f'<path d="{scallop(14, 35.5, 32)}" fill="#FFFFFF"/>'


def rays(n=12, cx=50, cy=50, r=72):
    import math
    out = ""
    for i in range(n):
        a0 = math.radians(i * 360 / n)
        a1 = a0 + math.radians(360 / n / 2)
        out += (f'<path d="M{cx},{cy} L{cx + r * math.cos(a0):.1f},{cy + r * math.sin(a0):.1f} '
                f'L{cx + r * math.cos(a1):.1f},{cy + r * math.sin(a1):.1f} Z" fill="#FFFFFF"/>')
    return out


# Characters: honest stand-ins (real games render the actual models in a ViewportFrame or pre-rendered PNGs)
OWL = (f'<ellipse cx="50" cy="60" rx="30" ry="36" fill="#58B83A" {stroke(6)}/>'
       '<ellipse cx="50" cy="70" rx="16" ry="20" fill="#E57A6B"/>'
       f'<circle cx="38" cy="38" r="12" fill="#FFFFFF" {stroke(4)}/><circle cx="62" cy="38" r="12" fill="#FFFFFF" {stroke(4)}/>'
       '<circle cx="40" cy="40" r="5" fill="#1B1B1F"/><circle cx="60" cy="40" r="5" fill="#1B1B1F"/>'
       '<path d="M46,48 L54,48 L50,58 Z" fill="#9AA6B4"/>'
       f'<path d="M26,26 L34,14 L42,26 M58,26 L66,14 L74,26" fill="#3E8E2A" {stroke(4)}/>')
HOUSE = (f'<path d="M22,50 L50,24 L78,50 L78,82 L22,82 Z" fill="#E88A2E" {stroke(6)}/>'
         f'<path d="M14,52 L50,18 L86,52" fill="none" stroke="{OUT}" stroke-width="10" stroke-linejoin="round"/>'
         '<path d="M14,52 L50,18 L86,52" fill="none" stroke="#C0601C" stroke-width="5" stroke-linejoin="round"/>'
         '<circle cx="40" cy="56" r="6" fill="#FFFFFF"/><circle cx="60" cy="56" r="6" fill="#FFFFFF"/>'
         '<circle cx="41" cy="57" r="3" fill="#1B1B1F"/><circle cx="59" cy="57" r="3" fill="#1B1B1F"/>'
         '<path d="M42,68 C46,80 56,80 60,68 Z" fill="#E85A7A"/>'
         f'<path d="M30,82 L26,94 M70,82 L74,94" stroke="#C0601C" stroke-width="7" stroke-linecap="round"/>')
BLOCKY = (f'<rect x="34" y="10" width="32" height="26" fill="#5A3A2A" {stroke(5)}/>'
          f'<rect x="36" y="18" width="28" height="20" fill="#E8B48A" {stroke(4)}/>'
          f'<rect x="30" y="38" width="40" height="34" fill="#8BE07A" {stroke(5)}/>'
          f'<rect x="16" y="38" width="14" height="32" fill="#8BE07A" {stroke(5)}/>'
          f'<rect x="70" y="38" width="14" height="32" fill="#8BE07A" {stroke(5)}/>'
          f'<rect x="32" y="72" width="16" height="22" fill="#3A8CE0" {stroke(5)}/>'
          f'<rect x="52" y="72" width="16" height="22" fill="#3A8CE0" {stroke(5)}/>'
          '<rect x="30" y="68" width="40" height="5" fill="#D2563A"/>')


def stud_tile():
    # 16x16 tile: soft rounded square, like the embossed studs on every button/card (white, tinted/faded in engine)
    return ('<rect x="2.5" y="2.5" width="11" height="11" rx="2.5" fill="#FFFFFF" opacity="0.55"/>'
            '<rect x="2.5" y="2.5" width="11" height="11" rx="2.5" fill="none" stroke="#FFFFFF" stroke-width="1.2"/>')


B = ""
B += place("asset-icon_basket", (16, 296, 54, 42), BASKET)
B += place("asset-icon_sword", (94, 295, 48, 46), SWORD)
B += place("asset-icon_map", (20, 372, 48, 44), MAP)
B += place("asset-icon_faces", (92, 374, 50, 42), FACES)
B += place("asset-icon_gear", (13, 448, 36, 36), GEAR)
B += place("asset-icon_gift", (62, 449, 35, 35), GIFT)
B += place("asset-icon_excl", (64, 283, 22, 26), EXCL)
B += place("asset-title_basket", (344, 172, 56, 52), BASKET, 'data-keep-color="true"')  # tilt via Rotation in Roblox
B += place("asset-robux", (420, 515, 26, 26), robux())
B += place("asset-cash", (522, 410, 100, 100), CASH)
B += place("asset-catapult", (804, 410, 100, 100), CATAPULT)
B += place("asset-badge_ring", (500, 395, 142, 142), BADGE_RING)
B += place("asset-badge_inner", (783, 395, 142, 142), BADGE_INNER, 'fill="#FFFFFF"')
B += place("asset-rays", (380, 214, 112, 112), rays(14, r=80), '')
B += place("asset-sparkle", (600, 425, 18, 18), SPARKLE, '')
B += place("asset-char_owl", (402, 238, 72, 76), OWL)
B += place("asset-char_house", (521, 240, 72, 72), HOUSE)
B += place("asset-char_blocky", (639, 238, 76, 78), BLOCKY)
B += f'<g id="asset-tile_stud" transform="translate(1200,700)">{stud_tile()}</g>'

svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="1275" height="769" viewBox="0 0 1275 769">'
       f'<rect id="bg" width="1275" height="769" fill="#6A8CFF"/>{B}</svg>')
open("icons.svg", "w", encoding="utf-8").write(svg)
print("ok")
