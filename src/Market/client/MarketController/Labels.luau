--!strict
-- World texts of the Mart (FEAT-008, FEAT-015; `story/ui-text.md` §2-§3). Pure functions over Content: no Vide,
-- no network, no Modux. Owner of the wording: narrative-writer; this file only applies it.
-- Provisional (TASK-037):
--   * level names are the ui-text.md §3 proposals (Draft), Content.Upgrades has only the upgrade name;
--   * effect lines ("3 spots · 10 s") are written here from the level Effects until ui-text.md has them;
--   * "MAX" on the Gear Stand plate (FEAT-015 v2 table, ui-text.md §2; was "Maxed" on the GEAR WALL card, TASK-140);
--   * "Day N" under "Out of stock" (FEAT-008 proposal, DEC-180 keeps it Draft);
--   * badge = first letter of the upgrade until the AST-071 renders exist (Q-152).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

const LEVEL_NAMES: { [string]: { [number]: string } } = {
	grill = { "Old Grill", "Double Grill", "Big Sizzle Grill" },
	cooler = { "Small Storage", "Storage 2", "Storage 3", "Big Storage", "Huge Storage" }, -- owner request 2026-10-14 (Provisional names; level 5 TASK-324)
	counter = { "Little Counter", "Wide Counter", "Long Counter" },
	trailer_lights = { [1] = "Patio Lights" },
	-- DEC-331 (Provisional names): the capacity lines on B2 / B3 / B4 (cooler, coffee_maker and trailer_lights above are retired)
	bun_box = { "Small Bun Box", "Bun Box", "Big Bun Box" },
	topping_rack = { "Little Rack", "Topping Rack", "Full Rack" },
	coffee_shelf = { "Coffee Shelf", "Big Shelf", "Full Shelf" },
	coffee_maker = { "Coffee Maker", "Quick Brew", "Strong Brew" },
	breaker_box = { [0] = "Old Breaker", [1] = "Quick Breaker", [2] = "Snap Breaker" },
}

-- The capacity lines (UPG-035..037, DEC-331) quote Ingredients[x].Capacity at the level of the row.
const BUN_SAMPLE = "bun"
const SAUCE_SAMPLE = "ketchup"
const TOPPING_SAMPLE = "cheese"
const COFFEE_SAMPLE = "coffee"

const Labels = {
	OutOfStock = "Out of stock",
	Maxed = "MAX",
	TrailerOnly = "Trailer only",
	NothingSpecial = "Nothing special today",
	SoldOut = "Sold out",
}

-- "Back next shift" / "Back in 2 shifts" (Gear Stand cooldown, Q-203): shifts left before the line is on sale again.
function Labels.Back(wait: number): string
	return if wait <= 1 then "Back next shift" else `Back in {string.format("%d", wait)} shifts`
end

local function number(value: number): string
	return if value % 1 == 0 then string.format("%d", value) else string.format("%g", value)
end

-- Capacity of `ingredient` at `level`; nil when the row is missing
local function capacityOf(ingredient: string, level: number): number?
	const row = Content.Ingredients.ByKey[ingredient]
	return if row then row.Capacity[level] else nil
end

function Labels.Price(price: number): string
	return "$" .. number(price)
end

-- "Day 3" for an ingredient that unlocks on a day; "" when the unlock is not a day (Coffee: trailer).
function Labels.UnlockDay(ingredient: Content.Ingredient): string
	return if ingredient.UnlockDay > 0 then "Day " .. number(ingredient.UnlockDay) else ""
end

function Labels.LevelName(upgrade: Content.Upgrade, level: number): string
	const names = LEVEL_NAMES[upgrade.Key]
	return if names and names[level] then names[level] else upgrade.Name
end

function Labels.Badge(upgrade: Content.Upgrade): string
	return string.upper(string.sub(upgrade.Name, 1, 1))
end

-- Effect of a level in one line (FEAT-015: "3 spots · 10 s").
function Labels.Effect(upgrade: Content.Upgrade, row: Content.UpgradeLevel): string
	const effects = row.Effects
	const key = upgrade.Key
	if key == "grill" then
		return `{number(effects.GrillSlots or 0)} spots · {number(effects.GrillTime or 0)} s`
	elseif key == "bun_box" then
		const buns = capacityOf(BUN_SAMPLE, effects.BunCapacityLevel or 1)
		return if buns then `{number(buns)} buns & sausages` else "More stock"
	elseif key == "topping_rack" then
		const level = effects.ToppingCapacityLevel or 1
		const sauces = capacityOf(SAUCE_SAMPLE, level)
		const toppings = capacityOf(TOPPING_SAMPLE, level)
		return if sauces and toppings then `{number(sauces)} sauce · {number(toppings)} toppings` else "More stock"
	elseif key == "coffee_shelf" then
		const coffees = capacityOf(COFFEE_SAMPLE, effects.CoffeeCapacityLevel or 1)
		return if coffees then `{number(coffees)} coffees` else "More stock"
	elseif key == "counter" then
		return `{number(effects.QueueSize or 0)} in line · +{number(effects.PatienceBonus or 0)} s`
	elseif key == "trailer_lights" then
		const bonus = math.floor(((effects.DayFlowBonus or 1) - 1) * 100 + 0.5)
		return `+{number(bonus)}% customers`
	elseif key == "coffee_maker" then
		return `{number(effects.CoffeeBrewTime or 0)} s brew · +{number(effects.CoffeeRestore or 0)} sanity`
	elseif key == "breaker_box" then
		return `Power back in {number(effects.BreakerHold or 0)} s`
	end
	return ""
end

return table.freeze(Labels)
