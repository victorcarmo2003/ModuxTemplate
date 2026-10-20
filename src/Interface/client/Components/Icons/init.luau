--!strict
-- Icon sheet AST-071 (1024², cells 128²): name -> rect, from Assets/textures/ui/AST-071_icons.json.
-- Regenerate this map when the JSON changes (same keys: "Hud/coin", "Class/class_fox", "Ingredient/bun", ...).
-- Placeholder renders are marked in the JSON (`placeholder`); the class icons are the Day head render until AST-086.
-- Second sheet AST-091 (`Ui/<name>`): RhosGFX vector icons with the same Ink outline, from
-- Assets/textures/ui/AST-091_ui_icons.json (tools/icons/build_ui_kit.py). RhosGFX licence: use in this game only.
-- Usage: ImageLabel.Image = Icons.ImageOf(name); ImageRectOffset/ImageRectSize = Icons.Rect(name).
-- Every UI image id of the project lives in `Ids` (one place to paste the upload ids). An id that is still ""
-- makes `Has` false for its names, so the caller keeps its drawn fallback until the upload.

export type Rect = { Offset: Vector2, Size: Vector2 }

const Ids = table.freeze({
	-- AST-071 icon sheet (food, stations, HUD, reactions)
	Sheet = "rbxassetid://75974795918833",
	-- AST-091 UI icon sheet (Assets/textures/ui/AST-091_ui_icons.png)
	UiSheet = "rbxassetid://121094453044732",
	-- AST-091 studs tile (Assets/textures/ui/AST-091_studs.png, 128², tileable)
	Studs = "rbxassetid://118792572605027",
})

const IMAGE = Ids.Sheet

const RECTS: { [string]: { number } } = {
	["Class/class_bear"] = { 640, 512, 128, 128 },
	["Class/class_cat"] = { 512, 512, 128, 128 },
	["Class/class_dog"] = { 256, 512, 128, 128 },
	["Class/class_fox"] = { 768, 512, 128, 128 },
	["Class/class_lion"] = { 128, 640, 128, 128 },
	["Class/class_owl"] = { 896, 512, 128, 128 },
	["Class/class_panda"] = { 0, 640, 128, 128 },
	["Class/class_rabbit"] = { 384, 512, 128, 128 },
	["Hud/ambulance"] = { 896, 640, 128, 128 },
	["Hud/coin"] = { 256, 640, 128, 128 },
	["Hud/gem"] = { 384, 640, 128, 128 },
	["Hud/moon"] = { 640, 640, 128, 128 },
	["Hud/phone"] = { 768, 640, 128, 128 },
	["Hud/sun"] = { 512, 640, 128, 128 },
	["Ingredient/bacon"] = { 640, 0, 128, 128 },
	["Ingredient/bun"] = { 0, 0, 128, 128 },
	["Ingredient/cheese"] = { 512, 0, 128, 128 },
	["Ingredient/coffee"] = { 0, 128, 128, 128 },
	["Ingredient/cream_cheese"] = { 896, 0, 128, 128 },
	["Ingredient/ketchup"] = { 256, 0, 128, 128 },
	["Ingredient/mustard"] = { 384, 0, 128, 128 },
	["Ingredient/potato_sticks"] = { 768, 0, 128, 128 },
	["Ingredient/sausage"] = { 128, 0, 128, 128 },
	["Item/coffee"] = { 384, 256, 128, 128 },
	["Item/hot_dog"] = { 128, 128, 128, 128 },
	["Item/pack_bacon"] = { 896, 128, 128, 128 },
	["Item/pack_buns"] = { 384, 128, 128, 128 },
	["Item/pack_cheese"] = { 768, 128, 128, 128 },
	["Item/pack_coffee"] = { 256, 256, 128, 128 },
	["Item/pack_cream_cheese"] = { 128, 256, 128, 128 },
	["Item/pack_ketchup"] = { 512, 128, 128, 128 },
	["Item/pack_mustard"] = { 640, 128, 128, 128 },
	["Item/pack_potato_sticks"] = { 0, 256, 128, 128 },
	["Item/pack_sausages"] = { 256, 128, 128, 128 },
	["Item/revive_kit"] = { 512, 256, 128, 128 },
	["Notice/lock"] = { 384, 768, 128, 128 },
	["Notice/rare"] = { 640, 768, 128, 128 },
	["Notice/trailer"] = { 512, 768, 128, 128 },
	["Reaction/scribble_cloud"] = { 128, 768, 128, 128 },
	["Reaction/star"] = { 0, 768, 128, 128 },
	["Reaction/steam"] = { 256, 768, 128, 128 },
	["Upgrade/cash_drawer_lock"] = { 768, 384, 128, 128 },
	["Upgrade/coffee_machine"] = { 128, 512, 128, 128 },
	["Upgrade/cooler/1"] = { 0, 384, 128, 128 },
	["Upgrade/cooler/2"] = { 128, 384, 128, 128 },
	["Upgrade/cooler/3"] = { 256, 384, 128, 128 },
	["Upgrade/counter/1"] = { 384, 384, 128, 128 },
	["Upgrade/counter/2"] = { 512, 384, 128, 128 },
	["Upgrade/counter/3"] = { 640, 384, 128, 128 },
	["Upgrade/food_trailer"] = { 0, 512, 128, 128 },
	["Upgrade/grill/1"] = { 640, 256, 128, 128 },
	["Upgrade/grill/2"] = { 768, 256, 128, 128 },
	["Upgrade/grill/3"] = { 896, 256, 128, 128 },
	["Upgrade/trailer_lights"] = { 896, 384, 128, 128 },
}

const UI_RECTS: { [string]: { number } } = {
	["Ui/arrow_left"] = { 256, 0, 128, 128 },
	["Ui/arrow_right"] = { 384, 0, 128, 128 },
	["Ui/bell"] = { 384, 256, 128, 128 },
	["Ui/calendar"] = { 256, 128, 128, 128 },
	["Ui/cash"] = { 384, 128, 128, 128 },
	["Ui/check"] = { 128, 0, 128, 128 },
	["Ui/clock"] = { 0, 256, 128, 128 },
	["Ui/close"] = { 0, 0, 128, 128 },
	["Ui/friends"] = { 640, 128, 128, 128 },
	["Ui/hourglass"] = { 640, 0, 128, 128 },
	["Ui/info"] = { 768, 0, 128, 128 },
	["Ui/lantern"] = { 128, 256, 128, 128 },
	["Ui/megaphone"] = { 256, 256, 128, 128 },
	["Ui/paw"] = { 768, 128, 128, 128 },
	["Ui/sparkle"] = { 0, 128, 128, 128 },
	["Ui/spectate"] = { 512, 0, 128, 128 },
	["Ui/thumbs_up"] = { 896, 128, 128, 128 },
	["Ui/tip_jar"] = { 512, 128, 128, 128 },
	["Ui/trophy"] = { 128, 128, 128, 128 },
	["Ui/warning"] = { 896, 0, 128, 128 },
}

-- Whole images outside the sheets (rect 0,0,0,0 = the full image): the Roblox Robux glyph shipped with the client
const SINGLES: { [string]: string } = {
	["Ui/robux"] = "rbxasset://textures/ui/common/robux.png",
	-- fall screens (DEC-317; tools/icons/life_hearts.py): team life heart (white, tinted in LifeHeart) and the revive icon
	["Life/heart"] = "rbxassetid://127177868031282", -- AST-165
	["Life/revive"] = "rbxassetid://92117058169007", -- AST-166
	-- coin pack art (tools/icons/shop_icons.py art/cash_*, owner 2026-10-16): sack, pile, chest
	["Shop/cash_100"] = "rbxassetid://85020875005926",
	["Shop/cash_300"] = "rbxassetid://138499953827803",
	["Shop/cash_800"] = "rbxassetid://97587055399361",
}
const FULL = { 0, 0, 0, 0 }

-- Sheet image and cell of a name; nil when unknown or when its sheet is not uploaded yet.
local function lookup(name: string): (string?, { number }?)
	const single = SINGLES[name]
	if single ~= nil then
		return single, FULL
	end
	const r = RECTS[name]
	if r ~= nil then
		return IMAGE, r
	end
	const u = UI_RECTS[name]
	if u ~= nil and Ids.UiSheet ~= "" then
		return Ids.UiSheet, u
	end
	return nil, nil
end

local function rect(name: string): Rect?
	const _, r = lookup(name)
	if r == nil then
		return nil
	end
	return { Offset = Vector2.new(r[1], r[2]), Size = Vector2.new(r[3], r[4]) }
end

return table.freeze({
	Ids = Ids,
	-- AST-071 sheet (kept for callers that only use `Ingredient/`, `Class/`, `Hud/` names)
	Image = IMAGE,
	-- Sheet of any name ("" when unknown or not uploaded)
	ImageOf = function(name: string): string
		const image = lookup(name)
		return image or ""
	end,
	-- nil for an unknown name (the caller keeps its fallback)
	Rect = rect,
	Has = function(name: string): boolean
		const image = lookup(name)
		return image ~= nil
	end,
})
