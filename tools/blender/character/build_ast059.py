"""AST-059 Acc_Raincoat: yellow rain cape (Body, anchor Torso) + rounded hood (Hood, anchor Head) for the Sheep rig.

  sh bl.sh tools/blender/character/build_ast059.py            (headless; opens AST-053_Animal_Sheep.blend as REF base)

Modelled in place (rest pose of the crew kit, Blender Z up / Y front, studs), like Acc_SafetyVest. Colour only from the
KayKit atlas (Day cells): outer = yellow row 2 col 3, lining/toggles = amber row 2 col 2. Writes the .blend; export and
renders are done by export_ast059.py / render_ast059.py.
"""
import bpy, bmesh, math, json
from mathutils import Vector

ROOT = "D:/UserData/Documents/ModuxGames/Sell Hotdogs/Assets/"
SHEEP = ROOT + "blender/character/AST-053_Animal_Sheep.blend"
OUT_BLEND = ROOT + "blender/character/AST-059_Acc_Raincoat.blend"
GRID = (8, 4)
YELLOW = (2, 3, 0.12, 0.55)   # outer shell
AMBER = (2, 2, 0.05, 0.4)    # lining, toggles, hem lip

bpy.ops.wm.open_mainfile(filepath=SHEEP)
keep = {"Head_Sheep", "Wool_Sheep", "Ears_Sheep", "Face_Sheep", "REF_Torso", "REF_Left Arm", "REF_Right Arm",
        "REF_Left Leg", "REF_Right Leg"}
for o in list(bpy.data.objects):
    if o.name not in keep:
        bpy.data.objects.remove(o, do_unlink=True)
for o in bpy.data.objects:
    if not o.name.startswith("REF_"):
        o.name = "REF_" + o.name
mat = bpy.data.materials["M_RestaurantBits"]


class B:
    def __init__(self):
        self.bm = bmesh.new()
        self.tags = []

    def v(self, p):
        return self.bm.verts.new(p)

    def f(self, vs, want, band):
        fc = self.bm.faces.new(vs)
        self.tags.append((fc, want, band))
        return fc

    def finish(self, name):
        bm = self.bm
        bm.normal_update()
        for fc, want, band in self.tags:   # orient from intent: open shells defeat automatic recalc
            w = want(fc.calc_center_median()) if callable(want) else want
            if fc.normal.dot(w) < 0:
                fc.normal_flip()
        bm.normal_update()
        bands = {fc.index: band for fc, _, band in self.tags}
        zs = [v.co.z for v in bm.verts]
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = True
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        me.materials.append(mat)
        uv = me.uv_layers.new(name="UVMap")
        z0, z1 = min(zs), max(zs)
        cols, rows = GRID
        for p in me.polygons:
            row, col, lo, hi = bands[p.index]
            for li in p.loop_indices:
                z = me.vertices[me.loops[li].vertex_index].co.z
                t = (z - z0) / (z1 - z0) if z1 > z0 else 0.5
                uv.data[li].uv = ((col + 0.5) / cols, 1 - (row + hi - t * (hi - lo)) / rows)
        return o


def sup(a, rx, ry, p=3.0):
    c, s = math.cos(a), math.sin(a)
    return rx * math.copysign(abs(c) ** (2 / p), c), ry * math.copysign(abs(s) ** (2 / p), s)


# ------------------------------------------------------------ Body (anchor Torso)
N = 12
rings = [  # z, rx, ry   (top to hem)
    (4.10, 1.08, 0.66),
    (3.45, 1.09, 0.67),
    (2.75, 1.09, 0.68),
    (2.05, 1.12, 0.74),
    (1.55, 1.30, 0.88),
]
bb = B()
R = []
for k, (z, rx, ry) in enumerate(rings):
    row = []
    for i in range(N):
        a = 2 * math.pi * i / N + math.pi / N
        x, y = sup(a, rx, ry)
        zz = z + (0.075 * math.cos(3 * a) if k == len(rings) - 1 else 0.0)   # wavy hem
        row.append(bb.v((x, y, zz)))
    R.append(row)
outward = lambda c: Vector((c.x, c.y, 0))
for k in range(len(R) - 1):
    for i in range(N):
        j = (i + 1) % N
        bb.f([R[k][i], R[k + 1][i], R[k + 1][j], R[k][j]], outward, YELLOW)
inset, lip_h = 0.07, 0.28
RI, RU = [], []
for i in range(N):
    p = R[-1][i].co
    d = Vector((p.x, p.y, 0)).normalized() * inset
    RI.append(bb.v((p.x - d.x, p.y - d.y, p.z)))
    RU.append(bb.v((p.x - d.x, p.y - d.y, p.z + lip_h)))
for i in range(N):
    j = (i + 1) % N
    bb.f([R[-1][i], RI[i], RI[j], R[-1][j]], Vector((0, 0, -1)), AMBER)
    bb.f([RI[i], RU[i], RU[j], RI[j]], lambda c: Vector((-c.x, -c.y, 0)), AMBER)
body = bb.finish("Acc_Raincoat_Body")

# three chunky toggles down the front (amber, flat shaded)
tg = B()
for zt in (3.55, 3.0, 2.45):
    yf = 0.67
    for (z0, rx, ry), (z1, rx1, ry1) in zip(rings, rings[1:]):
        if z1 <= zt <= z0:
            yf = ry1 + (ry - ry1) * (zt - z1) / (z0 - z1)
    w, d, h = 0.16, 0.10, 0.2
    y0 = yf - 0.03
    vs = {(sx, sy, sz): tg.v((sx * w / 2, y0 + sy * d, zt + sz * h / 2)) for sx in (-1, 1) for sy in (0, 1) for sz in (-1, 1)}
    def quad(keys, nrm):
        tg.f([vs[k] for k in keys], nrm, AMBER)
    quad([(-1, 0, -1), (1, 0, -1), (1, 1, -1), (-1, 1, -1)], Vector((0, 0, -1)))
    quad([(-1, 0, 1), (-1, 1, 1), (1, 1, 1), (1, 0, 1)], Vector((0, 0, 1)))
    quad([(-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1)], Vector((0, 1, 0)))
    quad([(-1, 0, -1), (-1, 0, 1), (1, 0, 1), (1, 0, -1)], Vector((0, -1, 0)))
    quad([(-1, 0, -1), (-1, 1, -1), (-1, 1, 1), (-1, 0, 1)], Vector((-1, 0, 0)))
    quad([(1, 0, -1), (1, 0, 1), (1, 1, 1), (1, 1, -1)], Vector((1, 0, 0)))
tog = tg.finish("Toggles")
for p in tog.data.polygons:
    p.use_smooth = False
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True); tog.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
body = bpy.context.view_layer.objects.active
body.name = "Acc_Raincoat_Body"; body.data.name = "Acc_Raincoat_Body"

# ------------------------------------------------------------ Hood (anchor Head)
HN = 10
A0, A1 = math.radians(52), math.radians(308)   # azimuth from +Y (front); the front is open
hring = [  # z, rx, ry, cy
    (3.98, 1.28, 1.08, -0.22),
    (4.60, 1.72, 1.45, -0.35),
    (5.35, 1.74, 1.50, -0.40),
    (5.95, 1.42, 1.28, -0.45),
]
POLE = (0.0, -0.45, 6.4)
THK = 0.08


def hood_pts(shrink):
    rr = []
    for z, rx, ry, cy in hring:
        rr.append([Vector(((rx - shrink) * math.sin(A0 + (A1 - A0) * i / HN),
                           cy + (ry - shrink) * math.cos(A0 + (A1 - A0) * i / HN),
                           z)) for i in range(HN + 1)])
    return rr, Vector((POLE[0], POLE[1], POLE[2] - shrink))


hb = B()
axis = lambda c: Vector((c.x, c.y + 0.4, c.z - 4.9))
grids = {}
for name, shrink, outer, band in (("o", 0.0, True, YELLOW), ("i", THK, False, AMBER)):
    rr, pole = hood_pts(shrink)
    V = [[hb.v(p) for p in row] for row in rr]
    P = hb.v(pole)
    t = axis if outer else (lambda c: -axis(c))
    for k in range(len(V) - 1):
        for i in range(HN):
            hb.f([V[k][i], V[k + 1][i], V[k + 1][i + 1], V[k][i + 1]], t, band)
    for i in range(HN):
        hb.f([V[-1][i], P, V[-1][i + 1]], t, band)
    grids[name] = (V, P)
(VO, PO), (VI, PI) = grids["o"], grids["i"]
for i in range(HN):
    hb.f([VO[0][i], VI[0][i], VI[0][i + 1], VO[0][i + 1]], Vector((0, 0, -1)), YELLOW)
for end in (0, HN):
    ny = Vector((1 if end == 0 else -1, 0.6, 0)) if False else Vector((0, 1, 0))
    for k in range(len(VO) - 1):
        hb.f([VO[k][end], VO[k + 1][end], VI[k + 1][end], VI[k][end]], ny, YELLOW)
    hb.f([VO[-1][end], PO, PI, VI[-1][end]], ny, YELLOW)
hood = hb.finish("Acc_Raincoat_Hood")

for o in (body, hood):
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
    bm.to_mesh(o.data); bm.free()
    o.data.update()

bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
info = {}
for o in (body, hood):
    pts = [v.co for v in o.data.vertices]
    info[o.name] = {"tris": len(o.data.polygons), "min": [round(min(p[i] for p in pts), 3) for i in range(3)],
                    "max": [round(max(p[i] for p in pts), 3) for i in range(3)]}
print("INFO", json.dumps(info))
