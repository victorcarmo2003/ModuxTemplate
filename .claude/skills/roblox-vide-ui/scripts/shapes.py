#!/usr/bin/env python3
"""SVG primitives for game HUDs: the shapes Roblox cannot draw natively.

Use as a library (import shapes; shapes.chamfer(...)) or CLI that prints an SVG fragment
(or a full document with --doc / -o file.svg). All geometry in px, angles in degrees, 0 deg = up, clockwise.

Kinds:
  chamfer    panel with cut corners           --w --h --cut [--corners tl,tr,br,bl] [--stroke N | --fill]
  brackets   corner brackets around a box     --w --h --len --stroke
  arc        segmented ring / gauge           --r --thickness --start --end [--segments N --gap DEG] [--cap]
  ticks      radial tick marks                --r --len --count [--start --end] --stroke [--major N --major-len L]
  chevron    > shaped arrow                    --w --h --stroke [--dir right|left|up|down] [--count N --spacing S]
  segbar     segmented bar (cells)             --w --h --cells N --gap G [--skew DEG] [--filled K]
  hexcell    hexagon (pointy top)              --r [--stroke N | --fill]
  leader     callout line with dot / elbow     --x2 --y2 [--elbow X] --stroke [--dot R]
  battery    battery glyph                     --w --h --stroke --level 0..1
  reticle    crosshair (4 ticks + center dot)  --gap --len --stroke [--dot R]
  scanlines  tileable scanline pattern        --w --h --period --line

Examples:
  python shapes.py arc --r 60 --thickness 6 --start -120 --end 120 --segments 12 --gap 3 --doc -o gauge.svg
  python shapes.py chamfer --w 300 --h 80 --cut 14 --corners tl,br --stroke 2
"""
from __future__ import annotations

import argparse
import math
import sys

WHITE = "#FFFFFF"


def _f(v: float) -> str:
    return f"{v:.2f}".rstrip("0").rstrip(".")


def _paint(stroke: float | None, fill: bool, color: str = WHITE) -> str:
    if fill:
        return f'fill="{color}" stroke="none"'
    return f'fill="none" stroke="{color}" stroke-width="{_f(stroke or 2)}" stroke-linejoin="miter" stroke-miterlimit="10"'


def polar(cx: float, cy: float, r: float, deg: float) -> tuple[float, float]:
    a = math.radians(deg)
    return cx + r * math.sin(a), cy - r * math.cos(a)


def chamfer(w: float, h: float, cut: float, corners: str = "tl,tr,br,bl", stroke: float | None = 2,
            fill: bool = False, x: float = 0, y: float = 0) -> str:
    """Rectangle with 45 deg cuts on the chosen corners. Stroke is inset by half its width so it stays inside w x h."""
    cs = set(c.strip() for c in corners.split(",") if c.strip())
    i = 0 if fill else (stroke or 2) / 2
    x0, y0, x1, y1 = x + i, y + i, x + w - i, y + h - i
    c = max(0.0, cut - i * 0.4)
    pts: list[tuple[float, float]] = []
    pts += [(x0, y0 + c), (x0 + c, y0)] if "tl" in cs else [(x0, y0)]
    pts += [(x1 - c, y0), (x1, y0 + c)] if "tr" in cs else [(x1, y0)]
    pts += [(x1, y1 - c), (x1 - c, y1)] if "br" in cs else [(x1, y1)]
    pts += [(x0 + c, y1), (x0, y1 - c)] if "bl" in cs else [(x0, y1)]
    d = "M" + " L".join(f"{_f(px)},{_f(py)}" for px, py in pts) + " Z"
    return f'<path d="{d}" {_paint(stroke, fill)}/>'


def brackets(w: float, h: float, length: float, stroke: float = 2, x: float = 0, y: float = 0) -> str:
    i = stroke / 2
    x0, y0, x1, y1 = x + i, y + i, x + w - i, y + h - i
    L = length
    d = (f"M{_f(x0)},{_f(y0 + L)} V{_f(y0)} H{_f(x0 + L)} "
         f"M{_f(x1 - L)},{_f(y0)} H{_f(x1)} V{_f(y0 + L)} "
         f"M{_f(x1)},{_f(y1 - L)} V{_f(y1)} H{_f(x1 - L)} "
         f"M{_f(x0 + L)},{_f(y1)} H{_f(x0)} V{_f(y1 - L)}")
    return f'<path d="{d}" fill="none" stroke="{WHITE}" stroke-width="{_f(stroke)}" stroke-linecap="square"/>'


def _arc_band(cx: float, cy: float, r_out: float, r_in: float, a0: float, a1: float) -> str:
    large = 1 if (a1 - a0) % 360 > 180 else 0
    p1, p2 = polar(cx, cy, r_out, a0), polar(cx, cy, r_out, a1)
    p3, p4 = polar(cx, cy, r_in, a1), polar(cx, cy, r_in, a0)
    return (f"M{_f(p1[0])},{_f(p1[1])} A{_f(r_out)},{_f(r_out)} 0 {large} 1 {_f(p2[0])},{_f(p2[1])} "
            f"L{_f(p3[0])},{_f(p3[1])} A{_f(r_in)},{_f(r_in)} 0 {large} 0 {_f(p4[0])},{_f(p4[1])} Z")


def arc(r: float, thickness: float, start: float = -120, end: float = 120, segments: int = 1, gap: float = 0,
        cx: float | None = None, cy: float | None = None, filled: int | None = None) -> str:
    """Filled ring band from start to end (deg, 0 = up, clockwise), optionally split in segments with gaps.
    filled=K draws only the first K segments (useful to export 'full' and 'empty' variants)."""
    cx = r if cx is None else cx
    cy = r if cy is None else cy
    span = end - start
    n = max(1, segments)
    seg = (span - gap * (n - 1)) / n
    parts = []
    for k in range(n if filled is None else min(filled, n)):
        a0 = start + k * (seg + gap)
        if seg >= 359.9:  # a full ring is one SVG arc with equal endpoints = nothing; draw two halves
            parts.append(_arc_band(cx, cy, r, r - thickness, a0, a0 + 180))
            parts.append(_arc_band(cx, cy, r, r - thickness, a0 + 180, a0 + 360))
        else:
            parts.append(_arc_band(cx, cy, r, r - thickness, a0, a0 + seg))
    return f'<path d="{" ".join(parts)}" fill="{WHITE}"/>'


def ticks(r: float, length: float, count: int, start: float = 0, end: float = 360, stroke: float = 2,
          major: int = 0, major_len: float | None = None, cx: float | None = None, cy: float | None = None) -> str:
    cx = r if cx is None else cx
    cy = r if cy is None else cy
    full = abs((end - start) % 360) < 1e-6
    step = (end - start) / (count if full else max(1, count - 1))
    lines = []
    for k in range(count):
        a = start + k * step
        L = major_len if (major and k % major == 0 and major_len) else length
        x0, y0 = polar(cx, cy, r, a)
        x1, y1 = polar(cx, cy, r - L, a)
        lines.append(f"M{_f(x0)},{_f(y0)} L{_f(x1)},{_f(y1)}")
    return f'<path d="{" ".join(lines)}" stroke="{WHITE}" stroke-width="{_f(stroke)}" fill="none"/>'


def chevron(w: float, h: float, stroke: float = 2, direction: str = "right", count: int = 1, spacing: float = 0,
            x: float = 0, y: float = 0) -> str:
    i = stroke
    paths = []
    for k in range(count):
        ox = x + k * spacing if direction in ("right", "left") else x
        oy = y + k * spacing if direction in ("up", "down") else y
        if direction == "right":
            pts = [(ox + i, oy + i), (ox + w - i, oy + h / 2), (ox + i, oy + h - i)]
        elif direction == "left":
            pts = [(ox + w - i, oy + i), (ox + i, oy + h / 2), (ox + w - i, oy + h - i)]
        elif direction == "up":
            pts = [(ox + i, oy + h - i), (ox + w / 2, oy + i), (ox + w - i, oy + h - i)]
        else:
            pts = [(ox + i, oy + i), (ox + w / 2, oy + h - i), (ox + w - i, oy + i)]
        paths.append("M" + " L".join(f"{_f(a)},{_f(b)}" for a, b in pts))
    return (f'<path d="{" ".join(paths)}" fill="none" stroke="{WHITE}" stroke-width="{_f(stroke)}" '
            f'stroke-linejoin="miter" stroke-linecap="butt"/>')


def segbar(w: float, h: float, cells: int, gap: float, skew: float = 0, filled: int | None = None,
           x: float = 0, y: float = 0) -> str:
    """Row of cells; skew (deg) slants each cell like a parallelogram (AW exo/armor bars)."""
    cw = (w - gap * (cells - 1)) / cells
    off = math.tan(math.radians(skew)) * h
    parts = []
    for k in range(cells if filled is None else min(filled, cells)):
        x0 = x + k * (cw + gap)
        pts = [(x0 + off, y), (x0 + cw + off, y), (x0 + cw, y + h), (x0, y + h)]
        parts.append("M" + " L".join(f"{_f(a)},{_f(b)}" for a, b in pts) + " Z")
    return f'<path d="{" ".join(parts)}" fill="{WHITE}"/>'


def hexcell(r: float, stroke: float | None = 2, fill: bool = False, cx: float | None = None,
            cy: float | None = None) -> str:
    cx = r if cx is None else cx
    cy = r if cy is None else cy
    rr = r - (0 if fill else (stroke or 2) / 2)
    pts = [polar(cx, cy, rr, a) for a in range(0, 360, 60)]
    d = "M" + " L".join(f"{_f(a)},{_f(b)}" for a, b in pts) + " Z"
    return f'<path d="{d}" {_paint(stroke, fill)}/>'


def leader(x2: float, y2: float, stroke: float = 1.5, elbow: float | None = None, dot: float = 0,
           x: float = 0, y: float = 0) -> str:
    """Callout line from (x,y) to (x2,y2); elbow = x where it turns horizontal. Dot at the origin."""
    d = f"M{_f(x)},{_f(y)} L{_f(elbow)},{_f(y2)} L{_f(x2)},{_f(y2)}" if elbow is not None else \
        f"M{_f(x)},{_f(y)} L{_f(x2)},{_f(y2)}"
    out = f'<path d="{d}" fill="none" stroke="{WHITE}" stroke-width="{_f(stroke)}"/>'
    if dot:
        out += f'<circle cx="{_f(x)}" cy="{_f(y)}" r="{_f(dot)}" fill="{WHITE}"/>'
    return out


def battery(w: float, h: float, stroke: float = 2, level: float = 1.0, x: float = 0, y: float = 0) -> str:
    cap_h = max(2.0, h * 0.06)
    cap_w = w * 0.4
    body_y = y + cap_h + 1
    body_h = h - cap_h - 1
    pad = stroke + 2
    inner_h = (body_h - 2 * pad) * max(0.0, min(1.0, level))
    out = [f'<rect x="{_f(x + (w - cap_w) / 2)}" y="{_f(y)}" width="{_f(cap_w)}" height="{_f(cap_h)}" fill="{WHITE}"/>',
           f'<rect x="{_f(x + stroke / 2)}" y="{_f(body_y + stroke / 2)}" width="{_f(w - stroke)}" '
           f'height="{_f(body_h - stroke)}" rx="{_f(w * 0.12)}" fill="none" stroke="{WHITE}" stroke-width="{_f(stroke)}"/>']
    if inner_h > 0:
        out.append(f'<rect x="{_f(x + pad)}" y="{_f(body_y + body_h - pad - inner_h)}" width="{_f(w - 2 * pad)}" '
                   f'height="{_f(inner_h)}" rx="{_f(w * 0.06)}" fill="{WHITE}"/>')
    return "".join(out)


def reticle(gap: float, length: float, stroke: float = 2, dot: float = 0, cx: float | None = None,
            cy: float | None = None) -> str:
    size = gap + length
    cx = size if cx is None else cx
    cy = size if cy is None else cy
    d = (f"M{_f(cx)},{_f(cy - gap)} V{_f(cy - size)} M{_f(cx)},{_f(cy + gap)} V{_f(cy + size)} "
         f"M{_f(cx - gap)},{_f(cy)} H{_f(cx - size)} M{_f(cx + gap)},{_f(cy)} H{_f(cx + size)}")
    out = f'<path d="{d}" stroke="{WHITE}" stroke-width="{_f(stroke)}" fill="none"/>'
    if dot:
        out += f'<circle cx="{_f(cx)}" cy="{_f(cy)}" r="{_f(dot)}" fill="{WHITE}"/>'
    return out


def scanlines(w: float, h: float, period: float = 4, line: float = 1) -> str:
    rows = int(h // period)
    d = " ".join(f"M0,{_f(k * period)} H{_f(w)}" for k in range(rows))
    return f'<path d="{d}" stroke="{WHITE}" stroke-width="{_f(line)}" fill="none"/>'


def doc(body: str, w: float, h: float, bg: str | None = None) -> str:
    bgr = f'<rect width="100%" height="100%" fill="{bg}"/>' if bg else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{_f(w)}" height="{_f(h)}" '
            f'viewBox="0 0 {_f(w)} {_f(h)}">{bgr}{body}</svg>')


def _cli() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("kind")
    for name, default in [("w", 100), ("h", 40), ("cut", 10), ("len", 12), ("stroke", 2), ("r", 50), ("thickness", 6),
                          ("start", -120), ("end", 120), ("gap", 0), ("count", 12), ("major_len", 0), ("spacing", 0),
                          ("x2", 100), ("y2", 0), ("dot", 0), ("level", 1), ("period", 4), ("line", 1), ("skew", 0)]:
        p.add_argument(f"--{name.replace('_', '-')}", type=float, default=default)
    p.add_argument("--corners", default="tl,tr,br,bl")
    p.add_argument("--fill", action="store_true")
    p.add_argument("--segments", type=int, default=1)
    p.add_argument("--cells", type=int, default=5)
    p.add_argument("--filled", type=int, default=None)
    p.add_argument("--major", type=int, default=0)
    p.add_argument("--dir", default="right")
    p.add_argument("--elbow", type=float, default=None)
    p.add_argument("--doc", action="store_true", help="wrap in a full <svg> sized to the shape")
    p.add_argument("--bg", default=None, help="background color for previews (e.g. #202020)")
    p.add_argument("-o", "--out")
    a = p.parse_args()

    k = a.kind
    size = (a.w, a.h)
    if k == "chamfer":
        body = chamfer(a.w, a.h, a.cut, a.corners, None if a.fill else a.stroke, a.fill)
    elif k == "brackets":
        body = brackets(a.w, a.h, a.len, a.stroke)
    elif k == "arc":
        body = arc(a.r, a.thickness, a.start, a.end, a.segments, a.gap, filled=a.filled)
        size = (2 * a.r, 2 * a.r)
    elif k == "ticks":
        body = ticks(a.r, a.len, int(a.count), a.start, a.end, a.stroke, a.major, a.major_len or None)
        size = (2 * a.r, 2 * a.r)
    elif k == "chevron":
        n = int(a.count) if a.count != 12 else 1
        body = chevron(a.w, a.h, a.stroke, a.dir, n, a.spacing)
        size = (a.w + a.spacing * (n - 1), a.h) if a.dir in ("right", "left") else (a.w, a.h + a.spacing * (n - 1))
    elif k == "segbar":
        body = segbar(a.w, a.h, a.cells, a.gap, a.skew, a.filled)
        size = (a.w + abs(math.tan(math.radians(a.skew)) * a.h), a.h)
    elif k == "hexcell":
        body = hexcell(a.r, None if a.fill else a.stroke, a.fill)
        size = (2 * a.r, 2 * a.r)
    elif k == "leader":
        body = leader(a.x2, a.y2, a.stroke, a.elbow, a.dot, x=a.dot, y=a.dot)
        size = (a.x2 + 2 * a.dot, max(a.y2, 0) + 2 * a.dot + a.stroke)
    elif k == "battery":
        body = battery(a.w, a.h, a.stroke, a.level)
    elif k == "reticle":
        body = reticle(a.gap, a.len, a.stroke, a.dot)
        size = (2 * (a.gap + a.len), 2 * (a.gap + a.len))
    elif k == "scanlines":
        body = scanlines(a.w, a.h, a.period, a.line)
    else:
        p.error(f"unknown kind {k}")
        return 2
    out = doc(body, *size, bg=a.bg) if (a.doc or a.out) else body
    if a.out:
        with open(a.out, "w", encoding="utf-8") as fh:
            fh.write(out)
        print(f"wrote {a.out} ({_f(size[0])}x{_f(size[1])})")
    else:
        sys.stdout.write(out + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(_cli())
