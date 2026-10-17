--!strict
-- Class skins (owner request 2026-10-17, Provisional; design/skins-proposal.md, Q-300..Q-305). Visual only: a skin never
-- changes a class number (DEC-069 guard), ClassService:GetModifier never reads it.
-- Sold ONLY for Robux, one Developer Product per skin (ProductId 0 = not created on the Creator Hub yet: never prompted,
-- no receipt maps to it). Granted by SkinService on the receipt, kept in profile.Skins; the equipped one per class in
-- profile.EquippedSkins. Keys are persisted and are the SkinState / SkinEquip wire enum: never rename.
--   Class      Content.Classes key the skin dresses
--   Sheet      outfit sheet name: Assets/textures/character/skins/T_Skin_<Sheet>_<Day|Mid|Night>.png
--              (tools/assetplace/gen_skin_textures.py); ids in src/Crew/shared/SkinLooks.luau
--   Fur        fur colour of the skin (head and hands under the texture alpha); nil = the species' own
--   Limited    on sale only until EndsAt (os.time, UTC); after it the skin is hidden for players who do not own it,
--              owners keep it forever (Q-301)
--   Swatch     two colours of the in-game circle while the icon is not uploaded (ClassSelect)
--   Accessories / Hat   extra kit pieces (CrewRig.Build options), lot 1b (Q-305); nil = none
--   Robux      suggested price (Creator Hub) and display fallback; the real one is GetProductInfo (Q-302)
-- ProductIds: Creator Hub, created by the owner 2026-10-17 from docs/monetization/skins.csv.
local Classes = require(script.Parent.Classes)
local Table = require(script.Parent.Table)

export type Theme = "Halloween" | "Classic"

export type Skin = {
	Key: string,
	Ref: string,
	Class: string,
	Name: string,
	Text: string,
	Theme: Theme,
	Sheet: string,
	Fur: Color3?,
	Swatch: { Color3 },
	Accessories: { string }?,
	Hat: string?,
	Limited: boolean,
	EndsAt: number, -- os.time UTC; 0 = never ends (Limited false)
	ProductId: number,
	Robux: number,
}

export type Rules = {
	None: string, -- wire value of "no skin" (SkinEquip / SkinState)
	PerClass: number, -- circles under the card (ClassSelect): the first N skins of the class on show
}

-- Halloween lot 1 (Q-301): on sale until 2026-11-03 00:00 UTC.
const HALLOWEEN_END = 1793664000

const list: { Skin } = {
	{
		Key = "skin_dog_pumpkin",
		Ref = "AST-123",
		Class = "class_dog",
		Name = "Pumpkin Rookie",
		Text = "A pumpkin apron and orange sleeves for spooky shifts.",
		Theme = "Halloween",
		Sheet = "Pumpkin",
		Swatch = { Color3.fromRGB(242, 140, 40), Color3.fromRGB(58, 50, 66) },
		Limited = true,
		EndsAt = HALLOWEEN_END,
		ProductId = 3719210168,
		Robux = 99,
	},
	{
		Key = "skin_rabbit_ghost",
		Ref = "AST-123",
		Class = "class_rabbit",
		Name = "Ghost Runner",
		Text = "Boo! A sheet-white uniform with little ghost mittens.",
		Theme = "Halloween",
		Sheet = "Ghost",
		Fur = Color3.fromRGB(233, 238, 248),
		Swatch = { Color3.fromRGB(236, 238, 250), Color3.fromRGB(139, 147, 181) },
		Limited = true,
		EndsAt = HALLOWEEN_END,
		ProductId = 3719210179,
		Robux = 129,
	},
	{
		Key = "skin_cat_witch",
		Ref = "AST-123",
		Class = "class_cat",
		Name = "Witch Cat",
		Text = "A black cat in a starry purple apron.",
		Theme = "Halloween",
		Sheet = "Witch",
		Fur = Color3.fromRGB(58, 54, 64),
		Swatch = { Color3.fromRGB(123, 79, 194), Color3.fromRGB(52, 46, 60) },
		Limited = true,
		EndsAt = HALLOWEEN_END,
		ProductId = 3719210194,
		Robux = 129,
	},
	{
		Key = "skin_bear_franken",
		Ref = "AST-123",
		Class = "class_bear",
		Name = "Franken Hauler",
		Text = "Green fur, stitched apron and heavy work gloves.",
		Theme = "Halloween",
		Sheet = "Franken",
		Fur = Color3.fromRGB(134, 184, 106),
		Swatch = { Color3.fromRGB(110, 154, 85), Color3.fromRGB(96, 104, 114) },
		Limited = true,
		EndsAt = HALLOWEEN_END,
		ProductId = 3719210205,
		Robux = 129,
	},
	{
		Key = "skin_fox_vampire",
		Ref = "AST-123",
		Class = "class_fox",
		Name = "Count Hawker",
		Text = "A dapper vampire look with white gloves.",
		Theme = "Halloween",
		Sheet = "Vampire",
		Swatch = { Color3.fromRGB(52, 44, 60), Color3.fromRGB(110, 30, 62) },
		Limited = true,
		EndsAt = HALLOWEEN_END,
		ProductId = 3719210220,
		Robux = 149,
	},
	{
		Key = "skin_owl_skeleton",
		Ref = "AST-123",
		Class = "class_owl",
		Name = "Bone Owl",
		Text = "A friendly skeleton suit that glows in the night shift.",
		Theme = "Halloween",
		Sheet = "Skeleton",
		Fur = Color3.fromRGB(74, 70, 80),
		Swatch = { Color3.fromRGB(50, 44, 58), Color3.fromRGB(236, 226, 200) },
		Limited = true,
		EndsAt = HALLOWEEN_END,
		ProductId = 3719210233,
		Robux = 149,
	},
}

const rules: Rules = {
	None = "none",
	PerClass = 5,
}

-- Keys by class, in list order (the circles under the card)
const byClass: { [string]: { string } } = {}
for _, skin in list do
	const bucket = byClass[skin.Class] or {}
	table.insert(bucket, skin.Key)
	byClass[skin.Class] = bucket
	if Classes.ByKey[skin.Class] == nil then
		error(`[Content.Skins] {skin.Key}: unknown Class {skin.Class}`)
	end
	if skin.Key == rules.None then
		error(`[Content.Skins] '{rules.None}' is reserved`)
	end
	if skin.Limited and skin.EndsAt <= 0 then
		error(`[Content.Skins] {skin.Key}: a Limited skin needs EndsAt`)
	end
	if #skin.Swatch ~= 2 then
		error(`[Content.Skins] {skin.Key}: Swatch needs 2 colours`)
	end
end

-- SkinState.Owned is a Lync bitfield (32 bits, Validate BITFIELD_MAX)
if #list > 32 then
	error(`[Content.Skins] {#list} skins exceed the SkinState.Owned bitfield (32): split the packet first`)
end

-- Wire enum of SkinEquip / SkinState: "none" + every key
const choices: { string } = { rules.None }
for _, skin in list do
	table.insert(choices, skin.Key)
end

return Table.with(Table.new(list), {
	Rules = Table.record(rules),
	ByClass = Table.record(byClass),
	Choices = Table.record(choices),
})
