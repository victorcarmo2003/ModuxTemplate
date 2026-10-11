# Shared helpers for the Mart v2 assets (AST-103..AST-107). Exec'd by each build script:
#   exec(open(<this file>, encoding="utf-8").read())
# Builds on the roblox-asset-pipeline toylib (box/cyl/torus/tube/uv_band) with the KitchenPack (KayKit Restaurant
# Bits) gradient atlas, so every piece shares one texture with the KitchenPack props already in the game.
import bpy, bmesh, json, math, os, sys
from mathutils import Vector, Matrix

SKILL = os.path.expanduser("~/.claude/skills/roblox-asset-pipeline/scripts/blender/")
exec(open(SKILL + "toylib.py", encoding="utf-8").read())

ROOT = "D:/UserData/Documents/ModuxGames/Sell Hotdogs/"
ATLAS = ROOT + "Assets/KitchenPack/Assets/textures/restaurantbits_texture.png"
REF = ROOT + "Assets/reference/"

# KitchenPack atlas bands (row, col, lo, hi) - 8 x 4 grid of vertical gradients (sampled 2026-10-11)
TEAL = (1, 2, 0.10, 0.65)
TEAL_D = (1, 2, 0.45, 0.95)
MUSTARD = (1, 6, 0.04, 0.42)
YELLOW = (2, 3, 0.10, 0.90)
CREAM = (1, 4, 0.04, 0.45)
WOOD = (1, 5, 0.10, 0.80)
WOOD_D = (0, 6, 0.15, 0.75)
STEEL = (0, 3, 0.05, 0.60)
STEEL_L = (0, 4, 0.05, 0.75)
SLATE = (0, 2, 0.20, 0.80)
DARK = (0, 1, 0.30, 0.90)
KETCHUP = (2, 6, 0.10, 0.70)
RED = (1, 1, 0.15, 0.55)
GREEN = (2, 1, 0.05, 0.60)
PINK = (2, 5, 0.10, 0.55)
PEACH = (1, 3, 0.05, 0.50)
ORANGE = (2, 4, 0.10, 0.70)
BROWN = (0, 6, 0.40, 1.00)
ICE = (1, 0, 0.00, 0.45)
GLASS = (3, 0, 0.30, 0.60)
BUN = (1, 5, 0.00, 0.55)


def mesh_objs():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def recentre(objs=None):
    """Lesson 25: the bbox base centre of the whole asset IS the origin. Returns the shift applied (x, y, z)."""
    objs = objs or mesh_objs()
    lo, hi = bbox(objs)
    shift = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for o in objs:
        o.data.transform(Matrix.Translation(-shift))
    for o in bpy.context.scene.objects:
        if o.type == "EMPTY" and o.parent is None:
            o.location -= shift
    bpy.context.view_layer.update()
    return shift


def report(objs=None):
    objs = objs or mesh_objs()
    lo, hi = bbox(objs)
    parts = {o.name: tris_of(o) for o in objs}
    size = hi - lo
    # Blender (x, y, z) -> Roblox studs X = x, Y = z (up), Z = y (depth)
    return {"size_studs_XYZ": [round(size.x, 3), round(size.z, 3), round(size.y, 3)],
            "tris": sum(parts.values()), "parts": parts}


def atts_json(path, extra=None):
    """Empties do not become Attachments in Roblox: positions (Roblox axes, model-local, after the 180 deg turn of
    the exporter: Roblox X = -x, Y = z, Z = y) go in a side JSON."""
    out = {}
    for o in bpy.context.scene.objects:
        if o.type == "EMPTY":
            p = o.matrix_world.translation
            out[o.name] = [round(-p.x, 3), round(p.z, 3), round(p.y, 3)]
    if extra:
        out.update(extra)
    json.dump(out, open(path, "w"), indent=1)


def views(stem, objs=None, fp=None):
    """3/4 front, front, back 3/4 previews (+ optional first-person: (eye_xyz, target_xyz))."""
    objs = objs or mesh_objs()
    render(REF + stem + ".png", objs, direction=(0.75, 1.0, 0.55))
    render(REF + stem + "_Front.png", objs, direction=(0.0, 1.0, 0.12))
    render(REF + stem + "_Back.png", objs, direction=(-0.8, -1.0, 0.5))
    if fp:
        scn = bpy.context.scene
        cam = bpy.data.objects["PreviewCam"]
        cam.location = Vector(fp[0])
        cam.rotation_euler = (Vector(fp[1]) - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = 18
        scn.render.filepath = REF + stem + "_FirstPerson.png"
        bpy.ops.render.render(write_still=True)


def setup_render():
    scn = bpy.context.scene
    scn.render.image_settings.file_format = "PNG"
    scn.view_settings.view_transform = "Standard"
    try:
        scn.eevee.taa_render_samples = 16
    except Exception:
        pass


RZ = Matrix.Rotation(math.pi, 4, "Z")


def export_fbx(path):
    """Same convention as roblox-asset-pipeline export_import.py: geometry turned 180 deg about Z (Blender +Y front ->
    Roblox -Z), global_scale 0.01, textures embedded. Call AFTER saving the .blend (it rotates the scene)."""
    objs = [o for o in bpy.context.scene.objects if o.type in ("MESH", "EMPTY") and not o.name.startswith(("REF_", "Preview"))]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    for o in [o for o in objs if o.parent is None or o.parent not in objs]:
        o.matrix_world = RZ @ o.matrix_world
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH", "EMPTY"}, apply_unit_scale=True,
                             global_scale=0.01, axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE",
                             add_leaf_bones=False, bake_anim=False, path_mode="COPY", embed_textures=True)


def import_piece(path):
    """Import a pack piece, bake its transforms (fix mirrored nodes), return its mesh objects."""
    before = set(bpy.data.objects)
    if path.lower().endswith((".glb", ".gltf")):
        bpy.ops.import_scene.gltf(filepath=path)
    else:
        bpy.ops.import_scene.fbx(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    bpy.context.view_layer.update()
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
    return meshes


def place_piece(meshes, size=None, scale=None, base=(0, 0, 0), rotz=0.0):
    """Uniformly scale pack meshes (to fit `size` max extents or by `scale`), base-centre them at `base`."""
    lo, hi = bbox(meshes)
    s = scale
    if s is None:
        ext = hi - lo
        s = min(size[i] / ext[i] for i in range(3) if size[i])
    c = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    M = Matrix.Translation(Vector(base)) @ Matrix.Rotation(rotz, 4, "Z") @ Matrix.Scale(s, 4) @ Matrix.Translation(-c)
    for o in meshes:
        o.data.transform(M)
        if not o.data.materials or o.data.materials[0] != mat:
            pass
    return s


def to_atlas_material(o):
    """Pack piece already UV-mapped on the KitchenPack atlas: swap its material for the shared atlas material."""
    o.data.materials.clear()
    o.data.materials.append(mat)


def save_all(cat, stem, info):
    blend = ROOT + "Assets/blender/%s/%s.blend" % (cat, stem)
    save_blend(blend)
    fbx = ROOT + "Assets/import/%s/%s.fbx" % (cat, stem)
    export_fbx(fbx)
    info["fbx"] = fbx
    info["blend"] = blend
    print("REPORT", json.dumps({stem: info}))
