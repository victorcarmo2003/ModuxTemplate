--!strict
-- Upgrades with levels per vehicle (content-data.md §3.7; upgrades.md; FEAT-015; DEC-046, DEC-101, DEC-106, DEC-184).
-- Upgrades record id = IndexOf[key]. Levels[vehicle] lists every level from StartLevel to max, in order; the
-- first row is what the vehicle comes with (Price 0). Effects = absolute value of each Stat at that level.
-- DEC-184: levels are per vehicle. Since 2026-10-12 (user decision, Provisional) the trailer is the only vehicle, so every
-- upgrade has one Levels row (key "trailer"); the cart rows left. The prices are the old trailer ones (Q-163 a, c).
-- 2026-10-11 (TASK-144; FEAT-037, UPG-008..010; Q-178, Q-179, Provisional): SoldAt "InPlace" = bought on a prompt in
-- the world (SeatingService, action buy_in_place), never on the Gear Stand (BenchSpot ""); PlaceSpots[i] = where
-- level StartLevel + i is sold (TBL-n = table n of Content.Seating). Scope "Pad" (no row uses it any more) = the level
-- belongs to the Pad, not to the vehicle (kept for the code and Validate). Requires = another upgrade's minimum level on
-- the current vehicle before this one can be bought (UPG-009 needs 2 tables).
-- Provisional: Part names (UpgradePiece is found by tag + Upgrade/Level attributes, architecture.md §18.4 T38;
-- the trailer piece is another instance inside the trailer model). Final names with art-director / TASK-005.
local Stats = require(script.Parent.Stats)
local Table = require(script.Parent.Table)

export type Level = {
	Level: number,
	Price: number,
	Effects: { [Stats.Stat]: number },
	Part: string, -- UpgradePiece shown at this level; "" = none
}

export type SoldAt = "Bench" | "InPlace"
export type Scope = "Vehicle" | "Pad"
export type Requires = { Upgrade: string, Level: number }

export type Upgrade = {
	Key: string,
	Ref: string,
	Name: string,
	Vehicles: { string }, -- keys of Vehicles where the upgrade exists
	StartLevel: number,
	Levels: { [string]: { Level } }, -- per vehicle key
	UnlockDay: number,
	SoldAt: SoldAt,
	BenchSpot: string, -- B1..B5 when SoldAt = "Bench"; "" when "InPlace"
	PlaceSpots: { string }, -- SoldAt "InPlace": spot of each purchasable level, in order; {} on the bench
	Scope: Scope, -- "Vehicle" (DEC-184: the trailer starts over) or "Pad" (kept across the swap, Q-179 a)
	Requires: Requires?, -- prerequisite on the current vehicle (UPG-009: trailer_tables >= 2)
	Cooldown: boolean?, -- false = this Bench line has no Gear Stand cooldown (Counter, DEC-241); nil / true = Mart.Cooldown
}

-- UPG-001 Grill: 2 slots/8 s -> 3/6 s $60 -> 4/4 s $150 (DEC-046; times reworked 2026-10-14, slowed the same day: too fast to follow).
-- GrillTime is the whole cook: (GrillTime - Rules.Grill.PostFlip) s on the first side, then the sausage WAITS for the flip, then
-- PostFlip s (2 s) and it is ready, so the first side takes 6 / 4 / 2 s by level. Bar grill, one sausage per roller; each level = more rollers (DEC-138, DEC-201).
const grillTrailer: { Level } = {
	{ Level = 1, Price = 0, Effects = { GrillSlots = 2, GrillTime = 8 }, Part = "Grill_L1" },
	{ Level = 2, Price = 60, Effects = { GrillSlots = 3, GrillTime = 6 }, Part = "Grill_L2" }, -- Q-163 a
	{ Level = 3, Price = 150, Effects = { GrillSlots = 4, GrillTime = 4 }, Part = "Grill_L3" }, -- Q-163 a
}

-- UPG-002 Storage (was "Cooler"; owner request 2026-10-14, Provisional): the FIRST upgrade of the run (the Day 1 upgrade
-- lesson, TutorialService). Level 1 + three purchases; each level raises every stock by the steps of
-- Ingredients.Capacity (buns +4: 12/16/20/24; ketchup and mustard +5: 15/20/25/30, the old level-1 30 at the top; the
-- other toppings the same shape). Prices $40 / $70 / $110 (Provisional, economy.md §2: was $50 / $120 for two levels).
-- The key stays "cooler" (record id, run snapshots "Upg"); the old level numbers 1..3 still load (rows 1..4 exist).
const coolerTrailer: { Level } = {
	{ Level = 1, Price = 0, Effects = { StockCapacityLevel = 1 }, Part = "Cooler_L1" },
	{ Level = 2, Price = 40, Effects = { StockCapacityLevel = 2 }, Part = "Cooler_L2" },
	{ Level = 3, Price = 70, Effects = { StockCapacityLevel = 3 }, Part = "Cooler_L3" },
	-- the map has Cooler_L1..L3: level 4 reuses Cooler_L3 (same Part = same piece, UpgradeService:RefreshPiece)
	{ Level = 4, Price = 110, Effects = { StockCapacityLevel = 4 }, Part = "Cooler_L3" },
	-- TASK-324 (owner request 2026-10-15, Provisional): one more level so the anomaly run has more to buy
	{ Level = 5, Price = 120, Effects = { StockCapacityLevel = 5 }, Part = "Cooler_L3" },
}

-- UPG-013 Coffee Maker (TASK-324, owner request 2026-10-15, Provisional; anomaly mode only, B3): the factory machine
-- (UPG-007) brews faster and a stronger cup. CoffeeBrewTime / CoffeeRestore are the base the class reads over
-- (CoffeeMachine station passes them to ClassService:GetModifier): 6 s / +25 -> 5 s / +30 ($40) -> 4 s / +35 ($70).
-- No piece on the trailer (Part names a Gear Stand miniature only; placeholder box until the art exists).
const coffeeMakerTrailer: { Level } = {
	{ Level = 1, Price = 0, Effects = { CoffeeBrewTime = 6, CoffeeRestore = 25 }, Part = "" },
	{ Level = 2, Price = 40, Effects = { CoffeeBrewTime = 5, CoffeeRestore = 30 }, Part = "CoffeeMaker_L2" },
	{ Level = 3, Price = 70, Effects = { CoffeeBrewTime = 4, CoffeeRestore = 35 }, Part = "CoffeeMaker_L3" },
}

-- UPG-014 Breaker Box (TASK-324, owner request 2026-10-15, Provisional; anomaly mode only, B4): the breaker of the
-- blackout (ANM-020, family C) resets faster. BreakerHold = hold of the breaker_reset prompt (LightService sets
-- PromptHold): 3 s (Actions.breaker_reset) -> 2 s ($30) -> 1 s ($60).
const breakerBoxTrailer: { Level } = {
	{ Level = 0, Price = 0, Effects = { BreakerHold = 3 }, Part = "" },
	{ Level = 1, Price = 30, Effects = { BreakerHold = 2 }, Part = "Breaker_L1" },
	{ Level = 2, Price = 60, Effects = { BreakerHold = 1 }, Part = "Breaker_L2" },
}

-- UPG-003 Counter (DEC-241, user decision 2026-10-13; prices Provisional): the line starts with ONE customer (the one at
-- the counter) and grows to 5: QueueSize 1/2/3/4/5, PatienceBonus 0/+5/+10/+15/+20 s, $0/$30/$60/$100/$150. No Gear
-- Stand cooldown on this line (Cooldown = false). The map only has the pieces Counter_L1..L3: levels 4 and 5 reuse
-- Counter_L3 (UpgradeService shows a piece while the current row has the same Part).
const counterTrailer: { Level } = {
	{ Level = 1, Price = 0, Effects = { QueueSize = 1, PatienceBonus = 0 }, Part = "Counter_L1" },
	{ Level = 2, Price = 30, Effects = { QueueSize = 2, PatienceBonus = 5 }, Part = "Counter_L2" },
	{ Level = 3, Price = 60, Effects = { QueueSize = 3, PatienceBonus = 10 }, Part = "Counter_L3" },
	{ Level = 4, Price = 100, Effects = { QueueSize = 4, PatienceBonus = 15 }, Part = "Counter_L3" },
	{ Level = 5, Price = 150, Effects = { QueueSize = 5, PatienceBonus = 20 }, Part = "Counter_L3" },
}

-- UPG-004 Cash Drawer Lock: thief opens in 8 s and steals 50% -> 16 s / 30% for $80 (DEC-046, DEC-050).
const drawerLockTrailer: { Level } = {
	{ Level = 0, Price = 0, Effects = { DrawerOpenTime = 8, StealPct = 50 }, Part = "" },
	{ Level = 1, Price = 80, Effects = { DrawerOpenTime = 16, StealPct = 30 }, Part = "DrawerLock_L1" }, -- Q-163 a, c
}

-- UPG-005 Trailer Lights, trailer only, $100: day flow x1.1, night LightZone radius 18 studs (DEC-046, DEC-055).
const trailerLightsTrailer: { Level } = {
	{ Level = 0, Price = 0, Effects = { LightRadius = 0, DayFlowBonus = 1 }, Part = "" },
	{ Level = 1, Price = 100, Effects = { LightRadius = 18, DayFlowBonus = 1.1 }, Part = "TrailerLights_L1" },
}

-- UPG-011 Trailer Tables (FEAT-037; user decisions 2026-10-12; Provisional, Q-209): the four tables at the Pad, bought in
-- place at the ghost table: TBL-1 -> TBL-4 (renumbered from 6..9 when the trailer became the only vehicle; the old Patio
-- Tables UPG-008 are gone). $30 / $45 / $60 / $80 = $215 (the first four UPG-008 prices; Provisional).
const trailerTablesTrailer: { Level } = {
	{ Level = 0, Price = 0, Effects = { TrailerTableCount = 0 }, Part = "" },
	{ Level = 1, Price = 30, Effects = { TrailerTableCount = 1 }, Part = "" },
	{ Level = 2, Price = 45, Effects = { TrailerTableCount = 2 }, Part = "" },
	{ Level = 3, Price = 60, Effects = { TrailerTableCount = 3 }, Part = "" },
	{ Level = 4, Price = 80, Effects = { TrailerTableCount = 4 }, Part = "" },
}

-- UPG-009 Patio Lights (FEAT-037; Provisional): $120, SitChance +0.10 day and night; at night the LZ-PATIO light zone
-- on the trailer switch (not wired yet: needs the LightGroups row + the binding volume, board note of TASK-145).
local function patioLights(): { Level }
	return {
		{ Level = 0, Price = 0, Effects = { SitBonus = 0 }, Part = "" },
		{ Level = 1, Price = 120, Effects = { SitBonus = 0.10 }, Part = "" },
	}
end

-- UPG-010 Back Bar (Q-179 b; Provisional, cuttable): $90, trailer only, one more table spot (TBL-BAR). Listed for the
-- contract; SeatingService does not sell it yet (TBL-6..9 became the Trailer tables, UPG-011).
const backBarTrailer: { Level } = {
	{ Level = 0, Price = 0, Effects = {}, Part = "" },
	{ Level = 1, Price = 90, Effects = {}, Part = "" },
}

-- Bench spots B1..B5, always on sale, no rotation (DEC-101, DEC-106; FEAT-015). UnlockDay 1 = from the first day.
return Table.new({
	{
		Key = "grill",
		Ref = "UPG-001",
		Name = "Grill",
		Vehicles = { "trailer" },
		StartLevel = 1,
		Levels = { trailer = grillTrailer },
		UnlockDay = 1,
		SoldAt = "Bench",
		BenchSpot = "B1",
		PlaceSpots = {},
		Scope = "Vehicle",
	},
	{
		Key = "cooler",
		Ref = "UPG-002",
		Name = "Storage",
		Vehicles = { "trailer" },
		StartLevel = 1,
		Levels = { trailer = coolerTrailer },
		UnlockDay = 1,
		SoldAt = "Bench",
		BenchSpot = "B2",
		PlaceSpots = {},
		Scope = "Vehicle",
	},
	{
		Key = "counter",
		Ref = "UPG-003",
		Name = "Counter",
		Vehicles = { "trailer" },
		StartLevel = 1,
		Levels = { trailer = counterTrailer },
		UnlockDay = 1,
		SoldAt = "Bench",
		BenchSpot = "B3",
		PlaceSpots = {},
		Scope = "Vehicle",
		Cooldown = false, -- DEC-241: the Counter can be bought shift after shift
	},
	{
		Key = "cash_drawer_lock",
		Ref = "UPG-004",
		Name = "Drawer Lock",
		Vehicles = { "trailer" },
		StartLevel = 0,
		Levels = { trailer = drawerLockTrailer },
		UnlockDay = 1,
		SoldAt = "Bench",
		BenchSpot = "B4",
		PlaceSpots = {},
		Scope = "Vehicle",
	},
	{
		Key = "trailer_lights",
		Ref = "UPG-005",
		Name = "Trailer Lights",
		Vehicles = { "trailer" }, -- FEAT-015, DEC-055
		StartLevel = 0,
		Levels = { trailer = trailerLightsTrailer },
		UnlockDay = 1,
		SoldAt = "Bench",
		BenchSpot = "B5",
		PlaceSpots = {},
		Scope = "Vehicle",
	},
	-- Anomaly mode only (Content.Mode.AnomalyOnlyUpgrades, TASK-324): the pedestals of Counter (B3) and Drawer Lock (B4)
	{
		Key = "coffee_maker",
		Ref = "UPG-013",
		Name = "Coffee Maker",
		Vehicles = { "trailer" },
		StartLevel = 1,
		Levels = { trailer = coffeeMakerTrailer },
		UnlockDay = 1,
		SoldAt = "Bench",
		BenchSpot = "B3",
		PlaceSpots = {},
		Scope = "Vehicle",
	},
	{
		Key = "breaker_box",
		Ref = "UPG-014",
		Name = "Breaker Box",
		Vehicles = { "trailer" },
		StartLevel = 0,
		Levels = { trailer = breakerBoxTrailer },
		UnlockDay = 1,
		SoldAt = "Bench",
		BenchSpot = "B4",
		PlaceSpots = {},
		Scope = "Vehicle",
	},
	-- In place (TASK-144; FEAT-037; Q-178 A): not on the Gear Stand
	{
		Key = "patio_lights",
		Ref = "UPG-009",
		Name = "Patio Lights",
		Vehicles = { "trailer" },
		StartLevel = 0,
		Levels = { trailer = patioLights() },
		UnlockDay = 2,
		SoldAt = "InPlace",
		BenchSpot = "",
		PlaceSpots = { "PATIO-LIGHTS" }, -- sign next to TBL-1 (UPG-009)
		Scope = "Vehicle",
		Requires = { Upgrade = "trailer_tables", Level = 2 },
	},
	{
		Key = "back_bar",
		Ref = "UPG-010",
		Name = "Back Bar",
		Vehicles = { "trailer" },
		StartLevel = 0,
		Levels = { trailer = backBarTrailer },
		UnlockDay = 1,
		SoldAt = "InPlace",
		BenchSpot = "",
		PlaceSpots = { "TBL-BAR" }, -- TBL-1..4 are the tables (UPG-011)
		Scope = "Vehicle",
	},
	{
		Key = "trailer_tables",
		Ref = "UPG-011",
		Name = "Trailer Table",
		Vehicles = { "trailer" },
		StartLevel = 0,
		Levels = { trailer = trailerTablesTrailer },
		UnlockDay = 1,
		SoldAt = "InPlace",
		BenchSpot = "",
		PlaceSpots = { "TBL-1", "TBL-2", "TBL-3", "TBL-4" },
		Scope = "Vehicle",
	},
} :: { Upgrade })
