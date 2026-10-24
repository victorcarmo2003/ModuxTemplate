"""Build the final import set: every asset as FBX that lands in Roblox at the right size and orientation.

  sh bl.sh export_import.py -- --root "D:/Game/Assets" [--direct direct.json] [--only "character/*"] [--cube]

  --root    Assets folder containing blender/<cat>/*.blend and the pack folders; output goes to <root>/import/
  --direct  JSON list of pack pieces used as-is: [{"cat","name","path","mode","target"}] (templates/direct_pack_example.json)
            mode: "x" | "y" (up) | "z" | "max" uniform to that size, or "box" with target [X, Y up, Z] (null = keep uniform)
  --only    fnmatch filter on "<cat>/<file>" for the .blend part (e.g. "character/*")
  --skip-blends  only export the direct list
  --cube    also write _Calibration_Cube_1stud.fbx

Conventions applied (measured in Roblox, see references/roblox-import.md):
  1 Blender unit = 1 stud (global_scale 0.01), geometry rotated 180 deg about Z (Blender +Y front -> Roblox -Z),
  textures embedded, pivot = base centre (direct pieces), mirrored glTF nodes fixed. Writes <root>/import/_export_log.json.
"""
import bpy, fnmatch, glob, json, os, sys
from mathutils import Vector, Matrix


def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    o = {"root": None, "direct": None, "only": None, "cube": False, "skip_blends": False}
    i = 0
    while i < len(a):
        k = a[i]
        if k == "--cube": o["cube"] = True
        elif k == "--skip-blends": o["skip_blends"] = True
        else:
            o[k[2:].replace("-", "_")] = a[i + 1]; i += 1
        i += 1
    return o


A = args()
ROOT = A["root"].rstrip("/\\") + "/"
OUT = ROOT + "import/"
log = []
RZ = Matrix.Rotation(3.141592653589793, 4, "Z")


def fbx(path, objs):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    roots = [o for o in objs if o.parent is None or o.parent not in objs]
    for o in roots:  # Roblox ignores FBX axis metadata: turn the geometry itself
        o.matrix_world = RZ @ o.matrix_world
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH", "EMPTY"}, apply_unit_scale=True,
                             global_scale=0.01, axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE",
                             add_leaf_bones=False, bake_anim=False, path_mode="COPY", embed_textures=True)


# ---------- our .blend sources ----------
if not A["skip_blends"]:
    for path in sorted(glob.glob(ROOT + "blender/**/*.blend", recursive=True)):
        rel = os.path.relpath(path, ROOT + "blender").replace("\\", "/")
        if A["only"] and not fnmatch.fnmatch(rel, A["only"]):
            continue
        bpy.ops.wm.open_mainfile(filepath=path)
        objs = [o for o in bpy.data.objects if o.type in ("MESH", "EMPTY") and not o.name.startswith("REF_") and not o.hide_render]
        if not objs:
            log.append(["skip-empty", rel]); continue
        for im in bpy.data.images:
            if im.source == "FILE" and im.filepath and not os.path.exists(bpy.path.abspath(im.filepath)):
                log.append(["missing-texture", rel, im.filepath])
        out = OUT + rel[:-6] + ".fbx"
        fbx(out, objs)
        log.append(["ours", rel, os.path.getsize(out)])

# ---------- pack pieces used as-is ----------
for d in (json.load(open(A["direct"], encoding="utf-8")) if A["direct"] else []):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    before = set(bpy.data.objects)
    p = d["path"] if os.path.isabs(d["path"]) else ROOT + d["path"]
    if p.lower().endswith((".glb", ".gltf")):
        bpy.ops.import_scene.gltf(filepath=p)
    else:
        bpy.ops.import_scene.fbx(filepath=p)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    for o in meshes:
        mw = o.matrix_world.copy()
        o.data.transform(mw)
        if mw.determinant() < 0:
            o.data.flip_normals()
    for o in new:
        o.parent = None
    for o in meshes:
        o.matrix_world = Matrix.Identity(4)
    for o in new:
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    # Materials without an image (Kenney glass: flat colour, alpha 0.5, UVs spanning -11..27) would read the
    # atlas once joined and show it tiled. Collapse their UVs onto the atlas texel closest to their colour and
    # keep glass objects separate (named "Glass*"; the placement runner makes them translucent).
    atlas = next((n.image for m in bpy.data.materials if m and m.use_nodes for n in m.node_tree.nodes
                  if n.type == "TEX_IMAGE" and n.image), None)
    apx = list(atlas.pixels[:]) if atlas else None
    separate = []
    for o in meshes:
        me = o.data
        uvl = me.uv_layers.active or me.uv_layers.new(name="UVMap")
        flat_all, glass = True, False
        for mi, m in enumerate(me.materials):
            has_img = bool(m and m.use_nodes and any(n.type == "TEX_IMAGE" and n.image for n in m.node_tree.nodes))
            if has_img:
                flat_all = False
                continue
            bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if m and m.use_nodes else None
            col = tuple(bsdf.inputs["Base Color"].default_value[:3]) if bsdf else (0.8, 0.8, 0.8)
            glass = glass or (bsdf is not None and bsdf.inputs["Alpha"].default_value < 0.99)
            uv = (0.5, 0.5)
            if apx:
                w, h = atlas.size
                best = None
                for yy in range(0, h, max(1, h // 64)):
                    for xx in range(0, w, max(1, w // 64)):
                        k = (yy * w + xx) * 4
                        dist = sum((apx[k + c] - col[c]) ** 2 for c in range(3))
                        if best is None or dist < best[0]:
                            best = (dist, xx, yy)
                uv = ((best[1] + 0.5) / w, (best[2] + 0.5) / h)
            for p in me.polygons:
                if p.material_index == mi:
                    for li in p.loop_indices:
                        uvl.data[li].uv = uv
        if flat_all and len(meshes) > 1:
            separate.append(o)
            o.name = "Glass" if glass else (o.name + "_Flat")
            log.append(["flat-material", d["name"], o.name])
    pts = [v.co for o in meshes for v in o.data.vertices]
    mn = Vector((min(q.x for q in pts), min(q.y for q in pts), min(q.z for q in pts)))
    mx = Vector((max(q.x for q in pts), max(q.y for q in pts), max(q.z for q in pts)))
    size = mx - mn
    mode, target = d["mode"], d["target"]
    if mode == "box":
        tx, ty, tz = target
        u = tx / size.x
        S = (u, tz / size.y if tz else u, ty / size.z if ty else u)
    else:
        ref = {"x": size.x, "y": size.z, "z": size.y, "max": max(size)}[mode]
        S = (target / ref,) * 3
    base = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
    M = Matrix.Diagonal((S[0], S[1], S[2], 1)) @ Matrix.Translation(-base)
    for o in meshes:
        o.data.transform(M)
    solid = [o for o in meshes if o not in separate]
    if len(solid) > 1:
        bpy.ops.object.select_all(action="DESELECT")
        for o in solid:
            o.select_set(True)
        bpy.context.view_layer.objects.active = solid[0]
        bpy.ops.object.join()
        solid = [bpy.context.view_layer.objects.active]
    solid[0].name = d["name"]; solid[0].data.name = d["name"]
    out = OUT + d["cat"] + "/" + d["name"] + ".fbx"
    fbx(out, solid + separate)
    log.append(["pack", d["cat"] + "/" + d["name"], round(size.x * S[0], 2), round(size.z * S[2], 2), round(size.y * S[1], 2)])

if A["cube"]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.5))
    c = bpy.context.active_object; c.name = "Calibration_1stud"
    fbx(OUT + "_Calibration_Cube_1stud.fbx", [c])
    log.append(["cube", "_Calibration_Cube_1stud"])

os.makedirs(OUT, exist_ok=True)
json.dump(log, open(OUT + "_export_log.json", "w"), indent=1)
for l in log:
    print("LOG", *l)
