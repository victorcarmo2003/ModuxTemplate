--!strict
-- Gem pack art (TASK-301): Assets/textures/ui/shop/gems_<n>.png (tools/icons/shop_icons.py, 512², full colour),
-- uploaded 2026-10-15; the same ids are in Assets/textures/ui/_texture_ids.json. Keyed by Content.Shop.GemPacks key.
-- A key missing here = not uploaded: the card draws the Hud/gem sheet icon instead.
const IMAGES: { [string]: string } = {
	gems_50 = "rbxassetid://91276487880723",
	gems_130 = "rbxassetid://137767066767714",
	gems_300 = "rbxassetid://99522160619366",
	gems_700 = "rbxassetid://92452637788166",
}

return table.freeze(IMAGES)
