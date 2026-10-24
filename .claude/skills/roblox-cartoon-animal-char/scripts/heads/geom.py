# AST-053 round heads, step 1: geometry. For every animal: open the ORIGINAL animal .blend (heads/orig), replace
# Head_<A> by a smooth single-mesh oval head (lattice 22 x 9 rings), build the Face_<A> shell, attachments,
# adjust Ears_Dog / Beak_Owl, write heads/work_<A>.blend + heads/layout_<A>.json (texel -> 3D for painting).
# Run: ANIMAL=Dog sh bl.sh geom.py
import sys, os, json, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib, hcommon
importlib.reload(hcommon)
from hcommon import *
import bpy, bmesh
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ONLY = [a for a in os.environ.get("ANIMAL", "").split(",") if a]
SHELL_OFF = 0.012


def sgnpow(v, e):
    return math.copysign(abs(v) ** e, v)


def rings_for(an):
    """RINGS with the per-animal tweaks applied, plus RING_INSERT rings (linear interpolation)."""
    P = A[an]
    base = [(z, a + P.get("da", {}).get(z, 0.0), bf + P.get("dbf", {}).get(z, 0.0), bb, n) for z, a, bf, bb, n in RINGS]
    out = list(base)
    for zi in RING_INSERT:
        for r0, r1 in zip(base, base[1:]):
            if r0[0] < zi < r1[0]:
                t = (zi - r0[0]) / (r1[0] - r0[0])
                out.append(tuple(r0[i] + (r1[i] - r0[i]) * t for i in range(5)))
    return sorted(out)


def ring_point(an, k, th):
    z, a, bf, bb, n = RG[k]
    P = A[an]
    s, c = math.sin(th), math.cos(th)
    x = a * sgnpow(s, 2 / n)
    y = (bf if c >= 0 else bb) * sgnpow(c, 2 / n)
    if z < CAP_UNDER - 0.01:
        sn = SNOUT3.get(an)
        if sn and c > 0:
            rz = sn["rz"] if z >= sn["zc"] else sn.get("rzd", sn["rz"] * 1.8)
            r2 = (x / (sn["rx"] * 1.12)) ** 2 + ((z - sn["zc"]) / rz) ** 2
            if r2 < 1:
                y += sn["A"] * 0.88 * (1 - r2) ** 1.5 * math.sqrt(c)
        tf = P.get("tuft")
        if tf:
            w = max(0.0, (abs(s) - 0.85) / 0.15)
            x += math.copysign(tf["A"] * FS * w * math.exp(-((z - d2w_z(tf["z"])) / (tf["wz"] * FS)) ** 2), s)
    return Vector((x, y, z))


def build_head(an):
    global RG
    RG = rings_for(an)
    N = N_AZ
    phis = [-math.pi + 2 * math.pi * j / N for j in range(N)]
    ths = [math.copysign(math.pi * (abs(p) / math.pi) ** 1.25, p) for p in phis]
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    grid = [[bm.verts.new(ring_point(an, k, th)) for th in ths] for k in range(len(RG))]
    bot = bm.verts.new((0, 0, BASE_Z))
    top = bm.verts.new((0, 0, TOP_Z))
    # v by arc length along the front meridian
    fr = [grid[k][N // 2].co for k in range(len(RG))]
    L = [fr[0].length if False else (fr[0] - bot.co).length]
    for k in range(1, len(fr)):
        L.append(L[-1] + (fr[k] - fr[k - 1]).length)
    L.append(L[-1] + (top.co - fr[-1]).length)
    tot = L[-1]
    vr = [0.012 + 0.976 * l / tot for l in L]          # vr[k] ring k, vr[-1] top pole
    v_bot = 0.004
    U = lambda j: 0.004 + 0.992 * j / N
    for k in range(len(RG) - 1):
        for j in range(N):
            j2 = (j + 1) % N
            f = bm.faces.new((grid[k][j], grid[k][j2], grid[k + 1][j2], grid[k + 1][j]))
            for l, (uu, vv) in zip(f.loops, ((U(j), vr[k]), (U(j + 1), vr[k]), (U(j + 1), vr[k + 1]), (U(j), vr[k + 1]))):
                l[uvl].uv = (uu, vv)
    for j in range(N):
        j2 = (j + 1) % N
        f = bm.faces.new((grid[0][j2], grid[0][j], bot))
        for l, (uu, vv) in zip(f.loops, ((U(j + 1), vr[0]), (U(j), vr[0]), (U(j + 0.5), v_bot))):
            l[uvl].uv = (uu, vv)
        k = len(RG) - 1
        f = bm.faces.new((grid[k][j], grid[k][j2], top))
        for l, (uu, vv) in zip(f.loops, ((U(j), vr[k]), (U(j + 1), vr[k]), (U(j + 0.5), vr[-1]))):
            l[uvl].uv = (uu, vv)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def mesh_obj(name, bm, mat=None):
    me = bpy.data.meshes.new(name); bm.to_mesh(me)
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    return o


def shade(o, ang=60):
    me = o.data
    for p in me.polygons:
        p.use_smooth = True
    try:
        me.set_sharp_from_angle(angle=math.radians(ang))
    except Exception as e:
        print("set_sharp_from_angle failed", e)


def world_bvh(o):
    bm = bmesh.new(); bm.from_mesh(o.data); bm.transform(o.matrix_world)
    t = BVHTree.FromBMesh(bm); bm.free(); return t


def empty(name, loc, parent=None, rot=None):
    e = bpy.data.objects.new(name, None); e.empty_display_size = 0.2
    bpy.context.scene.collection.objects.link(e)
    e.location = Vector(loc)
    if rot:
        e.rotation_euler = rot
    if parent is not None:
        e.parent = parent
        e.matrix_parent_inverse = parent.matrix_world.inverted()
    return e


def build(an):
    bpy.ops.wm.open_mainfile(filepath=ROOT + f"Assets/blender/character/AST-053_Animal_{an}.blend" if False else HD + f"/orig/AST-053_Animal_{an}.blend")
    OB = bpy.data.objects
    for im in bpy.data.images:     # paths were relative to Assets/blender/character
        if im.filepath.startswith("//"):
            im.filepath = os.path.normpath(os.path.join(ROOT + "Assets/blender/character", im.filepath[2:]))
            im.reload()
            print("IMG", im.name, im.filepath, os.path.exists(im.filepath))
    old = OB["Head_" + an]
    old_mats = list(old.data.materials)
    for ch in list(old.children):
        bpy.data.objects.remove(ch, do_unlink=True)
    bpy.data.objects.remove(old, do_unlink=True)
    # ---------------- head
    bm = build_head(an)
    head = mesh_obj("Head_" + an, bm)
    bm.free()
    head.data.transform(Matrix.Translation((0, 0, -4.0))); head.location = (0, 0, 4.0)
    shade(head)
    bpy.context.view_layer.update()
    tree = world_bvh(head)

    def surf_y(x, z):
        h = tree.ray_cast(Vector((x, 5, z)), Vector((0, -1, 0)))
        return h[0].y if h[0] else None
    # ---------------- face shell (front region, offset along vertex normals, frontal UV)
    bmh = bmesh.new(); bmh.from_mesh(head.data); bmh.transform(head.matrix_world)
    bmh.normal_update()
    # front-only shell: flat face normal . front >= FACE_MIN_DOT (never the curved sides), below the cap
    sel = [f for f in bmh.faces if f.normal.y >= FACE_MIN_DOT and f.calc_center_median().z < CAP_UNDER - 0.04 and f.calc_center_median().y > 0.3 and all(abs(v.co.x) <= FACE_MAX_X for v in f.verts)]
    bs = bmesh.new(); uvs = bs.loops.layers.uv.new("UVMap")
    vm = {}
    vn = {}
    for f in sel:
        vs = []
        for v in f.verts:
            if v.index not in vm:
                vm[v.index] = bs.verts.new(v.co + v.normal * SHELL_OFF)
                vn[vm[v.index]] = v.normal.copy()
            vs.append(vm[v.index])
        nf = bs.faces.new(vs)
        for l, v in zip(nf.loops, f.verts):
            u, vt = face_uv(v.co.x, v.co.z)
            l[uvs].uv = (u, 1 - vt)
    bmh.free()
    bs.verts.index_update()
    normals = [None] * len(bs.verts)
    for bv, nn in vn.items():
        normals[bv.index] = nn
    face = mesh_obj("Face_" + an, bs); bs.free()
    face.data.transform(Matrix.Translation((0, 0, -4.0))); face.location = (0, 0, 4.0)
    shade(face, 80)
    # same normals as the head underneath: no shading seam at the shell border
    face.data.normals_split_custom_set_from_vertices(normals)
    # ---------------- attachments
    mn = Vector([min((head.matrix_world @ v.co)[i] for v in head.data.vertices) for i in range(3)])
    mx = Vector([max((head.matrix_world @ v.co)[i] for v in head.data.vertices) for i in range(3)])
    hc = (mn + mx) / 2
    yff = surf_y(0, hc.z)
    ysn = surf_y(0, NOSE_Z)
    att = {"HatAttachment": (0, 0, TOP_Z), "HairAttachment": (0, 0, TOP_Z),
           "FaceFrontAttachment": (0, yff, hc.z), "FaceCenterAttachment": (0, 0, hc.z),
           "EarLeftAttachment": (-0.94, 0, 5.64 + CAP_DZ), "EarRightAttachment": (0.94, 0, 5.64 + CAP_DZ),
           "SnoutAttachment": (0, ysn, NOSE_Z)}
    rot = {"EarLeftAttachment": (0, math.radians(-30), 0), "EarRightAttachment": (0, math.radians(30), 0)}
    for k, p in att.items():
        empty(k, p, head, rot.get(k))
    face.location = att["FaceFrontAttachment"]
    face.data.transform(Matrix.Translation(Vector((0, 0, 4.0)) - Vector(att["FaceFrontAttachment"])))
    empty(f"Face_{an}_FaceFrontAttachment", att["FaceFrontAttachment"], face)
    # ---------------- per-animal accessory adjustments
    notes = {}
    # the cap rides CAP_DZ higher (HatAttachment); ear sockets + ears follow
    for nm in ("REF_Cap",) + tuple(n for n in OB.keys() if n.startswith("Ears_")):
        if nm in OB and OB[nm].parent is None:
            OB[nm].location.z += CAP_DZ
    bpy.context.view_layer.update()
    if an == "Dog" and "Ears_Dog" in OB:
        ears = OB["Ears_Dog"]
        # head half-width where the ears hang vs the old box head (1.15)
        hw = max(abs((head.matrix_world @ v.co).x) for v in head.data.vertices if 4.55 <= (head.matrix_world @ v.co).z <= 5.27)
        d = round(hw - 1.15 - 0.03, 3)
        mw = ears.matrix_world
        inv = mw.inverted()
        for v in ears.data.vertices:
            w = mw @ v.co
            w.x += math.copysign(d, w.x)
            v.co = inv @ w
        notes["Ears_Dog_shift_x"] = d
    if an == "Owl" and "Beak_Owl" in OB:
        bk = OB["Beak_Owl"]
        bmin = min((bk.matrix_world @ v.co).y for v in bk.data.vertices)
        tgt = surf_y(0, NOSE_Z + 0.04) - 0.04
        dy = tgt - bmin
        dz = NOSE_Z - D_NOSE_Z
        bk.data.transform(Matrix.Translation((0, dy, dz)))
        bpy.context.view_layer.update()
        ch = [c for c in bk.children]
        for c in ch:
            c.matrix_world = Matrix.Translation(att["SnoutAttachment"])
        # beak origin onto the snout attachment
        mw = bk.matrix_world.copy()
        piv = Vector(att["SnoutAttachment"])
        bk.data.transform(Matrix.Translation(mw.translation - piv))
        bk.matrix_world = Matrix.Translation(piv)
        for c in ch:
            c.matrix_world = Matrix.Translation(piv)
        notes["Beak_Owl_shift_yz"] = [round(dy, 3), round(dz, 3)]
    # ---------------- layout for painting the head sheet (texel -> 3D)
    me = head.data; me.calc_loop_triangles()
    uvd = me.uv_layers["UVMap"].data
    S = 512
    tris = []
    mwh = head.matrix_world
    nrm = [v.normal.copy() for v in me.vertices]
    for lt in me.loop_triangles:
        tris.append({"uv": [[uvd[li].uv.x * S, (1 - uvd[li].uv.y) * S] for li in lt.loops],
                     "p": [list(mwh @ me.vertices[vi].co) for vi in lt.vertices],
                     "n": [list(nrm[vi]) for vi in lt.vertices], "i": lt.polygon_index})
    me.calc_loop_triangles()
    fd = face.data; fd.calc_loop_triangles(); fuv = fd.uv_layers["UVMap"].data; mwf = face.matrix_world
    ftris = [{"uv": [[fuv[li].uv.x * S, (1 - fuv[li].uv.y) * S] for li in lt.loops],
              "p": [list(mwf @ fd.vertices[vi].co) for vi in lt.vertices], "n": [list(fd.vertices[vi].normal) for vi in lt.vertices],
              "i": lt.polygon_index} for lt in fd.loop_triangles]
    json.dump({"size": S, "tris": ftris}, open(HD + f"/facelayout_{an}.json", "w"))
    info = {"head_tris": len(me.loop_triangles), "face_tris": len(face.data.loop_triangles),
            "bbox_min": list(mn), "bbox_max": list(mx), "center": list(hc), "att": att, "notes": notes,
            "face_bbox": [[min((face.matrix_world @ v.co)[i] for v in face.data.vertices) for i in range(3)],
                          [max((face.matrix_world @ v.co)[i] for v in face.data.vertices) for i in range(3)]]}
    json.dump({"size": S, "tris": tris}, open(HD + f"/layout_{an}.json", "w"))
    json.dump(info, open(HD + f"/ginfo_{an}.json", "w"), indent=1)
    print("GEOM", an, json.dumps({k: info[k] for k in ("head_tris", "face_tris", "notes")}),
          "size", [round(mx[i] - mn[i], 3) for i in range(3)], "center", [round(c, 3) for c in hc], flush=True)
    bpy.ops.file.make_paths_absolute()
    bpy.ops.wm.save_as_mainfile(filepath=HD + f"/work_{an}.blend")


for an in (ONLY or ORDER):
    build(an)
print("GEOM DONE")
