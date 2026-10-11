# AST-106 Section signs of the Mart v2 (MAP-01 18.6). No modelled text (style guide 1.1): the text and the AST-071 icon
# go on the Cream "Face_Front" / "Face_Back" panels by SurfaceGui. Hanging signs: 4 x 1.2 double-faced board with a
# coloured frame (front and back halves can differ: SAUCES Mustard / SNACKS - COFFEE Coffee), two eyelets and two
# steel rods "Rod_L" / "Rod_R" (plain cylinders: scale Size.Y in Roblox to reach the ceiling). Wall sign: 6 x 1.4.
import os, sys
HERE = os.path.dirname(os.path.abspath(sys.argv[sys.argv.index("--python") + 1]))
exec(open(os.path.join(HERE, "common.py"), encoding="utf-8").read())

COFFEE = (0, 6, 0.45, 1.00)
MINT = (2, 1, 0.00, 0.45)
# ceiling of the Mart at 12 over the floor; rod length = 12 - (sign centre + 0.6 + eyelet)
HANG = [("AST-106_SignBakery", BUN, BUN, 8.0),
        ("AST-106_SignProduce", MINT, MINT, 8.0),
        ("AST-106_SignMeatDeli", KETCHUP, KETCHUP, 8.5),
        ("AST-106_SignSaucesSnacks", MUSTARD, COFFEE, 9.0)]
W, HT, T = 4.0, 1.2, 0.3


def hanging(stem, front, back, centre_h):
    reset(ATLAS)
    setup_render()
    b = [box("CoreF", (W, T / 2, HT), (0, T / 4, HT / 2), front, bevel=0.07),
         box("CoreB", (W, T / 2, HT), (0, -T / 4, HT / 2), back, bevel=0.07)]
    for ex in (-1.5, 1.5):
        b.append(torus("Eyelet", 0.1, 0.035, (ex, 0, HT + 0.1), "y", STEEL, segs=8, rsegs=4))
    board = join(b, "Board")
    ff = box("Face_Front", (W - 0.36, 0.05, HT - 0.3), (0, T / 2 + 0.02, HT / 2), CREAM, bevel=0.02)
    fb = box("Face_Back", (W - 0.36, 0.05, HT - 0.3), (0, -T / 2 - 0.02, HT / 2), CREAM, bevel=0.02)
    rod = 12.0 - (centre_h + HT / 2) - 0.13
    rl = cyl("Rod_L", 0.07, rod, (-1.5, 0, HT + 0.13 + rod / 2), "z", STEEL, segs=6)
    rr = cyl("Rod_R", 0.07, rod, (1.5, 0, HT + 0.13 + rod / 2), "z", STEEL, segs=6)
    empty("Text_Front", (0, T / 2 + 0.05, HT / 2))
    empty("Text_Back", (0, -T / 2 - 0.05, HT / 2))
    recentre()
    info = report()
    info["rod_length"] = round(rod, 3)
    info["hang"] = "board bottom at %.2f over the Mart floor (centre %.2f); model base = board bottom" % (centre_h - HT / 2, centre_h)
    atts_json(ROOT + "Assets/import/market/%s_atts.json" % stem)
    lo, hi = bbox([board, ff, fb])
    render(REF + stem + ".png", [board, ff, fb, rl, rr], direction=(0.75, 1.0, 0.35))
    render(REF + stem + "_Back.png", [board, ff, fb], direction=(-0.6, -1.0, 0.2))
    save_all("market", stem, info)


def wall():
    stem = "AST-106_WallSignDairy"
    reset(ATLAS)
    setup_render()
    w, h, t = 6.0, 1.4, 0.25
    board = box("Board", (w, t, h), (0, t / 2 + 0.2, h / 2), TEAL, bevel=0.08)
    st = [cyl("Standoff", 0.18, 0.2, (sx, 0.1, h / 2), "y", STEEL, segs=8) for sx in (-2.4, 2.4)]
    board = join([board] + st, "Board")
    ff = box("Face_Front", (w - 0.4, 0.05, h - 0.32), (0, t + 0.2 + 0.02, h / 2), CREAM, bevel=0.02)
    empty("Text_Front", (0, t + 0.25, h / 2))
    recentre()
    info = report()
    info["hang"] = "back (standoffs) against the wall, front +0.47 off it; base = board bottom (h 7.8 for centre 8.5)"
    atts_json(ROOT + "Assets/import/market/%s_atts.json" % stem)
    render(REF + stem + ".png", None, direction=(0.75, 1.0, 0.35))
    save_all("market", stem, info)


for args in HANG:
    hanging(*args)
wall()
