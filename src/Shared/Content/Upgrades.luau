--!strict
-- Upgrades with levels per vehicle (content-data.md §3.7; upgrades.md; FEAT-015; DEC-046, DEC-101, DEC-106, DEC-184).
-- Upgrades record id = IndexOf[key]. Levels[vehicle] lists every level from StartLevel to max, in order; the
-- first row is what the vehicle comes with (Price 0). Effects = absolute value of each Stat at that level.
-- DEC-184: levels are per vehicle and the trailer starts over at StartLevel. Cart and trailer rows are written out
-- separately so a trailer price is a number change only.
-- Provisional: trailer prices = cart prices and Drawer Lock bought again on the trailer (Q-163 a, c).
-- 2026-10-11 (TASK-144; FEAT-037, UPG-008..010; Q-178, Q-179, Provisional): SoldAt "InPlace" = bought on a prompt in
-- the world (SeatingService, action buy_in_place), never on the Gear Stand (BenchSpot ""); PlaceSpots[i] = where
-- level StartLevel + i is sold (TBL-n = table n of Content.Seating). Scope "Pad" = the level belongs to the Pad, not
-- to the vehicle: UpgradeService writes it on every vehicle at once, so the cart -> trailer swap keeps it (Q-179 a);
-- Levels of a Pad upgrade are identical on every vehicle (Validate). Requires = another upgrade's minimum level on the
-- current vehicle before this one can be bought (UPG-009 needs 2 tables).
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
	Requires: Requires?, -- prerequisite on the current vehicle (UPG-009: patio_tables >= 2)
}

-- UPG-001 Grill: 2 slots/12 s -> 3/10 s $60 -> 4/8 s $150 (DEC-046). Roller grill, one sausage per roller pair,
-- each level = more rollers on the same machine (DEC-138, DEC-201).
const grillCart: { Level } = {
	{ Level = 1, Price = 0, Effects = { GrillSlots = 2, GrillTime = 12 }, Part = "Grill_L1" },
	{ Level = 2, Price = 60, Effects = { GrillSlots = 3, GrillTime = 10 }, Part = "Grill_L2" },
	{ Level = 3, Price = 150, Effects = { GrillSlots = 4, GrillTime = 8 }, Part = "Grill_L3" },
}
const grillTrailer: { Level } = {
	{ Level = 1, Price = 0, Effects = { GrillSlots = 2, GrillTime = 12 }, Part = "Grill_L1" },
	{ Level = 2, Price = 60, Effects = { GrillSlots = 3, GrillTime = 10 }, Part = "Grill_L2" }, -- Q-163 a
	{ Level = 3, Price = 150, Effects = { GrillSlots = 4, GrillTime = 8 }, Part = "Grill_L3" }, -- Q-163 a
}

-- UPG-002 Cooler: capacity level 1 -> 2 $50 -> 3 $120 (DEC-046, DEC-049). Per-ingredient numbers live in
-- Ingredients.Capacity (one entry per level; Q-062 for cream cheese).
const coolerCart: { Level } = {
	{ Level = 1, Price = 0, Effects = { StockCapacityLevel = 1 }, Part = "Cooler_L1" },
	{ Level = 2, Price = 50, Effects = { StockCapacityLevel = 2 }, Part = "Cooler_L2" },
	{ Level = 3, Price = 120, Effects = { StockCapacityLevel = 3 }, Part = "Cooler_L3" },
}
const coolerTrailer: { Level } = {
	{ Level = 1, Price = 0, Effects = { StockCapacityLevel = 1 }, Part = "Cooler_L1" },
	{ Level = 2, Price = 50, Effects = { StockCapacityLevel = 2 }, Part = "Cooler_L2" }, -- Q-163 a
	{ Level = 3, Price = 120, Effects = { StockCapacityLevel = 3 }, Part = "Cooler_L3" }, -- Q-163 a
}

-- UPG-003 Counter: queue 3 -> 4 +10 s patience $70 -> 5 +20 s $160 (DEC-046, DEC-072).
const counterCart: { Level } = {
	{ Level = 1, Price = 0, Effects = { QueueSize = 3, PatienceBonus = 0 }, Part = "Counter_L1" },
	{ Level = 2, Price = 70, Effects = { QueueSize = 4, PatienceBonus = 10 }, Part = "Counter_L2" },
	{ Level = 3, Price = 160, Effects = { QueueSize = 5, PatienceBonus = 20 }, Part = "Counter_L3" },
}
const counterTrailer: { Level } = {
	{ Level = 1, Price = 0, Effects = { QueueSize = 3, PatienceBonus = 0 }, Part = "Counter_L1" },
	{ Level = 2, Price = 70, Effects = { QueueSize = 4, PatienceBonus = 10 }, Part = "Counter_L2" }, -- Q-163 a
	{ Level = 3, Price = 160, Effects = { QueueSize = 5, PatienceBonus = 20 }, Part = "Counter_L3" }, -- Q-163 a
}

-- UPG-004 Cash Drawer Lock: thief opens in 8 s and steals 50% -> 16 s / 30% for $80 (DEC-046, DEC-050).
const drawerLockCart: { Level } = {
	{ Level = 0, Price = 0, Effects = { DrawerOpenTime = 8, StealPct = 50 }, Part = "" },
	{ Level = 1, Price = 80, Effects = { DrawerOpenTime = 16, StealPct = 30 }, Part = "DrawerLock_L1" },
}
const drawerLockTrailer: { Level } = {
	{ Level = 0, Price = 0, Effects = { DrawerOpenTime = 8, StealPct = 50 }, Part = "" },
	{ Level = 1, Price = 80, Effects = { DrawerOpenTime = 16, StealPct = 30 }, Part = "DrawerLock_L1" }, -- Q-163 a, c
}

-- UPG-005 Trailer Lights, trailer only, $100: day flow x1.1, night LightZone radius 18 studs (DEC-046, DEC-055).
const trailerLightsTrailer: { Level } = {
	{ Level = 0, Price = 0, Effects = { LightRadius = 0, DayFlowBonus = 1 }, Part = "" },
	{ Level = 1, Price = 100, Effects = { LightRadius = 18, DayFlowBonus = 1.1 }, Part = "TrailerLights_L1" },
}

-- UPG-008 Patio Tables (FEAT-037; Provisional): one table per level, bought at the ghost table itself, fixed order
-- TBL-1 (closest to Q1) -> TBL-5; $30 / $45 / $60 / $80 / $100 = $315. Pad scope: same rows on both vehicles.
local function patioTables(): { Level }
	return {
		{ Level = 0, Price = 0, Effects = { TableCount = 0 }, Part = "" },
		{ Level = 1, Price = 30, Effects = { TableCount = 1 }, Part = "" },
		{ Level = 2, Price = 45, Effects = { TableCount = 2 }, Part = "" },
		{ Level = 3, Price = 60, Effects = { TableCount = 3 }, Part = "" },
		{ Level = 4, Price = 80, Effects = { TableCount = 4 }, Part = "" },
		{ Level = 5, Price = 100, Effects = { TableCount = 5 }, Part = "" },
	}
end

-- UPG-011 Trailer Tables (FEAT-037; user request 2026-10-12; Provisional, Q-209): the four tables placed for the
-- trailer, trailer only, bought in place at the ghost table once the trailer is the vehicle: TBL-6 -> TBL-9;
-- $50 / $70 / $90 / $120 = $330 (the trailer comes after Night 2: more cash than the cart days, so dearer than UPG-008).
const trailerTablesTrailer: { Level } = {
	{ Level = 0, Price = 0, Effects = { TrailerTableCount = 0 }, Part = "" },
	{ Level = 1, Price = 50, Effects = { TrailerTableCount = 1 }, Part = "" },
	{ Level = 2, Price = 70, Effects = { TrailerTableCount = 2 }, Part = "" },
	{ Level = 3, Price = 90, Effects = { TrailerTableCount = 3 }, Part = "" },
	{ Level = 4, Price = 120, Effects = { TrailerTableCount = 4 }, Part = "" },
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
		Vehicles = { "cart", "trailer" },
		StartLevel = 1,
		Levels = { cart = grillCart, trailer = grillTrailer },
		UnlockDay = 1,
		SoldAt = "Bench",
		BenchSpot = "B1",
		PlaceSpots = {},
		Scope = "Vehicle",
	},
	{
		Key = "cooler",
		Ref = "UPG-002",
		Name = "Cooler",
		Vehicles = { "cart", "trailer" },
		StartLevel = 1,
		Levels = { cart = coolerCart, trailer = coolerTrailer },
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
		Vehicles = { "cart", "trailer" },
		StartLevel = 1,
		Levels = { cart = counterCart, trailer = counterTrailer },
		UnlockDay = 1,
		SoldAt = "Bench",
		BenchSpot = "B3",
		PlaceSpots = {},
		Scope = "Vehicle",
	},
	{
		Key = "cash_drawer_lock",
		Ref = "UPG-004",
		Name = "Drawer Lock",
		Vehicles = { "cart", "trailer" },
		StartLevel = 0,
		Levels = { cart = drawerLockCart, trailer = drawerLockTrailer },
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
		Vehicles = { "trailer" }, -- bench shows "Trailer only" while on the cart (FEAT-015, DEC-055)
		StartLevel = 0,
		Levels = { trailer = trailerLightsTrailer },
		UnlockDay = 1,
		SoldAt = "Bench",
		BenchSpot = "B5",
		PlaceSpots = {},
		Scope = "Vehicle",
	},
	-- In place (TASK-144; FEAT-037; Q-178 A): not on the Gear Stand
	{
		Key = "patio_tables",
		Ref = "UPG-008",
		Name = "Patio Table",
		Vehicles = { "cart", "trailer" },
		StartLevel = 0,
		Levels = { cart = patioTables(), trailer = patioTables() },
		UnlockDay = 2, -- Day 1 is the tutorial (FEAT-037)
		SoldAt = "InPlace",
		BenchSpot = "",
		PlaceSpots = { "TBL-1", "TBL-2", "TBL-3", "TBL-4", "TBL-5" },
		Scope = "Pad",
	},
	{
		Key = "patio_lights",
		Ref = "UPG-009",
		Name = "Patio Lights",
		Vehicles = { "cart", "trailer" },
		StartLevel = 0,
		Levels = { cart = patioLights(), trailer = patioLights() },
		UnlockDay = 2,
		SoldAt = "InPlace",
		BenchSpot = "",
		PlaceSpots = { "PATIO-LIGHTS" }, -- sign next to TBL-1 (UPG-009)
		Scope = "Pad",
		Requires = { Upgrade = "patio_tables", Level = 2 },
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
		PlaceSpots = { "TBL-BAR" }, -- TBL-6..9 are the Trailer tables (UPG-011)
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
		PlaceSpots = { "TBL-6", "TBL-7", "TBL-8", "TBL-9" },
		Scope = "Vehicle",
	},
} :: { Upgrade })
