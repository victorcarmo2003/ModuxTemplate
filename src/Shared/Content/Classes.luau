--!strict
-- Playable classes: animal = class (content-data.md §3.10; DEC-069, DEC-070, DEC-186).
-- STUB (TASK-003): keys, species and effects from content-data.md v4; names/descriptions/numbers reviewed in TASK-009.
-- Keys are persisted in the profile (Classes, SelectedClass) and are the Profile/ClassAction enum: never rename.
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
	Description: string,
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
		Description = "",
		Tier = 0,
		Price = 0, -- every new account owns it (DEC-186)
		InMvp = true,
		Effects = {},
	},
	{
		Key = "class_rabbit",
		Ref = "CLS-002",
		Species = "rabbit",
		Name = "Runner",
		Description = "",
		Tier = 1,
		Price = 45,
		InMvp = true,
		Effects = {
			{ Stat = "WalkSpeed", Op = "Set", Value = 18, Scope = "Self" },
			{ Stat = "SanityStart", Op = "Set", Value = 90, Scope = "Self" },
		},
	},
	{
		Key = "class_cat",
		Ref = "CLS-003",
		Species = "cat",
		Name = "Line Cook",
		Description = "",
		Tier = 1,
		Price = 45,
		InMvp = true,
		Effects = {
			{ Stat = "GrillTime", Op = "Mul", Value = 0.85, Scope = "Self" }, -- only sausages he placed
			{ Stat = "WalkSpeed", Op = "Set", Value = 15, Scope = "Self" },
		},
	},
	{
		Key = "class_bear",
		Ref = "CLS-004",
		Species = "bear",
		Name = "Hauler",
		Description = "",
		Tier = 1,
		Price = 45,
		InMvp = true,
		Effects = {
			{ Stat = "PackageLimit", Op = "Set", Value = 3, Scope = "Self" },
			{ Stat = "WalkSpeed", Op = "Set", Value = 14, Scope = "Self", When = "PackagesAtLeast", WhenValue = 3 },
		},
	},
	{
		Key = "class_fox",
		Ref = "CLS-005",
		Species = "fox",
		Name = "Hawker",
		Description = "",
		Tier = 2,
		Price = 120,
		InMvp = true,
		Effects = {
			{ Stat = "TipAmount", Op = "Set", Value = 2, Scope = "Self" },
			{ Stat = "TipWindow", Op = "Add", Value = -4, Scope = "Self" },
		},
	},
	{
		Key = "class_owl",
		Ref = "CLS-006",
		Species = "owl",
		Name = "Night Owl",
		Description = "",
		Tier = 2,
		Price = 120,
		InMvp = true,
		Effects = {
			{ Stat = "SanityStart", Op = "Set", Value = 120, Scope = "Self" },
			{ Stat = "SanityMax", Op = "Set", Value = 120, Scope = "Self" },
			{ Stat = "WalkSpeed", Op = "Set", Value = 15, Scope = "Self", When = "Day" },
		},
	},
	{
		Key = "class_panda",
		Ref = "CLS-007",
		Species = "panda",
		Name = "Barista",
		Description = "",
		Tier = 2,
		Price = 120,
		InMvp = false, -- first update
		Effects = {
			{ Stat = "CoffeeBrewTime", Op = "Set", Value = 3, Scope = "Self" },
			{ Stat = "CoffeeRestore", Op = "Set", Value = 35, Scope = "Self" },
			{ Stat = "SeeAnomalyLoss", Op = "Set", Value = 8, Scope = "Self" },
		},
	},
	{
		Key = "class_lion",
		Ref = "CLS-008",
		Species = "lion",
		Name = "Shift Lead",
		Description = "",
		Tier = 3,
		Price = 180,
		InMvp = false, -- first update
		Effects = {
			{ Stat = "BossBonusPP", Op = "Add", Value = 5, Scope = "Party" }, -- does not stack
			{ Stat = "TipAmount", Op = "Set", Value = 0, Scope = "Self" },
		},
	},
} :: { Class })
