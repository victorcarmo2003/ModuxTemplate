--!strict
-- Net v3 (waves 1-3). Contract: docs/tech/network.md v4 (wave 1), v5 §13.1-§13.4 (wave 2) and §13.5-§13.7 (wave 3):
-- schema, writer, reader and rate of every entry.
-- Rules: set = state the party sees (late joiners get it ready); packet = event or private data.
-- No keyBy (T14). Enums and bitfields come from Content keys (T13): Lync sorts the names, both sides require the
-- same Content, code reads and writes strings. Owner of this file: TASK-004 (wave 1), TASK-048 (wave 2), TASK-097
-- (wave 3) (board conflict point). Legacy Round packet and Health/Armor/Stamina Vitals are gone (§13.11).
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
		-- Wave 3 (§13.5, ANM-002): 0 or nil = nothing altered; grill/board: 1 = this slot; rail: position 1..Count.
		-- Optional so the wave 1-2 writer keeps compiling and encoding until TASK-109 writes it (nil reads as 0).
		Altered = Lync.optional(Lync.int(0, 30)),
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

	-- Wave 2 (network.md §13.1-§13.4) ----------------------------------------------------------------------------

	-- §13.1, record = UserId. Writer: VitalService (single writer). Replaces the legacy Health/Armor/Stamina set
	Vitals = Lync.replicate(Lync.struct({
		State = Lync.enum({ "Active", "Down", "Reviving", "Spectator", "Away" }),
		StateEndsAt = Lync.f64(), -- Down: 6:00 AM of the night of the fall (DEC-115); 0 = no deadline
		KnockedUntil = Lync.f64(), -- hit by a car until (wave 3); 0 = standing
		Class = Lync.enum(Content.Classes.Keys),
	})),

	-- §13.1 s -> owner. Writer: VitalService. Max = 0: no sanity (day), the HUD hides the meter
	Sanity = Lync.packet(Lync.struct({
		Value = Lync.int(0, 200),
		Max = Lync.int(0, 200),
	})),

	-- §13.1 s -> group. Writers: VitalService, TrafficService (Hit, wave 3). The state itself is in Vitals
	LifeEvent = Lync.packet(Lync.struct({
		UserId = Lync.f64(),
		Event = Lync.enum({ "Down", "Revived", "Spectating", "Hit", "Wipe", "WipeCleared" }),
	})),

	-- §13.1 s -> group. Writer: VehicleService (1.5 s fade of the vehicle swap, T58)
	Transition = Lync.packet(Lync.struct({
		Kind = Lync.enum({ "VehicleSwap" }),
		StartedAt = Lync.f64(),
	})),

	-- §13.1 s -> each player on RunEnded. Writer: RoundService. Gems of this run for this player (RunRewards)
	RunReport = Lync.packet(Lync.struct({
		Result = Lync.enum({ "Success", "Failed" }),
		Day = Lync.int(1, 10000),
		Night = Lync.int(0, 10),
		Gems = Lync.int(0, 100000),
	})),

	-- §13.2, record = Content.LightGroups.IndexOf[key]. Writer: LightService
	Lights = Lync.replicate(Lync.struct({
		On = Lync.bool(), -- group lit now (night, switch/upgrade, no Hush)
		At = Lync.f64(), -- last change; Hush: start (posts go out by Order x Step)
	})),

	-- §13.3, record 1. Writer: BossService. Line = floor((now - StartedAt) / BossCallRules.LineTime) (T44)
	Call = Lync.replicate(Lync.struct({
		Call = Lync.enum(Content.BossCalls.Keys), -- includes "none"
		State = Lync.enum({ "Idle", "Ringing", "Talking" }),
		StartedAt = Lync.f64(),
	})),

	-- §13.4, record 1. Writer: ThiefService. Bar over Bar_Thief by StartedAt / Duration
	Thief = Lync.replicate(Lync.struct({
		State = Lync.enum({ "None", "Lurking", "Approaching", "Opening", "Fleeing" }),
		StartedAt = Lync.f64(),
		Duration = Lync.quant(0, 30, 0.1), -- Opening: 8 s (16 s with UPG-004)
	})),

	-- Wave 3 (network.md §13.5-§13.7) ----------------------------------------------------------------------------

	-- §13.5, record = occurrence 1..255 (cyclic, per night). Writer: AnomalyService. No verb or deadline (T10)
	Anomalies = Lync.replicate(Lync.struct({
		Anomaly = Lync.enum(Content.Anomalies.Keys),
		Phase = Lync.enum({ "Signal", "Active", "Resolved", "Failed" }),
		StartedAt = Lync.f64(),
		-- Walker: step 0..10; Hush: posts out; others 0
		Step = Lync.int(0, 20),
		-- NpcId of the customer anomaly, or anchor index (AnchorId/MapPoint); 0 = none
		Anchor = Lync.int(0, 65535),
	})),

	-- §13.5 s -> group (everyone sees the sign, DEC-204). Writer: AnomalyService
	AnomalyCue = Lync.packet(Lync.struct({
		Anomaly = Lync.enum(Content.Anomalies.Keys),
		Cue = Lync.enum(Content.AnomalyCues.Keys),
		Entity = Lync.int(0, 65535),
		Seed = Lync.int(0, 65535),
	})),

	-- §13.5 c -> s, 10 Hz, latest wins. Sender: CameraController (night, Active, not hidden). Responder: AnomalyService.
	-- Degrees 0..360, 1 degree steps; angle is cyclic, so a pitch of -20 travels as 340 (reader maps > 180 to -).
	Gaze = Lync.packet(Lync.struct({
		Yaw = Lync.angle(1),
		Pitch = Lync.angle(1),
	})):newest(10),

	-- §13.6, record = UserId; removed when the player gets up. Writer: HideService (T52: Vitals keeps one writer)
	Hides = Lync.replicate(Lync.struct({
		-- H1..H4 (DEC-176)
		Slot = Lync.int(1, 4),
	})),

	-- §13.7 (§6.2 schema), record 1. Writer: CutsceneService. Needed = ceil(0.5 x connected participants) (DEC-194)
	Cutscene = Lync.replicate(Lync.struct({
		Scene = Lync.enum(Content.Cutscenes.Keys),
		StartedAt = Lync.f64(),
		Votes = Lync.int(0, 4),
		Needed = Lync.int(0, 4),
	})),

	-- §13.7 c -> s, <= 1 per segment. Responder: CutsceneService
	SkipVote = Lync.packet(Lync.empty()),

	-- §13.7 (§6.2 schema; architecture.md §8.1), record = car slot 1..8. Writer: TrafficService, on events only.
	-- Route = Content.Traffic.Routes.IndexOf; Look = Content.Traffic.LookIndex (4 shapes x 5 paints = 20; room to 32).
	-- Position = Traffic/shared/Motion from the last record (AnchorAt/AnchorDist, stop at StopDist until HeldUntil)
	Traffic = Lync.replicate(Lync.struct({
		Route = Lync.int(1, 32),
		Look = Lync.int(1, 32),
		AnchorAt = Lync.f64(),
		AnchorDist = Lync.f32(),
		StopDist = Lync.f32(),
		HeldUntil = Lync.f64(),
	})),

	-- §13.7 (§6.2 schema; architecture.md §8.2) c -> s, own character only. Responder: TrafficService (+-8 studs)
	CarHit = Lync.packet(Lync.struct({
		Car = Lync.int(1, 8),
	})),

	-- §13.7, record = pedestrian slot 1..8. Writer: PedestrianService. Looks ride here (rule 9 exception: no server
	-- model, T46); same 1D record as Traffic, read with Traffic/shared/Motion
	Pedestrians = Lync.replicate(Lync.struct({
		-- Content.WalkPaths.IndexOf
		Path = Lync.int(1, 64),
		Species = Lync.enum(Content.Species.Keys),
		Outfit = Lync.enum(Content.Outfits.Keys),
		Speed = Lync.quant(4, 12, 0.5),
		AnchorAt = Lync.f64(),
		AnchorDist = Lync.f32(),
		-- stop at a crosswalk waiting for the reservation (§8.1); 0 = no stop
		StopDist = Lync.f32(),
		HeldUntil = Lync.f64(),
	})),
})
