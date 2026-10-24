"""Overlap / z-fight checker for .blend files (headless).

  sh bl.sh overlap_check.py -- --root "D:/Game/Assets/blender" [--files equipment/A.blend vehicle/B.blend] [--out report.json]

Parts = loose islands of every visible mesh (REF_* ignored). For each pair of parts whose triangles overlap:
  z-fight  = same-facing normals (dot > 0.999), same plane (< 0.003) and REAL overlap area (> 1e-4)
  other    = interpenetration/contact (often intentional embedding - judge on close-up renders)
Prints FILE lines with zfight_pairs and ZF details. Back-to-back contact faces and edge-only touches are not z-fight.
"""
import bpy, bmesh, glob, json, os, sys
from mathutils import Vector
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ROOT, FILES, OUTP = None, [], None
i = 0
while i < len(argv):
    if argv[i] == "--root": ROOT = argv[i + 1]; i += 2
    elif argv[i] == "--out": OUTP = argv[i + 1]; i += 2
    elif argv[i] == "--files":
        i += 1
        while i < len(argv) and not argv[i].startswith("--"):
            FILES.append(argv[i]); i += 1
    else: i += 1
paths = [os.path.join(ROOT, f) for f in FILES] if FILES else sorted(glob.glob(os.path.join(ROOT, "**", "*.blend"), recursive=True))


def _area(va, vb, n):
    ax = (va[1] - va[0]).normalized(); ay = n.cross(ax)
    P = lambda p: ((p - va[0]).dot(ax), (p - va[0]).dot(ay))
    subj = [P(p) for p in va]; clip = [P(p) for p in vb]
    cr = lambda o, a, b: (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    if cr(clip[0], clip[1], clip[2]) < 0: clip = clip[::-1]
    if cr(subj[0], subj[1], subj[2]) < 0: subj = subj[::-1]
    out = subj
    for k in range(3):
        a, b = clip[k], clip[(k + 1) % 3]
        inp, out = out, []
        if not inp: break
        for j in range(len(inp)):
            p, q = inp[j], inp[(j + 1) % len(inp)]
            ip, iq = cr(a, b, p) > 1e-9, cr(a, b, q) > 1e-9
            if ip: out.append(p)
            if ip != iq:
                d1, d2 = cr(a, b, p), cr(a, b, q)
                t = d1 / (d1 - d2)
                out.append((p[0] + t * (q[0] - p[0]), p[1] + t * (q[1] - p[1])))
    if len(out) < 3: return 0.0
    return abs(sum(out[k][0] * out[(k + 1) % len(out)][1] - out[(k + 1) % len(out)][0] * out[k][1] for k in range(len(out)))) / 2


report = {}
for path in paths:
    bpy.ops.wm.open_mainfile(filepath=path)
    parts = []
    for o in bpy.data.objects:
        if o.type != "MESH" or o.name.startswith("REF_") or o.hide_render:
            continue
        bm = bmesh.new(); bm.from_mesh(o.data); bm.transform(o.matrix_world)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        bm.faces.ensure_lookup_table()
        seen, isl = set(), []
        for f in bm.faces:
            if f.index in seen: continue
            st, comp = [f], []
            while st:
                x = st.pop()
                if x.index in seen: continue
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
    for a_i in range(len(parts)):
        for b_i in range(a_i + 1, len(parts)):
            ov = trees[a_i].overlap(trees[b_i])
            if not ov: continue
            cop = 0
            for a, b in ov:
                va = [parts[a_i][1][q] for q in parts[a_i][2][a]]
                vb = [parts[b_i][1][q] for q in parts[b_i][2][b]]
                na = (va[1] - va[0]).cross(va[2] - va[0]).normalized()
                nb = (vb[1] - vb[0]).cross(vb[2] - vb[0]).normalized()
                if na.dot(nb) > 0.999 and abs((vb[0] - va[0]).dot(na)) < 0.003 and _area(va, vb, na) > 1e-4:
                    cop += 1
            hits.append({"a": parts[a_i][0], "b": parts[b_i][0], "pairs": len(ov), "coplanar": cop,
                         "at": [round(x, 2) for x in (sum(parts[b_i][1], Vector()) / len(parts[b_i][1]))]})
    rel = os.path.relpath(path, ROOT)
    report[rel] = {"parts": len(parts), "hits": hits}
    zf = [h for h in hits if h["coplanar"]]
    print(f"FILE {rel}: parts={len(parts)} intersecting_pairs={len(hits)} zfight_pairs={len(zf)}")
    for h in zf:
        print("   ZF", h["a"], "x", h["b"], "tris", h["coplanar"], "at", h["at"])
if OUTP:
    json.dump(report, open(OUTP, "w"), indent=1)
