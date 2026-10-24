import os as _os
WORK = _os.environ.get("CHAR_WORK", _os.getcwd()).replace("\\", "/")
PROJECT = _os.environ.get("CHAR_PROJECT", "").replace("\\", "/").rstrip("/") + "/"
import json
SP = "."
info = json.load(open("crew/info.json")); atts = json.load(open("rbx/AST-053_CrewBase_atts.json"))
R = lambda v: [round(v[0], 4), round(v[2], 4), round(-v[1], 4)]
parts = {}
for n, d in info.items():
    sz = d["size_bl"]; parts[n] = {"size": [sz[0], sz[2], sz[1]], "center_world": R(d["center_bl"]), "tris": d["tris"]}
I = [1, 0, 0, 0, 1, 0, 0, 0, 1]
ROOT = [-1, 0, 0, 0, 0, 1, 0, 1, 0]
RS = [0, 0, 1, 0, 1, 0, -1, 0, 0]
LS = [0, 0, -1, 0, 1, 0, 1, 0, 0]
hc = parts["Head"]["center_world"][1] - parts["Torso"]["center_world"][1]
neck_c1_y = round(1.0 - hc, 4)
motors = {
 "RootJoint": {"Part0": "HumanoidRootPart", "Part1": "Torso", "C0": [0, 0, 0] + ROOT, "C1": [0, 0, 0] + ROOT, "standard": True},
 "Neck": {"Part0": "Torso", "Part1": "Head", "C0": [0, 1, 0] + ROOT, "C1": [0, neck_c1_y, 0] + ROOT, "standard": False,
          "note": f"C0 = R6 standard. C1.Y = {neck_c1_y} (standard -0.5) because the chibi Head is {parts['Head']['size'][1]} tall and its mesh bottom is sunk 0.05 into the torso top"},
 "Right Shoulder": {"Part0": "Torso", "Part1": "Right Arm", "C0": [1, 0.5, 0] + RS, "C1": [-0.5, 0.5, 0] + RS, "standard": True},
 "Left Shoulder": {"Part0": "Torso", "Part1": "Left Arm", "C0": [-1, 0.5, 0] + LS, "C1": [0.5, 0.5, 0] + LS, "standard": True},
 "Right Hip": {"Part0": "Torso", "Part1": "Right Leg", "C0": [1, -1, 0] + RS, "C1": [0.5, 1, 0] + RS, "standard": True},
 "Left Hip": {"Part0": "Torso", "Part1": "Left Leg", "C0": [-1, -1, 0] + LS, "C1": [-0.5, 1, 0] + LS, "standard": True},
}
ORI = {"EarLeftAttachment": [0, 0, 30], "EarRightAttachment": [0, 0, -30]}
att_local = {}
for k, w in atts.items():
    part, an = k.split("/")
    c = parts[part]["center_world"]
    att_local.setdefault(part, {})[an.replace("Cap_", "").replace("Apron_", "")] = {
        "position": [round(w[i] - c[i], 4) for i in range(3)], "orientation": ORI.get(an, [0, 0, 0])}
out = {
 "asset": "AST-053 CrewBase (HotDog Crew R6 base body)",
 "axes": "Roblox (X right, Y up, -Z front). CFrame arrays = [x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22] (CFrame.new(...) order). Part positions with the character standing on Y=0 (HRP centre at Y=3).",
 "notes": [
  "MeshPart CFrame = centre of the mesh bounding box (Roblox rule); Motor6D C0/C1 below are relative to those centres. Blender object origins sit on the joints only for posing in Blender.",
  "Torso and limbs keep the exact R6 boxes (Torso 2x2x1, limbs 1x2x1): all Motor6Ds except Neck.C1 are the stock R6 values, so default R6 Animate/emotes work unchanged.",
  "HumanoidRootPart: Transparency 1, CanCollide true (R6 default), no mesh needed in game (a 2x2x1 Part works; mesh exported only for completeness).",
  "Cap and Apron are Accessories: Handle = the MeshPart, with an Attachment of the listed name/position inside the Handle; Humanoid:AddAccessory welds it to the body attachment of the same name.",
  "Fur recolor per animal: KitchenPack atlas column 5 row 1 (u 0.6875, v 0.5..0.75) is used ONLY by fur faces (Head, forearms+hands below the sleeve hem). Remap those UVs to the animal band, or swap the band in a per-animal atlas copy."
 ],
 "parts": parts,
 "motor6d": motors,
 "attachments_part_local": att_local,
 "accessories": {
  "Cap": {"handle_size": parts["Cap"]["size"], "attachment": "HatAttachment", "attachment_position_in_handle": att_local["Cap"]["HatAttachment"]["position"], "file": "Assets/models/character/AST-053_CrewCap.fbx"},
  "Apron": {"handle_size": parts["Apron"]["size"], "attachment": "BodyFrontAttachment", "attachment_position_in_handle": att_local["Apron"]["BodyFrontAttachment"]["position"], "file": "Assets/models/character/AST-053_CrewApron.fbx",
            "logo_area": "flat front panel between Y 2.2 and 3.05 world (part-local Y -0.675..0.175), width 1.8; decal AST-072 on the Front face"},
 },
}
json.dump(out, open(PROJECT + "Assets/blender/character/AST-053_CrewBase_joints.json", "w"), indent=1)
print(json.dumps(motors["Neck"]), json.dumps(out["accessories"], indent=0))
print(json.dumps(att_local, indent=0)[:3000])
