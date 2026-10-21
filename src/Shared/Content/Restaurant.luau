--!strict
-- Restaurant flow, single record (tech/restaurant-flow.md rev. 2 §4.1; design/restaurant-flow.md FEAT-043..FEAT-050;
-- DEC-269..DEC-280). Owner: game-designer (numbers) + architect (binding names). Every number Provisional.
-- The restaurant is the only flow (DEC-307, 2026-10-18): the trailer mode and its rollback switch are gone. The
-- tables that used to follow the switch (Prep, Seating, Vehicles, Supply) hold the restaurant values themselves.
-- "ByParty" lists have 4 entries: party of 1..4 active players at the start of the shift (Q-067).
local Table = require(script.Parent.Table)

export type ByParty = { number }

export type Rules = {
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
	-- DEC-311: an unflipped sausage stops at this fraction of the cook time until it is flipped (the flip mini-game of the
	-- cooking focus); flipped, it resumes from there. Provisional
	HoldAt: number,
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
	-- DT-PC tablet + DT-WIN "Hand Out" anchors (TASK-574). Owner 2026-10-20 (Provisional): false = the order is taken and
	-- the food served on the prompt of the car at the window
	WindowAnchors: boolean,
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
	CookBoard: string, -- Model name of the cutting board of the cooking focus (kitchen-focus.md §1; attribute CookStation wins)
	PickupTag: string, -- Model PICKUP
	PickupPrompt: string,
	PickupPoint: string, -- MapPoint + NpcNode format, n = 1..PickupSlotsMax
	SecondTabletPoint: string, -- MapPoint of the 2nd tablet head (optional)
	DriveStop: string,
	DriveIn: string,
	DriveOut: string,
	DriveWindow: string, -- anchor of drive_serve
}

-- Pickup arc (owner 2026-10-20, Provisional): the customers whose order was taken wait in an arc outside, around the pickup
-- and a bit to one side, instead of the PU-2..n line. "Hand Over" puts the plate on the PICKUP counter (the sale is decided
-- then, as before); the customer of that plate walks from the arc to the counter, takes it and goes (table / takeaway).
export type PickupArc = {
	Enabled: boolean, -- false = the PU-k line as before
	Radius: number, -- studs from PU-1 to the arc
	Spread: number, -- degrees each side of the outward direction
	Shift: number, -- studs along the counter (+ = towards +X of the map) the arc centre moves from PU-1
	Slots: number, -- plates the counter shows at once (Gap apart)
	Gap: number, -- studs between two plates on the counter
	CollectTimeout: number, -- s the walk arc -> counter may take before the plate goes into its hands anyway
}

export type Restaurant = {
	Rules: Rules,
	PickupArc: PickupArc,
	-- MapIds of the AutoDoor Models opened by hand (prompt) instead of by proximity (owner 2026-10-18; RestaurantDoorService)
	ManualDoors: { string },
	-- world boxes that also count as "inside" besides the kitchen zone LZ-1 (owner 2026-10-18: the stock room / pantry;
	-- Anomaly/OutsideService). Min / Max corners, measured in Studio on 2026-10-18
	SafeBoxes: { { Min: Vector3, Max: Vector3 } },
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
	-- owner 2026-10-20 (Provisional): numbers judged in Play; Shift away from the tablet queue (it runs towards +X)
	PickupArc = {
		Enabled = true,
		Radius = 5,
		Spread = 70,
		Shift = -3,
		Slots = 3,
		Gap = 1.2,
		CollectTimeout = 8,
	},
	ManualDoors = { "DOOR-B" },
	SafeBoxes = {
		{ Min = Vector3.new(-48.3, -1, -11.2), Max = Vector3.new(-25.5, 12, -3.4) }, -- pantry / stock room
	},
	Rules = {
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
	Grill = { BurnAfter = 10, FlipFrom = 0.4, FlipTo = 0.6, HoldAt = 0.5, PickupPerfect = 3, PickupGood = 7 },
	Bun = { CutHold = 0.6 },
	Tables = { Count = 4, GroupsPerTable = 2, EatTime = 12, EatJitter = 2, TableTip = 1, TrayFade = 3, SitHeadroom = 2 },
	Flow = {
		PartyMult = { 1.0, 1.8, 2.5, 3.1 },
		-- owner 2026-10-18: there was no break between customers; slower nights plus a quiet stretch (Provisional)
		-- owner 2026-10-21: nights felt empty (~5 real customers on Night 1); faster again, shorter and rarer lull
		-- (Provisional, economy.md §5)
		-- owner 2026-10-21 (gameplay review, Provisional): 30..22 s kept the solo kitchen at ~90-110% with no room for the
		-- anomalies and chores; 34..26 s leaves it at ~75-85% (design/gameplay-flow-review.md)
		NightInterval = { 34, 33, 32, 31, 30, 29, 28, 27, 26, 26 },
		LullEvery = 4,
		LullSeconds = 20,
		Day1Interval = 22,
		MaxCustomers = { 5, 7, 9, 9 },
	},
	Drive = {
		Enabled = true, -- TASK-574 (2026-10-20): DriveThruService; false = no car ever
		WindowAnchors = false, -- owner 2026-10-20: no drive-thru tablet, the prompt is on the car
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
		Enabled = true, -- the stock room is the only stock source (FEAT-050, DEC-307)
		LowAt = 0.25,
		MartShelves = false, -- the Mart left the map (DEC-307)
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
		CookBoard = "TLR-CUTTING_BOARD",
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

export type Module = Restaurant & { PickupPoints: (count: number?) -> { string } }

const out: Module = table.clone(restaurant) :: any
out.PickupPoints = pickupPoints
return Table.record(out)
