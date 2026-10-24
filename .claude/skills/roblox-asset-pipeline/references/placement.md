# Placing assets on the map

## Placement table (data only, versioned in the repo)

`tools/assetplace/<MAP>_placements.luau` returns a list:
```luau
{ asset = "AST-033_BuildingA", x = -80, y = 0.4, z = -41, rotY = 0, group = "Buildings", id = "B3",
  replaces = { "Buildings/B3_Facade" },   -- paths inside the blockout root that become invisible
  part = { "Rail_6" },                   -- optional: keep only these meshes of a multi-variant file
  layer = "night",                       -- optional: "day" (default visible) / "night" (stored in ServerStorage)
  note = "..." },
```
- `x, z` map coordinates, `y` absolute height of the asset pivot (base). `rotY` degrees:
  `CFrame.new(x,y,z) * CFrame.Angles(0, rad(rotY), 0)`. With front = -Z, rotY 0 faces north (-Z), 180 south.
- Header comment: conventions, measured facts, assumptions, what stayed blockout and why.
- A level designer can write it from the level doc + blockout script + export log; give them the export
  convention explicitly (front = -Z for EVERY imported asset - including your own models).

## Runner (`scripts/studio/place_assets.luau`)

- `Place.run(placements, ids)`: idempotent (rebuilds `workspace.<MAP>_Assets`), loads each asset once into
  `ServerStorage.__AssetCache` (PackageLink removed, parts anchored), clones per entry, hides `replaces`
  (Transparency 1, no collide/query, original values stored in attributes - also Decals/SurfaceGuis), groups by
  `group`, night layer into `ServerStorage.<MAP>_Assets_Night` (folders prefixed `Night_`).
- `Place.restore()`: shows the blockout again exactly as it was, deletes the asset folder.
- `Place.showLayer("night"|"day")`: swaps overlapping sets (cart by day, trailer by night on the same pad).
- Load the runner and table into ModuleScripts from the local http server, `require(module:Clone())` to bypass
  the require cache, run, report `placed N / M` + missing ids + missing paths.

## Orientation rules (learned the hard way)

- Verify with a **raycast probe** on a placed asset, not by reading coordinates: cast from ±Z at the height of a
  feature that protrudes on the front (knobs). This found that 50 entries (all self-modelled assets) were 180°
  off because the table author measured "front = +Z" in Blender instead of in Roblox.
- Vehicle shells whose stations are placed from mount attachments: rotate the shell, keep station positions
  (they come from the mounts) - check that the service window faces the queue.
- Parts modelled in another asset's space (lamp head made in the pole's space) inherit the same rotation trap:
  align by measurement (raycast down along the arm, find its tip, move the head's bbox centre there) and write
  the measured coordinates back into the table.
- Kit tiles have fixed sizes (roads 24×24 with a 2.4 curb inside); where the level geometry does not fit
  (32-wide avenue) keep the blockout and say so instead of distorting tiles.
