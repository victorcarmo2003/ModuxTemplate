# QA checklist - run BEFORE you hand a model to the owner

Born from Sell Hotdogs AST-061 / AST-059 (2026-10-14): a bite that was invisible at game distance, inverted normals on
every procedural mesh, a Night atlas swap that turned a yellow coat black. All were visible in a 10-second check that
was skipped. Report each item as checked / not checked, never "looks fine".

## A. Geometry (Blender, headless script, numbers in the report)
1. **Normals outward.** After building any procedural mesh (ellipsoid, tube, cone, boolean result) run
   `bmesh.ops.recalc_face_normals` and then VERIFY: for each island cast rays from face centres along the normal; count
   faces that point inward. Target 0. Script-built primitives usually come out 80-90% inverted (AST-061: 80/84 of ~90 faces).
   After a boolean, recalc again, then check non-manifold edges (open cones on purpose: orient them by hand).
2. **Object matrix determinant > 0** and transforms applied before export (a mirror flips winding).
3. **Tris within the sheet budget**, per piece, printed. Duplicates removed (`remove_doubles`).
4. **Pivot / bbox in studs** printed and compared with the sheet; base-centre pivot unless the sheet says otherwise.
5. **Thin or open pieces** (worms, legs, drips): closed solids, or double-sided on purpose; never single-sided planes.

## B. Reads at game distance (render, look at it yourself)
6. **Three renders minimum**: 3/4, top, and the angle the player really sees (first person eye height / game camera).
7. **Distance test**: shrink the render to the size the object has on screen (or view from 6-8 studs). A feature smaller
   than ~5% of the piece (a bite, a stud, a button) does not exist for the player: exaggerate it.
8. **Contrast test**: the feature must differ from its surround in value, not only in hue (cream bite on a cream crumb
   disappears). Convert the render to grayscale and check.
9. **Silhouette test**: black fill render; the thing must still be readable (a cockroach, a hood).

## C. Roblox side (Studio, after import)
10. **Scale convention**: `models/` FBX (scaling 100 in the nodes) and `import/` FBX (global_scale 0.01, no Lcl Scaling)
    are NOT interchangeable. Upload only the `import/` form; measure with `LoadAsset` (known size must match, e.g. the
    sausage 1.2 studs).
11. **Every pack variant**: accessories go through `Dress`, which swaps the atlas TextureID per pack. Check the piece in
    Day, Mid AND Night: a colour cell can turn near-black in another pack's atlas (yellow coat -> black in Night). Fix with
    a keep-atlas rule or its own texture, not by hoping.
12. **From below and inside**: orbit under the piece; inverted faces show as missing surfaces. Place a clone upside down if
    the camera cannot go under (the Studio camera can be blocked by the floor).
13. **Joints in motion**: for accessories on rigs, pose the arm swing and the walk: arm radius vs coat width, legs vs hem.
14. **Textures present** (not blank while moderation runs: wait and recapture), textures non-opaque where alpha matters.

## D. Process
15. Do not drive the live Blender MCP scene with destructive calls (`read_factory_settings`, `wm.read_homefile`): they
    drop the MCP connection and can wipe the owner's work. Build headless and render with `bl.sh`.
16. Upload only after the owner approves the look; obsolete textures are not uploaded.
17. Record in the sheet (Provisional / In review) the ids, tris, bbox and what was NOT checked.
