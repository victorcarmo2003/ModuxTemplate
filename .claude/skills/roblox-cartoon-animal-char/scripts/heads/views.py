# Validation views: front / 3-4 (45) / profile (85) / above 30, camera at another character's eye height.
# Env: ANIMAL=Dog,Fox  SRC=dir with AST-053_Animal_<A>.blend  TAG=before|after  TEXDIR=override texture dir (before)
import sys, os, json, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hcommon import *
import bpy, bmesh
from mathutils import Vector
ONLY = [a for a in os.environ.get("ANIMAL", "").split(",") if a]
SRC = os.environ.get("SRC", ROOT + "Assets/blender/character")
TAG = os.environ.get("TAG", "after")
TEXDIR = os.environ.get("TEXDIR")
VIEWS = os.environ.get("VIEWS", "front,34,profile,top").split(",")
COL = json.load(open(HD + "/colors.json"))
RD = HD + "/v"; os.makedirs(RD, exist_ok=True)
CREWTEX = ROOT + "Assets/blender/character/AST-053_CrewTex.blend"
def lin(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
def aim(o, d):
    o.rotation_euler = Vector(d).normalized().to_track_quat("Z", "Y").to_euler()
def run(an):
    bpy.ops.wm.open_mainfile(filepath=SRC + f"/AST-053_Animal_{an}.blend")
    OB = bpy.data.objects
    for im in bpy.data.images:
        if im.filepath.startswith("//"):
            im.filepath = os.path.normpath(os.path.join(ROOT + "Assets/blender/character", im.filepath[2:]))
        p = im.filepath
        if TEXDIR and p:
            b = os.path.basename(p)
            alt = os.path.join(TEXDIR, "face", b) if b.startswith("T_Expr") else os.path.join(TEXDIR, b)
            if os.path.exists(alt):
                im.filepath = alt
        im.reload()
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
    scn.render.resolution_x = scn.render.resolution_y = 560
    tgt = Vector((0, 0.25, 4.85))
    D = {"front": (0, 1, 0), "34": (math.sin(math.radians(45)), math.cos(math.radians(45)), 0),
         "profile": (math.sin(math.radians(85)), math.cos(math.radians(85)), 0),
         "top": (math.sin(math.radians(25)) * math.cos(math.radians(30)), math.cos(math.radians(25)) * math.cos(math.radians(30)), math.sin(math.radians(30)))}
    for v in VIEWS:
        dv = Vector(D[v]).normalized()
        cam.location = tgt + dv * 7.0
        cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
        aim(L["Key"], dv * 1.4 + Vector((0.6, 0, 0.55)))
        aim(L["Fill"], Vector((-dv.x, -dv.y * 0.3, 0.4)) + Vector((-0.6, 0.2, 0)))
        aim(L["Rim"], Vector((-dv.x * 0.5, -1, 0.7)))
        scn.render.filepath = RD + f"/{TAG}_{an}_{v}.png"
        bpy.ops.render.render(write_still=True)
    print("VIEWS", an, TAG, flush=True)
for an in (ONLY or ORDER):
    run(an)
