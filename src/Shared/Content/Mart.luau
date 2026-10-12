--!strict
-- Mart v2 "Gear Stand" (TASK-135; FEAT-015 v2; MAP-01 §18.4, §18.5; Q-175, Q-176, Q-177 Provisional A).
-- The upgrade bench becomes a kiosk with three wooden roll-up shutters (L, C, R) and six pedestals with a floating
-- miniature. Nothing here changes price, effect or rotation (Upgrades, DEC-101, DEC-106): this is presentation and
-- the phases in which the kiosk serves. Single record (like Neon). Owner: game-designer; numbers PROVISIONAL.
--   * KioskClosedPhases: the shutters are down and the server refuses bench purchases (MarketService, TASK-139).
--     Every other Shift phase is open, day and night (DEC-049). The client derives the door from the Shift phase:
--     no network of its own.
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

export type Mart = {
	KioskClosedPhases: { string }, -- keys of Shift
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
	},
	Hint: {
		-- "Closing time" hint: toast (server, once per shift) and arrow to the stand while the phase is one of these and
		-- Cash + Drawer >= the cheapest line on sale (or nothing bought yet). Ends with Open or on reaching the stand.
		Phases: { string },
		Reach: number, -- studs from the stand where the arrow is dismissed
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
	-- Q-176 A: closed only across the turn change (Summary, boss Call), lost night / resume and the non-play phases.
	KioskClosedPhases = { "Summary", "Call", "NightLost", "Resume", "Intro", "Finale", "RunEnd" },
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
	Plate = { Distance = 45, Lift = 1.3, Width = 190 },
	Hint = { Phases = { "Closing", "Summary", "Prep" }, Reach = 9 },
	Tags = { Pedestal = "GearPedestal", Shutter = "GearShutter", Slot = "Slot" },
	Fallback = { DoorHeight = 7, DoorAhead = 1, AnchorHeight = 4.2, Margin = 1.5 },
}

return table.freeze(mart)
