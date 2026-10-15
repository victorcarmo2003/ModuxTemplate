--!strict
-- Game mode switch (owner requests 2026-10-14, Provisional; open-questions.md "pedidos do dono 2026-10-14"). The game is
-- an ANOMALY game played mostly at night, simpler and for kids: the day-shop systems are switched OFF, not deleted, so a
-- later "day-only mode" can bring them back by turning DayOnly on. ONE flag for every system that depends on it:
--   * tables (SeatingService: every table Locked/hidden, nobody sits, no buy_in_place / serve_table / clean_table;
--     SeatingController: no TableSign / PadTag), Patio Lights, Back Bar;
--   * the day thief and the Cash Drawer Lock (ThiefService never plans an attempt);
--   * the Counter line (Wide Counter, UPG-003) on the Gear Stand.
-- DayOnlyUpgrades are never on sale while DayOnly = false (UpgradeService:CanBuy "locked", MarketService off the stand,
-- the client pedestal shows nothing). Their level stays where the run has it (StartLevel on a new run), so an old run
-- snapshot loads unchanged; while off, a Stat they own reads Fixed[stat] when listed there (else the current row).
-- Fixed.QueueSize = 2 (Provisional): the counter holds two customers in the anomaly mode, so ANM-004 (the copied customer,
-- FreeSlots 2) can still start. At night CustomerService reads Flow.NightQueueSize = 1 instead (TASK-287: one NPC at
-- the counter at a time), so ANM-004 waits for its 1-by-1 design. Double grill (UPG-001) stays on sale.
local Stats = require(script.Parent.Stats)
local Table = require(script.Parent.Table)

export type Mode = {
	DayOnly: boolean, -- false = anomaly mode (default); true = the day-only mode with tables, thief and Wide Counter
	DayOnlyUpgrades: { string }, -- keys of Content.Upgrades only sold in the day-only mode
	Fixed: { [Stats.Stat]: number }, -- Stat values while their day-only upgrade is off
}

const mode: Mode = {
	DayOnly = false,
	DayOnlyUpgrades = { "counter", "cash_drawer_lock", "trailer_tables", "patio_lights", "back_bar" },
	Fixed = { QueueSize = 2 },
}

const offSet: { [string]: boolean } = {}
for _, key in mode.DayOnlyUpgrades do
	offSet[key] = true
end

-- true = the upgrade is switched off in the current mode (never on sale)
local function isOff(upgradeKey: string): boolean
	return not mode.DayOnly and offSet[upgradeKey] == true
end

return Table.record({
	DayOnly = mode.DayOnly,
	DayOnlyUpgrades = mode.DayOnlyUpgrades,
	Fixed = mode.Fixed,
	IsOff = isOff,
})
