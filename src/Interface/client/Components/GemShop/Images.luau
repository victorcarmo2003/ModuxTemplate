--!strict
-- Gem pack art of the cards (owner request 2026-10-15): Assets/textures/ui/shop/art/gems_<n>.png (tools/icons/
-- shop_icons.py ART: the gems alone, no tile and no number, centred, transparent; the card spins its own rays behind
-- them). The numbered tiles in Assets/textures/ui/shop/ are the Creator Hub product images, not used in game. Ids also
-- in Assets/textures/ui/_texture_ids.json ("shop/art/<key>"). Keyed by Content.Shop.GemPacks key.
-- A key missing here = not uploaded: the card draws the Hud/gem sheet icon instead.
const IMAGES: { [string]: string } = {
	gems_50 = "rbxassetid://118789478835763",
	gems_130 = "rbxassetid://128486767420497",
	gems_300 = "rbxassetid://134749981583296",
	gems_700 = "rbxassetid://93811989249782",
}

return table.freeze(IMAGES)
