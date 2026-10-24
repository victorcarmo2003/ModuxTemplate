# Usage: sh bl.sh invscan.py -- <dir with AST-*.blend>   -> prints INV lines for inside-out closed islands
# Scan every mesh object of the character blends for closed islands with negative signed volume (inside-out).
import bpy, bmesh, glob, os
from mathutils import Vector
import sys
R = (sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else r"Assets/blender/character/").rstrip("/") + "/"
files = sorted(glob.glob(R + "AST-053_*.blend"))
for F in files:
    bpy.ops.wm.open_mainfile(filepath=F)
    for o in bpy.data.objects:
        if o.type != "MESH" or o.name.startswith("REF_"): continue
        bm = bmesh.new(); bm.from_mesh(o.data)
        seen = set(); mw = o.matrix_world; det = mw.determinant()
        for f in bm.faces:
            if f.index in seen: continue
            st = [f]; g = []; seen.add(f.index)
            while st:
                h = st.pop(); g.append(h)
                for e in h.edges:
                    for k in e.link_faces:
                        if k.index not in seen: seen.add(k.index); st.append(k)
            if not all(len(e.link_faces) == 2 for ff in g for e in ff.edges): continue
            vol = 0.0
            for ff in g:
                vs = [v.co for v in ff.verts]
                for j in range(1, len(vs) - 1): vol += vs[0].dot(vs[j].cross(vs[j + 1])) / 6
            vol *= det
            if vol < -1e-6:
                print("INV", os.path.basename(F), o.name, "faces", len(g), "vol", round(vol, 4))
        bm.free()
print("SCAN DONE", len(files))
