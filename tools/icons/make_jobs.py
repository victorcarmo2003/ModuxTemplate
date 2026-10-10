"""AST-071 icon sheet, step 1/3: write jobs.json (which model/objects/camera per icon).
Pipeline (from the repo root; Python needs the WMI shim on this machine, see the asset-pipeline skill):
  python tools/icons/make_jobs.py
  sh ~/.claude/skills/roblox-asset-pipeline/scripts/blender/bl.sh tools/icons/render_icons.py -- --jobs tools/icons/jobs.json --out <ABS_TMP>/renders
  python tools/icons/build_sheet.py <ABS_TMP>/renders .
Outputs: Assets/textures/ui/AST-071_icons.png + .json, Assets/reference/AST-071_icons_contact.png.
--out must be ABSOLUTE (Blender resolves relative paths against its own cwd).
"""
import json, os, sys

R = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "Assets")).replace("\\", "/")
B = R + "/blender"
I = R + "/import"
HERE = os.path.dirname(os.path.abspath(__file__))

V34 = [0.75, 1.0, 0.6]      # 3/4 front-right, above (+Y = front)
VHI = [0.6, 1.0, 1.1]       # higher, for flat things
VFACE = [0.42, 1.0, 0.22]   # portraits: 3/4 frontal

jobs = []
def job(key, **kw):
    kw["key"] = key
    jobs.append(kw)

# --- Ingredients
job("ing_bun", file=B + "/food/AST-001_Bun.blend", show=["Bun_Open"], view=[0.6, 1.0, 0.9])
job("ing_sausage", file=B + "/food/AST-002_Sausage.blend", show=["Sausage_Grilled"])
job("ing_ketchup", file=B + "/food/AST-004_KetchupBottle.blend", show=["Bottle", "Cap", "Fill"], view=[0.6, 1.0, 0.35])
job("ing_mustard", file=B + "/food/AST-005_MustardBottle.blend", show=["Bottle", "Cap", "Fill"], view=[0.6, 1.0, 0.35])
job("ing_cheese", file=B + "/food/AST-006_Cheese.blend", show=["Cheese_Slice"], view=VHI)
job("ing_bacon", file=B + "/food/AST-007_Bacon.blend", show=["Bacon_Pile"], view=VHI)
job("ing_potato_sticks", file=B + "/food/AST-008_PotatoSticks.blend", show=["PotatoSticks_Pile"], view=[0.75, 1.0, 0.7])
job("ing_cream_cheese", file=B + "/food/AST-009_CreamCheese.blend", show=["CreamCheese_Jar"], view=[0.6, 1.0, 0.45])
job("ing_coffee", file=B + "/equipment/AST-022_CoffeeMachine.blend", show=["Jar", "JarHandle", "Coffee"], view=[0.7, 1.0, 0.35])

# --- Tools
job("tool_hot_dog", file=B + "/food/AST-003_HotDog.blend", show=["HotDog_Display"])
PK = {  # AST-011 table: shape + dominant colour (style guide 2.1)
    "pack_sausages": ("Carton", ["#7E3519", "#E08A55"]),
    "pack_buns": ("Bag", ["#B9803E", "#F4D9A0"]),
    "pack_ketchup": ("Can", ["#A8261B", "#F07A6A"]),
    "pack_mustard": ("Can", ["#C98E12", "#FFE07A"]),
    "pack_cheese": ("CartonSmall", ["#D9961A", "#FFE58A"]),
    "pack_bacon": ("BagFlat", ["#A8402E", "#F3B7A0"]),
    "pack_potato_sticks": ("Bag", ["#C98E12", "#F7D27A"]),
    "pack_cream_cheese": ("CanSmall", ["#256E7A", "#FFF8EC"]),
    "pack_coffee": ("Bag", ["#3B2519", "#8A5A3E"]),
}
for k, (shape, col) in PK.items():
    job("tool_" + k, fbx=[{"path": I + "/food/AST-011_%s.fbx" % shape, "tint": col, "tint_mode": "ramp"}], view=V34)
job("tool_coffee", file=B + "/food/AST-010_Coffee.blend", show=["Handle"], view=[0.6, 1.0, 0.45])
job("tool_rescue_whistle", file=B + "/market/AST-051_ReviveKit.blend", show=["Handle"], view=[1.0, 0.75, 0.45])

# --- Upgrades
SAUS = B + "/food/AST-002_Sausage.blend"
slots_x = [-1.35, -0.45, 0.45, 1.35]
for lvl, n in ((1, 2), (2, 3), (3, 4)):
    app = []
    for i in range(n):
        app.append({"file": SAUS, "objs": ["Sausage_Grilled"], "rot": [0, 0, 90], "loc": [slots_x[i], 0.52, 0.0], "snap_top": "Grill_L%d" % lvl})
    job("upg_grill_%d" % lvl, file=B + "/equipment/AST-012_RollerGrill.blend", show=["Grill_L%d" % lvl], append=app, view=V34)
job("upg_cooler_1", file=B + "/equipment/AST-018_CoolerL1.blend", show=["Body", "Lid"], view=V34)
job("upg_cooler_2", file=B + "/equipment/AST-018_CoolerL2.blend", show=["Body", "Lid_L", "Lid_R"], view=V34)
job("upg_cooler_3", fbx=[{"path": I + "/equipment/AST-018_CoolerL3.fbx"}], view=V34)
CS = I + "/equipment/AST-019_CounterStraight.fbx"
CC = I + "/equipment/AST-019_CounterCorner.fbx"
ST = I + "/equipment/AST-019_Stool.fbx"
job("upg_counter_1", fbx=[{"path": CS}], view=V34)
job("upg_counter_2", fbx=[{"path": CS, "loc": [-1.6, 0, 0]}, {"path": CS, "loc": [1.6, 0, 0]},
                          {"path": ST, "loc": [-1.6, 2.4, 0]}, {"path": ST, "loc": [1.6, 2.4, 0]}], view=V34)
job("upg_counter_3", fbx=[{"path": CS, "loc": [-1.6, 0, 0]}, {"path": CS, "loc": [1.6, 0, 0]}, {"path": CC, "loc": [4.8, 0, 0]}, {"path": CS, "rot": [0, 0, 90], "loc": [4.8, -3.2, 0]},
                          {"path": ST, "loc": [-1.6, 2.4, 0]}, {"path": ST, "loc": [1.6, 2.4, 0]}], view=V34)
job("upg_cash_drawer_lock", file=B + "/equipment/AST-020_CashRegister.blend", show=["Register", "Drawer", "Lock"], view=V34)
job("upg_trailer_lights", file=B + "/equipment/AST-023_TrailerLights.blend", show=["Lights_Mast", "Lights_Mast_Lamps"], frame=["Lights_Mast_Lamps"], zoom=0.75, view=[0.6, 1.0, 0.3])
TR = ["Body", "Awning", "Chassis", "Door_Back", "Door_Glass", "Steps", "Wheel_DoorSide", "Wheel_WindowSide", "Shelf_Fold"]
job("upg_food_trailer", file=B + "/vehicle/AST-027_OpenLateTrailer.blend", show=TR, view=[0.9, 1.0, 0.45])
job("upg_coffee_machine", file=B + "/equipment/AST-022_CoffeeMachine.blend",
    show=["Body", "Button", "Coffee", "Jar", "JarHandle", "ReadyLamp"], view=V34)

# --- Classes (High portrait = Day head + Normal face, DEC-167; crew cap on)
SP = [("class_dog", "Dog"), ("class_rabbit", "Rabbit"), ("class_cat", "Cat"), ("class_bear", "Bear"),
      ("class_fox", "Fox"), ("class_owl", "Owl"), ("class_panda", "Panda"), ("class_lion", "Lion")]
for key, a in SP:
    show = ["Head_" + a, "Ears_" + a, "Face_" + a, "REF_Cap"]
    if a == "Owl": show.append("Beak_Owl")
    if a == "Lion": show.append("Mane_Lion")
    job(key, file=B + "/character/AST-053_Animal_%s.blend" % a, show=show, view=VFACE)

# --- HUD / notices from models
job("hud_phone", file=B + "/equipment/AST-042_VehiclePhone.blend",
    show=["Phone_Trailer", "Trailer_Handset", "Trailer_Cord", "Trailer_Lamp"], view=[0.55, 1.0, 0.3])
job("hud_ambulance", file=B + "/vehicle/AST-052_Ambulance.blend",
    show=["Body", "Door_RearL", "Door_RearR", "Headlights", "Lightbar_L", "Lightbar_R", "Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"],
    view=[1.0, 0.8, 0.5])
job("note_lock", file=B + "/equipment/AST-020_Padlock.blend", show=["Padlock"], view=[0.35, 1.0, 0.2])
job("note_trailer", file=B + "/vehicle/AST-027_OpenLateTrailer.blend", show=TR, view=[1.0, 0.55, 0.35])

json.dump(jobs, open(os.path.join(HERE, "jobs.json"), "w"), indent=1)
print(len(jobs), "jobs")
