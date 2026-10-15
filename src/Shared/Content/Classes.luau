--!strict
-- Playable classes: animal = class (content-data.md §3.10; DEC-069, DEC-070, DEC-186).
-- TASK-009: 6 in the MVP (dog, rabbit, cat, bear, fox, owl), panda/lion in the first update (DEC-186).
-- Bonus + drawback are passive (DEC-186), numbers unchanged from DEC-069. Gem prices x75 economy (TASK-308, owner request
-- 2026-10-15, Provisional; was 0/45/120/180 by tier, DEC-070): 0 / 2,000 / 3,000 / 10,000 / 15,000 / 20,000.
-- Keys are persisted in the profile (Classes, SelectedClass) and are the Profile/ClassAction enum: never rename.
-- Name, Description and Blurb are placeholders (narrative-writer, DEC-022, ui-text.md "Crew" screen): change text, not keys.
-- Raccoon is never a class species (DEC-159, DEC-186): Validate checks Species.ReservedFor.
local Stats = require(script.Parent.Stats)
local Table = require(script.Parent.Table)

export type Op = "Set" | "Mul" | "Add"
export type Scope = "Self" | "Party"
export type When = "Always" | "Day" | "Night" | "PackagesAtLeast"
export type SkillKind = "Perk" | "Drawback"

-- A passive skill card of the class screen (TASK-302): presentation only of the class Effects (DEC-069), never
-- a rule of its own. Icon = key of Assets/textures/ui/skills (tools/icons/skill_icons.py). Names / texts Provisional.
export type Skill = {
	Name: string,
	Text: string,
	Icon: string,
	Kind: SkillKind,
}

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
	Blurb: string, -- placeholder flavour line of the class card, 1-2 short lines (narrative-writer; Provisional, TASK-299)
	Skills: { Skill }, -- passive skill cards (TASK-302): perks first, then drawbacks
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
		Blurb = "Fresh on the crew and ready for any shift.",
		Skills = {
			{
				Name = "All-Rounder",
				Text = "All-Rounder keeps every stat at the crew standard.",
				Icon = "skill_all_round",
				Kind = "Perk",
			},
		},
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
		Blurb = "Quick on the feet, a bit jumpy after dark.",
		Skills = {
			{
				Name = "Quick Legs",
				Text = "Quick Legs gives you a move speed bonus.",
				Icon = "skill_quick_legs",
				Kind = "Perk",
			},
			{
				Name = "Jumpy",
				Text = "Jumpy starts each night with 90 sanity.",
				Icon = "skill_jumpy",
				Kind = "Drawback",
			},
		},
		Tier = 1,
		Price = 2000, -- tier 1 (TASK-308; DEC-070 was 45)
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
		Blurb = "Knows every inch of the grill by heart.",
		Skills = {
			{
				Name = "Grill Master",
				Text = "Grill Master cooks your sausages 15% faster.",
				Icon = "skill_grill_master",
				Kind = "Perk",
			},
			{
				Name = "Short Strides",
				Text = "Short Strides makes you walk a little slower.",
				Icon = "skill_short_strides",
				Kind = "Drawback",
			},
		},
		Tier = 1,
		Price = 2000, -- tier 1 (TASK-308; DEC-070 was 45)
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
		Blurb = "Big arms, big loads, steady pace.",
		Skills = {
			{
				Name = "Bear Hug",
				Text = "Bear Hug lets you carry 3 packages.",
				Icon = "skill_bear_hug",
				Kind = "Perk",
			},
			{
				Name = "Heavy Load",
				Text = "Heavy Load slows you down while carrying 3.",
				Icon = "skill_heavy_load",
				Kind = "Drawback",
			},
		},
		Tier = 1,
		Price = 3000, -- tier 1, top of it (TASK-308; DEC-070 was 45); in the MVP since DEC-186
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
		Blurb = "Charms a tip out of anyone, if you are quick.",
		Skills = {
			{
				Name = "Sweet Talk",
				Text = "Sweet Talk earns $2 tips on your orders.",
				Icon = "skill_sweet_talk",
				Kind = "Perk",
			},
			{
				Name = "Short Fuse",
				Text = "Short Fuse makes the tip window 4 s shorter.",
				Icon = "skill_short_fuse",
				Kind = "Drawback",
			},
		},
		Tier = 2,
		Price = 10000, -- tier 2 (TASK-308; DEC-070 was 120); in the MVP since DEC-186
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
		Blurb = "Wide awake when the street goes quiet.",
		Skills = {
			{
				Name = "Wide Awake",
				Text = "Wide Awake starts nights with 120 max sanity.",
				Icon = "skill_wide_awake",
				Kind = "Perk",
			},
			{
				Name = "Daydreamer",
				Text = "Daydreamer makes you walk slower by day.",
				Icon = "skill_daydreamer",
				Kind = "Drawback",
			},
		},
		Tier = 2,
		Price = 10000, -- tier 2 (TASK-308; DEC-070 was 120)
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
		Blurb = "Brews the strongest coffee on the block.",
		Skills = {
			{
				Name = "Double Shot",
				Text = "Double Shot: 3 s coffee that restores 35.",
				Icon = "skill_double_shot",
				Kind = "Perk",
			},
			{
				Name = "Spooked",
				Text = "Spooked makes seeing anomalies hit harder.",
				Icon = "skill_spooked",
				Kind = "Drawback",
			},
		},
		Tier = 2,
		Price = 15000, -- tier 2, top of it (TASK-308; DEC-070 was 120)
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
		Blurb = "Runs the crew like it owns the stand.",
		Skills = {
			{
				Name = "Rally Cry",
				Text = "Rally Cry gives the party +5 boss bonus.",
				Icon = "skill_rally_cry",
				Kind = "Perk",
			},
			{
				Name = "Big Ego",
				Text = "Big Ego gets no tips on your orders.",
				Icon = "skill_big_ego",
				Kind = "Drawback",
			},
		},
		Tier = 3,
		Price = 20000, -- tier 3 (TASK-308; DEC-070 was 180)
		InMvp = false, -- first update (DEC-186)
		Effects = {
			{ Stat = "BossBonusPP", Op = "Add", Value = 5, Scope = "Party" }, -- does not stack (DEC-069)
			{ Stat = "TipAmount", Op = "Set", Value = 0, Scope = "Self" }, -- drawback (DEC-069)
		},
	},
} :: { Class })
