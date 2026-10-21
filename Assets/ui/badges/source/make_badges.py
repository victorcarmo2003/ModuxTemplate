"""Generate the 15 badge icons (docs/design/badges.md) as SVG + HTML, then render 512x512 PNGs with headless Chrome.

Cartoon pass (v2): faces and googly eyes on the objects, thick wobbly ink (SVG displacement filter),
offset sticker shadow, comic bursts, sweat drops and motion marks. Subjects and group colours as v1 (DEC-315).

Usage: python make_badges.py
Output: ../<nn>_<key>.png, source/svg/<key>.svg, source/board.png (5-column contact sheet)
"""

import math
import os
import random
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)
SVG_DIR = os.path.join(HERE, "svg")
HTML_DIR = os.path.join(HERE, "html")
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

INK = "#2B2233"
WHITE = "#FFF8EC"
CREAM = "#FFF1D6"
KETCHUP = "#E2402E"
MUSTARD = "#F6C12B"
TEAL = "#3FA7B5"
BLUSH = "#FF8A7A"
SWEAT = "#9FD3E8"
FONT = "'Fredoka One', 'Fredoka', sans-serif"

# (disc centre, disc edge, ring, burst behind the icon)
THEMES = {
	"day": ("#FFF1C4", "#F6C12B", "#E2402E", "#FFF8EC"),
	"night": ("#4A4F93", "#1B2140", "#3FA7B5", "#5A60A8"),
	"horror": ("#6A1A26", "#140810", "#B8262B", "#3A0C16"),
	"milestone": ("#FFF8EC", "#F3DFA2", "#3FA7B5", "#F6C12B"),
	"dawn": ("#FFC27A", "#6B5BA8", "#F6C12B", "#FFD9A0"),
}

SW = 12
S = f'stroke="{INK}" stroke-width="{SW}" stroke-linejoin="round" stroke-linecap="round"'
S8 = f'stroke="{INK}" stroke-width="8" stroke-linejoin="round" stroke-linecap="round"'


def line(d, w=SW, color=INK, extra=""):
	return f'<path d="{d}" stroke="{color}" stroke-width="{w}" fill="none" stroke-linecap="round" stroke-linejoin="round" {extra}/>'


def star(x, y, r, fill=WHITE):
	p = f"M{x},{y - r} Q{x},{y} {x + r},{y} Q{x},{y} {x},{y + r} Q{x},{y} {x - r},{y} Q{x},{y} {x},{y - r} Z"
	return f'<path d="{p}" fill="{fill}" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>'


def sparkles(pts, fill=WHITE):
	return "".join(star(x, y, r, fill) for x, y, r in pts)


def dots(points, fill=WHITE, op=0.8):
	return "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" opacity="{op}"/>' for x, y, r in points)


NIGHT_STARS = dots([(-140, -120, 5), (130, -140, 4), (150, -40, 3), (-160, 30, 3), (-90, -165, 3), (90, 150, 3), (-130, 130, 4)])


def burst(r_out, r_in, n=14, fill=WHITE, op=1.0, seed=1, cx=0, cy=0, stroke=True):
	rnd = random.Random(seed)
	pts = []
	for i in range(n * 2):
		a = math.pi * i / n - math.pi / 2
		r = (r_out if i % 2 == 0 else r_in) * rnd.uniform(0.9, 1.08)
		pts.append(f"{cx + r * math.cos(a):.1f},{cy + r * math.sin(a):.1f}")
	st = f'stroke="{INK}" stroke-width="8" stroke-linejoin="round"' if stroke else ""
	return f'<polygon points="{" ".join(pts)}" fill="{fill}" opacity="{op}" {st}/>'


def googly(x, y, r, lx=0.0, ly=0.0, pupil=0.52, sw=8):
	"""Googly eye: white ball, pupil pushed toward (lx, ly) in -1..1, glint."""
	pr = r * pupil
	px, py = x + lx * (r - pr - 2), y + ly * (r - pr - 2)
	return (
		f'<circle cx="{x}" cy="{y}" r="{r}" fill="{WHITE}" stroke="{INK}" stroke-width="{sw}"/>'
		f'<circle cx="{px:.1f}" cy="{py:.1f}" r="{pr:.1f}" fill="{INK}"/>'
		f'<circle cx="{px - pr * 0.35:.1f}" cy="{py - pr * 0.35:.1f}" r="{pr * 0.3:.1f}" fill="{WHITE}"/>'
	)


def blush(x, y, rx=16, ry=9, op=0.75):
	return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{BLUSH}" opacity="{op}"/>'


def grin(x, y, w, h, tongue=True):
	"""Open D-shaped smile with tongue."""
	d = f"M{x - w},{y} Q{x},{y + h * 2} {x + w},{y} Z"
	t = ""
	if tongue:
		t = f'<path d="M{x - w * 0.45},{y + h * 0.75} Q{x},{y + h * 0.35} {x + w * 0.45},{y + h * 0.75} Q{x},{y + h * 1.15} {x - w * 0.45},{y + h * 0.75} Z" fill="{KETCHUP}"/>'
	return f'<path d="{d}" fill="{INK}" {S8}/>{t}'


def smile(x, y, w, h, sw=9):
	return line(f"M{x - w},{y} Q{x},{y + h} {x + w},{y}", sw)


def sweat(x, y, s=1.0, rot=0):
	return (
		f'<g transform="translate({x},{y}) rotate({rot}) scale({s})">'
		f'<path d="M0,-22 Q16,2 12,12 A12,12 0 0 1 -12,12 Q-16,2 0,-22 Z" fill="{SWEAT}" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>'
		f'<ellipse cx="-4" cy="6" rx="3" ry="5" fill="{WHITE}"/></g>'
	)


def marks(pts, w=9, color=INK):
	"""Short motion / shake dashes: list of (x1, y1, x2, y2)."""
	return "".join(line(f"M{a},{b} L{c},{d}", w, color) for a, b, c, d in pts)


def text(t, x, y, size, fill, stroke=INK, sw=14, rot=0):
	return (
		f'<text x="{x}" y="{y}" transform="rotate({rot} {x} {y})" font-family="{FONT}" font-size="{size}" text-anchor="middle" fill="{fill}" '
		f'stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round" paint-order="stroke">{t}</text>'
	)


def hotdog(tx=0, ty=0, rot=0, sc=1.0, face="happy"):
	if face == "cool":
		f = (
			f'<path d="M-92,-40 h74 q4,40 -34,40 q-40,0 -40,-40 Z M18,-40 h74 q4,40 -34,40 q-40,0 -40,-40 Z" fill="{INK}" {S8}/>'
			f'<path d="M-18,-34 h36" stroke="{INK}" stroke-width="10"/>'
			f'<path d="M-76,-32 l18,0 M34,-32 l18,0" stroke="{WHITE}" stroke-width="6" stroke-linecap="round" opacity="0.8"/>'
			+ grin(0, 30, 52, 20)
		)
	else:
		f = googly(-42, -24, 28, 0.2, 0.25) + googly(42, -24, 28, 0.2, 0.25) + grin(0, 30, 48, 20) + blush(-92, 34) + blush(92, 34)
	return f'''<g transform="translate({tx},{ty}) rotate({rot}) scale({sc})">
	<rect x="-150" y="-56" width="300" height="84" rx="42" fill="#F4D9A0" {S}/>
	<rect x="-182" y="-42" width="364" height="60" rx="30" fill="#C2602F" {S}/>
	<path d="M-160,-30 q-6,10 0,22 M160,-30 q6,10 0,22" stroke="#7E3519" stroke-width="7" fill="none" stroke-linecap="round"/>
	<path d="M-140,-14 q15,-18 30,0 t30,0 t30,0 t30,0 t30,0 t30,0 t30,0 t30,0 t30,0" stroke="{MUSTARD}" stroke-width="12" fill="none" stroke-linecap="round"/>
	<path d="M-158,5 Q-158,74 -95,74 L95,74 Q158,74 158,5 Z" fill="#D9A35E" {S}/>
	{f}
</g>'''


ICONS = {}

# 1 — the stand wakes up: windows are eyes, the door is a big grin.
ICONS["welcome"] = ("day", f'''
<rect x="-130" y="-55" width="260" height="170" rx="16" fill="{CREAM}" {S}/>
<rect x="-108" y="-28" width="70" height="66" rx="12" fill="#BFE3F0" {S}/>
<rect x="38" y="-28" width="70" height="66" rx="12" fill="#BFE3F0" {S}/>
{googly(-73, 6, 26, 0.45, -0.3)}{googly(73, 6, 26, -0.1, -0.3)}
{grin(0, 58, 46, 26)}
{blush(-80, 72)}{blush(80, 72)}
<path d="M-152,-112 L152,-112 L152,-58 L-152,-58 Z" fill="{CREAM}"/>
<path d="M-91,-112 L-30,-112 L-30,-58 L-91,-58 Z M30,-112 L91,-112 L91,-58 L30,-58 Z M152,-112 L152,-58 L91,-58 L91,-112 Z M-152,-112 L-152,-58 L-91,-58 L-91,-112 Z" fill="{KETCHUP}"/>
<path d="M-152,-58 q15,32 30,0 t30,0 t30,0 t30,0 t30,0 t30,0 t30,0 t30,0 t30,0 t30,0" fill="{KETCHUP}" {S}/>
<path d="M-152,-112 L152,-112 L152,-58 L-152,-58 Z" fill="none" {S}/>
<g transform="rotate(-9 0 -150)">
	<rect x="-84" y="-176" width="168" height="56" rx="16" fill="{MUSTARD}" {S}/>
	{text("OPEN", 0, -133, 40, WHITE, INK, 10)}
</g>
{marks([(-118, -170, -100, -158), (-124, -146, -102, -142), (110, -186, 96, -170), (122, -162, 100, -154)])}
''')

# 2 — clipboard with three ticks, winking and grinning.
ICONS["tutorial_done"] = ("day", '<g transform="rotate(-7)">' + f'''
<rect x="-118" y="-150" width="236" height="300" rx="24" fill="#C2602F" {S}/>
<rect x="-94" y="-118" width="188" height="244" rx="12" fill="{WHITE}" {S}/>
<rect x="-50" y="-176" width="100" height="50" rx="16" fill="#C9D1D8" {S}/>
''' + "".join(f'''
<rect x="-72" y="{y}" width="40" height="40" rx="8" fill="{WHITE}" {S8}/>
{line(f"M-66,{y + 18} l14,16 l30,-42", 13, "#3E8A4A")}
<rect x="-14" y="{y + 13}" width="78" height="15" rx="7" fill="#CFC8B8"/>''' for y in (-96, -46, 4)) + f'''
{line("M-48,82 q14,-14 28,0", 9)}
{googly(34, 78, 17, -0.2, -0.2, sw=7)}
{smile(-6, 98, 26, 22)}
{blush(-60, 104, 12, 7)}{blush(56, 104, 12, 7)}
</g>''' + sparkles([(150, -120, 22), (-155, 120, 16)]) + marks([(140, 40, 160, 30), (138, 70, 162, 70)]))

# 3 — the very first hot dog waves hello.
ICONS["first_hotdog"] = ("day", burst(195, 150, 16, WHITE, 0.55, 3, stroke=False) + f'''
{line("M110,-20 Q150,-44 136,-84", 16)}
<circle cx="134" cy="-96" r="22" fill="#F4D9A0" {S8}/>
''' + hotdog(-8, 26, -8, 0.95) + marks([(96, -118, 106, -138), (140, -138, 148, -158), (170, -112, 188, -122)]) + sparkles([(-130, -120, 26), (-160, -40, 14), (130, 140, 16)]))

# 4 — "wheee!": a sausage launched off the spatula, squashed by the flip.
ICONS["golden_flip"] = ("day", f'''
<g transform="translate(-30,40) rotate(-28)">
	<rect x="-18" y="40" width="36" height="160" rx="16" fill="#7E3519" {S}/>
	<rect x="-78" y="-64" width="156" height="114" rx="20" fill="#C9D1D8" {S}/>
	<path d="M-36,-38 v62 M0,-38 v62 M36,-38 v62" stroke="#7C8792" stroke-width="12" stroke-linecap="round"/>
</g>
{line("M-120,-40 Q-120,-130 -40,-160", 10, WHITE, 'opacity="0.95"')}
{line("M-86,-24 Q-86,-96 -24,-124", 8, WHITE, 'opacity="0.75"')}
<g transform="translate(56,-104) rotate(22) scale(1.35,1.05)">
	<rect x="-100" y="-34" width="200" height="68" rx="34" fill="#C2602F" {S}/>
	<path d="M-70,-20 q12,8 0,22 M70,-20 q-12,8 0,22" stroke="#7E3519" stroke-width="7" fill="none" stroke-linecap="round"/>
	{googly(-22, -10, 17, 0.6, -0.5, sw=6)}{googly(18, -10, 17, 0.6, -0.5, sw=6)}
	<ellipse cx="0" cy="18" rx="10" ry="9" fill="{INK}"/>
</g>
{marks([(-12, -40, -24, -22), (12, -30, 4, -12), (-40, -54, -58, -42)])}
''' + sparkles([(160, -30, 28), (-160, 60, 20), (140, 110, 16), (-60, -175, 12)]))

# 5 — sleepy crescent moon in a nightcap.
ICONS["first_night"] = ("night", NIGHT_STARS + f'''
<circle cx="-10" cy="10" r="160" fill="{CREAM}" opacity="0.07"/>
<path d="M50,-130 A130,130 0 0 0 50,130 A230,230 0 0 1 50,-130 Z" fill="{CREAM}" {S}/>
<path d="M50,-130 Q90,-168 150,-140 Q120,-120 104,-86 Q84,-112 50,-130 Z" fill="{KETCHUP}" {S}/>
<circle cx="112" cy="-80" r="18" fill="{WHITE}" {S8}/>
{line("M-64,-30 q18,16 36,0", 10)}
{line("M-58,40 q16,14 34,-2", 10)}
{blush(-70, 8, 13, 8)}
{text("Z", 112, 18, 60, WHITE, INK, 10, 12)}
{text("z", 150, 70, 42, WHITE, INK, 8, 12)}
{text("z", 120, 118, 30, WHITE, INK, 7, 12)}
''')

# 6 — a customer that is not quite right (crooked eyes, too many teeth) under a big red "no".
ICONS["not_today"] = ("night", NIGHT_STARS + f'''
<path d="M-95,-85 Q-140,-60 -118,4 Q-95,-30 -80,-50 Z" fill="#C9A27A" {S}/>
<path d="M95,-85 Q140,-60 118,4 Q95,-30 80,-50 Z" fill="#C9A27A" {S}/>
<ellipse cx="0" cy="0" rx="102" ry="114" fill="#E8D9B5" {S}/>
{googly(-38, -30, 30, 0.7, -0.6)}{googly(42, -22, 18, -0.8, 0.6, sw=7)}
<path d="M-62,34 Q0,74 66,28 Q60,64 0,74 Q-56,70 -62,34 Z" fill="{WHITE}" {S8}/>
<path d="M-44,42 l4,24 M-22,48 l2,24 M0,52 v22 M22,49 l-1,22 M44,40 l-3,24" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>
{sweat(112, -60, 1.0, 20)}
<circle cx="0" cy="0" r="162" fill="none" stroke="{INK}" stroke-width="44"/>
<path d="M-114,114 L114,-114" stroke="{INK}" stroke-width="44" stroke-linecap="round"/>
<circle cx="0" cy="0" r="162" fill="none" stroke="{KETCHUP}" stroke-width="28"/>
<path d="M-114,114 L114,-114" stroke="{KETCHUP}" stroke-width="28" stroke-linecap="round"/>
''')

# 7 — the bulb pops back on: wide-eyed, nervous grin, one bead of sweat.
ICONS["lights_back"] = ("night", NIGHT_STARS + f'''
<circle cx="0" cy="-30" r="165" fill="{MUSTARD}" opacity="0.16"/>
{burst(178, 128, 12, "#FFD45A", 0.35, 7, 0, -30, stroke=False)}
<path d="M-62,44 Q-108,0 -108,-50 A108,108 0 0 1 108,-50 Q108,0 62,44 Z" fill="#FFD45A" {S}/>
<ellipse cx="-56" cy="-92" rx="18" ry="30" fill="{WHITE}" opacity="0.7" transform="rotate(32 -56 -92)"/>
{googly(-36, -52, 30, 0, 0, 0.42)}{googly(36, -52, 30, 0, 0, 0.42)}
<path d="M-50,-4 Q0,4 50,-4 Q46,34 0,36 Q-46,34 -50,-4 Z" fill="{WHITE}" {S8}/>
{line("M-48,14 h96", 5)}
<path d="M-26,-2 v34 M0,0 v36 M26,-2 v34" stroke="{INK}" stroke-width="5"/>
{sweat(84, -110, 1.1, 15)}
<rect x="-56" y="44" width="112" height="78" rx="14" fill="#C9D1D8" {S}/>
<path d="M-56,70 h112 M-56,96 h112" stroke="{INK}" stroke-width="8"/>
<path d="M-30,122 Q0,152 30,122" fill="#7C8792" {S}/>
''' + marks([(-178, -40, -140, -40), (178, -40, 140, -40), (-132, -158, -106, -132), (132, -158, 106, -132), (0, -205, 0, -172)], 14, "#FFD45A"))

# 8 — hiding behind a crate, cheeks puffed, sweating, while the Walker passes.
ICONS["held_breath"] = ("night", NIGHT_STARS + f'''
<g fill="#0B0D1E" stroke="#0B0D1E" stroke-width="6" stroke-linejoin="round">
	<ellipse cx="96" cy="-150" rx="28" ry="34"/>
	<path d="M80,-118 L112,-118 L130,40 L116,40 L104,-40 L92,40 L78,40 Z"/>
	<path d="M80,-110 Q48,-40 56,40 L64,40 Q64,-30 94,-98 Z"/>
	<path d="M112,-110 Q146,-40 142,40 L134,40 Q130,-30 104,-98 Z"/>
</g>
<circle cx="88" cy="-152" r="6" fill="#FF3B30"/><circle cx="106" cy="-152" r="6" fill="#FF3B30"/>
<path d="M-150,-8 Q-150,-92 -82,-92 Q-14,-92 -14,-8 Z" fill="#E8D9B5" {S}/>
<circle cx="-150" cy="-22" r="22" fill="#E8D9B5" {S}/>
<circle cx="-14" cy="-22" r="22" fill="#E8D9B5" {S}/>
{blush(-146, -20, 13, 9, 0.9)}{blush(-18, -20, 13, 9, 0.9)}
{googly(-102, -46, 20, 0.75, 0, sw=7)}{googly(-60, -46, 20, 0.75, 0, sw=7)}
{sweat(-178, -76, 1.0, -25)}{sweat(-6, -100, 0.85, 25)}
<rect x="-176" y="-12" width="210" height="156" rx="12" fill="#C2602F" {S}/>
<path d="M-176,40 h210 M-176,92 h210 M-124,-12 v156 M-20,-12 v156" stroke="#7E3519" stroke-width="8"/>
<rect x="-176" y="-12" width="210" height="156" rx="12" fill="none" {S}/>
''')

# 9 — the ceiling shadow grins; you stare very, very hard at the floor.
ICONS["eyes_down"] = ("horror", f'''
<path d="M-212,-212 L212,-212 L212,-100 Q180,-70 160,-108 Q146,-20 122,-36 Q104,-100 82,-86 Q62,8 36,-14 Q20,-90 0,-80 Q-24,30 -50,-6 Q-62,-90 -86,-86 Q-102,-24 -126,-44 Q-142,-104 -166,-94 Q-186,-56 -212,-84 Z" fill="#0B0D1E"/>
<path d="M-70,-150 l40,14 M70,-150 l-40,14" stroke="#FF3B30" stroke-width="14" stroke-linecap="round"/>
<path d="M-90,-120 Q0,-60 90,-120 Q0,-90 -90,-120 Z" fill="{WHITE}"/>
<path d="M-70,-112 l10,14 l10,-10 l10,14 l10,-12 l10,14 l10,-12 l10,14 l10,-12 l10,14 l10,-12 l10,14 l10,-14" stroke="#0B0D1E" stroke-width="5" fill="none" stroke-linejoin="round"/>
<circle cx="0" cy="96" r="82" fill="{WHITE}" {S}/>
<circle cx="0" cy="140" r="34" fill="#5A1620" {S8}/>
<circle cx="0" cy="146" r="16" fill="#0B0D1E"/>
<circle cx="-12" cy="130" r="7" fill="{WHITE}"/>
{line("M-58,40 Q-30,24 -6,34", 11, WHITE)}
{line("M58,40 Q30,24 6,34", 11, WHITE)}
{sweat(-98, 40, 1.2, -20)}{sweat(98, 60, 1.0, 20)}
''')

# 10 — the Hunter tips his hat and smiles far too wide under the streetlamp.
ICONS["met_hunter"] = ("horror", f'''
<defs><filter id="glow" x="-1" y="-1" width="3" height="3"><feGaussianBlur stdDeviation="9"/></filter></defs>
<path d="M-140,-60 L-60,170 L-220,170 Z" fill="#FFD45A" opacity="0.16"/>
<rect x="-158" y="-80" width="18" height="260" fill="#0B0D1E"/>
<path d="M-149,-80 Q-149,-122 -114,-122 L-98,-122" stroke="#0B0D1E" stroke-width="16" fill="none"/>
<path d="M-120,-124 h44 l-9,24 h-26 Z" fill="#0B0D1E"/>
<ellipse cx="-98" cy="-98" rx="17" ry="8" fill="#FFD45A"/>
<g fill="#000" opacity="0.92">
	<ellipse cx="54" cy="-20" rx="70" ry="78"/>
	<path d="M-30,30 Q54,0 138,30 L170,220 L-62,220 Z"/>
	<rect x="-30" y="-106" width="168" height="24" rx="10"/>
	<path d="M4,-100 Q4,-170 54,-170 Q104,-170 104,-100 Z"/>
</g>
<g filter="url(#glow)"><ellipse cx="26" cy="-40" rx="22" ry="12" fill="#FF3B30"/><ellipse cx="84" cy="-40" rx="22" ry="12" fill="#FF3B30"/></g>
<ellipse cx="26" cy="-40" rx="15" ry="8" fill="#FFB0A8"/><ellipse cx="84" cy="-40" rx="15" ry="8" fill="#FFB0A8"/>
<path d="M8,-58 l34,8 M102,-58 l-34,8" stroke="#000" stroke-width="10" stroke-linecap="round"/>
<path d="M-8,0 Q54,48 118,0 Q54,30 -8,0 Z" fill="{WHITE}"/>
<path d="M2,4 l10,14 l10,-8 l10,14 l10,-8 l12,14 l10,-14 l12,8 l10,-14 l10,8 l10,-14" stroke="#000" stroke-width="5" fill="none" stroke-linejoin="round"/>
{text("!", -40, -120, 70, WHITE, INK, 10, -12)}
''')

# 11 — half moon with a determined wink, and a big "5" on a burst.
ICONS["halfway"] = ("night", NIGHT_STARS + f'''
<circle cx="-40" cy="-30" r="126" fill="#1B2140" {S}/>
<path d="M-40,-156 A126,126 0 0 1 -40,96 Z" fill="{CREAM}" {S}/>
{line("M-8,-68 q16,-12 32,4", 10)}
{googly(30, -50, 22, 0.3, 0.2, sw=7)}
{smile(18, 10, 30, 26)}
{blush(44, -8, 12, 7)}
{burst(104, 76, 11, MUSTARD, 1, 5, 104, 104)}
{text("5", 104, 158, 160, WHITE, INK, 16, 10)}
''')

# 12 — the hundredth hot dog is way too cool now.
ICONS["hot_dog_hundred"] = ("milestone", f'''
<g opacity="0.55">''' + "".join(f'<path d="M0,0 L{230 * math.cos(a * 0.3927):.0f},{230 * math.sin(a * 0.3927):.0f} L{230 * math.cos((a + 0.5) * 0.3927):.0f},{230 * math.sin((a + 0.5) * 0.3927):.0f} Z" fill="{MUSTARD}"/>' for a in range(16)) + f'''</g>
{hotdog(0, -62, -8, 0.84, "cool")}
{text("100", 0, 150, 138, KETCHUP, INK, 16, -6)}
''' + sparkles([(-160, -110, 18), (160, -130, 22), (170, 40, 14)]))

# 13 — dawn: the sun rises smiling, the tired streetlamp can finally rest.
ICONS["kept_light"] = ("dawn", f'''
<circle cx="50" cy="140" r="176" fill="#FFD45A" opacity="0.25"/>
<circle cx="50" cy="140" r="132" fill="#FFD45A" {S}/>
{line("M6,70 q16,-16 32,0", 10)}{line("M62,70 q16,-16 32,0", 10)}
{grin(50, 96, 36, 18)}
{blush(0, 98, 14, 8)}{blush(100, 98, 14, 8)}
<rect x="-212" y="140" width="424" height="80" fill="{INK}"/>
<rect x="-104" y="-100" width="24" height="240" fill="#4A4E58" {S}/>
{line("M-92,-100 Q-92,-150 -46,-150 L-30,-150", 22, "#4A4E58")}
<path d="M-84,-186 h124 l-22,66 h-80 Z" fill="#6A6F7C" {S}/>
<ellipse cx="-22" cy="-118" rx="36" ry="10" fill="{CREAM}"/>
{line("M-56,-160 q10,8 20,0", 8, CREAM)}{line("M-8,-160 q10,8 20,0", 8, CREAM)}
{line("M-36,-138 q14,6 28,0", 6, CREAM)}
<rect x="-130" y="128" width="76" height="20" rx="6" fill="#4A4E58" {S}/>
{text("z", 66, -170, 40, WHITE, INK, 8, 10)}{text("z", 92, -196, 28, WHITE, INK, 6, 10)}
''' + sparkles([(-160, -40, 16), (150, -110, 22), (170, 10, 12)]))

# 14 — smug little shield, not a single scratch on it.
ICONS["not_a_scratch"] = ("dawn", f'''
<path d="M0,-170 L136,-118 Q140,40 0,164 Q-140,40 -136,-118 Z" fill="{TEAL}" {S}/>
<path d="M0,-140 L106,-98 Q108,28 0,128 Z" fill="#256E7A" opacity="0.5"/>
<path d="M0,-170 L136,-118 Q140,40 0,164 Q-140,40 -136,-118 Z" fill="none" {S}/>
{line("M-74,-96 l40,10 M74,-96 l-40,10", 10)}
<path d="M-74,-66 a22,22 0 0 0 44,0 Z M30,-66 a22,22 0 0 0 44,0 Z" fill="{WHITE}" {S8}/>
<circle cx="-46" cy="-58" r="8" fill="{INK}"/><circle cx="58" cy="-58" r="8" fill="{INK}"/>
{line("M-40,-14 Q10,8 46,-24", 10)}
<path d="M0,130 C-74,80 -50,26 0,56 C50,26 74,80 0,130 Z" fill="{KETCHUP}" {S8}/>
<ellipse cx="-24" cy="62" rx="9" ry="6" fill="{WHITE}" opacity="0.75" transform="rotate(-30 -24 62)"/>
''' + sparkles([(160, -140, 24), (-166, -40, 16), (150, 90, 16), (-130, 130, 12)]))

# 15 — one hundred days: the alarm clock is exhausted and still ringing.
ICONS["day_100"] = ("milestone", f'''
{line("M-70,-160 l-24,-28 M70,-160 l24,-28", 16)}
<circle cx="-92" cy="-150" r="34" fill="{KETCHUP}" {S} transform="rotate(-20 -92 -150)"/>
<circle cx="92" cy="-150" r="34" fill="{KETCHUP}" {S}/>
<path d="M-82,72 l-24,34 M82,72 l24,34" stroke="{INK}" stroke-width="16" stroke-linecap="round"/>
<circle cx="0" cy="-30" r="132" fill="{WHITE}" {S}/>
''' + "".join(f'<circle cx="{98 * math.cos(a * 0.5236):.0f}" cy="{-30 + 98 * math.sin(a * 0.5236):.0f}" r="7" fill="{INK}"/>' for a in (0, 3, 6, 9)) + f'''
{line("M-70,-66 h44 M26,-66 h44", 10)}
{googly(-46, -48, 20, 0, 0.6, sw=7)}{googly(46, -48, 20, 0, 0.6, sw=7)}
{line("M-66,-26 q20,10 40,0 M26,-26 q20,10 40,0", 6, "#8E6FA8")}
{line("M-30,26 q10,-10 20,0 t20,0 t20,0", 9)}
{sweat(92, -4, 1.1, 20)}
{marks([(-176, -60, -152, -52), (-182, -26, -156, -24), (176, -60, 152, -52), (182, -26, 156, -24), (-150, -196, -136, -176), (150, -196, 136, -176)])}
<path d="M-178,86 L178,86 L156,124 L178,162 L-178,162 L-156,124 Z" fill="{KETCHUP}" {S}/>
{text("100", 0, 152, 80, WHITE, INK, 12)}
''')

ORDER = [
	"welcome", "tutorial_done", "first_hotdog", "golden_flip", "first_night", "not_today", "lights_back",
	"held_breath", "eyes_down", "met_hunter", "halfway",
	"hot_dog_hundred", "kept_light", "not_a_scratch", "day_100",
]


def badge_svg(key):
	theme, icon = ICONS[key]
	c1, c2, ring, glow = THEMES[theme]
	return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
<defs>
	<radialGradient id="bg" cx="0.4" cy="0.3" r="0.8"><stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/></radialGradient>
	<clipPath id="disc"><circle cx="256" cy="256" r="212"/></clipPath>
	<filter id="ink" x="-10%" y="-10%" width="125%" height="125%">
		<feTurbulence type="fractalNoise" baseFrequency="0.018" numOctaves="2" seed="4" result="n"/>
		<feDisplacementMap in="SourceGraphic" in2="n" scale="7" xChannelSelector="R" yChannelSelector="G" result="w"/>
		<feFlood flood-color="{INK}" flood-opacity="0.5"/>
		<feComposite operator="in" in2="w"/>
		<feOffset dx="7" dy="9" result="sh"/>
		<feMerge><feMergeNode in="sh"/><feMergeNode in="w"/></feMerge>
	</filter>
</defs>
<circle cx="256" cy="256" r="254" fill="{INK}"/>
<circle cx="256" cy="256" r="240" fill="{ring}"/>
<circle cx="256" cy="256" r="240" fill="none" stroke="#FFFFFF" stroke-opacity="0.25" stroke-width="6"/>
<circle cx="256" cy="256" r="218" fill="{INK}"/>
<circle cx="256" cy="256" r="212" fill="url(#bg)"/>
<g clip-path="url(#disc)">
	{burst(222, 196, 22, glow, 0.35, 11, 256, 256, stroke=False)}
	<g filter="url(#ink)"><g transform="translate(256,256)">{icon}</g></g>
</g>
<path d="M90,170 A180,180 0 0 1 200,70" stroke="#FFFFFF" stroke-opacity="0.22" stroke-width="16" fill="none" stroke-linecap="round"/>
</svg>'''


HEAD = (
	'<!doctype html><html><head><meta charset="utf-8">'
	'<link href="https://fonts.googleapis.com/css2?family=Fredoka+One&display=block" rel="stylesheet">'
	"<style>html,body{margin:0;background:transparent;overflow:hidden}svg{display:block}</style></head><body>"
)


def board(pngs, path, cell=256, cols=5, bg=(233, 228, 218, 255)):
	from PIL import Image

	rows = (len(pngs) + cols - 1) // cols
	sheet = Image.new("RGBA", (cell * cols, cell * rows), bg)
	for i, p in enumerate(pngs):
		im = Image.open(p).convert("RGBA").resize((cell, cell), Image.LANCZOS)
		sheet.alpha_composite(im, ((i % cols) * cell, (i // cols) * cell))
	sheet.save(path)


def main():
	os.makedirs(SVG_DIR, exist_ok=True)
	os.makedirs(HTML_DIR, exist_ok=True)
	pngs = []
	for i, key in enumerate(ORDER, 1):
		svg = badge_svg(key)
		with open(os.path.join(SVG_DIR, f"{key}.svg"), "w", encoding="utf-8") as f:
			f.write(svg)
		html_path = os.path.join(HTML_DIR, f"{key}.html")
		with open(html_path, "w", encoding="utf-8") as f:
			f.write(HEAD + svg + "</body></html>")
		png = os.path.join(OUT, f"{i:02d}_{key}.png")
		subprocess.run([
			CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
			"--default-background-color=00000000", "--window-size=512,512",
			"--virtual-time-budget=5000", f"--screenshot={png}", "file:///" + html_path.replace("\\", "/"),
		], check=True, capture_output=True)
		pngs.append(png)

	board(pngs, os.path.join(HERE, "board.png"))
	print("ok", len(ORDER))


if __name__ == "__main__":
	main()
