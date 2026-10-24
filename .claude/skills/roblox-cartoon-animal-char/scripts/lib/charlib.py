# Shared helpers for lot 5 (DEC-139 pending edits). Headless Blender 5.2. 1 unit = 1 stud, Blender +Y = front.
import os as _os
WORK = _os.environ.get("CHAR_WORK", _os.getcwd()).replace("\\", "/")
PROJECT = _os.environ.get("CHAR_PROJECT", "").replace("\\", "/").rstrip("/") + "/"
import bpy, bmesh, json, math, os, functools, builtins
from mathutils import Vector, Matrix

print = functools.partial(builtins.print, flush=True)
SP = WORK
ROOT = PROJECT
CK = ROOT + "Assets/CarKit/Models/GLB format/{}.glb"
CC = ROOT + "Assets/CityKitCommercial/Models/GLB format/{}.glb"
KP = ROOT + "Assets/KitchenPack/Assets/gltf/{}.gltf"


def clear():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.meshes):
        bpy.data.meshes.remove(m)


def imp(path):
    """Import glTF; bake every mesh to world space (flip if mirrored); drop non-mesh nodes."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        if o.type == "MESH":
            mw = o.matrix_world.copy()
            o.parent = None
            o.data.transform(mw)
            if mw.determinant() < 0:
                o.data.flip_normals()
            o.matrix_world = Matrix.Identity(4)
    for o in new:
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    return {o.name.split(".")[0]: o for o in new if o.name in bpy.data.objects}


def cell_of(poly, uvd, cols=16):
    u = sum((uvd[l].uv for l in poly.loop_indices), Vector((0, 0))) / poly.loop_total
    return (int(u.x * cols), int((1 - u.y) * 4))


def split_faces(obj, pred, name):
    """Move faces where pred(poly) is true into a new object (same material/UV). Returns new obj or None."""
    me = obj.data
    bm = bmesh.new(); bm.from_mesh(me)
    uvd = me.uv_layers.active.data
    sel = set(p.index for p in me.polygons if pred(p, uvd))
    if not sel:
        bm.free(); return None
    bm2 = bm.copy()
    bm.faces.ensure_lookup_table(); bm2.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[i] for i in sel], context="FACES")
    bmesh.ops.delete(bm2, geom=[f for f in bm2.faces if f.index not in sel], context="FACES")
    me2 = bpy.data.meshes.new(name)
    bm2.to_mesh(me2); bm2.free()
    bm.to_mesh(me); bm.free()
    for m in me.materials:
        me2.materials.append(m)
    o2 = bpy.data.objects.new(name, me2)
    bpy.context.scene.collection.objects.link(o2)
    return o2


def shift_uv(obj, src_cell, dst_cell, cols=16, frac_map=None):
    """Move every loop whose face sits in src_cell to dst_cell (same position inside the cell)."""
    me = obj.data; uvd = me.uv_layers.active.data
    for p in me.polygons:
        if src_cell is not None and cell_of(p, uvd, cols) != src_cell:
            continue
        for li in p.loop_indices:
            u, v = uvd[li].uv
            sc = src_cell or cell_of(p, uvd, cols)
            fu = u * cols - sc[0]
            fv = (1 - v) * 4 - sc[1]
            if frac_map:
                fv = frac_map(fv)
            uvd[li].uv = ((dst_cell[0] + fu) / cols, 1 - (dst_cell[1] + fv) / 4)


def set_uv_all(obj, cell, frac=0.5, cols=16):
    me = obj.data; uvd = me.uv_layers.active.data
    for l in uvd:
        l.uv = ((cell[0] + 0.5) / cols, 1 - (cell[1] + frac) / 4)


def wheel(name, R, W, segs, sign, tire_cell, hub_cell, mat, cols=16, c=None, rh=None, d=None):
    """Toy wheel around the X axis, centred at origin. sign=+1: hub faces +X. Tire + inset hub disc."""
    c = c if c is not None else R * 0.17
    rh = rh if rh is not None else R * 0.58
    d = d if d is not None else W * 0.08
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    prof = [(-W / 2, R - c), (-W / 2 + c, R), (W / 2 - c, R), (W / 2, R - c), (W / 2, rh), (W / 2 - d, rh)]
    rings = []
    for a, r in prof:
        rings.append([bm.verts.new((a * sign, r * math.cos(2 * math.pi * (i + 0.5) / segs), r * math.sin(2 * math.pi * (i + 0.5) / segs))) for i in range(segs)])
    faces_tire, faces_hub = [], []
    for k in range(len(prof) - 1):
        for i in range(segs):
            j = (i + 1) % segs
            f = bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
            (faces_hub if k == len(prof) - 2 else faces_tire).append(f)
    faces_tire.append(bm.faces.new(list(reversed(rings[0]))))
    faces_hub.append(bm.faces.new(rings[-1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    for fs, cl, fr in ((faces_tire, tire_cell, 0.5), (faces_hub, hub_cell, 0.35)):
        for f in fs:
            for l in f.loops:
                l[uvl].uv = ((cl[0] + 0.5) / cols, 1 - (cl[1] + fr) / 4)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for p in me.polygons:
        p.use_smooth = False
    me.materials.append(mat)
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    return o


def tris(o):
    o.data.calc_loop_triangles()
    return len(o.data.loop_triangles)


def bbox(objs):
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    mn = Vector([min(p[i] for p in pts) for i in range(3)]); mx = Vector([max(p[i] for p in pts) for i in range(3)])
    return mn, mx


def set_origin(o, pivot):
    """Keep world shape, move the object origin to pivot (world)."""
    pv = Vector(pivot)
    o.data.transform(Matrix.Translation(o.matrix_world.translation - pv))
    o.matrix_world = Matrix.Translation(pv)


def empty(name, loc, parent=None, size=0.3):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = size
    bpy.context.scene.collection.objects.link(e)
    e.location = Vector(loc)
    if parent is not None:
        e.parent = parent
        e.matrix_parent_inverse = parent.matrix_world.inverted()
    return e


def rbx(v):
    return [round(v.x, 4), round(v.z, 4), round(-v.y, 4)]


def part_json(o, tex, transparency=None, material=None):
    me = o.data
    me.calc_loop_triangles()
    uvl = me.uv_layers.active
    mw = o.matrix_world
    pos, uvs = [], []
    for lt in me.loop_triangles:
        for li in lt.loops:
            pos += rbx(mw @ me.vertices[me.loops[li].vertex_index].co)
            u = uvl.data[li].uv
            uvs += [round(u[0], 5), round(1 - u[1], 5)]
    d = {"name": o.name, "pos": pos, "uv": uvs, "tex": tex}
    if transparency is not None:
        d["transparency"] = transparency
    if material is not None:
        d["material"] = material
    return d


def write_json(base, entries):
    """entries: [(label, [part dicts])]"""
    out = []
    for label, parts in entries:
        out.append({"label": label, "parts": parts, "tris": sum(len(p["pos"]) // 9 for p in parts)})
    os.makedirs(SP + "/rbx", exist_ok=True)
    json.dump(out, open(SP + "/rbx/" + base + ".json", "w"))
    return out


def save(cat, base, export_objs, blend=True):
    fbx = ROOT + f"Assets/models/{cat}/{base}.fbx"
    os.makedirs(os.path.dirname(fbx), exist_ok=True)
    if blend:
        b = ROOT + f"Assets/blender/{cat}/{base}.blend"
        os.makedirs(os.path.dirname(b), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=b)
    bpy.ops.object.select_all(action="DESELECT")
    for o in export_objs:
        o.hide_set(False); o.select_set(True)
    bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, object_types={"MESH", "EMPTY"}, apply_unit_scale=True,
                             axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE", add_leaf_bones=False, bake_anim=False)
    return fbx


def render(base, views, target, dist, ortho=None, res=(900, 600), lens=50, hide=()):
    scn = bpy.context.scene
    os.makedirs(SP + "/previews", exist_ok=True)
    cam = bpy.data.objects.new("PrevCam", bpy.data.cameras.new("PrevCam")); scn.collection.objects.link(cam)
    sun = bpy.data.objects.new("PrevSun", bpy.data.lights.new("PrevSun", "SUN")); scn.collection.objects.link(sun)
    sun.data.energy = 3.0; sun.rotation_euler = (math.radians(45), 0, math.radians(150))
    scn.camera = cam
    scn.render.resolution_x, scn.render.resolution_y = res
    if scn.world is None:
        scn.world = bpy.data.worlds.new("W")
    scn.world.color = (0.55, 0.6, 0.66)
    hidden = []
    for o in hide:
        if not o.hide_render:
            o.hide_render = True; hidden.append(o)
    if ortho:
        cam.data.type = "ORTHO"; cam.data.ortho_scale = ortho
    else:
        cam.data.lens = lens
    outs = []
    for suffix, d in views:
        if isinstance(d, tuple) and len(d) == 2 and isinstance(d[0], (tuple, list)):
            loc, tgt = Vector(d[0]), Vector(d[1])
        else:
            tgt = Vector(target); loc = tgt + Vector(d).normalized() * dist
        cam.location = loc
        cam.rotation_euler = (tgt - loc).to_track_quat("-Z", "Y").to_euler()
        scn.render.filepath = SP + f"/previews/{base}{suffix}.png"
        bpy.ops.render.render(write_still=True)
        outs.append(scn.render.filepath)
    for o in hidden:
        o.hide_render = False
    bpy.data.objects.remove(cam, do_unlink=True); bpy.data.objects.remove(sun, do_unlink=True)
    return outs
