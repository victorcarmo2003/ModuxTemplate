# Into Roblox: export, upload, assemble

1. Export with the roblox-asset-pipeline exporter (`export_import.py --only "character/AST-###_*"`): 180° about Z,
   `global_scale 0.01`, embedded textures. Upload with `rbx_upload.py` (drop the old ids from `_asset_ids.json` first).
2. PNGs (outfits, heads, expressions, night atlas) via Studio `upload_image` → `_texture_ids.json`.
3. Assemble in Studio (edit mode, `execute_luau`): fetch `build_crew.luau`, the ids and texture ids from a local
   http server (enable HttpService only while fetching, restore it), load the source into a ModuleScript, require.

```lua
local Crew = require(ms)
Crew.ensureExpressions(tex)          -- ReplicatedStorage.CrewExpressions/<Name> SurfaceAppearance templates
local m = Crew.build({ ids = ids, tex = tex, animal = "Dog", outfit = "Crew" | "A" | "B", time = "Day" | "Night",
	fur = Color3.fromRGB(185, 122, 79), earsUp = false, cap = true, expression = "Normal",
	at = CFrame.new(x, groundY + 3, z) * CFrame.Angles(0, math.rad(180), 0) })
Crew.setExpression(m, "Fainted")     -- clones the template into Face (prefers <Name>_Night on Night models)
```

- The face shell needs real transparency: `SurfaceAppearance` with `AlphaMode = Transparency` (a TextureID paints
  transparent texels with the part Color and hides the head marks). `SurfaceAppearance.ColorMap` is not writable by
  game scripts at runtime → prebuild one SurfaceAppearance per expression in edit mode and swap by cloning.
- Head: `TextureID = T_Head_<A>[_Night]`, `Color = fur`. Body parts: outfit TextureID, `Color = fur` (hands).
- Rebuild of existing demo models: read Animal/Outfit/Time/Expression attributes + HRP CFrame, destroy, rebuild.
  Fur: read from the old Head.Color only if it was the true fur (keep a fur table per species to be safe).
- Captures: `screen_capture` with camera/look-at; black images = Studio minimised/unfocused (ask the user to keep it
  open) — fall back to probes. Always look at front, 3/4 and profile close-ups.
- The user saves the place (Ctrl+S); MCP cannot.
