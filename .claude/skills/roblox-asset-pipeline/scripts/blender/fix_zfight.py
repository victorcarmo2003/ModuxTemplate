"""Auto-fix z-fighting: push the smaller island of every same-facing coplanar pair out by EPS along the normal,
then resave the .blend and re-export its work FBX (<root>/models/<rel>.fbx, same conventions as the modellers).

  sh bl.sh fix_zfight.py -- --root "D:/Game/Assets" equipment/AST-020_CashRegister.blend story/AST-037_Flyer.blend

Triangulates before detecting (ngons hide pairs). Re-run overlap_check.py afterwards. For interpenetration that is
not coplanar (an arm through a knob), fix the geometry by hand - this script does not move those.
"""
import bpy, bmesh, os, sys
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:]
ROOT = argv[argv.index("--root") + 1].rstrip("/\\") + "/"
files = [a for k, a in enumerate(argv) if a != "--root" and (k == 0 or argv[k - 1] != "--root")]
EPS = 0.004


def islands(bm):
    seen, out = set(), []
    for f in bm.faces:
        if f.index in seen: continue
        st, comp = [f], []
        while st:
            x = st.pop()
            if x.index in seen: continue
            seen.add(x.index); comp.append(x)
            for e in x.edges:
                st += [g for g in e.link_faces if g.index not in seen]
        out.append(comp)
    return out


for rel in files:
    bpy.ops.wm.open_mainfile(filepath=ROOT + "blender/" + rel)
    moved = 0
    for o in bpy.data.objects:
        if o.type != "MESH" or o.name.startswith("REF_"): continue
        for _ in range(40):
            bm = bmesh.new(); bm.from_mesh(o.data); bmesh.ops.triangulate(bm, faces=bm.faces[:])
            bm.faces.ensure_lookup_table(); bm.verts.ensure_lookup_table()
            trees = []
            for comp in islands(bm):
                vs = list({v for f in comp for v in f.verts}); idx = {v: i for i, v in enumerate(vs)}
                trees.append((BVHTree.FromPolygons([v.co for v in vs], [[idx[v] for v in f.verts] for f in comp]), comp, vs))
            changed = False
            for i in range(len(trees)):
                for j in range(i + 1, len(trees)):
                    ti, ci, vi = trees[i]; tj, cj, vj = trees[j]
                    for a, b in ti.overlap(tj):
                        fa, fb = ci[a], cj[b]
                        if fa.normal.dot(fb.normal) > 0.999 and abs((fb.verts[0].co - fa.verts[0].co).dot(fa.normal)) < 0.003:
                            small = vi if len(vi) < len(vj) else vj
                            n = fa.normal.copy()
                            for v in small:
                                v.co += n * EPS
                            moved += 1; changed = True
                            break
                    if changed: break
                if changed: break
            if changed:
                bm.to_mesh(o.data)
            bm.free()
            if not changed: break
    bpy.ops.wm.save_as_mainfile(filepath=ROOT + "blender/" + rel)
    out = ROOT + "models/" + rel[:-6] + ".fbx"
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in bpy.data.objects:
        if ob.type in ("MESH", "EMPTY") and not ob.name.startswith("REF_"):
            ob.select_set(True)
    bpy.ops.export_scene.fbx(filepath=out, use_selection=True, object_types={"MESH", "EMPTY"}, apply_unit_scale=True,
                             axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE", add_leaf_bones=False, bake_anim=False)
    print("FIXED", rel, "islands moved", moved)
