--!strict
-- Restaurant flow, single record (tech/restaurant-flow.md rev. 2 §4.1; design/restaurant-flow.md FEAT-043..FEAT-050;
-- DEC-269..DEC-280). Owner: game-designer (numbers) + architect (binding names). Every number Provisional.
-- Rules.Enabled = false keeps the trailer flow (no pickup line, no plate gate, tablets ignored, the new map points not
-- required by MapIndex/Required). Rollback = Enabled false (+ the trailer back from ServerStorage.TRAILER_Backup_20261017).
--
-- THE SINGLE SWITCH (TASK-390, tech/restaurant-flow.md §6): Rules.Enabled is the only thing to flip to turn the
-- restaurant on. Every table that changes with it reads Switch below (derived here, never edited by hand there):
--   Prep.Rules.Enabled = false, Prep.Rules.WorldKitchenPrompts = true   (DT-R8: no focused prep, world kitchen prompts)
--   Seating.SitAt = "Served", Seating.DirtyTables = false                (DT-R11: sits after the sale, no tray)
--   Vehicles.trailer.HasBackDoor = false, Vehicles.trailer.Restaurant = true (DT-R1, DEC-280: no back door)
--   Anomalies: the CutAnomalies rows lose Family and Scripted (out of the agenda, design/anomalies-v3-restaurant.md §8)
--   Nights: NewAnomaly per night and debut night per row from NewAnomalies / DebutNights (the cut ones were premieres)
--   Supply.MartShelves = false (owner 2026-10-17: the Mart left the map, stock comes from the stock room bays; MapIndex
--     then requires no BUY-* shelf anchor, no OP-1 / MKT-DOOR point). Written below from Switch.MartShelves.
-- Off (default) = every field keeps the published trailer value.
-- "ByParty" lists have 4 entries: party of 1..4 active players at the start of the shift (Q-067).
local Table = require(script.Parent.Table)

export type ByParty = { number }

export type Rules = {
	Enabled: boolean, -- false = trailer flow (DEC-280 restaurant off); the published game stays the same
	PlateSlots: number, -- physical PLATE-n on the assembly table (the map may bind fewer)
	PlateSlotsMax: number, -- with UPG-024 Long Pass (+2 / +4)
	ActivePlates: ByParty, -- plate slots active per party (FEAT-044); full = tablet "Kitchen full"
	PickupSlots: ByParty, -- pickup spots PU-1..n active per party (FEAT-046; follows ActivePlates)
	PickupSlotsMax: number, -- PU-n authored at most (UPG-024 ceiling); Customers.Pickup wire is 1..12
	TabletsMax: number, -- TAB-1 always, TAB-2 with UPG-027 (records 1..TabletsMax; 5 = DT-PC)
	DrivePcIndex: number, -- Tablets record of the drive-thru computer (wave R3)
	QueuePerTablet: number, -- Q1..Qn per tablet (FEAT-043)
	TakeawayWhenNoTable: boolean, -- served with no free table (or no headroom) = leaves carrying the plate
	PreppedFirst: boolean, -- a new ticket prefers a plate that already has bun + sausage (solo pre-prep)
	TakeRadius: number, -- = Actions.tablet_take.Radius
	TalkRadius: number, -- studs: walking further cancels the talk (FEAT-043)
	ServeRadius: number, -- = Actions.pickup_serve.Radius
	OrderNumberMax: number, -- #n over the customer's head, 1..n per shift, wraps
	OrphanReuse: boolean, -- a plate whose customer left serves an identical new order (FEAT-044)
	FillAllHold: number, -- s: hold on a plate slot = one item per plate that needs it (FEAT-044)
	UrgentAt: number, -- patience fraction: the ticket gets "!" (FEAT-044)
	SlotLock: number, -- s: a slot just filled is locked for the others (co-op, DEC-259)
}

-- Dialogue at the tablet (FEAT-043): TalkTime = Open + Lead + PerItem x (2 + K) + Confirm (+ PairExtra + items of the 2nd).
-- The client reveals item i at StartedAt + Open + Lead + PerItem x i (bun, sausage, then ToppingKeys order).
export type Talk = {
	Open: number,
	Lead: number,
	PerItem: number,
	Confirm: number,
	PairExtra: number,
	HurryMult: number, -- pressing interact again speeds the rest up
	VeteranAfter: number, -- orders taken by this player in the run before the veteran speed
	VeteranMult: number,
	MinTotal: number, -- floor with every speed-up (UPG-034)
}

export type Patience = {
	Queue: number, -- s at the tablet queue
	DtQueue: number, -- s at the drive-thru window
	PrepBase: number, -- s from the #n stamp: PrepBase + PrepPerK x K (+ PairBonus)
	DtPrepBase: number,
	PrepPerK: number,
	PairBonus: number,
	TipBase: number, -- tip window: TipBase + TipPerK x K
	TipPerK: number,
	IncompleteRefund: number, -- fraction of the price refunded (floor)
	GiveUpRefund: number,
}

export type Stacks = {
	Bun: number, -- bun_sliced Count cap (UPG-019 raises it)
	Sausage: number, -- sausage_grilled Count cap (UPG-018 raises it)
	Plates: number, -- hot_dog plates per player
	Boxes: number, -- stock_box per player
}

export type Grill = {
	BurnAfter: number, -- s after Ready (UPG-016 raises it)
	FlipFrom: number, -- fraction of the cook time: the flip window opens
	FlipTo: number,
	PickupPerfect: number, -- s after Ready: collected within = Perfect
	PickupGood: number,
}

export type Bun = {
	CutHold: number, -- s per bun, world prompt (wave 0) = Actions.bun_slice.Hold
}

export type Tables = {
	Count: number,
	GroupsPerTable: number, -- one group per bench, strangers never share one (Q-324)
	EatTime: number,
	EatJitter: number,
	TableTip: number, -- $ per diner, straight to the tip jar (no dirty table)
	TrayFade: number, -- s
	SitHeadroom: number,
}

export type Flow = {
	PartyMult: ByParty,
	NightInterval: { number }, -- s per night 1..10 (used by CustomerService at night with the restaurant on)
	LullEvery: number, -- customers between two quiet stretches at night (0 = none)
	LullSeconds: number, -- s added to the interval after every LullEvery customers (owner 2026-10-18: "no break")
	Day1Interval: number,
	MaxCustomers: ByParty,
}

export type Drive = {
	Enabled: boolean, -- wave R3; false = no car ever
	UnlockNight: number,
	Lanes: number, -- DriveCars records 1..Lanes (1 = at the window)
	ShareByParty: ByParty, -- fraction of the spawn attempts that become a car
	QueueByParty: ByParty, -- cars waiting behind the window
	OrderPatience: number,
	PrepBase: number,
	PrepPerK: number,
	ArriveTime: number, -- s DT-IN -> DT-STOP
	LeaveTime: number, -- s DT-STOP -> DT-OUT
	HornAt: { number }, -- patience fractions, decreasing
	StressAt: number,
	PetChance: number,
	PetAfter: number,
	PetBonus: number,
	PetIgnore: number,
	PetMax: number,
}

-- FEAT-050: infinite stock room (owner 2026-10-17, Provisional): every StockShelf bay always gives a box of its package
-- (take_box, no counter, no phone order, no cost) -> Restock at the station. Boxes reuse Content.Packages (same content);
-- the limit is the station Capacity
export type Supply = {
	Enabled: boolean, -- false = Mart shelves stay the stock source
	LowAt: number, -- stock fraction: box icon + stock_low toast
	MartShelves: boolean, -- true = the Mart still sells packages
}

export type Dialog = {
	Greeting: { string }, -- player line
	Opening: { string }, -- customer line before the items
	Ask: { [string]: { string } }, -- Ingredients key -> lines (bun, sausage, every ToppingKeys)
	Close: { string },
	Blank: { string }, -- ANM-001 (no face): nothing to read
	KitchenFull: string, -- tablet lamp text
}

export type Binding = {
	TabletTag: string, -- Model TAB-n
	TabletIndex: string, -- number attribute 1..TabletsMax, DrivePcIndex
	TabletPrompt: string, -- child anchor (PromptAction tablet_take)
	TabletScreen: string, -- optional Attachment for the balloon
	PlateTag: string, -- Part PLATE-n
	PlateIndex: string,
	PlatePut: string,
	PlateTake: string,
	PlateTicket: string, -- BillboardGui anchor
	PickupTag: string, -- Model PICKUP
	PickupPrompt: string,
	PickupPoint: string, -- MapPoint + NpcNode format, n = 1..PickupSlotsMax
	SecondTabletPoint: string, -- MapPoint of the 2nd tablet head (optional)
	DriveStop: string,
	DriveIn: string,
	DriveOut: string,
	DriveWindow: string, -- anchor of drive_serve
}

export type Restaurant = {
	Rules: Rules,
	-- MapIds of the AutoDoor Models opened by hand (prompt) instead of by proximity (owner 2026-10-18; RestaurantDoorService)
	ManualDoors: { string },
	Talk: Talk,
	Patience: Patience,
	Stacks: Stacks,
	Grill: Grill,
	Bun: Bun,
	Tables: Tables,
	Flow: Flow,
	Drive: Drive,
	Supply: Supply,
	Dialog: Dialog,
	Binding: Binding,
}

const restaurant: Restaurant = {
	ManualDoors = { "DOOR-B" },
	Rules = {
		Enabled = false,
		PlateSlots = 8,
		PlateSlotsMax = 12,
		ActivePlates = { 4, 6, 8, 8 },
		PickupSlots = { 4, 6, 8, 8 },
		PickupSlotsMax = 12,
		TabletsMax = 2,
		DrivePcIndex = 5,
		QueuePerTablet = 4,
		TakeawayWhenNoTable = true,
		PreppedFirst = true,
		TakeRadius = 6,
		TalkRadius = 10,
		ServeRadius = 7,
		OrderNumberMax = 99,
		OrphanReuse = true,
		FillAllHold = 0.5,
		UrgentAt = 0.25,
		SlotLock = 0.6,
	},
	Talk = {
		Open = 1.2,
		Lead = 0.8,
		PerItem = 0.45,
		Confirm = 0.6,
		PairExtra = 1.0,
		HurryMult = 2,
		VeteranAfter = 8,
		VeteranMult = 1.6,
		MinTotal = 1.5,
	},
	Patience = {
		Queue = 45,
		DtQueue = 40,
		PrepBase = 75,
		DtPrepBase = 70,
		PrepPerK = 5,
		PairBonus = 10,
		TipBase = 24,
		TipPerK = 4,
		IncompleteRefund = 0.5,
		GiveUpRefund = 1,
	},
	Stacks = { Bun = 3, Sausage = 3, Plates = 2, Boxes = 2 },
	Grill = { BurnAfter = 10, FlipFrom = 0.4, FlipTo = 0.6, PickupPerfect = 3, PickupGood = 7 },
	Bun = { CutHold = 0.6 },
	Tables = { Count = 4, GroupsPerTable = 2, EatTime = 12, EatJitter = 2, TableTip = 1, TrayFade = 3, SitHeadroom = 2 },
	Flow = {
		PartyMult = { 1.0, 1.8, 2.5, 3.1 },
		-- owner 2026-10-18: there was no break between customers; slower nights plus a quiet stretch (Provisional)
		NightInterval = { 55, 52, 50, 48, 46, 45, 44, 43, 42, 40 },
		LullEvery = 3,
		LullSeconds = 45,
		Day1Interval = 22,
		MaxCustomers = { 5, 7, 9, 9 },
	},
	Drive = {
		Enabled = false,
		UnlockNight = 2,
		Lanes = 3, -- 1 at the window + up to 2 waiting (QueueByParty)
		ShareByParty = { 0.15, 0.20, 0.20, 0.25 },
		QueueByParty = { 0, 1, 1, 2 },
		OrderPatience = 40,
		PrepBase = 70,
		PrepPerK = 5,
		ArriveTime = 4,
		LeaveTime = 3,
		HornAt = { 0.5, 0.25 },
		StressAt = 0.25,
		PetChance = 0.2,
		PetAfter = 15,
		PetBonus = 10,
		PetIgnore = 12,
		PetMax = 1,
	},
	Supply = {
		Enabled = false,
		LowAt = 0.25,
		MartShelves = true, -- derived: overwritten from Switch.MartShelves below (never edit by hand)
	},
	-- placeholder lines (narrative-writer owns them; English UI, no "sausage" for TTS: "dog" / "frank")
	Dialog = {
		Greeting = { "Hi! What can I get you?" },
		Opening = { "Hmm, I'd like...", "Okay, so..." },
		Ask = {
			bun = { "a bun..." },
			sausage = { "...with a dog" },
			ketchup = { "ketchup" },
			mustard = { "mustard" },
			cheese = { "cheese" },
			bacon = { "bacon" },
			potato_sticks = { "potato sticks" },
			cream_cheese = { "cream cheese" },
		},
		Close = { "That's it!" },
		Blank = { "..." },
		KitchenFull = "Kitchen full",
	},
	Binding = {
		TabletTag = "Tablet",
		TabletIndex = "TabletIndex",
		TabletPrompt = "Prompt_Take",
		TabletScreen = "Att_Screen",
		PlateTag = "PlateSlot",
		PlateIndex = "PlateIndex",
		PlatePut = "Prompt_Put",
		PlateTake = "Prompt_Take",
		PlateTicket = "Att_Ticket",
		PickupTag = "Pickup",
		PickupPrompt = "Prompt_Serve",
		PickupPoint = "PU-%d",
		SecondTabletPoint = "Q1B",
		DriveStop = "DT-STOP",
		DriveIn = "DT-IN",
		DriveOut = "DT-OUT",
		DriveWindow = "DT-WIN",
	},
}

-- PU-1..PU-n MapPoint ids (n = Rules.PickupSlotsMax by default)
local function pickupPoints(count: number?): { string }
	const out: { string } = {}
	for index = 1, count or restaurant.Rules.PickupSlotsMax do
		table.insert(out, string.format(restaurant.Binding.PickupPoint, index))
	end
	return out
end

-- What Rules.Enabled flips in the other Content tables (see the header). Pure data, read at require time.
export type Switch = {
	On: boolean, -- = Rules.Enabled
	PrepEnabled: boolean, -- Prep.Rules.Enabled
	WorldKitchenPrompts: boolean, -- Prep.Rules.WorldKitchenPrompts (the restaurant kitchen is world prompts)
	SitAt: "Order" | "Served", -- Seating.SitAt
	DirtyTables: boolean, -- Seating.DirtyTables
	HasBackDoor: boolean, -- Vehicles.trailer.HasBackDoor
	VehicleIsRestaurant: boolean, -- Vehicles.trailer.Restaurant
	MartShelves: boolean, -- Supply.MartShelves (the Mart and its BUY-* shelves left the map with the restaurant)
	-- Anomalies keys out of the agenda (Family nil, Scripted nil); the row, module and Journal page stay (dev can force them)
	CutAnomalies: { string },
	NewAnomalies: { [number]: string }, -- night index -> Nights[k].NewAnomaly override
	DebutNights: { [string]: number }, -- Anomalies key -> Night override (a night whose premiere was cut needs a debut)
}

const on = restaurant.Rules.Enabled

-- design/anomalies-v3-restaurant.md §8.1 (DEC-279, Provisional until wave R4 adapts them) + Q-331 ("hide" leaves):
--   ANM-002 food (work channel) · ANM-003 bank clock + trailer switch · ANM-004 back door knock · ANM-007, 017, 018
--   family B (hide in the HideZone behind the trailer, no back door; ANM-019 left the cut with TASK-484: it is "don't look up") · ANM-009 back door knock / crack
-- TASK-483 (DEC-294): ANM-004 is back (no back door here, so the copy only costs sanity; stare pressure, its scene) and
-- ANM-017 is back as "get off the floor" (Kit/Hide Test "Floor", its scene); ANM-009 is back (owner 2026-10-18: Walt
-- knocking on the back door, now opened by hand, RestaurantDoorService)
const CUT_ANOMALIES = {
	"anm_002_wrong_food",
	"anm_003_stopped_clock",
	"anm_007_walker",
	"anm_018_grin",
}

const switch: Switch = {
	On = on,
	PrepEnabled = not on,
	WorldKitchenPrompts = on,
	SitAt = if on then "Served" else "Order",
	DirtyTables = not on,
	HasBackDoor = not on,
	VehicleIsRestaurant = on,
	MartShelves = not on,
	CutAnomalies = if on then CUT_ANOMALIES else {},
	-- premieres of nights 6..8 were family B: the family A row debuting that night takes the call (Provisional; the
	-- boss call texts of those nights still name the old monster until the narrative pass of wave R4)
	NewAnomalies = if on
		then {
			[6] = "anm_014_big_head",
			-- [7] crawler presents Night 7 again (TASK-483), the floater debuts beside it as in the trailer
			[8] = "anm_008_long_car",
		}
		else {},
	-- TASK-484: ANM-019 is back in the restaurant ("don't look up", no HideZone) and presents Night 9 again; the starer
	-- keeps its own debut (Night 8, silently, like before the cut)
	DebutNights = {},
}

restaurant.Supply.MartShelves = switch.MartShelves

export type Module = Restaurant & { PickupPoints: (count: number?) -> { string }, Switch: Switch }

const out: Module = table.clone(restaurant) :: any
out.PickupPoints = pickupPoints
out.Switch = switch
return Table.record(out)
