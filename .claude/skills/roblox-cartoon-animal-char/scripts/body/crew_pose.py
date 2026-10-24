# Render AST-053 CrewBase: turnaround + test poses (rotating parts about their joint origins) + penetration report.
import sys, os, math, json
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from charlib import *
from mathutils.bvhtree import BVHTree

bpy.ops.wm.open_mainfile(filepath=ROOT + "Assets/blender/character/AST-053_CrewBase.blend")
scn = bpy.context.scene
OB = bpy.data.objects
NAMES = ["Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "Cap", "Apron"]
REST = {n: OB[n].matrix_world.copy() for n in NAMES}
for o in OB:
    if o.type == "EMPTY":
        o.hide_render = True

# hot dog prop for the holding pose (AST-003)
with bpy.data.libraries.load(ROOT + "Assets/blender/food/AST-003_HotDog.blend") as (src, dst):
    dst.objects = [n for n in src.objects if n in ("Handle", "Sausage")]
for o in dst.objects:
    scn.collection.objects.link(o)
hd = OB["Handle"]
hd.hide_render = True; OB["Sausage"].hide_render = True

# ground plane
bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=8)
gme = bpy.data.meshes.new("Ground"); bm.to_mesh(gme); bm.free()
gnd = bpy.data.objects.new("Ground", gme); scn.collection.objects.link(gnd)
gm = bpy.data.materials.new("G"); gm.use_nodes = True
next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.25, 0.27, 0.32, 1)
gme.materials.append(gm)
gnd.location.z = -0.001


def reset():
    for n in NAMES:
        OB[n].matrix_world = REST[n]
    hd.hide_render = True; OB["Sausage"].hide_render = True
    bpy.context.view_layer.update()


def rot(name, R, carry=()):
    o = OB[name]
    p = o.matrix_world.translation.copy()
    M = Matrix.Translation(p) @ R.to_4x4() @ Matrix.Translation(-p)
    for x in (o,) + tuple(OB[c] for c in carry):
        x.matrix_world = M @ x.matrix_world


def Rx(d): return Matrix.Rotation(math.radians(d), 3, "X")
def Ry(d): return Matrix.Rotation(math.radians(d), 3, "Y")
def Rz(d): return Matrix.Rotation(math.radians(d), 3, "Z")


def pen_report(tag, extra=()):
    """Triangle-pair overlaps between parts in the current pose."""
    bpy.context.view_layer.update()
    objs = [OB[n] for n in NAMES] + list(extra)
    trees = {}
    for o in objs:
        me = o.data
        vs = [o.matrix_world @ v.co for v in me.vertices]
        trees[o.name] = BVHTree.FromPolygons(vs, [p.vertices[:] for p in me.polygons])
    res = {}
    for i in range(len(objs)):
        for j in range(i + 1, len(objs)):
            k = len(trees[objs[i].name].overlap(trees[objs[j].name]))
            if k:
                res[f"{objs[i].name} x {objs[j].name}"] = k
    print("PEN", tag, res)
    return res


def render(base, views, target, dist, res=(600, 800), lens=50):
    cam = bpy.data.objects.new("PrevCam", bpy.data.cameras.new("PrevCam")); scn.collection.objects.link(cam)
    key = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "SUN")); scn.collection.objects.link(key)
    fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "SUN")); scn.collection.objects.link(fill)
    scn.camera = cam; cam.data.lens = lens
    scn.render.resolution_x, scn.render.resolution_y = res
    if scn.world is None:
        scn.world = bpy.data.worlds.new("W")
    scn.world.color = (0.55, 0.6, 0.66)
    for suffix, d in views:
        tgt = Vector(target); dv = Vector(d).normalized(); loc = tgt + dv * dist
        key.data.energy = 3.0; fill.data.energy = 1.0
        key.rotation_euler = (dv + Vector((0.35, 0, 0.7))).normalized().to_track_quat("Z", "Y").to_euler()
        fill.rotation_euler = (Vector((-dv.x, -dv.y, 0.5))).normalized().to_track_quat("Z", "Y").to_euler()
        cam.location = loc
        cam.rotation_euler = (tgt - loc).to_track_quat("-Z", "Y").to_euler()
        scn.render.filepath = SP + f"/previews/{base}{suffix}.png"
        bpy.ops.render.render(write_still=True)
    for o in (cam, key, fill):
        bpy.data.objects.remove(o, do_unlink=True)


reset()
rest_pen = pen_report("rest")
render("AST-053_CrewBase", [("_front", (0, 1, 0.12)), ("_side", (1, 0, 0.12)), ("_back", (0, -1, 0.12)),
                            ("_34", (0.8, 1, 0.45))], (0, 0, 2.9), 13.5, res=(600, 800), lens=50)

# --- pose 1: waving (right arm up/out, head tilt, small weight shift)
reset()
rot("Right Arm", Ry(28) @ Rx(168))
rot("Left Arm", Rx(-8))
rot("Head", Ry(-6), carry=("Cap",))
wave_pen = pen_report("wave")
render("AST-053_CrewBase_wave", [("", (0.55, 1, 0.3)), ("_back", (0.4, -1, 0.5))], (0, 0, 3.4), 13.5, res=(600, 800))
render("AST-053_CrewBase_wave_close", [("", (1, 0.7, 0.4))], (1.2, 0, 4.4), 5.5, res=(700, 700))

# --- pose 2: holding a hot dog in the right hand (tool-hold arm forward)
reset()
rot("Right Arm", Rx(90))
rot("Left Arm", Rx(12))
rot("Right Leg", Rx(-10)); rot("Left Leg", Rx(10))
hd.hide_render = False; OB["Sausage"].hide_render = False
hd.matrix_world = Matrix.Translation((1.5, 1.22, 3.89)) @ Rz(0).to_4x4()
hold_pen = pen_report("hotdog", extra=(hd,))
render("AST-053_CrewBase_hotdog", [("", (0.9, 1, 0.35)), ("_side", (1, 0.15, 0.2))], (0.4, 0.3, 3.2), 13.5, res=(600, 800))
render("AST-053_CrewBase_hotdog_close", [("", (0.6, 1, 0.5))], (1.4, 0.8, 3.8), 5.0, res=(700, 700))

# --- extra: running extreme (R6 run swing ~45 deg) to check apron vs legs
reset()
rot("Right Leg", Rx(45)); rot("Left Leg", Rx(-45))
rot("Right Arm", Rx(-45)); rot("Left Arm", Rx(45))
run_pen = pen_report("run45")
render("AST-053_CrewBase_run", [("", (1, 0.35, 0.15)), ("_front", (0.3, 1, 0.1))], (0, 0, 2.6), 13.5, res=(600, 800))
render("AST-053_CrewBase_run_close", [("", (1, 0.8, -0.1))], (0.4, 0.4, 2.1), 5.0, res=(700, 700))
reset()
json.dump({"rest": rest_pen, "wave": wave_pen, "hotdog": hold_pen, "run45": run_pen}, open(SP + "/crew/pen.json", "w"), indent=1)
print("POSE DONE")
