"""Render one thumbnail per candidate model (same ortho camera, sun, transparent background) for approval boards.

  sh bl.sh thumbs.py -- --jobs jobs.json --out D:/tmp/thumbs
  jobs.json = [["FP_hot-dog", "D:/Game/Assets/FoodPack/Models/GLB format/hot-dog.glb"], ...]   (.glb/.gltf/.fbx)
Prints "<key> dims X x Y x Z" (Blender axes, native units) per job - useful to spot packs at odd scales.
"""
import bpy, json, math, os, sys
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
JOBS = json.load(open(argv[argv.index("--jobs") + 1]))
OUT = argv[argv.index("--out") + 1]
os.makedirs(OUT, exist_ok=True)
scn = bpy.context.scene
for o in list(scn.objects):
    o.hide_render = True
cam = bpy.data.objects.new("Thumb_Cam", bpy.data.cameras.new("Thumb_Cam")); scn.collection.objects.link(cam)
sun = bpy.data.objects.new("Thumb_Sun", bpy.data.lights.new("Thumb_Sun", "SUN")); scn.collection.objects.link(sun)
sun.data.energy = 3.0; sun.rotation_euler = (math.radians(40), math.radians(10), math.radians(35))
cam.data.type = "ORTHO"
scn.camera = cam
scn.render.resolution_x = scn.render.resolution_y = 320
scn.render.film_transparent = True
DIR = Vector((1.0, -1.3, 0.85)).normalized()
for key, path in JOBS:
    before = set(bpy.data.objects)
    try:
        if path.lower().endswith((".glb", ".gltf")):
            bpy.ops.import_scene.gltf(filepath=path)
        else:
            bpy.ops.import_scene.fbx(filepath=path)
    except Exception as e:
        print(key, "IMPORT FAIL", str(e)[:80]); continue
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    if pts:
        mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        c = (mn + mx) / 2; size = mx - mn; r = size.length / 2
        cam.location = c + DIR * (r * 4 + 1)
        cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam.data.ortho_scale = r * 2.2; cam.data.clip_end = r * 10 + 10
        scn.render.filepath = os.path.join(OUT, key + ".png")
        bpy.ops.render.render(write_still=True)
        print(key, "dims %.2f x %.2f x %.2f" % (size.x, size.y, size.z))
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
