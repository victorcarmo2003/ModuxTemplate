"""Reference renders of AST-059 on the Sheep (Workbench, texture colours). Output Assets/reference/AST-059_Acc_Raincoat_*.png

  sh bl.sh tools/blender/character/render_ast059.py [-- <blend> <suffix_dir>]
Atlas swap test: also renders the cape with the Night atlas (what Dress would do without a KeepAtlas exception)."""
import bpy, math, sys
from mathutils import Vector

ROOT = "D:/UserData/Documents/ModuxGames/Sell Hotdogs/Assets/"
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
bpy.ops.wm.open_mainfile(filepath=args[0] if args else ROOT + "blender/character/AST-059_Acc_Raincoat.blend")
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sh = sc.display.shading
sh.light = "STUDIO"; sh.color_type = "TEXTURE"; sh.show_cavity = False
sh.studio_light = "studio.sl" if "studio.sl" in [s.name for s in bpy.context.preferences.studio_lights] else sh.studio_light
sc.display.shading.show_shadows = False
sc.render.resolution_x = sc.render.resolution_y = 800
sc.render.film_transparent = False
w = bpy.data.worlds.new("W"); w.use_nodes = False; w.color = (0.82, 0.86, 0.9); sc.world = w
sc.view_settings.view_transform = "Standard"
for m in bpy.data.materials:
    for n in m.node_tree.nodes if m.use_nodes else []:
        if n.type == "TEX_IMAGE":
            n.interpolation = "Closest" if "restaurantbits" in (n.image.filepath if n.image else "") else n.interpolation

cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = "ORTHO"; cam.data.ortho_scale = 9.2
target = Vector((0, -0.2, 3.7))


def shot(name, direction):
    d = Vector(direction).normalized()
    cam.location = target + d * 30
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = ROOT + "reference/AST-059_Acc_Raincoat_" + name + ".png"
    bpy.ops.render.render(write_still=True)


def show(hide_acc=False):
    for o in bpy.data.objects:
        if o.name.startswith("Acc_"):
            o.hide_render = hide_acc


shot("Front", (0, 1, 0.12))
shot("ThreeQuarter", (0.8, 0.75, 0.22))
shot("Back", (0, -1, 0.15))
shot("Side", (1, 0, 0.1))
# without the cape: the Sheep alone, for comparison
show(True); shot("Bare_Front", (0, 1, 0.12)); show(False)
# Night atlas swap (shows why the piece must keep the Day atlas)
night = bpy.data.images.load(ROOT + "textures/character/T_Atlas_Kitchen_Night.png")
for o in bpy.data.objects:
    if o.name.startswith("Acc_"):
        for m in o.data.materials:
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE":
                    n.image = night
shot("NightAtlasSwap_ThreeQuarter", (0.8, 0.75, 0.22))
