--!strict
-- Animal species (content-data.md §3.10a; DEC-158, DEC-159, DEC-186, DEC-188, DEC-192, DEC-214).
-- TASK-009: 18 species. 8 have a class (6 playable in the MVP: PlayableKeys); raccoon is Quick Quentin only.
-- DEC-188 a: every species may be a customer (civil outfit, never the crew uniform), except the raccoon.
-- Wave 1 draws customers only from CustomerTypes.Species; where playable species and the pig appear as
-- customers is Q-165 (Provisional: pedestrians only, wave 2). Pig as a normal customer: DEC-192 confirmed by DEC-214.
-- Named characters reuse existing species (DEC-178, DEC-203: Opal = owl, Pickett = mouse, Raincoat Lady = frog).
-- Texture ids are NOT here: src/Crew/shared/CrewLooks.luau (TASK-006), indexed by these keys.
local Classes = require(script.Parent.Classes)
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

export type Derived = {
	PlayableKeys: { string }, -- species whose class is InMvp (the "Crew" screen of the MVP, DEC-186)
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

const base = Table.new({
	animal("dog", "Dog", "class_dog"), -- CLS-001
	animal("rabbit", "Rabbit", "class_rabbit"), -- CLS-002
	animal("cat", "Cat", "class_cat"), -- CLS-003
	animal("bear", "Bear", "class_bear"), -- CLS-004
	animal("fox", "Fox", "class_fox"), -- CLS-005
	animal("owl", "Owl", "class_owl"), -- CLS-006; also Opal (DEC-203)
	animal("panda", "Panda", "class_panda"), -- CLS-007 (first update)
	animal("lion", "Lion", "class_lion"), -- CLS-008 (first update)
	animal("penguin", "Penguin", nil), -- NPC-001
	animal("hamster", "Hamster", nil), -- NPC-002
	animal("mouse", "Mouse", nil), -- NPC-002; also Mr. Pickett (DEC-203)
	animal("frog", "Frog", nil), -- NPC-003; also Raincoat Lady (DEC-203)
	animal("monkey", "Monkey", nil), -- NPC-004
	animal("turtle", "Turtle", nil), -- NPC-005 (not a class, DEC-186); also Walt (DEC-202)
	animal("sheep", "Sheep", nil), -- NPC-005
	animal("koala", "Koala", nil), -- NPC-006
	animal("pig", "Pig", nil), -- normal customer (DEC-192, DEC-214); no customer type yet (Q-165)
	{
		Key = "raccoon",
		Name = "Raccoon",
		Asset = "Raccoon",
		Customer = false,
		Pedestrian = false,
		ReservedFor = "NPC-007", -- Quick Quentin only (DEC-159, DEC-186)
	},
} :: { Species })

const derived: Derived = {
	PlayableKeys = Table.keysWhere(base, function(row: Species): boolean
		const class = if row.Class then Classes.ByKey[row.Class] else nil
		return class ~= nil and class.InMvp
	end),
}

return Table.with(base, derived)
