# Usage: sh <roblox-asset-pipeline>/scripts/blender/bl.sh tools/blender/drive_cars.py -- "<repo>/Assets"
# Drive-thru car variants (TASK-574, owner 2026-10-20): the AST-035 cars with the glass faces as their own object
# ("Glass", made translucent in Roblox) and a dark inner shell ("Interior", flipped copy of the body) so the cabin is
# not hollow when seen through the glass. Saves Assets/blender/vehicle/AST-035_Car<Shape>_Drive.blend and exports
# Assets/import/vehicle/AST-035_Car<Shape>_Drive.fbx (Body, Glass, Interior; same origin as the base car).
import bpy, bmesh, os, sys
from mathutils import Matrix
ROOT = sys.argv[sys.argv.index("--") + 1]
RZ = Matrix.Rotation(3.141592653589793, 4, "Z")
DARK = (0.16, 0.16, 0.18)

def glassy(c):
    return c[2] >= 0.97 and c[0] >= 0.8 and c[1] >= 0.9

for shape in ["Sedan", "Hatch", "Van", "Pickup"]:
    src = f"{ROOT}/blender/vehicle/AST-035_Car{shape}.blend"
    bpy.ops.wm.open_mainfile(filepath=src)
    img = bpy.data.images["colormap"]; w, h = img.size; px = list(img.pixels)
    def col(u, v):
        x = min(int(u % 1 * w), w - 1); y = min(int(v % 1 * h), h - 1); i = (y * w + x) * 4
        return px[i:i + 3]
    # darkest neutral texel for the interior
    best = None
    for y in range(0, h, 4):
        for x in range(0, w, 4):
            i = (y * w + x) * 4; c = px[i:i + 3]
            d = sum((c[k] - DARK[k]) ** 2 for k in range(3))
            if best is None or d < best[0]: best = (d, x, y)
    dark_uv = ((best[1] + 0.5) / w, (best[2] + 0.5) / h)

    body = bpy.data.objects["Body"]
    paint = bpy.data.objects["Paint"]
    # 1. glass faces out of the body
    bm = bmesh.new(); bm.from_mesh(body.data); uvl = bm.loops.layers.uv.active
    glass_faces = []
    for f in bm.faces:
        u = sum(l[uvl].uv.x for l in f.loops) / len(f.loops); v = sum(l[uvl].uv.y for l in f.loops) / len(f.loops)
        if glassy(col(u, v)): glass_faces.append(f)
    gm = bpy.data.meshes.new("Glass")
    gbm = bmesh.new()
    vmap = {}
    guv = gbm.loops.layers.uv.new("UVMap")
    for f in glass_faces:
        vs = []
        for vert in f.verts:
            if vert not in vmap: vmap[vert] = gbm.verts.new(vert.co)
            vs.append(vmap[vert])
        nf = gbm.faces.new(vs)
        for nl, ol in zip(nf.loops, f.loops): nl[guv].uv = ol[uvl].uv
    gbm.to_mesh(gm); gbm.free()
    bmesh.ops.delete(bm, geom=glass_faces, context="FACES_ONLY")
    bm.to_mesh(body.data); bm.free()
    glass = bpy.data.objects.new("Glass", gm); glass.matrix_world = body.matrix_world.copy()
    gm.materials.append(body.data.materials[0])
    bpy.context.scene.collection.objects.link(glass)
    # 2. interior: body + paint copies, flipped, one dark texel
    parts = []
    for o in (body, paint):
        c = o.copy(); c.data = o.data.copy(); bpy.context.scene.collection.objects.link(c); parts.append(c)
    bpy.ops.object.select_all(action="DESELECT")
    for c in parts: c.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    inner = bpy.context.view_layer.objects.active; inner.name = "Interior"; inner.data.name = "Interior"
    me = inner.data
    for p in me.polygons: p.flip()
    # a hair inside the outer shell: never coplanar with it
    me.update()
    for v in me.vertices: v.co -= v.normal * -0.06
    for l in me.uv_layers.active.data: l.uv = dark_uv
    # 3. keep only what the variant exports
    keep = {"Body", "Glass", "Interior"}
    for o in list(bpy.data.objects):
        if o.name not in keep: bpy.data.objects.remove(o, do_unlink=True)
    print(shape, "glass faces", len(glass_faces), "body", len(body.data.polygons), "interior", len(me.polygons), "dark", dark_uv, col(*dark_uv))
    blend = f"{ROOT}/blender/vehicle/AST-035_Car{shape}_Drive.blend"
    bpy.ops.wm.save_as_mainfile(filepath=blend)
    objs = [bpy.data.objects[n] for n in ("Body", "Glass", "Interior")]
    for o in objs: o.matrix_world = RZ @ o.matrix_world
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    out = f"{ROOT}/import/vehicle/AST-035_Car{shape}_Drive.fbx"
    bpy.ops.export_scene.fbx(filepath=out, use_selection=True, object_types={"MESH"}, apply_unit_scale=True,
                             global_scale=0.01, axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE",
                             add_leaf_bones=False, bake_anim=False, path_mode="COPY", embed_textures=True)
    print("exported", out, os.path.getsize(out))
