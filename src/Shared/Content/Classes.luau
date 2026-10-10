--!strict
-- Playable classes: animal = class (content-data.md §3.10; DEC-069, DEC-070, DEC-186).
-- TASK-009: 6 in the MVP (dog, rabbit, cat, bear, fox, owl), panda/lion in the first update (DEC-186).
-- Bonus + drawback are passive (DEC-186), numbers unchanged from DEC-069; prices by tier 0/45/120/180 (DEC-070).
-- Keys are persisted in the profile (Classes, SelectedClass) and are the Profile/ClassAction enum: never rename.
-- Name and Description are placeholders (narrative-writer, DEC-022, ui-text.md "Crew" screen): change text, not keys.
-- Raccoon is never a class species (DEC-159, DEC-186): Validate checks Species.ReservedFor.
local Stats = require(script.Parent.Stats)
local Table = require(script.Parent.Table)

export type Op = "Set" | "Mul" | "Add"
export type Scope = "Self" | "Party"
export type When = "Always" | "Day" | "Night" | "PackagesAtLeast"

export type Effect = {
	Stat: Stats.Stat,
	Op: Op,
	Value: number,
	Scope: Scope,
	When: When?, -- nil = Always
	WhenValue: number?, -- PackagesAtLeast
}

export type Class = {
	Key: string,
	Ref: string,
	Species: string, -- key of Species (1 <-> 1)
	Name: string, -- placeholder (narrative-writer)
	Description: string, -- placeholder: bonus . drawback, one line each (narrative-writer)
	Tier: number,
	Price: number, -- gems
	InMvp: boolean,
	Effects: { Effect },
}

return Table.new({
	{
		Key = "class_dog",
		Ref = "CLS-001",
		Species = "dog",
		Name = "Rookie",
		Description = "No perks, no drawbacks. Good at a bit of everything.",
		Tier = 0,
		Price = 0, -- every new account owns it (DEC-186); the balance baseline (DEC-069)
		InMvp = true,
		Effects = {},
	},
	{
		Key = "class_rabbit",
		Ref = "CLS-002",
		Species = "rabbit",
		Name = "Runner",
		Description = "Moves faster. Starts each night with 90 sanity.",
		Tier = 1,
		Price = 45, -- DEC-070 tier 1
		InMvp = true,
		Effects = {
			{ Stat = "WalkSpeed", Op = "Set", Value = 18, Scope = "Self" }, -- 16 -> 18 (DEC-069)
			{ Stat = "SanityStart", Op = "Set", Value = 90, Scope = "Self" }, -- drawback, max stays 100 (DEC-069)
		},
	},
	{
		Key = "class_cat",
		Ref = "CLS-003",
		Species = "cat",
		Name = "Line Cook",
		Description = "Sausages you grill cook 15% faster. Walks a little slower.",
		Tier = 1,
		Price = 45, -- DEC-070 tier 1
		InMvp = true,
		Effects = {
			{ Stat = "GrillTime", Op = "Mul", Value = 0.85, Scope = "Self" }, -- only sausages he placed (DEC-069)
			{ Stat = "WalkSpeed", Op = "Set", Value = 15, Scope = "Self" }, -- drawback 16 -> 15 (DEC-069)
		},
	},
	{
		Key = "class_bear",
		Ref = "CLS-004",
		Species = "bear",
		Name = "Hauler",
		Description = "Carries 3 packages. Slower while carrying all 3.",
		Tier = 1,
		Price = 45, -- DEC-070 tier 1; in the MVP since DEC-186
		InMvp = true,
		Effects = {
			{ Stat = "PackageLimit", Op = "Set", Value = 3, Scope = "Self" }, -- 2 -> 3 (DEC-069, DEC-049)
			-- drawback: 14 only while holding 3 packages (DEC-069)
			{ Stat = "WalkSpeed", Op = "Set", Value = 14, Scope = "Self", When = "PackagesAtLeast", WhenValue = 3 },
		},
	},
	{
		Key = "class_fox",
		Ref = "CLS-005",
		Species = "fox",
		Name = "Hawker",
		Description = "Earns $2 tips on your orders. Tip window is 4 s shorter.",
		Tier = 2,
		Price = 120, -- DEC-070 tier 2; in the MVP since DEC-186
		InMvp = true,
		Effects = {
			-- "own order": Take Order per content-data §3.10 vs Serve per classes.md CLS-005 (Provisional, TASK-017)
			{ Stat = "TipAmount", Op = "Set", Value = 2, Scope = "Self" }, -- $1 -> $2 (DEC-069, DEC-072)
			{ Stat = "TipWindow", Op = "Add", Value = -4, Scope = "Self" }, -- drawback (DEC-069)
		},
	},
	{
		Key = "class_owl",
		Ref = "CLS-006",
		Species = "owl",
		Name = "Night Owl",
		Description = "Starts nights with 120 sanity (max 120). Slower by day.",
		Tier = 2,
		Price = 120, -- DEC-070 tier 2
		InMvp = true,
		Effects = {
			{ Stat = "SanityStart", Op = "Set", Value = 120, Scope = "Self" }, -- DEC-069 (wave 2)
			{ Stat = "SanityMax", Op = "Set", Value = 120, Scope = "Self" }, -- DEC-069 (wave 2)
			{ Stat = "WalkSpeed", Op = "Set", Value = 15, Scope = "Self", When = "Day" }, -- drawback (DEC-069)
		},
	},
	{
		Key = "class_panda",
		Ref = "CLS-007",
		Species = "panda",
		Name = "Barista",
		Description = "Your coffee brews in 3 s and restores 35. Seeing anomalies hits harder.",
		Tier = 2,
		Price = 120, -- DEC-070 tier 2
		InMvp = false, -- first update (DEC-186)
		Effects = {
			{ Stat = "CoffeeBrewTime", Op = "Set", Value = 3, Scope = "Self" }, -- coffee he made (DEC-069)
			{ Stat = "CoffeeRestore", Op = "Set", Value = 35, Scope = "Self" }, -- for whoever drinks it (DEC-069)
			{ Stat = "SeeAnomalyLoss", Op = "Set", Value = 8, Scope = "Self" }, -- drawback (DEC-069)
		},
	},
	{
		Key = "class_lion",
		Ref = "CLS-008",
		Species = "lion",
		Name = "Shift Lead",
		Description = "Party boss bonus +5 points (does not stack). No tips on your orders.",
		Tier = 3,
		Price = 180, -- DEC-070 tier 3
		InMvp = false, -- first update (DEC-186)
		Effects = {
			{ Stat = "BossBonusPP", Op = "Add", Value = 5, Scope = "Party" }, -- does not stack (DEC-069)
			{ Stat = "TipAmount", Op = "Set", Value = 0, Scope = "Self" }, -- drawback (DEC-069)
		},
	},
} :: { Class })
