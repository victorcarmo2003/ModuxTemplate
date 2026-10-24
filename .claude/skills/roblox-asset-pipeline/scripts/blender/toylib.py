# Toy low-poly builder helpers for Roblox assets (headless Blender).
#   exec(open("<skill>/scripts/blender/toylib.py", encoding="utf-8").read())
#   reset("<atlas.png>", grid=(8, 4))      # empty scene + one material using the family atlas
#   body = box("Body", (4.6, 2.6, 0.55), (0, 0, 0.355), (0, 4), bevel=0.05)
# Units = studs. Blender +Y = front (lands on Roblox -Z through export_import.py). Pivot = base centre.
# Colour only through atlas bands: (row, col[, lo, hi]) in a cols x rows grid of vertical gradients
# (lo/hi pick a slice of the gradient: 0 = top/light, 1 = bottom/dark).
import bpy, bmesh, json, math, os
from mathutils import Vector, Matrix

mat = None
GRID = (8, 4)  # columns, rows of the atlas


def reset(atlas_path, grid=(8, 4)):
    global mat, GRID
    GRID = grid
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    img = bpy.data.images.load(atlas_path)
    mat = bpy.data.materials.new("M_Atlas")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    ti = nt.nodes.new("ShaderNodeTexImage"); ti.image = img; ti.interpolation = "Closest"
    nt.links.new(ti.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6


def uv_band(obj, band):
    row, col = band[0], band[1]
    lo, hi = (band[2], band[3]) if len(band) > 2 else (0.12, 0.88)
    cols, rows = GRID
    me = obj.data
    uv = me.uv_layers.new(name="UVMap")
    zs = [v.co.z for v in me.vertices]
    z0, z1 = min(zs), max(zs)
    for poly in me.polygons:
        for li in poly.loop_indices:
            z = me.vertices[me.loops[li].vertex_index].co.z
            t = (z - z0) / (z1 - z0) if z1 > z0 else 0.5
            frac = hi - t * (hi - lo)
            uv.data[li].uv = ((col + 0.5) / cols, 1 - (row + frac) / rows)


def finish(bm, name, band, smooth=False):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = smooth
    uv_band(o, band)
    return o


def box(name, size, center, band, bevel=0.0, rot=None, drop=()):
    """Chamfered box. drop = list of normals whose faces are removed (hidden faces)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    if drop:
        bm.normal_update()
        dead = [f for f in bm.faces if any(f.normal.dot(Vector(d)) > 0.99 for d in drop)]
        bmesh.ops.delete(bm, geom=dead, context="FACES_ONLY")
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=bevel, segments=1, affect="EDGES", profile=0.5)
    if rot is not None:
        bmesh.ops.transform(bm, matrix=rot, verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)
    return finish(bm, name, band)


def _axis(axis):
    return {"x": Matrix.Rotation(math.radians(90), 4, "Y"), "y": Matrix.Rotation(math.radians(90), 4, "X"), "z": Matrix.Identity(4)}[axis]


def cyl(name, d, length, center, axis, band, segs=8, d2=None, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=d / 2,
                          radius2=(d2 if d2 is not None else d) / 2, depth=length)
    if bevel > 0:
        cap_edges = [e for e in bm.edges if any(len(f.verts) > 4 for f in e.link_faces)]
        bmesh.ops.bevel(bm, geom=cap_edges, offset=bevel, segments=1, affect="EDGES", profile=0.5)
    bmesh.ops.transform(bm, matrix=_axis(axis), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)
    return finish(bm, name, band, smooth=True)


def torus(name, R, r, center, axis, band, segs=10, rsegs=4):
    bm = bmesh.new()
    rings = []
    for i in range(segs):
        a = 2 * math.pi * i / segs
        c, s = math.cos(a), math.sin(a)
        rings.append([bm.verts.new(((R + r * math.cos(2 * math.pi * j / rsegs + math.pi / rsegs)) * c,
                                    (R + r * math.cos(2 * math.pi * j / rsegs + math.pi / rsegs)) * s,
                                    r * math.sin(2 * math.pi * j / rsegs + math.pi / rsegs))) for j in range(rsegs)])
    for i in range(segs):
        A, B = rings[i], rings[(i + 1) % segs]
        for j in range(rsegs):
            bm.faces.new((A[j], B[j], B[(j + 1) % rsegs], A[(j + 1) % rsegs]))
    bmesh.ops.transform(bm, matrix=_axis(axis), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)
    return finish(bm, name, band, smooth=True)


def tube(name, pts, r, band, sides=3, closed=False, radii=None):
    """Sweep a small polygon along a polyline (cords, piping, sauce zigzags)."""
    bm = bmesh.new()
    n = len(pts)
    rings = []
    for i in range(n):
        p = Vector(pts[i])
        t = (Vector(pts[(i + 1) % n]) - Vector(pts[i - 1])).normalized() if closed else \
            (Vector(pts[min(i + 1, n - 1)]) - Vector(pts[max(i - 1, 0)])).normalized()
        up = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
        a = t.cross(up).normalized(); b = t.cross(a).normalized()
        rr = radii[i] if radii else r
        rings.append([bm.verts.new(p + rr * (math.cos(2 * math.pi * j / sides + math.pi / sides) * a +
                                             math.sin(2 * math.pi * j / sides + math.pi / sides) * b)) for j in range(sides)])
    for i in range(n if closed else n - 1):
        A, B = rings[i], rings[(i + 1) % n]
        for j in range(sides):
            bm.faces.new((A[j], B[j], B[(j + 1) % sides], A[(j + 1) % sides]))
    if not closed:
        bm.faces.new(list(reversed(rings[0]))); bm.faces.new(rings[-1])
    return finish(bm, name, band, smooth=True)


def join(parts, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    g = bpy.context.view_layer.objects.active
    g.name = name; g.data.name = name
    return g


def set_origin(o, p):
    """Move an object's origin (pivot) to world point p without moving the geometry (hinges, Fill bases)."""
    p = Vector(p)
    o.data.transform(Matrix.Translation(-p))
    o.location = p


def parent(child, par):
    bpy.context.view_layer.update()
    mw = child.matrix_world.copy()
    child.parent = par
    child.matrix_parent_inverse = par.matrix_world.inverted()
    child.matrix_world = mw


def empty(name, loc, par=None):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.1
    bpy.context.scene.collection.objects.link(e)
    e.location = Vector(loc)
    if par is not None:
        parent(e, par)
    return e


def tris_of(o):
    o.data.calc_loop_triangles()
    return len(o.data.loop_triangles)


def bbox(objs):
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in objs if o.type == "MESH" for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def entry(label, root, tex):
    """Bridge JSON entry for quick Studio preview (preview_mesh.luau). Roblox axes (x, z, -y), v flipped.
    NOTE: preview frame = Blender frame (front at -Z only after export_import's rotation; preview shows front +Z)."""
    bpy.context.view_layer.update()
    inv = root.matrix_world.inverted()
    parts, atts, total = [], [], 0
    stack = [root]
    objs = []
    while stack:
        o = stack.pop(); objs.append(o); stack += list(o.children)
    for o in objs:
        if o.type == "EMPTY":
            p = inv @ o.matrix_world.translation
            atts.append({"name": o.name, "pos": [round(p.x, 4), round(p.z, 4), round(-p.y, 4)]})
            continue
        if o.type != "MESH":
            continue
        me = o.data; me.calc_loop_triangles()
        m = inv @ o.matrix_world
        uvl = me.uv_layers[0]
        pos, uvs = [], []
        flip = m.determinant() < 0
        for lt in me.loop_triangles:
            for li in (reversed(lt.loops) if flip else lt.loops):
                v = m @ me.vertices[me.loops[li].vertex_index].co
                pos += [round(v.x, 4), round(v.z, 4), round(-v.y, 4)]
                u = uvl.data[li].uv
                uvs += [round(u[0], 5), round(1 - u[1], 5)]
        total += len(me.loop_triangles)
        parts.append({"name": o.name, "pos": pos, "uv": uvs, "tex": tex})
    return {"label": label, "parts": parts, "tris": total, "atts": atts}


def save_blend(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=path)


def render(path, objs=None, direction=(0.75, 1.0, 0.6), lens=50, res=(900, 600), margin=1.25, world=(0.5, 0.55, 0.62)):
    """Quick EEVEE preview; direction is from target to camera (+Y = front)."""
    scn = bpy.context.scene
    objs = objs or [o for o in scn.objects if o.type == "MESH"]
    lo, hi = bbox(objs)
    c = (lo + hi) / 2
    rad = (hi - lo).length / 2
    d = Vector(direction).normalized()
    half_v = math.atan(18 * res[1] / res[0] / lens)
    dist = rad * margin / math.sin(half_v)
    cam = bpy.data.objects.get("PreviewCam") or bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
    if cam.name not in scn.collection.objects:
        scn.collection.objects.link(cam)
    cam.location = c + d * dist
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens; cam.data.clip_start = 0.01
    if not bpy.data.objects.get("PreviewSun"):
        sun = bpy.data.objects.new("PreviewSun", bpy.data.lights.new("PreviewSun", "SUN")); scn.collection.objects.link(sun)
        sun.data.energy = 3.0; sun.rotation_euler = (math.radians(45), 0, math.radians(150))
    scn.camera = cam
    scn.render.resolution_x, scn.render.resolution_y = res
    if scn.world is None:
        scn.world = bpy.data.worlds.new("W")
    scn.world.color = world
    os.makedirs(os.path.dirname(path), exist_ok=True)
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)


print("toylib loaded")
