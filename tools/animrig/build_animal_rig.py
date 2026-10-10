# AST-069 AnimalRig builder. Rebuilds Assets/blender/character/AST-069_AnimalRig.blend from a COPY of CommunityR6.blend
# (the user's reference rig, never edit the original). Re-run when a species is added (edit SPECIES below).
#   cp "C:/Users/hakor/Documents/Rigs/CommunityR6.blend" <tmp>/copy.blend
#   ROOT="<project>/" blender -b <tmp>/copy.blend --factory-startup --python tools/animrig/build_animal_rig.py
# (on Windows use the WMI-safe wrapper of the roblox-cartoon-animal-char skill: PYTHONPATH=<skill>/scripts/nowmi)
# Then check with tools/animrig/verify_animal_rig.py (renders into Assets/reference/rig/).
# AST-069 AnimalRig: CommunityR6 copy -> HotDog Crew animal rig.
# Run on a COPY of CommunityR6.blend:  blender -b <copy> --python build.py
# Env: ROOT = project root (with trailing slash)
import bpy, os, re, json
from mathutils import Matrix, Vector

ROOT = os.environ["ROOT"]
CH = ROOT + "Assets/blender/character/"
OUT = CH + "AST-069_AnimalRig.blend"

# ---------------------------------------------------------------- species table (order = Species index)
SPECIES = ["Dog", "Cat", "Rabbit", "Fox", "Bear", "Panda", "Turtle", "Owl", "Lion", "Penguin", "Hamster", "Mouse",
           "Frog", "Monkey", "Sheep", "Koala", "Pig", "Raccoon"]
looks = open(ROOT + "src/Crew/shared/CrewLooks.luau", encoding="utf-8").read()
FUR, EARSUP = {}, {}
for m in re.finditer(r"\n\t\t(\w+) = \{ -- (\w+):.*?Fur = Color3\.fromHex\(\"(\w{6})\"\),\s*EarsUp = (true|false)", looks, re.S):
    FUR[m.group(2)] = m.group(3)
    EARSUP[m.group(2)] = m.group(4) == "true"
missing = [a for a in SPECIES if a not in FUR or not os.path.exists(CH + f"AST-053_Animal_{a}.blend")]
assert not missing, missing
PLAIN_CAP = [i for i, a in enumerate(SPECIES) if not EARSUP[a]]
print("SPECIES", list(enumerate(SPECIES)), "plain cap:", PLAIN_CAP)

# save first at the destination so appended relative paths stay valid
bpy.ops.wm.save_as_mainfile(filepath=OUT, relative_remap=True)

D = bpy.data
scn = bpy.context.scene
PA = D.objects["__PrimaryArmature"]
IA = D.objects["InternalArmature"]
BODYSET = D.objects["Body"]

# ---------------------------------------------------------------- 1. remove the generic Roblox body meshes
bt = D.collections["BodyTypes"]
for c in [bt] + list(bt.children_recursive):
    for o in list(c.objects):
        me = o.data
        D.objects.remove(o, do_unlink=True)
        if me and me.users == 0:
            D.meshes.remove(me)
for c in list(bt.children_recursive) + [bt]:
    D.collections.remove(c)
for k in ("BodyType", "Feminine"):
    if k in BODYSET:
        del BODYSET[k]
for a in list(D.actions):
    if a.users == 0:
        D.actions.remove(a)

# ---------------------------------------------------------------- 2. settings on the "Body" settings object
BODYSET["Species"] = SPECIES.index("Dog")
ui = BODYSET.id_properties_ui("Species")
ui.update(min=0, max=len(SPECIES) - 1, soft_min=0, soft_max=len(SPECIES) - 1,
          description=", ".join(f"{i} {a}" for i, a in enumerate(SPECIES)))
BODYSET["Cap"] = True
BODYSET.id_properties_ui("Cap").update(description="Crew cap (ears-up species get the cap with ear holes)")
BODYSET["Apron"] = True
BODYSET.id_properties_ui("Apron").update(description="Crew apron")

rig_col = D.collections["Rig1"]
char = D.collections.new("Character")
rig_col.children.link(char)
body_col = D.collections.new("CrewBody")
char.children.link(body_col)
sp_root = D.collections.new("Species")
char.children.link(sp_root)


def ensure_rest():
    bpy.context.view_layer.update()


def child_of(o, bone):
    """Rigid part on an InternalArmature bone, same mechanism as the CommunityR6 meshes."""
    for c in list(o.constraints):
        o.constraints.remove(c)
    con = o.constraints.new("CHILD_OF")
    con.name = "Child Of"
    con.target = IA
    con.subtarget = bone
    pb = IA.pose.bones[bone]
    con.inverse_matrix = (IA.matrix_world @ pb.matrix).inverted()
    return con


def vis_driver(o, expr, use_cap=False, use_apron=False):
    for path in ("hide_viewport", "hide_render"):
        o.driver_remove(path)
        fc = o.driver_add(path)
        d = fc.driver
        d.type = "SCRIPTED"
        for name, prop in (("s", "Species"), ("cap", "Cap"), ("apron", "Apron")):
            if name == "cap" and not use_cap:
                continue
            if name == "apron" and not use_apron:
                continue
            v = d.variables.new()
            v.name = name
            v.type = "SINGLE_PROP"
            v.targets[0].id_type = "OBJECT"
            v.targets[0].id = BODYSET
            v.targets[0].data_path = f'["{prop}"]'
        d.expression = expr
        assert d.is_simple_expression, (o.name, expr)


def append(path, names):
    with D.libraries.load(path, link=False) as (src, dst):
        dst.objects = [n for n in names if n in src.objects]
    return [o for o in dst.objects if o is not None]


ensure_rest()
# sanity: the internal armature is in its rest pose
for pb in IA.pose.bones:
    dm = (pb.matrix - pb.bone.matrix_local)
    err = max(abs(x) for r in dm for x in r)
    print("REST", pb.name, round(err, 5))

# ---------------------------------------------------------------- 3. crew body (common to every species)
BONE_OF = {"Torso": "Torso", "Left Arm": "Left Arm", "Right Arm": "Right Arm", "Left Leg": "Left Leg",
           "Right Leg": "Right Leg", "Apron": "Torso", "Cap": "Head", "Cap_EarsUp": "Head"}
CAP_RAISE = 0.30
crew = append(CH + "AST-053_CrewTex.blend", ["Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "Apron", "Cap"])
crew += append(CH + "AST-053_CrewCap_EarsUp.blend", ["Cap_EarsUp"])
for o in crew:
    src = o.name.split(".")[0]
    bone = BONE_OF[src]
    o.name = f"{src}_Crew"
    o.data.name = f"{src}_Crew"
    body_col.objects.link(o)
    o.parent = None
    if src.startswith("Cap"):
        o.location.z += CAP_RAISE  # round heads (DEC-152): cap rides +0.30 on HatAttachment, as CrewRig does
    ensure_rest()
    child_of(o, bone)
    if src == "Cap":
        vis_driver(o, "not cap or (" + " and ".join(f"s != {i}" for i in PLAIN_CAP) + ")", use_cap=True)
    elif src == "Cap_EarsUp":
        vis_driver(o, "not cap or not (" + " and ".join(f"s != {i}" for i in PLAIN_CAP) + ")", use_cap=True)
    elif src == "Apron":
        vis_driver(o, "not apron", use_apron=True)
    print("BODY", o.name, "->", bone)

# hands = fur colour of the species (CrewLooks.Fur): constant ColorRamp indexed by Species (simple driver, no Python)
W = len(SPECIES)


def lin(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


mo = D.materials["M_CrewOutfit"]
nt = mo.node_tree
fur = nt.nodes.get("Fur")
print("OUTFIT NODES", [(n.name, n.type) for n in nt.nodes])
val = nt.nodes.new("ShaderNodeValue"); val.name = "SpeciesU"; val.label = "Species -> ramp (driver)"
fc = val.outputs[0].driver_add("default_value")
v = fc.driver.variables.new(); v.name = "s"; v.type = "SINGLE_PROP"
v.targets[0].id_type = "OBJECT"; v.targets[0].id = BODYSET; v.targets[0].data_path = '["Species"]'
fc.driver.expression = f"(s + 0.5) / {W}"
assert fc.driver.is_simple_expression
ramp = nt.nodes.new("ShaderNodeValToRGB"); ramp.name = "FurPerSpecies"; ramp.label = "Fur per species (CrewLooks.Fur)"
cr = ramp.color_ramp
cr.interpolation = "CONSTANT"
while len(cr.elements) < W:
    cr.elements.new(0.5)
for i, a in enumerate(SPECIES):
    h = FUR[a]
    cr.elements[i].position = i / W
    cr.elements[i].color = (lin(int(h[0:2], 16)), lin(int(h[2:4], 16)), lin(int(h[4:6], 16)), 1.0)
nt.links.new(val.outputs[0], ramp.inputs["Fac"])
if fur is not None:
    for l in list(fur.outputs[0].links):
        nt.links.new(ramp.outputs["Color"], l.to_socket)
    fur.label = "Fur (unused: FurPerSpecies drives it)"
else:
    print("WARN no Fur node in M_CrewOutfit")

# ---------------------------------------------------------------- 4. species pieces (head, face shell, ears, tail, extras)
TORSO_PIECES = ("Tail_", "Shell_")
tris = {}
for i, a in enumerate(SPECIES):
    path = CH + f"AST-053_Animal_{a}.blend"
    with D.libraries.load(path) as (src, _):
        names = [n for n in src.objects if not n.startswith("REF_")]
    objs = [o for o in append(path, names) if o.type == "MESH"]
    # empties (attachments) come along only if named: drop any that slipped in
    col = D.collections.new(f"Species_{a}")
    sp_root.children.link(col)
    n = 0
    for o in objs:
        o.parent = None
        col.objects.link(o)
        bone = "Torso" if o.name.startswith(TORSO_PIECES) else "Head"
        ensure_rest()
        child_of(o, bone)
        vis_driver(o, f"s != {i}")
        n += sum(len(p.vertices) - 2 for p in o.data.polygons)
    tris[a] = n
    print("SPECIES", i, a, [o.name for o in objs], n)
for o in list(D.objects):
    if o.type == "EMPTY" and len(o.users_collection) == 0:
        D.objects.remove(o)

# ---------------------------------------------------------------- 5. control tweaks for the bigger head
pb_head = PA.pose.bones["Head"]
shape = pb_head.custom_shape
if shape is not None:
    vs = [Vector(v.co) for v in shape.data.vertices]
    print("HEADSHAPE", shape.name, [round(min(v[k] for v in vs), 3) for k in range(3)], [round(max(v[k] for v in vs), 3) for k in range(3)],
          tuple(pb_head.custom_shape_scale_xyz), tuple(pb_head.custom_shape_translation), pb_head.bone.length)

# Head control circle: the round head (2.84 x 2.05, cap on top) hides the R6-sized circle -> wider and above the cap
pb_head.custom_shape_scale_xyz = (1.45, 1.0, 1.45)
pb_head.custom_shape_translation = (pb_head.custom_shape_translation[0], 1.45, pb_head.custom_shape_translation[2])

# ---------------------------------------------------------------- 6. rigid R6 limbs pinned to their joint in IK mode
# CommunityR6 places the rigid limb on the IK forearm/shin (chain with clavicle), so in IK the block translates away
# from the R6 pivot (measured 0.30 stud at the shoulder, 1.09 at the hip). For our joints (Motor6D rotation only) the
# limb now rotates about the R6 pivot and aims at the IK control. "Pin Joint" = 0 restores the original behaviour.
bpy.context.view_layer.objects.active = PA
PA.hide_set(False)
PA.select_set(True)
OFF = PA.matrix_world.inverted()
LIMBS = {  # settings object, positioner, IK control, R6 pivot (Blender world)
    "Right Arm": ("RightArm_Positioner", "RightArm-IK", Vector((1, 0, 3.5))),
    "Left Arm": ("LeftArm_Positioner", "LeftArm-IK", Vector((-1, 0, 3.5))),
    "Right Leg": ("RightLeg_Positioner", "RightLeg-IK", Vector((1, 0, 2.0))),
    "Left Leg": ("LeftLeg_Positioner", "LeftLeg-IK", Vector((-1, 0, 2.0))),
}
# LookToPoint: level with the neck pivot (Track To aims the head -Z from the pivot; the original sat 2 studs low)
bpy.ops.object.mode_set(mode="EDIT")
eb = PA.data.edit_bones
lk = eb["LookToPoint"]
dz = (OFF @ Vector((0, 0, 4.0))).z - lk.head.z
lk.head.z += dz; lk.tail.z += dz
for side, (posn, ik, piv) in LIMBS.items():
    nm = posn.replace("_Positioner", "_PinAim")
    b = eb.get(nm) or eb.new(nm)
    b.head = OFF @ piv
    b.tail = eb[ik].head.copy()       # rest: aim already points at the IK control -> zero rotation at rest
    b.parent = eb["PrimaryTorso_Positioner"]
    b.use_connect = False
    b.use_deform = False
    b.roll = 0
bpy.ops.object.mode_set(mode="OBJECT")
for side, (posn, ik, piv) in LIMBS.items():
    nm = posn.replace("_Positioner", "_PinAim")
    PA.data.bones[nm].hide = True
    pb = PA.pose.bones[nm]
    for c in list(pb.constraints):
        pb.constraints.remove(c)
    dt = pb.constraints.new("DAMPED_TRACK"); dt.name = "AimAtIK"
    dt.target = PA; dt.subtarget = ik; dt.track_axis = "TRACK_Y"
    setobj = D.objects[side]
    setobj["Pin Joint"] = 1.0
    setobj.id_properties_ui("Pin Joint").update(min=0.0, max=1.0, soft_min=0.0, soft_max=1.0,
        description="IK: 1 = rigid R6 limb rotates about its joint and aims at the IK control (no gap); 0 = original CommunityR6 (limb follows the IK forearm/shin)")
    pp = PA.pose.bones[posn]
    ik_con = next(c for c in pp.constraints if c.type == "CHILD_OF" and c.subtarget.endswith(("LowerArm", "LowerLeg")))
    con = pp.constraints.get("PinAim") or pp.constraints.new("CHILD_OF")
    con.name = "PinAim"; con.target = PA; con.subtarget = nm
    con.set_inverse_pending = True   # solved at rest below
    for c, expr in ((ik_con, "ik * (1 - pin)"), (con, "ik * pin")):
        dp = f'pose.bones["{posn}"].constraints["{c.name}"].influence'
        PA.driver_remove(dp)
        fc = PA.driver_add(dp)
        for mod in list(fc.modifiers):
            fc.modifiers.remove(mod)
        d = fc.driver; d.type = "SCRIPTED"
        for vn, prop in (("ik", "IK/FK"), ("pin", "Pin Joint")):
            v = d.variables.new(); v.name = vn; v.type = "SINGLE_PROP"
            v.targets[0].id_type = "OBJECT"; v.targets[0].id = setobj; v.targets[0].data_path = f'["{prop}"]'
        d.expression = expr
        assert d.is_simple_expression
    print("PIN", side, nm, "ik con", ik_con.name)

# solve the pending inverses at rest with every limb temporarily in IK + pinned (influence 1)
saved = {side: D.objects[side]["IK/FK"] for side in LIMBS}
for side in LIMBS:
    D.objects[side]["IK/FK"] = 1.0
    D.objects[side].update_tag()
PA.update_tag()
scn.frame_set(scn.frame_current); bpy.context.view_layer.update()
scn.frame_set(scn.frame_current); bpy.context.view_layer.update()
for side, v in saved.items():
    D.objects[side]["IK/FK"] = v
    D.objects[side].update_tag()
scn.frame_set(scn.frame_current); bpy.context.view_layer.update()
for side, (posn, ik, piv) in LIMBS.items():
    c = PA.pose.bones[posn].constraints["PinAim"]
    print("PININV", side, c.set_inverse_pending, [round(x, 3) for x in c.inverse_matrix.translation])

# ---------------------------------------------------------------- 7. one image datablock per file (appends duplicated them)
by_path = {}
for im in list(D.images):
    if not im.filepath or im.packed_file:
        continue
    key = os.path.normcase(os.path.abspath(bpy.path.abspath(im.filepath)))
    if key in by_path:
        im.user_remap(by_path[key]); D.images.remove(im)
    else:
        by_path[key] = im
for im in list(D.images):
    if im.users == 0:
        D.images.remove(im)

# small text block in the blend with the species indices
t = D.texts.get("AnimalRig_README.txt") or D.texts.new("AnimalRig_README.txt")
t.from_string("AST-069 AnimalRig (Sell Hotdogs) - see Assets/blender/character/AST-069_AnimalRig.md\n"
              "Species switch: R6 Rig panel > Rig Settings > Body > Species\n" +
              "\n".join(f"  {i:2d} = {a}" for i, a in enumerate(SPECIES)) +
              "\nCap / Apron toggles on the same Body settings object.\n"
              "Animation bones = InternalArmature (HumanoidRootPart, Torso, Head, Left/Right Arm, Left/Right Leg).\n")

json.dump({"species": SPECIES, "tris": tris, "plain_cap": PLAIN_CAP}, open(os.environ.get("INFO", os.devnull), "w"))
bpy.ops.file.make_paths_relative()
bpy.ops.wm.save_mainfile()
print("SAVED", OUT)
