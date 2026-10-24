#!/usr/bin/env python3
"""Export a HUD mockup SVG into Roblox-ready layers + a layout file.

Id conventions inside the mockup (top-level or nested in groups):
  <g id="group-NAME" data-anchor="br">   container; children are laid out relative to it (becomes a Frame)
  <g id="asset-NAME" data-tint="#FFC83D"> exported as a WHITE PNG (alpha kept), tint goes to ImageColor3
       data-keep-color="true"            export with its real colors (multi-color art)
       data-glow="8"                     also export NAME_glow.png (blurred alpha), radius in mockup px
       data-glow-color="#C8641E"         glow tint when it differs from the art (AW: dark orange rim on amber)
       data-slice="12"                   9-slice margin in mockup px (written to layout as SliceCenter)
  <rect id="frame-NAME" rx="3" .../>     native Frame (not exported): size, color, transparency; rx -> UICorner
  <text id="text-NAME" ...>              native TextLabel (not exported): text, size, color, family
  anything else (e.g. id="ref", "guide-*") is ignored and hidden during export

Opacity on an asset/frame/text is not baked: it is exported at full alpha and written as *Transparency.

  python export_layers.py mock.svg -o out/ --scale 2 [--pad 4] [--only asset-ammo*]

Outputs out/<name>.png, out/<name>_glow.png, out/layout.json, out/_preview.png (all layers, transparent).
"""
from __future__ import annotations

import argparse
import fnmatch
import json
from pathlib import Path

from PIL import Image, ImageFilter
from playwright.sync_api import sync_playwright

from render import page_html

MAX_SIDE = 1024

COLLECT_JS = r"""
() => {
  const sel = '[id^="asset-"],[id^="text-"],[id^="frame-"],[id^="group-"]';
  const stage = document.querySelector('#stage').getBoundingClientRect();
  const out = [];
  const firstPaint = (el) => {
    // only drawable leaves: a <g> computes fill = black by default and would win
    const leaf = 'path,rect,circle,ellipse,polygon,polyline,line,text';
    const nodes = [el, ...el.querySelectorAll('*')].filter(n => n.matches(leaf));
    for (const n of nodes) {
      if (getComputedStyle(n).visibility === 'hidden') continue;
      const cs = getComputedStyle(n);
      if (cs.fill && cs.fill !== 'none' && !cs.fill.startsWith('url')) return cs.fill;
      if (cs.stroke && cs.stroke !== 'none' && !cs.stroke.startsWith('url')) return cs.stroke;
    }
    return 'rgb(255, 255, 255)';
  };
  for (const el of document.querySelectorAll(sel)) {
    const r = el.getBoundingClientRect();
    const cs = getComputedStyle(el);
    const parent = el.parentElement ? el.parentElement.closest('[id^="group-"]') : null;
    const kind = el.id.split('-')[0];
    const item = {
      id: el.id, kind, name: el.id.slice(kind.length + 1),
      parent: parent ? parent.id : null,
      x: r.left - stage.left, y: r.top - stage.top, w: r.width, h: r.height,
      opacity: parseFloat(cs.opacity),
      anchor: el.dataset.anchor || null,
      tint: el.dataset.tint || null,
      keepColor: el.dataset.keepColor === 'true',
      glow: parseFloat(el.dataset.glow || '0'),
      glowColor: el.dataset.glowColor || null,
      radius: el.getAttribute('rx') ? parseFloat(el.getAttribute('rx')) : null,
      slice: el.dataset.slice ? parseFloat(el.dataset.slice) : null,
      z: parseInt(el.dataset.z || '0'),
      color: firstPaint(el),
    };
    if (kind === 'text') {
      item.text = el.textContent.trim();
      item.fontSize = parseFloat(cs.fontSize);
      item.fontFamily = cs.fontFamily;
      item.fontWeight = cs.fontWeight;
      item.textAnchor = cs.textAnchor;
      item.color = cs.fill;
    }
    if (kind === 'frame') {
      item.color = cs.fill !== 'none' ? cs.fill : cs.stroke;
      item.fillOpacity = parseFloat(cs.fillOpacity);
    }
    out.push(item);
  }
  return out;
}
"""


def rgb_to_hex(css: str) -> str:
    css = css.strip()
    if css.startswith("url(") or css in ("none", ""):
        return "#FFFFFF"  # gradient/pattern fill: rebuild it with a UIGradient (layout marks "fillPaint")
    if css.startswith("#"):
        return css.upper()
    nums = [float(v) for v in css[css.find("(") + 1:css.find(")")].replace("/", ",").split(",")[:3]]
    return "#" + "".join(f"{int(round(v)):02X}" for v in nums)


def infer_anchor(x: float, y: float, w: float, h: float, W: float, H: float) -> str:
    cx, cy = x + w / 2, y + h / 2
    hx = "l" if cx < W / 3 else ("r" if cx > 2 * W / 3 else "c")
    vy = "t" if cy < H / 3 else ("b" if cy > 2 * H / 3 else "m")
    return vy + hx


ANCHOR_VEC = {"t": 0.0, "m": 0.5, "b": 1.0, "l": 0.0, "c": 0.5, "r": 1.0}


def placement(item: dict, box: tuple[float, float, float, float]) -> dict:
    """Position relative to a parent box (x, y, w, h). Gives both scale-only and anchored offset forms."""
    px, py, pw, ph = box
    x, y, w, h = item["x"] - px, item["y"] - py, item["w"], item["h"]
    anchor = item.get("anchor") or infer_anchor(x, y, w, h, pw, ph)
    ay, ax = ANCHOR_VEC[anchor[0]], ANCHOR_VEC[anchor[1]]
    # point of the element that sits on the anchor
    ex, ey = x + ax * w, y + ay * h
    return {
        "anchor": anchor,
        "anchorPoint": [ax, ay],
        "scale": {"position": [round(ex / pw, 4), round(ey / ph, 4)], "size": [round(w / pw, 4), round(h / ph, 4)]},
        # offset from the anchored parent edge: UDim2.new(ax, ox, ay, oy) with Size UDim2.fromOffset(w, h)
        "offset": {"position": [round(ex - ax * pw, 1), round(ey - ay * ph, 1)], "size": [round(w, 1), round(h, 1)]},
    }


def bleed(png: Path, white: bool) -> None:
    """Fix dark fringes: Roblox filters images without premultiplied alpha, so the RGB of fully transparent
    pixels bleeds into edges. Browsers write them as black -> dark halo around every shape (seen in Studio).
    White assets: RGB = white everywhere. Colored assets: spread edge colors outward into transparent pixels."""
    import numpy as np
    from scipy.ndimage import distance_transform_edt
    img = Image.open(png).convert("RGBA")
    a = np.asarray(img).copy()
    if white:
        a[..., :3] = 255
    else:
        empty = a[..., 3] == 0
        if empty.any() and (~empty).any():
            _, (iy, ix) = distance_transform_edt(empty, return_indices=True)
            a[..., :3] = a[iy, ix, :3]
    Image.fromarray(a).save(png)


def glow_from(png: Path, radius_px: float) -> Path:
    img = Image.open(png).convert("RGBA")
    alpha = img.getchannel("A").filter(ImageFilter.GaussianBlur(radius_px))
    out = Image.new("RGBA", img.size, (255, 255, 255, 0))
    out.putalpha(alpha)
    dst = png.with_name(png.stem + "_glow.png")
    out.save(dst)
    return dst


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("src", type=Path)
    ap.add_argument("-o", "--out", type=Path, required=True)
    ap.add_argument("--scale", type=float, default=2, help="export scale vs mockup px (2 = HiDPI-safe)")
    ap.add_argument("--pad", type=float, default=4, help="transparent padding in mockup px (stroke + filtering)")
    ap.add_argument("--only", action="append", default=[], help="fnmatch on asset id")
    a = ap.parse_args()
    a.out.mkdir(parents=True, exist_ok=True)

    html, W, H = page_html(a.src, None, 1, [])
    tmp = a.src.with_suffix(".export.html")
    tmp.write_text(html, encoding="utf-8")
    layout: dict = {"source": str(a.src), "reference": [W, H], "scale": a.scale, "items": []}
    warnings: list[str] = []
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch()
            page = browser.new_page(viewport={"width": W, "height": H}, device_scale_factor=a.scale)
            page.goto(tmp.resolve().as_uri())
            page.wait_for_timeout(150)
            items = page.evaluate(COLLECT_JS)
            by_id = {it["id"]: it for it in items}

            # preview of everything that is part of the UI (ignores ref/guide layers)
            prev = page.add_style_tag(content='[id^="ref"],[id^="guide"],[id^="bg"]{display:none!important}')
            page.locator("#stage").screenshot(path=str(a.out / "_preview.png"), omit_background=True)
            prev.evaluate("el => el.remove()")

            for it in items:
                parent_box = (0.0, 0.0, float(W), float(H))
                if it["parent"] and it["parent"] in by_id:
                    pb = by_id[it["parent"]]
                    parent_box = (pb["x"], pb["y"], pb["w"], pb["h"])
                entry = {k: it[k] for k in ("id", "kind", "name", "parent", "z")}
                entry["box"] = [round(it[k], 1) for k in ("x", "y", "w", "h")]
                entry["transparency"] = round(1 - it["opacity"], 3)
                if it["kind"] == "text":
                    entry |= {"text": it["text"], "fontSize": round(it["fontSize"]), "fontFamily": it["fontFamily"],
                              "fontWeight": it["fontWeight"], "textAnchor": it["textAnchor"],
                              "color": rgb_to_hex(it["color"])}
                elif it["kind"] == "frame":
                    entry["color"] = rgb_to_hex(it["color"])
                    if str(it["color"]).startswith("url("):
                        entry["fillPaint"] = it["color"]
                    entry["transparency"] = round(1 - it["opacity"] * it["fillOpacity"], 3)
                    if it["radius"]:
                        entry["radius"] = it["radius"]

                if it["kind"] == "asset" and (not a.only or any(fnmatch.fnmatch(it["id"], pat) for pat in a.only)):
                    pad = a.pad + it["glow"] * 3
                    clip = {"x": max(0, it["x"] - pad), "y": max(0, it["y"] - pad),
                            "width": it["w"] + 2 * pad, "height": it["h"] + 2 * pad}
                    css = ('#stage svg *{visibility:hidden!important}'
                           f'#stage #{it["id"]},#stage #{it["id"]} *{{visibility:visible!important}}'
                           f'#stage #{it["id"]}{{opacity:1!important;'
                           + ('' if it["keepColor"] else 'filter:brightness(0) invert(1);') + '}')
                    handle = page.add_style_tag(content=css)
                    png = a.out / f'{it["name"]}.png'
                    page.screenshot(path=str(png), clip=clip, omit_background=True)
                    handle.evaluate("el => el.remove()")
                    bleed(png, white=not it["keepColor"])
                    img = Image.open(png)
                    entry["image"] = png.name
                    entry["imageSize"] = list(img.size)
                    entry["box"] = [round(clip["x"], 1), round(clip["y"], 1), round(clip["width"], 1),
                                    round(clip["height"], 1)]
                    entry["color"] = rgb_to_hex(it["tint"] or it["color"]) if not it["keepColor"] else "#FFFFFF"
                    if max(img.size) > MAX_SIDE:
                        warnings.append(f'{png.name} is {img.size[0]}x{img.size[1]} > {MAX_SIDE}: lower --scale or split')
                    if it["slice"]:
                        m = (it["slice"] + pad) * a.scale
                        entry["sliceCenter"] = [round(m), round(m), round(img.size[0] - m), round(img.size[1] - m)]
                    if it["glow"]:
                        g = glow_from(png, it["glow"] * a.scale)
                        entry["glow"] = g.name
                        entry["glowColor"] = rgb_to_hex(it["glowColor"]) if it["glowColor"] else entry["color"]
                    it_box = dict(it, x=clip["x"], y=clip["y"], w=clip["width"], h=clip["height"])
                    entry |= placement(it_box, parent_box)
                else:
                    entry |= placement(it, parent_box)
                layout["items"].append(entry)
            browser.close()
    finally:
        tmp.unlink(missing_ok=True)

    (a.out / "layout.json").write_text(json.dumps(layout, indent=2), encoding="utf-8")
    n_assets = sum(1 for e in layout["items"] if "image" in e)
    print(f"exported {n_assets} assets, {len(layout['items'])} layout items -> {a.out}")
    for w in warnings:
        print("WARN", w)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
