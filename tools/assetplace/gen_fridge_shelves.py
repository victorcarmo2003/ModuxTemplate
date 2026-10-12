"""AST-030_FridgeDisplayShelves - open-interior dairy fridge (Mart v2 DAIRY), headless Blender.

  sh bl.sh gen_fridge_shelves.py -- <atlas.png> <out.blend> [<preview_dir>]

Frame = the SAME frame as the old closed AST-030_FridgeDisplay source (doors on Blender -Y = Roblox local +Z, bbox x +-2, y -1.25..1.25,
z 0..7) so the live placements (CFrame) do not change. Atlas = Kenney MiniMarket colormap (16 cols x 4 rows of vertical gradients).
Objects (one MeshPart each in Roblox): Fridge_Body (off-white cabinet, cream interior), Fridge_Trim (teal frames/header/handles,
Color set in Studio), Fridge_Doors (glass panes, Transparency/Material in Studio), Fridge_Shelves (steel boards), Fridge_Led (Neon strips).
"""
import sys, os
exec(open(os.path.expanduser("~/.claude/skills/roblox-asset-pipeline/scripts/blender/toylib.py"), encoding="utf-8").read())
A = sys.argv[sys.argv.index("--") + 1:]
ATLAS, OUT = A[0], A[1]
reset(ATLAS, grid=(16, 4))
WHITE, CREAM, STEEL, DARK = (3, 8), (2, 0), (3, 6), (3, 0)
FLAT = (0.3, 0.7)

def b(name, size, center, band, drop=()):
    return box(name, size, center, band + FLAT, drop=drop)

# ---- body
body = [
    b("sL", (0.15, 2.0, 6.22), (-1.925, 0.25, 3.89), WHITE),
    b("sR", (0.15, 2.0, 6.22), (1.925, 0.25, 3.89), WHITE),
    b("top", (3.7, 2.0, 0.39), (0, 0.25, 6.805), WHITE),
    b("plinth", (4.0, 2.15, 0.78), (0, 0.175, 0.39), DARK),
    b("back", (3.7, 0.15, 5.83), (0, 1.175, 3.695), CREAM),
    b("floor", (3.7, 1.85, 0.12), (0, 0.175, 0.84), CREAM),
    b("divider", (0.1, 1.85, 5.71), (0, 0.175, 3.755), WHITE),
]
BODY = join(body, "Fridge_Body")

# ---- trim (teal in Studio): header band, door frames, handles
trim = [b("hdr", (4.0, 0.2, 0.39), (0, -0.85, 6.805), WHITE, drop=[(0, 1, 0)])]
for (x0, x1) in ((-1.85, -0.05), (0.05, 1.85)):
    cx = (x0 + x1) / 2
    trim += [b("vl", (0.12, 0.25, 5.83), (x0 + 0.06, -0.875, 3.695), WHITE),
             b("vr", (0.12, 0.25, 5.83), (x1 - 0.06, -0.875, 3.695), WHITE),
             b("hb", (1.56, 0.25, 0.12), (cx, -0.875, 0.84), WHITE),
             b("ht", (1.56, 0.25, 0.12), (cx, -0.875, 6.55), WHITE)]
    hx = -0.12 if cx < 0 else 0.12
    trim += [b("hd", (0.09, 0.2, 1.8), (hx, -1.15, 3.7), WHITE),
             b("hs1", (0.09, 0.06, 0.1), (hx, -1.02, 4.4), WHITE),
             b("hs2", (0.09, 0.06, 0.1), (hx, -1.02, 3.0), WHITE)]
TRIM = join(trim, "Fridge_Trim")

# ---- glass panes
doors = [b("gA", (1.6, 0.04, 5.65), (-0.95, -0.91, 3.69), WHITE),
         b("gB", (1.6, 0.04, 5.65), (0.95, -0.91, 3.69), WHITE)]
DOORS = join(doors, "Fridge_Doors")

# ---- shelves (2 per bay on top of the floor) + LED
sh, led = [], []
for cx in (-0.95, 0.95):
    for zt in (2.9, 4.9):
        sh.append(b("board", (1.8, 1.8, 0.1), (cx, 0.2, zt - 0.05), STEEL))
        sh.append(b("lip", (1.8, 0.04, 0.1), (cx, -0.72, zt + 0.05), CREAM))
        led.append(b("led", (1.5, 0.06, 0.06), (cx, -0.6, zt - 0.13), WHITE))
    led.append(b("ledtop", (1.5, 0.06, 0.06), (cx, -0.6, 6.58), WHITE))
SHELVES = join(sh, "Fridge_Shelves")
LED = join(led, "Fridge_Led")

for o in (BODY, TRIM, DOORS, SHELVES, LED):
    print(o.name, "tris", tris_of(o))
lo, hi = bbox([BODY, TRIM, DOORS, SHELVES, LED])
print("BBOX", tuple(round(v, 3) for v in lo), tuple(round(v, 3) for v in hi))
img = bpy.data.images[0]
img.pack()
if len(A) > 2:
    render(A[2] + "/fridge_front.png", direction=(0.45, -1.0, 0.35), res=(700, 900), margin=1.1)
    render(A[2] + "/fridge_back.png", direction=(-0.6, 1.0, 0.4), res=(700, 900), margin=1.1)
save_blend(OUT)
