# AST-107 Open refrigerated meat case (MEAT & DELI island, MAP-01 18.2/18.3): low (2.95), open top, reachable from both
# corridors. 4.5 x 3 per unit, the island is 2 units side by side (9 x 3). The Mini Market freezer (MM/freezer) was
# rejected: it is a closed chest with glass lids (0.8 x 0.6 x 0.35 proportions -> 2.0 tall at 4.5 wide, products hidden).
# Content: KitchenPack ham and steak (same atlas) + modelled sausage and bacon trays. Front = +y (corridor 1 side).
import os, sys
HERE = os.path.dirname(os.path.abspath(sys.argv[sys.argv.index("--python") + 1]))
exec(open(os.path.join(HERE, "common.py"), encoding="utf-8").read())
KP = ROOT + "Assets/KitchenPack/Assets/fbx/"

reset(ATLAS)
setup_render()
L, D, WALL = 4.5, 3.0, 0.22
Z0, ZB, ZW, ZR = 0.35, 2.55, 2.25, 2.85  # kick top, body top, well floor, rim top
S = [box("Kick", (L - 0.2, D - 0.2, Z0), (0, 0, Z0 / 2), DARK, bevel=0.05)]
# shell: 4 walls (hollow well) - white enamel with a Ketchup band and a Teal base line
S.append(box("WallF", (L, WALL, ZB - Z0), (0, D / 2 - WALL / 2, (Z0 + ZB) / 2), STEEL_L, bevel=0.06))
S.append(box("WallB", (L, WALL, ZB - Z0), (0, -D / 2 + WALL / 2, (Z0 + ZB) / 2), STEEL_L, bevel=0.06))
S.append(box("WallL", (WALL, D - 2 * WALL, ZB - Z0), (-L / 2 + WALL / 2, 0, (Z0 + ZB) / 2), STEEL_L, bevel=0.06))
S.append(box("WallR", (WALL, D - 2 * WALL, ZB - Z0), (L / 2 - WALL / 2, 0, (Z0 + ZB) / 2), STEEL_L, bevel=0.06))
S.append(box("Fill", (L - 2 * WALL, D - 2 * WALL, ZW - Z0), (0, 0, (Z0 + ZW) / 2), STEEL, drop=[(0, 0, -1)]))
S.append(box("WellFloor", (L - 2 * WALL - 0.02, D - 2 * WALL - 0.02, 0.06), (0, 0, ZW + 0.03), ICE))
for sy in (1, -1):
    S.append(box("Band", (L + 0.04, 0.05, 0.32), (0, sy * (D / 2 + 0.005), 1.75), KETCHUP, bevel=0.02))
    S.append(box("BaseLine", (L + 0.04, 0.05, 0.12), (0, sy * (D / 2 + 0.005), 0.62), TEAL, bevel=0.015))
for sx in (1, -1):
    S.append(box("BandEnd", (0.05, D + 0.04, 0.29), (sx * (L / 2 + 0.005), 0, 1.75), KETCHUP, bevel=0.02))
# rim (steel frame with a lip) and a low divider in the middle
rw = 0.3
for sy in (1, -1):
    S.append(box("RimLong", (L + 0.12, rw, ZR - ZB), (0, sy * (D / 2 - rw / 2 + 0.06), (ZB + ZR) / 2), STEEL, bevel=0.06))
for sx in (1, -1):
    S.append(box("RimEnd", (rw, D - 2 * rw + 0.12, ZR - ZB), (sx * (L / 2 - rw / 2 + 0.06), 0, (ZB + ZR) / 2), STEEL, bevel=0.06))
S.append(box("Divider", (0.1, D - 2 * WALL, 0.42), (0, 0, ZW + 0.21), STEEL_L, bevel=0.03))
# price rail on the front lip (for price tags by SurfaceGui)
S.append(box("PriceRail", (L - 0.6, 0.06, 0.2), (0, D / 2 + 0.03, ZB - 0.12), CREAM, bevel=0.02))
S.append(box("PriceRailB", (L - 0.6, 0.06, 0.2), (0, -D / 2 - 0.03, ZB - 0.12), CREAM, bevel=0.02))
case = join(S, "Case")

# content (one object "Food": decorative, no prompt geometry needed)
F = []
# left half: sausages (Sausage Raw pink) on 2 steel trays
for ty in (-0.55, 0.55):
    F.append(box("Tray", (1.75, 0.9, 0.08), (-1.05, ty, ZW + 0.1), STEEL_L, bevel=0.02))
    for i in range(5):
        F.append(cyl("Sausage", 0.2, 1.4, (-1.05, ty - 0.32 + i * 0.16, ZW + 0.24), "x", PINK, segs=6))
# right half: bacon slabs (back tray) and KitchenPack steak + ham (front)
F.append(box("Tray", (1.75, 0.9, 0.08), (1.05, -0.55, ZW + 0.1), STEEL_L, bevel=0.02))
for i in range(4):
    F.append(box("Bacon", (1.5, 0.2, 0.07), (1.05, -0.85 + i * 0.2, ZW + 0.18 + i * 0.012), KETCHUP if i % 2 else PINK, bevel=0.02))
for i, (px, rot) in enumerate(((0.6, 0.3),)):
    m = import_piece(KP + "food_ingredient_steak.fbx")
    place_piece(m, scale=0.8, base=(px, 0.55, ZW + 0.06), rotz=rot)
    F += m
m = import_piece(KP + "food_ingredient_ham.fbx")
place_piece(m, scale=0.6, base=(1.5, 0.55, ZW + 0.06), rotz=0.15)
F += m
for o in F:
    if o.data.materials and o.data.materials[0] != mat:
        to_atlas_material(o)
food = join(F, "Food")

empty("Prompt_Buy_Sausages", (-1.05, 0, 3.6 - 0.0))
empty("Prompt_Buy_Bacon", (1.05, 0, 3.6))
recentre()
info = report()
info["note"] = "island = 2 units side by side (9 x 3); anchors h 3.6 over the top (MAP-01 18.3)"
atts_json(ROOT + "Assets/import/market/AST-107_MeatCase_atts.json")
views("AST-107_MeatCase", fp=((0.5, 3.6, 4.5), (0.0, 0.0, 2.3)))
save_all("market", "AST-107_MeatCase", info)
