"""Bake flat material colours into a palette texture so a pack model keeps its colours in Roblox.

Many Poly Pizza / Quaternius / Kenney (older kits) models colour faces with plain material colours. The Roblox FBX
import keeps one texture per MeshPart, not per-material colours, so those models come in white. This script imports
each model, gives every distinct material colour one texel of a small palette image, points the UVs of that
material's faces at its texel, replaces all materials by one material using the palette, and writes a .glb that
export_import.py (roblox-asset-pipeline) then handles like an atlas model.

  sh bl.sh tools/blender/palette_bake.py -- --out <dir> <model.glb|.gltf|.fbx> [...]
Output: <dir>/<stem>.glb and <dir>/<stem>_palette.png
"""
import bpy
import os
import sys

argv = sys.argv[sys.argv.index("--") + 1:]
out_dir = argv[argv.index("--out") + 1]
paths = [a for i, a in enumerate(argv) if a != "--out" and (i == 0 or argv[i - 1] != "--out")]
os.makedirs(out_dir, exist_ok=True)
SIZE = 16  # 256 colours max


def material_color(m):
    if m is None:
        return (0.8, 0.8, 0.8, 1.0)
    if m.use_nodes:
        bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf:
            c = bsdf.inputs["Base Color"].default_value
            return (c[0], c[1], c[2], 1.0)
    c = m.diffuse_color
    return (c[0], c[1], c[2], 1.0)


for path in paths:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    low = path.lower()
    if low.endswith((".glb", ".gltf")):
        bpy.ops.import_scene.gltf(filepath=path)
    elif low.endswith(".fbx"):
        bpy.ops.import_scene.fbx(filepath=path)
    else:
        bpy.ops.wm.obj_import(filepath=path)
    stem = os.path.splitext(os.path.basename(path))[0]
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    colors = []
    index = {}
    for o in meshes:
        for m in o.data.materials:
            c = tuple(round(v, 4) for v in material_color(m))
            if c not in index:
                index[c] = len(colors)
                colors.append(c)
    img = bpy.data.images.new(stem + "_palette", SIZE, SIZE, alpha=False)
    px = [0.0] * (SIZE * SIZE * 4)
    for i, c in enumerate(colors[: SIZE * SIZE]):
        x, y = i % SIZE, i // SIZE
        k = (y * SIZE + x) * 4
        # palette stored linear in Blender; the glTF exporter writes sRGB PNG
        px[k:k + 4] = list(c)
    img.pixels = px
    img.filepath_raw = os.path.join(out_dir, stem + "_palette.png")
    img.file_format = "PNG"
    img.save()
    mat = bpy.data.materials.new(stem + "_palette")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    for o in meshes:
        me = o.data
        uvl = me.uv_layers.active or me.uv_layers.new(name="UVMap")
        mats = list(me.materials)
        for p in me.polygons:
            m = mats[p.material_index] if p.material_index < len(mats) else None
            i = index[tuple(round(v, 4) for v in material_color(m))]
            u = ((i % SIZE) + 0.5) / SIZE
            v = ((i // SIZE) + 0.5) / SIZE
            for li in p.loop_indices:
                uvl.data[li].uv = (u, v)
        me.materials.clear()
        me.materials.append(mat)
    out = os.path.join(out_dir, stem + ".glb")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB")
    print("baked", stem, len(colors), "colours ->", out)
