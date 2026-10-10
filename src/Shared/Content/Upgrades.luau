--!strict
-- Upgrades with levels per vehicle (content-data.md §3.7; upgrades.md; FEAT-015; DEC-046, DEC-101, DEC-106, DEC-184).
-- Upgrades record id = IndexOf[key]. Levels[vehicle] lists every level from StartLevel to max, in order; the
-- first row is what the vehicle comes with (Price 0). Effects = absolute value of each Stat at that level.
-- DEC-184: levels are per vehicle and the trailer starts over at StartLevel. Cart and trailer rows are written out
-- separately so a trailer price is a number change only.
-- Provisional: trailer prices = cart prices and Drawer Lock bought again on the trailer (Q-163 a, c).
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
	},
} :: { Upgrade })
