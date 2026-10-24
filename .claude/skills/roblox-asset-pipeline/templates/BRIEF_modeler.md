# Common brief - modeller agents (copy into the project's scratch/work folder and fill the <...>)

Style: <project style rule, e.g. toy low-poly Kenney/KayKit, colour ONLY from pack atlases>.
Read first: <style guide sections>, your sheets in <asset list>, and any decision about them.

**Do NOT edit docs/** (the recorder writes decisions). Only asset files. Do not touch other agents' files.

## Method (mandatory)
- Headless Blender through the WMI-safe wrapper: `sh <skill>/scripts/blender/bl.sh script.py -- args`
  (never the user's live Blender; kill only your own stuck processes; never use tasklist/wmic).
- Helpers: `exec(open("<skill>/scripts/blender/toylib.py").read())`, `reset("<atlas.png>")`, `box/cyl/torus/tube`,
  `uv_band(obj, (row, col[, lo, hi]))`, `empty`, `set_origin`, `render`, `entry`.
- 1 unit = 1 stud. Blender **+Y = front**. Pivot = base centre (Tools: grip + Empty `Att_Hand`).
- Glb/gltf pack pieces: bake `matrix_world` into the mesh; flip normals when the determinant < 0.
- Colour only from the family atlas: <atlas path(s) and useful bands>.
- Moving / state / transparent / neon pieces = separate objects with their own pivot (lid, door, Fill, lamp).
- Thick shapes, chamfer ~8-12%, nothing interactive < 0.2 stud, within the sheet's tris budget.

## Quality gates (before delivering)
- `sh bl.sh <skill>/scripts/blender/overlap_check.py -- --root <Assets/blender> --files <yours>` → zfight_pairs = 0.
- Renders: 3/4, front, first-person (eye 4.5 over the real surface), close-ups of every joint; LOOK at them.
- Nothing floating, nothing leaking (liquids inside containers), handles connected to bodies.

## Delivery
- `<Assets>/blender/<cat>/AST-###_<Name>.blend` + `<Assets>/models/<cat>/AST-###_<Name>.fbx` (work FBX).
- Previews: `<scratch>/previews/AST-###_<Name>*.png`. Bridge JSON (optional): `<scratch>/rbx/AST-###_<Name>.json`.
- Answer: per sheet → paths, tris per part, final dimensions, pivots/attachments, deviations from the sheet.
