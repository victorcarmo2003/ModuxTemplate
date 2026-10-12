"""AST-027 Open Late Trailer: lower the service counter, the window sill and the fold shelf by 0.9 stud.

  sh bl.sh tools/blender/lower_trailer_counter.py -- <abs path AST-027_OpenLateTrailer.blend>

Why (2026-10-11, first-person night): counter top 3.5 over the floor (Z 5.5 in the model) hides the customers in the
window and the toppings. New counter top / window sill: Z 4.6 (2.6 over the floor, Z 2.0).
Idempotent: a marker custom property on the scene ("counter_lowered") stops a second run.
Edits (model space, 1 unit = 1 stud, +Y = front/window side):
  Counters   Z 2.0..5.5 -> 2.0..4.6 (linear squash, floor stays)
  Body       Z 2.2..5.18 -> 2.2..4.286 (linear squash of the lower skirt), window sill/frame verts (Z 5.18..6.2,
             inside the window X -10.3..12.8, Y >= 5) -> -0.9 (opening is 0.9 taller: sill 4.6, head stays 10.0)
  Awning     (service shutter plate, closed) bottom edge Z 5.45/5.53 -> 4.55/4.63 (head stays 10.25)
  Shelf_Fold whole piece -0.9 (stays under the new sill)
  Mount_*    counter mounts Z 5.5 -> 4.6 (Grill, Rail, StockBun, StockSausage, Toppings, Board, Counter, Drawer, Coffee)
Wall mounts (Mount_Phone, Mount_Switch), Seat_*, Hide_*, Door, roof, wheels, Floor do not change.
"""
import bpy, sys

DROP = 0.9
OLD_TOP, NEW_TOP, FLOOR = 5.5, 4.6, 2.0
path = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.open_mainfile(filepath=path)
sc = bpy.context.scene
if sc.get("counter_lowered"):
    print("ALREADY lowered, nothing to do")
    sys.exit(0)


def remap(o, fn):
    mw = o.matrix_world.copy()
    inv = mw.inverted()
    for v in o.data.vertices:
        w = mw @ v.co
        w.z = fn(w)
        v.co = inv @ w
    o.data.update()


k_counter = (NEW_TOP - FLOOR) / (OLD_TOP - FLOOR)
remap(bpy.data.objects["Counters"], lambda w: FLOOR + (w.z - FLOOR) * k_counter)

LOW_TOP = 5.18  # last ring of the lower skirt
k_skirt = (LOW_TOP - DROP - 2.2) / (LOW_TOP - 2.2)


def body(w):
    if w.z <= 2.2:
        return w.z
    if w.z <= LOW_TOP + 0.005:
        return 2.2 + (w.z - 2.2) * k_skirt
    if w.z < 6.2:
        assert w.y >= 5.0 - 1e-3 and -10.4 <= w.x <= 12.9, ("window ring expected", tuple(w))
        return w.z - DROP
    return w.z


remap(bpy.data.objects["Body"], body)
remap(bpy.data.objects["Awning"], lambda w: w.z - DROP if w.z < 5.6 else w.z)
remap(bpy.data.objects["Shelf_Fold"], lambda w: w.z - DROP)
for n in ("Grill", "Rail", "StockBun", "StockSausage", "Toppings", "Board", "Counter", "Drawer", "Coffee"):
    e = bpy.data.objects["Mount_" + n]
    assert abs(e.location.z - OLD_TOP) < 1e-4, (n, e.location.z)
    e.location.z = NEW_TOP
sc["counter_lowered"] = True
bpy.ops.wm.save_mainfile()
for n in ("Body", "Counters", "Awning", "Shelf_Fold"):
    o = bpy.data.objects[n]
    zs = [(o.matrix_world @ v.co).z for v in o.data.vertices]
    print("RESULT", n, "Z %.3f..%.3f" % (min(zs), max(zs)))
