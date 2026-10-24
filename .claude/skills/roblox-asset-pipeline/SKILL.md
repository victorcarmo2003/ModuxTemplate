---
name: roblox-asset-pipeline
description: End-to-end 3D asset pipeline for Roblox games - source free/CC0 models (Kenney, KayKit, Poly Pizza, Sketchfab), check licences, build approval boards, edit or model low-poly assets in Blender (headless, atlas-coloured), export FBX that land in Roblox at the right scale/orientation with textures, upload them through Open Cloud, place them on a map from a placement table (replacing a blockout), verify in Studio (captures, raycast probes, z-fight checks) and assemble custom R6 characters (animal/humanoid rigs, outfit textures, day/night variants). Use whenever the task is "make/replace/import/place 3D assets or props in Roblox", "build the map with real assets", "find free models", "model X in Blender for Roblox", "custom rig / R6 character", or anything that turns blockout Parts into real meshes. Prefer this over ad-hoc Part building for anything that should look like a finished prop.
---

# Roblox asset pipeline - from free model / Blender to placed in the map

Building props out of stacked Parts looks artificial (a cup whose coffee leaks out, a handle that is a floating
brick). This skill replaces that with a pipeline that was proven on a full game map (Sell Hotdogs, 2026-10):
~100 assets sourced/edited/modelled, uploaded, 210 placements, characters with textures - all verified in Studio.

**The rule:** every asset is decided *source first* (pack → library → model), approved on a board by the user,
then goes through ONE export convention and is verified *in Studio*, never only in Blender.
**The loop:** map → source → board → approve → build/edit → check → export → upload → place → verify → lapidate.

## 0. Context first (always)

1. Read the project's art rules before touching anything: style guide (palette, shape language, tris budgets,
   texture budget), asset list / sheets (IDs, sizes in studs, pivots, attachments), level doc (coordinates),
   decisions log. **Project docs outrank this skill.** If the project has an approval process (decisions log,
   secretary agent), use it: agents propose, the user decides, a recorder writes it down.
2. Check the toolchain once per session: `scripts/blender/bl.sh` (headless Blender), Studio MCP connected
   (`list_roblox_studios`), Blender MCP (only for the live scene the user watches), Open Cloud API key
   (`ROBLOX_API_KEY` user env var - never print it), Python with Pillow/numpy.
3. Find what already exists: asset packs in the repo (`Assets/<Pack>`), previous exports (`Assets/import`),
   placement tables (`tools/assetplace`), id maps (`_asset_ids.json`).

## 1. The loop

```
 A. MAP        every sheet (AST/ID) → candidate file or "model" (references/sourcing.md)
 B. BOARD      render candidates with one camera/light → approval boards per category (scripts/py/board.py)
 C. APPROVE    user approves / swaps / asks edits → record (decisions log) → sheet status Approved
 D. BUILD      pack as-is | pack + edit | model in style (references/blender.md); parallel agents (references/orchestration.md)
 E. CHECK      overlap/z-fight checker = 0, tris within budget, renders incl. first-person + close-ups of joints
 F. EXPORT     scripts/blender/export_import.py → Assets/import/<cat>/*.fbx (scale 0.01, rotate 180, textures embedded)
 G. UPLOAD     scripts/py/rbx_upload.py (Open Cloud, group or user creator) → _asset_ids.json
 H. PLACE      placement table + scripts/studio/place_assets.luau (hides blockout, reversible, day/night layers)
 I. VERIFY     Studio captures + raycast probes (orientation), fix table, re-run (references/verification.md)
 J. LAPIDATE   user reviews in Studio; fixes go back to the .blend / table, never patched by hand in Studio only
```

Calibrate once per project before mass upload: export `_Calibration_Cube_1stud.fbx`, upload, LoadAsset, measure
(must be 1×1×1) and probe the front of one real asset (must face -Z). Two of the worst bugs of the first run
(100× scale, 180° flipped) were caught exactly here - see references/roblox-import.md.

## 2. Source decision (the core rule)

| Need | Choose | Why |
|---|---|---|
| Generic prop that a pack has (food, crates, shelves, roads, buildings, cars) | **Pack as-is**, scaled to the sheet | cheapest, coherent |
| Pack piece close but wrong (burger buns in a crate, stove instead of roller grill, dent in a seat, too many tris) | **Pack + edit** in Blender (swap content, remove islands, fill holes, rebuild the heavy part) | keeps the family look |
| Nothing in the chosen family | **Model in style** with the atlas method (references/blender.md) | coherent with packs |
| Library model (Poly Pizza/Sketchfab) | only same-family authors, CC0 or CC-BY (credited), no brands | mixing authors breaks the style |
| AI generator | last resort, one object, still atlas-recoloured | inconsistent topology/style |

Pick **1-2 coherent families** (e.g. Kenney + KayKit, both CC0, gradient-atlas colour). The user compared
"painted texture" vs "pack atlas as-is" side by side in Studio and chose the pack atlas - test, don't assume.
Characters are the exception: outfit/face textures are fine there (references/characters.md; full workflow in the skill `roblox-cartoon-animal-char`).

Hard bans:
- **Never** ship Parts stacked to fake curved/hollow shapes (handles, cups, rings) - model or CSG them.
- **Never** a part floating or a liquid leaking through its container; **never** coplanar same-facing faces.
- **Never** stretch a pack piece non-uniformly when it has bevels/feet you can see (stool with a tall cushion);
  stretch only the part that should grow (the post), keep the rest uniform.
- **Never** import a model whose licence you did not verify; record CC0/CC-BY in the credits doc.
- **Never** reproduce brands (real cars' emblems, medical crosses, logos, real products) - recolour/remove.

## 3. Conventions (one set, everywhere)

- 1 Blender unit = 1 stud. Blender **+Y = front** of the asset; pivot = **base centre** (Tools: grip point).
- Colour from **one atlas per family** via UV bands (`uv_band`), no new textures for props.
- Every moving / state / transparent / neon piece is its **own object** with its own pivot (lid, door, Fill, lamp).
- Names PascalCase English; attachments as Empties (`Att_*`, `Prompt_*`, `Mount_*`, `Light_*`, `VFX_*`, `Slot_*`).
- Export (handled by `export_import.py`): `global_scale=0.01`, geometry rotated 180° about Z before export
  (Roblox ignores FBX axis metadata), `path_mode=COPY, embed_textures=True`. In Roblox: size in studs,
  pivot base centre, **front = -Z (LookVector)**.
- Files: `Assets/blender/<cat>/AST-###_Name.blend`, `Assets/models/<cat>/...fbx` (work), `Assets/import/<cat>/...fbx`
  (final, embedded), `Assets/textures/<cat>/`, ids in `Assets/import/_asset_ids.json`.

## 4. Commands

| Step | Command |
|---|---|
| Headless Blender (Windows-safe) | `sh scripts/blender/bl.sh script.py [-- args]` (shadows a hung WMI; plain `blender -b` hangs then) |
| Thumbnails of candidates | `bl.sh scripts/blender/thumbs.py -- --jobs jobs.json --out thumbs/` |
| Approval board | `python scripts/py/board.py rows.json board.png "Title"` |
| Model in style | `exec` `scripts/blender/toylib.py` (box/cyl/torus/tube/uv_band/empty/render/save_export) |
| Overlap / z-fight check | `bl.sh scripts/blender/overlap_check.py -- --root Assets/blender [--files a.blend ...]` |
| Auto-fix z-fight | `bl.sh scripts/blender/fix_zfight.py -- --root Assets equipment/AST-020_X.blend ...` |
| Export import set | `bl.sh scripts/blender/export_import.py -- --root Assets --direct direct.json` |
| Upload (Open Cloud) | `python scripts/py/rbx_upload.py --group <id> --map Assets/import/_asset_ids.json files...` |
| Serve files to Studio | `python -m http.server 8772 --bind 127.0.0.1 --directory <repo>` (+ HttpEnabled, restore after) |
| Place on map | `scripts/studio/place_assets.luau` → `Place.run(placements, ids)`, `Place.restore()`, `Place.showLayer()` |
| Probes | `scripts/studio/probes.luau` (front-facing test, size check, lamp/arm alignment) |
| Character | `scripts/studio/build_crew.luau` → `Crew.build{ animal, outfit, time, fur, at }` |
| Quick preview without upload | `scripts/studio/preview_mesh.luau` (EditableMesh from bridge JSON; not saved with the place) |

## 5. Verification checklist (every batch)

- [ ] Sizes match the sheet (bbox printed by the export log / probe), pivot at base.
- [ ] `zfight_pairs = 0` (area-based checker); visible interpenetration checked on close-up renders.
- [ ] Tris within budget; heavy pack pieces rebuilt (crate 2,772 → 648).
- [ ] Rendered from the player's eye (first person, eye 4.5 over a 3.5 counter for a counter game).
- [ ] In Studio: front faces where it should (raycast probe, not eyeballing), textures present, nothing floating.
- [ ] Replaced blockout hidden, not destroyed; `Place.restore()` works.
- [ ] Licences/credits recorded; brand check done.
Report honestly what stayed blockout and why, and what needs the user's decision.
- [ ] Full pre-delivery QA (normals by ray test, distance/contrast/silhouette tests, Day/Mid/Night atlas, scale convention): `references/qa-checklist.md`.

## 6. Files

- `references/sourcing.md` - families, licences, Poly Pizza/Sketchfab, brand traps, approval boards
- `references/blender.md` - headless + WMI, atlas method, editing pack meshes, budgets, pitfalls
- `references/roblox-import.md` - export settings, calibration, Open Cloud upload, LoadAsset, textures
- `references/placement.md` - placement table format, runner, layers, orientation rules
- `references/verification.md` - captures, black viewport, probes, z-fight, detail pass
- `references/characters.md` - custom R6 rig (body/animal parts), joints, outfit textures, day/night
- `references/orchestration.md` - parallel modeller agents, brief template, approval loop, autonomous runs
- `references/qa-checklist.md` - pre-delivery QA, run before showing any model to the owner
- `references/lessons.md` - every failure seen so far and its fix (read before a new project)
- `templates/BRIEF_modeler.md`, `templates/direct_pack_example.json`, `templates/placements_example.luau`
