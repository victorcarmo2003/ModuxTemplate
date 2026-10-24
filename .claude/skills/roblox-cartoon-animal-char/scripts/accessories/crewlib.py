# Helpers for AST-053 animal pieces (HotDog Crew). Headless Blender 5.2. 1 unit = 1 stud, Blender +Y = front, Z up.
import sys, os, json, math
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from charlib import *
from mathutils.bvhtree import BVHTree

BASE = ROOT + "Assets/blender/character/AST-053_CrewBase.blend"
CAPUP_BLEND = ROOT + "Assets/blender/character/AST-053_CrewCap_EarsUp.blend"
OUTDIR = SP + "/crew/animals"

# head of the base body (same numbers as crew_base.py)
HW, HD, HH = 2.30, 1.90, 1.75
HZ0 = 3.95
HC = HZ0 + HH / 2          # 4.825
TOPZ = HC + HH / 2         # 5.70
FRONT = HD / 2             # 0.95
SOCK_X, SOCK_Z, TILT = 0.94, 5.64, 30.0
# standard ear hole of Cap_EarsUp, in the ear frame (x outward along the tilt, y front, z along the ear axis)
HOLE_HX, HOLE_HY, HOLE_Z0, HOLE_Z1 = 0.31, 0.20, -0.45, 0.75

# KitchenPack atlas bands (row, col, frac_top, frac_bottom)
RED = (2, 6, 0.30, 0.62)
RED_DK = (2, 6, 0.55, 0.80)
FUR_BASE = (1, 5, 0.10, 0.62)

MAT = None


def get_mat():
    global MAT
    if MAT is None or MAT.name not in bpy.data.materials:
        MAT = bpy.data.materials.get("M_RestaurantBits")
        if MAT is None:
            img = bpy.data.images.load(ROOT + "Assets/KitchenPack/Assets/gltf/restaurantbits_texture.png")
            MAT = bpy.data.materials.new("M_RestaurantBits"); MAT.use_nodes = True
            nt = MAT.node_tree
            bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
            ti = nt.nodes.new("ShaderNodeTexImage"); ti.image = img; ti.interpolation = "Closest"
            nt.links.new(ti.outputs["Color"], bsdf.inputs["Base Color"])
            bsdf.inputs["Roughness"].default_value = 0.7
    return MAT


def V(*a):
    return Vector(a[0] if len(a) == 1 else a)


# ---------------------------------------------------------------- bmesh shapes
def bm_box(size, M=None, r=0.0, seg=1):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    if r > 0:
        bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=r, segments=seg, affect="EDGES", profile=0.5)
    if M is not None:
        bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    return bm


def bm_cyl(rx, rz, depth, seg, M):
    """Elliptic prism, axis along local Y (front), centred at the origin, then M."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=1.0, radius2=1.0, depth=depth)
    bmesh.ops.scale(bm, vec=Vector((rx, rz, 1)), verts=bm.verts)
    bmesh.ops.transform(bm, matrix=Matrix.Rotation(math.radians(-90), 4, "X"), verts=bm.verts)
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    return bm


def bm_sphere(r, center, u=8, v=5, scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=r)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)
    return bm


def bm_ico(r, center, sub=2, scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)
    return bm


def bm_loft(rings, cap0=True, cap1=True):
    """rings: list of point lists (same length) or single Vector (tip). Face int layer 'seg' = segment index
    (-1 first cap, -2 last cap)."""
    bm = bmesh.new()
    lay = bm.faces.layers.int.new("seg")
    R = []
    for ring in rings:
        if isinstance(ring, Vector):
            R.append([bm.verts.new(ring)])
        else:
            R.append([bm.verts.new(p) for p in ring])
    for k in range(len(R) - 1):
        a, b = R[k], R[k + 1]
        if len(a) == 1:
            n = len(b)
            for i in range(n):
                bm.faces.new((a[0], b[i], b[(i + 1) % n]))[lay] = k
        elif len(b) == 1:
            n = len(a)
            for i in range(n):
                bm.faces.new((a[i], a[(i + 1) % n], b[0]))[lay] = k
        else:
            n = len(a)
            for i in range(n):
                bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))[lay] = k
    if cap0 and len(R[0]) > 1:
        bm.faces.new(R[0])[lay] = -1
    if cap1 and len(R[-1]) > 1:
        bm.faces.new(R[-1])[lay] = -2
    return bm


def ring_ellipse(c, ax, ay, rx, ry, n, phase=0.5):
    c, ax, ay = Vector(c), Vector(ax).normalized(), Vector(ay).normalized()
    return [c + ax * (rx * math.cos(2 * math.pi * (i + phase) / n)) + ay * (ry * math.sin(2 * math.pi * (i + phase) / n))
            for i in range(n)]


def ring_rrect(c, ax, ay, hx, hy, r, seg=1):
    c, ax, ay = Vector(c), Vector(ax).normalized(), Vector(ay).normalized()
    r = min(r, hx * 0.95, hy * 0.95)
    pts = []
    for sx, sy, a0 in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        cx, cy = sx * (hx - r), sy * (hy - r)
        for i in range(seg + 1):
            a = math.radians(a0 + 90 * i / seg)
            pts.append(c + ax * (cx + r * math.cos(a)) + ay * (cy + r * math.sin(a)))
    return pts


def tube(points, radii, n=6, up=(1, 0, 0), sy=None):
    """Tube along a polyline; radius 0 at the end = pointed tip. sy: optional per-ring y-squash factors."""
    P = [Vector(p) for p in points]
    rings = []
    for i, p in enumerate(P):
        t = (P[min(i + 1, len(P) - 1)] - P[max(i - 1, 0)]).normalized()
        u = Vector(up); ax = (u - t * u.dot(t)).normalized(); ay = t.cross(ax)
        r = radii[i]
        if r <= 0:
            rings.append(p)
        else:
            rings.append(ring_ellipse(p, ax, ay, r, r * (sy[i] if sy else 1.0), n))
    return bm_loft(rings)


def head_bm(cuts=()):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector((HW, HD, HH)), verts=bm.verts)
    bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=0.42, segments=3, affect="EDGES", profile=0.5)
    bmesh.ops.translate(bm, vec=Vector((0, 0, HC)), verts=bm.verts)
    for co, no in cuts:
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=Vector(co), plane_no=Vector(no))
    return bm


def ear_frame(side):
    """Matrix ear-local -> world for side +1 (right, +X) / -1 (left). Local x points outward."""
    a = math.radians(TILT)
    X = Vector((side * math.cos(a), 0, -math.sin(a)))
    Y = Vector((0, 1, 0))
    Z = Vector((side * math.sin(a), 0, math.cos(a)))
    M = Matrix.Identity(4)
    for i in range(3):
        M[i][0], M[i][1], M[i][2] = X[i], Y[i], Z[i]
    M[0][3], M[1][3], M[2][3] = side * SOCK_X, 0, SOCK_Z
    return M


def xform(bm, M):
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    return bm


def mirror_x(bm):
    bmesh.ops.scale(bm, vec=Vector((-1, 1, 1)), verts=bm.verts)
    return bm


# ---------------------------------------------------------------- objects + atlas UV
def band_uv(band, t):
    r, c, lo, hi = band
    frac = hi - t * (hi - lo)
    return ((c + 0.5) / 8, 1 - (r + frac) / 4)


def to_obj(name, bm, spec, zr=None):
    """spec: band tuple, or callable(face, bm) -> band. v follows world z inside zr (top = band top)."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    uvl = bm.loops.layers.uv.new("UVMap")
    zs = [v.co.z for v in bm.verts]
    z0, z1 = zr if zr else (min(zs), max(zs))
    for f in bm.faces:
        band = spec(f, bm) if callable(spec) else spec
        for l in f.loops:
            t = min(1, max(0, (l.vert.co.z - z0) / (z1 - z0))) if z1 > z0 + 1e-6 else 0.5
            l[uvl].uv = band_uv(band, t)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for a in [a.name for a in me.attributes if a.name == "seg"]:
        me.attributes.remove(me.attributes[a])
    me.materials.append(get_mat())
    for p in me.polygons:
        p.use_smooth = False
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    return o


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = name; o.data.name = name
    return o


# ---------------------------------------------------------------- clean paint UV (second layer)
def paint_uv(obj, region, angle=60, margin=0.012):
    """Smart-project into a new 'UVPaint' layer and pack, without rotation, into region (u0, v0, u1, v1)
    of the animal's 512x512 sheet, keeping island aspect. UVMap (atlas) stays first/active-render."""
    me = obj.data
    uvp = me.uv_layers.new(name="UVPaint")
    me.uv_layers.active = uvp
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True); bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=0.0, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    u0, v0, u1, v1 = region
    k = (u1 - u0) / (v1 - v0)
    uvp = obj.data.uv_layers["UVPaint"]
    for l in uvp.data:
        l.uv = (l.uv.x, l.uv.y * k)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=False, margin=margin)
    bpy.ops.object.mode_set(mode="OBJECT")
    me = obj.data
    uvp = me.uv_layers["UVPaint"]
    for l in uvp.data:
        l.uv = (u0 + l.uv.x * (u1 - u0), v0 + l.uv.y * (v1 - v0))
    me.uv_layers.active = me.uv_layers["UVMap"]
    me.uv_layers["UVMap"].active_render = True
    return uvp


def uv_overlap_px(objs, layer="UVPaint", res=512):
    """Count texels covered by more than one triangle (all objects together share one sheet)."""
    import array
    grid = array.array("H", bytes(2 * res * res))
    bad = 0
    for o in objs:
        me = o.data; me.calc_loop_triangles()
        uv = me.uv_layers[layer].data
        for lt in me.loop_triangles:
            p = [uv[i].uv * res for i in lt.loops]
            xs = [q.x for q in p]; ys = [q.y for q in p]
            for py in range(max(0, int(min(ys))), min(res, int(max(ys)) + 1)):
                for px in range(max(0, int(min(xs))), min(res, int(max(xs)) + 1)):
                    cx, cy = px + 0.5, py + 0.5
                    d1 = (p[1].x - p[0].x) * (cy - p[0].y) - (p[1].y - p[0].y) * (cx - p[0].x)
                    d2 = (p[2].x - p[1].x) * (cy - p[1].y) - (p[2].y - p[1].y) * (cx - p[1].x)
                    d3 = (p[0].x - p[2].x) * (cy - p[2].y) - (p[0].y - p[2].y) * (cx - p[2].x)
                    if (d1 >= 0 and d2 >= 0 and d3 >= 0) or (d1 <= 0 and d2 <= 0 and d3 <= 0):
                        g = grid[py * res + px]
                        if g:
                            bad += 1
                        grid[py * res + px] = g + 1
    used = sum(1 for g in grid if g)
    return bad, used / (res * res)


def uv_polys(objs, layer="UVPaint"):
    out = []
    for o in objs:
        me = o.data
        uv = me.uv_layers[layer].data
        for p in me.polygons:
            out.append([o.name, [[round(uv[i].uv.x, 5), round(uv[i].uv.y, 5)] for i in p.loop_indices]])
    return out


# ---------------------------------------------------------------- checks
def islands(o):
    bm = bmesh.new(); bm.from_mesh(o.data); bm.transform(o.matrix_world)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
    seen, out = set(), []
    for f in bm.faces:
        if f.index in seen:
            continue
        st, comp = [f], []
        while st:
            x = st.pop()
            if x.index in seen:
                continue
            seen.add(x.index); comp.append(x)
            for e in x.edges:
                st += [g for g in e.link_faces if g.index not in seen]
        vmap, verts, tri = {}, [], []
        for f2 in comp:
            t = []
            for v in f2.verts:
                if v.index not in vmap:
                    vmap[v.index] = len(verts); verts.append(v.co.copy())
                t.append(vmap[v.index])
            tri.append(tuple(t))
        out.append((verts, tri))
    bm.free()
    return out


def _area(va, vb, n):
    ax = (va[1] - va[0]).normalized(); ay = n.cross(ax)
    P = lambda p: ((p - va[0]).dot(ax), (p - va[0]).dot(ay))
    subj = [P(p) for p in va]; clip = [P(p) for p in vb]
    def cross(o, a, b): return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    if cross(clip[0], clip[1], clip[2]) < 0: clip = clip[::-1]
    if cross(subj[0], subj[1], subj[2]) < 0: subj = subj[::-1]
    out = subj
    for i in range(3):
        a, b = clip[i], clip[(i + 1) % 3]
        inp, out = out, []
        if not inp: break
        for j in range(len(inp)):
            p, q = inp[j], inp[(j + 1) % len(inp)]
            ip, iq = cross(a, b, p) > 1e-9, cross(a, b, q) > 1e-9
            if ip: out.append(p)
            if ip != iq:
                d1, d2 = cross(a, b, p), cross(a, b, q)
                t = d1 / (d1 - d2)
                out.append((p[0] + t * (q[0] - p[0]), p[1] + t * (q[1] - p[1])))
    if len(out) < 3: return 0.0
    return abs(sum(out[k][0] * out[(k + 1) % len(out)][1] - out[(k + 1) % len(out)][0] * out[k][1] for k in range(len(out)))) / 2


def check(objs, no_touch=()):
    """zfight = coplanar overlapping triangles between different islands (any objects).
    no_touch = list of (objA, objB, skip_islands_A) pairs that must not intersect at all."""
    parts = []
    for o in objs:
        for k, (v, t) in enumerate(islands(o)):
            parts.append((o.name, k, v, t))
    trees = [BVHTree.FromPolygons(v, t, epsilon=0.0) for _, _, v, t in parts]
    zf, inter = [], {}
    for i in range(len(parts)):
        for j in range(i + 1, len(parts)):
            ov = trees[i].overlap(trees[j])
            if not ov:
                continue
            key = (parts[i][0], parts[j][0])
            inter.setdefault(key, []).append((parts[i][1], parts[j][1], len(ov)))
            for a, b in ov:
                va = [parts[i][2][q] for q in parts[i][3][a]]
                vb = [parts[j][2][q] for q in parts[j][3][b]]
                na = (va[1] - va[0]).cross(va[2] - va[0]).normalized()
                nb = (vb[1] - vb[0]).cross(vb[2] - vb[0]).normalized()
                if abs(na.dot(nb)) > 0.999 and abs((vb[0] - va[0]).dot(na)) < 0.003 and _area(va, vb, na) > 1e-4:
                    zf.append((parts[i][0], parts[i][1], parts[j][0], parts[j][1]))
                    break
    bad = {}
    for a, b, skipA in no_touch:
        for key in ((a, b), (b, a)):
            for ia, ib, n in inter.get(key, []):
                iA = ia if key[0] == a else ib
                if iA in skipA:
                    continue
                bad.setdefault(f"{a} x {b}", 0)
                bad[f"{a} x {b}"] += n
    return zf, bad, inter
