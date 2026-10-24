# AST-053 CrewTex step 3: materials (texture + fur colour through alpha), board renders, .blend, FBX, bridge JSON.
import sys, os, math, json
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from charlib import *

BLEND = ROOT + "Assets/blender/character/AST-053_CrewTex.blend"
TEXD = ROOT + "Assets/textures/character/"
bpy.ops.wm.open_mainfile(filepath=BLEND)
scn = bpy.context.scene
OB = bpy.data.objects
BODY = ["Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"]
ACC = ["Cap", "Apron"]
ALL = BODY + ["Head"] + ACC


def srgb2lin(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def load(name):
    im = bpy.data.images.get(name) or bpy.data.images.load(TEXD + name)
    im.filepath = "//../../textures/character/" + name
    im.alpha_mode = "STRAIGHT"
    return im


def make_mat(name, img):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        if n.type not in ("OUTPUT_MATERIAL", "BSDF_PRINCIPLED"):
            nt.nodes.remove(n)
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Roughness"].default_value = 0.75
    t = nt.nodes.new("ShaderNodeTexImage"); t.name = "Tex"; t.image = img; t.interpolation = "Linear"
    rgb = nt.nodes.new("ShaderNodeRGB"); rgb.name = "Fur"; rgb.label = "Fur colour (MeshPart.Color)"
    mix = nt.nodes.new("ShaderNodeMix"); mix.name = "FurMix"; mix.data_type = "RGBA"
    nt.links.new(t.outputs["Alpha"], mix.inputs["Factor"])
    nt.links.new(rgb.outputs["Color"], mix.inputs[6])
    nt.links.new(t.outputs["Color"], mix.inputs[7])
    nt.links.new(mix.outputs[2], b.inputs["Base Color"])
    return m


def set_fur(col):
    for m in (MO, MF):
        m.node_tree.nodes["Fur"].outputs[0].default_value = (*[srgb2lin(c) for c in col], 1)


IM = {n: load(n) for n in ["T_Crew_Uniform_Day.png", "T_Crew_Uniform_Night.png", "T_Civil_A_Day.png", "T_Civil_A_Night.png",
                           "T_Civil_B_Day.png", "T_Civil_B_Night.png", "T_Face_Day.png", "T_Face_Night.png"]}
MO = make_mat("M_CrewOutfit", IM["T_Crew_Uniform_Day.png"])
MF = make_mat("M_CrewFace", IM["T_Face_Day.png"])
for nm in ALL + ["HumanoidRootPart"]:
    me = OB[nm].data
    me.materials.clear()
    me.materials.append(MF if nm == "Head" else MO)
old = bpy.data.materials.get("M_RestaurantBits")
if old and old.users == 0:
    bpy.data.materials.remove(old)
OB["HumanoidRootPart"].hide_render = True
for o in OB:
    if o.type == "EMPTY":
        o.hide_render = True

VARIANTS = [  # label, outfit, face, fur colour, night, cap, apron
    ("Crew - dia", "T_Crew_Uniform_Day.png", "T_Face_Day.png", (196, 128, 70), False, True, True),
    ("Crew - noite", "T_Crew_Uniform_Night.png", "T_Face_Night.png", (196, 128, 70), True, True, True),
    ("Civil A - dia", "T_Civil_A_Day.png", "T_Face_Day.png", (128, 132, 142), False, True, False),
    ("Civil A - noite", "T_Civil_A_Night.png", "T_Face_Night.png", (128, 132, 142), True, True, False),
    ("Civil B - dia", "T_Civil_B_Day.png", "T_Face_Day.png", (222, 112, 50), False, False, False),
    ("Civil B - noite", "T_Civil_B_Night.png", "T_Face_Night.png", (222, 112, 50), True, False, False),
]

# ---------------- save the .blend (crew day as default, dog-tan fur preview)
set_fur(VARIANTS[0][3])
bpy.ops.wm.save_as_mainfile(filepath=BLEND)

# ---------------- renders
os.makedirs(SP + "/previews/crewtex", exist_ok=True)
bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=10)
gme = bpy.data.meshes.new("Ground"); bm.to_mesh(gme); bm.free()
gnd = bpy.data.objects.new("Ground", gme); scn.collection.objects.link(gnd)
gm = bpy.data.materials.new("G"); gm.use_nodes = True
gb = next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
gme.materials.append(gm)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); scn.collection.objects.link(cam)
scn.camera = cam; cam.data.lens = 50
key = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "SUN")); scn.collection.objects.link(key)
fill_ = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "SUN")); scn.collection.objects.link(fill_)
rim = bpy.data.objects.new("Rim", bpy.data.lights.new("Rim", "SUN")); scn.collection.objects.link(rim)
lamp = bpy.data.objects.new("Lamp", bpy.data.lights.new("Lamp", "POINT")); scn.collection.objects.link(lamp)
scn.render.resolution_x, scn.render.resolution_y = 600, 800
scn.view_settings.view_transform = "Standard"
if scn.world is None:
    scn.world = bpy.data.worlds.new("W")
scn.world.use_nodes = True
bg = next(n for n in scn.world.node_tree.nodes if n.type == "BACKGROUND")


def aim(o, d):
    o.rotation_euler = Vector(d).normalized().to_track_quat("Z", "Y").to_euler()


VIEWS = [("front", (0, 1, 0.12)), ("34", (0.8, 1, 0.35))]
tiles = []
for i, (label, to, tf, furc, night, capv, apv) in enumerate(VARIANTS):
    MO.node_tree.nodes["Tex"].image = IM[to]; MF.node_tree.nodes["Tex"].image = IM[tf]
    set_fur(furc)
    OB["Cap"].hide_render = not capv; OB["Apron"].hide_render = not apv
    if night:
        bg.inputs[0].default_value = (0.012, 0.016, 0.04, 1); bg.inputs[1].default_value = 1.0
        gb.inputs["Base Color"].default_value = (0.02, 0.022, 0.035, 1)
        key.data.color = (0.55, 0.68, 1.0); key.data.energy = 2.0
        fill_.data.color = (0.35, 0.42, 0.8); fill_.data.energy = 0.6
        rim.data.color = (0.5, 0.75, 1.0); rim.data.energy = 2.5
        lamp.data.color = (1.0, 0.62, 0.3); lamp.data.energy = 120; lamp.hide_render = False
    else:
        bg.inputs[0].default_value = (0.42, 0.55, 0.72, 1); bg.inputs[1].default_value = 0.9
        gb.inputs["Base Color"].default_value = (0.32, 0.30, 0.27, 1)
        key.data.color = (1.0, 0.95, 0.86); key.data.energy = 3.2
        fill_.data.color = (0.75, 0.85, 1.0); fill_.data.energy = 0.9
        rim.data.color = (1, 1, 1); rim.data.energy = 0.6
        lamp.hide_render = True
    for vn, d in VIEWS:
        dv = Vector(d).normalized()
        tgt = Vector((0, 0, 3.0))
        cam.location = tgt + dv * 14.5
        cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
        aim(key, dv * 1.4 + Vector((0.6, 0, 0.55)))
        aim(fill_, Vector((-dv.x, -dv.y * 0.3, 0.4)) + Vector((-0.6, 0.2, 0)))
        aim(rim, Vector((-dv.x * 0.5, -1, 0.7)))
        lamp.location = (-3.0, 2.5, 5.5)
        out = SP + f"/previews/crewtex/v{i}_{vn}.png"
        scn.render.filepath = out
        bpy.ops.render.render(write_still=True)
        tiles.append((label, vn, out))
# close-ups of the face/logo (day + night)
for i in (0, 1):
    label, to, tf, furc, night, capv, apv = VARIANTS[i]
    MO.node_tree.nodes["Tex"].image = IM[to]; MF.node_tree.nodes["Tex"].image = IM[tf]
    set_fur(furc); OB["Cap"].hide_render = False; OB["Apron"].hide_render = False
    if night:
        bg.inputs[0].default_value = (0.012, 0.016, 0.04, 1)
        key.data.color = (0.55, 0.68, 1.0); key.data.energy = 1.6; lamp.hide_render = False
        fill_.data.energy = 0.35; rim.data.energy = 2.5
    else:
        bg.inputs[0].default_value = (0.42, 0.55, 0.72, 1)
        key.data.color = (1.0, 0.95, 0.86); key.data.energy = 3.2; lamp.hide_render = True
        fill_.data.energy = 0.9; rim.data.energy = 0.6
    for vn, d, tgt, dist in (("face", (0.25, 1, 0.15), (0, 0, 4.4), 6.0), ("back", (-0.5, -1, 0.3), (0, 0, 3.4), 9.0)):
        dv = Vector(d).normalized(); cam.location = Vector(tgt) + dv * dist
        cam.rotation_euler = (Vector(tgt) - cam.location).to_track_quat("-Z", "Y").to_euler()
        aim(key, dv * 1.4 + Vector((0.6, 0, 0.55)))
        scn.render.filepath = SP + f"/previews/crewtex/close{i}_{vn}.png"
        bpy.ops.render.render(write_still=True)
json.dump(tiles, open(SP + "/previews/crewtex/tiles.json", "w"))
for o in (gnd, cam, key, fill_, rim, lamp):
    bpy.data.objects.remove(o, do_unlink=True)

# ---------------- bridge JSON (Roblox axes), one entry per variant
entries = []
for label, to, tf, furc, night, capv, apv in VARIANTS:
    parts = []
    for nm in ["HumanoidRootPart"] + ALL:
        if (nm == "Cap" and not capv) or (nm == "Apron" and not apv):
            continue
        o = OB[nm]
        d = part_json(o, tf if nm == "Head" else to, transparency=1 if nm == "HumanoidRootPart" else None)
        d["pivot"] = rbx(o.matrix_world.translation)
        d["color"] = list(furc)
        parts.append(d)
    entries.append(("AST-053 CrewTex " + label, parts))
write_json("AST-053_CrewTex", entries)

# ---------------- FBX: textures linked straight to Base Color (crew day), embedded
MO.node_tree.nodes["Tex"].image = IM["T_Crew_Uniform_Day.png"]; MF.node_tree.nodes["Tex"].image = IM["T_Face_Day.png"]
for m in (MO, MF):
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    nt.links.new(nt.nodes["Tex"].outputs["Color"], b.inputs["Base Color"])
exp = []
for nm in ["HumanoidRootPart"] + ALL:
    o = OB[nm]; exp.append(o); exp += list(o.children)
bpy.ops.object.select_all(action="DESELECT")
for o in exp:
    o.hide_set(False); o.select_set(True)
fbx = ROOT + "Assets/models/character/AST-053_CrewTex.fbx"
bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, object_types={"MESH", "EMPTY"}, apply_unit_scale=True,
                         axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE", add_leaf_bones=False, bake_anim=False,
                         path_mode="COPY", embed_textures=True)
tot = 0
for nm in ALL:
    tot += tris(OB[nm])
print("TRIS visible", tot, {nm: tris(OB[nm]) for nm in ALL})
print("BUILD DONE", os.path.getsize(fbx))
