# Textures: outfits, fur, day/night

Characters are the exception to "no painted textures": the scenery stays on pack atlases.

## Outfit sheet — `scripts/outfit/unwrap.py` → `paint_outfit.py` → `build_outfit.py`
- Clean UV unwrap of Torso, arms, legs, Cap, Apron into one 512² "outfit" sheet (apron front denser for the logo).
  Roblox reads ONLY the first UV channel: put the paint UV first.
- `layout.json`: islands + triangles in pixel space with world positions; the painter rasterises each texel back to
  its rest position/normal and paints in 3D body space (stitches, folds, pockets, logo, shoes).
- **Fur by alpha**: alpha 0 texels = skin/fur (hands, neck) → the part's `MeshPart.Color` (= species fur) shows
  through; one outfit sheet serves every species. Semi-transparent dark pixels = shading/grime over fur.
- Outfits made: `T_Crew_Uniform_Day/Night` (red cap, red apron with original logo, cream shirt, black pants, shoes),
  `T_Civil_A/B_Day/Night` (civilian sets for NPC animals; apron removed for civil outfits).

## Day / night (texture swap only, same meshes)
- Day: cute, clean, big shiny eyes. Night: darker, desaturated, stains/grime (brown, never blood), small glowing
  pupils, droopy brows. Keep within the audience rating.
- Night needs ALL of: outfit night sheet, head night sheet, night expression, AND a night copy of the colour atlas for
  atlas-coloured accessories (`scripts/py/night_atlas.py`: fur tones → night fur, whites ×0.74 cool, reds like the
  night uniform). `Crew.build` swaps it (keeps `DayTextureID` attribute).
- **Roblox caveat:** a ~30% navy overlay painted with partial alpha rendered almost opaque on a MeshPart TextureID
  (night heads came out solid navy, the fox lost its orange). Blender previews blend it properly. If the species
  colour must survive at night, bake the night fur per species into opaque texels instead of relying on alpha.

## Upload
FBX textures with an alpha-mix material do not embed → upload the PNGs separately (Studio MCP `upload_image` from a
local http server on 127.0.0.1, then stop it) and keep `_texture_ids.json` (name → rbxassetid). Every repaint = new
upload = new id: update the json and rebuild the Studio templates.

## Memory
512² RGBA ≈ 1.3 MiB uncompressed with mips, ~340 KB GPU (BC3). Per character: outfit + head + expression, ×2 night.

## Mid state (sanity / stress meter)
A third texture state between day and night: every Day/Night pair gets a `_Mid` sheet = 50 % per-pixel RGBA blend
(heads, outfits, accessory atlas). `Crew.applyTime(model, "Day"|"Mid"|"Night")` swaps all of them at runtime with the
default face Normal / Exhausted / Normal_Night; `Crew.setSanity(model, "High"|"Mid"|"Low" | 0..1)` maps a meter to it.
