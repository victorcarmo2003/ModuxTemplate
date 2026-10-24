#!/usr/bin/env python3
"""Mockup generator template. Copy next to your work files, edit BODY, run:

    python make_mockup.py            -> mock.svg
    python <skill>/scripts/render.py mock.svg -o over.png --bg ref.jpg --opacity 0.6

Ids: group-*, asset-*, frame-*, text-* (see references/asset-pipeline.md). Coordinates in 1920x1080 px,
measured with grid.py. Example below = AW-style weapon panel (tested end to end when the skill was built).
"""
import os
import subprocess
import sys

SKILL = os.path.expanduser("~/.claude/skills/roblox-vide-ui/scripts")
sys.path.insert(0, SKILL)
import shapes as S  # noqa: E402

FONTS = subprocess.run([sys.executable, f"{SKILL}/roblox_fonts.py", "Oswald", "Roboto Condensed"],
                       capture_output=True, text=True).stdout.strip()
REF = ""  # e.g. "file:///C:/path/ref.jpg" -> drawn as id="ref" (ignored by export)

PRIMARY, SECONDARY, ACCENT, DANGER = "#FEFEFE", "#B2B4B6", "#F9C914", "#D8282A"


def g(id_, body, x=0, y=0, extra=""):
    return f'<g id="{id_}" transform="translate({x},{y})" {extra}>{body}</g>'


BODY = ""
if REF:
    BODY += f'<image id="ref" href="{REF}" width="1920" height="1080" opacity="0.5"/>'
BODY += '<g id="group-weapon" data-anchor="br">'
BODY += '<rect x="600" y="400" width="720" height="330" fill="none"/>'  # group bounds
BODY += (f'<text id="text-round" x="970" y="574" font-family="Oswald" font-weight="300" font-size="176" '
         f'fill="{PRIMARY}" text-anchor="middle">25</text>')
BODY += f'<rect id="frame-ammo_divider" x="885" y="598" width="173" height="2" fill="{SECONDARY}" opacity="0.8"/>'
BODY += (f'<text id="text-reserve" x="976" y="683" font-family="Oswald" font-weight="300" font-size="86" '
         f'fill="{SECONDARY}" text-anchor="middle">120</text>')
BODY += g("asset-battery", S.battery(40, 98, 3, 0.35), 617, 595)
BODY += g("asset-chevron", S.chevron(22, 40, 2.5), 1096, 538)
BODY += g("asset-streak_rings", S.arc(36, 4, 0, 360, cx=40, cy=36) + S.arc(36, 4, 0, 360, cx=114, cy=36),
          1128, 524, f'data-tint="{ACCENT}" data-glow="5"')
BODY += "</g>"

svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">'
       f"{FONTS}{BODY}</svg>")
open("mock.svg", "w", encoding="utf-8").write(svg)
print("wrote mock.svg")
