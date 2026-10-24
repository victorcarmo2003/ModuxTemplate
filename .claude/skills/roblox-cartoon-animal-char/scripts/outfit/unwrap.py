# AST-053 CrewTex step 1: clean UV unwrap of the CrewBase parts into two 512 sheets (geometry untouched).
#   Sheet "outfit": Torso, arms, legs, Cap, Apron (+ HRP collapsed)   -> T_Crew_Uniform_*, T_Civil_*
#   Sheet "face"  : Head                                               -> T_Face_*
# Writes Assets/blender/character/AST-053_CrewTex.blend (UV only; materials set in build.py) and
# scratchpad/crewtex/layout.json (islands + triangles in pixel space with world positions) for the painter.
import os as _os
WORK = _os.environ.get("CHAR_WORK", _os.getcwd()).replace("\\", "/")
PROJECT = _os.environ.get("CHAR_PROJECT", "").replace("\\", "/").rstrip("/") + "/"
import sys, math, json
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from charlib import *

SIZE = 512
PAD = 4
bpy.ops.wm.open_mainfile(filepath=ROOT + "Assets/blender/character/AST-053_CrewBase.blend")
OB = bpy.data.objects


def W(o):
    return [o.matrix_world @ v.co for v in o.data.vertices]


def components(me):
    """connected vertex components -> list of sorted vertex index lists"""
    par = list(range(len(me.vertices)))
    def f(a):
        while par[a] != a:
            par[a] = par[par[a]]; a = par[a]
        return a
    for e in me.edges:
        a, b = f(e.vertices[0]), f(e.vertices[1])
        if a != b:
            par[a] = b
    g = {}
    for i in range(len(me.vertices)):
        g.setdefault(f(i), []).append(i)
    return sorted(g.values(), key=len, reverse=True)


def rr_param(dx, dy, a, b, r):
    """perimeter position on a rounded rect (inner half extents a,b, radius r). 0 = start of back-right
    corner, increasing: right side -> front -> left side -> back."""
    hp = math.pi / 2
    if dx > a and dy < -b:
        ang = math.atan2(dy + b, dx - a)            # -90..0
        return r * (ang + hp)
    if dx > a and dy <= b:
        return r * hp + (dy + b)
    if dx > a:
        return r * hp + 2 * b + r * math.atan2(dy - b, dx - a)
    if dy > b and dx >= -a:
        return r * math.pi + 2 * b + (a - dx)
    if dy > b:
        return r * math.pi + 2 * b + 2 * a + r * (math.atan2(dy - b, dx + a) - hp)
    if dx < -a and dy >= -b:
        return 1.5 * math.pi * r + 2 * b + 2 * a + (b - dy)
    if dx < -a:
        ang = math.atan2(dy + b, dx + a)            # -180..-90
        return 1.5 * math.pi * r + 4 * b + 2 * a + r * (ang + 2 * math.pi - math.pi)
    if dy < -b:
        return 2 * math.pi * r + 4 * b + 2 * a + (dx + a)
    # inside the inner rect (degenerate): use angle
    return (math.atan2(dy, dx) + hp) % (2 * math.pi) / (2 * math.pi) * (4 * a + 4 * b + 2 * math.pi * r)


def unwrap_faces_periodic(faces_loops, P):
    """faces_loops: {poly: [u per loop]} -> make each face continuous across the seam."""
    for p, us in faces_loops.items():
        if max(us) - min(us) > P / 2:
            faces_loops[p] = [u + P if u < P / 2 else u for u in us]
    return faces_loops


ISL = []          # islands: dict(obj, sheet, name, weight, loops{poly: [(x,y)...]})


def add(obj, sheet, name, weight, loops):
    # orientation: total signed UV area must be positive (CCW, same as the face winding) -> else mirror u
    area = 0
    for p, uvs in loops.items():
        for i in range(len(uvs)):
            x0, y0 = uvs[i]; x1, y1 = uvs[(i + 1) % len(uvs)]
            area += x0 * y1 - x1 * y0
    if area < 0:
        loops = {p: [(-x, y) for x, y in uvs] for p, uvs in loops.items()}
    ISL.append(dict(obj=obj.name, sheet=sheet, name=name, weight=weight, loops=loops))


def lathe_unwrap(o, vidx, n, sheet, pref, w_side, w_top, w_bot, faces=None):
    me = o.data
    Vw = W(o)
    vidx = sorted(vidx)
    nr = len(vidx) // n
    assert nr * n == len(vidx), (o.name, len(vidx), n)
    ring_of, pos_in = {}, {}
    rings = []
    for k in range(nr):
        ids = vidx[k * n:(k + 1) * n]
        zs = [Vw[i].z for i in ids]
        assert max(zs) - min(zs) < 1e-4, (o.name, k, zs)
        xs = [Vw[i].x for i in ids]; ys = [Vw[i].y for i in ids]
        cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
        hx, hy = (max(xs) - min(xs)) / 2, (max(ys) - min(ys)) / 2
        a = max(abs(Vw[i].x - cx) for i in ids if abs(abs(Vw[i].y - cy) - hy) < 1e-5)
        r = hx - a; b = hy - r
        P = 4 * a + 4 * b + 2 * math.pi * r
        rings.append(dict(z=zs[0], cx=cx, cy=cy, a=a, b=b, r=r, P=P, hy=hy))
        for i in ids:
            ring_of[i] = k
    Pref = max(rg["P"] for rg in rings)
    vk = [0.0]
    for k in range(1, nr):
        d = math.hypot(rings[k]["z"] - rings[k - 1]["z"], rings[k]["hy"] - rings[k - 1]["hy"])
        vk.append(vk[-1] - d)
    side, top, bot = {}, {}, {}
    polys = faces if faces is not None else [p.index for p in me.polygons]
    for pi in polys:
        p = me.polygons[pi]
        ks = {ring_of[v] for v in p.vertices}
        if len(ks) == 1 and len(p.vertices) == n:
            k = ks.pop()
            if k == 0:
                top[pi] = [(Vw[me.loops[l].vertex_index].x, Vw[me.loops[l].vertex_index].y) for l in p.loop_indices]
            else:
                bot[pi] = [(Vw[me.loops[l].vertex_index].x, -Vw[me.loops[l].vertex_index].y) for l in p.loop_indices]
            continue
        us = []
        for l in p.loop_indices:
            vi = me.loops[l].vertex_index; rg = rings[ring_of[vi]]
            us.append(rr_param(Vw[vi].x - rg["cx"], Vw[vi].y - rg["cy"], rg["a"], rg["b"], rg["r"]) / rg["P"] * Pref)
        side[pi] = us
    unwrap_faces_periodic(side, Pref)
    side_l = {pi: [(u, vk[ring_of[me.loops[l].vertex_index]]) for u, l in zip(us, me.polygons[pi].loop_indices)]
              for pi, us in side.items()}
    add(o, sheet, pref + "_side", w_side, side_l)
    if top:
        add(o, sheet, pref + "_top", w_top, top)
    if bot:
        add(o, sheet, pref + "_bottom", w_bot, bot)


def band_unwrap(o, polys, sheet, name, weight):
    """closed or open band of quads (each shares <=2 edges with band neighbours) -> straight strip."""
    me = o.data
    Vw = W(o)
    pset = set(polys)
    ek = lambda a, b: (min(a, b), max(a, b))
    edge_faces = {}
    for pi in polys:
        vs = me.polygons[pi].vertices
        for i in range(4):
            edge_faces.setdefault(ek(vs[i], vs[(i + 1) % 4]), []).append(pi)
    rungs = {pi: [e for e in (ek(me.polygons[pi].vertices[i], me.polygons[pi].vertices[(i + 1) % 4]) for i in range(4))
                  if len(edge_faces[e]) == 2] for pi in polys}
    # start: a face with one rung (open band) or any face
    start = next((pi for pi in polys if len(rungs[pi]) == 1), polys[0])
    vs = list(me.polygons[start].vertices)
    # orient the first rung
    if rungs[start]:
        if len(rungs[start]) == 2:
            first = rungs[start][0]
        else:   # open band: the start rung is the edge opposite the only shared rung
            sh = rungs[start][0]
            first = next(ek(vs[i], vs[(i + 1) % 4]) for i in range(4)
                         if not (set(ek(vs[i], vs[(i + 1) % 4])) & set(sh)))
    vpos = {first[0]: (0.0, 0.0), first[1]: (0.0, (Vw[first[0]] - Vw[first[1]]).length)}
    U = 0.0
    out = {}
    cur, cur_rung = start, first
    seen = set()
    while cur is not None and cur not in seen:
        seen.add(cur)
        fv = list(me.polygons[cur].vertices)
        a, b = cur_rung
        # the other two verts: rail neighbours of a and b
        def rail_nb(x, other):
            i = fv.index(x)
            for j in ((i + 1) % 4, (i - 1) % 4):
                if fv[j] != other:
                    return fv[j]
        a2, b2 = rail_nb(a, b), rail_nb(b, a)
        L = ((Vw[a2] - Vw[a]).length + (Vw[b2] - Vw[b]).length) / 2
        ua = vpos[a][0]
        vpos[a2] = (ua + L, vpos[a][1]); vpos[b2] = (ua + L, vpos[b][1])
        loc = {a: vpos[a], b: vpos[b], a2: vpos[a2], b2: vpos[b2]}
        out[cur] = [loc[me.loops[l].vertex_index] for l in me.polygons[cur].loop_indices]
        nxt_rung = ek(a2, b2)
        nb = [f for f in edge_faces.get(nxt_rung, []) if f != cur and f in pset]
        cur_rung = (a2, b2)
        cur = nb[0] if nb else None
        # vertices are shared: the next face sees a2,b2 at u = ua+L (vpos already set)
    assert len(seen) == len(polys), (o.name, name, len(seen), len(polys))
    add(o, sheet, name, weight, out)


def planar(o, polys, sheet, name, weight, axes):
    """axes: function(world Vector) -> (x, y)"""
    me = o.data; Vw = W(o)
    add(o, sheet, name, weight, {pi: [axes(Vw[me.loops[l].vertex_index]) for l in me.polygons[pi].loop_indices] for pi in polys})


def per_face(o, polys, sheet, name, weight):
    me = o.data; Vw = W(o)
    for k, pi in enumerate(polys):
        p = me.polygons[pi]
        n = (o.matrix_world.to_3x3() @ p.normal).normalized()
        t = Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))
        t = (t - n * t.dot(n)).normalized()
        bb = n.cross(t)
        # u along t, v along bb ; t x bb = -n... use (bb, t) so that bb x t = n
        add(o, sheet, f"{name}{k}", weight, {pi: [(Vw[me.loops[l].vertex_index].dot(bb), Vw[me.loops[l].vertex_index].dot(t))
                                                for l in p.loop_indices]})


# ---------------- outfit sheet
lathe_unwrap(OB["Torso"], range(40), 8, "outfit", "Torso", 1.0, 0.45, 0.45)
for nm in ("Right Arm", "Left Arm"):
    lathe_unwrap(OB[nm], range(56), 8, "outfit", nm.replace(" ", ""), 1.0, 0.7, 0.7)
for nm in ("Right Leg", "Left Leg"):
    lathe_unwrap(OB[nm], range(48), 8, "outfit", nm.replace(" ", ""), 1.0, 0.35, 0.6)

# Cap: components crown (16/ring), brim, button
cap = OB["Cap"]; cme = cap.data; cW = W(cap)
comps = components(cme)
vcomp = {}
for ci, c in enumerate(comps):
    for v in c:
        vcomp[v] = ci
def comp_polys(me, ci, vc):
    return [p.index for p in me.polygons if vc[p.vertices[0]] == ci]
crown_ci = 0
others = sorted(range(1, len(comps)), key=lambda ci: max(cW[v].y for v in comps[ci]), reverse=True)
brim_ci, btn_ci = others[0], others[1]
print("cap comps", [len(c) for c in comps], "brim", brim_ci, "btn", btn_ci)
lathe_unwrap(cap, comps[crown_ci], 16, "outfit", "CapCrown", 1.0, 1.0, 0.35, faces=comp_polys(cme, crown_ci, vcomp))
bp = comp_polys(cme, brim_ci, vcomp)
mw3 = cap.matrix_world.to_3x3()
nrm = {pi: (mw3 @ cme.polygons[pi].normal).normalized() for pi in bp}
planar(cap, [pi for pi in bp if nrm[pi].z > 0.6], "outfit", "CapBrim_top", 1.0, lambda v: (v.x, v.y))
planar(cap, [pi for pi in bp if nrm[pi].z < -0.6], "outfit", "CapBrim_bottom", 0.7, lambda v: (v.x, -v.y))
band_unwrap(cap, [pi for pi in bp if abs(nrm[pi].z) <= 0.6], "outfit", "CapBrim_edge", 1.0)
btp = comp_polys(cme, btn_ci, vcomp)
bn = {pi: (mw3 @ cme.polygons[pi].normal).normalized() for pi in btp}
planar(cap, [pi for pi in btp if bn[pi].z > 0.6], "outfit", "CapButton_top", 1.0, lambda v: (v.x, v.y))
band_unwrap(cap, [pi for pi in btp if abs(bn[pi].z) <= 0.6], "outfit", "CapButton_side", 1.0)
bott = [pi for pi in btp if bn[pi].z < -0.6]
if bott:
    planar(cap, bott, "outfit", "CapButton_bottom", 0.5, lambda v: (v.x, -v.y))

# Apron: panel (largest comp) + 4 strap boxes
ap = OB["Apron"]; ame = ap.data; aW = W(ap)
acomps = components(ame)
avc = {}
for ci, c in enumerate(acomps):
    for v in c:
        avc[v] = ci
pp = comp_polys(ame, 0, avc)
an = {pi: (ap.matrix_world.to_3x3() @ ame.polygons[pi].normal).normalized() for pi in pp}
planar(ap, [pi for pi in pp if an[pi].y > 0.3], "outfit", "Apron_front", 1.7, lambda v: (-v.x, v.z))
planar(ap, [pi for pi in pp if an[pi].y < -0.3], "outfit", "Apron_back", 0.6, lambda v: (v.x, v.z))
band_unwrap(ap, [pi for pi in pp if abs(an[pi].y) <= 0.3], "outfit", "Apron_edge", 1.0)
for ci in range(1, len(acomps)):
    per_face(ap, comp_polys(ame, ci, avc), "outfit", f"Apron_strap{ci}_", 1.0)

# ---------------- face sheet: head side split front/back, top, bottom
hd = OB["Head"]; hme = hd.data; hW = W(hd)
HW, HD, HH, R = 2.30, 1.90, 1.75, 0.42
HC = 4.825
A_, B_ = HW / 2 - R, HD / 2 - R
ZLO, ZHI = HC - HH / 2 + R, HC + HH / 2 - R
PH = 4 * A_ + 4 * B_ + 2 * math.pi * R
U_RS = R * math.pi / 2 + B_                       # right side centre
U_LS = 1.5 * math.pi * R + 3 * B_ + 2 * A_        # left side centre
hn = {p.index: (hd.matrix_world.to_3x3() @ p.normal).normalized() for p in hme.polygons}
side_us, top, bot = {}, [], []
for p in hme.polygons:
    if hn[p.index].z >= 0.75:
        top.append(p.index); continue
    if hn[p.index].z <= -0.75:
        bot.append(p.index); continue
    side_us[p.index] = [rr_param(hW[hme.loops[l].vertex_index].x, hW[hme.loops[l].vertex_index].y, A_, B_, R)
                        for l in p.loop_indices]
unwrap_faces_periodic(side_us, PH)


def head_v(v):
    q = Vector((max(-A_, min(A_, v.x)), max(-B_, min(B_, v.y))))
    h = (Vector((v.x, v.y)) - q).length
    zc = max(ZLO, min(ZHI, v.z))
    dz = v.z - zc
    return zc + R * math.atan2(dz, h) if abs(dz) > 1e-9 else v.z


front, back = {}, {}
for pi, us in side_us.items():
    c = sum(us) / len(us)
    vs = [head_v(hW[hme.loops[l].vertex_index]) for l in hme.polygons[pi].loop_indices]
    if U_RS + 0.05 < c < U_LS - 0.05:
        front[pi] = list(zip(us, vs))
    else:
        if c < PH / 2:
            us = [u + PH for u in us]
        back[pi] = list(zip(us, vs))
add(hd, "face", "Head_front", 1.0, front)
add(hd, "face", "Head_back", 0.8, back)
planar(hd, top, "face", "Head_top", 0.75, lambda v: (v.x, v.y))
planar(hd, bot, "face", "Head_bottom", 0.3, lambda v: (v.x, -v.y))


# ---------------- pack (shelf, max density)
def maxrects(sizes):
    """MaxRects best-short-side-fit with 90deg rotation. sizes: [(w,h)] -> [(x,y,rot)] or None"""
    free = [(0, 0, SIZE, SIZE)]
    res = [None] * len(sizes)
    order = sorted(range(len(sizes)), key=lambda i: -max(sizes[i]) * 10000 - min(sizes[i]))
    for i in order:
        w, h = sizes[i]
        best = None
        for fx, fy, fw, fh in free:
            for rot, (ww, hh) in ((0, (w, h)), (1, (h, w))):
                if ww <= fw and hh <= fh:
                    sc = (min(fw - ww, fh - hh), max(fw - ww, fh - hh))
                    if best is None or sc < best[0]:
                        best = (sc, fx, fy, ww, hh, rot)
        if best is None:
            return None
        _, x, y, ww, hh, rot = best
        res[i] = (x, y, rot)
        nf = []
        for fx, fy, fw, fh in free:
            if x >= fx + fw or x + ww <= fx or y >= fy + fh or y + hh <= fy:
                nf.append((fx, fy, fw, fh)); continue
            if x > fx: nf.append((fx, fy, x - fx, fh))
            if x + ww < fx + fw: nf.append((x + ww, fy, fx + fw - x - ww, fh))
            if y > fy: nf.append((fx, fy, fw, y - fy))
            if y + hh < fy + fh: nf.append((fx, y + hh, fw, fy + fh - y - hh))
        free = [a for a in nf if not any(a != b and b[0] <= a[0] and b[1] <= a[1] and a[0] + a[2] <= b[0] + b[2]
                                         and a[1] + a[3] <= b[1] + b[3] for b in nf)]
        free = list(dict.fromkeys(free))
    return res


def pack(isls, D):
    sizes = []
    for isl in isls:
        xs = [x for uvs in isl["loops"].values() for x, _ in uvs]; ys = [y for uvs in isl["loops"].values() for _, y in uvs]
        isl["bb"] = (min(xs), min(ys), max(xs), max(ys))
        s = D * isl["weight"]
        sizes.append((math.ceil((max(xs) - min(xs)) * s) + 2 * PAD, math.ceil((max(ys) - min(ys)) * s) + 2 * PAD))
    r = maxrects(sizes)
    if r is None:
        return None
    return [(isl, x, y, w, h, rot) for isl, (w, h), (x, y, rot) in zip(isls, sizes, r)]


LAYOUT = {}
for sheet in ("outfit", "face"):
    isls = [i for i in ISL if i["sheet"] == sheet]
    lo, hi = 5.0, 400.0
    for _ in range(40):
        mid = (lo + hi) / 2
        if pack(isls, mid):
            lo = mid
        else:
            hi = mid
    D = math.floor(lo * 10) / 10
    placed = pack(isls, D)
    LAYOUT[sheet] = dict(D=D, placed=placed)
    print("SHEET", sheet, "D px/stud", D, "islands", len(placed))

# ---------------- write UVs
for o in [OB[n] for n in ("Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "Cap", "Apron", "HumanoidRootPart")]:
    me = o.data
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    me.uv_layers.new(name="UVMap")
    for l in me.uv_layers[0].data:
        l.uv = (2 / SIZE, 2 / SIZE)       # HRP / anything unassigned -> corner (invisible part)

isl_meta = []
tri_out = {"outfit": [], "face": []}
for sheet, L in LAYOUT.items():
    D = L["D"]
    for isl, x0, y0, w, h, rot in L["placed"]:
        o = OB[isl["obj"]]; me = o.data; uvl = me.uv_layers[0].data
        s = D * isl["weight"]
        mnx, mny, mxx, mxy = isl["bb"]
        iid = len(isl_meta)
        isl_meta.append(dict(id=iid, sheet=sheet, obj=isl["obj"], name=isl["name"], px_per_stud=round(s, 2),
                             rect=[x0, y0, h, w] if rot else [x0, y0, w, h], rot=rot))
        for pi, uvs in isl["loops"].items():
            for l, (lx, ly) in zip(me.polygons[pi].loop_indices, uvs):
                if rot:      # rotate 90 deg (keeps winding)
                    px = x0 + PAD + (ly - mny) * s
                    py = y0 + PAD + (lx - mnx) * s
                else:
                    px = x0 + PAD + (lx - mnx) * s
                    py = y0 + PAD + (mxy - ly) * s
                uvl[l].uv = (px / SIZE, 1 - py / SIZE)
        isl["id"] = iid
# triangles for the rasterizer
face_isl = {}
for isl in ISL:
    for pi in isl["loops"]:
        face_isl[(isl["obj"], pi)] = isl["id"]
for o in [OB[n] for n in ("Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "Cap", "Apron")]:
    me = o.data; me.calc_loop_triangles(); uvl = me.uv_layers[0].data; mw = o.matrix_world
    for lt in me.loop_triangles:
        iid = face_isl[(o.name, lt.polygon_index)]
        sheet = isl_meta[iid]["sheet"]
        n = (mw.to_3x3() @ me.polygons[lt.polygon_index].normal).normalized()
        tri_out[sheet].append(dict(i=iid, uv=[[round(uvl[l].uv[0] * SIZE, 4), round((1 - uvl[l].uv[1]) * SIZE, 4)] for l in lt.loops],
                                   p=[[round(c, 5) for c in (mw @ me.vertices[me.loops[l].vertex_index].co)] for l in lt.loops],
                                   n=[round(c, 4) for c in n]))
json.dump(dict(size=SIZE, pad=PAD, D={k: v["D"] for k, v in LAYOUT.items()}, islands=isl_meta, tris=tri_out),
          open(WORK + "/crewtex/layout.json", "w"))
# overlap sanity: rasterize nothing here, just check rect overlap
for sheet in LAYOUT:
    R_ = [m["rect"] for m in isl_meta if m["sheet"] == sheet]
    bad = 0
    for i in range(len(R_)):
        for j in range(i + 1, len(R_)):
            a, b = R_[i], R_[j]
            if a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]:
                bad += 1
    print("RECT OVERLAPS", sheet, bad)
for m in isl_meta:
    print("ISL", m["sheet"], m["name"], m["px_per_stud"], m["rect"])
bpy.ops.wm.save_as_mainfile(filepath=ROOT + "Assets/blender/character/AST-053_CrewTex.blend")
print("UNWRAP DONE")
