# Material pass: from "2010 Flash" to textured, lit UI

User verdict on a gradients-only RPG screen: *"muito cruas… apenas um gradiente não é o suficiente e os adornos
parecem jogos flash do ano 2010"*. This is the fix that was built and verified in Studio (2026-10-05):
`templates/example_rpg_inventory_v2.luau`, `templates/blender_ui_kit.py`, `templates/example_material_pass.py`.

## Why flat UIs read as dated
1. No material: color + linear gradient = plastic. 2. Ornaments are unlit vector lines (uniform stroke, flat
gold) = clipart. 3. No depth (nothing recessed or raised, no shadows). 4. Gold outline on everything (no rest for
the eye). 5. Placeholder item art.

## The layers (apply in this order, measure each in a before/after crop)
| Layer | How | Notes |
|---|---|---|
| Material texture | Poly Haven CC0 texture (via Blender MCP `download_polyhaven_asset`), graded in Python: luminance normalized by std (grain) + normal-map relief lit from the UI key-light direction, multiplied onto a dark base color; 512 px seamless tile, `ScaleType.Tile` 256 px | Check seams (wrap-around delta). Contrast ~2% luminance std on a dark base is enough; compressing more made it invisible |
| Lit ornaments | Blender kit: forged band (bevelled slab), iron plates, gold rods, faceted gems, metallic gold with noise roughness, HDRI + warm key (top-left) + warm rim; ortho, transparent film, 2x | 9-slice source drawn small (panel 200x200, corners 64). Fewer, chunkier pieces beat thin filigree; rivets > floating curls |
| Drop shadows | blurred alpha of the ornament, **black RGB**, offset (+2..3, +4..6) in Roblox, sibling under the art | Do NOT run white alpha-bleed on shadow PNGs: it turned the shadow into a white halo (seen in Studio) |
| Panel shadow on the world | 9-slice soft dark rect (256 px, margin 96) behind the panel | |
| Recessed slots | dark well + inner-shadow 9-slice (darker toward the top = light from above) + faint lit lip at the bottom + 1 px gold-lo stroke @0.55 | Replaced gold corner ticks on every slot |
| Atmosphere | ember glow from the bottom + vignette (gradients) **on top of** the texture | Gradients are the finishing layer, not the material |
| Life | ember specks tile, `ImageColor3` ember, gradient fade, looping tween scrolling up (static in edit-mode captures) | |
| Engraved title | UIGradient on the TextLabel (light gold → dark gold) + dark UIStroke | |

## Blender gotchas (MCP for Blender add-on)
- Work in an isolated scene; the HDRI download assigns the world of the ACTIVE scene (side effect — report it).
- Poly Haven texture downloads go to a temp folder that is deleted after import: save the images from Blender
  (`img.copy()` → `filepath_raw` → `save()`) before using them outside.
- Cycles under-reported by RNA: set it in try/except.
- Dark non-metal under the strong key light: albedo ~0.004 (0.018 rendered grey); flat plates facing the camera
  mirror the HDRI zenith → roughness 0.9, specular 0.08. Gold: base (1.0, 0.56, 0.16), metallic 1, roughness 0.3
  with noise variation. Gems: deep red base, low emission (0.35), roughness 0.02 — strong emission = plastic.
- Iterate on the render with a corner zoom over a dark background before uploading.

## Still missing after the pass (say so in reports)
Real item icons and character render; animated embers only visible in play; per-rarity frame variants.
