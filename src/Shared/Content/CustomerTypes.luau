--!strict
-- Customer types (content-data.md §3.16; npcs.md; DEC-188). Variant = species x civil outfit.
-- STUB (TASK-003): keys, refs and species from content-data.md v4; numbers copied from npcs.md (Rascunho);
-- Accessories empty until the kit names exist (TASK-006). Reviewed in TASK-009.
local Table = require(script.Parent.Table)

export type Role = "Customer" | "Pedestrian"
export type ShiftKind = "Day" | "Night" | "Any"

export type CustomerType = {
	Key: string,
	Ref: string,
	Name: string,
	Role: Role,
	Species: { string }, -- keys of Species; empty for Pedestrian = any species with Pedestrian = true
	Accessories: { string }, -- mesh names in ReplicatedStorage.Assets.Crew.Accessories
	Outfits: { string }, -- keys of Outfits (civil_* only), uniform draw
	Shift: ShiftKind,
	UnlockDay: number,
	UnlockNight: number, -- 0 = never at night
	Weight: { Day: number, Night: number },
	WalkSpeed: number,
	KShift: { Delta: number, Chance: number }, -- K +-1 after the phase draw (clamped 0..3)
	IngredientMult: { [string]: number }, -- keys of Ingredients.ToppingKeys; missing = 1
	Lines: { string },
}

const CIVIL = { "civil_a", "civil_b", "civil_c", "civil_d", "civil_e", "civil_f", "civil_g", "civil_h" }
const NO_SHIFT = { Delta = 0, Chance = 0 }

return Table.new({
	{
		Key = "office_worker",
		Ref = "NPC-001",
		Name = "Office Worker",
		Role = "Customer",
		Species = { "penguin" },
		Accessories = {},
		Outfits = { "civil_a", "civil_c", "civil_e", "civil_g" },
		Shift = "Any",
		UnlockDay = 1,
		UnlockNight = 1,
		Weight = { Day = 30, Night = 30 },
		WalkSpeed = 14,
		KShift = NO_SHIFT,
		IngredientMult = { mustard = 1.5, potato_sticks = 0.7, cream_cheese = 1.3 },
		Lines = {},
	},
	{
		Key = "student",
		Ref = "NPC-002",
		Name = "Student",
		Role = "Customer",
		Species = { "hamster", "mouse" },
		Accessories = {},
		Outfits = CIVIL,
		Shift = "Day",
		UnlockDay = 1,
		UnlockNight = 0,
		Weight = { Day = 30, Night = 0 },
		WalkSpeed = 14,
		KShift = NO_SHIFT,
		IngredientMult = { ketchup = 1.5, cheese = 1.4, mustard = 0.6 },
		Lines = {},
	},
	{
		Key = "jogger",
		Ref = "NPC-003",
		Name = "Jogger",
		Role = "Customer",
		Species = { "frog" },
		Accessories = {},
		Outfits = CIVIL,
		Shift = "Day",
		UnlockDay = 1,
		UnlockNight = 0,
		Weight = { Day = 15, Night = 0 },
		WalkSpeed = 18,
		KShift = { Delta = -1, Chance = 0.4 },
		IngredientMult = { mustard = 1.2, bacon = 0.5, cream_cheese = 0.5 },
		Lines = {},
	},
	{
		Key = "construction_worker",
		Ref = "NPC-004",
		Name = "Construction Worker",
		Role = "Customer",
		Species = { "monkey" },
		Accessories = {},
		Outfits = CIVIL,
		Shift = "Any",
		UnlockDay = 2,
		UnlockNight = 1,
		Weight = { Day = 20, Night = 25 },
		WalkSpeed = 13,
		KShift = { Delta = 1, Chance = 0.3 },
		IngredientMult = { bacon = 1.8, potato_sticks = 1.3, ketchup = 0.8 },
		Lines = {},
	},
	{
		Key = "grandparent",
		Ref = "NPC-005",
		Name = "Grandparent",
		Role = "Customer",
		Species = { "turtle", "sheep" },
		Accessories = {},
		Outfits = CIVIL,
		Shift = "Day",
		UnlockDay = 3,
		UnlockNight = 0,
		Weight = { Day = 10, Night = 0 },
		WalkSpeed = 9,
		KShift = NO_SHIFT,
		IngredientMult = { cream_cheese = 1.6, cheese = 1.2, mustard = 0.5, bacon = 0.6 },
		Lines = {},
	},
	{
		Key = "night_shift_worker",
		Ref = "NPC-006",
		Name = "Night Shift Worker",
		Role = "Customer",
		Species = { "koala" },
		Accessories = {},
		Outfits = CIVIL,
		Shift = "Night",
		UnlockDay = 0,
		UnlockNight = 1,
		Weight = { Day = 0, Night = 45 },
		WalkSpeed = 13,
		KShift = NO_SHIFT,
		IngredientMult = { ketchup = 1.2, potato_sticks = 1.3 },
		Lines = {},
	},
	{
		Key = "pedestrian",
		Ref = "NPC-019",
		Name = "Pedestrian",
		Role = "Pedestrian", -- wave 2 (DEC-183)
		Species = {},
		Accessories = {},
		Outfits = CIVIL,
		Shift = "Any",
		UnlockDay = 1,
		UnlockNight = 1,
		Weight = { Day = 0, Night = 0 },
		WalkSpeed = 8,
		KShift = NO_SHIFT,
		IngredientMult = {},
		Lines = {},
	},
} :: { CustomerType })
