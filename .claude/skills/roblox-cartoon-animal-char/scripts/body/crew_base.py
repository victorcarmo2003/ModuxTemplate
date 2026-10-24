# AST-053 CrewBase: HotDog Crew common R6 body (no animal features). Headless Blender 5.2.
# 1 unit = 1 stud, Blender +Y = front (Roblox -Z), Z up. Standing on ground: HRP centre at (0,0,3).
# Parts keep exact R6 bounding boxes (Torso 2x2x1, limbs 1x2x1) so default R6 Motor6Ds/animations work;
# Head is chibi 2.3 x 1.75 x 1.9. Each object origin = its R6 joint (neck, shoulder, hip); HRP origin = centre.
import sys, os, json, math
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from charlib import *

clear()
TEX = ROOT + "Assets/KitchenPack/Assets/gltf/restaurantbits_texture.png"
img = bpy.data.images.load(TEX)
mat = bpy.data.materials.new("M_RestaurantBits")
mat.use_nodes = True
nt = mat.node_tree
bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
ti = nt.nodes.new("ShaderNodeTexImage"); ti.image = img; ti.interpolation = "Closest"
nt.links.new(ti.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.7

# band specs: (row, col, frac_top, frac_bottom) inside the 8x4 KitchenPack atlas
RED = (2, 6, 0.30, 0.62)
RED_DK = (2, 6, 0.55, 0.80)
CREAM = (1, 4, 0.06, 0.42)
PANTS = (0, 1, 0.55, 0.85)
SHOE = (0, 0, 0.45, 0.90)
FUR = (1, 5, 0.10, 0.62)      # neutral light-brown "fur" band, swapped per animal
GHOST = (0, 3, 0.5, 0.5)


def set_uv(me, face_spec, zr=None):
    """face_spec(poly) -> band spec. v follows world z inside [z0,z1] (top light)."""
    uv = me.uv_layers.new(name="UVMap")
    zs = [v.co.z for v in me.vertices]
    z0, z1 = zr if zr else (min(zs), max(zs))
    for p in me.polygons:
        r, c, lo, hi = face_spec(p)
        for li in p.loop_indices:
            z = me.vertices[me.loops[li].vertex_index].co.z
            t = min(1, max(0, (z - z0) / (z1 - z0))) if z1 > z0 else 0.5
            frac = hi - t * (hi - lo)
            uv.data[li].uv = ((c + 0.5) / 8, 1 - (r + frac) / 4)


def mk(name, bm):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = False
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    return o


def rring(bm, z, hx, hy, r, seg, cx=0.0, cy=0.0):
    pts = []
    for k, (sx, sy, a0) in enumerate(((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270))):
        ccx, ccy = cx + sx * (hx - r), cy + sy * (hy - r)
        for i in range(seg + 1):
            a = math.radians(a0 + 90 * i / seg)
            pts.append(bm.verts.new((ccx + r * math.cos(a), ccy + r * math.sin(a), z)))
    return pts


def lathe(name, rings, seg_bands, top_band, bot_band, seg=1, cx=0.0, cy=0.0):
    """rings top->bottom: (z, hx, hy, r). seg_bands[k] = band between ring k and k+1."""
    bm = bmesh.new()
    lay = bm.faces.layers.int.new("band")
    R = [rring(bm, z, hx, hy, r, seg, cx, cy) for z, hx, hy, r in rings]
    tag = []
    n = len(R[0])
    for k in range(len(R) - 1):
        for i in range(n):
            j = (i + 1) % n
            f = bm.faces.new((R[k][i], R[k][j], R[k + 1][j], R[k + 1][i]))
            tag.append((f, seg_bands[k]))
    tag.append((bm.faces.new(R[0]), top_band))
    tag.append((bm.faces.new(list(reversed(R[-1]))), bot_band))
    bands = list(dict.fromkeys(b for _, b in tag))
    for f, b in tag:
        f[lay] = bands.index(b)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    me.materials.append(mat)
    attr = me.attributes["band"].data
    idx = [a.value for a in attr]
    set_uv(me, lambda p: bands[idx[p.index]])
    me.attributes.remove(me.attributes["band"])
    for p in me.polygons:
        p.use_smooth = False
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    return o


# ---------------- Torso 2 x 1 x 2 (x, y, z), z 2..4: cream shirt, black waistband (pants top)
torso = lathe("Torso", [
    (4.00, 0.90, 0.40, 0.06),
    (3.90, 1.00, 0.50, 0.12),
    (2.32, 1.00, 0.50, 0.12),
    (2.10, 1.00, 0.50, 0.12),
    (2.00, 0.90, 0.40, 0.06)],
    [CREAM, CREAM, PANTS, PANTS], CREAM, PANTS)

# ---------------- Arms 1 x 1 x 2, z 2..4: short cream sleeve (full 1x1), fur forearm/hand 0.8x0.8
def arm(name, cx):
    return lathe(name, [
        (4.00, 0.40, 0.40, 0.08),
        (3.90, 0.50, 0.50, 0.14),
        (3.24, 0.50, 0.50, 0.14),
        (3.16, 0.45, 0.45, 0.12),
        (3.16, 0.40, 0.40, 0.11),
        (2.10, 0.40, 0.40, 0.11),
        (2.00, 0.30, 0.30, 0.07)],
        [CREAM, CREAM, CREAM, CREAM, FUR, FUR], CREAM, FUR, cx=cx)

arm_r = arm("Right Arm", 1.5)
arm_l = arm("Left Arm", -1.5)

# ---------------- Legs 1 x 1 x 2, z 0..2: black pants tapering a bit, darker shoe block
def leg(name, cx):
    return lathe(name, [
        (2.00, 0.42, 0.42, 0.06),
        (1.92, 0.50, 0.50, 0.12),
        (0.46, 0.46, 0.46, 0.11),
        (0.46, 0.50, 0.50, 0.13),
        (0.07, 0.50, 0.50, 0.13),
        (0.00, 0.42, 0.42, 0.07)],
        [PANTS, PANTS, SHOE, SHOE, SHOE], PANTS, SHOE, cx=cx)

leg_r = leg("Right Leg", 0.5)
leg_l = leg("Left Leg", -0.5)

# ---------------- Head: neutral rounded block, chibi 2.3 x 1.9 x 1.75 (x, y, z), bottom sunk 0.05 into torso
HW, HD, HH = 2.30, 1.90, 1.75
HZ0 = 3.95
HC = HZ0 + HH / 2                      # 4.825
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1.0)
bmesh.ops.scale(bm, vec=Vector((HW, HD, HH)), verts=bm.verts)
bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=0.42, segments=3, affect="EDGES", profile=0.5)
bmesh.ops.translate(bm, vec=Vector((0, 0, HC)), verts=bm.verts)
head = mk("Head", bm)
set_uv(head.data, lambda p: FUR)

# ---------------- HumanoidRootPart (invisible) 2 x 1 x 2 at torso centre
bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
bmesh.ops.scale(bm, vec=Vector((2, 1, 2)), verts=bm.verts)
bmesh.ops.translate(bm, vec=Vector((0, 0, 3)), verts=bm.verts)
hrp = mk("HumanoidRootPart", bm)
set_uv(hrp.data, lambda p: GHOST)
hrp.hide_render = True
hrp.display_type = "WIRE"

# ---------------- Cap (accessory on HatAttachment): crown hugging the head top + front brim + button
O = 0.07                     # gap/offset over the head surface
BR = 0.42                    # head bevel radius
TOPZ = HC + HH / 2           # 5.70
cz = TOPZ - BR               # bevel circle centre height 5.28
fx, fy = HW / 2 - BR, HD / 2 - BR
rings = [(TOPZ + O, fx + 0.02, fy + 0.02, 0.02)]
for a in (35, 65):
    ra = math.radians(a)
    rr = (BR + O) * math.sin(ra)
    rings.append((cz + (BR + O) * math.cos(ra), fx + rr, fy + rr, max(0.03, rr)))
rings += [(cz - 0.02, fx + BR + O, fy + BR + O, BR + O), (5.02, fx + BR + O, fy + BR + O, BR + O)]
crown = lathe("Cap_Crown", rings, [RED] * (len(rings) - 1), RED, RED_DK, seg=3)
# brim: rounded plate, back edge buried in the crown, tilted 10 deg down at the front
bm = bmesh.new()
outline = [(-0.86, 0.55), (0.86, 0.55), (0.86, 1.20)]
for i in range(1, 8):
    a = math.radians(i * 180 / 8)
    outline.append((0.86 * math.cos(a), 1.20 + 0.62 * math.sin(a)))
outline.append((-0.86, 1.20))
T = 0.10
top = [bm.verts.new((x, y, 0)) for x, y in outline]
bot = [bm.verts.new((x, y, -T)) for x, y in outline]
bm.faces.new(top); bm.faces.new(list(reversed(bot)))
for i in range(len(outline)):
    j = (i + 1) % len(outline)
    bm.faces.new((top[i], top[j], bot[j], bot[i]))
bmesh.ops.transform(bm, matrix=Matrix.Translation((0, 0.42, 5.14)) @ Matrix.Rotation(math.radians(-10), 4, "X")
                    @ Matrix.Translation((0, -0.55, 0)), verts=bm.verts)
brim = mk("Cap_Brim", bm)
set_uv(brim.data, lambda p: RED_DK)
bm = bmesh.new()
bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=8, radius1=0.13, radius2=0.10, depth=0.10)
bmesh.ops.translate(bm, vec=Vector((0, 0, TOPZ + O + 0.04)), verts=bm.verts)
btn = mk("Cap_Button", bm)
set_uv(btn.data, lambda p: RED)
bpy.ops.object.select_all(action="DESELECT")
for o in (crown, brim, btn):
    o.select_set(True)
bpy.context.view_layer.objects.active = crown
bpy.ops.object.join()
cap = bpy.context.view_layer.objects.active
cap.name = "Cap"; cap.data.name = "Cap"

# ---------------- Apron (accessory on BodyFrontAttachment): bib + skirt, flat logo area, skirt flares out below z 2.2
AY0, AT = 0.515, 0.07
out2d = [(-0.58, 3.78), (0.58, 3.78), (0.58, 3.05), (0.90, 2.86), (0.92, 2.20), (0.92, 1.80), (0.84, 1.70),
         (-0.84, 1.70), (-0.92, 1.80), (-0.92, 2.20), (-0.90, 2.86), (-0.58, 3.05)]
bm = bmesh.new()
fr = [bm.verts.new((x, AY0 + AT, z)) for x, z in out2d]
bk = [bm.verts.new((x, AY0, z)) for x, z in out2d]
ff = bm.faces.new(fr); fb = bm.faces.new(list(reversed(bk)))
for i in range(len(out2d)):
    j = (i + 1) % len(out2d)
    bm.faces.new((fr[i], fr[j], bk[j], bk[i]))
# split front/back at the bend line (z 2.2) and the bib line (z 3.05)
bmesh.ops.connect_verts(bm, verts=[fr[4], fr[9]])
bmesh.ops.connect_verts(bm, verts=[bk[4], bk[9]])
for v in bm.verts:
    if v.co.z < 2.2 - 1e-6:
        v.co.y += (2.2 - v.co.z) * 0.38
# straps: from bib corners up over the torso top edge, ending under the head
for sx in (-1, 1):
    for (p0, p1) in (((sx * 0.50 - 0.08, AY0 + 0.01, 3.70), (sx * 0.50 + 0.08, AY0 + 0.06, 4.03)),
                     ((sx * 0.50 - 0.07, 0.10, 3.99), (sx * 0.50 + 0.07, AY0 + 0.05, 4.05))):
        c = [(p0[i] + p1[i]) / 2 for i in range(3)]; s = [p1[i] - p0[i] for i in range(3)]
        g = bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=Vector(s), verts=g["verts"])
        bmesh.ops.translate(bm, vec=Vector(c), verts=g["verts"])
apron = mk("Apron", bm)
set_uv(apron.data, lambda p: RED, zr=(1.7, 4.05))

# ---------------- origins at R6 joints (world, Blender axes)
JOINT = {
    "HumanoidRootPart": (0, 0, 3.0), "Torso": (0, 0, 3.0), "Head": (0, 0, 4.0),
    "Right Arm": (1.0, 0, 3.5), "Left Arm": (-1.0, 0, 3.5), "Right Leg": (1.0, 0, 2.0), "Left Leg": (-1.0, 0, 2.0),
    "Cap": (0, 0, TOPZ), "Apron": (0, 0.5, 3.0),
}
for nm, p in JOINT.items():
    set_origin(bpy.data.objects[nm], p)

# ---------------- attachments (empties, Blender world positions)
ATT = {
    "Head": {"HatAttachment": (0, 0, TOPZ), "HairAttachment": (0, 0, TOPZ), "FaceFrontAttachment": (0, HD / 2, HC),
             "FaceCenterAttachment": (0, 0, HC), "EarLeftAttachment": (-0.94, 0, 5.64), "EarRightAttachment": (0.94, 0, 5.64),
             "SnoutAttachment": (0, HD / 2, HC - 0.225)},
    "Torso": {"NeckAttachment": (0, 0, 4), "BodyFrontAttachment": (0, 0.5, 3), "BodyBackAttachment": (0, -0.5, 3),
              "LeftCollarAttachment": (-1, 0, 4), "RightCollarAttachment": (1, 0, 4), "WaistFrontAttachment": (0, 0.5, 2),
              "WaistBackAttachment": (0, -0.5, 2), "WaistCenterAttachment": (0, 0, 2), "TailAttachment": (0, -0.5, 2.25)},
    "Left Arm": {"LeftShoulderAttachment": (-1.5, 0, 4), "LeftGripAttachment": (-1.5, 0, 2)},
    "Right Arm": {"RightShoulderAttachment": (1.5, 0, 4), "RightGripAttachment": (1.5, 0, 2)},
    "Left Leg": {"LeftFootAttachment": (-0.5, 0, 0)},
    "Right Leg": {"RightFootAttachment": (0.5, 0, 0)},
    "HumanoidRootPart": {"RootAttachment": (0, 0, 3)},
    "Cap": {"Cap_HatAttachment": (0, 0, TOPZ)},
    "Apron": {"Apron_BodyFrontAttachment": (0, 0.5, 3)},
}
for part, d in ATT.items():
    for an, p in d.items():
        empty(an, p, parent=bpy.data.objects[part], size=0.25)

# ---------------- report + JSON
bpy.context.view_layer.update()
BODY = ["HumanoidRootPart", "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg"]
ACC = ["Cap", "Apron"]
info = {}
for nm in BODY + ACC:
    o = bpy.data.objects[nm]
    mn, mx = bbox([o])
    info[nm] = {"tris": tris(o), "size_bl": [round(x, 3) for x in (mx - mn)], "center_bl": [round(x, 3) for x in (mn + mx) / 2]}
    print("PART", nm, info[nm])
print("TOTAL visible tris", sum(info[n]["tris"] for n in BODY + ACC if n != "HumanoidRootPart"))
json.dump(info, open(SP + "/crew/info.json", "w"), indent=1)

parts = []
for nm in BODY + ACC:
    o = bpy.data.objects[nm]
    d = part_json(o, "KP", transparency=1 if nm == "HumanoidRootPart" else None)
    d["pivot"] = rbx(o.matrix_world.translation)
    parts.append(d)
write_json("AST-053_CrewBase", [("AST-053 CrewBase (HotDog Crew R6 base)", parts)])
atts = {}
for part, d in ATT.items():
    for an in d:
        e = bpy.data.objects[an]
        atts[f"{part}/{an}"] = rbx(e.matrix_world.translation)
json.dump(atts, open(SP + "/rbx/AST-053_CrewBase_atts.json", "w"), indent=1)

# ---------------- save + export
def kids(names):
    out = []
    for n in names:
        o = bpy.data.objects[n]; out.append(o); out += list(o.children)
    return out

save("character", "AST-053_CrewBase", kids(BODY))
save("character", "AST-053_CrewCap", kids(["Cap"]), blend=False)
save("character", "AST-053_CrewApron", kids(["Apron"]), blend=False)
print("DONE")
