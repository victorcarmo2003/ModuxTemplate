--!strict
-- ANM-008 The long car (anomalies.md N8; npcs.md NPC-016; architecture.md §19.13 "Long car", §19.17; MAP-01 §9.5;
-- §19.14; FEAT-019, FEAT-023, FEAT-033; DEC-087, DEC-195, DEC-204, DEC-221; TASK-117, TASK-130). Rule in
-- Rules/ANM-008.luau. Verb: close the trailer service window (protected = window closed and inside the trailer).
--
-- The car is a client-only actor (Effects/ANM-008, TASK-118) driven by the record's StartedAt: it comes in on the
-- Ninth WB lane and reverses into MapPoint AN-12, parked at StartedAt + ArriveAt. The server keeps the timeline:
--   Start    AN-12 bound (else Start false, retried, one warning) -> TrafficService:Hold("anm_008", true) (no
--            traffic car spawns while it runs), Phase Signal.
--   Beam     ArriveAt + BeamDelay: Phase Active + cue car_highbeam (the window of CloseWindow s starts).
--   Flash    beam + CloseWindow: cue car_flash. Every active player in the trailer zone (inside the trailer, or within
--            ZoneRadius of ZonePoint) is tested: not protected -> Fail of that player (personal target, DEC-204);
--            protected -> watched until the car leaves. Outside the zone = not tested (Mart).
--   Stay     flash .. flash + StayFor: whoever opens the window fails (Shutter event, action -> who acted, DEC-204);
--            a watched player who leaves the trailer (5 Hz check) fails.
--   Flavour  on the first failure: car_honk + trailer_blackout (3 s, client only: no drain, DEC-195); a late failure
--            (opening, leaving) also flashes the beam once more.
--   Leave    flash + StayFor: Phase Failed when anyone failed, else Resolved (the client drives the car away), then
--            the record stays LeaveLinger s and Finish. The Hold is released by Stop.
--   Seen     1 s in the gaze cone of the parked car (AN-12, ViewRange 100) between parking and leaving.
--
-- PROVISIONAL (backend-coder, TASK-117; tests/wave-3.md L3-03/L3-15): trailer zone = flat radius around MapPoint TRL
-- (Rules Params), a player inside the trailer always counts as in the zone.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Api = require(script.Parent.Parent.Api)

const REF = "ANM-008"
const SPOT_POINT = "AN-12" -- MapPoint of the long car pose (MAP-01 §10.3)
const HOLD_REASON = "anm_008"
const CAR_HEIGHT = 2.5 -- studs above the ground: body of the car (target of the gaze cone)
const MAX_DT = 0.5 -- s; a late tick never counts more than this
-- Defaults when Rules/ANM-008 is missing (same numbers as the rule file)
const DEFAULT_ARRIVE_AT = 9.5
const DEFAULT_BEAM_DELAY = 2
const DEFAULT_CLOSE_WINDOW = 8
const DEFAULT_STAY_FOR = 15
const DEFAULT_LEAVE_LINGER = 6
const DEFAULT_ZONE_POINT = "TRL"
const DEFAULT_ZONE_RADIUS = 24

type Stage = "Arriving" | "Beam" | "Watching" | "Leaving"

type State = {
	Stage: Stage,
	Car: Vector3,
	Range: number,
	ParkedAt: number,
	BeamAt: number,
	FlashAt: number,
	LeaveAt: number,
	FinishAt: number,
	ZonePoint: string,
	ZoneRadius: number,
	-- userId -> player protected at the flash, still watched until the car leaves
	Watched: { [number]: Player },
	Failed: { [number]: boolean },
	AnyFailed: boolean,
	Flavoured: boolean,
	Held: boolean,
	LastTick: number,
}

-- Live Holds of this module (two occurrences never release each other's Hold)
local holds = 0
local warnedMissing = false

local function param(rule: Api.Rule?, name: string, default: number): number
	if rule == nil then
		return default
	end
	const value = rule.Params[name]
	return if type(value) == "number" and value == value and value >= 0 and value ~= math.huge then value else default
end

local function text(rule: Api.Rule?, name: string, default: string): string
	if rule == nil then
		return default
	end
	const value = rule.Params[name]
	return if type(value) == "string" and value ~= "" then value else default
end

local function setHold(ctx: Api.Context, state: State, on: boolean)
	if state.Held == on then
		return
	end
	state.Held = on
	holds = math.max(0, holds + (if on then 1 else -1))
	if on and holds == 1 then
		ctx.Traffic.Hold(HOLD_REASON, true)
	elseif not on and holds == 0 then
		ctx.Traffic.Hold(HOLD_REASON, false)
	end
end

local function inZone(ctx: Api.Context, state: State, player: Player): boolean
	return ctx.Vehicle.IsInside(player) or ctx.InZone(player, state.ZonePoint, state.ZoneRadius)
end

-- -35 for one player (once per occurrence); the first failure plays the flavour (DEC-195)
local function fail(ctx: Api.Context, occ: Api.Occurrence, state: State, player: Player, late: boolean)
	const userId = player.UserId
	state.Watched[userId] = nil
	if state.Failed[userId] then
		return
	end
	state.Failed[userId] = true
	state.AnyFailed = true
	ctx.Fail(occ, { player })
	if state.Flavoured then
		return
	end
	state.Flavoured = true
	if late then
		ctx.Cue(occ, "car_flash", 0)
	end
	ctx.Cue(occ, "trailer_blackout", 0)
	ctx.Cue(occ, "car_honk", 0)
end

-- End of the close window: test every active player in the trailer zone.
local function flash(ctx: Api.Context, occ: Api.Occurrence, state: State)
	state.Stage = "Watching"
	ctx.Cue(occ, "car_flash", 0)
	const failing: { Player } = {}
	for _, player in ctx.Active() do
		if not inZone(ctx, state, player) then
			continue -- outside the trailer zone: not tested (npcs.md N8)
		end
		if ctx.Vehicle.IsProtected(player) then
			state.Watched[player.UserId] = player
		else
			table.insert(failing, player)
		end
	end
	for _, player in failing do
		fail(ctx, occ, state, player, false)
	end
end

local function leave(ctx: Api.Context, occ: Api.Occurrence, state: State)
	state.Stage = "Leaving"
	state.Watched = {}
	ctx.Publish(occ, { Phase = if state.AnyFailed then "Failed" else "Resolved" })
end

const LongCar: Api.Module = {
	Ref = REF,

	Start = function(ctx: Api.Context, occ: Api.Occurrence): boolean
		const spot = MapIndex.FindPoint(SPOT_POINT)
		if spot == nil then
			if not warnedMissing then
				warnedMissing = true
				ctx.Log(occ, `MapPoint {SPOT_POINT} not bound; not started (MAP-01 §10.3)`)
			end
			return false
		end
		const rule = ctx.Rule(REF)
		const row = Content.Anomalies.ByKey[occ.Key]
		const parkedAt = occ.StartedAt + param(rule, "ArriveAt", DEFAULT_ARRIVE_AT)
		const beamAt = parkedAt + param(rule, "BeamDelay", DEFAULT_BEAM_DELAY)
		const flashAt = beamAt + param(rule, "CloseWindow", if rule ~= nil then rule.Window else DEFAULT_CLOSE_WINDOW)
		const leaveAt = flashAt + param(rule, "StayFor", DEFAULT_STAY_FOR)
		const state: State = {
			Stage = "Arriving",
			Car = spot.Position + Vector3.new(0, CAR_HEIGHT, 0),
			Range = if row ~= nil then row.ViewRange else 0,
			ParkedAt = parkedAt,
			BeamAt = beamAt,
			FlashAt = flashAt,
			LeaveAt = leaveAt,
			FinishAt = leaveAt + param(rule, "LeaveLinger", DEFAULT_LEAVE_LINGER),
			ZonePoint = text(rule, "ZonePoint", DEFAULT_ZONE_POINT),
			ZoneRadius = param(rule, "ZoneRadius", DEFAULT_ZONE_RADIUS),
			Watched = {},
			Failed = {},
			AnyFailed = false,
			Flavoured = false,
			Held = false,
			LastTick = occ.StartedAt,
		}
		occ.State = state
		setHold(ctx, state, true)
		ctx.Publish(occ, { Phase = "Signal", Step = 0, Anchor = 0 })
		return true
	end,

	Tick = function(ctx: Api.Context, occ: Api.Occurrence, now: number)
		const state = occ.State :: State
		const dt = math.clamp(now - state.LastTick, 0, MAX_DT)
		state.LastTick = now

		if state.Stage == "Leaving" then
			if now >= state.FinishAt then
				ctx.Finish(occ)
			end
			return
		end
		if now >= state.ParkedAt and state.Range > 0 then
			ctx.SeenTick(occ, state.Car, state.Range, dt)
		end
		if state.Stage == "Arriving" and now >= state.BeamAt then
			state.Stage = "Beam"
			ctx.Publish(occ, { Phase = "Active" })
			ctx.Cue(occ, "car_highbeam", 0)
		end
		if state.Stage == "Beam" and now >= state.FlashAt then
			flash(ctx, occ, state)
		end
		if state.Stage == "Watching" then
			-- Omission (anomalies.md N8): a watched player left the trailer before the car left. Read at 5 Hz (Tick only
			-- runs in the Night phase).
			const out: { Player } = {}
			for _, player in state.Watched do
				if player.Parent == nil then
					continue
				end
				if not ctx.Vehicle.IsInside(player) then
					table.insert(out, player)
				end
			end
			for _, player in out do
				fail(ctx, occ, state, player, true)
			end
			if now >= state.LeaveAt then
				leave(ctx, occ, state)
			end
		end
	end,

	-- Action (DEC-204): opening the window while the car is parked fails who opened, wherever they are
	OnEvent = function(ctx: Api.Context, occ: Api.Occurrence, event: Api.Event)
		const state = occ.State :: State?
		if state == nil or state.Stage ~= "Watching" then
			return
		end
		if event.Kind == "Shutter" then
			const opener = event.Player
			if not event.Closed and opener ~= nil then
				fail(ctx, occ, state, opener, true)
			end
		end
	end,

	Stop = function(ctx: Api.Context, occ: Api.Occurrence, _reason: Api.StopReason)
		const state = occ.State :: State?
		if state ~= nil then
			setHold(ctx, state, false)
		end
		occ.State = nil
	end,
}

return LongCar
