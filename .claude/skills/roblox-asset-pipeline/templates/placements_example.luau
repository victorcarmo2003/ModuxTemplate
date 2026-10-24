--[[
	<MAP> placement table (data only). Status: Draft. Runner: <skill>/scripts/studio/place_assets.luau.

	CONVENTIONS
	- x, z map coordinates; y = absolute height of the asset pivot (base centre).
	- rotY degrees: CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(rotY), 0). Every imported asset faces -Z
	  (LookVector) at rotY 0 -> rotY 0 = front north (-Z), 180 = south, 90 = west, 270 = east.
	  VERIFY with a raycast probe after the first run (references/placement.md) - do not trust measurements
	  taken in Blender.
	- replaces = paths inside workspace.<MAP>_Blockout hidden when the asset is in (never markers/routes/zones).
	- optional: part = { meshes to keep }, layer = "day" | "night", note = "...".

	MEASURED FACTS / ASSUMPTIONS / LEFT AS BLOCKOUT
	- ...
]]

return {
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = -28, rotY = 0, group = "Roads", id = "Z-07", replaces = { "Ground/Juniper_N_1" } },
	{ asset = "AST-036_StreetLightCurved", x = -14, y = 0.24, z = -24, rotY = 90, group = "StreetLights", id = "JL-01", replaces = { "StreetLights/JL-01" } },
	{ asset = "AST-036_LampHead", x = -12.405, y = 0.24, z = -24, rotY = 90, group = "StreetLights", id = "JL-01", note = "seated on the measured arm tip" },
	{ asset = "AST-026_CornerCart", x = 41, y = 0.45, z = 37.5, rotY = 0, group = "Cart", id = "CART", layer = "day", replaces = { "Pad/CART/Base" } },
	{ asset = "AST-013_RestRail", part = { "Rail_6" }, x = 37.5, y = 3.95, z = 37.5, rotY = 180, group = "Cart", id = "CART-R", layer = "day" },
	{ asset = "AST-027_OpenLateTrailer", x = 40, y = 0.45, z = 41, rotY = 0, group = "Trailer", id = "TRL", layer = "night", replaces = { "Pad/TRL" } },
}
