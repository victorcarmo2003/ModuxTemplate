# AST-053 round heads, step 3: materials, save .blend + FBX, renders (assembled on the CrewTex body).
# Env: ANIMAL=Dog,Cat  NOSAVE=1 (renders only)  EXPR=1 (also the expression close-ups, Dog)
import sys, os, json, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hcommon import *
import bpy, bmesh
from mathutils import Vector, Matrix

ONLY = [a for a in os.environ.get("ANIMAL", "").split(",") if a]
NOSAVE = os.environ.get("NOSAVE") == "1"
DOEXPR = os.environ.get("EXPR") == "1"
COL = json.load(open(HD + "/colors.json"))
RD = HD + "/r"
os.makedirs(RD, exist_ok=True)
CREWTEX = ROOT + "Assets/blender/character/AST-053_CrewTex.blend"
EXPRS = ["Normal", "Happy", "Smile", "Sad", "Fainted", "Normal_Night"]


def lin(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def img(path, rel):
    for im in bpy.data.images:
        if im.filepath and os.path.normcase(bpy.path.abspath(im.filepath)) == os.path.normcase(path):
            im.reload(); return im
    im = bpy.data.images.load(path)
    im.alpha_mode = "STRAIGHT"
    return im


def head_mat(an):
    name = f"M_Head_{an}"
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        if n.type not in ("OUTPUT_MATERIAL", "BSDF_PRINCIPLED"):
            nt.nodes.remove(n)
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Roughness"].default_value = 0.8
    t = nt.nodes.new("ShaderNodeTexImage"); t.name = "Tex"; t.image = img(TEX + f"T_Head_{an}.png", None)
    rgb = nt.nodes.new("ShaderNodeRGB"); rgb.name = "Fur"; rgb.label = "Fur colour (MeshPart.Color)"
    rgb.outputs[0].default_value = (*[lin(c) for c in COL[an]["fur"]], 1)
    mix = nt.nodes.new("ShaderNodeMix"); mix.name = "FurMix"; mix.data_type = "RGBA"
    nt.links.new(t.outputs["Alpha"], mix.inputs["Factor"])
    nt.links.new(rgb.outputs["Color"], mix.inputs[6])
    nt.links.new(t.outputs["Color"], mix.inputs[7])
    nt.links.new(mix.outputs[2], b.inputs["Base Color"])
    return m


def face_mat():
    m = bpy.data.materials.get("M_Face_Expr") or bpy.data.materials.new("M_Face_Expr")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        if n.type not in ("OUTPUT_MATERIAL", "BSDF_PRINCIPLED"):
            nt.nodes.remove(n)
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Roughness"].default_value = 0.55
    t = nt.nodes.new("ShaderNodeTexImage"); t.name = "Tex"; t.image = img(TEX + "face/T_Expr_Normal.png", None)
    nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    nt.links.new(t.outputs["Alpha"], b.inputs["Alpha"])
    try:
        m.surface_render_method = "BLENDED"
    except Exception:
        pass
    try:
        m.use_transparency_overlap = False
    except Exception:
        pass
    return m


def setup_render():
    scn = bpy.context.scene
    try:
        scn.render.engine = "BLENDER_EEVEE"
    except TypeError:
        scn.render.engine = "BLENDER_EEVEE_NEXT"
    scn.view_settings.view_transform = "Standard"
    if scn.world is None:
        scn.world = bpy.data.worlds.new("W")
    scn.world.use_nodes = True
    bg = next(n for n in scn.world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.42, 0.55, 0.72, 1); bg.inputs[1].default_value = 0.9
    L = {}
    for nm, e, c in (("Key", 3.2, (1, .95, .86)), ("Fill", 0.9, (.75, .85, 1)), ("Rim", 0.6, (1, 1, 1))):
        o = bpy.data.objects.new(nm, bpy.data.lights.new(nm, "SUN")); scn.collection.objects.link(o)
        o.data.energy = e; o.data.color = c; L[nm] = o
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); scn.collection.objects.link(cam)
    scn.camera = cam; cam.data.lens = 50
    return cam, L


def aim(o, d):
    o.rotation_euler = Vector(d).normalized().to_track_quat("Z", "Y").to_euler()


def shoot(cam, L, d, tgt, dist, path, res=(600, 800)):
    scn = bpy.context.scene
    scn.render.resolution_x, scn.render.resolution_y = res
    dv = Vector(d).normalized(); tgt = Vector(tgt)
    cam.location = tgt + dv * dist
    cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
    aim(L["Key"], dv * 1.4 + Vector((0.6, 0, 0.55)))
    aim(L["Fill"], Vector((-dv.x, -dv.y * 0.3, 0.4)) + Vector((-0.6, 0.2, 0)))
    aim(L["Rim"], Vector((-dv.x * 0.5, -1, 0.7)))
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)


def run(an):
    bpy.ops.wm.open_mainfile(filepath=HD + f"/work_{an}.blend")
    OB = bpy.data.objects
    head, face = OB["Head_" + an], OB["Face_" + an]
    hm, fm = head_mat(an), face_mat()
    head.data.materials.clear(); head.data.materials.append(hm)
    face.data.materials.clear(); face.data.materials.append(fm)
    pieces = [o for o in OB if o.type == "MESH" and not o.name.startswith("REF_")]
    if not NOSAVE:
        bpy.ops.wm.save_as_mainfile(filepath=ROOT + f"Assets/blender/character/AST-053_Animal_{an}.blend")
        bpy.ops.file.make_paths_relative()
        bpy.ops.wm.save_mainfile()
        # FBX: textures straight into Base Color so the exporter finds them, embedded
        nt = hm.node_tree
        b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        nt.links.new(nt.nodes["Tex"].outputs["Color"], b.inputs["Base Color"])
        exp = []
        for o in pieces:
            exp.append(o); exp += list(o.children)
        bpy.ops.object.select_all(action="DESELECT")
        for o in exp:
            o.hide_set(False); o.select_set(True)
        bpy.ops.export_scene.fbx(filepath=ROOT + f"Assets/models/character/AST-053_Animal_{an}.fbx", use_selection=True,
                                 object_types={"MESH", "EMPTY"}, apply_unit_scale=True, axis_forward="-Z", axis_up="Y",
                                 mesh_smooth_type="FACE", add_leaf_bones=False, bake_anim=False, path_mode="COPY", embed_textures=True)
        nt.links.new(nt.nodes["FurMix"].outputs[2], b.inputs["Base Color"])
        print("SAVED", an, flush=True)
    # ---------------- assemble on the CrewTex body for the board
    want = ["Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "Apron"] + (["Cap"] if CAP.get(an) == "Cap" else [])
    with bpy.data.libraries.load(CREWTEX) as (src, dst):
        dst.objects = want
    for o in dst.objects:
        bpy.context.scene.collection.objects.link(o)
        if o.name.startswith("Cap"):
            o.location.z += CAP_DZ
    for o in OB:
        if o.name.startswith("REF_") and not (o.name == "REF_Cap" and CAP.get(an) != "Cap"):
            o.hide_render = True
        if o.type == "EMPTY":
            o.hide_render = True
    mo = bpy.data.materials.get("M_CrewOutfit")
    if mo:
        mo.node_tree.nodes["Fur"].outputs[0].default_value = (*[lin(c) for c in COL[an]["hand"]], 1)
    # ground
    bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=10)
    gme = bpy.data.meshes.new("Ground"); bm.to_mesh(gme); bm.free()
    gnd = bpy.data.objects.new("Ground", gme); bpy.context.scene.collection.objects.link(gnd)
    gm = bpy.data.materials.new("G"); gm.use_nodes = True
    next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.32, 0.30, 0.27, 1)
    gme.materials.append(gm)
    cam, L = setup_render()
    shoot(cam, L, (0, 1, 0.12), (0, 0, 3.0), 14.5, RD + f"/{an}_front.png")
    shoot(cam, L, (0.8, 1, 0.35), (0, 0, 3.0), 14.5, RD + f"/{an}_34.png")
    shoot(cam, L, (0.3, 1, 0.18), (0, 0.2, 4.85), 6.6, RD + f"/{an}_face.png", (600, 600))
    shoot(cam, L, (1, 0.05, 0.15), (0, 0.0, 4.85), 6.6, RD + f"/{an}_side.png", (600, 600))
    shoot(cam, L, (-0.6, -1, 0.3), (0, 0, 3.4), 12.0, RD + f"/{an}_back.png")
    # eye checks: 60 deg and 75 deg from the front, slightly below (like a player looking at a taller head)
    shoot(cam, L, (math.sin(math.radians(60)), math.cos(math.radians(60)), -0.05), (0, 0.6, 4.8), 4.6, RD + f"/{an}_e60.png", (600, 600))
    shoot(cam, L, (math.sin(math.radians(75)), math.cos(math.radians(75)), -0.10), (0, 0.8, 4.8), 4.0, RD + f"/{an}_e75.png", (600, 600))
    if DOEXPR:
        t = fm.node_tree.nodes["Tex"]
        for e in EXPRS:
            t.image = img(TEX + f"face/T_Expr_{e}.png", None)
            shoot(cam, L, (0.22, 1, 0.12), (0, 0.2, 4.85), 5.9, RD + f"/{an}_expr_{e}.png", (600, 600))
        hm.node_tree.nodes["Tex"].image = img(TEX + f"T_Head_{an}_Night.png", None)
        t.image = img(TEX + "face/T_Expr_Normal_Night.png", None)
        mo = bpy.data.materials.get("M_CrewOutfit")
        if mo:
            mo.node_tree.nodes["Tex"].image = img(ROOT + "Assets/textures/character/T_Crew_Uniform_Night.png", None)
        bg = next(n for n in bpy.context.scene.world.node_tree.nodes if n.type == "BACKGROUND")
        bg.inputs[0].default_value = (0.012, 0.016, 0.04, 1)
        L["Key"].data.color = (0.55, 0.68, 1.0); L["Key"].data.energy = 2.0
        L["Fill"].data.color = (0.35, 0.42, 0.8); L["Fill"].data.energy = 0.6
        L["Rim"].data.color = (0.5, 0.75, 1.0); L["Rim"].data.energy = 2.5
        shoot(cam, L, (0.22, 1, 0.12), (0, 0.2, 4.85), 5.9, RD + f"/{an}_night.png", (600, 600))


for an in (ONLY or ORDER):
    run(an)
print("FINISH DONE")
