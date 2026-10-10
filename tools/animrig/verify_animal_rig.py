# AST-069 AnimalRig verification (never saves): pivots vs game Motor6D, test pose, joint separation, renders.
#   ROOT="<project>/" [RENDER=0] [TORSO=1] [SPECIES_SHOTS=1] blender -b Assets/blender/character/AST-069_AnimalRig.blend \
#       --factory-startup --python tools/animrig/verify_animal_rig.py
# AST-069 verification: pivots vs game Motor6D, test pose, joint separation, renders. Never saves the blend.
import bpy, os, json, math, bmesh
from mathutils import Vector, Matrix

ROOT = os.environ["ROOT"]
RD = ROOT + "Assets/reference/rig/"
os.makedirs(RD, exist_ok=True)
RENDER = os.environ.get("RENDER", "1") == "1"
D = bpy.data
scn = bpy.context.scene
PA, IA, BODY = D.objects["__PrimaryArmature"], D.objects["InternalArmature"], D.objects["Body"]
jbase = json.load(open(ROOT + "Assets/blender/character/AST-053_CrewBase_joints.json"))
janim = json.load(open(ROOT + "Assets/blender/character/AST-053_Animals_joints.json"))["animals"]


def upd():
    for o in (BODY, D.objects["Right Arm"], D.objects["Head"], D.objects["Left Leg"], PA, IA):
        o.update_tag()
    scn.frame_set(scn.frame_current)
    bpy.context.view_layer.update()


def rbx(v):  # Blender (x right, +y front, z up) -> Roblox (x right, y up, -z front)
    return Vector((v.x, v.z, -v.y))


# ---------------------------------------------------------------- drivers health
bad = []
for idb in list(D.objects) + [m.node_tree for m in D.materials if m.node_tree]:
    ad = getattr(idb, "animation_data", None)
    if not ad:
        continue
    for d in ad.drivers:
        if not d.driver.is_valid or (d.driver.type == "SCRIPTED" and not d.driver.is_simple_expression):
            bad.append((idb.name, d.data_path, d.driver.type, d.driver.expression, d.driver.is_valid))
print("DRIVERS primary:", len(PA.animation_data.drivers), "invalid/non-simple:", len(bad))
for b in bad:
    print("  BADDRV", b)
print("TEXTS", [t.name for t in D.texts])
print("IMAGES", [(i.name, i.filepath, i.packed_file is not None, os.path.exists(bpy.path.abspath(i.filepath)) if i.filepath else None) for i in D.images])
print("BONES IA", [b.name for b in IA.data.bones])

# ---------------------------------------------------------------- pivots vs Motor6D (stock C0 + rest-pose C1)
upd()
parts_center = {k: Vector(v["center_world"]) for k, v in jbase["parts"].items()}
parts_center["Head"] = Vector(janim["Dog"]["head"]["center_world"])
JOINTS = {"RootJoint": ("HumanoidRootPart", "Torso"), "Neck": ("Torso", "Head"), "Right Shoulder": ("Torso", "Right Arm"),
          "Left Shoulder": ("Torso", "Left Arm"), "Right Hip": ("Torso", "Right Leg"), "Left Hip": ("Torso", "Left Leg")}
worst = 0
pivot_rbx = {}
for jn, (p0, p1) in JOINTS.items():
    c0 = jbase["motor6d"][jn]["C0"]
    piv = parts_center[p0] + Vector(c0[:3])  # Part0 has identity rotation at rest
    pivot_rbx[jn] = piv
    bh = rbx(IA.matrix_world @ IA.data.bones[p1].head_local)
    e = (bh - piv).length
    worst = max(worst, e)
    print(f"PIVOT {jn:15s} motor6d={tuple(round(x,3) for x in piv)} bone[{p1}]={tuple(round(x,3) for x in bh)} err={e:.4f}")
bh = rbx(IA.matrix_world @ IA.data.bones["HumanoidRootPart"].head_local)
e = (bh - parts_center["HumanoidRootPart"]).length; worst = max(worst, e)
print(f"PIVOT HumanoidRootPart centre={tuple(parts_center['HumanoidRootPart'])} bone={tuple(round(x,3) for x in bh)} err={e:.4f}")
print(f"PIVOT_WORST {worst:.4f} (tol 0.02)")

# part centres (MeshPart CFrame = bbox centre): proves the rest pose gives the same C1 as the game
MESH_OF = {"Torso": "Torso_Crew", "Left Arm": "Left Arm_Crew", "Right Arm": "Right Arm_Crew", "Left Leg": "Left Leg_Crew",
           "Right Leg": "Right Leg_Crew", "Head": "Head_Dog"}


def bbox_c(o):
    bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
    return Vector([(min(v[i] for v in bb) + max(v[i] for v in bb)) / 2 for i in range(3)])


for part, mn in MESH_OF.items():
    c = rbx(bbox_c(D.objects[mn])); e = (c - parts_center[part]).length
    print(f"CENTRE {part:10s} mesh={tuple(round(x,3) for x in c)} game={tuple(round(x,3) for x in parts_center[part])} err={e:.4f}")
    worst = max(worst, e)
print(f"CENTRE_WORST {worst:.4f}")

# ---------------------------------------------------------------- species switch check
vis = lambda: sorted(o.name for o in D.objects if o.type == "MESH" and not o.evaluated_get(bpy.context.evaluated_depsgraph_get()).hide_render and any(c.name.startswith(("Species_", "CrewBody")) for c in o.users_collection))
print("VISIBLE default:", vis())
for s in (1, 6, 7):
    BODY["Species"] = s; upd()
    print(f"VISIBLE Species={s}:", vis())
BODY["Species"] = 0; upd()

# ---------------------------------------------------------------- test pose
# the file keeps CommunityR6's rest keys at frame 0 (ArmatureAction); pose on top of them = new keys, here just unassign it
PA.animation_data.action = None
upd()
rest = {o.name: o.matrix_world.copy() for o in D.objects if o.type == "MESH" and o.constraints}
D.objects["Right Arm"]["IK/FK"] = 1.0
D.objects["Right Arm"]["Grab"] = 1.0
D.objects["Head"]["Track Object"] = 1.0
upd()


def set_world(bn, loc):
    pb = PA.pose.bones[bn]
    m = pb.matrix.copy()
    m.translation = PA.matrix_world.inverted() @ Vector(loc)
    pb.matrix = m
    upd()


GRAB = (1.15, 1.55, 3.05)            # in front of the right shoulder, a bit below it
set_world("RightArm_GrabPoint", GRAB)
ll = PA.pose.bones["LeftLeg-IK"]
set_world("LeftLeg-IK", (PA.matrix_world @ ll.head) + Vector((0, 0.75, 0.9)))   # knee up
set_world("LookToPoint", (3.5, 3.0, 4.6))                                       # look to the right/front
if os.environ.get("TORSO") == "1":   # extra stress: lean the upper torso forward/right
    ut = PA.pose.bones["UpperTorso-IKTarget"]
    set_world("UpperTorso-IKTarget", (PA.matrix_world @ ut.head) + Vector((0.35, 0.6, -0.1)))
    set_world("LowerTorso-FK", (PA.matrix_world @ PA.pose.bones["LowerTorso-FK"].head) + Vector((0, 0, -0.4)))
upd()

sep_worst = 0
MESH_P = {"HumanoidRootPart": None, "Torso": "Torso_Crew", "Head": "Head_Dog", "Right Arm": "Right Arm_Crew",
          "Left Arm": "Left Arm_Crew", "Right Leg": "Right Leg_Crew", "Left Leg": "Left Leg_Crew"}
for jn, (p0, p1) in JOINTS.items():
    if MESH_P[p0] is None:
        continue
    piv = Vector((pivot_rbx[jn].x, -pivot_rbx[jn].z, pivot_rbx[jn].y))  # back to Blender
    o0, o1 = D.objects[MESH_P[p0]], D.objects[MESH_P[p1]]
    a = o0.matrix_world @ rest[o0.name].inverted() @ piv
    b = o1.matrix_world @ rest[o1.name].inverted() @ piv
    sep = (a - b).length; sep_worst = max(sep_worst, sep)
    ang = (o1.matrix_world.to_quaternion().rotation_difference(rest[o1.name].to_quaternion())).angle
    print(f"JOINT {jn:15s} separation={sep:.4f} part1 rotated {math.degrees(ang):6.1f} deg")
print(f"SEPARATION_WORST {sep_worst:.4f}")
# accessories ride their bone rigidly
for n, base in (("Ears_Dog", "Head_Dog"), ("Face_Dog", "Head_Dog"), ("Cap_Crew", "Head_Dog"), ("Tail_Dog", "Torso_Crew"), ("Apron_Crew", "Torso_Crew")):
    o, bo = D.objects[n], D.objects[base]
    rel_rest = rest[bo.name].inverted() @ rest[o.name]
    rel_now = bo.matrix_world.inverted() @ o.matrix_world
    dm = max(abs(x) for r in (rel_now - rel_rest) for x in r)
    print(f"RIGID {n:10s} on {base}: drift={dm:.5f}")
# hand reached the grab point?  bottom centre of the arm (RightGripAttachment)
arm = D.objects["Right Arm_Crew"]
grip_rest = Vector((1.5, 0, 2.0))
grip = arm.matrix_world @ rest[arm.name].inverted() @ grip_rest
print(f"GRIP hand={tuple(round(x,3) for x in grip)} target={GRAB} dist={(grip - Vector(GRAB)).length:.3f}")
head = D.objects["Head_Dog"]
fwd = (head.matrix_world.to_3x3() @ rest[head.name].to_3x3().inverted()) @ Vector((0, 1, 0))
print(f"HEAD forward now={tuple(round(x,3) for x in fwd)} (yaw {math.degrees(math.atan2(fwd.x, fwd.y)):.1f} deg, pitch {math.degrees(math.asin(max(-1,min(1,fwd.z)))):.1f})")

# ---------------------------------------------------------------- renders
if RENDER:
    try:
        scn.render.engine = "BLENDER_EEVEE"
    except TypeError:
        scn.render.engine = "BLENDER_EEVEE_NEXT"
    scn.view_settings.view_transform = "Standard"
    scn.world = scn.world or D.worlds.new("W")
    scn.world.use_nodes = True
    bg = next(n for n in scn.world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.42, 0.55, 0.72, 1); bg.inputs[1].default_value = 0.9
    L = {}
    for nm, e, c in (("Key", 3.2, (1, .95, .86)), ("Fill", 0.9, (.75, .85, 1)), ("Rim", 0.6, (1, 1, 1))):
        o = D.objects.new("V_" + nm, D.lights.new(nm, "SUN")); scn.collection.objects.link(o)
        o.data.energy = e; o.data.color = c; L[nm] = o
    bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=12)
    gme = D.meshes.new("Ground"); bm.to_mesh(gme); bm.free()
    gnd = D.objects.new("V_Ground", gme); scn.collection.objects.link(gnd)
    gm = D.materials.new("G"); gm.use_nodes = True
    next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.32, 0.30, 0.27, 1)
    gme.materials.append(gm)
    # grab target marker (small red sphere)
    bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=0.12)
    sme = D.meshes.new("Mk"); bm.to_mesh(sme); bm.free()
    mk = D.objects.new("V_GrabMarker", sme); scn.collection.objects.link(mk); mk.location = GRAB
    mm = D.materials.new("Mk"); mm.use_nodes = True
    next(n for n in mm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.9, 0.05, 0.05, 1)
    sme.materials.append(mm)
    mk2 = D.objects.new("V_LookMarker", sme); scn.collection.objects.link(mk2); mk2.location = (3.5, 3.0, 4.6)
    cam = D.objects.new("V_Cam", D.cameras.new("V_Cam")); scn.collection.objects.link(cam)
    scn.camera = cam; cam.data.lens = 50
    for o in D.objects:  # hide the CommunityR6 camera / helpers from renders
        if o.type in ("CAMERA",) and o is not cam:
            o.hide_render = True

    def aim(o, d):
        o.rotation_euler = Vector(d).normalized().to_track_quat("Z", "Y").to_euler()

    def shoot(d, tgt, dist, name, res=(800, 900)):
        scn.render.resolution_x, scn.render.resolution_y = res
        dv = Vector(d).normalized(); tgt = Vector(tgt)
        cam.location = tgt + dv * dist
        cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
        aim(L["Key"], dv * 1.4 + Vector((0.6, 0, 0.55)))
        aim(L["Fill"], Vector((-dv.x, -dv.y * 0.3, 0.4)) + Vector((-0.6, 0.2, 0)))
        aim(L["Rim"], Vector((-dv.x * 0.5, -1, 0.7)))
        scn.render.filepath = RD + name
        bpy.ops.render.render(write_still=True)
        print("RENDER", RD + name)

    shoot((0.75, 1, 0.3), (0.6, 0.5, 3.0), 15.5, "AST-069_pose_34.png")
    shoot((0, 1, 0.1), (0.4, 0.5, 3.0), 15.5, "AST-069_pose_front.png")
    shoot((1, 0.02, 0.12), (0, 0.5, 3.0), 15.5, "AST-069_pose_side.png")
    shoot((-0.3, 1, 0.9), (0.6, 0.6, 3.6), 9.0, "AST-069_pose_top.png")
    if os.environ.get("SPECIES_SHOTS") == "1":
        mk.hide_render = mk2.hide_render = True
        # back to rest for the species shots
        for pb in PA.pose.bones:
            pb.matrix_basis = Matrix.Identity(4)
        D.objects["Right Arm"]["IK/FK"] = 0.0; D.objects["Right Arm"]["Grab"] = 0.0; D.objects["Head"]["Track Object"] = 0.0
        for s, a in ((0, "Dog"), (1, "Cat"), (6, "Turtle"), (7, "Owl")):
            BODY["Species"] = s; upd()
            shoot((0.6, 1, 0.2), (0, 0, 3.1), 14.5, f"AST-069_rest_{a}.png", (600, 800))
print("VERIFY DONE")
