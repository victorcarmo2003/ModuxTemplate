#!/usr/bin/env python3
"""Make the mockup use the exact fonts Roblox will render (WYSIWYG typography).

  python roblox_fonts.py --list                      # Roblox families, local faces, Google Fonts twin
  python roblox_fonts.py "Roboto Condensed" Oswald   # print a <style> block to paste inside the mockup <svg>

Local faces come from the Roblox install (%LOCALAPPDATA%/Roblox/Versions/*/content/fonts). Weights Roblox
downloads on demand (rbxassetid faces, e.g. Roboto Condensed Light) are pulled from Google Fonts, which hosts
the same open fonts. In Luau use: Font.new("rbxasset://fonts/families/<File>.json", Enum.FontWeight.X).
"""
from __future__ import annotations

import argparse
import glob
import json
import os
from pathlib import Path

# Roblox family file -> Google Fonts family (None = not on Google Fonts; local file only)
GOOGLE = {
    "RobotoCondensed": "Roboto Condensed", "Roboto": "Roboto", "RobotoMono": "Roboto Mono", "Oswald": "Oswald",
    "TitilliumWeb": "Titillium Web", "Jura": "Jura", "Michroma": "Michroma", "Sarpanch": "Sarpanch",
    "Montserrat": "Montserrat", "Nunito": "Nunito", "FredokaOne": "Fredoka", "LuckiestGuy": "Luckiest Guy",
    "Bangers": "Bangers", "PressStart2P": "Press Start 2P", "Ubuntu": "Ubuntu", "Merriweather": "Merriweather",
    "SourceSansPro": "Source Sans 3", "JosefinSans": "Josefin Sans", "Inconsolata": "Inconsolata",
    "Arimo": "Arimo", "DenkOne": "Denk One", "Creepster": "Creepster", "AmaticSC": "Amatic SC",
    "Fondamento": "Fondamento", "GrenzeGotisch": "Grenze Gotisch", "IndieFlower": "Indie Flower",
    "Kalam": "Kalam", "PatrickHand": "Patrick Hand", "PermanentMarker": "Permanent Marker",
    "SpecialElite": "Special Elite", "Balthazar": "Balthazar", "AccanthisADFStd": None, "BuilderSans": None,
    "BuilderMono": None, "BuilderExtended": None, "Zekton": None, "Guru": None, "HighwayGothic": None,
}


# Weights to request from Google Fonts (others: default 400 only, a bad axis spec makes Google reject the request)
WEIGHTS = {
    "Roboto Condensed": "ital,wght@0,300;0,400;0,700;1,300;1,400;1,700", "Roboto": "wght@300;400;500;700",
    "Oswald": "wght@200;300;400;500;600;700", "Titillium Web": "wght@300;400;600;700", "Montserrat": "wght@400;500;700;900",
    "Nunito": "wght@400;700;900", "Ubuntu": "wght@300;400;500;700", "Fredoka": "wght@400;500;600;700",
    "Source Sans 3": "wght@300;400;600;700", "Roboto Mono": "wght@300;400;700", "Jura": "wght@300;400;500;700",
    "Josefin Sans": "wght@300;400;700", "Merriweather": "wght@300;400;700;900",
}


def fonts_dir() -> Path | None:
    base = os.environ.get("LOCALAPPDATA", "")
    cands = sorted(glob.glob(os.path.join(base, "Roblox", "Versions", "*", "content", "fonts")),
                   key=os.path.getmtime, reverse=True)
    return Path(cands[0]) if cands else None


def families(fd: Path) -> dict[str, dict]:
    out = {}
    for f in sorted((fd / "families").glob("*.json")):
        try:
            out[f.stem] = json.loads(f.read_text(encoding="utf-8"))
        except Exception:
            pass
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("names", nargs="*", help="family display name or file stem")
    ap.add_argument("--list", action="store_true")
    a = ap.parse_args()
    fd = fonts_dir()
    if fd is None:
        print("Roblox install not found; Google Fonts only.")
    fams = families(fd) if fd else {}

    if a.list or not a.names:
        for stem, fam in fams.items():
            faces = []
            for face in fam["faces"]:
                local = face["assetId"].startswith("rbxasset://")
                faces.append(f'{face["weight"]}{"i" if face["style"] == "italic" else ""}{"*" if local else ""}')
            g = GOOGLE.get(stem)
            print(f'{stem:18} {fam["name"]:20} faces {" ".join(faces):40} google: {g or "-"}')
        print("(* = file present locally)")
        return 0

    css = []
    imports: list[str] = []
    for name in a.names:
        stem = next((s for s, f in fams.items() if name in (s, f["name"])), name.replace(" ", ""))
        fam = fams.get(stem)
        display = fam["name"] if fam else name
        if fam and fd:
            for face in fam["faces"]:
                if face["assetId"].startswith("rbxasset://fonts/"):
                    path = (fd / face["assetId"].removeprefix("rbxasset://fonts/")).resolve().as_uri()
                    css.append(f"@font-face{{font-family:'{display}';src:url('{path}');"
                               f"font-weight:{face['weight']};font-style:{face['style']}}}")
        g = GOOGLE.get(stem)
        if g:
            spec = f":{WEIGHTS[g]}" if g in WEIGHTS else ""
            imports.append(f"@import url('https://fonts.googleapis.com/css2?family={g.replace(' ', '+')}{spec}&display=block');")
    block = "<style>"
    block += "".join(imports)
    block += "".join(css) + "</style>"
    print(block)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
