# AST-061 (ANM-002 The wrong food), headless Blender 5.x:
#   blender -b Assets/blender/anomaly/AST-061_WrongFood.blend --python tools/blender/anomaly/build_ast061.py -- <renderDir>
#   (add "--mode toppings" after the script to build the Wrong_* toppings blend + FBX instead)
# Rebuilds Bun_Bitten (real bite geometry + mould patches), keeps Sausage_Wrong (adds a slime highlight band),
# FBX: global_scale=1.0 to match the existing Assets/models/food and anomaly FBX (Blender import shows 1 unit = 1 stud).
# and builds the Wrong_* toppings. Colour only through the FoodPack colormap atlas (16 x 4 grid).
import bpy, bmesh, math, os, sys, random
from mathutils import Vector, Matrix

ROOT = "D:/UserData/Documents/ModuxGames/Sell Hotdogs/"
OUTD = ROOT + "Assets/blender/anomaly/"
FBXD = os.environ.get("AST_FBXD", ROOT + "Assets/models/anomaly/")
RDIR = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else ROOT + "Assets/reference/"
RDIR = RDIR.rstrip("/\\") + "/"
exec(open("C:/Users/hakor/.claude/skills/roblox-asset-pipeline/scripts/blender/toylib.py", encoding="utf-8").read())
mat = bpy.data.materials["M_FoodPack"]

# atlas bands (row, col, lo, hi) in the 16 x 4 FoodPack colormap
CRUST = (2, 0, 0.1, 0.9); CREAM = (2, 6, 0.1, 0.9)
MOLD = (3, 4, 0.1, 0.9); MOLD_L = (2, 8, 0.1, 0.6)
SL_PALE = (3, 12, 0.0, 0.3); SL_MINT = (2, 8, 0.0, 0.15)
ROACH = (2, 2, 0.1, 0.9); ROACH_D = (3, 2, 0.1, 0.9)
BEETLE = (1, 4, 0.1, 0.9); BEETLE_D = (3, 6, 0.1, 0.9)
WORM_A = (2, 4, 0.5, 0.9); WORM_B = (2, 0, 0.1, 0.9); WORM_C = (3, 0, 0.1, 0.9); WORM_E = (2, 1, 0.1, 0.9)
SLIME_G = (2, 8, 0.1, 0.9); SLIME_R = (2, 14, 0.1, 0.9); BUBBLE_PINK = (3, 0, 0.1, 0.6)


def set_uv(o, fband):
    me = o.data
    uv = me.uv_layers.get("UVMap") or me.uv_layers.new(name="UVMap")
    zs = [v.co.z for v in me.vertices]; z0, z1 = min(zs), max(zs)
    for p, b in zip(me.polygons, fband):
        for li in p.loop_indices:
            z = me.vertices[me.loops[li].vertex_index].co.z
            t = (z - z0) / (z1 - z0) if z1 > z0 else 0.5
            frac = b[3] - t * (b[3] - b[2])
            uv.data[li].uv = ((b[1] + 0.5) / 16, 1 - (b[0] + frac) / 4)


def new_obj(name, bm, bands, smooth=False):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    me.materials.append(mat)
    for p in me.polygons: p.use_smooth = smooth
    set_uv(o, bands)
    return o


class Builder:
    def __init__(s): s.v = []; s.f = []; s.b = []
    def add(s, verts, faces, band):
        n = len(s.v); s.v += [tuple(x) for x in verts]
        for f in faces: s.f.append([i + n for i in f]); s.b.append(band)
    def ell(s, c, r, band, seg=8, lat=2, zmin=None):
        v = [(c[0], c[1], c[2] + r[2])]
        for i in range(1, lat + 1):
            th = math.pi * i / (lat + 1)
            for j in range(seg):
                a = 2 * math.pi * j / seg
                v.append((c[0] + r[0] * math.sin(th) * math.cos(a), c[1] + r[1] * math.sin(th) * math.sin(a), c[2] + r[2] * math.cos(th)))
        v.append((c[0], c[1], c[2] - r[2]))
        f = []; last = len(v) - 1
        for j in range(seg): f.append([0, 1 + (j + 1) % seg, 1 + j])
        for i in range(lat - 1):
            for j in range(seg):
                a = 1 + i * seg + j; b = 1 + i * seg + (j + 1) % seg
                f.append([a, b, b + seg, a + seg])
        base = 1 + (lat - 1) * seg
        for j in range(seg): f.append([last, base + j, base + (j + 1) % seg])
        if zmin is not None: v = [(x, y, max(z, zmin)) for x, y, z in v]
        s.add(v, f, band)
    def tube(s, pts, radii, band, sides=3):
        rings = []
        for i, p in enumerate(pts):
            p = Vector(p)
            t = (Vector(pts[min(i + 1, len(pts) - 1)]) - Vector(pts[max(i - 1, 0)])).normalized()
            up = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            a = t.cross(up).normalized(); b = t.cross(a).normalized()
            r = radii[i] if isinstance(radii, (list, tuple)) else radii
            rings.append([p + r * (math.cos(2 * math.pi * j / sides + math.pi / sides) * a + math.sin(2 * math.pi * j / sides + math.pi / sides) * b) for j in range(sides)])
        v = [tuple(x) for r in rings for x in r]; f = []
        for i in range(len(pts) - 1):
            for j in range(sides):
                a = i * sides + j; b = i * sides + (j + 1) % sides
                f.append([a, a + sides, b + sides, b])
        f.append(list(reversed(range(sides)))); f.append([(len(pts) - 1) * sides + j for j in range(sides)])
        s.add(v, f, band)
    def make(s, name, smooth=False):
        bm = bmesh.new()
        vs = [bm.verts.new(v) for v in s.v]
        for f in s.f: bm.faces.new([vs[i] for i in f])
        # every piece is a closed solid (ellipsoids, 3/4-sided tubes with caps): weld, then orient each island's
        # normals outward. The raw fan/quad winding above was inverted on ~85% of the faces (checked by diag, 2026-10-14).
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        return new_obj(name, bm, s.b, smooth)


def tris(o):
    o.data.calc_loop_triangles(); return len(o.data.loop_triangles)


# ------------------------------------------------------------------ Bun_Bitten
def build_bun():
    xs = [-0.5, -0.25, 0.0, 0.25, 0.5]
    outer = [(-0.225, 0.345), (-0.225, 0.16), (0.0, 0.0), (0.225, 0.16), (0.225, 0.345)]
    inner = [(0.155, 0.345), (0.0, 0.11), (-0.155, 0.345)]
    ring = outer + inner; R = len(ring); S = len(xs)
    bm = bmesh.new(); vs = [bm.verts.new((x, y, z)) for x in xs for (y, z) in ring]
    def idx(s, j): return s * R + j % R
    for s in range(S - 1):
        for j in range(R): bm.faces.new([vs[idx(s, j)], vs[idx(s + 1, j)], vs[idx(s + 1, j + 1)], vs[idx(s, j + 1)]])
    for s, rev in ((0, True), (S - 1, False)):
        ids = [idx(s, j) for j in range(R)]
        if rev: ids.reverse()
        bm.faces.new([vs[i] for i in ids])
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bun = new_obj("Bun_Bitten", bm, [CRUST] * len(bm.faces))
    # the bite: union of overlapping low-poly spheres subtracted (scalloped tooth marks, real geometry)
    spheres = [((0.12, 0.25, 0.27), 0.17), ((0.29, 0.27, 0.29), 0.17), ((0.43, 0.24, 0.285), 0.14)]
    cuts = []
    for c, r in spheres:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=5, radius=r, location=c)
        cuts.append(bpy.context.object)
    bpy.ops.object.select_all(action="DESELECT")
    for o in cuts: o.select_set(True)
    bpy.context.view_layer.objects.active = cuts[0]
    bpy.ops.object.join()
    cut = bpy.context.object
    m = bun.modifiers.new("bite", "BOOLEAN"); m.operation = "DIFFERENCE"; m.object = cut; m.solver = "EXACT"; m.use_self = True
    bpy.context.view_layer.objects.active = bun
    bpy.ops.object.modifier_apply(modifier="bite")
    bpy.data.objects.remove(cut, do_unlink=True)
    me = bun.data
    for p in me.polygons: p.use_smooth = False
    # mould blobs (flat green lumps on the crust and in the trough)
    bm = bmesh.new(); bm.from_mesh(me)
    # the boolean (EXACT, self-union of the 3 spheres) can leave mixed winding: weld and orient the closed body outward
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.faces.layers.int.new("bi")
    lay = bm.faces.layers.int["bi"]
    table = [CRUST, CREAM, MOLD, MOLD_L]
    for f in bm.faces:
        c = f.calc_center_median(); n = f.normal
        on_cut = any(abs((c - Vector(sc)).length - r) < 0.045 for sc, r in spheres)
        inner = c.z > 0.08 and abs(c.y) < 0.17 and n.y * c.y < 0 and n.z > 0.15
        if on_cut: band = CREAM            # bite flesh
        elif inner: band = CREAM           # crumb inside the trough
        else: band = CRUST                 # crust: outer walls, rim top, ends, bottom
        f[lay] = table.index(band)
    bands = [table[f[lay]] for f in bm.faces]
    rnd = random.Random(7)
    # irregular mould patches: ragged flat lumps lying on the crust (top rim, sides, end) and inside the trough
    # (centre, normal axis, radius a/b, band)
    patches = [((-0.32, -0.19, 0.345), "z", (0.13, 0.07), MOLD), ((-0.05, -0.2, 0.345), "z", (0.08, 0.05), MOLD_L),
               ((-0.2, -0.225, 0.25), "y", (0.12, 0.09), MOLD), ((0.15, -0.225, 0.22), "y", (0.09, 0.07), MOLD_L),
               ((-0.5, 0.02, 0.22), "x", (0.14, 0.1), MOLD), ((-0.15, -0.07, 0.17), "z", (0.14, 0.07), MOLD),
               ((0.2, 0.0, 0.115), "z", (0.12, 0.07), MOLD_L)]
    for c, ax, (ra, rb), b in patches:
        n = 7; ctr = Vector(c); lift = 0.02
        vs_ = []
        for k in range(n):
            a = 2 * math.pi * k / n; j = rnd.uniform(0.6, 1.25)
            u, v = ra * j * math.cos(a), rb * j * math.sin(a)
            off = {"z": (u, v, 0.0), "y": (u, 0.0, v), "x": (0.0, u, v)}[ax]
            vs_.append(bm.verts.new(ctr + Vector(off)))
        apex = {"z": (0, 0, lift), "y": (0, -lift, 0), "x": (-lift, 0, 0)}[ax]
        apx = bm.verts.new(ctr + Vector(apex))
        for k in range(n):
            ff = bm.faces.new([vs_[k], vs_[(k + 1) % n], apx]); ff[lay] = table.index(b)
            ff.normal_update()
            if ff.normal.dot(Vector(apex)) < 0: ff.normal_flip()   # open lump: normal must face away from the crust (apex side)
    bm.faces.ensure_lookup_table()
    bands = [table[f[lay]] for f in bm.faces]
    bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = False
    set_uv(bun, bands)
    return bun


def run_food():
    old = bpy.data.objects["Bun_Bitten"]
    bpy.data.objects.remove(old, do_unlink=True)
    bun = build_bun()
    for e in ("Att_Hand", "Att_Sausage"):
        bpy.data.objects[e].parent = bun
    sw = bpy.data.objects["Sausage_Wrong"]
    me = sw.data; uvl = me.uv_layers["UVMap"]
    n = 0
    for p in me.polygons:
        c = p.center
        if p.normal.z > 0.55 and abs(c.x) < 0.45 and abs(c.y) < 0.06:
            b = SL_PALE
            for li in p.loop_indices:
                uvl.data[li].uv = ((b[1] + 0.5) / 16, 1 - (b[0] + 0.15) / 4)
            n += 1
    print("sausage highlight faces", n)
    return bun, sw


# ------------------------------------------------------------------ toppings
def roach():
    b = Builder()
    b.ell((0.0, 0, 0.06), (0.27, 0.15, 0.07), ROACH, seg=8, lat=2, zmin=0.0)
    b.ell((0.34, 0, 0.045), (0.09, 0.075, 0.045), ROACH_D, seg=6, lat=1, zmin=0.0)
    for sgn in (-1, 1):
        b.tube([(0.39, 0.03 * sgn, 0.07), (0.5, 0.12 * sgn, 0.09), (0.58, 0.2 * sgn, 0.07)], 0.022, ROACH_D)
    for k, x in enumerate((0.14, 0.0, -0.14)):
        for sgn in (-1, 1):
            b.tube([(x, 0.1 * sgn, 0.03), (x + 0.02, 0.2 * sgn, 0.045), (x - 0.04 * (k - 1), 0.28 * sgn, 0.0)], 0.024, ROACH_D)
    return b.make("Wrong_Roach")


def beetle():
    b = Builder()
    b.ell((0.0, 0, 0.0), (0.22, 0.19, 0.19), BEETLE, seg=8, lat=2, zmin=0.0)
    b.ell((0.27, 0, 0.0), (0.09, 0.09, 0.09), BEETLE_D, seg=6, lat=2, zmin=0.0)
    b.add([(0.33, -0.015, 0.06), (0.33, 0.015, 0.06), (0.43, 0.0, 0.13), (0.33, 0, 0.0)], [[0, 1, 2], [0, 3, 1], [1, 3, 2], [0, 2, 3]], BEETLE_D)
    for x in (0.1, 0.0, -0.1):
        for sgn in (-1, 1):
            b.tube([(x, 0.15 * sgn, 0.03), (x + 0.02, 0.25 * sgn, 0.04), (x - 0.02, 0.31 * sgn, 0.0)], 0.026, BEETLE_D)
    return b.make("Wrong_Beetle")


def worms():
    b = Builder()
    specs = [(WORM_A, -0.2, 0.0, 1), (WORM_B, -0.07, 2.2, -1), (WORM_C, 0.07, 4.0, 1), (WORM_E, 0.2, 1.0, -1)]
    for band, y0, ph, sg in specs:
        pts = []
        for i in range(5):   # 5 rings (was 6): 4 worms x 36 = 144 tris, under the 150 of cheese
            t = i / 4
            pts.append((-0.4 + 0.8 * t, y0 + sg * 0.045 * math.sin(ph + t * 6.5), 0.055 + 0.05 * math.sin(ph + t * 5.0) ** 2 + (0.06 if i == 4 else 0)))
        b.tube(pts, [0.035, 0.06, 0.06, 0.055, 0.03], band, sides=4)
    return b.make("Wrong_Worms")


def slime(name, base, hi_band):
    b = Builder()
    b.ell((0, 0, 0.0), (0.4, 0.15, 0.2), base, seg=8, lat=2, zmin=0.0)            # mound
    b.ell((0.24, -0.04, 0.0), (0.17, 0.11, 0.13), base, seg=6, lat=1, zmin=0.0)    # second lump
    b.ell((-0.12, 0.03, 0.18), (0.07, 0.06, 0.07), hi_band, seg=6, lat=1)           # bubbles on top
    b.ell((0.2, 0.02, 0.17), (0.06, 0.05, 0.06), hi_band, seg=6, lat=1)
    b.ell((-0.22, 0.12, 0.0), (0.05, 0.05, 0.2), base, seg=5, lat=1)             # drip running down the side
    b.ell((0.1, -0.12, 0.0), (0.045, 0.045, 0.17), base, seg=5, lat=1)
    return b.make(name, smooth=True)


def run_toppings():
    for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
    fns = [roach, beetle, worms, lambda: slime("Wrong_SlimeGreen", SLIME_G, SL_MINT), lambda: slime("Wrong_SlimeRed", SLIME_R, BUBBLE_PINK)]
    objs = []
    for i, fn in enumerate(fns):
        o = fn(); o.location = (0, -1.4 * i, 0)
        e = bpy.data.objects.new("Att_Topping_" + o.name.split("_")[1], None); bpy.context.scene.collection.objects.link(e)
        e.empty_display_size = 0.05; e.parent = o
        objs.append(o)
    bpy.context.view_layer.update()
    return objs


def export(path, objs):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    RZ = Matrix.Rotation(math.pi, 4, "Z")
    allo = []
    for o in objs:
        allo.append(o); allo += [c for c in o.children]
    for o in bpy.data.objects:
        if o.parent is None and o.type == "EMPTY" and o not in allo: allo.append(o)
    for o in allo:
        if o.parent is None: o.matrix_world = RZ @ o.matrix_world
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT")
    for o in allo: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH", "EMPTY"}, apply_unit_scale=True,
                             global_scale=1.0, axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE",
                             add_leaf_bones=False, bake_anim=False, path_mode="COPY", embed_textures=True)
    for o in allo:
        if o.parent is None: o.matrix_world = RZ.inverted() @ o.matrix_world
    bpy.context.view_layer.update()


def shots(tag, objs, views):
    for e in bpy.data.objects:
        if e.type == "EMPTY": e.hide_render = True
    for n, d in views:
        render(RDIR + f"AST-061_{tag}_{n}.png", objs, direction=d, res=(900, 600), margin=1.15)


if "--mode" in sys.argv and sys.argv[sys.argv.index("--mode") + 1] == "toppings":
    objs = run_toppings()
    for o in objs: print(o.name, tris(o), [round(x, 3) for x in o.dimensions])
    export(FBXD + "AST-061_WrongToppings.fbx", objs)
    bpy.ops.wm.save_as_mainfile(filepath=OUTD + "AST-061_WrongToppings.blend")
    shots("WrongToppings", objs, [("top", (0.0, -0.01, 1.0))])
    for o in objs:
        shots("WrongToppings_" + o.name.split("_")[1], [o], [("three_quarter", (0.5, 1.0, 0.8))])
else:
    bun, sw = run_food()
    print("Bun_Bitten", tris(bun), [round(x, 3) for x in bun.dimensions], "Sausage_Wrong", tris(sw))
    bpy.context.view_layer.update()
    export(FBXD + "AST-061_WrongFood.fbx", [bun, sw])
    bpy.ops.wm.save_as_mainfile(filepath=OUTD + "AST-061_WrongFood.blend")
    shots("WrongFood", [bun, sw], [("three_quarter", (0.6, 1.0, 0.9)), ("bite", (0.15, 1.0, 0.75)), ("top", (0.0, -0.01, 1.0))])
