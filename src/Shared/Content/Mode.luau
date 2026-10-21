--!strict
-- Game mode switch (owner requests 2026-10-14, Provisional; open-questions.md "pedidos do dono 2026-10-14"). The game is
-- an ANOMALY game played mostly at night, simpler and for kids: the day-shop systems are switched OFF, not deleted, so a
-- later "day-only mode" can bring them back by turning DayOnly on. ONE flag for every system that depends on it:
--   * tables (SeatingService: every table Locked/hidden, nobody sits, no buy_in_place / serve_table / clean_table;
--     SeatingController: no TableSign / PadTag), Patio Lights, Back Bar;
--   * the Counter line (Wide Counter, UPG-003) on the Gear Stand.
-- RetiredUpgrades (DEC-331) are off in EVERY mode: Storage ("cooler", split into Bun Box / Topping Rack / Coffee Shelf),
-- Coffee Maker and Trailer Lights. Their rows stay in Content.Upgrades so old run snapshots load.
-- DayOnlyUpgrades are never on sale while DayOnly = false (UpgradeService:CanBuy "locked", MarketService off the stand,
-- the client pedestal shows nothing). Their level stays where the run has it (StartLevel on a new run), so an old run
-- snapshot loads unchanged; while off, a Stat they own reads Fixed[stat] when listed there (else the current row).
-- Fixed (Provisional): QueueSize = 2 (Counter off), CoffeeBrewTime = 6 / CoffeeRestore = 25 (Coffee Maker retired, its level 1),
-- StockCapacityLevel = 1 (Storage retired), LightRadius = 0 / DayFlowBonus = 1 (Trailer Lights retired).
-- Fixed.QueueSize = 2: the counter holds two customers in the anomaly mode, so ANM-004 (the copied customer,
-- FreeSlots 2) can still start. At night CustomerService reads Flow.NightQueueSize = 1 instead (TASK-287: one NPC at
-- the counter at a time), so ANM-004 waits for its 1-by-1 design. Double grill (UPG-001) stays on sale.
local Stats = require(script.Parent.Stats)
local Table = require(script.Parent.Table)

export type Mode = {
	DayOnly: boolean, -- false = anomaly mode (default); true = the day-only mode with tables and Wide Counter
	DayOnlyUpgrades: { string }, -- keys of Content.Upgrades only sold in the day-only mode
	AnomalyOnlyUpgrades: { string }, -- keys of Content.Upgrades only sold in the anomaly mode (TASK-324)
	RetiredUpgrades: { string }, -- keys of Content.Upgrades off in every mode (DEC-331)
	Fixed: { [Stats.Stat]: number }, -- Stat values while their day-only upgrade is off
}

const mode: Mode = {
	DayOnly = false,
	DayOnlyUpgrades = { "counter", "trailer_tables", "patio_lights", "back_bar" },
	AnomalyOnlyUpgrades = { "bun_box", "topping_rack", "coffee_shelf", "breaker_box" },
	RetiredUpgrades = { "cooler", "coffee_maker", "trailer_lights" },
	Fixed = {
		QueueSize = 2,
		CoffeeBrewTime = 6,
		CoffeeRestore = 25,
		StockCapacityLevel = 1,
		LightRadius = 0,
		DayFlowBonus = 1,
	},
}

const dayOnly: { [string]: boolean } = {}
for _, key in mode.DayOnlyUpgrades do
	dayOnly[key] = true
end
const anomalyOnly: { [string]: boolean } = {}
for _, key in mode.AnomalyOnlyUpgrades do
	anomalyOnly[key] = true
end
const retired: { [string]: boolean } = {}
for _, key in mode.RetiredUpgrades do
	retired[key] = true
end

-- true = the upgrade is switched off in the current mode (never on sale)
local function isOff(upgradeKey: string): boolean
	if retired[upgradeKey] then
		return true
	end
	if mode.DayOnly then
		return anomalyOnly[upgradeKey] == true
	end
	return dayOnly[upgradeKey] == true
end

return Table.record({
	DayOnly = mode.DayOnly,
	DayOnlyUpgrades = mode.DayOnlyUpgrades,
	AnomalyOnlyUpgrades = mode.AnomalyOnlyUpgrades,
	RetiredUpgrades = mode.RetiredUpgrades,
	Fixed = mode.Fixed,
	IsOff = isOff,
})
