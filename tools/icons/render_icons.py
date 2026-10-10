"""Render AST-071 icon sources: one PNG (RGBA, transparent) per job. Run with bl.sh.
   bl.sh render_icons.py -- --jobs jobs.json --out renders/ [--only key1,key2]"""
import bpy, json, math, os, sys
from mathutils import Vector, Euler

argv = sys.argv[sys.argv.index("--") + 1:]
JOBS = json.load(open(argv[argv.index("--jobs") + 1]))
OUT = argv[argv.index("--out") + 1]
ONLY = argv[argv.index("--only") + 1].split(",") if "--only" in argv else None
RES = 512
os.makedirs(OUT, exist_ok=True)


def hex2lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c] + [1.0]


def setup_scene():
    scn = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scn.render.engine = eng
            break
        except Exception:
            pass
    scn.render.resolution_x = scn.render.resolution_y = RES
    scn.render.resolution_percentage = 100
    scn.render.film_transparent = True
    scn.render.image_settings.file_format = "PNG"
    scn.render.image_settings.color_mode = "RGBA"
    scn.view_settings.view_transform = "Standard"
    scn.view_settings.look = "None"
    scn.view_settings.exposure = 0.0
    scn.view_settings.gamma = 1.0
    try:
        scn.eevee.taa_render_samples = 32
    except Exception:
        pass
    for o in list(scn.objects):
        if o.type in ("LIGHT", "CAMERA"):
            o.hide_render = True
    w = bpy.data.worlds.new("IconWorld")
    scn.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = hex2lin("#D8D2C8")
    bg.inputs[1].default_value = 0.9
    # key light: Cream #FFF1D6 (style guide 5.2 ColorShift_Top), from front-left-top; cool soft rim from the back
    key = bpy.data.objects.new("Icon_Key", bpy.data.lights.new("Icon_Key", "SUN"))
    scn.collection.objects.link(key)
    key.data.energy = 2.4
    key.data.color = hex2lin("#FFF1D6")[:3]
    key.data.angle = math.radians(25)
    key.rotation_euler = Euler((math.radians(40), 0, math.radians(215)))
    rim = bpy.data.objects.new("Icon_Rim", bpy.data.lights.new("Icon_Rim", "SUN"))
    scn.collection.objects.link(rim)
    rim.data.energy = 0.8
    rim.data.color = (0.85, 0.92, 1.0)
    rim.rotation_euler = Euler((math.radians(65), 0, math.radians(30)))
    cam = bpy.data.objects.new("Icon_Cam", bpy.data.cameras.new("Icon_Cam"))
    scn.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    scn.camera = cam
    return scn, cam


def apply_xform(objs, t):
    for o in objs:
        if o.parent is not None and o.parent in objs:
            continue
        if "scale" in t:
            s = t["scale"]
            s = s if isinstance(s, list) else [s, s, s]
            o.scale = Vector((o.scale.x * s[0], o.scale.y * s[1], o.scale.z * s[2]))
            o.location = Vector((o.location.x * s[0], o.location.y * s[1], o.location.z * s[2]))
        if "rot" in t:
            r = Euler([math.radians(a) for a in t["rot"]])
            o.location = r.to_matrix() @ o.location
            o.rotation_euler = (r.to_matrix().to_4x4() @ o.rotation_euler.to_matrix().to_4x4()).to_euler()
        if "loc" in t:
            o.location = o.location + Vector(t["loc"])


def import_fbx(path, t):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    roots = [o for o in new if o.parent is None]
    # Assets/import convention: 0.01 scale + 180 deg about Z; undo -> 1 unit = 1 stud, +Y front
    if t.get("import_convention", True):
        for o in roots:
            o.scale = o.scale * 100
            o.location = o.location * 100
            r = Euler((0, 0, math.pi))
            o.location = r.to_matrix() @ o.location
            o.rotation_euler = (r.to_matrix().to_4x4() @ o.rotation_euler.to_matrix().to_4x4()).to_euler()
    apply_xform(new, t)
    meshes = [o for o in new if o.type == "MESH"]
    for o in meshes:
        if "tint" in t:
            tint(o, t["tint"], t.get("tint_mode", "multiply"))
    return meshes


def append_objs(path, names, t):
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n in names]
    out = []
    for o in dst.objects:
        if o is None:
            continue
        bpy.context.scene.collection.objects.link(o)
        out.append(o)
    bpy.context.view_layer.update()
    for o in out:
        if o.parent is not None and o.parent not in out:
            mw = o.matrix_world.copy()
            o.parent = None
            o.matrix_world = mw
    bpy.context.view_layer.update()
    apply_xform(out, t)
    if "snap_top" in t:
        ref = bpy.data.objects[t["snap_top"]]
        top = max((ref.matrix_world @ Vector(c)).z for c in ref.bound_box)
        bpy.context.view_layer.update()
        for o in out:
            bot = min((o.matrix_world @ Vector(c)).z for c in o.bound_box)
            o.location.z += top - bot - t.get("sink", 0.12)
    for o in out:
        o.hide_render = False
        if "tint" in t:
            tint(o, t["tint"], t.get("tint_mode", "multiply"))
    return [o for o in out if o.type == "MESH"]


def tint(o, hexcol, mode="multiply"):
    """Recolour for the icon only (source files untouched): multiply or replace the base colour."""
    for i, m in enumerate(list(o.data.materials)):
        if m is None:
            continue
        m2 = m.copy()
        m2.use_nodes = True
        nt = m2.node_tree
        bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is not None:
            links = list(bsdf.inputs["Base Color"].links)
            if mode == "ramp" and links:
                bw = nt.nodes.new("ShaderNodeRGBToBW")
                nt.links.new(links[0].from_socket, bw.inputs[0])
                ramp = nt.nodes.new("ShaderNodeValToRGB")
                dark, light = hexcol
                ramp.color_ramp.elements[0].position = 0.25
                ramp.color_ramp.elements[0].color = hex2lin(dark)
                ramp.color_ramp.elements[1].position = 0.85
                ramp.color_ramp.elements[1].color = hex2lin(light)
                nt.links.new(bw.outputs[0], ramp.inputs[0])
                nt.links.new(ramp.outputs[0], bsdf.inputs["Base Color"])
            elif mode == "replace" or not links:
                for l in links:
                    nt.links.remove(l)
                bsdf.inputs["Base Color"].default_value = hex2lin(hexcol)
            else:
                mix = nt.nodes.new("ShaderNodeMix")
                mix.data_type = "RGBA"
                mix.blend_type = "MULTIPLY"
                mix.inputs[0].default_value = 1.0
                nt.links.new(links[0].from_socket, mix.inputs[6])
                mix.inputs[7].default_value = hex2lin(hexcol)
                nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        o.data.materials[i] = m2


def frame(cam, objs, direction, zoom=1.0):
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in objs:
        oe = o.evaluated_get(dg)
        mw = oe.matrix_world
        pts += [mw @ v.co for v in oe.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c = (lo + hi) / 2
    rad = (hi - lo).length / 2
    d = Vector(direction).normalized()
    cam.location = c + d * (rad * 6 + 2)
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.view_layer.update()
    inv = cam.matrix_world.inverted()
    q = [inv @ p for p in pts]
    xs = [p.x for p in q]
    ys = [p.y for p in q]
    ext = max(max(xs) - min(xs), max(ys) - min(ys))
    cam.location = cam.matrix_world @ Vector(((max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, 0))
    cam.data.ortho_scale = ext * 1.12 / zoom
    cam.data.clip_start = 0.01
    cam.data.clip_end = rad * 20 + 20


for job in JOBS:
    key = job["key"]
    if ONLY and key not in ONLY:
        continue
    if job.get("file"):
        bpy.ops.wm.open_mainfile(filepath=job["file"])
        show = set(job.get("show", []))
        missing = show - {o.name for o in bpy.data.objects}
        if missing:
            print(key, "MISSING", missing)
        for o in bpy.data.objects:
            o.hide_render = o.name not in show
        shown = [o for o in bpy.data.objects if o.name in show]
        if "xform" in job:
            apply_xform(shown, job["xform"])
        objs = [o for o in shown if o.type == "MESH"]
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        objs = []
    scn, cam = setup_scene()
    for f in job.get("fbx", []):
        objs += import_fbx(f["path"], f)
    for a in job.get("append", []):
        objs += append_objs(a["file"], a["objs"], a)
    for name, col in job.get("tint", {}).items():
        for o in objs:
            if o.name == name:
                tint(o, col, job.get("tint_mode", "multiply"))
    for name, col in job.get("replace", {}).items():
        for o in objs:
            if o.name == name:
                tint(o, col, "replace")
    objs = [o for o in objs if not o.hide_render]
    bpy.context.view_layer.update()
    fobjs = [o for o in objs if o.name in job["frame"]] if "frame" in job else objs
    frame(cam, fobjs, job.get("view", (0.75, 1.0, 0.6)), job.get("zoom", 1.0))
    scn.render.filepath = os.path.join(OUT, key + ".png")
    bpy.ops.render.render(write_still=True)
    print("RENDERED", key, len(objs))
