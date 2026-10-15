"""Export AST-059 Acc_Raincoat pieces + verify (normals, tris, bbox, round trip).

  sh bl.sh tools/blender/character/export_ast059.py

Per piece two FBX files:
  Assets/models/character/AST-059_Acc_Raincoat_<Body|Hood>.fbx   plain (same convention as AST-081_Acc_*: in place, studs,
                                                                   re-imports with the .blend coordinates)
  Assets/import/character/AST-059_Acc_Raincoat_<Body|Hood>.fbx   Roblox-ready (geometry rotated 180 deg about Z, 0.01 scale,
                                                                   like export_import.py) for the later upload step
"""
import bpy, bmesh, json, math
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ROOT = "D:/UserData/Documents/ModuxGames/Sell Hotdogs/Assets/"
BLEND = ROOT + "blender/character/AST-059_Acc_Raincoat.blend"
bpy.ops.wm.open_mainfile(filepath=BLEND)
pieces = {n: bpy.data.objects["Acc_Raincoat_" + n] for n in ("Body", "Hood")}

# ---- normals: recompute is unreliable on open shells, so test with rays. A face of an open shell is "outward" when a ray
# from just above its surface, travelling along the normal, escapes to infinity or hits nothing of the same piece; and
# the lining faces (inside the hood / under the hem) are tested the other way. Here: outer faces by the radial rule.
report = {}
for n, o in pieces.items():
    me = o.data
    me.calc_loop_triangles()
    bad = 0
    tot = 0
    centre = Vector((0, 0, 3.0)) if n == "Body" else Vector((0, -0.4, 4.9))
    bm = bmesh.new(); bm.from_mesh(me); bm.normal_update()
    bvh = BVHTree.FromBMesh(bm)
    for f in bm.faces:
        c = f.calc_center_median()
        nrm = f.normal
        # uv v of the face tells outer (yellow, cell frac low) vs lining; use the colour band instead: amber = col 2
        u = me.uv_layers["UVMap"].data[me.polygons[f.index].loop_indices[0]].uv
        amber = (u.x * 8) < 3.0   # column 2 = lining / toggles / lip, column 3 = outer
        tot += 1
        if not amber:
            # outer shell: a ray from 0.02 outside along the normal must not hit the piece again (open shell, convex-ish)
            hit = bvh.ray_cast(c + nrm * 0.02, nrm, 20.0)
            if hit[0] is not None:
                bad += 1
            # and it must face away from the piece centre horizontally unless it is a rim facing down
            if nrm.z > -0.5 and Vector((c.x - centre.x, c.y - centre.y, 0)).dot(Vector((nrm.x, nrm.y, 0))) < -0.01 and not (n == "Hood" and nrm.y > 0.6):
                bad += 1
        else:
            # lining / lip: sits inside the outer shell - a ray along its normal (towards the cavity) must not hit the
            # outer shell within 0.0..; checked loosely: it must point toward the axis for hood lining
            if n == "Hood" and nrm.z > -0.5 and (Vector((c.x - centre.x, c.y - centre.y, 0)).dot(Vector((nrm.x, nrm.y, 0))) > 0.01) and c.z > 4.3:
                bad += 1
    bm.free()
    report[n] = {"tris": len(me.loop_triangles), "faces": len(me.polygons), "inverted_faces": bad}

# ---- export
def export(path, objs, rotate):
    bpy.ops.object.select_all(action="DESELECT")
    saved = []
    for o in objs:
        saved.append(o.matrix_world.copy())
        if rotate:
            o.matrix_world = Matrix.Rotation(math.pi, 4, "Z") @ o.matrix_world
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if rotate:
        bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, apply_unit_scale=True,
                                 global_scale=0.01, axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE",
                                 add_leaf_bones=False, bake_anim=False, path_mode="COPY", embed_textures=True)
    else:
        bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, mesh_smooth_type="FACE",
                                 add_leaf_bones=False, bake_anim=False, path_mode="COPY", embed_textures=True)
    for o, m in zip(objs, saved):
        o.matrix_world = m


for n, o in pieces.items():
    export(ROOT + f"models/character/AST-059_Acc_Raincoat_{n}.fbx", [o], False)
    export(ROOT + f"import/character/AST-059_Acc_Raincoat_{n}.fbx", [o], True)

# ---- round trip of the models/ files: bbox must equal the .blend
bpy.ops.wm.read_factory_settings(use_empty=True)
for n in pieces:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=ROOT + f"models/character/AST-059_Acc_Raincoat_{n}.fbx")
    for o in set(bpy.data.objects) - before:
        if o.type == "MESH":
            bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
            report[n]["roundtrip_min"] = [round(min(v[i] for v in bb), 3) for i in range(3)]
            report[n]["roundtrip_max"] = [round(max(v[i] for v in bb), 3) for i in range(3)]
            report[n]["roundtrip_tris"] = sum(len(p.vertices) - 2 for p in o.data.polygons)
            report[n]["materials"] = [m.name for m in o.data.materials]
            report[n]["uv_layers"] = list(o.data.uv_layers.keys())
print("REPORT", json.dumps(report))
