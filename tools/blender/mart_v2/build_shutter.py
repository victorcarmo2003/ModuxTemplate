# AST-103 Roller shutter (porta de enrolar de ripas de madeira).
#   sh bl.sh build_shutter.py
# Writes AST-103_RollerShutter (single 5 x 4.6, slats 0.35) and AST-103_RollerShutterTriple (Gear Stand doors of
# MAP-01 18.4: 9.5 / 4 / 9.5 x 7, 14 slats of 0.5), each slat its own object, numbered from the top (Slat_01 sits
# right under the roll box; the last one is the bottom bar with the handles).
import os
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"), encoding="utf-8").read()) \
    if "__file__" in dir() else None
import sys
HERE = os.path.dirname(os.path.abspath(sys.argv[sys.argv.index("--python") + 1]))
exec(open(os.path.join(HERE, "common.py"), encoding="utf-8").read())

SLAT_T = 0.11  # slat thickness (depth)


def door(prefix, x0, x1, height, slat_h, plane_y, roll_z0, roll_h, roll_depth, roll_front):
    """One shutter between x0..x1, slats from z 0 to height. Returns the created objects."""
    objs = []
    w = x1 - x0
    cx = (x0 + x1) / 2
    n = int(round(height / slat_h))
    rail_w = min(0.24, w * 0.05)
    # slats run into the rails (ends hidden inside the channel)
    sx0, sx1 = x0 + rail_w * 0.25, x1 - rail_w * 0.25
    for i in range(n):
        top = height - i * slat_h
        zc = top - slat_h / 2
        name = "%sSlat_%02d" % (prefix, i + 1)
        tone = WOOD if i % 2 == 0 else (1, 5, 0.18, 0.88)
        last = i == n - 1
        if not last:
            s = box(name, (sx1 - sx0, SLAT_T, slat_h), (cx, plane_y, zc), tone, bevel=min(0.045, slat_h * 0.13))
            objs.append(s)
        else:
            # bottom bar: wooden slat + steel foot strip + two pull handles (one mesh, moves with the slat)
            parts = [box(name, (sx1 - sx0, SLAT_T, slat_h * 0.72), (cx, plane_y, slat_h * 0.28 + slat_h * 0.36), tone,
                         bevel=min(0.045, slat_h * 0.13)),
                     box(name + "_foot", (sx1 - sx0, SLAT_T + 0.05, slat_h * 0.28), (cx, plane_y, slat_h * 0.14), STEEL,
                         bevel=0.03)]
            hw = 0.5 if w > 3 else 0.36
            for hx in ((cx - w * 0.25, cx + w * 0.25) if w > 3 else (cx,)):
                y0 = plane_y + SLAT_T / 2
                parts.append(tube(name + "_h", [(hx - hw / 2, y0 - 0.01, slat_h * 0.45), (hx - hw / 2, y0 + 0.12, slat_h * 0.45),
                                                (hx + hw / 2, y0 + 0.12, slat_h * 0.45), (hx + hw / 2, y0 - 0.01, slat_h * 0.45)],
                                  0.045, MUSTARD, sides=6))
            objs.append(join(parts, name))
    # rails (U channel read as a steel strip with a lip), full height + into the roll box
    for side, rx in (("L", x0 + rail_w / 2), ("R", x1 - rail_w / 2)):
        r = box("%sRail_%s" % (prefix, side), (rail_w, SLAT_T + 0.16, height + 0.05), (rx, plane_y, (height + 0.05) / 2),
                SLATE, bevel=0.03)
        objs.append(r)
    # roll box: rounded front (big bevel), end caps
    ry0 = roll_front - roll_depth
    rb = box("%sRoll" % prefix, (w + 0.1, roll_depth, roll_h), (cx, (ry0 + roll_front) / 2, roll_z0 + roll_h / 2),
             STEEL_L, bevel=min(0.22, roll_h * 0.22))
    lip = box("%sRoll_lip" % prefix, (w + 0.14, 0.08, 0.1), (cx, roll_front - 0.04, roll_z0 + 0.06), MUSTARD, bevel=0.03)
    objs.append(join([rb, lip], "%sRoll" % prefix))
    return objs


def build_single():
    reset(ATLAS)
    setup_render()
    W, H, SH = 5.0, 3.85, 0.35
    objs = door("", -W / 2, W / 2, H, SH, 0.0, H - 0.04, 0.78, 0.8, 0.5)
    shift = recentre()
    info = report()
    info["note"] = "slats numbered from the top; Slat_11 = bottom bar with handles"
    views("AST-103_RollerShutter", fp=((1.2, 3.2, 4.5), (0, 0, 2.2)))
    save_all("market", "AST-103_RollerShutter", info)


def build_triple():
    """Gear Stand frame: x = WORLD Z - 20, y = 97 - WORLD X (front +y faces the shop), z = above the Mart floor."""
    reset(ATLAS)
    setup_render()
    H, SH, PLANE = 7.0, 0.5, 3.2
    for p, x0, x1 in (("L_", -12.0, -2.5), ("C_", -2.0, 2.0), ("R_", 2.5, 12.0)):
        door(p, x0, x1, H, SH, PLANE, 6.95, 1.45, 1.1, 3.85)
    shift = recentre()
    info = report()
    # WORLD position of the bbox base centre (MAP = (-X, 67.887 - Z))
    info["world_base_centre"] = [round(97 - shift.y, 3), "floor", round(20 + shift.x, 3)]
    info["note"] = "front (-Z in Roblox) faces WORLD -X; prefixes L_/C_/R_; slats numbered from the top"
    views("AST-103_RollerShutterTriple", fp=((3.0, 7.0, 4.5), (-2.0, 0.0, 4.0)))
    save_all("market", "AST-103_RollerShutterTriple", info)


build_single()
build_triple()
