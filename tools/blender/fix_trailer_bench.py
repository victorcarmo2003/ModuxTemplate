"""AST-040 Trailer bench: the orange U handles sat at Z 0.25..0.38 (floor level) and read as feet sunk into the
checker floor in first person. Lift them to the door top (Z +1.17 (model space front = -Y here, the pack cabinet front) -> 1.42..1.55, under the 1.67 door rim).
Pure translation (no mirroring, normals stay). Idempotent.  sh bl.sh fix_trailer_bench.py -- <abs .blend>"""
import bpy, sys
path = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.open_mainfile(filepath=path)
o = bpy.data.objects["AST-040_TrailerBench"]
n = 0
for v in o.data.vertices:
    if 0.24 <= v.co.z <= 0.39 and v.co.y <= -1.22 and abs(v.co.x) <= 0.35:
        v.co.z += 1.17
        n += 1
print("MOVED", n, "verts")
o.data.update()
vs = [v.co for v in o.data.vertices]
print("BBOX", [round(min(v[i] for v in vs), 3) for i in range(3)], [round(max(v[i] for v in vs), 3) for i in range(3)])
bpy.ops.wm.save_mainfile()
