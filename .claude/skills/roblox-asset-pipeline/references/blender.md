# Blender work (headless)

## Running

- Use `sh scripts/blender/bl.sh script.py -- args`. On Windows a hung WMI service (`winmgmt`) makes every new
  Blender freeze before running the script (Python's platform module queries WMI). The wrapper puts
  `scripts/blender/nowmi/_wmi.py` (raises ImportError) on PYTHONPATH with `--python-use-system-env`, so Python
  falls back. Symptom: blender.exe processes that never print; `tasklist`/`wmic` also hang - do not use them.
- `--factory-startup` gives an empty, predictable scene; never touch the user's live Blender for batch work
  (live MCP only for things the user watches). Kill only your own stuck processes.
- Parallel agents may each run their own headless Blender; they must write different files.

## Model-in-style method (toylib)

`exec(open(".../scripts/blender/toylib.py").read())` then `reset(atlas_path)`:
- `box(name, size, center, band, bevel, rot, drop)` - chamfered box; `drop=[(0,0,-1)]` removes hidden faces.
- `cyl(name, d, length, center, axis, band, segs=8, d2=None, bevel)`, `torus(...)`, `tube(name, pts, r, band)`.
- `uv_band(obj, (row, col[, lo, hi]))` maps all faces into one gradient band of an 8×4 atlas, v following the
  object's height (light on top). Pick `lo/hi` to use only the light half when the band ends dark/brownish.
- `empty(name, loc, parent)` for attachments; `join(parts, name)`; `entry(label, root)` → bridge JSON (preview);
  `render(path, objs, direction)`; `save_export(blend, fbx, entries, json_name)`.
Toy rules that worked: thick shapes, bevel ~8-12% of the smallest side, nothing interactive < 0.2 stud,
first-person readability (eye 4.5, counter 3.5 → keep machines low; a real roller grill is taller than the eye).

## Editing pack meshes (bmesh recipes)

- **Bake transforms first**: `o.data.transform(o.matrix_world)`; if `matrix_world.determinant() < 0`
  (mirrored glTF nodes - e.g. half the cartons of a Mini Market shelf) call `o.data.flip_normals()`,
  else faces end up inverted in Roblox.
- **Find islands** (connected components) to delete content (burger buns + sesame seeds = 236 islands): delete
  islands above the floor and smaller than X, then add new content (hot dog buns) from another pack.
- **Fill a hole like the user does (F + Ctrl+T)**: remove the dent island, `remove_doubles` to weld seams,
  `holes_fill` only on the boundary loop you want (filter by radius/height or it also caps outer rims),
  `triangulate(BEAUTY)`, then copy each cap vertex's UV from the same vertex on the neighbouring face (a fixed UV
  makes a visible lighter disc).
- **Rebuild instead of decimating** when a pack piece is over budget (crate 1,880 tris → 13 boxes = 156 tris,
  same wood band). `dissolve_limit` barely helps on bevelled planks.
- **Stretch only what grows**: KayKit furniture is 1:2 height:width; to reach a 2.3 bar stool, scale uniformly
  by width, then move the seat stack up and stretch only the post vertices.
- Re-measure the real geometry before trusting numbers from another agent (an "~2 stud cargo" was really 8.37).

## Budgets / checks

- Count tris after triangulation; report per part. Prop small ≤ 500, medium ≤ 1,200, station ≤ 1,500,
  car ≤ 2,000 (wheels are the bulk - 14-sided wheels halve them), building ≤ 2,500, vehicle shell ≤ 3,500-4,000,
  character ≤ 2,000 (use the project's table).
- `overlap_check.py`: BVH overlap between islands/objects; z-fight = same-facing (dot > 0.999), same plane
  (< 0.003) and **real overlap area** (> 1e-4; edge-only contact is not z-fight). Back-to-back contact faces are fine.
- `fix_zfight.py` pushes the smaller island EPS (0.004) along the shared normal; triangulate before detecting.
- Multi-variant files (Rail_6 + Rail_8 at the same origin) report false z-fights - fine, document.
- Interpenetration the checker cannot judge (a crank arm through its knob): render close-ups from 3-5 angles
  and fix geometry (move the knob to the outer face of the arm).
