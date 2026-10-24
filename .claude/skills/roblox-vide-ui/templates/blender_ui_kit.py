"""Blender UI ornament kit — paste into mcp__blender__execute_blender_code (Blender 5.x, MCP for Blender add-on).

Renders lit 3D UI ornaments (gold bands, iron plates, gems, rods) to transparent PNGs that become Roblox
9-slices / ImageLabels. Studio-verified 2026-10-05 (RPG material pass). Read references/material-pass.md first.

Usage (one execute call per step):
  1. paste this whole file once -> creates scene "UI_Render", materials, stores B/render in driver_namespace
  2. build:  B = bpy.app.driver_namespace["uiB"]; render = bpy.app.driver_namespace["uiRender"]
             t = B("A_title", 466, 72)            # asset box in px (1 unit = 1 px at 1x, y down)
             t.slab(...); t.rod(...); t.diamond_plate(...)
             render(t, "title_plate_3d.png")       # 2x PNG, 5 px padding, transparent film
  3. post-process in Python (templates/example_material_pass.py): bleed, shadows, fades.

Rules learned the hard way:
  - Never touch the user's scenes: everything lives in "UI_Render". Note: download_polyhaven_asset(hdris) sets
    the HDRI on the ACTIVE scene's world as a side effect — tell the user.
  - Cycles is a registered add-on engine, so RNA under-reports it: set it inside try/except.
  - Dark non-metal surfaces under a strong key light need albedo ~0.004 (0.018 still rendered mid-grey); flat
    plates facing the camera mirror the HDRI zenith -> roughness ~0.9, low specular.
  - Same key-light direction (top-left) for every asset, and the same direction for baked relief in textures.
"""
import math
import os

import bmesh
import bpy
from mathutils import Vector

OUT = r"C:\path\to\work\b3d"  # <- set: where PNGs are written
HDRI_WORLD = "PolyHaven studio_small_03"  # <- a Poly Haven HDRI downloaded first (high-contrast studio = good specular)

scn = bpy.data.scenes.get("UI_Render") or bpy.data.scenes.new("UI_Render")
if HDRI_WORLD in bpy.data.worlds:
    scn.world = bpy.data.worlds[HDRI_WORLD]
    bg = next((n for n in scn.world.node_tree.nodes if n.type == "BACKGROUND"), None)
    if bg:
        bg.inputs["Strength"].default_value = 0.6
try:
    scn.render.engine = "CYCLES"
except TypeError as e:
    print("engine fallback:", e)
if scn.render.engine == "CYCLES":
    scn.cycles.samples = 96
    scn.cycles.use_denoising = True
scn.render.film_transparent = True
scn.render.image_settings.file_format = "PNG"
scn.render.image_settings.color_mode = "RGBA"
scn.view_settings.view_transform = "Standard"


def _principled(name):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    return m, next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")


def gold(name="UI_Gold", base=(1.0, 0.56, 0.16), rough=0.3):
    m, b = _principled(name)
    nt = m.node_tree
    b.inputs["Base Color"].default_value = (*base, 1)
    b.inputs["Metallic"].default_value = 1.0
    noise = nt.nodes.new("ShaderNodeTexNoise"); noise.inputs["Scale"].default_value = 0.35; noise.inputs["Detail"].default_value = 8
    mr = nt.nodes.new("ShaderNodeMapRange"); mr.inputs["To Min"].default_value = rough - 0.08; mr.inputs["To Max"].default_value = rough + 0.16
    nt.links.new(noise.outputs["Fac"], mr.inputs["Value"]); nt.links.new(mr.outputs["Result"], b.inputs["Roughness"])
    bump = nt.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.08
    nt.links.new(noise.outputs["Fac"], bump.inputs["Height"]); nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    return m


def iron(name="UI_Iron"):
    m, b = _principled(name)
    b.inputs["Base Color"].default_value = (0.0042, 0.0028, 0.0022, 1)
    b.inputs["Metallic"].default_value = 0.0
    b.inputs["Roughness"].default_value = 0.9
    b.inputs["Specular IOR Level"].default_value = 0.08
    return m


def gemstone(name="UI_Ember", color=(0.45, 0.03, 0.005), glow=(1.0, 0.22, 0.03)):
    m, b = _principled(name)
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = 0.02
    b.inputs["Coat Weight"].default_value = 1.0
    b.inputs["Emission Color"].default_value = (*glow, 1)
    b.inputs["Emission Strength"].default_value = 0.35
    return m


M = {"gold": gold(), "goldd": gold("UI_GoldDark", (0.55, 0.30, 0.10), 0.4), "iron": iron(), "gem": gemstone()}

# camera + lights (once)
if "UICam" not in bpy.data.objects:
    cd = bpy.data.cameras.new("UICam"); cd.type = "ORTHO"
    cam = bpy.data.objects.new("UICam", cd); cam.location = (0, 0, 100); scn.collection.objects.link(cam); scn.camera = cam
    for name, loc, energy, size, color in [("UIKey", (-160, 160, 220), 260000, 120, (1.0, 0.86, 0.68)),
                                           ("UIRim", (170, -170, 120), 90000, 80, (1.0, 0.55, 0.3))]:
        ld = bpy.data.lights.new(name, "AREA"); ld.energy = energy; ld.size = size; ld.color = color
        ob = bpy.data.objects.new(name, ld); ob.location = loc; scn.collection.objects.link(ob)
        ob.rotation_euler = (Vector((0, 0, 0)) - ob.location).to_track_quat("-Z", "Y").to_euler()


class B:
    """Builder in px coords of a w x h asset box (y down), centered on the camera; one collection per asset."""

    def __init__(self, name, w, h):
        self.w, self.h = w, h
        self.col = bpy.data.collections.get(name) or bpy.data.collections.new(name)
        if self.col.name not in scn.collection.children:
            scn.collection.children.link(self.col)
        for o in list(self.col.objects):
            bpy.data.objects.remove(o, do_unlink=True)

    def P(self, x, y, z=0.0):
        return Vector((x - self.w / 2, self.h / 2 - y, z))

    def _link(self, ob, mat):
        ob.data.materials.append(M[mat]); self.col.objects.link(ob); return ob

    def slab(self, name, outer, inner, depth, mat, bevel=1.2, z=0.0):
        """Extruded, bevelled plate (inner=None) or band between two polygons."""
        me = bpy.data.meshes.new(name); bm = bmesh.new()
        if inner:
            vo = [bm.verts.new(self.P(x, y, z)) for x, y in outer]; vi = [bm.verts.new(self.P(x, y, z)) for x, y in inner]
            for i in range(len(vo)):
                j = (i + 1) % len(vo)
                bm.faces.new((vo[i], vo[j], vi[j], vi[i]))
        else:
            bm.faces.new([bm.verts.new(self.P(x, y, z)) for x, y in outer])
        ext = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:])
        for v in [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]:
            v.co.z += depth
        bm.normal_update(); bm.to_mesh(me); bm.free()
        ob = bpy.data.objects.new(name, me)
        mod = ob.modifiers.new("bev", "BEVEL"); mod.width = bevel; mod.segments = 3; mod.limit_method = "ANGLE"
        for p in me.polygons:
            p.use_smooth = True
        ob.modifiers.new("wn", "WEIGHTED_NORMAL")
        return self._link(ob, mat)

    def rod(self, name, pts, r, mat, cyclic=False, z=0.0):
        cu = bpy.data.curves.new(name, "CURVE"); cu.dimensions = "3D"; cu.bevel_depth = r; cu.bevel_resolution = 4
        cu.use_fill_caps = True
        sp = cu.splines.new("POLY"); sp.points.add(len(pts) - 1)
        for i, (x, y) in enumerate(pts):
            v = self.P(x, y, z); sp.points[i].co = (v.x, v.y, v.z, 1)
        sp.use_cyclic_u = cyclic
        return self._link(bpy.data.objects.new(name, cu), mat)

    def gem(self, name, x, y, r, z):
        me = bpy.data.meshes.new(name); bm = bmesh.new()
        bot = bm.verts.new((0, 0, -r * 0.2))
        ring = [bm.verts.new((r * math.cos(math.radians(k * 45)), r * math.sin(math.radians(k * 45)), 0)) for k in range(8)]
        tab = [bm.verts.new((r * .55 * math.cos(math.radians(k * 45)), r * .55 * math.sin(math.radians(k * 45)), r * .5)) for k in range(8)]
        for i in range(8):
            j = (i + 1) % 8
            bm.faces.new((ring[i], ring[j], tab[j], tab[i])); bm.faces.new((ring[j], ring[i], bot))
        bm.faces.new(tab); bm.to_mesh(me); bm.free()
        ob = bpy.data.objects.new(name, me); ob.location = self.P(x, y, z)
        return self._link(ob, "gem")

    def diamond_plate(self, name, cx, cy, r, z=0.0, gem=True):
        pts = [(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)]
        self.slab(name, pts, None, 3.5, "iron", bevel=1.2, z=z)
        self.rod(name + "Rim", pts, 1.3, "gold", cyclic=True, z=z + 4.2)
        if gem:
            self.gem(name + "Gem", cx, cy, r * 0.5, z + 4.5)


def render(builder, filename, pad=5, scale=2):
    """Render only this builder's collection: ortho camera fitted to box + pad, PNG at `scale`x."""
    for c in scn.collection.children:
        c.hide_render = c.name != builder.col.name
    W, H = builder.w + 2 * pad, builder.h + 2 * pad
    scn.camera.data.ortho_scale = max(W, H)
    scn.render.resolution_x = int(W * scale); scn.render.resolution_y = int(H * scale)
    os.makedirs(OUT, exist_ok=True)
    scn.render.filepath = os.path.join(OUT, filename)
    win = bpy.context.window; prev = win.scene; win.scene = scn
    try:
        bpy.ops.render.render(write_still=True, scene=scn.name)
    finally:
        win.scene = prev
    return scn.render.filepath


bpy.app.driver_namespace["uiB"] = B
bpy.app.driver_namespace["uiRender"] = render
print("UI kit ready in scene", scn.name, "engine", scn.render.engine)
