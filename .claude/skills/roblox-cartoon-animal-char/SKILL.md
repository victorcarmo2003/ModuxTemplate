---
name: roblox-cartoon-animal-char
description: Build a custom cartoon ANIMAL character for Roblox (R6 custom rig, chibi round head with snout/chin volume, eyes/nose/mouth by texture with swappable expressions, textured outfits with fur colour through alpha, day/night variants), the "HotDog Crew" pattern from Sell Hotdogs. Use when the user asks for a custom animal character, a new species, a mascot/NPC animal, new outfit or expression, or day/night variant of these characters. Pairs with roblox-asset-pipeline (export/upload/placement).
---

# Cartoon animal character (R6 custom, textured face)

Pattern proven in Sell Hotdogs (AST-053 HotDog Crew, 8 species: Dog, Cat, Rabbit, Fox, Bear, Panda, Turtle, Owl).
Reference image of the target look: `Assets/reference/customrig.png` in that project (chibi animal, cap, apron).

**Rule:** one common body + one round head mesh per species + accessories (ears/tail/extras). Every face feature is
TEXTURE, never modelled. Expressions and day/night are texture swaps. Verify in Studio, not only in Blender.

Read `roblox-asset-pipeline` first for the generic loop (headless Blender wrapper, export convention 180° about Z,
`global_scale 0.01`, Open Cloud upload, `InsertService:LoadAsset`, Studio probes). This skill adds the character part.

## Loop

| Step | What | Script (this skill) | Reference |
|---|---|---|---|
| A | Brief: species list, colours (fur, secondary, hand), ears up/floppy/none, extras (shell, beak), outfits (crew/civil), day+night | `templates/colors_example.json` | spec.md |
| B | Common R6 body (exact R6 boxes, joint origins, attachments) | `scripts/body/crew_base.py` | spec.md |
| C | Pose test (wave, hold tool, run 45-60°) + penetration report | `scripts/body/crew_pose.py`, `overlap_crew.py` | verification.md |
| D | Outfit UV unwrap (512² sheets) + procedural paint (fur = alpha 0) + materials/FBX | `scripts/outfit/unwrap.py`, `paint_outfit.py`, `build_outfit.py` | textures.md |
| E | Accessories per species (ears, tail, shell, beak) on the colour atlas | `scripts/accessories/animals.py` (+`crewlib.py`) | spec.md |
| F | Round heads: lattice + compact oval snout + round chin + face shell with standard UV | `scripts/heads/geom.py` (+`hcommon.py` params) | heads.md |
| G | Paint head marks (T_Head_<A>[_Night]) + expression sheets (T_Expr_*) | `scripts/heads/paint_heads.py` (system Python) | heads.md, textures.md |
| H | Checks: eye stretch, cap clearance, ear gap, 60°/75° eye renders | `facecheck.py`, `capcheck.py`, `finish.py` (renders `_e60/_e75`), `views.py` | verification.md |
| I | Save .blend + FBX, joints JSON (Neck C1 per species, attachments, UV notes) | `finish.py`, `heads/joints.py`, `body/joints_base.py` | roblox.md |
| J | Night atlas for atlas-coloured accessories | `scripts/py/night_atlas.py` | textures.md |
| K | Export (pipeline exporter), upload FBX (rbx_upload) + PNGs (Studio `upload_image` via local http server) | roblox-asset-pipeline | roblox.md |
| L | Assemble in Studio: `Crew.build`, expressions templates, `Crew.setExpression`; demo row; captures front/3-4/profile | `scripts/studio/build_crew.luau` | roblox.md |
| M | Write user tweaks back to sources; record lessons | — | lessons.md |

## Running the scripts

They are the reference implementation from Sell Hotdogs (asset ids `AST-053_*`, KitchenPack atlas). Adapt names and
paths per project; paths come from env vars:

```sh
export CHAR_PROJECT="D:/Game"            # project root (has Assets/)
export CHAR_WORK="<scratchpad>/chars"    # work dir (layouts, renders, work_<A>.blend under heads/)
BL=~/.claude/skills/roblox-cartoon-animal-char/scripts/bl.sh   # WMI-safe headless Blender
ANIMAL=Dog sh $BL scripts/heads/geom.py          # Blender steps
ANIMAL=Dog python scripts/heads/paint_heads.py all   # numpy/PIL steps (system Python)
ANIMAL=Dog NOSAVE=1 sh $BL scripts/heads/finish.py    # renders only; without NOSAVE saves .blend + FBX
```
Species parameters live in `scripts/heads/hcommon.py` (`RINGS`, `A` per-animal tweaks, `SNOUT3`, eye/nose/mouth
heights, face UV) and `colors.json` (fur/hand colours). Accessory recipes per species in `accessories/animals.py`.

## Non-negotiables (each one cost a round of user feedback)

- Head = ONE smooth oval mesh with snout volume; no modelled eyes/nose/mouth; no boxy heads.
- Eyes sit on a FLAT area: the snout bump is compact and ends below the eyes, and continues down into a round chin
  (no pointy nose, no eyes sliding down the snout slope in profile).
- Enough rings in the eye/snout zone (26 az × 14 rings ≈ 728 tris) or facets/diagonal creases show in Roblox.
- Face shell normals = the head's normals (no shading seam); shell only on front-facing faces.
- Eyes: tall ovals, narrow, ONE small white highlight top-right. Check at 60° and 75°, not only front.
- Night must cover every piece (head texture, outfit texture AND night atlas for ears/tail/shell/beak/cap).
- Roblox renders a partial-alpha overlay on a MeshPart TextureID almost opaque: judge night colours in Studio.
- When the head grows, move every accessory that rides on its attachments (cap +0.30 with HatAttachment).
- Third-party pieces only with verified licence (see roblox-asset-pipeline / project credits).

## Budget (measured)
Body (torso, limbs, apron) ≈ 570 + Cap 224 / Cap_EarsUp 280; head 728; face shell 185-220; ears/tail/extras 50-370.
Full character ≈ 2.0-2.5k tris (measured on 18 species) — above a 1.8k "common NPC" ceiling: raise it or thin the back of the head.
Textures: outfit 512² + head 512² + expression 512² per state (RGBA ≈ 340 KB GPU each), ×2 for night.

## Many species at once
Parallel agents work well when each one copies `scripts/` into its own work dir, edits only its copy, runs with
`ANIMAL=<its species>`, writes only files named after its species and never repaints the shared `T_Expr_*`
(`paint_heads.py heads`, not `all`). Merge joints JSON and upload/assemble centrally afterwards.
