--!strict
-- Restaurant namespace of the Lync definitions (DEC-269..DEC-280; tech/restaurant-flow.md rev. 2 §2.6; wave R0: schema
-- only, no writer until R1 / R3, Content.Restaurant.Rules.Enabled). A second namespace on purpose: five more sets inside
-- "game" made its define "too complex to typecheck" (LuauSolverV2 budget), and merging both into one table typed as an
-- intersection broke every call on Net. Net/init.luau requires this module, so both machines define it before start.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)
local Content = require(ReplicatedStorage.shared.Content)

-- Restaurant set records (wave R0; schema and comments next to the sets in the define below). Built outside the
-- define table: one more inline struct there made the define "too complex to typecheck" (LuauSolverV2 budget)
local function restaurantPlates()
	return Lync.struct({
		Npc = Lync.int(0, 65535),
		Line = Lync.int(0, 2),
		Bun = Lync.bool(),
		Sausage = Lync.bool(),
		Toppings = Lync.bitfield(Content.Ingredients.ToppingKeys), -- a plate put back after the condiments
		Since = Lync.f64(),
		Orphan = Lync.optional(Lync.bool()),
		Altered = Lync.optional(Lync.bool()), -- ANM-002 on a plate (wave R4); nil = false
	})
end

local function restaurantTablets()
	return Lync.struct({
		State = Lync.enum({ "Idle", "Talking", "Full" }),
		Npc = Lync.int(0, 65535), -- customer at this tablet, 0 = none
		User = Lync.f64(), -- UserId taking the order, 0 = nobody
		StartedAt = Lync.f64(),
		EndsAt = Lync.f64(),
		Order = Lync.bitfield(Content.Ingredients.ToppingKeys),
		Order2 = Lync.optional(Lync.bitfield(Content.Ingredients.ToppingKeys)), -- pair (FEAT-038)
	})
end

local function restaurantDriveCars()
	return Lync.struct({
		State = Lync.enum({ "Arriving", "Waiting", "Leaving" }),
		Npc = Lync.int(0, 65535), -- the drive customer (Customers record)
		Look = Lync.int(1, 32), -- Content.Traffic.LookIndex
		At = Lync.f64(), -- server time of the State change
		Pet = Lync.optional(Lync.bool()), -- a pet rides along (R4)
	})
end

local function restaurantSupply()
	return Lync.struct({
		State = Lync.enum({ "Idle", "OnTheWay" }),
		EndsAt = Lync.f64(),
		Boxes = Lync.int(0, 255),
	})
end

local function restaurantHatch()
	return Lync.struct({
		Package = Lync.enum(Content.Packages.Keys),
		Amount = Lync.int(0, 999),
	})
end

return Lync.define("restaurant", {
	-- Restaurant (DEC-269..DEC-280; tech/restaurant-flow.md rev. 2 §2.5-§2.6, design FEAT-044/047/050). Wave R0: schema only,
	-- no writer until R1 / R3 (Content.Restaurant.Rules.Enabled). No keyBy. Every record is wide (16-bit Npc or f64), so the
	-- README drop.section floor does not apply.
	-- §2.2, record = plate slot 1..Content.Restaurant.Rules.PlateSlotsMax (only the slots the map binds). Writer: PlateService.
	-- Npc = NpcId of the ticket on this plate, 0 = none; Line = which hot dog of a pair (1 leader, 2 partner), 0 = none;
	-- Since = server time the ticket landed (oldest first), 0 = none; Orphan = its customer left (grey "?", FEAT-044)
	Plates = Lync.replicate(restaurantPlates()),

	-- §2.4, record 1 = TAB-1 (always), 2 = TAB-2 (UPG-027 bought and bound), Content.Restaurant.Rules.DrivePcIndex = DT-PC
	-- (wave R3). Writer: TabletService. Full = no free plate or pickup spot ("Kitchen full" lamp for everyone). The client
	-- reveals item i of Order at StartedAt + Talk.Open + Talk.Lead + Talk.PerItem * i (bun, sausage, then ToppingKeys order);
	-- EndsAt is the server's end of the talk (hurry / veteran speed already applied)
	Tablets = Lync.replicate(restaurantTablets()),

	-- §3.4 (wave R3), record = drive lane spot 1..Content.Restaurant.Drive.Lanes (1 = at the window, 2..3 = waiting behind).
	-- Writer: DriveThruService. The client moves the car DT-IN -> DT-STOP -> DT-OUT from State + At
	DriveCars = Lync.replicate(restaurantDriveCars()),

	-- FEAT-050 supply (design/restaurant-flow.md), record 1 = the phone order. Writer: SupplyService (later wave).
	-- OnTheWay until EndsAt (server time), then the boxes land on the hatch; Boxes = boxes in this call
	Supply = Lync.replicate(restaurantSupply()),

	-- FEAT-050, record = hatch shelf spot 1..Content.Restaurant.Supply.HatchSpots (box waiting to be taken). Writer:
	-- SupplyService. Package = Content.Packages key of the box, Amount = units inside; no record = empty spot
	Hatch = Lync.replicate(restaurantHatch()),
})
