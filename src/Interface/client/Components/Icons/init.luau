--!strict
-- Icon sheet AST-071 (1024², cells 128²): name -> rect, from Assets/textures/ui/AST-071_icons.json.
-- Regenerate this map when the JSON changes (same keys: "Hud/coin", "Class/class_fox", "Ingredient/bun", ...).
-- Placeholder renders are marked in the JSON (`placeholder`); the class icons are the Day head render until AST-086.
-- Usage: ImageLabel.Image = Icons.Image; ImageRectOffset/ImageRectSize = Icons.Rect(name).

export type Rect = { Offset: Vector2, Size: Vector2 }

const IMAGE = "rbxassetid://75974795918833"

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

local function rect(name: string): Rect?
	const r = RECTS[name]
	if r == nil then
		return nil
	end
	return { Offset = Vector2.new(r[1], r[2]), Size = Vector2.new(r[3], r[4]) }
end

return table.freeze({
	Image = IMAGE,
	-- nil for an unknown name (the caller keeps its fallback)
	Rect = rect,
	Has = function(name: string): boolean
		return RECTS[name] ~= nil
	end,
})
