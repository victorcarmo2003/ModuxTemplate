import os
import bpy, bmesh, sys, json, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hcommon import *
from mathutils import Vector
from mathutils.bvhtree import BVHTree
def wb(o):
    bm = bmesh.new(); bm.from_mesh(o.data); bm.transform(o.matrix_world); return bm
def inside(bvh, p):
    n = 0; q = p.copy(); d = Vector((0.0123, 0.0071, 1)).normalized()
    for _ in range(50):
        h = bvh.ray_cast(q, d)
        if h[0] is None: break
        n += 1; q = h[0] + d * 1e-5
    return n % 2 == 1
for an in ORDER:
    bpy.ops.wm.open_mainfile(filepath=ROOT + f"Assets/blender/character/AST-053_Animal_{an}.blend")
    cap = bpy.data.objects["REF_Cap"]
    bmc = wb(cap); bvc = BVHTree.FromBMesh(bmc)
    res = {}
    for nm in ("Head_" + an, "Face_" + an):
        o = bpy.data.objects[nm]; bm = wb(o)
        out_above = [v.co for v in bm.verts if v.co.z > CAP_UNDER + 0.01 and not inside(bvc, v.co)]
        res[nm] = len(out_above)
        # surface samples: tri centres above 5.03 outside the cap
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        bad = 0
        for f in bm.faces:
            for w in ((1/3,1/3,1/3),(0.6,0.2,0.2),(0.2,0.6,0.2),(0.2,0.2,0.6)):
                p = sum((v.co * k for v, k in zip(f.verts, w)), Vector())
                if p.z > CAP_UNDER + 0.01 and not inside(bvc, p): bad += 1
        res[nm + "_samples_out"] = bad
    # gap: head ring at the crown underside vs crown footprint (distance from head ring to cap at z=5.02)
    head = bpy.data.objects["Head_" + an]
    hb = BVHTree.FromBMesh(wb(head))
    gaps = []
    for k in range(36):
        a = 2 * math.pi * k / 36; d = Vector((math.sin(a), math.cos(a), 0))
        hh = hb.ray_cast(Vector((0, 0, CAP_UNDER - 0.02)), d); hc = bvc.ray_cast(Vector((0, 0, CAP_UNDER + 0.02)), d)
        if hh[0] and hc[0]:
            gaps.append(round(hc[3] - hh[3], 3))
    res["rim_gap_min_max"] = [min(gaps), max(gaps)] if gaps else None
    print("CAPCHECK", an, CAP.get(an, "Cap_EarsUp"), json.dumps(res), flush=True)
