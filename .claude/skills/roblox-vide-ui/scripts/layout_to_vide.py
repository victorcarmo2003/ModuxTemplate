#!/usr/bin/env python3
"""Turn export_layers.py's layout.json into a Vide component skeleton (Luau).

  python layout_to_vide.py out/layout.json --name WeaponPanel > WeaponPanel/init.luau
  python layout_to_vide.py out/layout.json --name WeaponPanel --mode scale     # pure Scale positions

Modes:
  offset (default)  groups pinned to their screen anchor with offsets in reference px; the root carries a UIScale
                    (props.Scale, e.g. viewport height / 1080). Keeps hairlines and proportions exact. Best for HUDs.
  scale             every position/size in Scale of the parent. Best for full-screen menus.

The skeleton is a starting point: it reproduces the static mockup. You still must
  - replace ASSET ids (or point them to the project's asset id module),
  - turn static text/visibility/colors into props/sources and add states,
  - map fontFamily to a Roblox Font (see references/roblox-ui-fundamentals.md#fonts),
  - follow the project's idiom (const vs local, create("X")({}) vs create "X" {}).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict

ALIGN = {"start": "Left", "middle": "Center", "end": "Right"}
WEIGHT = {100: "Thin", 200: "ExtraLight", 300: "Light", 400: "Regular", 500: "Medium", 600: "SemiBold",
          700: "Bold", 800: "ExtraBold", 900: "Heavy"}


def font_face(family_css: str, weight_css: str) -> str:
    """Map the mockup font to a Roblox Font.new(...) when the family exists in Roblox, else a TODO."""
    try:
        import roblox_fonts as RF
        fd = RF.fonts_dir()
        fams = RF.families(fd) if fd else {}
    except Exception:
        fams = {}
    first = family_css.split(",")[0].strip().strip("'\"")
    stem = next((s for s, f in fams.items() if first in (s, f["name"])), None)
    w = WEIGHT.get(int(round(float(weight_css or 400) / 100) * 100), "Regular")
    if stem is None:
        return f'FontFace = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.{w}), -- TODO: "{first}" is not a Roblox family'
    return f'FontFace = Font.new("rbxasset://fonts/families/{stem}.json", Enum.FontWeight.{w}),'


def ident(name: str) -> str:
    s = re.sub(r"[^0-9a-zA-Z]+", " ", name).title().replace(" ", "")
    return s if s and not s[0].isdigit() else "N" + s


def c3(hx: str) -> str:
    return f'Color3.fromHex("{hx}")'


def udim2(p: dict, mode: str, key: str) -> str:
    if mode == "scale":
        x, y = p["scale"][key]
        return f"UDim2.fromScale({x}, {y})"
    if key == "size":
        w, h = p["offset"]["size"]
        return f"UDim2.fromOffset({w:g}, {h:g})"
    ax, ay = p["anchorPoint"]
    ox, oy = p["offset"]["position"]
    return f"UDim2.new({ax:g}, {ox:g}, {ay:g}, {oy:g})"


def emit(item: dict, children: dict, mode: str, depth: int, out: list[str]) -> None:
    t = "\t" * depth
    kind = item["kind"]
    ap = item["anchorPoint"]
    common = [f'Name = "{ident(item["name"])}"', f"AnchorPoint = Vector2.new({ap[0]:g}, {ap[1]:g})",
              f"Position = {udim2(item, mode, 'position')}", f"Size = {udim2(item, mode, 'size')}"]
    if item.get("z"):
        common.append(f"ZIndex = {item['z']}")
    if kind == "group":
        cls, props = "Frame", common + ["BackgroundTransparency = 1"]
    elif kind == "frame":
        cls, props = "Frame", common + [f"BackgroundColor3 = {c3(item['color'])}",
                                        f"BackgroundTransparency = {item['transparency']:g}", "BorderSizePixel = 0"]
        if item.get("radius"):
            props.append(f'@create("UICorner")({{ CornerRadius = UDim.new(0, {item["radius"]:g}) }}),')
    elif kind == "text":
        cls = "TextLabel"
        # Roblox fits the whole line (ascent + descent) into TextSize, CSS font-size is the em. The SVG text box
        # height IS that line box, so Roblox TextSize = box height (Oswald: ~1.48 x CSS font-size).
        # TextSize (and TextScaled) cap at 100: above that, shrink by k and scale back with a UIScale on the
        # label (UIScale scales around the AnchorPoint, verified in Studio).
        line_px = item["box"][3]
        k = max(1, -(-int(round(line_px)) // 100))
        if k > 1:
            if mode == "offset":
                w, h = item["offset"]["size"]
                common[3] = f"Size = UDim2.fromOffset({w / k:g}, {h / k:g})"
            else:
                w, h = item["scale"]["size"]
                common[3] = f"Size = UDim2.fromScale({w / k:.4g}, {h / k:.4g})"
        props = common + ["BackgroundTransparency = 1", f'Text = "{item["text"]}"',
                          f"TextSize = {round(line_px / k)}",
                          f"TextColor3 = {c3(item['color'])}",
                          f"TextTransparency = {item['transparency']:g}",
                          f"TextXAlignment = Enum.TextXAlignment.{ALIGN.get(item.get('textAnchor'), 'Left')}",
                          "@" + font_face(item["fontFamily"], item["fontWeight"])]
        if k > 1:
            props.append(f'@create("UIScale")({{ Scale = {k} }}), -- TextSize caps at 100')
    else:  # asset
        cls = "ImageLabel"
        props = common + ["BackgroundTransparency = 1", f"Image = ASSET.{ident(item['name'])}",
                          f"ImageColor3 = {c3(item['color'])}",
                          f"ImageTransparency = {item['transparency']:g}"]
        if item.get("sliceCenter"):
            l, tt, r, b = item["sliceCenter"]
            props += ["ScaleType = Enum.ScaleType.Slice", f"SliceCenter = Rect.new({l}, {tt}, {r}, {b})",
                      "SliceScale = 1 / EXPORT_SCALE"]
    if kind == "asset" and item.get("glow"):
        # Glow is a SIBLING drawn under the art. With ZIndexBehavior.Sibling a child always draws above its
        # parent whatever its ZIndex, so a child glow would cover the art (seen in Studio).
        z = item.get("z") or 1
        out.append(f'{t}create("ImageLabel")({{')
        for gp in [f'Name = "{ident(item["name"])}Glow"', common[1], common[2], common[3], f"ZIndex = {z - 1}",
                   "BackgroundTransparency = 1", f"Image = ASSET.{ident(item['name'])}Glow",
                   f"ImageColor3 = {c3(item.get('glowColor') or item['color'])}", "ImageTransparency = 0.45"]:
            out.append(f"{t}\t{gp},")
        out.append(f"{t}}}),")
        if not item.get("z"):
            props.append(f"ZIndex = {z}")
    out.append(f'{t}create("{cls}")({{')
    for p in props:
        # "@" = line already carries its own trailing comma (+ comment)
        out.append(f"{t}\t{p[1:]}" if p.startswith("@") else f"{t}\t{p},")
    for ch in children.get(item["id"], []):
        emit(ch, children, mode, depth + 1, out)
    out.append(f"{t}}}),")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("layout")
    ap.add_argument("--name", required=True)
    ap.add_argument("--mode", choices=["offset", "scale"], default="offset")
    a = ap.parse_args()
    data = json.load(open(a.layout, encoding="utf-8"))
    items = data["items"]
    children: dict = defaultdict(list)
    roots = []
    for it in sorted(items, key=lambda i: i.get("z", 0)):
        (children[it["parent"]] if it["parent"] else roots).append(it)

    assets = [it for it in items if it.get("image")]
    out = ["--!strict", f"-- {a.name}: generated skeleton from {data['source']} (layout_to_vide.py).",
           "-- Static mockup only: wire props/states, then delete this comment.",
           'local ReplicatedStorage = game:GetService("ReplicatedStorage")',
           "local Vide = require(ReplicatedStorage.Packages.Vide)", "",
           "local create = Vide.create", "",
           f"local EXPORT_SCALE = {data['scale']:g}",
           "-- TODO: move to the project's asset id module after upload.",
           "local ASSET = {"]
    for it in assets:
        out.append(f'\t{ident(it["name"])} = "rbxassetid://0", -- {it["image"]} {it["imageSize"][0]}x{it["imageSize"][1]}')
        if it.get("glow"):
            out.append(f'\t{ident(it["name"])}Glow = "rbxassetid://0", -- {it["glow"]}')
    out += ["}", "", "export type Props = {",
            f"\t-- Uniform scale of the whole HUD; reference is {data['reference'][0]}x{data['reference'][1]}.",
            "\tScale: (() -> number)?,", "}", "",
            f"local function {a.name}(props: Props): Instance",
            '\treturn create("Frame")({',
            f'\t\tName = "{a.name}",', "\t\tBackgroundTransparency = 1,"]
    if a.mode == "offset":
        # UIScale also scales the root itself, so the root is sized 1/s to still cover the screen exactly.
        out[out.index(f"local function {a.name}(props: Props): Instance"):out.index(f"local function {a.name}(props: Props): Instance")] = [
            "local function scaleOf(props: Props): number",
            "\treturn if props.Scale then math.max(props.Scale(), 0.01) else 1",
            "end", ""]
        out += ["\t\tSize = function()", "\t\t\tlocal s = scaleOf(props)", "\t\t\treturn UDim2.fromScale(1 / s, 1 / s)",
                "\t\tend,", '\t\tcreate("UIScale")({', "\t\t\tScale = function()", "\t\t\t\treturn scaleOf(props)",
                "\t\t\tend,", "\t\t}),"]
    else:
        out.append("\t\tSize = UDim2.fromScale(1, 1),")
    for r in roots:
        emit(r, children, a.mode, 2, out)
    out += ["\t})", "end", "", f"return {a.name}", ""]
    sys.stdout.write("\n".join(out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
