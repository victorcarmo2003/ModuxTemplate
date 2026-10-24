# Headless Blender: for every .blend under Assets/blender, find triangles of DIFFERENT parts (objects or loose islands)
# that intersect. Coplanar hits (|n1.n2|>0.999 and same plane) = z-fight; others = interpenetration.
import os as _os
WORK = _os.environ.get("CHAR_WORK", _os.getcwd()).replace("\\", "/")
PROJECT = _os.environ.get("CHAR_PROJECT", "").replace("\\", "/").rstrip("/") + "/"
import bpy, bmesh, glob, os, sys, json
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = PROJECT + r"Assets/blender"
OUT = WORK + "/overlap_report.json"

def _area(va, vb, n):
    # overlap area of two coplanar triangles (Sutherland-Hodgman in the plane)
    ax = (va[1] - va[0]).normalized(); ay = n.cross(ax)
    P = lambda p: ((p - va[0]).dot(ax), (p - va[0]).dot(ay))
    subj = [P(p) for p in va]; clip = [P(p) for p in vb]
    def cross(o, a, b): return (a[0]-o[0])*(b[1]-o[1]) - (a[1]-o[1])*(b[0]-o[0])
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
report = {}
FILES = ["character/AST-053_CrewBase.blend"]
for path in [ROOT + "/" + f for f in FILES]:
    bpy.ops.wm.open_mainfile(filepath=path)
    parts = []  # (label, verts(list Vector world), tris(list of idx triples))
    for o in bpy.data.objects:
        if o.type != "MESH" or o.name.startswith("REF_") or o.hide_render:
            continue
        bm = bmesh.new(); bm.from_mesh(o.data); bm.transform(o.matrix_world)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
        # islands by face connectivity
        seen, isl = set(), []
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
            isl.append(comp)
        for k, comp in enumerate(isl):
            vmap, verts, tris = {}, [], []
            for f in comp:
                t = []
                for v in f.verts:
                    if v.index not in vmap:
                        vmap[v.index] = len(verts); verts.append(v.co.copy())
                    t.append(vmap[v.index])
                tris.append(tuple(t))
            parts.append((f"{o.name}#{k}", verts, tris))
        bm.free()
    trees = [BVHTree.FromPolygons(v, t, epsilon=0.0) for _, v, t in parts]
    hits = []
    for i in range(len(parts)):
        for j in range(i + 1, len(parts)):
            ov = trees[i].overlap(trees[j])
            if not ov:
                continue
            cop = 0
            for a, b in ov:
                va = [parts[i][1][q] for q in parts[i][2][a]]
                vb = [parts[j][1][q] for q in parts[j][2][b]]
                na = (va[1] - va[0]).cross(va[2] - va[0]).normalized()
                nb = (vb[1] - vb[0]).cross(vb[2] - vb[0]).normalized()
                if na.dot(nb) > 0.999 and abs((vb[0] - va[0]).dot(na)) < 0.003 and _area(va, vb, na) > 1e-4:
                    cop += 1
            c = sum(((sum(parts[i][1], Vector()) / len(parts[i][1]))[:],), ())
            hits.append({"a": parts[i][0], "b": parts[j][0], "pairs": len(ov), "coplanar": cop,
                         "at": [round(x, 2) for x in (sum(parts[j][1], Vector()) / len(parts[j][1]))]})
    rel = os.path.relpath(path, ROOT)
    report[rel] = {"parts": len(parts), "hits": hits}
    zf = sum(1 for h in hits if h["coplanar"])
    print(f"FILE {rel}: parts={len(parts)} intersecting_pairs={len(hits)} zfight_pairs={zf}")
    for h in hits:
        if h["coplanar"]:
            print("   ZF", h["a"], "x", h["b"], "tris", h["coplanar"], "at", h["at"])
json.dump(report, open(OUT, "w"), indent=1)
