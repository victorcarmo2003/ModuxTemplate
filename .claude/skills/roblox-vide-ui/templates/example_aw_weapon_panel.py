"""Worked example v2 (Studio-verified 2026-10-05, after detail pass): AW weapon panel, icons measured at 5-7x. --bg adds a flat world color for capture compares."""
import os
import subprocess
import sys

SKILL = os.path.expanduser("~/.claude/skills/roblox-vide-ui/scripts")
sys.path.insert(0, SKILL)
import shapes as S  # noqa: E402

FONTS = subprocess.run([sys.executable, f"{SKILL}/roblox_fonts.py", "Oswald"], capture_output=True,
                       text=True).stdout.strip()
P, SEC, ACC, DNG = "#FEFEFE", "#B2B4B6", "#F9C914", "#D8282A"
BROWN = "#A08A80"  # remaining part of an in-progress streak (measured, ~60% over the world)
RIM = "#C8641E"  # dark orange rim around amber art (the AW "glow" is a thin rim, not a bloom)
BG = len(sys.argv) > 1 and sys.argv[1] == "--bg"


def g(id_, body, extra=""):
    return f'<g id="{id_}" {extra}>{body}</g>'


def tg(id_, body, color, extra=""):
    return g(id_, body.replace("#FFFFFF", color), extra)


def rect(x, y, w, h, fill="#FFFFFF", extra=""):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" {extra}/>'


def circ(cx, cy, r, fill="#FFFFFF"):
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}"/>'


def poly(*pts, fill="#FFFFFF"):
    return f'<path d="M{" L".join(f"{x},{y}" for x, y in pts)} Z" fill="{fill}"/>'


def line(x1, y1, x2, y2, w=2):
    return f'<path d="M{x1},{y1} L{x2},{y2}" stroke="#FFFFFF" stroke-width="{w}" stroke-linecap="round"/>'


B = ""
if BG:
    B += rect(0, 0, 1920, 1080, "#5A5F64", 'id="bg"')
B += '<g id="group-weapon" data-anchor="br">'
B += rect(640, 330, 650, 430, "none")

# --- equipment column -------------------------------------------------------------------------
B += f'<rect id="frame-slot_a" x="658" y="471" width="16" height="16" fill="{DNG}"/>'
B += f'<rect id="frame-slot_b" x="658" y="499" width="16" height="16" fill="{P}"/>'
launcher = (rect(726, 443, 29, 16) + rect(711, 465, 66, 54) + rect(726, 528, 33, 15)
            + f'<circle cx="775" cy="448" r="19.5" fill="none" stroke="#FFFFFF" stroke-width="3.5"/>')
B += g("asset-exo_launcher", launcher)
B += f'<rect id="frame-exo_divider" x="681" y="563" width="120" height="4" fill="{SEC}" opacity="0.75"/>'

# ability: hub square + 6 nodes (measured 6x), small squares above/below, blocks top/bottom
hub = (741.4, 644.2)
nodes = [(723, 625, 6), (772.5, 613.7, 4.2), (790.8, 634.7, 7.5), (771.3, 657.2, 3), (695.8, 676.3, 4.2),
         (690, 638.8, 6)]
ability = (rect(723.3, 588, 35.4, 16.2) + rect(723.3, 686, 35.4, 16.2)
           + rect(737.4, 613.8, 7.4, 7) + rect(737.4, 669.2, 7.4, 7) + rect(737.5, 640.6, 7.8, 7.4))
ability += "".join(line(*hub, x, y, 2.2) + circ(x, y, r) for x, y, r in nodes)
B += g("asset-exo_ability", ability)

# battery: grey cap separated by a gap, shell r5 stroke 2.5; level fill = rounded rect clipped at the level
B += tg("asset-battery_cap", rect(626, 595, 21, 5), "#BFC1C3", 'opacity="0.85"')
B += g("asset-battery_shell",
       '<rect x="618.25" y="605.95" width="36.5" height="84.5" rx="5" fill="none" stroke="#FFFFFF" stroke-width="2.5"/>',
       'opacity="0.9"')
# fill shown at 35%; code builds it as Clip(level) > rounded Frame (r3) anchored bottom
B += f'<rect id="frame-battery_fill" x="626" y="655.8" width="22" height="28" rx="3" fill="{P}"/>'
B += f'<rect id="guide-battery_fill_flat_top" x="626" y="655.8" width="22" height="4" fill="{P}"/>'
B += f'<rect id="frame-vdivider" x="852" y="485" width="3" height="182" fill="{SEC}" opacity="0.6"/>'

# --- ammo ----------------------------------------------------------------------------------------
B += (f'<text id="text-round" x="966" y="574" font-family="Oswald" font-weight="300" font-size="172" '
      f'fill="{P}" text-anchor="middle">25</text>')
B += f'<rect id="frame-ammo_divider" x="884" y="597" width="174" height="4" fill="{SEC}" opacity="0.8"/>'
B += (f'<text id="text-reserve" x="976" y="683" font-family="Oswald" font-weight="300" font-size="86" '
      f'fill="{SEC}" text-anchor="middle">120</text>')

# --- streak column -------------------------------------------------------------------------------
# selector: chevron arms (1099,539.6)->(1118.6,557.5)->(1099,575.4); dot centered on the chevron axis
CY = 557.5
B += g("asset-selector",
       f'<path d="M1099,539.6 L1118.6,{CY} L1099,575.4" fill="none" stroke="#FFFFFF" stroke-width="2.4" '
       f'stroke-linejoin="miter"/>' + circ(1096.6, CY, 3.6))

# in-progress streak: ONE silhouette (railgun turret). Remaining part brown; earned part = same image in amber
# inside a clip whose width is the progress (here clipped at x=1188.9).
gun = (poly((1174.3, 344), (1202.4, 344), (1194.3, 367.6), (1165, 367.6))
       + rect(1194.3, 365, 59.3, 2.6) + rect(1165, 371.9, 87, 2.2)
       + poly((1255, 361.9), (1274.3, 361.9), (1270, 377.9), (1250.3, 377.9))
       + poly((1181.9, 377.9), (1211, 377.9), (1194.3, 427.9), (1165, 427.9))
       + poly((1218, 378), (1224, 378), (1207.9, 428), (1201, 428))
       + rect(1153.9, 432, 94, 2.3))
B += tg("asset-streak_progress", gun, BROWN, 'opacity="0.75"')
B += ('<clipPath id="guide-progress_clip"><rect x="1150" y="340" width="38.9" height="100"/></clipPath>'
      f'<g id="guide-progress_fill" clip-path="url(#guide-progress_clip)">{gun.replace("#FFFFFF", ACC)}</g>')
B += f'<rect id="frame-streak_div_a" x="1151" y="452" width="104" height="5" fill="{SEC}" opacity="0.7"/>'

# selected streak: drone (two rotors) with turret on top, joined by a 2.4 px stem (measured 5x)
drone = (S.arc(35.5, 4.4, 0, 360, cx=1168, cy=561.6) + S.arc(35.5, 4.4, 0, 360, cx=1241.7, cy=561.6)
         + rect(1162.6, 556, 11.4, 11.4) + rect(1236, 556, 11.4, 11.4)
         + rect(1188.4, 483, 7.6, 45) + rect(1213.6, 483, 8, 45)        # turret side bars
         + rect(1199.2, 507.6, 11.2, 20.4)                              # turret body
         + rect(1203.4, 528, 2.4, 72)                                   # stem through the rotors
         + rect(1199.2, 600, 11.2, 20.4))                               # lower block
B += tg("asset-streak_selected", drone, ACC, f'data-glow="2" data-glow-color="{RIM}"')
B += f'<rect id="frame-streak_div_b" x="1151" y="646" width="104" height="5" fill="{SEC}" opacity="0.7"/>'
squares = [(1157, 688, 20), (1187, 670, 23), (1220, 677, 30), (1153, 720, 15), (1173, 739, 15),
           (1195, 737, 11), (1227, 719, 39), (1185, 717, 5), (1197, 713, 5), (1203, 722, 7)]
B += tg("asset-streak_idle", "".join(rect(x, y, s, s) for x, y, s in squares), "#A4A6A8", 'opacity="0.75"')
B += "</g>"

svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">'
       f"{FONTS}{B}</svg>")
open("mock_bg.svg" if BG else "mock.svg", "w", encoding="utf-8").write(svg)
print("ok")
