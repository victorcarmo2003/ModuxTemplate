# Getting meshes into Roblox

## Export (export_import.py does all of this)

| Setting | Value | Why (measured) |
|---|---|---|
| `global_scale` | **0.01** with `apply_unit_scale=True` | without it a 1-stud cube imported as **100 studs** (Roblox read the FBX as cm) |
| geometry rotation | **rotate roots 180° about Z before export** | Roblox normalises FBX axis metadata; `axis_forward` changes had **no effect**. After the rotation Blender +Y (front) lands on Roblox **-Z** |
| flat-colour materials (glass) | split as `Glass*`, UVs collapsed to the nearest atlas texel | joined glass read the atlas and showed it tiled; runner makes `Glass*` translucent |
| textures | `path_mode="COPY", embed_textures=True` | otherwise meshes arrive grey. Verify: the .fbx contains `\x89PNG` / `Video` blocks |
| complex materials | upload the PNGs separately and set `TextureID` | a material mixing colour by alpha (fur) did not embed - TextureID came empty |
| objects | meshes + empties not named `REF_*`, not hidden | empties do NOT become Attachments; keep attachment positions in a `_atts.json` |

Pack pieces used as-is still go through the exporter (scaled to the sheet, base pivot, mirrored nodes fixed,
joined into one mesh named after the asset).

## Calibrate before mass upload

1. Export a 1×1×1 cube with base at 0 → upload → `InsertService:LoadAsset` → bbox must be 1,1,1.
2. Upload one real asset with an obvious front (control panel) → raycast probe from ±Z: the protruding knobs
   must be on -Z. Fix the exporter, never patch rotations per asset.

## Upload (Open Cloud Assets API)

`scripts/py/rbx_upload.py --group <groupId> --map Assets/import/_asset_ids.json files...`
- Key from `ROBLOX_API_KEY` (env or Windows registry `HKCU\Environment` after `setx`). Never print it; print length only.
- Creator: the place's owner. Read `game.CreatorType/CreatorId` in Studio: a **Group** place needs
  `creationContext.creator.groupId` (and a key with asset write permission for that group).
- `POST https://apis.roblox.com/assets/v1/assets` multipart (`request` JSON + `fileContent` model/fbx),
  poll `operations/<id>` until `done`, read `response.assetId`. ~3-5 s per file; skips names already in the map.
- Uploaded Models insert as **packages** (PackageLink) - the placement runner removes PackageLink from its cache.

## Into the place

- `InsertService:LoadAsset(id)` works in edit mode (Studio MCP `execute_luau`) for assets of the group/user;
  models keep their FBX coordinates (shared origin → body + accessories line up).
- Studio MCP `insert_asset` drops at the camera - fine for a single check, not for placement.
- **The place must be saved by the user** (Ctrl+S); MCP cannot save. Everything is reproducible from the
  placement table + runner if the session is lost.
- HttpService: enable only while fetching from the local server (`127.0.0.1`), restore the previous value.

## Preview without uploading (fast iteration)

Bridge JSON (positions in Roblox axes `(x, z, -y)`, UVs `v' = 1 - v`, one entry per part) →
`scripts/studio/preview_mesh.luau` builds EditableMesh → `AssetService:CreateMeshPartAsync`. Textures via
`upload_image` (Studio MCP, needs a local http server). Notes: the engine does **not** recentre EditableMesh
vertices (place the MeshPart at the asset pivot, not at the bbox centre); previews are not reliable after the
place reloads; the Studio viewport renders black when Studio is minimised/unfocused (captures come back black).
