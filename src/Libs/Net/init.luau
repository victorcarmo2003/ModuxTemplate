--!strict
-- Net v1 (wave 1). Contract: docs/tech/network.md v4 (schema, writer, reader and rate of every entry).
-- Rules: set = state the party sees (late joiners get it ready); packet = event or private data.
-- No keyBy (T14). Enums and bitfields come from Content keys (T13): Lync sorts the names, both sides require the
-- same Content, code reads and writes strings. Owner of this file: TASK-004 in wave 1 (board conflict point).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)
local Content = require(ReplicatedStorage.shared.Content)

return Lync.define("game", {
	-- c -> s handshake (NetService.Audience)
	Ready = Lync.packet(Lync.empty()),

	-- s -> owner (network.md §4.5; DEC-186). Private by construction: fireClient, never a set
	Profile = Lync.packet(Lync.struct({
		Gems = Lync.int(0, 2147483647),
		Classes = Lync.bitfield(Content.Classes.Keys), -- unlocked classes
		Selected = Lync.enum(Content.Classes.Keys),
	})),

	-- Run sets, wave 1 ---------------------------------------------------------------------------------------------

	-- §3.1, record 1. Writer: RoundService. Wave 1 writes only day fields (Night = 0, IsNight = false...)
	Shift = Lync.replicate(Lync.struct({
		Day = Lync.int(1, 10000),
		Night = Lync.int(0, 10),
		IsNight = Lync.bool(),
		Attempt = Lync.int(0, 9),
		Phase = Lync.enum(Content.Shift.PhaseKeys),
		PhaseStartedAt = Lync.f64(),
		PhaseDuration = Lync.int(0, 3600),
		ClockFrom = Lync.int(0, 2880), -- game minutes
		ClockTo = Lync.int(0, 2880),
		Vehicle = Lync.enum(Content.Vehicles.Keys),
		Chances = Lync.int(0, 9), -- DEC-110, DEC-112; not shown on the HUD (DEC-053)
		WipeEndsAt = Lync.f64(), -- 0 = no wipe window (DEC-094)
		WipeFrozen = Lync.bool(), -- DEC-118
	})),

	-- §3.2, record 1. Writer: RunStateService
	RunState = Lync.replicate(Lync.struct({
		PriceParty = Lync.int(0, 4), -- 0 until the end of Day 1, then fixed (DEC-121)
		RosterSize = Lync.int(1, 4),
		Endless = Lync.bool(), -- DEC-084
	})),

	-- §3.3, record 1. Writer: EconomyService
	Economy = Lync.replicate(Lync.struct({
		Cash = Lync.int(0, 2147483647),
		Drawer = Lync.int(0, 1000000),
	})),

	-- §3.4, record = Content.Ingredients.IndexOf[key] (all 9 always). Writer: KitchenService
	Stock = Lync.replicate(Lync.struct({
		Amount = Lync.int(0, 999),
		Capacity = Lync.int(0, 999), -- Cooler level of the current vehicle (DEC-184)
		Blocked = Lync.bool(), -- not unlocked yet: bowl lid, Mart "Out of stock", order draw (DEC-156, DEC-180)
	})),

	-- §3.5, record = StationId * 100 + Slot (Slot 0 = single-record station). Writer: KitchenService
	Stations = Lync.replicate(Lync.struct({
		Kind = Lync.enum(Content.Stations.RecordKeys), -- grill, rail, board (2 records, DEC-190)
		State = Lync.enum({ "Empty", "Working", "Ready" }),
		StartedAt = Lync.f64(), -- 0 = idle
		Duration = Lync.quant(0, 120, 0.1), -- real duration (level and class applied)
		Count = Lync.int(0, 30), -- rail: sausages on it; others 0
	})),

	-- §3.6, record = NpcId. Writer: CustomerService. Looks are model attributes (network.md §5), not here
	Customers = Lync.replicate(Lync.struct({
		State = Lync.enum({ "Arriving", "Queued", "Ordering", "Waiting", "Leaving" }),
		Slot = Lync.int(0, 8), -- 0 = out of the queue; 1..5 = Q1..Q5
		Order = Lync.bitfield(Content.Ingredients.ToppingKeys), -- empty until "Take Order" (FEAT-011)
		PatienceEndsAt = Lync.f64(), -- 0 until "Take Order" (T41: K stays hidden)
		Mood = Lync.enum(Content.Moods.Keys), -- Provisional (Q-164)
	})),

	-- §3.7, record = Content.Upgrades.IndexOf[key]; levels of the current vehicle only (DEC-184). Writer: UpgradeService
	Upgrades = Lync.replicate(Lync.struct({
		Level = Lync.int(0, 9),
	})),

	-- Packets, wave 1 ----------------------------------------------------------------------------------------------

	-- §4.1 c -> s. Single responder: InteractionService (T6). <= 8/s per player
	Interact = Lync.packet(Lync.struct({
		Id = Lync.int(1, 65535), -- EntityId of the target anchor (T33)
		Action = Lync.enum(Content.Actions.Keys),
	})),

	-- §4.2 s -> player or group, through RunStateService:Notify
	Notice = Lync.packet(Lync.struct({
		Kind = Lync.enum(Content.Notices.Keys),
		Value = Lync.int(-1000000, 1000000), -- {value} of the text, or a table index
	})),

	-- §4.3 s -> group. Writer: CustomerService
	Sale = Lync.packet(Lync.struct({
		Npc = Lync.int(1, 65535), -- NpcId
		Result = Lync.enum({ "Perfect", "Complete", "Incomplete", "Wrong", "Left", "Refused" }),
		Amount = Lync.int(0, 1000), -- what went into the drawer (tip included)
	})),

	-- §4.4 s -> group, start of Summary. Writer: EconomyService
	ShiftReport = Lync.packet(Lync.struct({
		Day = Lync.int(1, 10000),
		Night = Lync.int(0, 10),
		IsNight = Lync.bool(),
		Arrived = Lync.int(0, 999),
		Completed = Lync.int(0, 999),
		Drawer = Lync.int(0, 1000000),
		Tips = Lync.int(0, 100000),
		Stolen = Lync.int(0, 1000000), -- wave 1: 0
		Grade = Lync.enum({ "A", "B", "C", "D" }), -- no customer = C (DEC-051)
		Bonus = Lync.int(0, 1000000),
		Deposited = Lync.int(0, 1000000),
		Gems = Lync.int(0, 1000), -- wave 1: 0
		AfkLocked = Lync.bool(), -- wave 1: false
		LastChanceUsed = Lync.bool(), -- wave 1: false
	})),

	-- §4.6 c -> s. Responder: ClassService. <= 2/s
	ClassAction = Lync.packet(Lync.struct({
		Action = Lync.enum({ "Buy", "Select" }),
		Class = Lync.enum(Content.Classes.Keys),
	})),

	-- Legacy kept until wave 2 (network.md §4.7): example VitalService / RoundService still compile ----------------
	Vitals = Lync.replicate(Lync.struct({
		Health = Lync.int(0, 100),
		Armor = Lync.int(0, 100),
		Stamina = Lync.int(0, 100),
	})),

	Round = Lync.packet(Lync.struct({
		Status = Lync.enum({ "Waiting", "Playing", "Ending" }),
		Seconds = Lync.int(0, 3600),
	})),
})
