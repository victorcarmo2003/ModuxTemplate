--!strict
-- Upgrades with levels per vehicle (content-data.md §3.7; DEC-046, DEC-101, DEC-106, DEC-184).
-- Upgrades record id = IndexOf[key]. Levels[vehicle] lists every level from StartLevel to max, in order; the
-- first row is what the vehicle comes with (Price 0). Effects = absolute value of each Stat at that level.
-- STUB (TASK-003): numbers from upgrades.md; trailer prices = cart prices (Provisional, Q-163 a, c).
-- Part names Provisional (binding TASK-002 / art-director). Reviewed in TASK-008.
local Stats = require(script.Parent.Stats)
local Table = require(script.Parent.Table)

export type Level = {
	Level: number,
	Price: number,
	Effects: { [Stats.Stat]: number },
	Part: string, -- UpgradePiece shown at this level; "" = none
}

export type Upgrade = {
	Key: string,
	Ref: string,
	Name: string,
	Vehicles: { string }, -- keys of Vehicles where the upgrade exists
	StartLevel: number,
	Levels: { [string]: { Level } }, -- per vehicle key
	UnlockDay: number,
	SoldAt: "Bench",
	BenchSpot: string, -- B1..B5
}

const grill: { Level } = {
	{ Level = 1, Price = 0, Effects = { GrillSlots = 2, GrillTime = 12 }, Part = "Grill_L1" },
	{ Level = 2, Price = 60, Effects = { GrillSlots = 3, GrillTime = 10 }, Part = "Grill_L2" },
	{ Level = 3, Price = 150, Effects = { GrillSlots = 4, GrillTime = 8 }, Part = "Grill_L3" },
}

const cooler: { Level } = {
	{ Level = 1, Price = 0, Effects = { StockCapacityLevel = 1 }, Part = "Cooler_L1" },
	{ Level = 2, Price = 50, Effects = { StockCapacityLevel = 2 }, Part = "Cooler_L2" },
	{ Level = 3, Price = 120, Effects = { StockCapacityLevel = 3 }, Part = "Cooler_L3" },
}

const counter: { Level } = {
	{ Level = 1, Price = 0, Effects = { QueueSize = 3, PatienceBonus = 0 }, Part = "Counter_L1" },
	{ Level = 2, Price = 70, Effects = { QueueSize = 4, PatienceBonus = 10 }, Part = "Counter_L2" },
	{ Level = 3, Price = 160, Effects = { QueueSize = 5, PatienceBonus = 20 }, Part = "Counter_L3" },
}

const drawerLock: { Level } = {
	{ Level = 0, Price = 0, Effects = { DrawerOpenTime = 8, StealPct = 50 }, Part = "" },
	{ Level = 1, Price = 80, Effects = { DrawerOpenTime = 16, StealPct = 30 }, Part = "DrawerLock_L1" },
}

const trailerLights: { Level } = {
	{ Level = 0, Price = 0, Effects = { LightRadius = 0, DayFlowBonus = 1 }, Part = "" },
	{ Level = 1, Price = 100, Effects = { LightRadius = 18, DayFlowBonus = 1.1 }, Part = "TrailerLights_L1" },
}

return Table.new({
	{
		Key = "grill",
		Ref = "UPG-001",
		Name = "Grill",
		Vehicles = { "cart", "trailer" },
		StartLevel = 1,
		Levels = { cart = grill, trailer = grill },
		UnlockDay = 1,
		SoldAt = "Bench",
		BenchSpot = "B1",
	},
	{
		Key = "cooler",
		Ref = "UPG-002",
		Name = "Cooler",
		Vehicles = { "cart", "trailer" },
		StartLevel = 1,
		Levels = { cart = cooler, trailer = cooler },
		UnlockDay = 1,
		SoldAt = "Bench",
		BenchSpot = "B2",
	},
	{
		Key = "counter",
		Ref = "UPG-003",
		Name = "Counter",
		Vehicles = { "cart", "trailer" },
		StartLevel = 1,
		Levels = { cart = counter, trailer = counter },
		UnlockDay = 1,
		SoldAt = "Bench",
		BenchSpot = "B3",
	},
	{
		Key = "cash_drawer_lock",
		Ref = "UPG-004",
		Name = "Drawer Lock",
		Vehicles = { "cart", "trailer" },
		StartLevel = 0,
		Levels = { cart = drawerLock, trailer = drawerLock }, -- bought again on the trailer: Provisional (Q-163 c)
		UnlockDay = 1,
		SoldAt = "Bench",
		BenchSpot = "B4",
	},
	{
		Key = "trailer_lights",
		Ref = "UPG-005",
		Name = "Trailer Lights",
		Vehicles = { "trailer" }, -- bench shows "Trailer only" while on the cart
		StartLevel = 0,
		Levels = { trailer = trailerLights },
		UnlockDay = 1,
		SoldAt = "Bench",
		BenchSpot = "B5",
	},
} :: { Upgrade })
