import os
import bpy, sys, json, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hcommon import *
from mathutils import Vector
OLD = json.load(open(HD + "/orig/AST-053_Animals_joints.json"))
ROOTM = [-1, 0, 0, 0, 0, 1, 0, 1, 0]
ORI = {"EarLeftAttachment": [0, 0, 30], "EarRightAttachment": [0, 0, -30]}
R = lambda v: [round(v[0], 4), round(v[2], 4), round(-v[1], 4)]
def bbox(o):
    pts = [o.matrix_world @ v.co for v in o.data.vertices]
    mn = Vector([min(p[i] for p in pts) for i in range(3)]); mx = Vector([max(p[i] for p in pts) for i in range(3)])
    return mn, mx
def tris(o):
    o.data.calc_loop_triangles(); return len(o.data.loop_triangles)
out = {"asset": OLD["asset"], "axes": OLD["axes"], "notes": [
 "2026-10-10 round heads: Head_<Animal> is a single smooth mesh (oval, snout/beak volume, no modelled eyes/nose/mouth), base still at y=3.95 (Neck at the torso top), top at y=6.00 (old 5.70). Neck.C0 stays R6 standard; Neck.C1 below is per animal.",
 "Cap line raised +0.30: HatAttachment and EarLeft/EarRightAttachment are 0.30 higher than on the old box head, so Cap / Cap_EarsUp (files unchanged) and ears ride up with them. Cap: Dog and Turtle use the base Cap (AST-053_CrewCap.fbx); all others Cap_EarsUp (AST-053_CrewCap_EarsUp.fbx).",
 "Head_<Animal> UV (ONLY channel, 'UVMap') = T_Head_<Animal>.png / _Night.png, 512x512: alpha 0 = main fur (MeshPart.Color = fur), opaque texels = marks (muzzle, blaze, patches, mask, facial disc...). MeshPart.TextureID works (alpha shows Color).",
 "Face_<Animal> = thin shell over the FRONT of the head only (head faces whose flat normal . front >= 0.50, below the cap, |x| <= 1.20; offset 0.012 along the normals), its own MeshPart, Accessory welded by FaceFrontAttachment. ONLY UV channel = standard frontal projection v3 shared by all animals (2026-10-10 eye fix 2): u = 0.5 - 0.40*x (image left = viewer's left), v(from top) = 0.30 + 0.40*(4.86 - y) (x, y = Roblox character space, character on y=0). Eyes at u 0.34/0.66 v 0.30 (world x +-0.40, y 4.86, ovals 0.165 x 0.237), nose (snout tip) u 0.5 v 0.456 (y 4.47), mouth u 0.5 v 0.512 (y 4.33). One T_Expr_* sheet serves the 8 animals. Shell vertex normals = the head's (custom normals), no shading seam. Head v3: 26 x 14-ring lattice (728 tris), compact oval snout below the eyes + round chin (user: eyes were sliding down the snout slope; 'queixo redondo e fofinho').",
 "Face_<Animal> needs real transparency: use a SurfaceAppearance (AlphaMode = Transparency, ColorMap = T_Expr_*). SurfaceAppearance maps are not script-writable at runtime: keep one prebuilt SurfaceAppearance per expression (ReplicatedStorage) and swap it by parenting a clone into Face_<Animal>. Expressions: Normal, Happy, Smile, Sad, Fainted, Normal_Night (Assets/textures/character/face/).",
 "Ears_<Animal>, Tail_<Animal>, Shell_Turtle, Beak_Owl are Accessories: Handle = the MeshPart, one Attachment of the listed name/position/orientation inside it. Ears: one Handle with BOTH ears, welded by EarLeftAttachment (orientation 0,0,30 like the head's).",
 "Ears/Tail/Shell/Beak keep the KitchenPack atlas in UV channel 1 'UVMap' (restaurantbits_texture.png); channel 2 'UVPaint' unchanged."],
 "animals": {}}
for an in ORDER:
    bpy.ops.wm.open_mainfile(filepath=ROOT + f"Assets/blender/character/AST-053_Animal_{an}.blend")
    OB = bpy.data.objects
    head, face = OB["Head_" + an], OB["Face_" + an]
    mn, mx = bbox(head); hc = (mn + mx) / 2; hcr = R(hc)
    old = OLD["animals"][an]
    info_old = json.load(open(SP + f"/crew/animals/info_{an}.json"))
    atts = {c.name: c for c in head.children}
    d = {"cap": CAP.get(an, "Cap_EarsUp"), "tris": {}, "head": {"part": "Head_" + an,
         "size": [round(mx.x - mn.x, 4), round(mx.z - mn.z, 4), round(mx.y - mn.y, 4)], "center_world": hcr,
         "neck_C1": [round(0 - hcr[0], 4), round(4.0 - hcr[1], 4), round(0 - hcr[2], 4)] + ROOTM,
         "textures": {"day": f"T_Head_{an}.png", "night": f"T_Head_{an}_Night.png"},
         "fur_color_rgb": json.load(open(HD + "/colors.json"))[an]["fur"],
         "attachments": {k: {"position": [round(R(atts[k].matrix_world.translation)[i] - hcr[i], 4) for i in range(3)],
                             "orientation": ORI.get(k, [0, 0, 0])} for k in ["HatAttachment", "HairAttachment", "FaceFrontAttachment",
                             "FaceCenterAttachment", "EarLeftAttachment", "EarRightAttachment", "SnoutAttachment"]}},
         "accessories": {}}
    pieces = {}
    for o in OB:
        if o.type != "MESH" or o.name.startswith("REF_") or o.name == head.name:
            continue
        a, b = bbox(o); c = R((a + b) / 2)
        ch = [x for x in o.children if x.type == "EMPTY"]
        attn = ch[0].name.replace(o.name + "_", "") if ch else None
        ap = R(ch[0].matrix_world.translation) if ch else c
        entry = {"handle_size": [round(b.x - a.x, 4), round(b.z - a.z, 4), round(b.y - a.y, 4)], "attachment": attn,
                 "attachment_position_in_handle": [round(ap[i] - c[i], 4) for i in range(3)],
                 "orientation": ORI.get(attn, [0, 0, 0]), "tris": tris(o)}
        if o.name.startswith("Face_"):
            entry["surface_appearance"] = {"AlphaMode": "Transparency", "ColorMap": "face/T_Expr_Normal.png"}
        d["accessories"][o.name] = entry
        pieces[o.name] = entry["tris"]
    pieces = {"Head_" + an: tris(head), **pieces}
    tot = info_old["body_tris_no_head"] + info_old["cap_tris"] + sum(pieces.values())
    d["tris"] = {"pieces": pieces, "character_total": tot, "previous_head_tris": old["tris"]["pieces"]["Head_" + an]}
    out["animals"][an] = d
    print("J", an, d["head"]["size"], d["head"]["neck_C1"][:3], pieces, tot, flush=True)
json.dump(out, open(ROOT + "Assets/blender/character/AST-053_Animals_joints.json", "w"), indent=1)
print("JOINTS DONE")
