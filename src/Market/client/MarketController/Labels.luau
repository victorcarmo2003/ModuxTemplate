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
	cash_drawer_lock = { [1] = "Drawer Lock" },
	trailer_lights = { [1] = "Patio Lights" },
	-- TASK-324 (Provisional names): anomaly-mode lines on B3 / B4
	coffee_maker = { "Coffee Maker", "Quick Brew", "Strong Brew" },
	breaker_box = { [0] = "Old Breaker", [1] = "Quick Breaker", [2] = "Snap Breaker" },
}

-- The Storage line (UPG-002) quotes the buns and the sauce bowls.
const COOLER_SAMPLE = "bun" -- Storage plate: buns + sauce (owner request 2026-10-14)
const SAUCE_SAMPLE = "ketchup"

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
	elseif key == "cooler" then
		-- Storage (owner request 2026-10-14): buns and sauce, the two stocks the first upgrade is about
		const level = effects.StockCapacityLevel or 1
		const bun = Content.Ingredients.ByKey[COOLER_SAMPLE]
		const sauce = Content.Ingredients.ByKey[SAUCE_SAMPLE]
		const buns = if bun then bun.Capacity[level] else nil
		const sauces = if sauce then sauce.Capacity[level] else nil
		return if buns and sauces then `{number(buns)} buns · {number(sauces)} sauce` else "More stock"
	elseif key == "counter" then
		return `{number(effects.QueueSize or 0)} in line · +{number(effects.PatienceBonus or 0)} s`
	elseif key == "cash_drawer_lock" then
		return `Thief {number(effects.DrawerOpenTime or 0)} s · {number(effects.StealPct or 0)}%`
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
