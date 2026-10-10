--!strict
-- Animal species (content-data.md §3.10a; DEC-158, DEC-186, DEC-188, DEC-159, DEC-192).
-- STUB (TASK-003): rows from content-data.md v4; reviewed in TASK-009 (Q-165 pig/playable as customer).
-- Texture ids are NOT here: src/Crew/shared/CrewLooks.luau (TASK-006), indexed by these keys.
local Table = require(script.Parent.Table)

export type Species = {
	Key: string,
	Name: string,
	Asset: string, -- kit suffix: AST-053_Animal_<Asset>, T_Head_<Asset>[_Mid|_Night]
	Class: string?, -- key of Classes (1 <-> 1) or nil
	Customer: boolean, -- may appear as a customer (DEC-188 a); which types use it: CustomerTypes.Species
	Pedestrian: boolean, -- may be a passer-by (NPC-019, wave 2)
	ReservedFor: string?, -- NPC/CHR id; reserved species are never classes nor customers
}

local function animal(key: string, asset: string, class: string?): Species
	return {
		Key = key,
		Name = asset,
		Asset = asset,
		Class = class,
		Customer = true,
		Pedestrian = true,
	}
end

return Table.new({
	animal("dog", "Dog", "class_dog"),
	animal("rabbit", "Rabbit", "class_rabbit"),
	animal("cat", "Cat", "class_cat"),
	animal("bear", "Bear", "class_bear"),
	animal("fox", "Fox", "class_fox"),
	animal("owl", "Owl", "class_owl"),
	animal("panda", "Panda", "class_panda"),
	animal("lion", "Lion", "class_lion"),
	animal("penguin", "Penguin", nil), -- NPC-001
	animal("hamster", "Hamster", nil), -- NPC-002
	animal("mouse", "Mouse", nil), -- NPC-002
	animal("frog", "Frog", nil), -- NPC-003
	animal("monkey", "Monkey", nil), -- NPC-004
	animal("turtle", "Turtle", nil), -- NPC-005
	animal("sheep", "Sheep", nil), -- NPC-005
	animal("koala", "Koala", nil), -- NPC-006
	animal("pig", "Pig", nil), -- DEC-192 (to confirm); no customer type yet (Q-165)
	{
		Key = "raccoon",
		Name = "Raccoon",
		Asset = "Raccoon",
		Customer = false,
		Pedestrian = false,
		ReservedFor = "NPC-007", -- Quick Quentin only (DEC-159, DEC-186)
	},
} :: { Species })
