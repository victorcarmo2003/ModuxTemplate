--!strict
-- Rows of the class screen from Content (Classes, Species, Shop.GamePasses). Pure: no Vide, no network.
-- Skills: passive skill cards of Content.Classes (TASK-302), shown instead of the Description sentences.
-- Stats: attribute bars against the Rookie baseline (TASK-299), only from numbers Content already has.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

export type Entry = {
	Key: string,
	Title: string,
	Animal: string,
	Species: string,
	Badge: string,
	Icon: string,
	Price: number,
	Available: boolean,
	Blurb: string,
	Stats: { Stat },
	Skills: { Skill },
}

-- Passive skill card (TASK-302), from Content.Classes Skills.
export type Skill = {
	Name: string,
	Text: string,
	Icon: string, -- SkillImages key
	Kind: "Perk" | "Drawback",
}

-- One attribute bar of the card (TASK-299) around the Rookie baseline (the middle line); higher = better.
export type Stat = {
	Key: string,
	Label: string,
	Value: number,
	Base: number, -- Rookie (no effect)
	Text: string,
}

type Bar = {
	Key: string,
	Label: string,
	Stat: string, -- Content.Stats key
	Base: number,
	-- Effect value -> bar value (default: the stat value itself).
	Map: ((stat: number) -> number)?,
	Format: (value: number) -> string,
}

-- Bars from the numbers Content already has (Classes effects over RunParams / Sanity / ItemRules / OrderRules).
-- Conditional effects (owl by day, bear with 3 packages) show their value with the condition in the text.
const BARS: { Bar } = {
	{
		Key = "Speed",
		Label = "Speed",
		Stat = "WalkSpeed",
		Base = Content.RunParams.BaseWalkSpeed,
		Format = function(value: number): string
			return tostring(value)
		end,
	},
	{
		Key = "Sanity",
		Label = "Sanity",
		Stat = "SanityStart",
		Base = Content.Sanity.Start,
		Format = function(value: number): string
			return tostring(value)
		end,
	},
	{
		Key = "Carry",
		Label = "Carry",
		Stat = "PackageLimit",
		Base = Content.ItemRules.CategoryLimits.Package,
		Format = function(value: number): string
			return tostring(value)
		end,
	},
	{
		-- GrillTime is a time multiplier: 0.85 = "15% faster" (the class text)
		Key = "Grill",
		Label = "Grill",
		Stat = "GrillTime",
		Base = 100,
		Map = function(multiplier: number): number
			return math.floor(100 + (1 - multiplier) * 100 + 0.5)
		end,
		Format = function(value: number): string
			return `{value}%`
		end,
	},
	{
		Key = "Tips",
		Label = "Tips",
		Stat = "TipAmount",
		Base = Content.OrderRules.TipAmount,
		Format = function(value: number): string
			return `${value}`
		end,
	},
}

const WHEN_TEXT: { [string]: string } = {
	Day = "day",
	PackagesAtLeast = "loaded",
}

-- Bar value of one class (and the condition of its effect, if any).
local function barValue(bar: Bar, class: Content.Class): (number, string?)
	for _, effect in class.Effects do
		if effect.Stat == bar.Stat and effect.Scope == "Self" then
			local value = bar.Base
			if bar.Map then
				value = bar.Map(effect.Value)
			elseif effect.Op == "Set" then
				value = effect.Value
			elseif effect.Op == "Mul" then
				value = bar.Base * effect.Value
			else
				value = bar.Base + effect.Value
			end
			return value, if effect.When then WHEN_TEXT[effect.When] else nil
		end
	end
	return bar.Base, nil
end

local function stats(class: Content.Class): { Stat }
	const out: { Stat } = {}
	for _, bar in BARS do
		const value, condition = barValue(bar, class)
		const text = bar.Format(value)
		table.insert(out, {
			Key = bar.Key,
			Label = bar.Label,
			Value = value,
			Base = bar.Base,
			Text = if condition then `{text} {condition}` else text,
		})
	end
	return out
end

local function build(): { Entry }
	const list: { Entry } = {}
	for _, class in Content.Classes.List do
		const species = Content.Species.ByKey[class.Species]
		const animal = if species then species.Name else class.Species
		table.insert(list, {
			Key = class.Key,
			Title = class.Name,
			Animal = animal,
			Species = class.Species,
			Badge = string.upper(string.sub(animal, 1, 1)),
			Icon = `Class/{class.Key}`,
			Price = class.Price,
			Available = class.InMvp,
			Blurb = class.Blurb,
			Stats = stats(class),
			Skills = table.clone(class.Skills) :: { Skill },
		})
	end
	return list
end

-- Suggested Robux price of a class Game Pass (display fallback) and its PassId; nil = no pass (PassId 0 or not sold).
local function robux(key: string): (number?, number)
	const pass = Content.Shop.GamePasses.ByKey[key]
	if pass == nil or pass.PassId <= 0 then
		return nil, 0
	end
	return pass.Robux, pass.PassId
end

return table.freeze({
	Build = build,
	Robux = robux,
})
