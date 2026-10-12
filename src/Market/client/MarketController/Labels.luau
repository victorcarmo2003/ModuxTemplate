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
	cooler = { "Small Cooler", "Big Cooler", "Deep Chill Cooler" },
	counter = { "Little Counter", "Wide Counter", "Long Counter" },
	cash_drawer_lock = { [1] = "Drawer Lock" },
	trailer_lights = { [1] = "Trailer Lights" },
}

-- The Cooler line quotes the sausage box (the first thing a new player restocks).
const COOLER_SAMPLE = "sausage"

const Labels = {
	OutOfStock = "Out of stock",
	Maxed = "MAX",
	TrailerOnly = "Trailer only",
	NothingSpecial = "Nothing special today",
}

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
		const sample = Content.Ingredients.ByKey[COOLER_SAMPLE]
		const capacity = if sample then sample.Capacity[effects.StockCapacityLevel or 1] else nil
		return if capacity then `Holds {number(capacity)} sausages` else "More stock"
	elseif key == "counter" then
		return `{number(effects.QueueSize or 0)} in line · +{number(effects.PatienceBonus or 0)} s`
	elseif key == "cash_drawer_lock" then
		return `Thief {number(effects.DrawerOpenTime or 0)} s · {number(effects.StealPct or 0)}%`
	elseif key == "trailer_lights" then
		const bonus = math.floor(((effects.DayFlowBonus or 1) - 1) * 100 + 0.5)
		return `+{number(bonus)}% customers`
	end
	return ""
end

return table.freeze(Labels)
