--!strict
-- Mart v2 "Gear Stand" (TASK-135; FEAT-015 v2; MAP-01 §18.4, §18.5; Q-175, Q-176, Q-177 Provisional A).
-- The upgrade bench becomes a kiosk with three wooden roll-up shutters (L, C, R) and six pedestals with a floating
-- miniature. Nothing here changes price, effect or rotation (Upgrades, DEC-101, DEC-106): this is presentation and
-- the phases in which the kiosk serves. Single record (like Neon). Owner: game-designer; numbers PROVISIONAL.
--   * KioskClosedPhases: the shutters are always down in these phases and the server refuses bench purchases
--     (MarketService, TASK-139).
--   * Hours (owner request 2026-10-17, Provisional): business hours on top of that. The stand OPENS at the end of each
--     shift (RoundService.ShiftEnded = start of Summary), stays open through the break (Summary, Call, Prep) and for
--     StayOpenIntoShift seconds after the next shift's first selling phase (Open / Night) starts, with a warning toast
--     CloseWarning seconds before it CLOSES. Owner: GearStandService (server); the state rides in two Workspace
--     attributes (Hours.Attributes), read by MarketController for the shutters and the door SFX.
--     OpenAtShiftEnd = false = the old rule (open in every phase not in KioskClosedPhases).
--   * Pedestals: order = left to right as seen by the player; Offer "Upgrade" reads Upgrades.BenchSpot, "Special"
--     is the turn's special slot (FEAT-035). Doors: which pedestals each shutter covers (C covers Opal, Q-175).
--   * Tags/attributes: the contract with the map (TASK-138); see MarketController/Kiosk.luau and Minis.luau.

export type Offer = "Upgrade" | "Special"

export type Pedestal = {
	Slot: string, -- BenchSlot B1..B5 / S1
	Offer: Offer,
}

export type Door = {
	Key: string, -- "L" | "C" | "R": attribute Slot of a GearShutter model
	Pedestals: { string }, -- BenchSlots behind this shutter (fallback geometry and order)
}

export type Hours = {
	OpenAtShiftEnd: boolean, -- false = no hours: open in every phase not in KioskClosedPhases (rollback without code)
	StayOpenIntoShift: number, -- s the stand stays open after the next shift's first selling phase starts
	MinOpen: number, -- s the stand stays open at least from the moment it opened, before any scheduled close
	CloseWarning: number, -- s before closing when the "closing in" toast goes out (0 = no warning)
	Tick: number, -- Hz of the server close timer
	Attributes: {
		Open: string, -- Workspace attribute (boolean): the stand is open
		ClosesAt: string, -- Workspace attribute (number): server time it closes, 0 = no close scheduled
	},
	Sfx: {
		Open: string, -- Content.Sounds key played at the stand when the shutters go up
		Close: string, -- Content.Sounds key played when they go down
	},
	-- Sound under ReplicatedStorage.Assets.SFX played instead while the Sounds row still has no Id (owner upload)
	Assets: {
		Open: string,
		Close: string,
	},
}

export type Mart = {
	KioskClosedPhases: { string }, -- keys of Shift
	-- Owner request 2026-10-14 (Provisional): the Gear Stand is CLOSED at the start of the run. On Day 1 (day shift) it is
	-- also down in these phases: the first Mart visit is only for buns (tutorial shopping lesson); it opens at the end of
	-- the first shift (the day Closing at 6 PM, where the Day 1 upgrade lesson sends the rookie to buy Storage)
	FirstShiftClosedPhases: { string },
	Hours: Hours,
	Pedestals: { Pedestal },
	Doors: { Door }, -- animation order (Stagger) = list order
	Door: {
		CloseTime: number, -- s, shutter going down
		OpenTime: number, -- s, shutter going up
		Stagger: number, -- s between two shutters (L -> C -> R)
	},
	Mini: {
		Size: number, -- studs, largest dimension of the miniature
		Lift: number, -- studs from the pedestal top to the miniature centre
		Bob: number, -- studs, amplitude of the up/down sine
		BobPeriod: number, -- s
		SpinPeriod: number, -- s per turn (45 deg/s = 8 s)
		ActiveRadius: number, -- studs from the camera: farther = miniatures frozen, no per-frame cost
		LockedTransparency: number, -- "Trailer only" miniature
	},
	Purchase: {
		PopTime: number, -- s, fast turn + scale 1 -> PopScale -> 0
		PopScale: number,
		PopTurns: number, -- extra turns during the pop
		Confetti: number, -- AST-092 particles at the pedestal
		RiseDelay: number, -- s after the pop before the next miniature rises
		RiseTime: number, -- s the next miniature takes to rise out of the pedestal
		OpalLineGap: number, -- s between two Opal purchase lines (optional, pool "Purchase")
		OpalLineRadius: number, -- studs from Opal: only players this close get the line
	},
	Cooldown: {
		Turns: number, -- a Bench line bought in shift T is on sale again when shift T + Turns starts (2 = one full shift off)
	},
	Plate: {
		Distance: number, -- studs, BillboardGui MaxDistance of the price plate
		Lift: number, -- studs from the miniature centre up to the plate (it floats above the miniature, never in the glass)
		Width: number, -- px, fixed size like PatienceBar / OrderBubble (BillboardGui, UI scale does not reach it)
		-- TASK-595 (owner Play 2026-10-19: the plates showed through the walls into the shop, stacked on each other):
		-- only ONE plate at a time, the one looked at (or the nearest) within Focus studs of the camera, in the Cone
		-- (cosine of the half angle) and with a clear line of sight; not AlwaysOnTop, so walls hide it too.
		Focus: number, -- studs from the camera
		Cone: number, -- cos of the half angle around the look direction
	},
	Hint: {
		-- "Closing time" hint: toast (server, once per shift) and arrow to the stand while the phase is one of these and
		-- Cash + Drawer >= the cheapest line on sale (or nothing bought yet). Ends with Open or on reaching the stand.
		Phases: { string },
		Reach: number, -- studs from the stand where the arrow is dismissed
	},
	BunHint: {
		LowBuns: number, -- buns in the crate at or under which the Mart hint shows
		Phases: { string }, -- keys of Shift
		Reach: number, -- studs from the Mart door where it is dismissed
	},
	Tags: {
		Pedestal: string, -- Model (or BasePart) of one pedestal, attribute Slot = BenchSlot
		Shutter: string, -- Model of one roll-up shutter, attribute Slot = Doors[].Key
		Slot: string, -- attribute name read on both
	},
	Fallback: {
		DoorHeight: number, -- studs, generated test shutter when the map has no GearShutter
		DoorAhead: number, -- studs in front of the prompt anchors
		AnchorHeight: number, -- prompt anchor height above the floor (MAP-01 §18.4: 4.2)
		Margin: number, -- studs added to each side of a shutter span
	},
}

const mart: Mart = {
	-- Always down: lost night / resume and the non-play phases. Summary and Call left the list with the business hours
	-- (2026-10-17): the turn change is now when the stand is OPEN (Q-176 A had them closed).
	KioskClosedPhases = { "NightLost", "Resume", "Finale", "RunEnd" },
	-- Business hours (owner request 2026-10-17, PROVISIONAL numbers): opens at ShiftEnded, 45 s into the next shift's
	-- selling phase for the last purchases, "closing in 20s" toast, then CLOSED
	Hours = {
		OpenAtShiftEnd = true,
		StayOpenIntoShift = 45,
		-- owner request 2026-10-20 (Provisional, 1.5-3 min): open at least this long, time to save up for better gear
		MinOpen = 120,
		CloseWarning = 20,
		Tick = 4,
		Attributes = { Open = "GearStandOpen", ClosesAt = "GearStandClosesAt" },
		Sfx = { Open = "gear_door_open", Close = "gear_door_close" },
		Assets = { Open = "Metal Door Open", Close = "Metal Door Close" },
	},
	-- 2026-10-17 Day 1 cut (owner decision, Provisional): no upgrade lesson, the stand is open from the start
	FirstShiftClosedPhases = {},
	Pedestals = {
		{ Slot = "B1", Offer = "Upgrade" },
		{ Slot = "B2", Offer = "Upgrade" },
		{ Slot = "B3", Offer = "Upgrade" },
		{ Slot = "B4", Offer = "Upgrade" },
		{ Slot = "B5", Offer = "Upgrade" },
		{ Slot = "S1", Offer = "Special" },
	},
	Doors = {
		{ Key = "L", Pedestals = { "B1", "B2", "B3" } },
		{ Key = "C", Pedestals = {} }, -- Opal's counter (Q-175 A)
		{ Key = "R", Pedestals = { "B4", "B5", "S1" } },
	},
	Door = { CloseTime = 2.0, OpenTime = 1.6, Stagger = 0.25 },
	Mini = {
		Size = 1.6,
		Lift = 1.2,
		Bob = 0.25,
		BobPeriod = 3,
		SpinPeriod = 8,
		ActiveRadius = 60,
		LockedTransparency = 0.5,
	},
	Purchase = {
		PopTime = 0.4,
		PopScale = 1.3,
		PopTurns = 1,
		Confetti = 14,
		RiseDelay = 0.5,
		RiseTime = 0.6,
		OpalLineGap = 20,
		OpalLineRadius = 12,
	},
	-- Q-203 Provisional: one full shift off the stand after a purchase (user feedback 2026-10-11).
	Cooldown = { Turns = 2 },
	Plate = { Distance = 18, Lift = 1.3, Width = 190, Focus = 14, Cone = 0.8 },
	Hint = { Phases = { "Closing", "Summary", "Prep" }, Reach = 9 },
	-- Low-bun hint (2026-10-17, Provisional): any selling phase with LowBuns buns or fewer in the crate, an arrow to the
	-- Mart door and one toast per low spell; over on reaching the door (Reach) or once the stock is back above it
	BunHint = { LowBuns = 2, Phases = { "Open", "Closing", "Night" }, Reach = 10 },
	Tags = { Pedestal = "GearPedestal", Shutter = "GearShutter", Slot = "Slot" },
	Fallback = { DoorHeight = 7, DoorAhead = 1, AnchorHeight = 4.2, Margin = 1.5 },
}

const firstShift: { [string]: boolean } = {}
for _, phase in mart.FirstShiftClosedPhases do
	firstShift[phase] = true
end

-- Same answer on the server (MarketService, UpgradeService) and the client (MarketController shutters): the Gear Stand
-- is still closed because the first shift of the run has not ended (Day 1 day shift, phase in FirstShiftClosedPhases)
local function firstShiftClosed(info: { Day: number, IsNight: boolean }, phase: string): boolean
	return info.Day <= 1 and not info.IsNight and firstShift[phase] == true
end

table.freeze(mart)
return table.freeze({
	KioskClosedPhases = mart.KioskClosedPhases,
	FirstShiftClosedPhases = mart.FirstShiftClosedPhases,
	Hours = mart.Hours,
	Pedestals = mart.Pedestals,
	Doors = mart.Doors,
	Door = mart.Door,
	Mini = mart.Mini,
	Purchase = mart.Purchase,
	Cooldown = mart.Cooldown,
	Plate = mart.Plate,
	Hint = mart.Hint,
	BunHint = mart.BunHint,
	Tags = mart.Tags,
	Fallback = mart.Fallback,
	FirstShiftClosed = firstShiftClosed,
})
