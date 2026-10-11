# AST-104 Gear Stand (fachada/estrutura do quiosque do fundo do Mart, MAP-01 18.4). No shutters (AST-103 Triple) and
# no pedestals (AST-105): those are their own models, placed with the same frame.
# Frame: x = WORLD Z - 20, y = 97 - WORLD X (front +y faces the shop, lands on Roblox -Z), z = above the Mart floor.
import os, sys
HERE = os.path.dirname(os.path.abspath(sys.argv[sys.argv.index("--python") + 1]))
exec(open(os.path.join(HERE, "common.py"), encoding="utf-8").read())
KP = ROOT + "Assets/KitchenPack/Assets/fbx/"
MM = ROOT + "Assets/MiniMarket/Models/FBX format/"

reset(ATLAS)
setup_render()
P = []  # structure parts, joined into "Structure"

# fascia (testeira) h 7..11, X 93.6..94.4 -> y 2.6..3.4
P.append(box("Fascia", (25.0, 0.8, 4.0), (0, 3.0, 9.0), TEAL, bevel=0.08))
# sign field for the existing UPGRADES neon: Mustard frame + dark backing (neon reads on it day and night)
P.append(box("SignFrame", (16.4, 0.08, 2.3), (0, 3.44, 9.75), MUSTARD, bevel=0.035))
P.append(box("SignBack", (16.0, 0.08, 1.98), (0, 3.51, 9.75), DARK, bevel=0.03))
# side name plates (bench name text, TASK-142, goes here by SurfaceGui) - plain Cream with Mustard rim
for sx in (-1, 1):
    P.append(box("NameRim", (3.4, 0.07, 1.5), (sx * 10.5, 3.435, 9.75), MUSTARD, bevel=0.03))
    P.append(box("NamePlate", (3.1, 0.07, 1.2), (sx * 10.5, 3.5, 9.75), CREAM, bevel=0.025))
# top cornice / roof cap over the whole kiosk (overhangs the front)
P.append(box("Cap", (25.8, 6.9, 0.38), (0, 0.35, 11.19), CREAM, bevel=0.1))
P.append(box("CapTrim", (25.9, 0.14, 0.14), (0, 3.78, 11.0), MUSTARD, bevel=0.04))
# posts (guides of the doors): Z 7.5..8.0, 17.5..18.0, 22.0..22.5, 32.0..32.5
for x0 in (-12.5, -2.5, 2.0, 12.0):
    cx = x0 + 0.25
    P.append(box("Post", (0.5, 0.8, 7.0), (cx, 3.0, 3.5), CREAM, bevel=0.06))
    P.append(box("PostFoot", (0.62, 0.92, 0.45), (cx, 3.0, 0.225), STEEL, bevel=0.05))
    P.append(box("PostCap", (0.62, 0.92, 0.18), (cx, 3.0, 6.91), MUSTARD, bevel=0.04))
# side walls (kiosk ends) and back wall line: Teal panels with a Cream corner bead
for sx in (-1, 1):
    P.append(box("SideWall", (0.3, 5.6, 11.0), (sx * 12.35, -0.2, 5.5), TEAL, bevel=0.06))
    P.append(cyl("CornerBead", 0.36, 11.0, (sx * 12.42, 2.62, 5.5), "z", CREAM, segs=8))
# low glass grates in the L and R openings (X 94.0..94.3 -> y 2.7..3.0), h 2.6, with collision in Roblox
G = []
for name, x0, x1 in (("L", -12.0, -2.5), ("R", 2.5, 12.0)):
    cx, w = (x0 + x1) / 2, x1 - x0
    P.append(box("Kick", (w, 0.3, 0.6), (cx, 2.85, 0.3), WOOD_D, bevel=0.05))
    P.append(box("TopRail", (w, 0.36, 0.18), (cx, 2.85, 2.52), MUSTARD, bevel=0.06))
    for mx in (x0 + w / 3, x0 + 2 * w / 3):
        P.append(box("Mullion", (0.12, 0.2, 1.83), (mx, 2.85, 1.515), STEEL, bevel=0.03))
    G.append(box("Glass_" + name, (w - 0.02, 0.06, 1.81), (cx, 2.85, 1.515), GLASS))
# back wall shelves (scenery): two shelves per side with cartons and jars
for sx in (-1, 1):
    for z in (5.0, 6.3):
        x0, x1 = (-11.6, -3.4) if sx < 0 else (3.4, 11.6)
        cx, w = (x0 + x1) / 2, x1 - x0
        P.append(box("Shelf", (w, 0.7, 0.12), (cx, -2.6, z), WOOD, bevel=0.03))
        for bx in (x0 + 0.6, x1 - 0.6):
            P.append(box("Bracket", (0.1, 0.55, 0.35), (bx, -2.68, z - 0.235), STEEL, drop=[(0, -1, 0)]))
        # product cartons: varied heights and colours, never coplanar with each other
        cols = [KETCHUP, YELLOW, TEAL, ORANGE, GREEN, PEACH, RED, CREAM]
        k = 0
        x = x0 + 0.35
        while x < x1 - 0.7:
            wb = 0.55 + 0.15 * ((k * 7) % 3)
            hb = 0.45 + 0.12 * ((k * 5) % 4)
            P.append(box("Carton", (wb, 0.45, hb), (x + wb / 2, -2.62, z + 0.06 + hb / 2), cols[(k + int(z)) % len(cols)], drop=[(0, -1, 0), (0, 0, -1)]))
            x += wb + 0.12
            k += 1
STRUCT = join(P, "Structure")

# Opal counter (X 95.0..96.6, Z 18..22 -> y 0.4..2.0, x -2..2, h 3.5): cabinet + wood top + Mustard kick
C = [box("CounterBody", (3.8, 1.5, 3.1), (0, 1.2, 1.75), CREAM, bevel=0.07),
     box("CounterKick", (3.7, 1.4, 0.2), (0, 1.2, 0.1), STEEL, bevel=0.04),
     box("CounterTop", (4.0, 1.7, 0.3), (0, 1.2, 3.35), WOOD, bevel=0.07),
     box("CounterBand", (3.86, 0.06, 0.3), (0, 1.97, 2.6), MUSTARD, bevel=0.025)]
for px in (-1.25, 0, 1.25):
    C.append(box("CounterPanel", (1.05, 0.05, 1.6), (px, 1.965, 1.35), TEAL, bevel=0.03))
# service bell + crossword magazine + mug (scenery)
C.append(cyl("BellBase", 0.34, 0.06, (0.95, 1.55, 3.53), "z", DARK, segs=10))
bell = cyl("Bell", 0.3, 0.16, (0.95, 1.55, 3.64), "z", YELLOW, segs=10, d2=0.12)
C.append(bell)
C.append(box("Magazine", (0.7, 0.5, 0.05), (-0.2, 1.4, 3.525), CREAM, bevel=0.01, rot=Matrix.Rotation(0.3, 4, "Z")))
C.append(cyl("Mug", 0.26, 0.3, (0.3, 0.95, 3.65), "z", TEAL, segs=10))
COUNTER = join(C, "OpalCounter")
for o in G + [STRUCT, COUNTER]:
    pass

# Mini Market cash register on the counter (own object: it uses the Mini Market colormap atlas)
reg = import_piece(MM + "cash-register.fbx")
place_piece(reg, size=(1.3, None, 1.0), base=(-1.15, 1.15, 3.5), rotz=math.pi)
reg = join(reg, "CashRegister") if len(reg) > 1 else reg[0]
reg.name = "CashRegister"

# attachments (positions only; Roblox does not import empties - see _atts.json)
for i, (slot, wz) in enumerate((("B1", 10), ("B2", 13), ("B3", 16), ("B4", 24), ("B5", 27), ("S1", 30))):
    empty("Pedestal_" + slot, (wz - 20, 97 - 95.5, 0))
empty("Opal_Stand", (0, 97 - 98.0, 0))
empty("Neon_Upgrades", (0, 3.55, 9.75))
empty("NamePlate_L", (-10.5, 3.54, 9.75))
empty("NamePlate_R", (10.5, 3.54, 9.75))

shift = recentre()
info = report()
info["world_base_centre"] = [round(97 - shift.y, 3), "floor", round(20 + shift.x, 3)]
info["note"] = "front (-Z) faces WORLD -X; Glass_* translucent; CashRegister uses MiniMarket colormap"
atts_json(ROOT + "Assets/import/market/AST-104_GearStand_atts.json", {"_frame": "model-local Roblox axes, origin = bbox base centre"})
views("AST-104_GearStand", fp=((4.0, 10.0, 4.5), (0.0, 0.0, 4.5)))
save_all("market", "AST-104_GearStand", info)
